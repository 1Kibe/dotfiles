# shared helpers for the container tests
P=0; F=0
ok() { echo "PASS  $*"; P=$((P + 1)); }
ko() { echo "FAIL  $*"; F=$((F + 1)); }
t() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }
strip() { sed 's/\x1b\[[0-9;]*m//g'; }
summary() { echo "=== $1: ${P} passed, ${F} failed"; [[ $F -eq 0 ]]; }

# /src = repo checkout (read-only); NEW_REF = commit under test
NEW_REF="${NEW_REF:?NEW_REF not set}"
WT="${WT:-/src}"

git_setup() {
  git config --global --add safe.directory '*'
  git config --global user.email test@example.com
  git config --global user.name test
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
}

# clone at the new layout, with the current (maybe uncommitted) install.sh
clone_new() {
  git clone -q /src ~/dotfiles
  cd ~/dotfiles || exit 1
  git checkout -q -B main "${NEW_REF}"
  overlay
}

overlay() {
  cp "${WT}/install.sh" ~/dotfiles/install.sh
  git -C ~/dotfiles commit -qam "test: install.sh atual" || true
}
