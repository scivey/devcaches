#!/bin/bash
set -u
# set -o pipefail
SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})


function make-rm-func() {
    local badname="$1"
    local src=$(cat <<EOF
    {
        echo make-cleanup result;
        echo badname="$badname";
        rm -rf "$badname";
    }
EOF
)
    echo -n "$src"
}

__OK_CLEANUP=""
__ERR_CLEANUP=""
function register-cleanup() {
    if [[ "${__ERR_CLEANUP}" == "" ]]; then
        __ERR_CLEANUP="{ exit 1; }"
    fi
    local badname="$1"
    local cleanit=$(make-rm-func "$badname")
    __OK_CLEANUP="${cleanit}; ${__OK_CLEANUP}"
    __ERR_CLEANUP="${cleanit}; ${__ERR_CLEANUP}"
    # trap "{ echo '${__ERR_CLEANUP}'; exit 1; }" SIGTERM SIGINT
    # trap "{ echo '${__OK_CLEANUP}'; }" EXIT

    # trap "{ echo ENDED; exit 1; }" SIGTERM SIGINT
    trap "${__ERR_CLEANUP}" SIGTERM SIGINT
    trap "${__OK_CLEANUP}" EXIT
}


EXCLUDE=$(cat <<EOF

from __future__ import print_function
import sys

f1, f2 = sys.argv[1:]
bad = set()
with open(f1) as fin1:
    for line in fin1:
        bad.add(line.strip())
with open(f2) as fin2:
    for line in fin2:
        line = line.strip()
        if line in bad:
            continue
        print(line)
EOF
)


function base-name-no-ext() {
  local fname=$(basename "$1" | awk -F '.' '{print $1}' )
  echo -n "$fname"
}

function make-tmp-template() {
  local fname=$(base-name-no-ext "$1")
  local astemp="${fname}.tmpXXXX"
  echo -n "$astemp"
}

function __detail-mk-temp-in() {
  # this used to make more sense than it does now
  local base_cmd="$1"
  local target_dir="$2"
  local tmpl_base=${3:-${SCRIPT_NAME}}
  local target_tmpl=$(make-tmp-template "$tmpl_base")
  local fname=$(${base_cmd} -p "$target_dir" -t "$target_tmpl")
  echo -n "$fname"
}

function mk-temp-in() {
  __detail-mk-temp-in mktemp $@
}

function mk-temp-dir-in() {
  __detail-mk-temp-in "mktemp -d" $@
}

function exclude-from() {
  local tempdir="$1"
  local badfile="$2"
  local goodfile="$3"
  local fname=$(mk-temp-in "$tempdir" "exclude_py")
  echo "$EXCLUDE" > $fname
  python $fname "$badfile" "$goodfile"
}


function warm-deps-for-package() {
  local package_name="$1"
  mkdir -p temp
  local tdir=$(mk-temp-dir-in temp)
  echo "tdir='$tdir'" >&2
  register-cleanup "$tdir"

  local rdeps=$(mk-temp-in $tdir "rdeps")
  local dl_hist=$(mk-temp-in $tdir "dl_hist")

  # r-depends recursively lists dependencies
  apt-rdepends "$package_name" \
    | grep -v "^ " \
    | grep -v debconf-2 2>&1 > $rdeps

  set -o pipefail
  cat $rdeps | xargs apt-get download 2>&1 | tee $dl_hist
  local res="$?"
  set +o pipefail
  if [[ "$res" == "0" ]]; then
    echo "SUCCESS" >&2
    return
  else
    local dl_hist_bad_pkg=$(mk-temp-in $tdir "dl_hist_bad_pkg")
    local good_deps=$(mk-temp-in $tdir "good_deps")
    echo "FAILURE.. FIXING." >&2
    cat $dl_hist | awk '/.*select candidate.*/ {print $8}' > $dl_hist_bad_pkg
    exclude-from $tdir $dl_hist_bad_pkg $rdeps > $good_deps
    cat $good_deps | xargs apt-get download
  fi
}


for lname in $@; do
  echo "lname: '$lname'" >&2
  warm-deps-for-package $lname
done
