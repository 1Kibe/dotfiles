#!/usr/bin/env bash
# =============================================================================
# dotfiles – Install Script
# =============================================================================
# Installs the packages for this distro and links the configs into $HOME
# with GNU Stow. Each top-level folder below is a Stow package that mirrors
# $HOME (common/.config/nvim -> ~/.config/nvim):
#
#   common/     always linked (nvim, kitty, rofi, wallpapers)
#   xfce/       XFCE + i3
#   hyprland/   Hyprland + Quickshell (skipped while it has no configs)
#
# system/ holds files that go outside $HOME (copied with sudo, not linked).
#
# Package lists: packages/<distro>.txt (arch, fedora, ubuntu), picked from
# /etc/os-release.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh [-y|--yes] [command] [environment...]
#
# Options:
#   -y, --yes  Answer every question with its default, without prompting
#              (environments: xfce, SSH server: no, optional deps: skip)
#
# Commands:
#   install   Install packages and link configs (default)
#   link      Only link configs with stow (no packages, no services)
#   unlink    Remove the links made by stow
#   backup    Backup current ~/.config to archive
#   restore   Restore from a backup archive
#   list      List available backups
#
# Environments (install / link): xfce hyprland. "common" is always included.
# Without environment arguments the script asks which ones to enable.
# =============================================================================

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${CYAN}[i]${NC} $*"; }
step() { echo -e "${BLUE}[→]${NC} $*"; }

# Asks a question and prints the answer; an empty answer gives the default.
# With --yes (or no input, e.g. < /dev/null) the default is used without
# waiting. The question goes to stderr, so it shows inside $(...).
ask() {
  local question="$1" default="$2" answer=""
  if [[ -n "${ASSUME_YES}" ]]; then
    echo "${question}${default} (--yes)" >&2
  else
    read -r -p "$question" answer || answer=""
  fi
  echo "${answer:-$default}"
}

# ── Directories ──────────────────────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DST="${HOME}/.config"
BACKUPS_DIR="${DOTFILES_DIR}/.backups"
PACKAGES_DIR="${DOTFILES_DIR}/packages"
DM_UNIT_LINK="/etc/systemd/system/display-manager.service"
GREETD_DIR="/etc/greetd"
PAM_DIR="/etc/pam.d"

# System language and keyboard: the console, X11/Wayland (XFCE, cage and the
# login screen read it from localectl) and Hyprland (hypr/modules/input.lua)
SYSTEM_LOCALE="pt_BR.UTF-8"
CONSOLE_KEYMAP="br-abnt2"
XKB_LAYOUT="br"
XKB_MODEL="abnt2"
LOCALE_GEN="/etc/locale.gen"
# Login screen (Quickshell in cage): its files under /etc/greetd, root's,
# copied by this explicit list (repo path → path inside
# ${GREETD_DIR}/quickshell); its state (last user and session) in the
# greeter's own cache folder
GREETER_CACHE="/var/cache/qs-greeter"
GREETER_FILES=(
  "system/greetd/quickshell/shell.qml:shell.qml"
  "system/greetd/quickshell/Greeter.qml:Greeter.qml"
  "system/greetd/quickshell/greeter/GreeterState.qml:greeter/GreeterState.qml"
  "system/greetd/quickshell/greeter/sessions.js:greeter/sessions.js"
  "hyprland/.config/quickshell/theme/Theme.qml:theme/Theme.qml"
  "hyprland/.config/quickshell/lock/LockBackground.qml:lock/LockBackground.qml"
  "hyprland/.config/quickshell/lock/BigClock.qml:lock/BigClock.qml"
  "hyprland/.config/quickshell/lock/UserCard.qml:lock/UserCard.qml"
  "hyprland/.config/quickshell/lock/PasswordField.qml:lock/PasswordField.qml"
  "hyprland/.config/quickshell/lock/StatusIcons.qml:lock/StatusIcons.qml"
  "hyprland/.config/quickshell/lock/text.js:lock/text.js"
)

# Wallpaper in common/.config/wallpapers (also the default of xfce-wallpaper)
WALLPAPER_FILE="wallpaper-padrao.png"

# Background shared by the lock and login screens; the default picture until
# one is chosen (lock/BackgroundPicker)
SHARED_LOGIN_DIR="/usr/local/share/dotfiles/login"
LOGIN_DEFAULT_FILE="fundo-login-padrao.png"

# Optional environments (Stow packages next to common/), in menu order
ENVS_AVAILABLE=(xfce hyprland)
SELECTED_ENVS=()

# Set by -y / --yes: every question takes its default
ASSUME_YES=""

# Configs this repo no longer has: their ~/.config/<name> links (stow's or
# the old install.sh's) now point at nothing (remove_dropped_links)
DROPPED_CONFIGS=(alacritty)

# Folders shared by several packages. Stow must link what is inside them,
# never the folder itself: a linked ~/.config would put every app's config
# inside the repo. ~/.config/systemd/user holds only drop-ins from the repo,
# but "systemctl --user enable" writes its links there too. systemd ignores a
# drop-in folder that is a link, so the folder is real and only the .conf
# inside is linked (another service's drop-in needs its own entry).
SHARED_DIRS=(.config .config/autostart .config/systemd .config/systemd/user .config/systemd/user/hypridle.service.d .local .local/bin .local/share .local/share/icons .local/share/applications)

# ── Distro ───────────────────────────────────────────────────────────────────
# Maps /etc/os-release to a package list: arch, fedora, ubuntu (or unknown)
detect_distro() {
  local ids=""
  if [[ -r /etc/os-release ]]; then
    ids="$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")"
  fi
  case " ${ids} " in
    *" arch "*)                echo arch ;;
    *" fedora "*)              echo fedora ;;
    *" ubuntu "*|*" debian "*) echo ubuntu ;;
    *)                         echo unknown ;;
  esac
}

# ── Backup helpers ────────────────────────────────────────────────────────────
backup_config() {
  local timestamp backup_file
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_file="${BACKUPS_DIR}/config_${timestamp}.tar.gz"

  mkdir -p "${BACKUPS_DIR}"

  if [[ -d "${CONFIG_DST}" ]]; then
    step "Creating backup: ${backup_file}"
    tar -czf "${backup_file}" -C "$(dirname "${CONFIG_DST}")" "$(basename "${CONFIG_DST}")" 2>/dev/null || true
    log "Backup created: ${backup_file}"
    return 0
  else
    warn "No ~/.config directory found to backup"
    return 1
  fi
}

restore_config() {
  local backup_file="$1"

  if [[ ! -f "${backup_file}" ]]; then
    err "Backup file not found: ${backup_file}"
    return 1
  fi

  step "Restoring from: ${backup_file}"
  tar -xzf "${backup_file}" -C "${HOME}" || {
    err "Failed to restore backup"
    return 1
  }
  log "Configuration restored successfully"
}

list_backups() {
  if [[ -d "${BACKUPS_DIR}" ]]; then
    echo ""
    info "Available backups:"
    ls -lh "${BACKUPS_DIR}"/config_*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
  else
    warn "No backups found"
  fi
}

usage() {
  echo "Usage: $0 [-y|--yes] [command] [environment...]"
  echo ""
  echo "Options:"
  echo "  -y, --yes Answer every question with its default (no prompts)"
  echo ""
  echo "Commands:"
  echo "  install   Install packages and link configs (default)"
  echo "  link      Only link configs with stow (no packages, no services)"
  echo "  unlink    Remove the links made by stow"
  echo "  backup    Backup current ~/.config to archive"
  echo "  restore   Restore from a backup archive"
  echo "  list      List available backups"
  echo ""
  echo "Environments: ${ENVS_AVAILABLE[*]} (common is always included)."
  echo "Without environments, install and link ask which ones to enable."
}

# ── Environments ─────────────────────────────────────────────────────────────
env_label() {
  case "$1" in
    xfce)     echo "XFCE + i3" ;;
    hyprland) echo "Hyprland + Quickshell" ;;
    *)        echo "$1" ;;
  esac
}

# Menu default (and what --yes installs): every environment
env_default() {
  case "$1" in
    xfce|hyprland) echo y ;;
    *)             echo n ;;
  esac
}

is_known_env() {
  local env
  for env in "${ENVS_AVAILABLE[@]}"; do
    if [[ "$env" == "$1" ]]; then return 0; fi
  done
  return 1
}

has_env() {
  local env
  for env in "${SELECTED_ENVS[@]}"; do
    if [[ "$env" == "$1" ]]; then return 0; fi
  done
  return 1
}

# Fills SELECTED_ENVS from the arguments, or asks when there are none
choose_envs() {
  local env answer default
  SELECTED_ENVS=()

  if (( $# )); then
    for env in "$@"; do
      if [[ "$env" == "common" ]]; then continue; fi
      if ! is_known_env "$env"; then
        err "Unknown environment: ${env} (available: ${ENVS_AVAILABLE[*]})"
        exit 1
      fi
      if ! has_env "$env"; then SELECTED_ENVS+=("$env"); fi
    done
    return 0
  fi

  echo ""
  info "Which environments should be enabled? (common is always on)"
  for env in "${ENVS_AVAILABLE[@]}"; do
    default="$(env_default "$env")"
    if [[ "$default" == "y" ]]; then
      answer="$(ask "  ${env} ($(env_label "$env"))? [Y/n]: " y)"
    else
      answer="$(ask "  ${env} ($(env_label "$env"))? [y/N]: " n)"
    fi
    if [[ "${answer,,}" == y* ]]; then SELECTED_ENVS+=("$env"); fi
  done
}

# True when a package has nothing to link yet (only .gitkeep / README)
is_empty_package() {
  local found
  found="$(cd "${DOTFILES_DIR}/$1" && find . -type f ! -name .gitkeep ! -path './README*' -print -quit)"
  [[ -z "$found" ]]
}

# ── Packages ─────────────────────────────────────────────────────────────────
# Prints the packages of the given sections of a list, one per line.
# Format: see packages/arch.txt ([section] headers, '#' comments, "aur:" prefix).
read_packages() {
  local file="$1"
  shift
  awk -v want=" $* " '
    BEGIN { section = "common" }
    { sub(/#.*/, ""); gsub(/^[ \t\r]+|[ \t\r]+$/, "") }
    $0 == "" { next }
    /^\[.+\]$/ { section = substr($0, 2, length($0) - 2); next }
    index(want, " " section " ") && !seen[$0]++ { print }
  ' "$file"
}

pkg_install() {
  if (( $# == 0 )); then return 0; fi
  case "${DISTRO}" in
    arch)
      # The first call of the run also upgrades the system: installing from a
      # stale package database gives 404s on the mirrors or a partial upgrade
      if [[ -z "${PACMAN_SYNCED:-}" ]]; then
        sudo pacman -Syu --needed --noconfirm "$@"
        PACMAN_SYNCED=1
      else
        sudo pacman -S --needed --noconfirm "$@"
      fi
      ;;
    fedora)
      sudo dnf install -y "$@"
      ;;
    ubuntu)
      if [[ -z "${APT_UPDATED:-}" ]]; then
        sudo apt-get update
        APT_UPDATED=1
      fi
      sudo apt-get install -y "$@"
      ;;
    *)
      err "Unknown distro, cannot install: $*"
      return 1
      ;;
  esac
}

# paru from the AUR. makepkg also builds paru-debug (debug symbols, on by
# default in Arch's makepkg.conf): only paru itself is installed
bootstrap_paru() {
  local tmp
  pkg_install base-devel git
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  (
    cd "$tmp/paru" || exit 1
    # -r: rust (build-only dependency) doesn't stay installed
    makepkg -sr --noconfirm || exit 1
    mapfile -t pkgs < <(makepkg --packagelist | grep -v -- '-debug-')
    sudo pacman -U --noconfirm "${pkgs[@]}"
  )
  rm -rf "$tmp"
}

install_aur() {
  local aur_helper="" helper

  for helper in paru yay; do
    if command -v "$helper" &>/dev/null; then
      aur_helper="$helper"
      break
    fi
  done

  if [[ -z "$aur_helper" ]]; then
    warn "No AUR helper (paru/yay) found. Installing paru..."
    bootstrap_paru
    aur_helper="paru"
    log "paru installed."
  fi

  info "Installing AUR packages with ${aur_helper}..."
  # --removemake: build-only dependencies (go, pnpm...) don't stay installed
  "$aur_helper" -S --needed --noconfirm --removemake "$@"
  log "AUR packages installed."
}

install_packages() {
  local list="${PACKAGES_DIR}/${DISTRO}.txt"
  local -a all=() repo_pkgs=() aur_pkgs=()
  local pkg

  if [[ "${DISTRO}" == "unknown" || ! -f "$list" ]]; then
    warn "No package list for this distro (see /etc/os-release). Skipping packages."
    return 0
  fi

  mapfile -t all < <(read_packages "$list" common "${SELECTED_ENVS[@]}")
  for pkg in "${all[@]}"; do
    if [[ "$pkg" == aur:* ]]; then
      aur_pkgs+=("${pkg#aur:}")
    else
      repo_pkgs+=("$pkg")
    fi
  done

  if (( ${#repo_pkgs[@]} )); then
    info "Installing packages from packages/${DISTRO}.txt (common ${SELECTED_ENVS[*]})..."
    pkg_install "${repo_pkgs[@]}"
    log "Packages installed."
  else
    warn "packages/${DISTRO}.txt is still a TODO. Skipping packages."
  fi

  if (( ${#aur_pkgs[@]} )); then
    if [[ "${DISTRO}" == "arch" ]]; then
      install_aur "${aur_pkgs[@]}"
    else
      warn "Ignoring AUR entries outside Arch: ${aur_pkgs[*]}"
    fi
  fi
}

# Neovim formatters / LSPs that need extra runtimes (Arch package names)
install_optional_deps() {
  local choice

  if [[ "${DISTRO}" != "arch" ]]; then
    info "Optional Neovim runtimes (Java, PHP, Go, Rust, Nix): install them with your package manager if needed."
    return 0
  fi

  echo ""
  info "Some Neovim plugins need additional runtimes for formatters / LSPs."
  echo "The following are OPTIONAL – only install what you actually use:"
  echo ""
  echo "  [1] Java  – jdk-openjdk  (jdtls, google-java-format)"
  echo "  [2] PHP   – php          (php-cs-fixer)"
  echo "  [3] Go    – go           (gofumpt)"
  echo "  [4] Rust  – rustup       (rustfmt, rust-analyzer)"
  echo "  [5] Nix   – nix          (alejandra formatter)"
  echo "  [6] ALL of the above"
  echo "  [0] Skip"
  echo ""

  choice="$(ask "Enter your choice (0-6): " 0)"

  case "$choice" in
    1) pkg_install jdk-openjdk ;;
    2) pkg_install php ;;
    3) pkg_install go ;;
    4)
      pkg_install rustup
      rustup default stable 2>/dev/null || true
      ;;
    5)
      if ! command -v nix &>/dev/null; then
        warn "Nix requires the multi-user install. See https://nixos.org/download"
      fi
      ;;
    6)
      pkg_install jdk-openjdk php go rustup
      rustup default stable 2>/dev/null || true
      ;;
    0) info "Skipping optional dependencies." ;;
    *) warn "Invalid choice. Skipping." ;;
  esac
}

# ── Services ─────────────────────────────────────────────────────────────────
# greetd shows the login screen for every environment (Hyprland, Xfce, i3).
# Only enabled, not started: starting it now would switch to the login screen
# in the middle of the run. A LightDM set up by an older install.sh is
# replaced; any other display manager (gdm, sddm...) is kept.
enable_display_manager() {
  local current
  current="$(readlink -e "${DM_UNIT_LINK}" 2>/dev/null || true)"
  current="${current##*/}"

  case "$current" in
    "" | greetd.service) ;;
    lightdm.service)
      info "Replacing LightDM with greetd."
      sudo systemctl disable lightdm || warn "Could not disable lightdm."
      ;;
    *)
      info "Display manager already set (${current}), keeping it."
      return 0
      ;;
  esac

  if sudo systemctl enable greetd; then
    log "greetd enabled (login screen from the next boot)."
  else
    warn "Could not enable greetd."
  fi
}

enable_services() {
  local svc enable_sshd ssh_unit=sshd

  if [[ "${DISTRO}" == "ubuntu" ]]; then ssh_unit=ssh; fi

  info "Enabling system services..."

  for svc in NetworkManager bluetooth; do
    if sudo systemctl enable --now "$svc"; then
      log "${svc} enabled."
    else
      warn "Could not enable ${svc}."
    fi
  done
  sudo systemctl enable tailscaled 2>/dev/null || true

  if has_env xfce || has_env hyprland; then
    enable_display_manager
  fi

  # sshd opens remote login (password auth by default), so only on request
  enable_sshd="$(ask "Enable SSH server (${ssh_unit})? [y/N]: " n)"
  if [[ "${enable_sshd,,}" == "y" ]]; then
    sudo systemctl enable "${ssh_unit}"
    log "${ssh_unit} enabled."
  else
    info "Skipping ${ssh_unit}."
  fi
}

# ── Linking (GNU Stow) ───────────────────────────────────────────────────────
# XFCE writes machine data into the linked files: Wi-Fi network names in
# xfce4-panel.xml, monitor names and /home/<user> paths in xfce4-desktop.xml,
# the last window sizes in xfce4-desktop.xml and thunar.xml. These git filters
# strip them on commit (see .gitattributes).
setup_git_filter() {
  if git -C "${DOTFILES_DIR}" rev-parse --git-dir &>/dev/null; then
    git -C "${DOTFILES_DIR}" config filter.xfce-panel.clean "awk -f tools/xfce-panel-clean.awk"
    git -C "${DOTFILES_DIR}" config filter.xfce-desktop.clean "awk -f tools/xfce-desktop-clean.awk"
    git -C "${DOTFILES_DIR}" config filter.xfce-thunar.clean "awk -f tools/xfce-thunar-clean.awk"
    log "Git filters for xfce4-panel.xml, xfce4-desktop.xml and thunar.xml configured."
  fi
}

ensure_stow() {
  if command -v stow &>/dev/null; then return 0; fi
  if [[ "${DISTRO}" == "unknown" ]]; then
    err "GNU Stow not found. Install it and run: $0 link"
    exit 1
  fi
  info "Installing GNU Stow..."
  pkg_install stow
}

is_shared_dir() {
  local dir
  for dir in "${SHARED_DIRS[@]}"; do
    if [[ "$dir" == "$1" ]]; then return 0; fi
  done
  return 1
}

# Clears the way for stow under $HOME for one package:
# - links into this repo are removed and made again by stow. This covers the
#   ~/.config/<name> links of the old install.sh, which pointed at the
#   repo's old .config/ folder and are now broken.
# - anything else in the way is renamed to <name>.bak (nothing is deleted)
# Shared folders (.config, ...) are entered instead of linked.
clear_stow_targets() {
  local pkg_dir="$1" rel="${2:-}"
  local src name dst target backup
  local skip_re='^(README|LICENSE).*$|^COPYING$'   # stow skips these too

  while IFS= read -r -d '' src; do
    name="${src##*/}"
    if [[ -z "$rel" && "$name" =~ $skip_re ]]; then continue; fi
    name="${rel:+${rel}/}${name}"
    dst="${HOME}/${name}"

    if [[ -d "$src" ]] && is_shared_dir "$name"; then
      mkdir -p "$dst"
      clear_stow_targets "$pkg_dir" "$name"
      continue
    fi

    if [[ -L "$dst" ]]; then
      target="$(readlink -m "$dst")"
      if [[ "$target" == "$src" ]]; then continue; fi   # already linked
      if [[ "$target" == "${DOTFILES_DIR}/"* ]]; then
        rm "$dst"
        info "Removed old link ~/${name}"
        continue
      fi
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
      backup="${dst}.bak"
      if [[ -e "$backup" || -L "$backup" ]]; then
        backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
      fi
      mv "$dst" "$backup"
      warn "Moved existing ~/${name} to ${backup}"
    fi
  done < <(find "${pkg_dir}${rel:+/${rel}}" -mindepth 1 -maxdepth 1 -print0)
}

# The old layout kept the configs in the repo's .config/ and linked
# ~/.config/<name> to it, so apps also wrote untracked files there (XFCE panel
# launchers, other xfconf channels, ...). git pull only moves tracked files:
# move what is left to the package that now holds that folder.
migrate_old_layout() {
  local old="${DOTFILES_DIR}/.config"
  local src rel top env pkg dest moved=0

  if [[ ! -d "$old" ]]; then return 0; fi
  info "Moving files left in the old .config/ folder to the new packages..."

  while IFS= read -r -d '' src; do
    rel="${src#"${old}/"}"
    top="${rel%%/*}"
    pkg=""
    for env in common "${ENVS_AVAILABLE[@]}"; do
      if [[ -e "${DOTFILES_DIR}/${env}/.config/${top}" ]]; then
        pkg="$env"
        break
      fi
    done
    if [[ -z "$pkg" ]]; then continue; fi
    dest="${DOTFILES_DIR}/${pkg}/.config/${rel}"
    if [[ -e "$dest" || -L "$dest" ]]; then
      warn "Kept .config/${rel}: ${pkg}/.config/${rel} already exists"
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    mv "$src" "$dest"
    moved=$((moved + 1))
  done < <(find "$old" \( -type f -o -type l \) -print0)

  find "$old" -depth -type d -empty -delete
  log "Moved ${moved} file(s) from the old .config/ folder."
  if [[ -d "$old" ]]; then
    warn "Some files stayed in ${old}. Check them by hand."
  fi
}

# Lists the *.bak that clear_stow_targets left in ~/.config, so the copies
# from earlier runs don't pile up unnoticed. Only warns, deletes nothing.
report_bak_files() {
  local -a baks=()
  local f shown=0 max=10

  if [[ ! -d "${CONFIG_DST}" ]]; then return 0; fi
  mapfile -t baks < <(find "${CONFIG_DST}" -mindepth 1 -maxdepth 1 \
    \( -name '*.bak' -o -name '*.bak.[0-9]*' \) -print | sort)
  if (( ${#baks[@]} == 0 )); then return 0; fi

  warn "${#baks[@]} copy(ies) *.bak in ~/.config (files that were in the way of a link):"
  for f in "${baks[@]}"; do
    if (( shown == max )); then
      echo "    ... and $(( ${#baks[@]} - max )) more"
      break
    fi
    echo "    ~${f#"${HOME}"}"
    shown=$((shown + 1))
  done
  info "Check them and delete what you no longer need."
}

# Removes the ~/.config/<name> links of DROPPED_CONFIGS that are broken and
# pointed into this repo. A real folder, a link that still works or one that
# points elsewhere stays.
remove_dropped_links() {
  local name dst target
  for name in "${DROPPED_CONFIGS[@]}"; do
    dst="${CONFIG_DST}/${name}"
    if [[ ! -L "$dst" || -e "$dst" ]]; then continue; fi
    target="$(readlink -m "$dst")"
    if [[ "$target" == "${DOTFILES_DIR}/"* ]]; then
      rm "$dst"
      info "Removed old link ~/.config/${name}"
    fi
  done
}

link_configs() {
  local -a pkgs=(common)
  local env pkg

  for env in "${SELECTED_ENVS[@]}"; do
    if is_empty_package "$env"; then
      warn "Skipping ${env}: no configs in ${env}/ yet."
    else
      pkgs+=("$env")
    fi
  done

  ensure_stow
  setup_git_filter
  migrate_old_layout

  info "Linking with GNU Stow: ${pkgs[*]} -> ${HOME}"
  mkdir -p "${CONFIG_DST}"
  for pkg in "${pkgs[@]}"; do
    clear_stow_targets "${DOTFILES_DIR}/${pkg}"
  done
  stow --dir="${DOTFILES_DIR}" --target="${HOME}" --restow --verbose=1 "${pkgs[@]}"
  remove_dropped_links
  log "Linked: ${pkgs[*]}"
  report_bak_files
}

# Without arguments removes the links of every package
unlink_configs() {
  local -a pkgs=()
  local pkg

  if (( $# )); then
    for pkg in "$@"; do
      if [[ "$pkg" != "common" ]] && ! is_known_env "$pkg"; then
        err "Unknown environment: ${pkg} (available: common ${ENVS_AVAILABLE[*]})"
        exit 1
      fi
      pkgs+=("$pkg")
    done
  else
    pkgs=(common "${ENVS_AVAILABLE[@]}")
  fi

  if ! command -v stow &>/dev/null; then
    err "GNU Stow not found, nothing was linked by it."
    exit 1
  fi

  info "Removing links: ${pkgs[*]}"
  stow --dir="${DOTFILES_DIR}" --target="${HOME}" --delete --verbose=1 "${pkgs[@]}"
  log "Links removed. Files renamed to *.bak were left as they are."
}

# ── User directories ─────────────────────────────────────────────────────────
# Creates the folders named in the linked ~/.config/user-dirs.dirs (Imagens,
# Downloads...). xdg-user-dirs-update resets a missing folder to $HOME and
# rewrites the file, which replaces the stow link with a plain file.
create_user_dirs() {
  local conf="${HOME}/.config/user-dirs.dirs" line

  [[ -f "$conf" ]] || return 0
  while IFS= read -r line; do
    if [[ "$line" =~ ^XDG_[A-Z]+_DIR=\"\$HOME/(.+)\"$ ]]; then
      mkdir -p "${HOME}/${BASH_REMATCH[1]}"
    fi
  done < "$conf"
}

# ── Default apps ─────────────────────────────────────────────────────────────
# Prints the path of an installed .desktop file, or fails
find_desktop_file() {
  local dir IFS=:

  for dir in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    if [[ -f "${dir}/applications/$1" ]]; then
      echo "${dir}/applications/$1"
      return 0
    fi
  done
  return 1
}

# Makes an app the default for every type its .desktop file declares under a
# prefix (image/, video/): xdg-mime has no wildcards. Skipped when the app is
# not installed. Writes ~/.config/mimeapps.list (not in the repo).
set_default_app() {
  local desktop="$1" prefix="$2" file
  local -a types

  file="$(find_desktop_file "$desktop")" || return 0
  mapfile -t types < <(grep -m1 '^MimeType=' "$file" | cut -d= -f2- | tr ';' '\n' | grep "^${prefix}")
  if ((${#types[@]} == 0)); then
    return 0
  fi
  if xdg-mime default "$desktop" "${types[@]}"; then
    log "Default for ${prefix}*: ${desktop%.desktop} (${#types[@]} types)"
  else
    warn "Could not set ${desktop%.desktop} as the default for ${prefix}*"
  fi
}

# Images open in swayimg and videos in mpv. swayimg needs Wayland: in the
# XFCE session (X11) images don't open (README).
set_default_apps() {
  if ! command -v xdg-mime &>/dev/null; then
    warn "xdg-mime not found (xdg-utils), skipping the default apps."
    return 0
  fi
  set_default_app swayimg.desktop image/
  set_default_app mpv.desktop video/
}

# ── XFCE ─────────────────────────────────────────────────────────────────────
# The wallpaper is not in xfce4-desktop.xml: xfdesktop keys it by monitor name.
# ~/.local/bin/xfce-wallpaper sets it at every XFCE login (autostart).
configure_xfce() {
  local wallpaper="${DOTFILES_DIR}/common/.config/wallpapers/${WALLPAPER_FILE}"

  if [[ -f "$wallpaper" ]]; then
    info "Wallpaper is set at the next XFCE login (xfce-wallpaper)."
  else
    warn "Wallpaper not found: ${wallpaper}"
  fi
}

# Files of the login screen (Quickshell in cage, run by greetd as the
# "greeter" user): the greeter's QML, the session's theme and the parts of
# the lock screen it shares, and start-greeter. Regular root files, never
# links into the repo: the greeter must not run code the user can edit.
# Only the files of the list go in. The greeter's cache folder (last user
# and session) is its own, 700. Does not touch config.toml: greetd keeps
# showing the old login screen until configure_login_screen.
install_greeter_files() {
  local pair dir="${GREETD_DIR}/quickshell"

  if [[ ! -d "${GREETD_DIR}" ]]; then
    warn "greetd is not installed, skipping the login screen."
    return 1
  fi

  # Every step returns on failure: the caller only points greetd at the
  # new screen when all of it is in place
  sudo install -d -m755 -o root -g root "${dir}" "${dir}/greeter" "${dir}/theme" "${dir}/lock" || return 1
  for pair in "${GREETER_FILES[@]}"; do
    sudo install -m644 -o root -g root "${DOTFILES_DIR}/${pair%%:*}" "${dir}/${pair#*:}" || return 1
  done
  sudo install -m755 -o root -g root "${DOTFILES_DIR}/system/greetd/start-greeter" "${GREETD_DIR}/start-greeter" || return 1
  if id greeter &>/dev/null; then
    sudo install -d -m700 -o greeter -g greeter "${GREETER_CACHE}" || return 1
  else
    warn "No greeter user (greetd's package creates it): the login screen won't remember the last choices."
  fi
  log "Login screen files installed (${dir})."
}

# Points greetd at the Quickshell login screen (config.toml). The packaged
# config.toml is kept as .bak once. The old ReGreet files in /etc/greetd stay
# where they are (unused).
configure_login_screen() {
  local src="${DOTFILES_DIR}/system/greetd"

  if [[ ! -d "${GREETD_DIR}" ]]; then
    warn "greetd is not installed, skipping the login screen."
    return 0
  fi
  # config.toml only changes once every file of the new screen is in place
  if ! install_greeter_files; then
    err "Could not install the login screen files; greetd keeps the old login screen (config.toml unchanged)."
    return 0
  fi
  if [[ -f "${GREETD_DIR}/config.toml" && ! -e "${GREETD_DIR}/config.toml.bak" \
        && "$(< "${GREETD_DIR}/config.toml")" != "$(< "${src}/config.toml")" ]]; then
    sudo cp -p "${GREETD_DIR}/config.toml" "${GREETD_DIR}/config.toml.bak"
  fi
  sudo install -m644 -o root -g root "${src}/config.toml" "${GREETD_DIR}/config.toml"
  log "Login screen set (greetd + Quickshell)."
}

# Text consoles log out by themselves after 10 minutes without a command
# (system/profile.d/tmout.sh): a console left open after a lock-screen
# recovery does not stay logged in. SSH and the graphical session's
# terminals are not touched. A regular root file; not fatal.
install_console_timeout() {
  sudo install -o root -g root -m644 "${DOTFILES_DIR}/system/profile.d/tmout.sh" /etc/profile.d/tmout.sh \
    && log "Text consoles log out after 10 minutes idle (/etc/profile.d/tmout.sh)." \
    || warn "Could not install /etc/profile.d/tmout.sh (text consoles keep no time limit)."
}

# PAM service of the Quickshell lock screen (hyprland/.config/quickshell/lock).
# Without it PAM falls back to "other" (deny) and no password would unlock,
# so hypr-travar refuses to lock while it is missing. A regular root file,
# never a link into the repo: a user-owned link would let the user rewrite
# the rules that guard the lock.
install_lock_pam() {
  sudo install -o root -g root -m644 "${DOTFILES_DIR}/system/pam.d/quickshell-lock" "${PAM_DIR}/quickshell-lock"
  log "Lock screen PAM service installed (${PAM_DIR}/quickshell-lock)."
}

# Background shared by the lock and login screens: lock/BackgroundPicker
# writes it, the greeter user only reads it. The parent folders stay root's;
# only the last one belongs to the user who installs (the real one, also
# under sudo), so the picker replaces the picture without sudo. The default
# picture goes in only while none exists: running install.sh again keeps the
# user's choice. No chown -R anywhere.
setup_shared_login() {
  local user="${SUDO_USER:-$(id -un)}" group default
  group="$(id -gn "$user")"
  default="${DOTFILES_DIR}/common/.config/wallpapers/${LOGIN_DEFAULT_FILE}"

  sudo install -d -m755 -o root -g root "$(dirname "${SHARED_LOGIN_DIR}")"
  sudo install -d -m755 -o "$user" -g "$group" "${SHARED_LOGIN_DIR}"
  if [[ ! -e "${SHARED_LOGIN_DIR}/fundo.png" && -f "$default" ]]; then
    sudo install -m644 -o "$user" -g "$group" "$default" "${SHARED_LOGIN_DIR}/fundo.png"
  fi
  log "Lock and login background folder ready (${SHARED_LOGIN_DIR})."
}

# System language and keyboard (Arch). Each part checks first: on a system
# already set, no sudo runs. The language only changes after a question
# (yes with --yes) and keeps every LC_* already set; it applies from the next
# login. The keyboard keeps the current X11 options (localectl would drop
# what is not passed); --no-convert keeps the console and X11 keymaps apart.
# Never fatal: a step that fails only warns, the install goes on.
setup_locale_keyboard() {
  local status lang others options line done_any="" generated=1
  local -a extra=()

  if [[ "${DISTRO}" != "arch" ]]; then
    warn "Language and keyboard: only set automatically on Arch; set ${SYSTEM_LOCALE} and ${CONSOLE_KEYMAP} by hand."
    return 0
  fi

  # The locale, generated once
  if ! locale -a 2>/dev/null | grep -qix "${SYSTEM_LOCALE/UTF-8/utf8}"; then
    if grep -qE "^#[[:space:]]*${SYSTEM_LOCALE//./\\.} UTF-8" "${LOCALE_GEN}" 2>/dev/null; then
      sudo sed -i "s/^#[[:space:]]*${SYSTEM_LOCALE//./\\.} UTF-8/${SYSTEM_LOCALE} UTF-8/" "${LOCALE_GEN}" \
        || warn "Could not enable ${SYSTEM_LOCALE} in ${LOCALE_GEN}."
    elif ! grep -qE "^${SYSTEM_LOCALE//./\\.} UTF-8" "${LOCALE_GEN}" 2>/dev/null; then
      echo "${SYSTEM_LOCALE} UTF-8" | sudo tee -a "${LOCALE_GEN}" >/dev/null \
        || warn "Could not add ${SYSTEM_LOCALE} to ${LOCALE_GEN}."
    fi
    sudo locale-gen || warn "locale-gen failed."
    done_any=1
    # Switching to a locale that does not exist would break every program
    if ! locale -a 2>/dev/null | grep -qix "${SYSTEM_LOCALE/UTF-8/utf8}"; then
      generated=""
      warn "${SYSTEM_LOCALE} is not available: the system language stays as it is."
    fi
  fi

  status="$(localectl status 2>/dev/null || true)"
  # "System Locale: LANG=… LC_TIME=…" (the extra ones on the lines below)
  # (grep finds nothing on most systems: no LC_* set; that is not an error)
  lang="$(sed -n '/System Locale:/,/Keymap:/p' <<<"${status}" | grep -oE 'LANG=[^[:space:]]+' | head -n 1 || true)"
  others="$(sed -n '/System Locale:/,/Keymap:/p' <<<"${status}" | grep -oE '[A-Z_]+=[^[:space:]]+' | grep -v '^LANG=' | tr '\n' ' ' || true)"
  # One argument per LC_*, with no word splitting or globbing
  read -r -a extra <<<"${others}"
  if [[ -n "${generated}" && "${lang}" != "LANG=${SYSTEM_LOCALE}" ]]; then
    if [[ "$(ask "Use ${SYSTEM_LOCALE} as the system language (now ${lang:-unset})? [Y/n] " "y")" =~ ^[Yy] ]]; then
      if sudo localectl set-locale "LANG=${SYSTEM_LOCALE}" "${extra[@]}"; then
        log "System language: ${SYSTEM_LOCALE}${others:+ (kept: ${others% })} (from the next login)."
      else
        warn "Could not set the system language to ${SYSTEM_LOCALE}."
      fi
      done_any=1
    else
      info "System language kept (${lang:-unset})."
    fi
  fi

  line="$(sed -n 's/^ *VC Keymap: *//p' <<<"${status}")"
  if [[ "${line}" != "${CONSOLE_KEYMAP}" ]]; then
    sudo localectl set-keymap --no-convert "${CONSOLE_KEYMAP}" \
      || warn "Could not set the console keyboard to ${CONSOLE_KEYMAP}."
    done_any=1
  fi

  if [[ "$(sed -n 's/^ *X11 Layout: *//p' <<<"${status}")" != "${XKB_LAYOUT}" \
        || "$(sed -n 's/^ *X11 Model: *//p' <<<"${status}")" != "${XKB_MODEL}" ]]; then
    options="$(sed -n 's/^ *X11 Options: *//p' <<<"${status}")"
    sudo localectl set-x11-keymap --no-convert "${XKB_LAYOUT}" "${XKB_MODEL}" "" "${options}" \
      || warn "Could not set the X11/Wayland keyboard to ${XKB_LAYOUT} ${XKB_MODEL}."
    done_any=1
  fi

  if [[ -z "${done_any}" ]]; then
    log "Language and keyboard already ${SYSTEM_LOCALE} / ${CONSOLE_KEYMAP}."
  fi
}

# ── Install ──────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo "============================================================"
  log "Installation complete! 🎉"
  echo "============================================================"
  echo ""
  echo "  📋 Next steps:"
  if has_env xfce || has_env hyprland; then
    echo "  • Reboot and pick the session (Hyprland, Xfce or i3) on the login screen"
  fi
  echo "  • Open Neovim and let lazy.nvim bootstrap the plugins"
  echo "    (just run 'nvim' and wait – it's automatic)"
  echo "  • If you installed optional deps, run :Mason inside nvim"
  echo "    to verify your LSPs/formatters are installed"
  echo ""
  echo "  📁 Configuration:"
  echo "  • Linked with GNU Stow from ${DOTFILES_DIR}"
  echo "    packages: common ${SELECTED_ENVS[*]}"
  echo "  • Edit configs in the repo, changes take effect immediately"
  echo ""
  echo "  💡 Tips:"
  echo "  • Link again after a pull: $0 link"
  echo "  • Backup your current setup: $0 backup"
  echo "  • Restore from backup: $0 restore"
  echo "  • List available backups: $0 list"
  echo ""
  if has_env xfce; then
    echo "  ⚙️  XFCE Configuration:"
    echo "  • Panel settings: xfce/.config/xfce4/panel/"
    echo "  • Theme & shortcuts: xfce/.config/xfce4/xfconf/"
    echo "  • Wallpaper: set at login by ~/.local/bin/xfce-wallpaper"
    echo "  • Login screen: system/greetd/ (copied to /etc/greetd)"
    echo ""
  fi
  if has_env hyprland; then
    echo "  🪟 Hyprland:"
    echo "  • On the login screen pick \"Hyprland (uwsm-managed)\""
    echo "  • Machine settings (monitor, scale, VM fixes):"
    echo "    cp ~/.config/hypr/local.lua.example ~/.config/hypr/local.lua"
    echo "    and keep only the block for this machine"
    echo "  • Keybinds: Super+F1 or hyprland/README.md"
    echo "  • The Quickshell bar starts with the session; Super+D opens the launcher (rofi for now)"
    echo ""
  fi
  echo "============================================================"
}

main() {
  local -a args=()
  local arg

  # Options may come anywhere: ./install.sh --yes install xfce
  for arg in "$@"; do
    case "$arg" in
      -y|--yes) ASSUME_YES=1 ;;
      *)        args+=("$arg") ;;
    esac
  done
  set -- "${args[@]}"

  local command="${1:-install}"
  if (( $# )); then shift; fi
  command="${command#--}"   # accept --backup, --install, ...

  # ── Root check ──
  if [[ $EUID -eq 0 ]]; then
    err "Do not run this script as root. It will use sudo when needed."
    exit 1
  fi

  DISTRO="$(detect_distro)"
  log "Dotfiles directory: ${DOTFILES_DIR}"

  case "${command}" in
    backup)
      backup_config
      exit $?
      ;;
    restore)
      if [[ -z "${1:-}" ]]; then
        list_backups
        backup_file="$(ask "Enter backup file path to restore: " "")"
        if [[ -z "${backup_file}" ]]; then
          err "No backup file given. Usage: $0 restore <file>"
          exit 1
        fi
        restore_config "${backup_file}"
      else
        restore_config "$1"
      fi
      exit $?
      ;;
    list)
      list_backups
      exit 0
      ;;
    help|-h)
      usage
      exit 0
      ;;
    link)
      info "Distro: ${DISTRO}"
      choose_envs "$@"
      link_configs
      exit 0
      ;;
    unlink)
      unlink_configs "$@"
      exit 0
      ;;
    install)
      ;;
    *)
      err "Unknown command: ${command}"
      usage
      exit 1
      ;;
  esac

  if [[ "${DISTRO}" == "unknown" ]]; then
    warn "Unknown distro (see /etc/os-release). Packages are skipped, configs are still linked."
  else
    info "Distro: ${DISTRO} (packages/${DISTRO}.txt)"
  fi

  choose_envs "$@"
  install_packages
  setup_locale_keyboard
  enable_services
  install_optional_deps
  link_configs

  if has_env xfce; then
    configure_xfce
  fi
  if has_env xfce || has_env hyprland; then
    configure_login_screen
  fi
  if has_env xfce || has_env hyprland; then
    setup_shared_login
  fi
  if has_env hyprland; then
    install_lock_pam
  fi
  install_console_timeout

  create_user_dirs
  info "Running xdg-user-dirs-update to populate user directories..."
  xdg-user-dirs-update 2>/dev/null || true
  set_default_apps

  print_summary
}

# Run only when executed, so the functions can be sourced for testing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
