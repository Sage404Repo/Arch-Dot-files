#!/usr/bin/env bash
#
# Round-robins the default PipeWire audio sink between a small configured
# set of devices (bound to the media-play key in hyprland.conf).
#
# --- Configuration ------------------------------------------------------
# The original version of this script hardcoded two PipeWire object IDs
# (51 and 52). Those IDs are assigned by PipeWire/WirePlumber at runtime
# and are NOT stable across reboots or device reconnects, so the script
# would silently stop working on any other boot or machine.
#
# Configure this two ways:
#
#   1) A config file at ~/.config/hypr/audioswitch.conf (recommended —
#      this is the only way that reliably works when the script is run
#      from the Hyprland keybind in hyprland.conf, since Hyprland's `exec`
#      does NOT inherit environment variables merely exported in your
#      shell's rc file — only real config or `env = ...` lines in
#      hyprland.conf itself reach it):
#         echo 'AUDIOSWITCH_SINK_NAMES="Razer,Speaker"' > ~/.config/hypr/audioswitch.conf
#
#   2) Environment variables — convenient for testing from a terminal, but
#      NOT visible to the Hyprland-triggered keybind:
#         AUDIOSWITCH_SINK_NAMES="Razer,Speaker" ~/.config/hypr/audioswitch.sh
#
#   Match by (partial, case-insensitive) name with AUDIOSWITCH_SINK_NAMES
#   (recommended — stable across reboots), or by fixed PipeWire ID with
#   AUDIOSWITCH_SINK_IDS (legacy behaviour; IDs can change on reconnect).
#
# Run with --list to print all currently available sinks (ID + name) so
# you can pick the right values for your machine.
#
# If neither is configured anywhere, the script cycles through ALL
# currently available sinks — a safe, universal default that works on any
# machine out of the box, rather than silently failing because nobody
# configured anything yet.
: "${AUDIOSWITCH_SINK_NAMES:=}"
: "${AUDIOSWITCH_SINK_IDS:=}"

_config_file="${AUDIOSWITCH_CONFIG:-$HOME/.config/hypr/audioswitch.conf}"
# shellcheck disable=SC1090
[[ -f "$_config_file" ]] && source "$_config_file"

set -uo pipefail

usage() {
  cat <<'EOF'
Usage: audioswitch.sh [--list|-l] [--help|-h]

Cycles the default PipeWire audio sink between the devices configured via
the AUDIOSWITCH_SINK_NAMES or AUDIOSWITCH_SINK_IDS environment variables.

  --list, -l   List available sinks (ID + name) and exit.
  --help, -h   Show this help and exit.
EOF
}

notify() {
  # notify-send may not be installed on minimal setups; don't hard-fail.
  command -v notify-send &>/dev/null && notify-send "$@"
  return 0
}

die() {
  echo "audioswitch: error: $*" >&2
  notify "Audio Error" "$*"
  exit 1
}

check_dependencies() {
  if ! command -v wpctl &>/dev/null && ! command -v pactl &>/dev/null; then
    die "Neither wpctl nor pactl found. Install pipewire/pipewire-pulse."
  fi
}

# Clean, printable wpctl status output with box-drawing characters removed.
clean_status() {
  wpctl status | tr -cd '[:print:]\n' | sed 's/[^a-zA-Z0-9 .*()\[\]_-]//g'
}

# Print "<id> <name>" for every sink currently known to wpctl (falls back
# to pactl if wpctl's Sinks section can't be parsed).
list_sinks() {
  local clean rows
  clean=$(clean_status)
  rows=$(echo "$clean" | awk '
    /^[ ]*Sinks:/ { insink=1; next }
    /^[ ]*Sources:/ { insink=0 }
    insink && /^\*?[ ]*[0-9]+\./ {
      line=$0
      gsub(/^[ ]*\*?[ ]*/, "", line)
      sub(/\./, " ", line)
      print line
    }
  ')

  if [ -n "$rows" ]; then
    echo "$rows"
    return 0
  fi

  command -v pactl &>/dev/null && pactl list sinks short 2>/dev/null | awk '{$1=$1; print $1, $2}'
}

# Resolve a comma/space-separated list of name patterns to currently-valid
# sink IDs, in the order the patterns were given, skipping any pattern that
# doesn't currently match a sink.
resolve_ids_by_name() {
  local patterns_raw="$1"
  local -a patterns
  IFS=', ' read -r -a patterns <<< "$patterns_raw"

  local sinks
  sinks=$(list_sinks)

  local pattern id
  for pattern in "${patterns[@]}"; do
    [ -z "$pattern" ] && continue
    id=$(echo "$sinks" | grep -i -- "$pattern" | head -1 | awk '{print $1}')
    if [ -n "$id" ]; then
      echo "$id"
    else
      echo "Warning: no sink currently matches name pattern '$pattern', skipping..." >&2
    fi
  done
}

main() {
  case "${1:-}" in
    --list|-l)
      check_dependencies
      list_sinks
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    "") ;;
    *)
      usage >&2
      die "Unknown argument: $1"
      ;;
  esac

  check_dependencies

  local -a sink_list=()
  if [ -n "$AUDIOSWITCH_SINK_NAMES" ]; then
    mapfile -t sink_list < <(resolve_ids_by_name "$AUDIOSWITCH_SINK_NAMES")
  elif [ -n "$AUDIOSWITCH_SINK_IDS" ]; then
    local -a all_sinks target_ids
    mapfile -t all_sinks < <(list_sinks | awk '{print $1}')
    read -r -a target_ids <<< "$AUDIOSWITCH_SINK_IDS"

    local id found sink_id
    for id in "${target_ids[@]}"; do
      found=false
      for sink_id in "${all_sinks[@]}"; do
        if [[ "$sink_id" == "$id" ]]; then
          sink_list+=("$id")
          found=true
          break
        fi
      done
      [ "$found" = false ] && echo "Warning: sink $id not found on system, skipping..." >&2
    done
  else
    # Nothing configured anywhere (no audioswitch.conf, no env vars): fall
    # back to cycling through every currently available sink. This is what
    # makes the script actually useful out of the box on a fresh machine,
    # instead of failing with "no sinks available" until someone edits a
    # config for hardware it can't know about in advance.
    mapfile -t sink_list < <(list_sinks | awk '{print $1}')
    if [ ${#sink_list[@]} -gt 0 ]; then
      echo "Note: no sinks configured (see the header of this script); cycling through all ${#sink_list[@]} available sink(s)." >&2
    fi
  fi

  if [ ${#sink_list[@]} -eq 0 ]; then
    die "No configured sinks are currently available. Run with --list to see valid options."
  fi

  local current
  current=$(pactl get-default-sink 2>/dev/null || true)
  if [ -z "$current" ] || ! [[ "$current" =~ ^[0-9]+$ ]]; then
    # pactl may report a sink name rather than a numeric ID; fall back to
    # detecting the wpctl-marked default (the line starting with '*').
    current=$(clean_status | awk '
      /^[ ]*Sinks:/ { insink=1; next }
      /^[ ]*Sources:/ { insink=0 }
      insink && /^\*/ { gsub(/[^0-9]/, "", $2); if ($2 != "") { print $2; exit } }
    ')
  fi

  if [ -z "$current" ] || ! [[ "$current" =~ ^[0-9]+$ ]]; then
    current=${sink_list[0]}
    echo "Warning: could not detect current sink, assuming ${current}" >&2
  fi

  local index=-1 i
  for i in "${!sink_list[@]}"; do
    if [[ "${sink_list[$i]}" == "$current" ]]; then
      index=$i
      break
    fi
  done

  local next
  if [ "$index" -eq -1 ]; then
    next=${sink_list[0]}
  else
    next=${sink_list[$(( (index + 1) % ${#sink_list[@]} ))]}
  fi

  wpctl set-default "$next" || die "Failed to set default sink to $next"

  local name
  name=$(list_sinks | grep -E "^$next " | head -1 | cut -d' ' -f2-)
  [ -z "$name" ] && name="Sink $next"

  echo "Switched default audio sink: $current -> $next ($name)"
  notify "Audio Switched" "To: $name (ID: $next)"
}

main "$@"