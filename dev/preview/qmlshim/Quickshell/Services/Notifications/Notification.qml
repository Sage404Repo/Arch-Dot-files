import QtQuick
// Preview shim standing in for the real Notification data type — only
// used as a type annotation (`property list<Notification>`) and as plain
// JS objects with these fields elsewhere, so a bare QtObject is enough.
QtObject {
  property int urgency: 1
  property string appIcon: ""
  property string appName: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property var actions: []
  property int expireTimeout: 5000
}
