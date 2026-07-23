import QtQuick

// Preview shim for Quickshell.Wayland's PanelWindow.
//
// The real type is a wlr-layer-shell surface with boolean edge-anchoring
// (`anchors { top: true }`) and pixel margins, and implicitWidth/Height —
// none of which QtQuick's Window base type has. The `anchors`/`margins`
// grouped-property blocks are stripped from the scratch copy by
// dev/preview/run.sh instead of replicated here (a real Qt 6 QML engine
// limitation makes custom alias-based grouped properties only bind
// all-but-the-last member correctly); implicitWidth/implicitHeight are
// real plain properties here since components do bind to them directly.
Window {
  id: root
  property real implicitWidth: 0
  property real implicitHeight: 0
  width: implicitWidth > 0 ? implicitWidth : 400
  height: implicitHeight > 0 ? implicitHeight : 300

  property int exclusionMode: 0
  property bool focusable: false

  // Shadows the real (inherited) Window.screen, which is a genuine
  // QScreen*-typed C++ property — real Quickshell's PanelWindow.screen
  // instead takes a ShellScreen, and NotificationPopup.qml assigns it the
  // fake `{ name: "..." }` plain object Quickshell.qml's `screens` shim
  // returns. Assigning a plain object to the real Window.screen fails
  // ("Unable to assign QVariantMap to QQuickScreenInfo*"); redeclaring it
  // as `var` here shadows that C++ property for QML purposes and just
  // accepts whatever's assigned, which is all a visual-only preview needs.
  property var screen: null

  Component.onCompleted: root.requestActivate()
}
