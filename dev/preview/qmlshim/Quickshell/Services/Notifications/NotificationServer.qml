import QtQuick
// Preview shim: real NotificationServer listens on the D-Bus notification
// spec. Nothing to actually listen to in a visual preview, so this fires a
// few fake notifications shortly after startup instead (same "auto-trigger
// via Timer" convention as Io/IpcHandler.qml's toggle() call).
//
// These are emitted as plain JS objects, not `Notification {}` instances —
// the real NotificationService.qml singleton (the repo's own file, never
// modified by this harness) does `notification.tracked = true` on whatever
// it receives here, and a QML QObject instance isn't extensible from JS
// (assigning an undeclared property throws). Plain objects are, so this
// exercises NotificationService.qml's actual onNotification/cap-at-5 logic
// unmodified, not just a hand-built fake `notifications` list.
//
// Extends Item (never shown/parented) rather than QtObject so the child
// Timers below attach via Item's built-in `data` default property — see
// Quickshell/Singleton.qml for why a bare QtObject can't hold them.
Item {
  id: root
  signal notification(var notification)

  // Capability flags NotificationService.qml sets on its NotificationServer
  // instance — real values don't matter for a visual preview, just need to
  // exist so the assignments don't fail to resolve.
  property bool actionsSupported: false
  property bool bodySupported: false
  property bool bodyMarkupSupported: false
  property bool imageSupported: false
  property bool keepOnReload: false

  function _mkNotification(urgency, appName, summary, body, actions, expireTimeout) {
    return {
      urgency: urgency,
      appIcon: "",
      appName: appName,
      summary: summary,
      body: body,
      image: "",
      actions: actions || [],
      expireTimeout: expireTimeout !== undefined ? expireTimeout : 5000,
      tracked: false,
      dismiss: function () { console.log("[preview] dismissed:", summary); },
      expire: function () { console.log("[preview] expired:", summary); }
    };
  }

  function _mkAction(identifier, text) {
    return {
      identifier: identifier,
      text: text,
      invoke: function () { console.log("[preview] action invoked:", identifier); }
    };
  }

  // Urgency values match NotificationUrgency.qml's enum (Low=0, Normal=1,
  // Critical=2) without importing the singleton back into this file.
  Timer {
    interval: 300
    running: true
    onTriggered: root.notification(root._mkNotification(
      1, "Discord", "New message", "trap: hey, check the PR when you can", [], 5000))
  }

  Timer {
    interval: 600
    running: true
    onTriggered: root.notification(root._mkNotification(
      2, "System", "Battery critical", "9% remaining, plug in now",
      [root._mkAction("suspend", "Suspend"), root._mkAction("dismiss", "Dismiss")], 0))
  }

  Timer {
    interval: 900
    running: true
    onTriggered: root.notification(root._mkNotification(
      0, "LibreWolf", "Download complete", "", [], 4000))
  }
}
