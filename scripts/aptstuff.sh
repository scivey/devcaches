
function list-apt-libs() {
        ls /var/lib/dpkg/info \
    |   grep -P "^lib" \
    | sed -r 's/^(.*)\.[^.]+/\1/' \
    | uniq \
    | sort \
    | uniq
}
