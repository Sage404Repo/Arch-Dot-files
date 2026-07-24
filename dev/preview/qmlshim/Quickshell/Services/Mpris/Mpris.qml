pragma Singleton

import QtQuick
// Preview shim for the Mpris singleton — one fake "playing" player so
// MediaControl.qml has something real to render.
//
// Plain JS objects, not QtObject {} instances: a QML object declaration
// can't be embedded inline inside a JS array-literal property binding —
// only plain JS values can appear there.
QtObject {
  readonly property var players: QtObject {
    readonly property var values: [
      {
        trackTitle: "Preview Track Title",
        trackArtist: "Preview Artist",
        isPlaying: true,
        canGoNext: true,
        canGoPrevious: true,
        canTogglePlaying: true,
        next: function () { console.log("[preview] next()"); },
        previous: function () { console.log("[preview] previous()"); },
        togglePlaying: function () { this.isPlaying = !this.isPlaying; }
      }
    ]
  }
}

