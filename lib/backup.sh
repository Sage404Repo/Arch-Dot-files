#!/usr/bin/env bash
# =============================================================================
# lib/backup.sh — safe, timestamped backups before any existing file is
# touched. Nothing this installer does is ever destructive: files are always
# *moved* into DOTFILES_BACKUP_DIR, never deleted.
#
# Depends on: lib/log.sh
# =============================================================================

# backup::file <target> <intended_link_source>
#
# No-op if <target> doesn't exist, or if it's already the correct symlink
# from a previous run of this installer.
backup::file() {
  local target="$1" intended_source="$2"

  [[ -e "$target" || -L "$target" ]] || return 0

  if [[ -L "$target" ]] && [[ "$(readlink -f -- "$target" 2>/dev/null)" == "$(readlink -f -- "$intended_source")" ]]; then
    return 0
  fi

  local rel="${target#"$HOME"/}"
  local dest="$DOTFILES_BACKUP_DIR/$rel"
  mkdir -p -- "$(dirname -- "$dest")"

  log::warn "Backing up existing file: $target -> $dest"
  if [[ "${DOTFILES_DRY_RUN:-false}" == "true" ]]; then
    log::info "[dry-run] no file was actually moved"
    return 0
  fi
  mv -- "$target" "$dest"
}
