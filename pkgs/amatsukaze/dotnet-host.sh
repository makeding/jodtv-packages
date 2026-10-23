#!@shell@
directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
program=${0##*/}
exec @loader@ --library-path "@glibc@/lib:$directory/lib" "$directory/.$program-unwrapped" "$@"
