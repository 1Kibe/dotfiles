#!/usr/bin/env bash
# Runs inside a container as root: prepares a non-root user and runs a test.
# $1 = distro family (arch|ubuntu|fedora), $2 = test script, $3.. = args
set -euo pipefail
family="$1"; shift
case "$family" in
  arch)   pacman -Sy --noconfirm --needed git stow sudo grep >/dev/null ;;
  ubuntu) apt-get update -qq >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git sudo >/dev/null ;;
  fedora) dnf install -y -q git sudo findutils gawk util-linux shadow-utils >/dev/null ;;
esac
useradd -m kibe
echo 'kibe ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/kibe
su - kibe -c "NEW_REF='${NEW_REF}' WT='${WT:-/src}' bash /tests/$*"
