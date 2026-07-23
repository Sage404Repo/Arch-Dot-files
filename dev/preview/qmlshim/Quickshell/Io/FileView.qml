import QtQuick
// Preview shim: no real file I/O in a visual-only preview. Real Quickshell
// exposes `text` as a *function* (with its own manually-emitted
// `textChanged()` signal), not a plain property — matching that shape
// here, even though this shim never actually loads anything, so code
// calling `fileView.text()` doesn't fail with "text is not a function".
QtObject {
  property string path: ""
  property string _content: ""
  signal textChanged()
  function text() { return _content; }
}
