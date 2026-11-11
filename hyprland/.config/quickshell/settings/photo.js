.pragma library

// The user's photo (Configurações → Bloqueio e login → Foto), as fixed
// scripts that get every value as an argument ("sh -c <script> sh <args>";
// state/PhotoStore runs them under a timeout). Plain JS: read by the shell
// and by the tests (test-shell-pages.sh).

// $1 the picture, $2 the photo file (~/.face), $3 the size limit, $4 the
// largest side and $5 the most pixels ffmpeg may decode. The picture is read
// once, never through a link (dd iflag=nofollow; nonblock: a FIFO does not
// hang it), into a temporary file next to the photo; its size, real type and
// declared width and height are checked on that copy (a small compressed
// file may declare a huge picture: "big" then, exit 3). ffmpeg then decodes
// only that copy (a fixed decoder for the checked type, files only, one
// frame, one thread, its own pixel limit too, with room for the padding
// its decoders add to each side), crops it to a centered square
// and scales it to 512 px at most, into a second temporary file (600). That
// one is checked to be a PNG and renamed over the photo with `mv -T`, which
// replaces the entry itself (a link there is replaced, never followed).
// Prints "ok". Killed by the caller's timeout, it still removes both
// temporary files: the signal reaches ffmpeg too (its own timeout runs in
// the foreground, in the same process group) and ends the script through
// the EXIT trap; leftovers of a harder kill (over 5 minutes old) go first.
var setScript =
    'src=$1; out=$2; max=$3; side=$4; pixels=$5\n'
    + 'umask 077\n'
    + 'tin=; tout=\n'
    + 'trap \'rm -f -- ${tin:+"$tin"} ${tout:+"$tout"}\' EXIT\n'
    + 'trap \'exit 1\' HUP INT TERM\n'
    + 'dir=$(dirname -- "$out")\n'
    + '[ -d "$dir" ] || exit 1\n'
    + 'find "$dir" -maxdepth 1 \\( -name ".face-in-*" -o -name ".face-new-*" \\) -type f -mmin +5 -delete 2>/dev/null\n'
    + 'case "$src" in /*) ;; *) exit 1 ;; esac\n'
    + '[ -f "$src" ] && [ ! -L "$src" ] || exit 1\n'
    + 'tin=$(mktemp -p "$dir" .face-in-XXXXXX) || exit 1\n'
    + 'tout=$(mktemp -p "$dir" .face-new-XXXXXX) || exit 1\n'
    + 'dd if="$src" of="$tin" iflag=nofollow,nonblock bs=65536 count=$((max / 65536 + 2)) status=none || exit 1\n'
    + 's=$(stat -c %s -- "$tin") || exit 1\n'
    + '[ "$s" -gt 0 ] && [ "$s" -le "$max" ] || exit 1\n'
    + 'case "$(file -b --mime-type -- "$tin")" in\n'
    + '  image/png) dec=png ;;\n'
    + '  image/jpeg) dec=mjpeg ;;\n'
    + '  image/webp) dec=webp ;;\n'
    + '  *) exit 1 ;;\n'
    + 'esac\n'
    + 'wh=$(file -b -- "$tin" | grep -oE "[0-9]+ ?x ?[0-9]+" | tail -n 1 | tr -d " ")\n'
    + 'w=${wh%x*}; h=${wh#*x}\n'
    + 'case "$w:$h" in *[!0-9:]*|:*|*:) exit 1 ;; esac\n'
    + '[ ${#w} -le 9 ] && [ ${#h} -le 9 ] && [ "$w" -gt 0 ] && [ "$h" -gt 0 ] || exit 1\n'
    + 'if [ "$w" -gt "$side" ] || [ "$h" -gt "$side" ] || [ $((w * h)) -gt "$pixels" ]; then echo big; exit 3; fi\n'
    + 'timeout --foreground 15 ffmpeg -nostdin -hide_banner -loglevel error -y -protocol_whitelist file '
    + '-threads 1 -max_pixels $((pixels + 512 * side)) '
    + '-c:v "$dec" -f image2 -i "file:$tin" '
    + '-vf "crop=min(iw\\,ih):min(iw\\,ih),scale=min(512\\,iw):-1:flags=lanczos,format=rgb24" '
    + '-map_metadata -1 -frames:v 1 -f image2 -c:v png "file:$tout" || exit 1\n'
    + '[ "$(file -b --mime-type -- "$tout")" = image/png ] || exit 1\n'
    + 'chmod 600 -- "$tout" || exit 1\n'
    + 'mv -T -- "$tout" "$out" || exit 1\n'
    + 'tout=\n'
    + 'echo ok'

// $1 the photo file: removed (a link there goes, never followed)
var removeScript =
    'rm -f -- "$1" && echo ok'
