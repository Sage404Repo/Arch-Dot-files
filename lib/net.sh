#!/usr/bin/env bash
# =============================================================================
# lib/net.sh — connectivity probing + retry-with-backoff wrapper.
#
# Used to make the installer resilient to a network drop mid-run: instead of
# a single pacman/git/curl call failing the whole install, network-dependent
# steps are wrapped in net::retry, which retries with exponential backoff and
# gives up early (with a clear message) if the machine is fully offline.
#
# Depends on: lib/log.sh
# =============================================================================

# net::online — cheap reachability probe. Never fatal by itself.
net::online() {
  curl -fsS --max-time 4 -o /dev/null https://archlinux.org 2>/dev/null && return 0
  curl -fsS --max-time 4 -o /dev/null https://github.com 2>/dev/null && return 0
  return 1
}

# net::retry <max_attempts> <description> -- <command...>
net::retry() {
  local max="$1" desc="$2"; shift 2
  [[ "${1:-}" == "--" ]] && shift

  local attempt=1 delay=2
  while (( attempt <= max )); do
    log::debug "[$desc] attempt $attempt/$max: $*"
    if "$@"; then
      return 0
    fi

    if ! net::online; then
      log::error "[$desc] network appears to be down. Check your connection and re-run setup.sh."
      return 1
    fi

    if (( attempt == max )); then
      log::error "[$desc] failed after $max attempts."
      return 1
    fi

    log::warn "[$desc] failed (attempt $attempt/$max). Retrying in ${delay}s..."
    sleep "$delay"
    delay=$(( delay * 2 ))
    (( attempt++ ))
  done
  return 1
}
