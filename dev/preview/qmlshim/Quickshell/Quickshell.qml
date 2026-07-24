pragma Singleton

import QtQuick
// Preview shim for the `Quickshell` global singleton (Quickshell.env(),
// Quickshell.screens, Quickshell.iconPath()). Only needs to be plausible
// enough that bindings don't throw — real values don't matter for a
// visual-only preview.
//
// Two fake screens (not one) so multi-monitor UI (NotificationPopup's
// per-screen Variants, WallpaperManager's monitor-tab selector) has
// something real to render instead of a single/empty list.
QtObject {
  // Plain JS objects, not QtObject {} instances: a QML object declaration
  // can't be embedded inline inside a JS array-literal property binding
  // like this — only plain JS values can. `.name` access is all real
  // components need from this.
  readonly property var screens: [{ name: "preview-DP-1" }, { name: "preview-HDMI-A-1" }]

  function env(name) {
    return "";
  }

  function iconPath(name, fallback) {
    return "";
  }
}
