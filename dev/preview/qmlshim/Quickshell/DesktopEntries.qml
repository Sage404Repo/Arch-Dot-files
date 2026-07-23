pragma Singleton

import QtQuick
// Preview shim for the DesktopEntries singleton — returns a handful of fake
// desktop-entry-like objects so AppLauncher's whitelist filter has
// something real to show.
QtObject {
  function _entry(id, name, generic) {
    return {
      id: id,
      name: name,
      genericName: generic,
      keywords: [],
      categories: [],
      execute: function () { console.log("[preview] would launch:", id); }
    };
  }

  readonly property QtObject applications: QtObject {
    readonly property var values: [
      _entry("discord.desktop", "Discord", "Chat"),
      _entry("com.vysp3r.ProtonPlus.desktop", "ProtonPlus", "Settings"),
      _entry("librewolf.desktop", "LibreWolf", "Web Browser"),
      _entry("nm-connection-editor.desktop", "Network", "Settings"),
      _entry("steam.desktop", "Steam", "Games")
    ];
  }
}
