#!/usr/bin/env bash
# =============================================================================
# lib/menu.sh — pure-bash interactive TTY menu (no dialog/whiptail/fzf
# dependency, so it works on a completely fresh system with nothing but
# bash + ncurses' `tput`, which Arch ships by default).
#
# Reads raw keys from /dev/tty specifically (not stdin) so it keeps working
# under `curl -fsSL ... | bash`, where stdin is occupied by the script's own
# source.
#
# Every screen here drives real state used by setup.sh — there is no purely
# decorative option: selections change DOTFILES_DRY_RUN, filter the actual
# package arrays deps::resolve installs from, or print real, live paths
# (log file, backup dir) read straight from the modules that own them.
#
# Depends on: lib/log.sh, lib/ui.sh
# =============================================================================

_MENU_CANCELLED=1

menu::_restore_terminal() {
  tput cnorm 2>/dev/null || true
}

menu::_banner() {
  local cols width
  cols="$(tput cols 2>/dev/null || echo 80)"
  width=$(( cols < 60 ? cols : 60 ))
  printf '\033[1;35m'
  printf '%*s\n' "$width" '' | tr ' ' '='
  printf '  Arch-Dot-files-Fork installer\n'
  printf '%*s\n' "$width" '' | tr ' ' '='
  printf '\033[0m\n'
}

# menu::_read_key — blocks for exactly one keypress on /dev/tty and prints
# a normalized name: UP, DOWN, ENTER, SPACE, QUIT, or the raw character.
menu::_read_key() {
  local key rest
  IFS= read -rsn1 key < /dev/tty
  if [[ "$key" == $'\x1b' ]]; then
    IFS= read -rsn2 -t 0.05 rest < /dev/tty
    key+="$rest"
  fi
  case "$key" in
    $'\x1b[A') printf 'UP\n' ;;
    $'\x1b[B') printf 'DOWN\n' ;;
    "")        printf 'ENTER\n' ;;
    " ")       printf 'SPACE\n' ;;
    q|Q|$'\x1b') printf 'QUIT\n' ;;
    *)         printf '%s\n' "$key" ;;
  esac
}

# menu::select <title> <option...>
# Prints the chosen option text on stdout and returns 0, or returns 1
# (nothing printed) if the user cancelled with q/Esc.
# Falls back to auto-picking the first option when no tty is reachable, so
# callers never hang in a non-interactive context.
menu::select() {
  local title="$1"; shift
  local -a options=("$@")
  local n=${#options[@]} selected=0 i key

  if ! ui::has_tty; then
    log::debug "menu::select '$title': no tty, defaulting to '${options[0]}'"
    printf '%s\n' "${options[0]}"
    return 0
  fi

  tput civis 2>/dev/null || true
  while true; do
    clear
    menu::_banner
    printf '  %s\n\n' "$title"
    for i in "${!options[@]}"; do
      if [[ $i -eq $selected ]]; then
        printf '  \033[1;36m> %s\033[0m\n' "${options[$i]}"
      else
        printf '    %s\n' "${options[$i]}"
      fi
    done
    printf '\n  Up/Down move   Enter select   q quit\n'

    key="$(menu::_read_key)"
    case "$key" in
      UP)    selected=$(( (selected - 1 + n) % n )) ;;
      DOWN)  selected=$(( (selected + 1) % n )) ;;
      ENTER) menu::_restore_terminal; printf '%s\n' "${options[$selected]}"; return 0 ;;
      QUIT)  menu::_restore_terminal; return "$_MENU_CANCELLED" ;;
    esac
  done
}

# menu::multiselect <title> <option...>
# Prints each chosen option on its own line (possibly zero lines) and
# returns 0, or returns 1 if the user cancelled. Everything starts checked,
# since that mirrors setup.conf's default (install everything configured).
menu::multiselect() {
  local title="$1"; shift
  local -a options=("$@")
  local -a checked=()
  local n=${#options[@]} cursor=0 i key

  if ! ui::has_tty; then
    log::debug "menu::multiselect '$title': no tty, selecting all"
    printf '%s\n' "${options[@]}"
    return 0
  fi

  for (( i = 0; i < n; i++ )); do checked[i]=1; done

  tput civis 2>/dev/null || true
  while true; do
    clear
    menu::_banner
    printf '  %s\n' "$title"
    printf '  (Space toggle, Enter confirm, q cancel)\n\n'
    for i in "${!options[@]}"; do
      local box="[ ]"
      [[ "${checked[$i]}" == 1 ]] && box="[x]"
      if [[ $i -eq $cursor ]]; then
        printf '  \033[1;36m> %s %s\033[0m\n' "$box" "${options[$i]}"
      else
        printf '    %s %s\n' "$box" "${options[$i]}"
      fi
    done

    key="$(menu::_read_key)"
    case "$key" in
      UP)    cursor=$(( (cursor - 1 + n) % n )) ;;
      DOWN)  cursor=$(( (cursor + 1) % n )) ;;
      SPACE) [[ "${checked[$cursor]}" == 1 ]] && checked[cursor]=0 || checked[cursor]=1 ;;
      ENTER)
        menu::_restore_terminal
        for i in "${!options[@]}"; do
          [[ "${checked[$i]}" == 1 ]] && printf '%s\n' "${options[$i]}"
        done
        return 0
        ;;
      QUIT) menu::_restore_terminal; return "$_MENU_CANCELLED" ;;
    esac
  done
}

# menu::pause <message> — "press any key to continue"; no-op without a tty.
menu::pause() {
  local msg="${1:-Press any key to continue...}"
  ui::has_tty || return 0
  printf '\n  %s' "$msg"
  IFS= read -rsn1 < /dev/tty
  printf '\n'
}
