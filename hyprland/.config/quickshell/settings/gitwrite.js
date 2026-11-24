.pragma library
.import "gitaccounts.js" as Git

// Writing the code accounts' git files (state/SettingsApply): the fixed
// script and what it reads on its standard input. Plain JS: read by the
// shell and by the tests, which run the same script.
//
// Input: one line per file, "<mode> <name> <base64 text> [<key>]". mode w:
// write it; e: write it only if it is already there (a profile removed:
// its file goes back to the header, never deleted). name: contas.conf or
// contas/p1.conf … p8.conf, nothing else. key: the profile's SSH key, a
// file name in ~/.ssh, checked before its file is written. The texts go
// by the input, never by the arguments, so no name or e-mail shows in
// the process list.
//
// The script: umask 077; ~/.config/git and its contas/ must be real
// folders of the user (made 700 when missing, and only once there is
// something to write), never a link and never inside the clone of this
// repo ($2, the shell's folder of the repo); a
// file there that is a link, not a plain file or not the user's is never
// touched. Each text goes to <file>.new next to it, git must read it
// (git config --file … --list) with only the expected keys, and it
// replaces the file in one rename, mode 600, only when it changed. A
// failure keeps the old file. It prints only "ok" or "fail".

var SCRIPT = 'set -u\n'
    + 'umask 077\n'
    + 'd=$1; q=$2\n'
    + 'r=$(readlink -f -- "$q/../../..") || { echo fail; exit 1; }\n'
    + 'ready=0\n'
    // The folders, checked (and made, 700) only before the first write
    + 'prepare() {\n'
    + '  [ "$ready" = 1 ] && return 0\n'
    + '  [ -d "$(dirname -- "$d")" ] || return 1\n'
    + '  for x in "$d" "$d/contas"; do\n'
    // Inside the clone is refused before anything is made there
    + '    t=$(readlink -m -- "$x") || return 1\n'
    + '    case "$t/" in "$r"/*) return 1;; esac\n'
    + '    if [ ! -e "$x" ] && [ ! -L "$x" ]; then install -d -m 700 -- "$x" 2>/dev/null || return 1; fi\n'
    + '    [ -d "$x" ] && [ ! -L "$x" ] && [ -O "$x" ] || return 1\n'
    + '    t=$(readlink -f -- "$x") || return 1\n'
    + '    case "$t/" in "$r"/*) return 1;; esac\n'
    + '    chmod 700 -- "$x" || return 1\n'
    + '  done\n'
    + '  ready=1\n'
    + '}\n'
    + 'status=ok\n'
    + 'while IFS=" " read -r mode name data key rest; do\n'
    + '  case "$mode" in w|e) ;; *) status=fail; continue;; esac\n'
    + '  case "$name" in contas.conf|contas/p[1-8].conf) ;; *) status=fail; continue;; esac\n'
    + '  [ -z "${rest:-}" ] || { status=fail; continue; }\n'
    + '  f=$d/$name; tmp=$f.new\n'
    + '  if [ "$mode" = e ] && [ ! -e "$f" ] && [ ! -L "$f" ]; then continue; fi\n'
    + '  prepare || { echo fail; exit 1; }\n'
    + '  if [ -L "$f" ] || { [ -e "$f" ] && { [ ! -f "$f" ] || [ ! -O "$f" ]; }; }; then status=fail; continue; fi\n'
    + '  if [ -n "${key:-}" ]; then\n'
    + '    case "$key" in *[!A-Za-z0-9._@+-]*|.*|-*) status=fail; continue;; esac\n'
    + '    k=$HOME/.ssh/$key\n'
    + '    if [ -L "$k" ] || [ ! -f "$k" ] || [ ! -O "$k" ] || [ -n "$(find "$k" -maxdepth 0 -perm /077 2>/dev/null)" ]; then status=fail; continue; fi\n'
    + '  fi\n'
    + '  if [ -L "$tmp" ] || [ -e "$tmp" ]; then rm -f -- "$tmp" || { status=fail; continue; }; fi\n'
    + '  printf "%s" "$data" | base64 -d 2>/dev/null | { set -C; cat > "$tmp"; } 2>/dev/null || { rm -f -- "$tmp"; status=fail; continue; }\n'
    + '  names=$(git config --file "$tmp" --list --name-only 2>/dev/null) || { rm -f -- "$tmp"; status=fail; continue; }\n'
    + '  if [ "$name" = contas.conf ]; then\n'
    + '    allow="^(includeif\\.gitdir:~/[A-Za-z0-9._@+/-]+/\\.path|credential\\.https://(github|gitlab)\\.com\\.helper)$"\n'
    + '  else\n'
    + '    allow="^(user\\.name|user\\.email|core\\.sshcommand)$"\n'
    + '  fi\n'
    + '  if [ -n "$names" ] && printf "%s\\n" "$names" | grep -qvE "$allow"; then rm -f -- "$tmp"; status=fail; continue; fi\n'
    // The values that run or point somewhere: exactly what the shell writes
    + '  if [ "$name" = contas.conf ]; then\n'
    + '    bad=$(git config --file "$tmp" --get-regexp "^includeif\\." 2>/dev/null | grep -cvE "^includeif\\.gitdir:[^ ]+\\.path contas/p[1-8]\\.conf$")\n'
    + '    [ "$bad" = 0 ] || { rm -f -- "$tmp"; status=fail; continue; }\n'
    + '  else\n'
    + '    v=$(git config --file "$tmp" --get core.sshcommand 2>/dev/null)\n'
    + '    if [ -n "${key:-}" ]; then want="ssh -i $HOME/.ssh/$key -o IdentitiesOnly=yes"; else want=""; fi\n'
    + '    [ "$v" = "$want" ] || { rm -f -- "$tmp"; status=fail; continue; }\n'
    + '  fi\n'
    + '  if [ -f "$f" ] && cmp -s -- "$tmp" "$f"; then rm -f -- "$tmp"; chmod 600 -- "$f" || status=fail; continue; fi\n'
    + '  chmod 600 -- "$tmp" && mv -f -T -- "$tmp" "$f" || { rm -f -- "$tmp"; status=fail; }\n'
    + 'done\n'
    + 'echo "$status"\n'

// UTF-8 then base64, without Qt or node (the same in the shell and the tests)
var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function base64(text) {
    const bytes = []
    for (const ch of text) {
        const c = ch.codePointAt(0)
        if (c < 0x80)
            bytes.push(c)
        else if (c < 0x800)
            bytes.push(0xc0 | c >> 6, 0x80 | c & 63)
        else if (c < 0x10000)
            bytes.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63)
        else
            bytes.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63)
    }
    let out = ""
    for (let i = 0; i < bytes.length; i += 3) {
        const n = bytes[i] << 16 | (bytes[i + 1] || 0) << 8 | (bytes[i + 2] || 0)
        out += B64[n >> 18 & 63] + B64[n >> 12 & 63] + (i + 1 < bytes.length ? B64[n >> 6 & 63] : "=") + (i + 2 < bytes.length ? B64[n & 63] : "=")
    }
    return out
}

// The script's input for these lists (as SettingsStore keeps them, already
// checked): every profile's file, the header for the ids not in use (only
// where such a file is there), and contas.conf with one includeIf per
// folder whose profile is still there. contas.conf is made only once there
// is something in it or it is there already. Throws (fixed message) when
// a list does not pass
function input(profiles, folders, home) {
    if (!Array.isArray(profiles) || !Array.isArray(folders))
        throw new Error("invalid code accounts")
    const ids = profiles.map(p => p && p.id)
    const live = folders.filter(f => f && ids.includes(f.profile))
    const some = profiles.length > 0 || folders.length > 0
    let text = (some ? "w" : "e") + " contas.conf " + base64(Git.contasConf(profiles, live, home)) + "\n"
    for (let i = 1; i <= Git.PROFILE_MAX; i++) {
        const p = profiles.find(x => x.id === "p" + i)
        if (p)
            text += "w contas/p" + i + ".conf " + base64(Git.profileConf(p, home)) + " " + p.key + "\n"
        else
            text += "e contas/p" + i + ".conf " + base64(Git.emptyConf()) + "\n"
    }
    return text
}
