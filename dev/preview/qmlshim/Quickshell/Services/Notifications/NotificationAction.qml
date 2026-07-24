import QtQuick
// Preview shim standing in for the real NotificationAction type — only
// used as a `required property NotificationAction modelData` type
// annotation in a Repeater delegate, so a bare QtObject is enough.
QtObject {
  property string identifier: ""
  property string text: ""
  function invoke() {}
}
