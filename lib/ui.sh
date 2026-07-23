#!/usr/bin/env bash
# =============================================================================
# lib/ui.sh — user interaction helpers (confirmations, danger banners, tty
# detection).
# Depends on: lib/log.sh
# =============================================================================

# ui::has_tty — true if we can actually talk to a real terminal.
#
# Deliberately checks /dev/tty rather than `[[ -t 0 ]]`: when this script is
# run as `curl -fsSL ... | bash`, fd 0 is the pipe carrying the script's own
# source, NOT the user's keyboard — so `-t 0` is always false there even
# though the user's terminal (/dev/tty) is perfectly usable for prompts.
ui::has_tty() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

# ui::confirm <prompt> [default: y|n]
#
# Honors DOTFILES_ASSUME_YES (non-interactive "yes to all") and never hangs
# when no terminal is reachable at all — it falls back to the given default
# instead of blocking forever.
ui::confirm() {
  local prompt="$1" default="${2:-n}" reply hint="y/N"
  [[ "$default" == "y" ]] && hint="Y/n"

  if [[ "${DOTFILES_ASSUME_YES:-false}" == "true" ]]; then
    log::debug "auto-confirm (--yes): $prompt"
    return 0
  fi

  if ! ui::has_tty; then
    log::warn "No terminal available; defaulting to '$default' for: $prompt"
    [[ "$default" == "y" ]]
    return $?
  fi

  while true; do
    if ! read -r -p "? $prompt [$hint] " reply < /dev/tty > /dev/tty 2>&1; then
      echo
      log::warn "Input closed; assuming '$default'"
      [[ "$default" == "y" ]]
      return $?
    fi
    reply="${reply:-$default}"
    case "$reply" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo])      return 1 ;;
      *) echo "Please answer y or n." > /dev/tty ;;
    esac
  done
}

# ui::danger <headline> <detail-line...>
ui::danger() {
  local headline="$1"; shift
  log::warn "──────────────────────────────────────────────────────────"
  log::warn "DANGER: $headline"
  local line
  for line in "$@"; do log::warn "  $line"; done
  log::warn "──────────────────────────────────────────────────────────"
}
