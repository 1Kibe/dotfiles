.pragma library

// The user's photo (Configurações → Bloqueio e login → Foto), as fixed
// scripts that get every value as an argument ("sh -c <script> sh <args>";
// state/PhotoStore runs them under a timeout). Plain JS: read by the shell
// and by the tests (test-shell-pages.sh).

// $1 the picture, $2 the photo file (~/.face), $3 the size limit. The
// picture is read once, never through a link (dd iflag=nofollow; nonblock: a
// FIFO does not hang it), into a temporary file next to the photo; its size
// and real type are checked on that copy. ffmpeg then decodes only that copy
// (a fixed decoder for the checked type, files only, one frame), crops it to
// a centered square and scales it to 512 px at most, into a second
// temporary file (600). That one is checked to be a PNG and renamed over the
// photo with `mv -T`, which replaces the entry itself (a link there is
// replaced, never followed). Prints "ok".
var setScript =
    'src=$1; out=$2; max=$3\n'
    + 'umask 077\n'
    + 'dir=$(dirname -- "$out")\n'
    + '[ -d "$dir" ] || exit 1\n'
    + 'case "$src" in /*) ;; *) exit 1 ;; esac\n'
    + '[ -f "$src" ] && [ ! -L "$src" ] || exit 1\n'
    + 'tin=$(mktemp -p "$dir" .face-in-XXXXXX) || exit 1\n'
    + 'tout=$(mktemp -p "$dir" .face-new-XXXXXX) || exit 1\n'
    + 'trap \'rm -f -- "$tin" "$tout"\' EXIT\n'
    + 'dd if="$src" of="$tin" iflag=nofollow,nonblock bs=65536 count=$((max / 65536 + 2)) status=none || exit 1\n'
    + 's=$(stat -c %s -- "$tin") || exit 1\n'
    + '[ "$s" -gt 0 ] && [ "$s" -le "$max" ] || exit 1\n'
    + 'case "$(file -b --mime-type -- "$tin")" in\n'
    + '  image/png) dec=png ;;\n'
    + '  image/jpeg) dec=mjpeg ;;\n'
    + '  image/webp) dec=webp ;;\n'
    + '  *) exit 1 ;;\n'
    + 'esac\n'
    + 'timeout 15 ffmpeg -nostdin -hide_banner -loglevel error -y -protocol_whitelist file '
    + '-c:v "$dec" -f image2 -i "file:$tin" '
    + '-vf "crop=min(iw\\,ih):min(iw\\,ih),scale=min(512\\,iw):-1:flags=lanczos,format=rgb24" '
    + '-map_metadata -1 -frames:v 1 -f image2 -c:v png "file:$tout" || exit 1\n'
    + '[ "$(file -b --mime-type -- "$tout")" = image/png ] || exit 1\n'
    + 'chmod 600 -- "$tout" || exit 1\n'
    + 'mv -T -- "$tout" "$out" || exit 1\n'
    + 'echo ok'

// $1 the photo file: removed (a link there goes, never followed)
var removeScript =
    'rm -f -- "$1" && echo ok'
