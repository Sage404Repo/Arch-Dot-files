import QtQuick
// Preview shim: a plain Image stands in fine for IconImage's layout needs.
// (implicitWidth/implicitHeight are read-only on Image — driven by the
// loaded source's size — so the custom size has to go through
// width/height instead, not an override of the implicit* properties.)
Image {
  property int implicitSize: 16
  width: implicitSize
  height: implicitSize
  fillMode: Image.PreserveAspectFit
}
