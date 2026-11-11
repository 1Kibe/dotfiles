.pragma library

// The wallpaper import of the gallery (state/WallpaperStore), as a fixed
// script that gets every value as an argument ("sh -c <script> sh <args>";
// the store runs it under a 30 s timeout). Plain JS: read by the shell and
// by the tests (test-appearance.sh).
// $1 the picture, $2 the import folder, $3 the size limit. The folder is
// made 700 and must be a real folder (no link); leftovers of an import that
// was killed (.import-*, over 5 minutes old) go first. The picture is read
// once, never through a link (dd iflag=nofollow; nonblock: a FIFO does not
// hang it), at most the limit plus a little, into a temporary name inside
// the folder (removed on the way out, also when killed); the COPY's size
// and real type are checked, and it is named after the first 32 hex digits
// of its SHA-256 plus the extension of its type. The same picture again keeps the file already there. Prints the
// final path. Every path goes after "--" or as an operand of dd.
var importScript =
    'src=$1; dir=$2; max=$3\n'
    + 'umask 077\n'
    + 'mkdir -p -m 700 -- "$dir" || exit 1\n'
    + '[ -d "$dir" ] && [ ! -L "$dir" ] || exit 1\n'
    + 'chmod 700 -- "$dir" || exit 1\n'
    + 'find "$dir" -maxdepth 1 -name ".import-*" -type f -mmin +5 -delete 2>/dev/null\n'
    + 'case "$src" in /*) ;; *) exit 1 ;; esac\n'
    + '[ -f "$src" ] && [ ! -L "$src" ] || exit 1\n'
    + 'tmp=$(mktemp -p "$dir" .import-XXXXXX) || exit 1\n'
    + 'trap \'rm -f -- "$tmp"\' EXIT\n'
    + 'trap \'exit 1\' HUP INT TERM\n'
    + 'dd if="$src" of="$tmp" iflag=nofollow,nonblock bs=65536 count=$((max / 65536 + 2)) status=none || exit 1\n'
    + 's=$(stat -c %s -- "$tmp") || exit 1\n'
    + '[ "$s" -gt 0 ] && [ "$s" -le "$max" ] || exit 1\n'
    + 'case "$(file -b --mime-type -- "$tmp")" in\n'
    + '  image/png) ext=png ;;\n'
    + '  image/jpeg) ext=jpg ;;\n'
    + '  image/webp) ext=webp ;;\n'
    + '  *) exit 1 ;;\n'
    + 'esac\n'
    + 'h=$(sha256sum -- "$tmp" | cut -c1-32)\n'
    + 'case "$h" in *[!0-9a-f]*|"") exit 1 ;; esac\n'
    + 'dest="$dir/$h.$ext"\n'
    + 'if [ -e "$dest" ] || [ -L "$dest" ]; then\n'
    + '  [ -f "$dest" ] && [ ! -L "$dest" ] || exit 1\n'
    + '  rm -f -- "$tmp"\n'
    + 'else\n'
    + '  mv -T -- "$tmp" "$dest" || exit 1\n'
    + 'fi\n'
    + 'trap - EXIT\n'
    + 'printf "%s\\n" "$dest"'
