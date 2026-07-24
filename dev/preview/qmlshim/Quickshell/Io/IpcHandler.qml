import QtQuick

// Preview shim for Quickshell.Io's IpcHandler.
//
// Real IpcHandlers are invoked externally via `qs ipc call <target> <fn>`.
// There's no such bridge in a plain `qml` preview, so — purely to make the
// preview useful — if the handler declares a no-arg `toggle()` function
// (every component in this repo does), it's called automatically shortly
// after startup. This is preview-only convenience, not a real IPC
// implementation.
QtObject {
  property string target: ""

  // QtObject has no default property to hold a child Timer (only
  // Item-derived types do) — an invisible, zero-size Item is the
  // simplest fix that doesn't affect layout anywhere this is used.
  property Item _autoOpener: Item {
    visible: false
    width: 0
    height: 0

    Timer {
      interval: 250
      running: true
      onTriggered: {
        if (typeof toggle === "function") toggle();
      }
    }
  }
}
