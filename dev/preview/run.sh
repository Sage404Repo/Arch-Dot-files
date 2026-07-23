#!/usr/bin/env bash
# =============================================================================
# dev/preview/run.sh — render one of this repo's *real, unmodified* Quickshell
# QML components in an ordinary desktop window, using the shims in
# dev/preview/qmlshim/ instead of the real Quickshell runtime.
#
# Lets you visually sanity-check layout/color/spacing changes without
# Hyprland, without a Wayland compositor, and without installing Quickshell
# itself — only Qt6's own `qml` tool (qt6-declarative) is required, which is
# a common, small, non-invasive dependency (no dotfiles are touched, nothing
# is linked into $HOME).
#
# Usage:
#   dev/preview/run.sh <launcher|notifications|wallpaper|media|shell>
#
# Notes / limitations (visual-only preview, NOT a functional test):
#   - IPC-triggered panels auto-open ~250ms after start (see
#     qmlshim/Quickshell/Io/IpcHandler.qml) since there's no real
#     `qs ipc call` bridge to trigger them by hand here.
#   - The WlrLayershell.layer / .keyboardFocus / .namespace attached-property
#     lines are stripped from a *scratch copy* only (never the tracked repo
#     files) — real wlr-layer-shell attached properties need a C++ plugin
#     that plain QML can't provide. Everything else renders unmodified.
#   - Real IPC, real D-Bus notifications, real MPRIS players, real desktop
#     entries and real wallpaper scanning are NOT exercised; qmlshim feeds
#     each component small, fake sample data instead.
#
# IMPORTANT — logging: on a systemd/journald desktop session, Qt's default
# message handler routes qWarning()/console.warn() (and, critically, QML
# binding errors like "TypeError: ... of undefined") to the journal instead
# of this terminal's stderr whenever stderr isn't a tty (e.g. piped to a
# file/log). That makes broken bindings LOOK clean when they aren't — this
# bit a previous debugging session, which is why this is called out here
# instead of just being fixed silently. QT_ASSUME_STDERR_HAS_CONSOLE=1
# forces Qt to always write to this terminal's stderr regardless.
export QT_ASSUME_STDERR_HAS_CONSOLE=1
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
QUICKSHELL_SRC="$REPO_ROOT/~/.config/quickshell"
SHIM_DIR="$SCRIPT_DIR/qmlshim"

usage() {
  cat <<'EOF'
Usage: dev/preview/run.sh <target>

  launcher       applauncher/AppLauncher.qml
  notifications  notifications/NotificationPopup.qml
  wallpaper      wallpaper/WallpaperManager.qml
  media          media/MediaControl.qml
  shell          shell.qml (all four components at once)
EOF
}

[[ $# -eq 1 ]] || { usage >&2; exit 2; }

case "$1" in
  launcher)      rel="applauncher/AppLauncher.qml" ;;
  notifications) rel="notifications/NotificationPopup.qml" ;;
  wallpaper)     rel="wallpaper/WallpaperManager.qml" ;;
  media)         rel="media/MediaControl.qml" ;;
  shell)         rel="shell.qml" ;;
  -h|--help)     usage; exit 0 ;;
  *) echo "Unknown target: $1" >&2; usage >&2; exit 2 ;;
esac

# Prefer the Qt6-specific binary explicitly. A plain `qml` on PATH may
# resolve to a Qt5 install on some systems (they can coexist), and Qt5's
# QML engine doesn't understand newer syntax like
# `pragma ComponentBehavior: Bound` used in these files — it fails with a
# confusing parse error rather than a clear "wrong Qt version" message.
QML_BIN=""
for candidate in /usr/lib/qt6/bin/qml qml6 qml; do
  if command -v "$candidate" &>/dev/null; then
    QML_BIN="$candidate"
    break
  fi
done

if [[ -z "$QML_BIN" ]]; then
  echo "error: no 'qml' runtime found (looked for /usr/lib/qt6/bin/qml, qml6, qml)." >&2
  echo "       Install Qt6's declarative module, e.g.: sudo pacman -S --needed qt6-declarative" >&2
  exit 1
fi

if [[ "$("$QML_BIN" --version 2>&1)" != *"Qml Runtime 6."* ]]; then
  echo "warning: '$QML_BIN' does not report a Qt6 version; this preview needs Qt6." >&2
fi

if [[ ! -d "$QUICKSHELL_SRC" ]]; then
  echo "error: expected source directory not found: $QUICKSHELL_SRC" >&2
  exit 1
fi

scratch="$(mktemp -d)"
qml_pid=""

cleanup() {
  # If we're being interrupted while qml is still running, stop it FIRST —
  # otherwise removing $scratch out from under a still-running process
  # causes spurious "no such directory" errors on any file it hasn't
  # loaded yet (relative imports resolved lazily, IPC-triggered panels,
  # etc.), rather than a clean shutdown.
  if [[ -n "$qml_pid" ]] && kill -0 "$qml_pid" 2>/dev/null; then
    kill "$qml_pid" 2>/dev/null
    wait "$qml_pid" 2>/dev/null
  fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
# Separate, minimal handler for actual interruption: it must call `exit`
# itself so bash doesn't just resume waiting on the (still foreground)
# qml process afterward — `exit` here is what triggers the EXIT trap
# above to actually run.
trap 'exit 130' INT TERM

cp -r -- "$QUICKSHELL_SRC/." "$scratch/"

# Strip only the wlr-layer-shell attached-property lines (see header note
# above) from the scratch copy — the real, tracked files are never touched.
#
# Also strips the multi-line `anchors { ... }` / `margins { ... }` grouped
# -property blocks PanelWindow uses for boolean screen-edge docking: that's
# a real wlr-layer-shell-only concept with no plain-window equivalent, AND
# (found the hard way) replicating custom grouped-property blocks via a
# property alias hits a genuine Qt 6 QML engine limitation where only the
# LAST member of the group ever binds correctly. Not worth fighting for a
# visual-only preview — every component still centers in an ordinary
# window either way.
find "$scratch" -name '*.qml' -print0 | xargs -0 sed -i \
  -e '/WlrLayershell\.layer:/d' \
  -e '/WlrLayershell\.keyboardFocus:/d' \
  -e '/WlrLayershell\.namespace:/d' \
  -e '/^\s*anchors\s*{\s*$/,/^\s*}\s*$/d' \
  -e '/^\s*margins\s*{\s*$/,/^\s*}\s*$/d'

# A PanelWindow whose stripped `anchors {}` block filled all four screen
# edges (AppLauncher, WallpaperManager) now has no size hint at all and
# defaults to a tiny window — only a corner of the centered content is
# visible. Give the scratch copy a real preview-sized default window;
# components with their own implicitWidth/implicitHeight (e.g.
# MediaControl's compact 360x72 widget) already size correctly and are
# left alone since this only fires once, right after `PanelWindow {`, and
# an explicit width/height would win over implicitWidth if both were
# present — so this is scoped to files with none. Never touches the
# tracked files, scratch copy only.
for f in "$scratch/applauncher/AppLauncher.qml" "$scratch/wallpaper/WallpaperManager.qml"; do
  [[ -f "$f" ]] && sed -i '0,/visible: false/s//visible: false\n    width: 960\n    height: 720/' "$f"
done

# AppLauncher's `model: filteredApps` binds directly to a ScriptModel
# instance, matching real Quickshell's C++-backed ScriptModel (which
# implements a real list-model interface). The shim's ScriptModel.qml
# (see qmlshim/Quickshell/ScriptModel.qml) is plain QML and can't
# replicate that — Qt Quick treats a bare QObject assigned to `model:` as
# a single-row model exposing the object's own properties, not its
# `values` array. Rewriting to `.values` here (scratch-copy only) is the
# pragmatic equivalent of the anchors/margins stripping above: a real,
# C++-only interface that pure QML cannot fake, isolated to one line.
sed -i 's/model: filteredApps$/model: filteredApps.values/' "$scratch/applauncher/AppLauncher.qml" 2>/dev/null || true

echo "==> Previewing $rel with $QML_BIN — close the window (or Ctrl+C here) to stop."
# Backgrounded + waited-on (rather than a plain foreground call) so
# cleanup() above can actually locate and stop this process on a signal;
# see the comment there.
"$QML_BIN" -I "$SHIM_DIR" "$scratch/$rel" &
qml_pid=$!
wait "$qml_pid"
