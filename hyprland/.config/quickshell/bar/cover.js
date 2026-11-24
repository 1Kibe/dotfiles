.pragma library

// The copy of a track's cover that state/MediaState keeps for its color
// (ColorQuantizer only reads local files). Plain JS: read by the shell and
// by the tests, which run the same script with a fake curl.
//
// The address comes from any MPRIS player: only https, followed through at
// most 3 redirects, each one https too, no globbing, the address given to curl by its input
// (-K -), never as an argument (so a third party's address never reaches
// the process list or the log). The body is cut at 5 MiB in the pipe (not
// only by --max-filesize) and must start as a PNG or a JPEG before it
// replaces the copy, in one rename. $1: the copy's path. Exit 0: done.

var MAX = 5242880

// An address curl can take between quotes in its configuration: https,
// no space, quote, backslash or control character, no { } [ ] (curl's
// globbing, also off by -g), 2048 at most
function validUrl(url) {
    return typeof url === "string" && url.length <= 2048 && /^https:\/\/[^\s"\\{}\[\]\u0000-\u001f\u007f]+$/.test(url)
}

// The line curl reads from its input
function config(url) {
    return validUrl(url) ? "url = \"" + url + "\"\n" : ""
}

var SCRIPT = 'set -u\n'
    + 'umask 077\n'
    + 't=$1\n'
    + 'command -v curl >/dev/null 2>&1 || exit 90\n'
    + 'exec 2>/dev/null\n'
    + 'mkdir -p -- "$(dirname -- "$t")" || exit 1\n'
    + 'tmp=$t.new\n'
    + 'rm -f -- "$tmp" || exit 1\n'
    + 'trap \'rm -f -- "$tmp"\' EXIT\n'
    + 'env -u CURL_HOME -u CURL_CA_BUNDLE -u SSL_CERT_FILE -u SSL_CERT_DIR LC_ALL=C curl -q -K - -fsSLg --max-time 10 --max-filesize ' + MAX + ' \\\n'
    + '  --max-redirs 3 --proto =https --proto-redir =https -o - | head -c ' + (MAX + 1) + ' > "$tmp"\n'
    + '[ "${PIPESTATUS[0]}" = 0 ] || exit 1\n'
    + 's=$(stat -c %s -- "$tmp") || exit 1\n'
    + '(( s > 0 && s <= ' + MAX + ' )) || exit 1\n'
    + 'm=$(od -An -tx1 -N8 -- "$tmp" | tr -d " \\n")\n'
    + 'case "$m" in 89504e470d0a1a0a*|ffd8ff*) ;; *) exit 1;; esac\n'
    + 'mv -f -T -- "$tmp" "$t" || exit 1\n'
    + 'trap - EXIT\n'
