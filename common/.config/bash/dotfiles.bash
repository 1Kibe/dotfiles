# Bash settings of the dotfiles, loaded by ~/.bashrc (install.sh adds the
# line). Interactive shells only.
[[ $- == *i* ]] || return 0

# The Starship prompt (~/.config/starship.toml). Not on the text console
# (TERM=linux): it has no Nerd Font, so the default prompt stays there.
if command -v starship >/dev/null 2>&1 && [[ "${TERM:-}" != linux ]]; then
  eval "$(starship init bash)"
fi

# lazygit with the repo's config and, when the shell has written it, the
# theme's colors over it (tema.yml). The list is made at each start: a file
# in LG_CONFIG_FILE that is not there stops lazygit from opening.
lazygit() {
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit"
  local files="$dir/config.yml"
  [[ -f "$dir/tema.yml" ]] && files="$files,$dir/tema.yml"
  if [[ -f "$dir/config.yml" ]]; then
    LG_CONFIG_FILE="$files" command lazygit "$@"
  else
    command lazygit "$@"
  fi
}
