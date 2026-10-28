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

# clone at the new layout into $HOME/$1 (default: dotfiles)
clone_new() {
  DOTFILES="$HOME/${1:-dotfiles}"
  mkdir -p "$(dirname "$DOTFILES")"
  git clone -q /src "$DOTFILES"
  cd "$DOTFILES" || exit 1
  git checkout -q -B main "${NEW_REF}"
  overlay
}

# use the install.sh of $WT (same as the commit in CI)
overlay() {
  local dir="${DOTFILES:-$HOME/dotfiles}"
  cp "${WT}/install.sh" "$dir/install.sh"
  git -C "$dir" commit -qam "test: install.sh atual" >/dev/null || true
}
