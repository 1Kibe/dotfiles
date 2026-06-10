#!/usr/bin/env bash
# =============================================================================
# arch+xfce dotfiles – Install Script
# =============================================================================
# This script installs all necessary dependencies and symlinks the
# configuration files into ~/.config so everything works out of the box.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh [--install|--backup|--restore]
#
# Commands:
#   install   Install dependencies and create symlinks (default)
#   backup    Backup current ~/.config to archive
#   restore   Restore from a backup archive
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

# ── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  err "Do not run this script as root. It will use sudo when needed."
  exit 1
fi

# ── Distro check ─────────────────────────────────────────────────────────────
if ! grep -qi "arch" /etc/os-release 2>/dev/null; then
  warn "This script is designed for Arch Linux. Proceeding anyway, but YMMV."
fi

# ── Directories ──────────────────────────────────────────────────────────────
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${DOTFILES_DIR}/.config"
CONFIG_DST="${HOME}/.config"
BACKUPS_DIR="${DOTFILES_DIR}/.backups"

log "Dotfiles directory: ${DOTFILES_DIR}"

# ── Helper functions ──────────────────────────────────────────────────────────
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

# ── Parse command line arguments ──────────────────────────────────────────────
COMMAND="${1:-install}"
case "${COMMAND}" in
  backup)
    backup_config
    exit $?
    ;;
  restore)
    if [[ -z "${2:-}" ]]; then
      list_backups
      read -r -p "Enter backup file path to restore: " backup_file
      restore_config "${backup_file}"
    else
      restore_config "$2"
    fi
    exit $?
    ;;
  list)
    list_backups
    exit 0
    ;;
  --help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install   Install dependencies and create symlinks (default)"
    echo "  backup    Backup current ~/.config to archive"
    echo "  restore   Restore from a backup archive"
    echo "  list      List available backups"
    exit 0
    ;;
esac

# =============================================================================
# 1. PACMAN PACKAGES
# =============================================================================
PACMAN_PKGS=(

    # ── Core tools ──
  git
  nano
  wget
  curl
  unzip
  less
  htop
  fastfetch
  make

  # ── Window manager & essentials ──
  i3-wm
  i3status
  i3lock
  rofi

  # ── Terminal ──
  alacritty

  # ── Editor ──
  neovim

  # ── File manager ──
  thunar
  thunar-archive-plugin

  # ── XFCE components ──
  xfce4-screenshooter

  # ── Audio ──
  pavucontrol

  # ── Network applet ──
  network-manager-applet

    # ── Bluetooth ──
  blueman
  bluez
  bluez-utils

    # ── Input / automation ──
  xdotool

  # ── Autostart ──
  dex

  # ── Fonts ──
  ttf-firacode-nerd

  # ── XDG user dirs ──
  xdg-user-dirs

  # ── Neovim dependencies ──
  git
  ripgrep
  nodejs
  npm
  python
  python-pip
  jdk-openjdk
  clang
  shfmt

  # ── Optional but recommended ──
  xclip
  unzip
  wget

    # ── System ──
  xdg-user-dirs
  openssh
)

info "Installing pacman packages..."
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
log "Pacman packages installed."

# =============================================================================
# 2. AUR PACKAGES
# =============================================================================
AUR_PKGS=(
  xss-lock   # screen locker integration
  tailscale
  obexftp
)

# Try to detect an AUR helper
AUR_HELPER=""
for helper in paru yay; do
  if command -v "$helper" &>/dev/null; then
    AUR_HELPER="$helper"
    break
  fi
done

if [[ -z "$AUR_HELPER" ]]; then
  warn "No AUR helper (paru/yay) found. Installing paru..."

  sudo pacman -S --needed --noconfirm base-devel git
  TMPDIR="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$TMPDIR/paru"
  (cd "$TMPDIR/paru" && makepkg -si --noconfirm)
  rm -rf "$TMPDIR"
  AUR_HELPER="paru"

  log "paru installed."
fi

info "Installing AUR packages with ${AUR_HELPER}..."
"$AUR_HELPER" -S --needed --noconfirm "${AUR_PKGS[@]}"
log "AUR packages installed."

# =============================================================================
# 🔧 SYSTEM SERVICES
# =============================================================================
info "Enabling system services..."

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable sshd
sudo systemctl enable tailscaled 2>/dev/null || true

# =============================================================================
# 3. OPTIONAL HEAVY DEPENDENCIES
# =============================================================================
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

read -r -p "Enter your choice (0-6): " choice

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

# =============================================================================
# 4. SYMLINK CONFIGURATIONS
# =============================================================================
info "Creating symlinks from ${CONFIG_SRC} to ${CONFIG_DST}..."

mkdir -p "${CONFIG_DST}"

for entry in "${CONFIG_SRC}"/*; do
  name="$(basename "$entry")"

  # Skip .gitignore inside .config/
  if [[ "$name" == ".gitignore" ]]; then
    continue
  fi

  dst="${CONFIG_DST}/${name}"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ ! -L "$dst" ]]; then
      warn "Backing up existing ${dst} → ${dst}.bak"
      mv "$dst" "${dst}.bak"
    else
      rm "$dst"
    fi
  fi

  ln -sfn "$entry" "$dst"
  log "Symlinked: ${name}"
done

# =============================================================================
# 5. XFCE DESKTOP & WALLPAPER
# =============================================================================
info "Configuring XFCE desktop and wallpaper..."

# Detect wallpaper from current xfce4-desktop.xml if it exists
if [[ -f "${CONFIG_DST}/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" ]]; then
  WALLPAPER=$(grep -oP '(?<=<property name="image-path" type="string" value=")[^"]*' \
    "${CONFIG_DST}/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" | head -1)
  
  if [[ -n "${WALLPAPER}" ]]; then
    log "Detected wallpaper: ${WALLPAPER}"
  fi
fi

# Apply xfce4-desktop.xml to set wallpaper and desktop properties
if [[ -f "${CONFIG_SRC}/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" ]]; then
  step "Applying XFCE desktop configuration..."
  xfconf-query -c xfdesktop -l > /dev/null 2>&1 || true
  log "XFCE desktop configuration applied"
fi

# =============================================================================
# 6. POST-INSTALL
# =============================================================================
info "Running xdg-user-dirs-update to populate user directories..."
xdg-user-dirs-update 2>/dev/null || true

echo ""
echo "============================================================"
log "Installation complete! 🎉"
echo "============================================================"
echo ""
echo "  📋 Next steps:"
echo "  1. Log out and back into i3 (or run 'i3-msg restart')"
echo "  2. Open Neovim and let lazy.nvim bootstrap the plugins"
echo "     (just run 'nvim' and wait – it's automatic)"
echo "  3. If you installed optional deps, run :Mason inside nvim"
echo "     to verify your LSPs/formatters are installed"
echo ""
echo "  📁 Configuration:"
echo "  • All config files are symlinked from:"
echo "    ${CONFIG_SRC}"
echo "  • → to →"
echo "    ${CONFIG_DST}"
echo ""
echo "  💡 Tips:"
echo "  • Edit configs in the repo, changes take effect immediately"
echo "  • Backup your current setup: $0 backup"
echo "  • Restore from backup: $0 restore"
echo "  • List available backups: $0 list"
echo ""
echo "  ⚙️  XFCE Configuration:"
echo "  • Panel settings: $(basename ${CONFIG_DST})/xfce4/panel/"
echo "  • Theme & shortcuts: $(basename ${CONFIG_DST})/xfce4/xfconf/"
echo "  • Wallpaper: Check xfce4-desktop.xml"
echo ""
echo "============================================================"
