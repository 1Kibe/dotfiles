#!/usr/bin/env bash
# Machine that used the OLD layout, then pulls the new one and runs link.
set -uo pipefail
. /tests/lib.sh
git_setup

echo "### 1. machine on the old layout"
git clone -q /src ~/dotfiles
cd ~/dotfiles
git checkout -q -B main 611808f
# what the old install.sh did: symlink loop + wallpaper copy + git filter
mkdir -p ~/.config
for entry in ~/dotfiles/.config/*; do ln -sfn "$entry" ~/.config/"$(basename "$entry")"; done
mkdir -p ~/.config/wallpapers && cp -r ~/dotfiles/wallpapers/* ~/.config/wallpapers/
git config filter.xfce-panel.clean "awk -f tools/xfce-panel-clean.awk"
# files apps wrote through the old links (untracked in the repo)
mkdir -p ~/.config/xfce4/panel/launcher-1
echo '[Desktop Entry]' > ~/.config/xfce4/panel/launcher-1/term.desktop
echo '<channel name="xfce4-terminal"/>' > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml
echo 'gtk-theme-name=x' > ~/.config/gtk-3.0/settings.ini
# the user's own stuff, not from this repo
mkdir -p ~/.config/discord ~/.config/hypr
echo keep > ~/.config/discord/settings.json
echo 'monitor=,preferred,auto,1' > ~/.config/hypr/hyprland.conf
t "old: ~/.config/nvim is absolute link into repo" bash -c '[[ $(readlink ~/.config/nvim) == /home/*/dotfiles/.config/nvim ]]'
t "old: untracked xfce file landed in repo/.config" test -f ~/dotfiles/.config/xfce4/panel/launcher-1/term.desktop

echo "### 2. git pull (fast-forward to the new layout)"
git fetch -q origin
t "pull fast-forwards" git merge -q --ff-only "${NEW_REF}"
overlay
t "after pull: nvim link is broken" bash -c '[[ -L ~/.config/nvim && ! -e ~/.config/nvim ]]'
t "after pull: leftovers still in repo/.config" test -f ~/dotfiles/.config/xfce4/panel/launcher-1/term.desktop

echo "### 3. ./install.sh link xfce hyprland"
./install.sh link xfce hyprland 2>&1 | strip > /tmp/link1.log
rc=${PIPESTATUS[0]}
sed 's/^/    | /' /tmp/link1.log
t "link exits 0" test "$rc" -eq 0
for n in nvim alacritty rofi wallpapers; do
  t "~/.config/$n -> common" bash -c "[[ \$(readlink -f ~/.config/$n) == $HOME/dotfiles/common/.config/$n ]]"
done
for n in xfce4 i3 Thunar gtk-3.0 pavucontrol.ini user-dirs.dirs user-dirs.locale; do
  t "~/.config/$n -> xfce" bash -c "[[ \$(readlink -f ~/.config/$n) == $HOME/dotfiles/xfce/.config/$n ]]"
done
t "links are relative (made by stow)" bash -c '[[ $(readlink ~/.config/nvim) == ../dotfiles/common/.config/nvim ]]'
t "~/.config itself is a real dir" bash -c '[[ -d ~/.config && ! -L ~/.config ]]'
t "old .config/ removed from repo" test ! -e ~/dotfiles/.config
t "panel launcher moved to xfce package" test -f ~/dotfiles/xfce/.config/xfce4/panel/launcher-1/term.desktop
t "panel launcher visible in ~/.config" test -f ~/.config/xfce4/panel/launcher-1/term.desktop
t "terminal channel visible in ~/.config" test -f ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml
t "gtk settings.ini visible in ~/.config" test -f ~/.config/gtk-3.0/settings.ini
t "copied wallpapers moved to wallpapers.bak" test -d ~/.config/wallpapers.bak
t "wallpaper of xfce4-desktop.xml exists" bash -c 'f=$(grep -oP "(?<=name=\"last-image\" type=\"string\" value=\")[^\"]*" ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml); f=${f//\$\{HOME\}/$HOME}; test -f "$f"'
t "no wallpaper warning in output" bash -c '! grep -q "Wallpaper file not found" /tmp/link1.log'
t "hyprland skipped (empty)" grep -q "Skipping hyprland" /tmp/link1.log
t "user's own ~/.config/hypr untouched" bash -c '[[ ! -L ~/.config/hypr && -f ~/.config/hypr/hyprland.conf && ! -e ~/.config/hypr.bak ]]'
t "unrelated ~/.config/discord untouched" test -f ~/.config/discord/settings.json
t "nvim init.lua reachable" test -f ~/.config/nvim/init.lua
t "README/LICENSE/packages not linked into HOME" bash -c '[[ ! -e ~/README.md && ! -e ~/LICENSE && ! -e ~/packages && ! -e ~/.gitkeep ]]'
t "repo: only the moved leftovers are untracked" bash -c 'cd ~/dotfiles && [[ -z $(git status --porcelain | grep -v -e "^?? xfce/.config/xfce4/panel/" -e "^?? xfce/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml" -e "^?? xfce/.config/gtk-3.0/settings.ini") ]]'
t "git filter configured" bash -c '[[ $(git -C ~/dotfiles config filter.xfce-panel.clean) == "awk -f tools/xfce-panel-clean.awk" ]]'

echo "### 4. link again (idempotent)"
./install.sh link xfce 2>&1 | strip > /tmp/link2.log
rc=${PIPESTATUS[0]}
t "second link exits 0" test "$rc" -eq 0
t "second link moved nothing to .bak" bash -c '! grep -q "Moved existing" /tmp/link2.log'
t "only wallpapers.bak exists" bash -c '[[ $(ls -d ~/.config/*.bak* | wc -l) -eq 1 ]]'

echo "### 5. XFCE writes a Wi-Fi name into the panel file"
panel=~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
sed -i --follow-symlinks 's#</channel>#  <property name="plugins" type="empty">\n    <property name="known-legacy-items" type="array">\n      <value type="string" value="MinhaRedeWifi"/>\n    </property>\n  </property>\n</channel>#' "$panel"
t "SSID is in the repo file" grep -q MinhaRedeWifi ~/dotfiles/xfce/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
git -C ~/dotfiles add xfce/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
t "SSID not staged (clean filter)" bash -c '! git -C ~/dotfiles diff --cached | grep -q MinhaRedeWifi'
t "panel file shows no staged change" bash -c '[[ -z $(git -C ~/dotfiles diff --cached --name-only) ]]'
git -C ~/dotfiles reset -q

echo "### 6. unlink xfce"
./install.sh unlink xfce 2>&1 | strip > /tmp/unlink.log
rc=${PIPESTATUS[0]}
t "unlink exits 0" test "$rc" -eq 0
t "xfce links removed" bash -c '[[ ! -e ~/.config/xfce4 && ! -L ~/.config/xfce4 && ! -L ~/.config/i3 && ! -L ~/.config/user-dirs.dirs ]]'
t "common links kept" test -L ~/.config/nvim

echo "### 7. link with the menu (Enter, Enter = defaults)"
printf '\n\n' | ./install.sh link 2>&1 | strip > /tmp/link3.log
rc=${PIPESTATUS[1]}
t "menu link exits 0" test "$rc" -eq 0
t "default menu links xfce again" test -L ~/.config/xfce4
t "default menu skips hyprland silently" bash -c '! grep -q "Skipping hyprland" /tmp/link3.log'

echo "### 8. unlink everything"
./install.sh unlink 2>&1 | strip > /tmp/unlink2.log
t "no links into the repo left in ~/.config" bash -c '[[ -z $(find ~/.config -maxdepth 1 -type l) ]]'
t "user's hypr and discord still there" bash -c '[[ -f ~/.config/hypr/hyprland.conf && -f ~/.config/discord/settings.json ]]'

summary arch-migrate
