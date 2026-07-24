pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../common" as Common

// Small persistent media-transport widget, backed by MPRIS
// (Quickshell.Services.Mpris). Previously referenced by shell.qml
// (`import "media" as Media`) but never implemented, which broke shell
// startup entirely since the import target didn't exist.
Scope {
  id: root
  property var theme: Common.Theme {}

  // Prefer whichever player is actively playing; fall back to the first
  // available player so something useful is still shown when paused.
  readonly property var players: [...Mpris.players.values]
  readonly property var activePlayer: players.find(p => p.isPlaying) ?? players[0] ?? null
  readonly property bool hasPlayer: root.activePlayer !== null

  IpcHandler {
    target: "media"

    function playPause(): void {
      if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying();
    }

    function next(): void {
      if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next();
    }

    function previous(): void {
      if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous();
    }
  }

  PanelWindow {
    id: mediaWindow
    visible: root.hasPlayer
    focusable: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-media"

    exclusionMode: ExclusionMode.Ignore

    anchors {
      bottom: true
    }

    margins {
      bottom: 12
    }

    implicitWidth: 360
    implicitHeight: 72

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 2

          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown Title") : "No media playing"
            color: root.theme.textPrimary
            font.pixelSize: 13
            font.bold: true
            font.family: "Hack Nerd Font"
          }

          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            visible: text !== ""
            text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown Artist") : ""
            color: root.theme.textMuted
            font.pixelSize: 11
            font.family: "Hack Nerd Font"
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignVCenter
          spacing: 4

          Repeater {
            model: [
              { icon: "󰒮", enabled: root.activePlayer !== null && root.activePlayer.canGoPrevious, action: () => root.activePlayer.previous() },
              { icon: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊", enabled: root.activePlayer !== null && root.activePlayer.canTogglePlaying, action: () => root.activePlayer.togglePlaying() },
              { icon: "󰒭", enabled: root.activePlayer !== null && root.activePlayer.canGoNext, action: () => root.activePlayer.next() }
            ]

            delegate: Rectangle {
              id: mediaButton
              required property var modelData

              width: 28
              height: 28
              radius: 14
              opacity: modelData.enabled ? 1 : 0.35
              color: btnHover.containsMouse && modelData.enabled ? root.theme.bgHover : "transparent"

              Text {
                anchors.centerIn: parent
                text: mediaButton.modelData.icon
                color: root.theme.textPrimary
                font.pixelSize: 13
                font.family: "Hack Nerd Font"
              }

              MouseArea {
                id: btnHover
                anchors.fill: parent
                hoverEnabled: true
                enabled: mediaButton.modelData.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: mediaButton.modelData.action()
              }
            }
          }
        }
      }
    }
  }
}
