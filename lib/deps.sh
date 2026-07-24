#!/usr/bin/env bash
# =============================================================================
# lib/deps.sh — dependency resolution and conflict detection (policy layer).
#
# This is where "what should be installed, and in what order" lives. It is
# built entirely on top of the pkg:: strategy interface, so it never needs
# to know whether pacman, yay or paru actually does the work.
#
# Depends on: lib/log.sh, lib/ui.sh, lib/pkg.sh, lib/net.sh
# =============================================================================

# deps::check_conflicts <pkg...>
# Warns loudly about packages known to fight with this rice (e.g. pulseaudio
# vs. pipewire-pulse). Never removes anything automatically — that decision
# is left to the user.
deps::check_conflicts() {
  [[ $# -eq 0 ]] && return 0
  local pkg found=()
  for pkg in "$@"; do
    pkg::installed "$pkg" && found+=("$pkg")
  done
  if (( ${#found[@]} > 0 )); then
    ui::danger "Conflicting package(s) detected: ${found[*]}" \
      "These are known to conflict with the pipewire/Hyprland setup here." \
      "setup.sh will NOT remove them automatically." \
      "Consider removing them yourself first: sudo pacman -Rns ${found[*]}"
    ui::confirm "Continue anyway?" n || return 1
  fi
  return 0
}

# deps::resolve — the full dependency step, run once from setup.sh.
deps::resolve() {
  if ! pkg::is_arch; then
    log::error "pacman not found — this installer targets Arch Linux (or an Arch-based derivative)."
    return 1
  fi

  deps::check_conflicts "${DOTFILES_CONFLICT_PKGS[@]}" || return 1

  local -a missing_req missing_opt missing_aur
  mapfile -t missing_req < <(pkg::missing "${DOTFILES_REQUIRED_PKGS[@]}")
  mapfile -t missing_opt < <(pkg::missing "${DOTFILES_OPTIONAL_PKGS[@]}")
  mapfile -t missing_aur < <(pkg::missing "${DOTFILES_AUR_PKGS[@]}")

  if (( ${#missing_req[@]} > 0 )); then
    log::step "Required packages missing: ${missing_req[*]}"

    # Real gate, not decoration: required packages can only come from the
    # network, so check for one *before* prompting — otherwise the user
    # says "yes", waits through pacman's own timeout, and fails anyway.
    if ! net::online; then
      log::warn "No network reachable, and required packages are missing."
      ui::confirm "Continue anyway and attempt installation (likely to fail)?" n \
        || { log::error "Aborting: required packages can't be installed without a network connection."; return 1; }
    fi

    if ui::confirm "Install ${#missing_req[@]} required package(s) now?" y; then
      # Bounded retry loop instead of a dead end: a transient mirror hiccup
      # or a stale lock (self-healed inside pkg::install_official) shouldn't
      # force the whole script to be restarted from scratch. Only an
      # explicit, informed user choice can continue past a real failure.
      local attempts=0 max_attempts=3
      until pkg::install_official "${missing_req[@]}"; do
        (( attempts++ ))
        if (( attempts >= max_attempts )); then
          log::error "Required package install failed after $attempts attempt(s)."
          if ui::confirm "Continue WITHOUT these packages? (things will likely break)" n; then
            log::warn "Continuing without: ${missing_req[*]} — proceed at your own risk."
            break
          fi
          return 1
        fi
        log::warn "Install attempt $attempts/$max_attempts failed."
        ui::confirm "Retry?" y || { log::error "Aborting at your request."; return 1; }
      done
    else
      log::error "Required packages declined. Aborting (nothing else was changed)."
      return 1
    fi
  else
    log::ok "All required packages already installed."
  fi

  if (( ${#missing_opt[@]} > 0 )); then
    log::step "Optional packages missing: ${missing_opt[*]}"
    if ui::confirm "Install ${#missing_opt[@]} optional package(s)?" y; then
      pkg::install_official "${missing_opt[@]}" || log::warn "Some optional packages failed; continuing anyway."
    else
      log::info "Skipping optional packages (can be installed later)."
    fi
  else
    log::ok "All optional packages already installed."
  fi

  if (( ${#missing_aur[@]} > 0 )); then
    log::step "AUR packages missing: ${missing_aur[*]}"
    if ui::confirm "Install ${#missing_aur[@]} AUR package(s)?" y; then
      pkg::install_aur "${missing_aur[@]}" || log::warn "Some AUR packages failed; continuing anyway."
    else
      log::info "Skipping AUR packages (can be installed later)."
    fi
  else
    log::ok "All AUR packages already installed (or none configured)."
  fi

  return 0
}
