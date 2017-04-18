#!/bin/bash
set -u


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




function exclude-from() {
  local tempdir="$1"
  local badfile="$2"
  local goodfile="$3"
  local fname=$(mktemp -p $tempdir)
  fname="${fname}.py"
  echo "$EXCLUDE" > $fname
  python $fname "$badfile" "$goodfile"
}


function warm-deps-for-package() {
  local package_name="$1"
  mkdir -p temp
  local tdir=$(mktemp -d -p temp)
  echo "tdir='$tdir'" >&2
  register-cleanup "$tdir"
  # r-depends recursively lists dependencies
  apt-rdepends "$package_name" \
    | grep -v "^ " \
    | grep -v debconf-2 2>&1 > $tdir/rdeps

  set -o pipefail
  cat $tdir/rdeps | xargs apt-get download 2>&1 | tee $tdir/dl-hist
  local res="$?"
  set +o pipefail
  if [[ "$res" == "0" ]]; then
    echo "SUCCESS" >&2
    return
  else
    echo "FAILURE.. FIXING." >&2
    cat $tdir/dl-hist | awk '/.*select candidate.*/ {print $8}' > $tdir/dl-hist-bad-pkg
    exclude-from $tdir $tdir/dl-hist-bad-pkg $tdir/rdeps > $tdir/good_deps
    cat $tdir/good_deps | xargs apt-get download
  fi
}



warm-deps-for-package libboost-all-dev
