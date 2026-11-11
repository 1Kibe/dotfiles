.pragma library

// The wallpaper import of the gallery (state/WallpaperStore), as a fixed
// script that gets every value as an argument ("sh -c <script> sh <args>").
// Plain JS: read by the shell and by the tests (test-appearance.sh).
// $1 the picture, $2 the import folder, $3 the size limit. The folder is
// made 700 and must be a real folder (no link); the picture must be a
// regular file within the limit. It is copied to a temporary name inside
// the folder; the COPY's size and real type are checked, and it is
// renamed to the first 16 hex digits of its SHA-256 plus the extension of
// its type. Prints the final path. Every path goes after "--".
var importScript =
    'src=$1; dir=$2; max=$3\n'
    + 'umask 077\n'
    + 'mkdir -p -m 700 -- "$dir" || exit 1\n'
    + '[ -d "$dir" ] && [ ! -L "$dir" ] || exit 1\n'
    + 'chmod 700 -- "$dir" || exit 1\n'
    + '[ -f "$src" ] && [ ! -L "$src" ] || exit 1\n'
    + 's=$(stat -c %s -- "$src") || exit 1\n'
    + '[ "$s" -le "$max" ] || exit 1\n'
    + 'tmp=$(mktemp -p "$dir" .import-XXXXXX) || exit 1\n'
    + 'trap \'rm -f -- "$tmp"\' EXIT\n'
    + 'timeout 10 head -c "$((max + 1))" -- "$src" > "$tmp" || exit 1\n'
    + 's=$(stat -c %s -- "$tmp") || exit 1\n'
    + '[ "$s" -le "$max" ] || exit 1\n'
    + 'case "$(file -b --mime-type -- "$tmp")" in\n'
    + '  image/png) ext=png ;;\n'
    + '  image/jpeg) ext=jpg ;;\n'
    + '  image/webp) ext=webp ;;\n'
    + '  *) exit 1 ;;\n'
    + 'esac\n'
    + 'h=$(sha256sum -- "$tmp" | cut -c1-16)\n'
    + 'case "$h" in *[!0-9a-f]*|"") exit 1 ;; esac\n'
    + 'dest="$dir/$h.$ext"\n'
    + 'mv -T -- "$tmp" "$dest" || exit 1\n'
    + 'trap - EXIT\n'
    + 'printf "%s\\n" "$dest"'
