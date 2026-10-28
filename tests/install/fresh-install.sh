#!/usr/bin/env bash
# Fresh machine (no ~/.config) running the full "install" command.
# $1 = expected distro. On Arch sudo/paru are fakes that only log (no 1 GB
# download); on Ubuntu/Fedora sudo is real and the package manager runs.
set -uo pipefail
. /tests/lib.sh
git_setup
want="$1"
dir="${2:-dotfiles}"   # clone folder, relative to $HOME
rm -rf ~/.config

clone_new "$dir"
echo "    repo cloned at ~/$dir"

if [[ "$want" == "arch" ]]; then
  mkdir -p ~/fakebin
  printf '#!/bin/sh\necho "$*" >> ~/sudo.log\n' > ~/fakebin/sudo
  printf '#!/bin/sh\necho "paru $*" >> ~/sudo.log\n' > ~/fakebin/paru
  chmod +x ~/fakebin/*
  export PATH=~/fakebin:$PATH
fi

# answers: sshd? n / optional deps (arch only): 0
printf 'n\n0\n' | ./install.sh install xfce 2>&1 | strip > /tmp/install.log
rc=${PIPESTATUS[1]}
sed 's/^/    | /' /tmp/install.log
t "install exits 0" test "$rc" -eq 0
t "distro detected as $want" grep -q "Distro: ${want}" /tmp/install.log
t "reached the summary" grep -q "Installation complete" /tmp/install.log
t "~/.config created as a real dir" bash -c '[[ -d ~/.config && ! -L ~/.config ]]'
t "stow available" command -v stow
for n in nvim alacritty rofi wallpapers xfce4 i3 Thunar gtk-3.0 user-dirs.dirs; do
  t "~/.config/$n linked" bash -c "[[ -L ~/.config/$n && -e ~/.config/$n ]]"
done
t "links resolve into ~/$dir" bash -c "[[ \$(readlink -f ~/.config/nvim) == $HOME/$dir/common/.config/nvim && \$(readlink -f ~/.config/xfce4) == $HOME/$dir/xfce/.config/xfce4 ]]"
t "links are relative" bash -c "[[ \$(readlink ~/.config/nvim) == ../$dir/common/.config/nvim ]]"
t "wallpaper of xfce4-desktop.xml exists" bash -c 'f=$(grep -oP "(?<=name=\"last-image\" type=\"string\" value=\")[^\"]*" ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml); f=${f//\$\{HOME\}/$HOME}; test -f "$f"'
t "sshd skipped" grep -q "Skipping ssh" /tmp/install.log

if [[ "$want" == "arch" ]]; then
  echo "    sudo/paru calls:"; sed 's/^/    > /' ~/sudo.log
  t "pacman got common+xfce packages" bash -c 'grep -q "^pacman -S --needed --noconfirm git .*stow.* i3-wm .*xclip$" ~/sudo.log'
  t "pacman list has 38 packages" bash -c '[[ $(grep "^pacman -S --needed --noconfirm git" ~/sudo.log | wc -w) -eq $((4 + 38)) ]]'
  t "paru got the 3 AUR packages" grep -q "^paru -S --needed --noconfirm tailscale obexftp xss-lock$" ~/sudo.log
  t "services enabled" bash -c 'grep -q "systemctl enable --now NetworkManager" ~/sudo.log && grep -q "systemctl enable --now bluetooth" ~/sudo.log'
  t "sshd not enabled" bash -c '! grep -q "enable sshd" ~/sudo.log'
else
  t "empty package list is reported" grep -q "still a TODO" /tmp/install.log
  t "AUR not attempted" bash -c '! grep -qi "paru\|AUR helper" /tmp/install.log'
fi

summary "fresh-install-$want"
