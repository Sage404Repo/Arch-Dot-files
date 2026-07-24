#!/usr/bin/env bash
# =============================================================================
# setup.sh — installer for Tristan-Phillips/Arch-Dot-files-Fork
#
#   curl -fsSL https://raw.githubusercontent.com/Tristan-Phillips/Arch-Dot-files-Fork/main/setup.sh | bash
#
# Safe to re-run. Safe to Ctrl-C at any point. Existing files are backed up,
# never deleted. Nothing is installed without you being told what and why.
#
# All tunables live in setup.conf (tracked) / setup.conf.local (git-ignored,
# personal overrides) — see README.md for full documentation.
#
# Flags:
#   -y, --yes          assume "yes" on every prompt (non-interactive)
#   -n, --dry-run      show what would happen, change nothing
#   -v, --verbose      print extra debug information
#       --no-menu      skip the interactive menu even on a real terminal
#       --list-whitelist  print the configured app-launcher whitelist and exit
#   -h, --help         show this help and exit
# =============================================================================
set -Eeuo pipefail

# --- Sanity assertions (fail fast, with a clear reason, before ANYTHING else)-
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "error: do not run setup.sh as root/sudo — it resolves paths from \$HOME," >&2
  echo "       which would be /root instead of your account. sudo is invoked" >&2
  echo "       automatically, only for the specific pacman commands that need it." >&2
  exit 1
fi

if [[ -z "${HOME:-}" || ! -d "${HOME:-/nonexistent}" ]]; then
  echo "error: \$HOME is not set to a valid, existing directory — aborting." >&2
  exit 1
fi

DOTFILES_REPO_URL_DEFAULT="https://github.com/Tristan-Phillips/Arch-Dot-files-Fork.git"
DOTFILES_CLONE_DIR_DEFAULT="$HOME/.local/share/arch-dotfiles-fork"

# --- Resolve where *this* script actually lives (bootstrap if curled) -------
# When curled straight into bash, BASH_SOURCE[0] isn't a real file with
# sibling lib/ modules — so we bootstrap: clone the full repo, then re-exec
# the real setup.sh from inside that clone. From a normal `git clone`, we
# just use the directory we're already sitting in.
_self="${BASH_SOURCE[0]:-}"
if [[ -n "$_self" && -f "$_self" ]] && [[ -d "$(cd -- "$(dirname -- "$_self")" && pwd)/lib" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$_self")" && pwd)"
else
  echo "==> Bootstrapping: fetching Arch-Dot-files-Fork..."
  clone_dir="${DOTFILES_CLONE_DIR:-$DOTFILES_CLONE_DIR_DEFAULT}"
  repo_url="${DOTFILES_REPO_URL:-$DOTFILES_REPO_URL_DEFAULT}"

  if ! command -v git &>/dev/null; then
    echo "error: git is required but not installed. Install it first: sudo pacman -S --needed git" >&2
    exit 1
  fi

  # Small self-contained retry (lib/net.sh isn't available yet at this
  # point — it lives inside the repo we're about to clone).
  _bootstrap_retry() {
    local max=3 attempt=1 delay=2
    while (( attempt <= max )); do
      "$@" && return 0
      (( attempt == max )) && return 1
      echo "    retrying in ${delay}s (attempt $attempt/$max)..." >&2
      sleep "$delay"; delay=$(( delay * 2 )); (( attempt++ ))
    done
  }

  if [[ -d "$clone_dir/.git" ]]; then
    echo "==> Existing clone found at $clone_dir, updating..."
    if ! _bootstrap_retry git -C "$clone_dir" pull --ff-only; then
      echo "error: failed to update existing clone at $clone_dir (network drop?). Re-run setup.sh to retry." >&2
      exit 1
    fi
  else
    if [[ -z "$clone_dir" || "$clone_dir" != /* || "$clone_dir" == "/" ]]; then
      echo "error: unsafe DOTFILES_CLONE_DIR: '$clone_dir' (refusing to rm -rf)" >&2
      exit 1
    fi
    rm -rf -- "$clone_dir"   # clear out any stale/partial non-git leftovers
    if ! _bootstrap_retry git clone --depth 1 "$repo_url" "$clone_dir"; then
      echo "error: failed to clone $repo_url (network drop?). Cleaning up and exiting — just re-run to retry." >&2
      rm -rf -- "$clone_dir"
      exit 1
    fi
  fi

  echo "==> Continuing from $clone_dir/setup.sh"
  exec "$clone_dir/setup.sh" "$@"
fi

# --- Load configuration -------------------------------------------------------
# shellcheck source=setup.conf
source "$SCRIPT_DIR/setup.conf"
if [[ -f "$SCRIPT_DIR/setup.conf.local" ]]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/setup.conf.local"
fi

# --- Load library modules -----------------------------------------------------
for _lib in log ui net pkg deps backup link menu whitelist wallpaperconf; do
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/lib/${_lib}.sh"
done
unset _lib _self

# --- CLI flags -----------------------------------------------------------------
_explicit_noninteractive=false
_no_menu=false

usage() {
  sed -n '2,20p' "$SCRIPT_DIR/setup.sh" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)     DOTFILES_ASSUME_YES=true; _explicit_noninteractive=true ;;
    -n|--dry-run) DOTFILES_DRY_RUN=true;    _explicit_noninteractive=true ;;
    -v|--verbose) DOTFILES_VERBOSE=true ;;
    --no-menu)    _no_menu=true ;;
    --list-whitelist) whitelist::print; exit 0 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# --- Logging + signal handling -------------------------------------------------
log::init "$DOTFILES_LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

_interrupted=false
on_interrupt() { _interrupted=true; exit 130; }
trap on_interrupt INT TERM

on_err() {
  local code=$? line=$1
  # Only fires for genuinely unhandled failures — every anticipated failure
  # path in lib/*.sh already returns a clean, non-zero status inside an
  # `if`/`||`, which is exempt from triggering this trap.
  log::error "Unexpected failure at setup.sh:$line (exit $code)."
}
trap 'on_err $LINENO' ERR

cleanup() {
  local code=$?
  menu::_restore_terminal 2>/dev/null || true   # never leave the cursor hidden
  if [[ "$_interrupted" == "true" ]]; then
    log::warn "Cancelled by user. No further changes were made."
    log::warn "Anything already backed up is safe under: $DOTFILES_BACKUP_DIR"
    exit 130
  elif [[ $code -ne 0 ]]; then
    log::error "Setup did not complete (exit $code). Full log: $(log::file)"
  fi
}
trap cleanup EXIT

# ==============================================================================
# run_pipeline — the actual install steps ("Template Method": the sequence
# is fixed here; each step's real behavior lives in the matching lib/*.sh).
# ==============================================================================
run_pipeline() {
  log::step "Arch-Dot-files-Fork setup"
  log::info "Repo:   $SCRIPT_DIR"
  log::info "Target: $DOTFILES_TARGET_HOME"
  log::info "Log:    $(log::file)"
  [[ "$DOTFILES_DRY_RUN" == "true" ]] && log::warn "Dry-run mode: no files or packages will actually change."

  log::step "Resolving dependencies"
  if ! deps::resolve; then
    log::error "Dependency resolution failed or was aborted."
    return 1
  fi

  log::step "Syncing config-driven files"
  whitelist::render "$SCRIPT_DIR/~/.config/quickshell/common/Whitelist.qml"
  wallpaperconf::render "$DOTFILES_TARGET_HOME/.config/quickshell/wallpaper/monitors.conf" "$DOTFILES_TARGET_HOME"

  log::step "Linking dotfiles"
  ui::danger "About to link config files into \$HOME" \
    "Existing files at the same paths are MOVED (never deleted) to:" \
    "  $DOTFILES_BACKUP_DIR"
  if ! ui::confirm "Proceed with linking?" y; then
    log::info "Linking skipped by user request."
    return 0
  fi

  if ! link::run "$SCRIPT_DIR/~" "$DOTFILES_TARGET_HOME"; then
    log::warn "Some files could not be linked — see the errors above and the log."
    return 1
  fi

  log::step "Done"
  log::ok "Setup complete."
  log::info "Log saved to: $(log::file)"
  log::info "Restart Hyprland (or log out/in) for all changes to take effect."
  return 0
}

# --- Interactive menu (real actions only — nothing here is decorative) -------
configure_optional_packages() {
  local -a all=("${DOTFILES_OPTIONAL_PKGS[@]}" "${DOTFILES_AUR_PKGS[@]}")
  if (( ${#all[@]} == 0 )); then
    clear; log::info "No optional/AUR packages are configured."; menu::pause; return
  fi

  local selection status
  selection="$(menu::multiselect "Select optional/AUR packages to install this run" "${all[@]}")"
  status=$?
  if (( status != 0 )); then
    clear; log::info "Selection cancelled; configuration unchanged."; menu::pause; return
  fi

  local -a chosen=()
  [[ -n "$selection" ]] && mapfile -t chosen <<< "$selection"

  # Real effect: filters the exact arrays deps::resolve installs from, for
  # the remainder of this run.
  local -a new_opt=() new_aur=() pkg pick
  for pkg in "${DOTFILES_OPTIONAL_PKGS[@]}"; do
    for pick in "${chosen[@]}"; do [[ "$pkg" == "$pick" ]] && { new_opt+=("$pkg"); break; }; done
  done
  for pkg in "${DOTFILES_AUR_PKGS[@]}"; do
    for pick in "${chosen[@]}"; do [[ "$pkg" == "$pick" ]] && { new_aur+=("$pkg"); break; }; done
  done
  DOTFILES_OPTIONAL_PKGS=("${new_opt[@]}")
  DOTFILES_AUR_PKGS=("${new_aur[@]}")

  clear
  log::ok "Selection applied for this run: ${chosen[*]:-<none>}"
  log::info "This only affects this run. Add DOTFILES_OPTIONAL_PKGS=(...) to setup.conf.local to make it permanent."
  menu::pause
}

interactive_menu() {
  local choice
  while true; do
    choice="$(menu::select "What would you like to do?" \
      "Install / update dotfiles" \
      "Dry run (preview only, no changes)" \
      "Configure optional packages" \
      "View whitelisted apps" \
      "View log & backup locations" \
      "Quit")" || { clear; log::info "Cancelled."; exit 0; }

    case "$choice" in
      "Install / update dotfiles")
        DOTFILES_DRY_RUN=false
        clear
        run_pipeline || true
        menu::pause "Press any key to return to the menu..."
        ;;
      "Dry run (preview only, no changes)")
        DOTFILES_DRY_RUN=true
        clear
        run_pipeline || true
        menu::pause "Press any key to return to the menu..."
        ;;
      "Configure optional packages")
        configure_optional_packages
        ;;
      "View whitelisted apps")
        clear
        menu::_banner
        printf '\n  Launcher whitelist (edit in setup.conf / setup.conf.local):\n\n'
        whitelist::print | sed 's/^/    /'
        printf '\n'
        menu::pause
        ;;
      "View log & backup locations")
        clear
        menu::_banner
        printf '\n  Log file:   %s\n'   "$(log::file)"
        printf   '  Backup dir: %s\n'   "$DOTFILES_BACKUP_DIR"
        printf   '  Repo clone: %s\n\n' "$SCRIPT_DIR"
        menu::pause
        ;;
      "Quit")
        clear
        log::info "Goodbye."
        exit 0
        ;;
    esac
  done
}

# ==============================================================================
# Entry point
# ==============================================================================
if ui::has_tty && [[ "$_explicit_noninteractive" != "true" ]] && [[ "$_no_menu" != "true" ]]; then
  interactive_menu
else
  run_pipeline || exit 1
fi
