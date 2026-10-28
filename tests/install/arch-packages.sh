#!/usr/bin/env bash
# Runs as root in an Arch container: every name in packages/arch.txt must exist
# (repo packages through pacman, aur: ones through the AUR RPC or the repos).
set -uo pipefail
. /tests/lib.sh
pacman -Sy --noconfirm --needed curl >/dev/null
cd /src
source ./install.sh
set +e
mapfile -t all < <(read_packages packages/arch.txt common xfce hyprland)
repo=(); aur=()
for p in "${all[@]}"; do
  if [[ "$p" == aur:* ]]; then aur+=("${p#aur:}"); else repo+=("$p"); fi
done
echo "repo: ${#repo[@]}  aur: ${#aur[@]}"
t "all ${#repo[@]} repo packages resolve in pacman" pacman -Sp --print-format '%n' "${repo[@]}"
pacman -Sp --print-format '%n' "${repo[@]}" 2>&1 | grep -i "error" || true
for p in "${aur[@]}"; do
  if pacman -Si "$p" >/dev/null 2>&1; then
    ok "aur:$p (in official repos, paru installs it too)"
  else
    n=$(curl -fsS "https://aur.archlinux.org/rpc/v5/info?arg[]=$p" | grep -o '"resultcount":[0-9]*' | cut -d: -f2)
    t "aur:$p exists in the AUR" test "${n:-0}" -ge 1
  fi
done
summary arch-packages
