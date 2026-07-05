import QtQuick

QtObject {
  readonly property color bgBase: "#000000" //Background
  readonly property color bgSurface: "#000000" //Bar Background
  readonly property color bgOverlay: "#ff0000"
  readonly property color bgHover: "#ff0000"
  readonly property color bgSelected: "#ff0000"
  readonly property color bgBorder: "#000000"

  readonly property color textPrimary: "#ffffff"
  readonly property color textSecondary: "#ff0000"
  readonly property color textMuted: "#000000"

  readonly property color accentPrimary: "#ffffff"
  readonly property color accentCyan: "#7dcfff"
  readonly property color accentGreen: "#9ece6a"
  readonly property color accentOrange: "#ff9e64"
  readonly property color accentRed: "#f7768e"

  readonly property color urgencyLow: textMuted
  readonly property color urgencyNormal: accentPrimary
  readonly property color urgencyCritical: accentRed
  readonly property color batteryGood: accentGreen
  readonly property color batteryWarning: accentOrange
  readonly property color batteryCritical: accentRed

}
