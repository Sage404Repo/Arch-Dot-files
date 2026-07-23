import QtQuick

// Single shared theme definition, used by every Quickshell module
// (applauncher, notifications, wallpaper, media) via:
//   import "../common/Theme.qml" as Theme
//   property var theme: Theme {}
//
// This replaces three near-identical, drifting per-module DefaultTheme.qml
// copies (which had accidentally left debug/placeholder colors such as
// "#ff0000" and unreadable "#000000-on-#000000" text). Edit colors here
// once and every module picks up the change.
QtObject {
  // --- Surfaces ---------------------------------------------------------
  readonly property color bgBase: "#e6141414"     // panel / card background
  readonly property color bgSurface: "#0d0d0d"    // search boxes, chips, buttons
  readonly property color bgOverlay: Qt.rgba(0.0, 0.0, 0.0, 0.65) // full-screen dim backdrop
  readonly property color bgHover: "#26ffffff"    // hover state (translucent white)
  readonly property color bgSelected: "#33ffffff" // selected/highlighted row
  readonly property color bgBorder: "#26ffffff"   // hairline borders

  readonly property color searchBase: bgSurface
  readonly property color searchAccent: accentPrimary

  // --- Text ---------------------------------------------------------------
  readonly property color textPrimary: "#ffffff"
  readonly property color textSecondary: "#cccccc"
  readonly property color textMuted: "#8a8a8a"

  // --- Accents --------------------------------------------------------------
  readonly property color accentPrimary: "#ffffff"
  readonly property color accentCyan: "#7dcfff"
  readonly property color accentGreen: "#9ece6a"
  readonly property color accentOrange: "#ff9e64"
  readonly property color accentRed: "#f7768e"

  // --- Semantic aliases -----------------------------------------------------
  readonly property color urgencyLow: textMuted
  readonly property color urgencyNormal: accentPrimary
  readonly property color urgencyCritical: accentRed
  readonly property color batteryGood: accentGreen
  readonly property color batteryWarning: accentOrange
  readonly property color batteryCritical: accentRed
}
