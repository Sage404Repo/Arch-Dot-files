import QtQuick
import Quickshell
import Quickshell.Wayland
import "applauncher" as Launcher
import "notifications" as Notif
import "wallpaper" as WP
import "media" as Media
//import "filemanager" as FM

ShellRoot {
  Launcher.AppLauncher {}
  WP.WallpaperManager {}
  Notif.NotificationPopup {}
  Media.MediaControl {}
  //FM.FileManager {}
}

