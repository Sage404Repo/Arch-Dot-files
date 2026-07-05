import QtQuick

QtObject {
  readonly property color bgBase: "#00000000" //Box background
  readonly property color bgSurface: "#ffffff" //Accent colours
  readonly property color bgOverlay:  Qt.rgba(0.0,0.0,0.0,0.9) //Screen dim
  readonly property color bgHover: "#7a7a7a" //Hover
  readonly property color bgSelected: "#ffffff" //???
  readonly property color bgBorder: "#00000000" //Box border
  
  readonly property color searchBase: "#000000"
  readonly property color searchAccent: "#ffffff"

  readonly property color textPrimary: "#ffffff" 
  readonly property color textSecondary: "#ff0000"
  readonly property color textMuted: "#000000"

  readonly property color accentPrimary: "#ffffff"
  readonly property color accentCyan: "#7dcfff"
  readonly property color accentGreen: "#8fff91"
  readonly property color accentOrange: "#ff9e64"
  readonly property color accentRed: "#f7768e"

  readonly property color urgencyLow: textMuted
  readonly property color urgencyNormal: accentPrimary
  readonly property color urgencyCritical: accentRed
  readonly property color batteryGood: accentGreen
  readonly property color batteryWarning: accentOrange
  readonly property color batteryCritical: accentRed
}
