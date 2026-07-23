pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../common" as Common

Scope {
  id: root
  property var theme: Common.Theme {}

  property string searchText: ""
  property string previewPath: ""
  // "" means the "All Monitors" tab (shared library, applies to every
  // connected output at once). A specific screen name restricts the grid
  // to that monitor's own directory (if configured) and targets just it.
  property string selectedMonitor: ""

  IpcHandler {
    target: "wallpaper"

    function toggle(): void {
      wallpaperPanel.visible = !wallpaperPanel.visible;
      if (wallpaperPanel.visible) {
        root.searchText = "";
        root.previewPath = "";
        searchInput.forceActiveFocus();
        if (WallpaperService.wallpapers.length === 0) WallpaperService.rescan();
      }
    }
  }

  property var filteredWallpapers: {
    const source = WallpaperService.wallpapersFor(root.selectedMonitor);
    const q = searchText.toLowerCase();
    if (q === "") return source;
    return source.filter(p => {
      const name = p.split("/").pop().toLowerCase();
      return name.includes(q);
    });
  }

  PanelWindow {
    id: wallpaperPanel
    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-wallpaper"

    exclusionMode: ExclusionMode.Ignore

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Dark overlay backdrop
    MouseArea {
      anchors.fill: parent
      onClicked: wallpaperPanel.visible = false

      Rectangle {
        anchors.fill: parent
        color: root.theme.bgOverlay
      }
    }

    // Main wallpaper picker box
    Rectangle {
      anchors.centerIn: parent
      width: 720
      height: 560
      radius: 16
      color: root.theme.bgBase
      border.color: root.theme.bgBorder
      border.width: 1

      MouseArea {
        anchors.fill: parent
        onClicked: event => event.accepted = true
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          Text {
            text: "󰸉  Wallpaper"
            color: root.theme.accentPrimary
            font.pixelSize: 14
            font.family: "Hack Nerd Font"
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          Text {
            text: root.filteredWallpapers.length + " images"
            color: root.theme.textPrimary
            font.pixelSize: 11
            font.family: "Hack Nerd Font"
          }

          // Refresh button
          Rectangle {
            width: 28
            height: 28
            radius: 14
            color: refreshHover.containsMouse ? root.theme.bgHover : "transparent"
            Accessible.role: Accessible.Button
            Accessible.name: "Refresh wallpaper list"

            Text {
              anchors.centerIn: parent
              text: "󰑐"
              color: root.theme.textPrimary
              font.pixelSize: 14
              font.family: "Hack Nerd Font"
            }

            MouseArea {
              id: refreshHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: WallpaperService.rescan()
            }
          }
        }

        // Monitor selector — "All Monitors" plus one tab per connected
        // screen. Picking a tab restricts the grid to that monitor's own
        // wallpaper folder (if configured in DOTFILES_WALLPAPER_DIRS) and
        // targets just it when you click a thumbnail.
        Row {
          Layout.fillWidth: true
          spacing: 6

          Rectangle {
            width: allTabLabel.width + 20
            height: 26
            radius: 13
            color: root.selectedMonitor === "" ? root.theme.accentPrimary : root.theme.bgSurface

            Text {
              id: allTabLabel
              anchors.centerIn: parent
              text: "All Monitors"
              color: root.selectedMonitor === "" ? root.theme.bgBase : root.theme.textPrimary
              font.pixelSize: 11
              font.family: "Hack Nerd Font"
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedMonitor = ""
            }
          }

          Repeater {
            model: Quickshell.screens

            Rectangle {
              id: monitorTab
              required property var modelData

              width: tabLabel.width + 20
              height: 26
              radius: 13
              color: root.selectedMonitor === monitorTab.modelData.name ? root.theme.accentPrimary : root.theme.bgSurface

              Text {
                id: tabLabel
                anchors.centerIn: parent
                text: monitorTab.modelData.name
                color: root.selectedMonitor === monitorTab.modelData.name ? root.theme.bgBase : root.theme.textPrimary
                font.pixelSize: 11
                font.family: "Hack Nerd Font"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedMonitor = monitorTab.modelData.name
              }
            }
          }
        }

        // Search
        Rectangle {
          Layout.fillWidth: true
          height: 36
          radius: 8
          color: root.theme.searchBase
          border.color: searchInput.activeFocus ? root.theme.searchAccent : root.theme.bgBorder
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: ""
              color: root.theme.textPrimary
              font.pixelSize: 13
              font.family: "Hack Nerd Font"
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              color: root.theme.textPrimary
              font.pixelSize: 13
              font.family: "Hack Nerd Font"
              clip: true
              selectByMouse: true
              Accessible.role: Accessible.EditableText
              Accessible.name: "Search wallpapers"
              onTextChanged: root.searchText = text

              Keys.onEscapePressed: {
                if (root.previewPath !== "") {
                  root.previewPath = "";
                } else {
                  wallpaperPanel.visible = false;
                }
              }
            }

            Text {
              text: "Search wallpapers..."
              color: root.theme.textPrimary
              font.pixelSize: 13
              font.family: "Hack Nerd Font"
              visible: searchInput.text === "" && !searchInput.activeFocus
            }
          }
        }

        // Wallpaper grid
        GridView {
          id: wallpaperGrid
          Layout.fillWidth: true
          Layout.fillHeight: true
          cellWidth: Math.floor(width / 4)
          cellHeight: cellWidth * 0.6 + 8
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.filteredWallpapers

          delegate: Item {
            required property string modelData
            required property int index

            Accessible.role: Accessible.Button
            Accessible.name: modelData.split("/").pop() + (WallpaperService.currentFor(root.selectedMonitor) === modelData ? ", current wallpaper" : "")

            width: wallpaperGrid.cellWidth
            height: wallpaperGrid.cellHeight

            Rectangle {
              anchors.fill: parent
              anchors.margins: 4
              radius: 8
              color: root.theme.bgSurface
              border.color: WallpaperService.currentFor(root.selectedMonitor) === modelData ? root.theme.accentPrimary : (imgHover.containsMouse ? root.theme.bgBorder : "transparent")
              border.width: WallpaperService.currentFor(root.selectedMonitor) === modelData ? 2 : 1
              clip: true

              Image {
                anchors.fill: parent
                anchors.margins: 2
                source: "file://" + modelData
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 200
                sourceSize.height: 120
                asynchronous: true

                Rectangle {
                  anchors.fill: parent
                  color: root.theme.bgSurface
                  visible: parent.status !== Image.Ready

                  Text {
                    anchors.centerIn: parent
                    text: "󰋩"
                    color: root.theme.textPrimary
                    font.pixelSize: 24
                    font.family: "Hack Nerd Font"
                  }
                }
              }

              // Filename label
              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 22
                color: Qt.rgba(0, 0, 0, 0.6)

                Text {
                  anchors.centerIn: parent
                  text: modelData.split("/").pop()
                  color: "#ffffff"
                  font.pixelSize: 9
                  font.family: "Hack Nerd Font"
                  elide: Text.ElideMiddle
                  width: parent.width - 8
                  horizontalAlignment: Text.AlignHCenter
                }
              }

              // Active indicator
              Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                width: 20
                height: 20
                radius: 10
                color: root.theme.accentPrimary
                visible: WallpaperService.currentFor(root.selectedMonitor) === modelData

                Text {
                  anchors.centerIn: parent
                  text: ""
                  // Dark glyph on the light accentPrimary fill above — using
                  // textPrimary (also light) here was invisible (light-on-light).
                  color: root.theme.bgBase
                  font.pixelSize: 12
                  font.family: "Hack Nerd Font"
                }
              }

              MouseArea {
                id: imgHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                  if (mouse.button === Qt.RightButton) {
                    root.previewPath = modelData;
                  } else {
                    WallpaperService.setWallpaper(modelData, root.selectedMonitor);
                  }
                }
              }
            }
          }

          // Empty state
          Text {
            anchors.centerIn: parent
            text: "󰋩  No wallpapers found\nAdd images to ~/Pictures/Wallpapers/"
            color: root.theme.textPrimary
            font.pixelSize: 13
            font.family: "Hack Nerd Font"
            horizontalAlignment: Text.AlignHCenter
            visible: wallpaperGrid.count === 0
          }
        }

        // Footer
        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          Row {
            spacing: 4
            Rectangle {
              width: hintClick.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintClick; anchors.centerIn: parent; text: "click"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "apply"; color: root.theme.textPrimary; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Rectangle {
              width: hintRight.width + 8; height: 18; radius: 4; color: root.theme.bgSurface
              Text { id: hintRight; anchors.centerIn: parent; text: "right-click"; color: root.theme.textMuted; font.pixelSize: 10; font.family: "Hack Nerd Font" }
            }
            Text { text: "preview"; color: root.theme.textPrimary; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Row {
            spacing: 4
            Text { text: "Backend: " + WallpaperService.backend; color: root.theme.textPrimary; font.pixelSize: 10; font.family: "Hack Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
          }

          Item { Layout.fillWidth: true }
        }
      }
    }

    // Preview overlay
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.85)
      visible: root.previewPath !== ""

      MouseArea {
        anchors.fill: parent
        onClicked: root.previewPath = ""
      }

      Image {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8
        source: root.previewPath !== "" ? "file://" + root.previewPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }

      // Apply button
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40
        width: applyRow.width + 32
        height: 40
        radius: 20
        // accentSecondary/textSecondary/textMuted here (as fill + on-fill
        // text) don't exist on the shared theme and previously rendered as
        // invalid/mismatched colors; accentPrimary + bgBase gives a real,
        // legible light-button/dark-label pair matching the theme actually
        // shipped in common/Theme.qml.
        color: root.theme.accentPrimary
        Accessible.role: Accessible.Button
        Accessible.name: "Apply wallpaper"

        Row {
          id: applyRow
          anchors.centerIn: parent
          spacing: 8

          Text {
            text: ""
            color: root.theme.bgBase
            font.pixelSize: 14
            font.family: "Hack Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "Apply Wallpaper"
            color: root.theme.bgBase
            font.pixelSize: 13
            font.family: "Hack Nerd Font"
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WallpaperService.setWallpaper(root.previewPath, root.selectedMonitor);
            root.previewPath = "";
          }
        }
      }
    }
  }
}
