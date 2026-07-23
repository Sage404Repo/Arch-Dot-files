#!/usr/bin/env bash
# =============================================================================
# lib/log.sh — minimal "Logger" module.
#
# Bash has no classes, so this is written as a single piece of module-level
# state (the log file path + whether the terminal supports color) guarded
# behind a small function API — the same shape a Logger *singleton* would
# have in an OOP language: one shared instance, initialized once via
# log::init, used everywhere else through its public methods only.
#
# Public API:
#   log::init  <logfile>      initialize (idempotent, creates parent dirs)
#   log::file                 print the active log file path
#   log::info  <message...>   normal progress message
#   log::ok    <message...>   success message
#   log::warn  <message...>   warning (stderr + log)
#   log::error <message...>   error (stderr + log)
#   log::step  <message...>   section banner
#   log::debug <message...>   only echoed to stdout when DOTFILES_VERBOSE=true
# =============================================================================

_LOG_FILE=""
_LOG_COLOR=0
[[ -t 1 ]] && _LOG_COLOR=1

log::init() {
  _LOG_FILE="$1"
  mkdir -p -- "$(dirname -- "$_LOG_FILE")"
  {
    echo "==================================================================="
    echo "Arch-Dot-files-Fork setup — $(date -Iseconds 2>/dev/null || date)"
    echo "==================================================================="
  } >> "$_LOG_FILE"
}

log::file() { printf '%s\n' "$_LOG_FILE"; }

# --- internals ---------------------------------------------------------------

_log_write() {
  local level="$1"; shift
  [[ -n "$_LOG_FILE" ]] && printf '[%s] [%s] %s\n' "$(date '+%H:%M:%S')" "$level" "$*" >> "$_LOG_FILE"
}

_log_color() {
  local code="$1"; shift
  if [[ "$_LOG_COLOR" -eq 1 ]]; then
    printf '\033[%sm%s\033[0m\n' "$code" "$*"
  else
    printf '%s\n' "$*"
  fi
}

# --- public levels -------------------------------------------------------------

log::info()  { _log_color "0"    "  $*";  _log_write "INFO"  "$*"; }
log::ok()    { _log_color "0;32" "✔ $*";  _log_write "OK"    "$*"; }
log::warn()  { _log_color "0;33" "⚠ $*" >&2; _log_write "WARN"  "$*"; }
log::error() { _log_color "0;31" "✖ $*" >&2; _log_write "ERROR" "$*"; }
log::step()  { printf '\n'; _log_color "1;36" "==> $*"; _log_write "STEP" "$*"; }

log::debug() {
  _log_write "DEBUG" "$*"
  [[ "${DOTFILES_VERBOSE:-false}" == "true" ]] && _log_color "0;90" "  · $*"
  return 0
}
