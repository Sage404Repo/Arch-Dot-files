pragma Singleton

import QtQuick
// QML property names must start with a lowercase letter, so PascalCase
// constants like WlrLayer.Overlay have to be a QML `enum` (whose members
// ARE allowed to be PascalCase and are exposed directly on the type,
// without an enum-name qualifier) rather than plain `property int`.
QtObject {
  enum Value { Overlay, Top, Bottom, Background }
}
