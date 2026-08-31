if os.getenv("INFINITY_NESTED") == "1" then
  o.exec_on_start("quickshell --path ~/.config/quickshell/shell.qml --no-duplicate")
else
  o.exec_on_start("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  o.exec_on_start("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  o.exec_on_start("hypridle")
  o.exec_on_start("quickshell --path ~/.config/quickshell/shell.qml --no-duplicate --daemonize")
end
