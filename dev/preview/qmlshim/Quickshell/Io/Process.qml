import QtQuick
// Preview shim: real Process runs an external command. Never actually
// exec anything from a visual preview — just expose the properties the
// real components bind to so they don't error out.
QtObject {
  property string command: ""
  property bool running: false
  property var stdout: null
}
