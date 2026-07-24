#!/usr/bin/env bash
# =============================================================================
# lib/link.sh — links individual files from the repo's `~/` tree onto the
# real $HOME.
#
# Deliberately file-level, never directory-level: only files that actually
# exist in this repo are ever symlinked, and every parent directory along
# the way is a real, plain directory (mkdir -p). That means pre-existing,
# unrelated content anywhere under e.g. ~/.config or ~/Pictures is never
# hidden or replaced by symlinking a whole directory over it.
#
# Paths are resolved purely from $HOME / the target dir passed in — nothing
# here is hardcoded to a particular username or machine.
#
# Depends on: lib/log.sh, lib/backup.sh
# =============================================================================

# link::_is_ensured_dir <relative-path>
# True if <relative-path> is configured (DOTFILES_ENSURE_DIRS) to be created
# as a real, empty directory instead of linked — used for paths that are
# personal user data (e.g. a wallpapers folder) and only exist in the repo
# as an empty placeholder marker.
link::_is_ensured_dir() {
  local rel="$1" d
  for d in "${DOTFILES_ENSURE_DIRS[@]}"; do
    [[ "$rel" == "$d" ]] && return 0
  done
  return 1
}

# link::run <repo_home_dir> <real_home_dir>
#
# A failure on any single file (permissions, a backup that can't be moved,
# etc.) is logged and that file is skipped — it does not abort the whole
# run. The function still reports overall failure (non-zero) at the end if
# anything was skipped, so setup.sh can tell the user clearly rather than
# silently declaring success.
link::run() {
  local src_root="$1" dst_root="$2"
  local -i linked=0 ensured=0 skipped=0 failed=0
  local src rel dst

  if [[ ! -d "$src_root" ]]; then
    log::error "Expected dotfiles source directory not found: $src_root"
    return 1
  fi

  while IFS= read -r -d '' src; do
    rel="${src#"$src_root"/}"
    dst="$dst_root/$rel"

    if link::_is_ensured_dir "$rel"; then
      log::info "Ensuring real directory (user data, not linked): \$HOME/$rel"
      if [[ "${DOTFILES_DRY_RUN:-false}" != "true" ]] && ! mkdir -p -- "$dst" 2>/dev/null; then
        log::error "Could not create \$HOME/$rel (check permissions); skipping."
        (( failed++ ))
        continue
      fi
      (( ensured++ ))
      continue
    fi

    if [[ -L "$dst" ]] && [[ "$(readlink -f -- "$dst" 2>/dev/null)" == "$(readlink -f -- "$src")" ]]; then
      log::debug "Already linked: \$HOME/$rel"
      (( skipped++ ))
      continue
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
      if ! backup::file "$dst" "$src"; then
        log::error "Could not back up \$HOME/$rel; leaving it untouched and skipping this file."
        (( failed++ ))
        continue
      fi
    fi

    if ! mkdir -p -- "$(dirname -- "$dst")" 2>/dev/null; then
      log::error "Could not create parent directory for \$HOME/$rel; skipping."
      (( failed++ ))
      continue
    fi

    log::info "Linking \$HOME/$rel"
    if [[ "${DOTFILES_DRY_RUN:-false}" != "true" ]] && ! ln -s -- "$src" "$dst" 2>/dev/null; then
      log::error "Failed to create symlink for \$HOME/$rel; skipping."
      (( failed++ ))
      continue
    fi
    (( linked++ ))
  done < <(find "$src_root" -type f -print0)

  if (( failed > 0 )); then
    log::warn "Linked $linked file(s), ensured $ensured real dir(s), $skipped already up to date, $failed FAILED — see errors above."
    return 1
  fi

  log::ok "Linked $linked file(s), ensured $ensured real dir(s), $skipped already up to date."
}
