import QtQuick
// Preview shim for Quickshell's `Singleton` base type. Real singletons in
// this repo (WallpaperService.qml, NotificationService.qml) declare
// `pragma Singleton` and extend `Singleton { ... }` from `import
// Quickshell`, then nest plain QtObject-derived children (Process,
// FileView, NotificationServer) directly inside. A bare QtObject has no
// default property to hold those (tried `default property list<QtObject>`
// — QML rejects assigning declared children into it outside an Item root).
// Item's built-in `data` default property accepts any QtObject-derived
// child natively, so extending Item instead — never actually shown, never
// parented into a visible layout — is the simplest way to make this work.
Item {
}
