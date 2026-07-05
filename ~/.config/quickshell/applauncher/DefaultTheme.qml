import QtQuick

QtObject {
  readonly property color bgBase: "#00000000" //Box Background
  readonly property color bgSurface: "#000000" //Searchbox and buttons
  readonly property color bgOverlay: Qt.rgba(0.0,0.0,0.0,0.9) //Screen dim
  readonly property color bgHover: "#99000000" //Hover ?
  readonly property color bgSelected: "#99000000" //Select
  readonly property color bgBorder: "#00000000" //Outer border

  readonly property color textPrimary: "#ffffff"
  readonly property color textSecondary: "#ffffff"
  readonly property color textMuted: "#ffffff"

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
