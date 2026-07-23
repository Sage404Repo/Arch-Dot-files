import QtQuick
// Preview shim: real ScriptModel exposes an arbitrary JS array as a list
// model. QtQuick's ListModel doesn't accept raw objects well, so we just
// forward the `values` array directly — plain QtQuick views accept a JS
// array as `model` just fine.
QtObject {
  property string objectProp: "id"
  property var values: []
}
