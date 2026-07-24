#!/usr/bin/env bash
# =============================================================================
# lib/pkg.sh — package-manager abstraction ("Strategy" pattern).
#
# The rest of the installer never calls pacman/yay/paru directly — it calls
# pkg::install_official / pkg::install_aur, and this module decides *how*
# that actually happens (which concrete "strategy" backs it). That keeps
# deps.sh (the policy: what to install, in what order, with what prompts)
# completely decoupled from the mechanism.
#
# Depends on: lib/log.sh, lib/net.sh
# =============================================================================

_PKG_AUR_HELPER=""

pkg::is_arch() { command -v pacman &>/dev/null; }

pkg::installed() { pacman -Qi "$1" &>/dev/null; }

# pkg::_clear_stale_lock — self-heals the common "unable to lock database"
# pacman error left behind by a crashed/killed previous run. Only removes
# the lock when no pacman process is actually running, so a lock that's
# legitimately held is never pulled out from under a real process.
pkg::_clear_stale_lock() {
  local lock="/var/lib/pacman/db.lck"
  [[ -e "$lock" ]] || return 1
  if pgrep -x pacman &>/dev/null; then
    log::warn "pacman is already running elsewhere; leaving $lock in place."
    return 1
  fi
  log::warn "Found a stale pacman lock with no pacman process running; clearing it: $lock"
  sudo rm -f -- "$lock"
}

# pkg::_run_pacman <args...> — network-retried, with one automatic
# self-heal attempt (stale lock) before giving up.
pkg::_run_pacman() {
  net::retry 3 "pacman" -- sudo pacman "$@" && return 0
  pkg::_clear_stale_lock || return 1
  log::info "Retrying pacman after clearing stale lock..."
  net::retry 2 "pacman (post-unlock)" -- sudo pacman "$@"
}

# pkg::detect_aur_helper — memoized lookup of an available AUR helper.
pkg::detect_aur_helper() {
  if [[ -n "$_PKG_AUR_HELPER" ]]; then
    printf '%s\n' "$_PKG_AUR_HELPER"
    return 0
  fi
  local helper
  for helper in yay paru; do
    if command -v "$helper" &>/dev/null; then
      _PKG_AUR_HELPER="$helper"
      printf '%s\n' "$helper"
      return 0
    fi
  done
  return 1
}

# pkg::missing <pkg...> — prints the subset that is NOT currently installed.
pkg::missing() {
  local pkg
  for pkg in "$@"; do
    pkg::installed "$pkg" || printf '%s\n' "$pkg"
  done
}

# pkg::install_official <pkg...>
pkg::install_official() {
  [[ $# -eq 0 ]] && return 0
  log::info "Installing via pacman: $*"
  if [[ "${DOTFILES_DRY_RUN:-false}" == "true" ]]; then
    log::info "[dry-run] would run: sudo pacman -S --needed $*"
    return 0
  fi
  pkg::_run_pacman -Sy --noconfirm || return 1
  pkg::_run_pacman -S --needed --noconfirm "$@"
}

# pkg::install_aur <pkg...>
pkg::install_aur() {
  [[ $# -eq 0 ]] && return 0
  local helper
  if ! helper="$(pkg::detect_aur_helper)"; then
    log::warn "No AUR helper (yay/paru) found; cannot install: $*"
    log::warn "Install one manually first, e.g.: https://github.com/Jguer/yay#installation"
    return 1
  fi
  log::info "Installing via $helper (AUR): $*"
  if [[ "${DOTFILES_DRY_RUN:-false}" == "true" ]]; then
    log::info "[dry-run] would run: $helper -S --needed $*"
    return 0
  fi
  net::retry 3 "$helper install" -- "$helper" -S --needed --noconfirm "$@"
}
