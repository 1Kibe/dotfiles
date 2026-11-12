# Bash settings of the dotfiles, loaded by ~/.bashrc (install.sh adds the
# line). Interactive shells only.
[[ $- == *i* ]] || return 0

# The Starship prompt (~/.config/starship.toml). Not on the text console
# (TERM=linux): it has no Nerd Font, so the default prompt stays there.
if command -v starship >/dev/null 2>&1 && [[ "${TERM:-}" != linux ]]; then
  eval "$(starship init bash)"
fi
