.pragma library
.import "gitaccounts.js" as Git
.import "gitwrite.js" as GitWrite

// The cards of Configurações → Contas de código (settings/cards/Code*.qml):
// the edits of the two lists, the menus and the fixed scripts the cards
// run. Plain JS: read by the shell and by the tests. Every change comes
// back as the list's new JSON text (SettingsStore.set checks it again) or
// as a fixed phrase; no account, e-mail or path in a message.

var ERR = {
    label: "Dê um nome ao perfil, de até 40 letras",
    name: "O nome no commit precisa de até 100 letras, sem < nem >",
    email: "E-mail inválido",
    key: "Escolha uma chave SSH de ~/.ssh",
    gh: "Escolha uma conta da lista",
    full: "No máximo 8 perfis",
    folder: "Use uma pasta dentro da sua pasta pessoal, fora de ~/.ssh, ~/.config e ~/.gnupg, só com letras, números e . _ - @ +",
    taken: "Essa pasta já está na lista",
    folders: "No máximo 32 pastas",
    profile: "Escolha um perfil",
    store: "Não deu para guardar"
}

function list(text) {
    try {
        const l = JSON.parse(text)
        return Array.isArray(l) ? l : []
    } catch (e) {
        return []
    }
}

// The first id not in use, "" when the 8 are
function freeId(profiles) {
    for (let i = 1; i <= Git.PROFILE_MAX; i++) {
        if (!profiles.some(p => p.id === "p" + i))
            return "p" + i
    }
    return ""
}

function fail(error) {
    return { ok: false, error: error, text: "" }
}

function done(items) {
    return { ok: true, error: "", text: JSON.stringify(items) }
}

function clean(s) {
    return typeof s === "string" ? s.trim() : ""
}

// The editor's draft ({ id ("" for a new one), label, name, email, key,
// ghAccount }) into the list: the first field that does not pass says so
function saveProfile(profiles, draft) {
    const p = { id: clean(draft.id), label: clean(draft.label), name: clean(draft.name), email: clean(draft.email),
                key: clean(draft.key), ghAccount: clean(draft.ghAccount) }
    if (p.id === "") {
        p.id = freeId(profiles)
        if (p.id === "")
            return fail(ERR.full)
    } else if (!profiles.some(x => x.id === p.id)) {
        return fail(ERR.store)
    }
    if (!Git.validText(p.label, Git.LABEL_MAX))
        return fail(ERR.label)
    if (!Git.validText(p.name, Git.NAME_MAX) || Git.IDENT_NOT.test(p.name))
        return fail(ERR.name)
    if (!Git.validEmail(p.email))
        return fail(ERR.email)
    if (!Git.validKey(p.key))
        return fail(ERR.key)
    if (!Git.validGhAccount(p.ghAccount))
        return fail(ERR.gh)
    const next = profiles.some(x => x.id === p.id) ? profiles.map(x => x.id === p.id ? p : x) : profiles.concat([p])
    return Git.profilesText(JSON.stringify(next)) === null ? fail(ERR.store) : done(next)
}

// A profile goes; its folders stay in the list, with no includeIf, until
// they get another one
function removeProfile(profiles, id) {
    return done(profiles.filter(p => p.id !== id))
}

function addFolder(folders, profiles, typed, profileId, home) {
    if (folders.length >= Git.FOLDER_MAX)
        return fail(ERR.folders)
    const path = Git.normalFolder(clean(typed), home)
    if (path === "")
        return fail(ERR.folder)
    if (folders.some(f => f.path === path))
        return fail(ERR.taken)
    if (!profiles.some(p => p.id === profileId))
        return fail(ERR.profile)
    return done(folders.concat([{ path: path, profile: profileId }]))
}

function setFolderProfile(folders, profiles, path, profileId) {
    if (!profiles.some(p => p.id === profileId))
        return fail(ERR.profile)
    return done(folders.map(f => f.path === path ? { path: f.path, profile: profileId } : f))
}

function removeFolder(folders, path) {
    return done(folders.filter(f => f.path !== path))
}

// The profile's letter when there is no photo
function initial(label) {
    const s = clean(label)
    if (s === "")
        return "?"
    const c = s.charCodeAt(0)
    return (c >= 0xd800 && c <= 0xdbff ? s.slice(0, 2) : s.charAt(0)).toUpperCase()
}

function ghLogin(p) {
    return p && typeof p.ghAccount === "string" && p.ghAccount.startsWith("github.com|") ? p.ghAccount.slice(11) : ""
}

function githubUsers(hosts) {
    const e = Array.isArray(hosts) ? hosts.find(h => h.host === "github.com") : null
    return e ? e.users.map(u => u.login) : []
}

// The profile's account is one gh read in this opening
function accountRead(p, hosts) {
    const l = ghLogin(p)
    return l !== "" && githubUsers(hosts).includes(l)
}

// Under the profile's name: its account (or why there is none), then its key
function accountText(p, hosts, index, hidden) {
    const l = ghLogin(p)
    if (l === "")
        return "sem conta do GitHub"
    if (!accountRead(p, hosts))
        return "conta não encontrada"
    return hidden ? `conta ${index + 1}` : l
}

// The menu of Conta do GitHub: none, then the accounts of this reading (a
// stored one that is not among them shows as not found and gets no photo)
function ghOptions(hosts, current) {
    const out = [{ value: "", label: "Nenhuma" }]
    for (const l of githubUsers(hosts))
        out.push({ value: "github.com|" + l, label: l })
    if (typeof current === "string" && current !== "" && !out.some(o => o.value === current))
        out.push({ value: current, label: "conta não encontrada" })
    return out
}

// The menu of Chave SSH: the names the listing gave that pass, and the
// stored one if it is gone
function keyOptions(names, current) {
    const seen = {}
    const out = []
    for (const n of names.slice().sort()) {
        if (Git.validKey(n) && !seen[n]) {
            seen[n] = true
            out.push({ value: n, label: n })
        }
    }
    if (typeof current === "string" && current !== "" && !seen[current])
        out.push({ value: current, label: current + " · não encontrada" })
    return out
}

function profileOptions(profiles) {
    return profiles.map(p => ({ value: p.id, label: p.label }))
}

// ── The fixed scripts (bash -c, nothing of an account in the arguments) ──

// The names of ~/.ssh that can be a profile's key: plain files of the
// user, 600 or narrower, never a link nor ~/.ssh as a link; only names
// (nothing is opened), at most 64. The names are checked again in JS
var KEYS_SCRIPT = 'exec 2>/dev/null\n'
    + 's=$HOME/.ssh\n'
    + '[ -d "$s" ] && [ ! -L "$s" ] && [ -O "$s" ] || exit 0\n'
    + 'find "$s" -mindepth 1 -maxdepth 1 -type f -user "$(id -u)" ! -perm /077 ! -name "*.pub" -printf "%f\\n" | head -n 64\n'

function keyNames(text) {
    return typeof text === "string" ? text.split("\n").filter(n => Git.validKey(n)) : []
}

// The state of the folders. Input: GitWrite.input's lines (what the files
// should hold), then "d <n> <~/folder>" per folder. Output, fixed words
// only: "f <file> same|diff" per file to write, "d <n> 1|0" (the folder is
// there), "i 1|0" (~/.ssh/config names an IdentityFile: ssh may also offer
// that key, which the profile's command cannot take away)
var STATE_SCRIPT = 'set -u\n'
    + 'exec 2>/dev/null\n'
    + 'd=$1\n'
    + 'while IFS=" " read -r mode name data rest; do\n'
    + '  case "$mode" in\n'
    + '  w)\n'
    + '    case "$name" in contas.conf|contas/p[1-8].conf) ;; *) continue;; esac\n'
    + '    f=$d/$name\n'
    + '    if [ -f "$f" ] && [ ! -L "$f" ] && cmp -s -- <(printf "%s" "$data" | base64 -d) "$f"; then echo "f $name same"; else echo "f $name diff"; fi;;\n'
    + '  d)\n'
    + '    [[ $name =~ ^[0-9]{1,2}$ ]] || continue\n'
    + '    [[ $data =~ ^~/[A-Za-z0-9._@+/-]+$ ]] || { echo "d $name 0"; continue; }\n'
    + '    p=$HOME/${data#\\~/}\n'
    + '    if [ -d "$p" ]; then echo "d $name 1"; else echo "d $name 0"; fi;;\n'
    + '  esac\n'
    + 'done\n'
    + 'c=$HOME/.ssh/config\n'
    + 'if [ -f "$c" ] && grep -qiE "^[[:space:]]*identityfile([[:space:]]|=)" -- "$c"; then echo "i 1"; else echo "i 0"; fi\n'

function stateInput(writeInput, folders) {
    let text = writeInput
    folders.forEach((f, i) => { text += `d ${i} ${f.path}\n` })
    return text
}

// { files: { name: true|false }, dirs: [bool], idFile: bool }
function parseState(text) {
    const out = { files: {}, dirs: [], idFile: false }
    for (const line of (typeof text === "string" ? text : "").split("\n")) {
        let m = /^f (contas\.conf|contas\/p[1-8]\.conf) (same|diff)$/.exec(line)
        if (m) {
            out.files[m[1]] = m[2] === "same"
            continue
        }
        m = /^d ([0-9]{1,2}) ([01])$/.exec(line)
        if (m) {
            out.dirs[Number(m[1])] = m[2] === "1"
            continue
        }
        if (line === "i 1")
            out.idFile = true
    }
    return out
}

// A folder's line in Estado
function folderState(folder, index, state, profiles) {
    if (state.dirs[index] === undefined)
        return ""
    if (!state.dirs[index])
        return "a pasta não existe"
    if (!profiles.some(p => p.id === folder.profile))
        return "sem perfil: vale a conta ativa"
    const upToDate = state.files["contas.conf"] === true && state.files[`contas/${folder.profile}.conf`] === true
    return upToDate ? "em dia" : "o arquivo do git não está em dia"
}

// Conferir. Input: "<n> <~/folder> <e-mail in base64>" per folder; $1:
// the shell's folder of the repo. For each: the folder must be a real one;
// the repo is the folder itself or the first one found up to 3 levels down,
// and its git folder must be inside the folder (a worktree whose repo is
// elsewhere does not get the profile: nothing to check there). With no
// repo at all (git only weighs an includeIf inside a real repo), a
// temporary one is made right in the folder and removed at once: only in
// a real folder of the user, writable and outside the clone, named
// .conferir.XXXXXX, removed by that exact path (a child of the folder, its
// name checked, not a link), also on the way out; one left behind by a
// run that was killed goes on the next one, by the same check. git then
// says which e-mail it would use there, compared here and never printed.
// No network: only git init and git config. Output: "<n> ok|diferente|
// naoda|falta"
var CHECK_SCRIPT = 'set -u\n'
    + 'exec 2>/dev/null\n'
    + 'unset GIT_DIR GIT_WORK_TREE GIT_CONFIG GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CEILING_DIRECTORIES GIT_TEMPLATE_DIR\n'
    + 'export GIT_OPTIONAL_LOCKS=0 LC_ALL=C\n'
    + 'clone=$(readlink -f -- "$1/../../..") || exit 1\n'
    + 'tmp=""; tmpin=""\n'
    // Only a path made here, a direct child of its folder, never a link
    + 'drop() {\n'
    + '  local t=$1 parent=$2 b=${1##*/}\n'
    + '  [[ $b =~ ^\\.conferir\\.[A-Za-z0-9]{6}$ ]] || return 0\n'
    + '  [ "${t%/*}" = "$parent" ] || return 0\n'
    + '  [ -d "$t" ] && [ ! -L "$t" ] && [ -O "$t" ] || return 0\n'
    + '  rm -rf --one-file-system -- "$t"\n'
    + '}\n'
    + 'trap \'[ -n "$tmp" ] && drop "$tmp" "$tmpin"\' EXIT\n'
    + 'trap \'exit 1\' TERM INT HUP\n'
    + 'while IFS=" " read -r n path mail rest; do\n'
    + '  [[ $n =~ ^[0-9]{1,2}$ ]] || continue\n'
    + '  if ! [[ $path =~ ^~/[A-Za-z0-9._@+/-]+$ ]] || [[ /$path/ == */../* || /$path/ == */./* ]]; then echo "$n falta"; continue; fi\n'
    + '  p=$HOME/${path#\\~/}\n'
    + '  if [ -L "$p" ] || [ ! -d "$p" ]; then echo "$n falta"; continue; fi\n'
    + '  real=$(readlink -f -- "$p") || { echo "$n falta"; continue; }\n'
    + '  want=$(printf "%s" "$mail" | base64 -d) || { echo "$n naoda"; continue; }\n'
    + '  repo=""\n'
    + '  if [ -e "$p/.git" ]; then repo=$p\n'
    + '  else\n'
    + '    g=$(timeout 3 find "$p" -mindepth 2 -maxdepth 4 -name .git ! -path "*/.conferir.*" -print -quit)\n'
    + '    [ -n "$g" ] && repo=${g%/.git}\n'
    + '  fi\n'
    + '  if [ -n "$repo" ]; then\n'
    + '    gd=$(timeout 3 git -C "$repo" rev-parse --absolute-git-dir) || { echo "$n naoda"; continue; }\n'
    + '    gd=$(readlink -f -- "$gd") || { echo "$n naoda"; continue; }\n'
    + '    case "$gd/" in "$real"/*) ;; *) echo "$n naoda"; continue;; esac\n'
    + '    got=$(timeout 3 git -C "$repo" config --get user.email)\n'
    + '  else\n'
    // No repo: the temporary one, only where it is safe to write
    + '    [ -O "$p" ] && [ -w "$p" ] || { echo "$n naoda"; continue; }\n'
    + '    case "$real/" in "$clone"/*) echo "$n naoda"; continue;; esac\n'
    + '    for old in "$p"/.conferir.*; do [ -e "$old" ] && drop "$old" "$p"; done\n'
    + '    tmpin=$p\n'
    + '    tmp=$(mktemp -d -- "$p/.conferir.XXXXXX") || { tmp=""; echo "$n naoda"; continue; }\n'
    + '    if [[ ${tmp##*/} =~ ^\\.conferir\\.[A-Za-z0-9]{6}$ ]] && [ "${tmp%/*}" = "$p" ] && [ ! -L "$tmp" ] \\\n'
    + '        && timeout 3 git init -q --template= -- "$tmp"; then\n'
    + '      got=$(timeout 3 git -C "$tmp" config --get user.email)\n'
    + '    else\n'
    + '      got=""; drop "$tmp" "$p"; tmp=""; echo "$n naoda"; continue\n'
    + '    fi\n'
    + '    drop "$tmp" "$p"; tmp=""\n'
    + '  fi\n'
    + '  if [ -n "$got" ] && [ "$got" = "$want" ]; then echo "$n ok"; else echo "$n diferente"; fi\n'
    + 'done\n'

// One line per folder with a profile of the list (the others have nothing
// to check)
function checkInput(folders, profiles) {
    let text = ""
    folders.forEach((f, i) => {
        const p = profiles.find(x => x.id === f.profile)
        if (p)
            text += `${i} ${f.path} ${GitWrite.base64(p.email)}\n`
    })
    return text
}

function checkWord(w) {
    return w === "ok" ? "ok" : w === "diferente" ? "diferente" : w === "naoda" ? "não dá para conferir aqui"
         : w === "falta" ? "a pasta não existe" : ""
}

// { n: word } from the output
function parseCheck(text) {
    const out = {}
    for (const line of (typeof text === "string" ? text : "").split("\n")) {
        const m = /^([0-9]{1,2}) (ok|diferente|naoda|falta)$/.exec(line)
        if (m)
            out[Number(m[1])] = m[2]
    }
    return out
}
