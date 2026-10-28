#!/usr/bin/env bash
# =============================================================================
# dotfiles – Install Script
# =============================================================================
# Installs the packages for this distro and links the configs into $HOME
# with GNU Stow. Each top-level folder below is a Stow package that mirrors
# $HOME (common/.config/nvim -> ~/.config/nvim):
#
#   common/     always linked (nvim, alacritty, rofi, wallpapers)
#   xfce/       XFCE + i3
#   hyprland/   Hyprland + Quickshell (skipped while it has no configs)
#
# Package lists: packages/<distro>.txt (arch, fedora, ubuntu), picked from
# /etc/os-release.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh [command] [environment...]
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

# ── Directories ──────────────────────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DST="${HOME}/.config"
BACKUPS_DIR="${DOTFILES_DIR}/.backups"
PACKAGES_DIR="${DOTFILES_DIR}/packages"

# Optional environments (Stow packages next to common/), in menu order
ENVS_AVAILABLE=(xfce hyprland)
SELECTED_ENVS=()

# Folders shared by several packages. Stow must link what is inside them,
# never the folder itself: a linked ~/.config would put every app's config
# inside the repo.
SHARED_DIRS=(.config .local .local/bin .local/share)

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
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_file="${BACKUPS_DIR}/config_${timestamp}.tar.gz"

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
  echo "Usage: $0 [command] [environment...]"
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
    hyprland) echo "Hyprland + Quickshell, no configs yet" ;;
    *)        echo "$1" ;;
  esac
}

# Menu default: yes only for what this setup runs today
env_default() {
  if [[ "$1" == "xfce" ]]; then echo y; else echo n; fi
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
      read -r -p "  ${env} ($(env_label "$env"))? [Y/n]: " answer || answer=""
    else
      read -r -p "  ${env} ($(env_label "$env"))? [y/N]: " answer || answer=""
    fi
    answer="${answer:-$default}"
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
      sudo pacman -S --needed --noconfirm "$@"
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

install_aur() {
  local aur_helper="" helper tmp

  for helper in paru yay; do
    if command -v "$helper" &>/dev/null; then
      aur_helper="$helper"
      break
    fi
  done

  if [[ -z "$aur_helper" ]]; then
    warn "No AUR helper (paru/yay) found. Installing paru..."

    sudo pacman -S --needed --noconfirm base-devel git
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    aur_helper="paru"

    log "paru installed."
  fi

  info "Installing AUR packages with ${aur_helper}..."
  "$aur_helper" -S --needed --noconfirm "$@"
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

  read -r -p "Enter your choice (0-6): " choice || choice=0

  case "$choice" in
    1) sudo pacman -S --needed --noconfirm jdk-openjdk ;;
    2) sudo pacman -S --needed --noconfirm php ;;
    3) sudo pacman -S --needed --noconfirm go ;;
    4)
      sudo pacman -S --needed --noconfirm rustup
      rustup default stable 2>/dev/null || true
      ;;
    5)
      if ! command -v nix &>/dev/null; then
        warn "Nix requires the multi-user install. See https://nixos.org/download"
      fi
      ;;
    6)
      sudo pacman -S --needed --noconfirm jdk-openjdk php go rustup
      rustup default stable 2>/dev/null || true
      ;;
    0) info "Skipping optional dependencies." ;;
    *) warn "Invalid choice. Skipping." ;;
  esac
}

# ── Services ─────────────────────────────────────────────────────────────────
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

  # sshd opens remote login (password auth by default), so only on request
  read -r -p "Enable SSH server (${ssh_unit})? [y/N]: " enable_sshd || enable_sshd=""
  if [[ "${enable_sshd,,}" == "y" ]]; then
    sudo systemctl enable "${ssh_unit}"
    log "${ssh_unit} enabled."
  else
    info "Skipping ${ssh_unit}."
  fi
}

# ── Linking (GNU Stow) ───────────────────────────────────────────────────────
# XFCE writes runtime cache (Wi-Fi network names) into the linked
# xfce4-panel.xml. This git filter strips it on commit (see .gitattributes).
setup_git_filter() {
  if git -C "${DOTFILES_DIR}" rev-parse --git-dir &>/dev/null; then
    git -C "${DOTFILES_DIR}" config filter.xfce-panel.clean "awk -f tools/xfce-panel-clean.awk"
    log "Git filter for xfce4-panel.xml configured."
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

  info "Linking with GNU Stow: ${pkgs[*]} -> ${HOME}"
  mkdir -p "${CONFIG_DST}"
  for pkg in "${pkgs[@]}"; do
    clear_stow_targets "${DOTFILES_DIR}/${pkg}"
  done
  stow --dir="${DOTFILES_DIR}" --target="${HOME}" --restow --verbose=1 "${pkgs[@]}"
  log "Linked: ${pkgs[*]}"
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

# ── XFCE ─────────────────────────────────────────────────────────────────────
configure_xfce() {
  local desktop_xml="${CONFIG_DST}/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  local wallpaper=""

  info "Configuring XFCE desktop and wallpaper..."

  # Wallpaper path from xfce4-desktop.xml (uses ${HOME}, wallpapers come from common/)
  if [[ -f "${desktop_xml}" ]]; then
    wallpaper=$(grep -oP '(?<=<property name="(last-image|image-path)" type="string" value=")[^"]*' \
      "${desktop_xml}" | head -1 || true)

    if [[ -n "${wallpaper}" ]]; then
      log "Detected wallpaper: ${wallpaper}"
      wallpaper="${wallpaper//\$\{HOME\}/${HOME}}"
      if [[ ! -f "${wallpaper}" ]]; then
        warn "Wallpaper file not found: ${wallpaper}"
      fi
    fi

    step "Applying XFCE desktop configuration..."
    xfconf-query -c xfdesktop -l > /dev/null 2>&1 || true
    log "XFCE desktop configuration applied"
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
  if has_env xfce; then
    echo "  • Log out and back into i3 (or run 'i3-msg restart')"
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
    echo "  • Wallpaper: Check xfce4-desktop.xml"
    echo ""
  fi
  echo "============================================================"
}

main() {
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
        read -r -p "Enter backup file path to restore: " backup_file
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
  enable_services
  install_optional_deps
  link_configs

  if has_env xfce; then
    configure_xfce
  fi

  info "Running xdg-user-dirs-update to populate user directories..."
  xdg-user-dirs-update 2>/dev/null || true

  print_summary
}

# Run only when executed, so the functions can be sourced for testing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
