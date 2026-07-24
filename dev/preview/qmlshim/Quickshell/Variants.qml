import QtQml
// Preview shim for Quickshell's `Variants` (repeats a Component once per
// model entry, same idea as Repeater but for non-visual/window delegates).
// NotificationPopup.qml's delegate is a PanelWindow (Window-derived, not
// Item-derived) — QtQuick's Repeater requires Item delegates and fails
// with "Delegate must be of Item type" for anything else. Instantiator
// (QtQml, not QtQuick) is Quickshell's own real base for Variants and has
// no such restriction — it can create arbitrary QtObject/Window-derived
// objects per model entry, which is exactly what's needed here.
//
// Note: this prints a harmless `qt.core.qobject.connect: ... invalid
// nullptr parameter` warning to stderr for each instantiated delegate —
// internal QQmlDelegateModel bookkeeping, not a real error. Confirmed
// benign: nothing fails to load and no bound data is missing.
Instantiator {}
