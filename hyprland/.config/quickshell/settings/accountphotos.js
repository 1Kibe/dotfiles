.pragma library

// The public photo of a GitHub account (state/CodeAccounts): the fixed
// script that fetches it into the cache. Plain JS: read by the shell and
// by the tests, which run the same script with a fake curl.
//
// Input (stdin): the login, one line, already checked by
// codeaccounts.js validGithubPhotoLogin and checked again here. It never
// goes in an argument: curl gets its address from its own input (-K -).
// $1: the shell's folder of the repo (the cache must not be inside it).
//
// Two steps, no token, never following a redirect: github.com/<login>.png
// answers 302 with the account's id in its Location (only that exact
// address and a numeric id are taken); the photo's address is then made
// again from the id alone. The body is cut at 256 KiB in the pipe, and
// before it is kept it must be a PNG or a JPEG of 8 to 512 px each side
// (read from its header, so no other format, and no huge image, ever
// reaches the decoder). The cache: $XDG_CACHE_HOME (only a plain absolute
// path) or ~/.cache, then dotfiles/contas-fotos, 700, never a link nor
// inside the clone; each photo 600, named by the sha256 of
// "github.com|<login in lower case>", replaced in one rename; renewed after
// 7 days (or when its time is in the future). It prints one fixed word:
// "ok <hex>", "cached <hex>", "none" (no such account), "fail", "nocurl".
// Nothing else: no id, address, login or HTTP code goes back.

var SCRIPT = 'set -u\n'
    + 'umask 077\n'
    + 'q=$1\n'
    + 'r=$(readlink -f -- "$q/../../..") || { echo fail; exit 0; }\n'
    + 'IFS= read -r login || { echo fail; exit 0; }\n'
    + '[[ $login =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] || { echo fail; exit 0; }\n'
    + 'command -v curl >/dev/null 2>&1 || { echo nocurl; exit 0; }\n'
    + 'exec 2>/dev/null\n'
    + 'base=${XDG_CACHE_HOME:-}\n'
    + 'if ! [[ $base =~ ^/[A-Za-z0-9._/-]{1,200}$ ]] || [[ $base == *..* ]]; then base=$HOME/.cache; fi\n'
    + '[ -d "$base" ] || { echo fail; exit 0; }\n'
    + 'dir=$base/dotfiles/contas-fotos\n'
    + 'for x in "$base/dotfiles" "$dir"; do\n'
    + '  if [ ! -e "$x" ] && [ ! -L "$x" ]; then install -d -m 700 -- "$x" || { echo fail; exit 0; }; fi\n'
    + '  [ -d "$x" ] && [ ! -L "$x" ] && [ -O "$x" ] || { echo fail; exit 0; }\n'
    + '  t=$(readlink -f -- "$x") || { echo fail; exit 0; }\n'
    + '  case "$t/" in "$r"/*) echo fail; exit 0;; esac\n'
    + 'done\n'
    + '[ -z "$(find "$dir" -maxdepth 0 -perm /077)" ] || { echo fail; exit 0; }\n'
    + 'key=$(printf "github.com|%s" "${login,,}" | sha256sum | cut -c1-64)\n'
    + '[[ $key =~ ^[0-9a-f]{64}$ ]] || { echo fail; exit 0; }\n'
    + 'f=$dir/$key\n'
    + 'if [ -L "$f" ] || { [ -e "$f" ] && [ ! -f "$f" ]; }; then echo fail; exit 0; fi\n'
    + 'if [ -f "$f" ]; then\n'
    + '  m=$(stat -c %Y -- "$f"); now=$(date +%s)\n'
    + '  if (( m <= now && now - m <= 604800 )); then echo "cached $key"; exit 0; fi\n'
    + 'fi\n'
    + 'get() {\n'
    + '  env -u CURL_HOME -u CURL_CA_BUNDLE -u SSL_CERT_FILE -u SSL_CERT_DIR -u CURL_SSL_BACKEND LC_ALL=C \\\n'
    + '    timeout -k 2 8 setpriv --pdeathsig TERM -- curl -q -K - -s --proto =https --tlsv1.2 -m 8 --connect-timeout 5 --max-redirs 0 "$@"\n'
    + '}\n'
    // Step 1: the id, from the redirect's Location only
    + 'res=$(printf "url = \\"https://github.com/%s.png\\"\\n" "$login" | get -o /dev/null -w "%{http_code} %{redirect_url}") || { echo fail; exit 0; }\n'
    + 'if [[ $res =~ ^404\\ ?$ ]]; then echo none; exit 0; fi\n'
    + '[[ $res =~ ^302\\ https://avatars\\.githubusercontent\\.com/u/([0-9]{1,12})([?][^[:space:]]*)?$ ]] || { echo fail; exit 0; }\n'
    + 'id=${BASH_REMATCH[1]}\n'
    // Step 2: the photo, from an address made again
    + 'tmp=$(mktemp -- "$dir/.t.XXXXXXXX") || { echo fail; exit 0; }\n'
    + 'trap \'rm -f -- "$tmp"\' EXIT\n'
    + 'printf "url = \\"https://avatars.githubusercontent.com/u/%s?s=64\\"\\n" "$id" | get -f --max-filesize 262144 -o - | head -c 262145 > "$tmp"\n'
    + '[ "${PIPESTATUS[1]}" = 0 ] || { echo fail; exit 0; }\n'
    + 'size=$(stat -c %s -- "$tmp")\n'
    + '(( size >= 64 && size <= 262144 )) || { echo fail; exit 0; }\n'
    + 'hex=$(od -An -v -tx1 -- "$tmp" | tr -d " \\n")\n'
    + 'w=0; h=0\n'
    + 'if [[ ${hex:0:16} == 89504e470d0a1a0a && ${hex:24:8} == 49484452 ]]; then\n'
    + '  w=$((16#${hex:32:8})); h=$((16#${hex:40:8}))\n'
    + 'elif [[ ${hex:0:6} == ffd8ff ]]; then\n'
    // The markers up to the first SOFn (its height then width)
    + '  p=2; n=${#hex}\n'
    + '  while (( 2*p + 8 <= n )); do\n'
    + '    [[ ${hex:2*p:2} == ff ]] || break\n'
    + '    mk=${hex:2*p+2:2}\n'
    + '    if [[ $mk == ff ]]; then p=$((p+1)); continue; fi\n'
    + '    if [[ $mk =~ ^c[0-35-79a-bd-f]$ ]]; then\n'
    + '      (( 2*p + 18 <= n )) || break\n'
    + '      h=$((16#${hex:2*p+10:4})); w=$((16#${hex:2*p+14:4})); break\n'
    + '    fi\n'
    + '    [[ $mk == d8 || $mk == d9 || $mk == da ]] && break\n'
    + '    len=$((16#${hex:2*p+4:4})); (( len >= 2 )) || break\n'
    + '    p=$((p + 2 + len))\n'
    + '  done\n'
    + 'fi\n'
    + '(( w >= 8 && w <= 512 && h >= 8 && h <= 512 )) || { echo fail; exit 0; }\n'
    + 'chmod 600 -- "$tmp" && mv -f -T -- "$tmp" "$f" || { echo fail; exit 0; }\n'
    + 'trap - EXIT\n'
    + 'echo "ok $key"\n'

// The image source of a cached photo: the cache folder and a name the
// script returned, checked again; "" for anything else
function source(cacheDir, word) {
    if (typeof cacheDir !== "string" || !/^\/[A-Za-z0-9._\/-]{1,250}$/.test(cacheDir) || cacheDir.includes(".."))
        return ""
    const m = typeof word === "string" ? /^(?:ok|cached) ([0-9a-f]{64})$/.exec(word.trim()) : null
    return m === null ? "" : "file://" + cacheDir + "/" + m[1]
}
