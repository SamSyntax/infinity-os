mainMod = "SUPER"

o.replace("SUPER + RETURN", "Terminal", "ghostty")
o.replace("SUPER + SHIFT + F", "File manager", "uwsm app -- nautilus --new-window")
o.replace("SUPER + M", "Toggle split layout", hl.dsp.layout("togglesplit"))
o.replace("SUPER + D", "Lazydocker", "uwsm app -- ghostty -e lazydocker")
o.replace("SUPER + O", "Obsidian", "uwsm app -- obsidian")
o.replace("SUPER + slash", "Password manager", "uwsm app -- keepassxc")
o.replace("SUPER + B", "Browser", "xdg-open about:blank")

o.replace("SUPER + CTRL + H", "Resize left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
o.replace("SUPER + CTRL + L", "Resize right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
o.replace("SUPER + CTRL + K", "Resize up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
o.replace("SUPER + CTRL + J", "Resize down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

o.replace("SUPER + SHIFT + H", "Move window left", hl.dsp.window.move({ direction = "l" }))
o.replace("SUPER + SHIFT + L", "Move window right", hl.dsp.window.move({ direction = "r" }))
o.replace("SUPER + SHIFT + K", "Move window up", hl.dsp.window.move({ direction = "u" }))
o.replace("SUPER + SHIFT + J", "Move window down", hl.dsp.window.move({ direction = "d" }))

o.replace("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
o.replace("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))
o.replace("SUPER + K", "Focus up", hl.dsp.focus({ direction = "u" }))
o.replace("SUPER + J", "Focus down", hl.dsp.focus({ direction = "d" }))

o.replace("SUPER + Q", "Close window", hl.dsp.window.close())
o.replace("SUPER + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.replace("SUPER + R", "Apps", "fuzzel")
o.replace("SUPER + SHIFT + M", "Exit session", "hyprctl dispatch exit")

local function set_zoom(value)
  hl.config({ cursor = { zoom_factor = math.max(1, value) } })
end

local function scale_zoom(factor)
  set_zoom((hl.get_config("cursor.zoom_factor") or 1) * factor)
end

o.replace("SUPER + mouse_down", "Zoom in", function() scale_zoom(1.1) end)
o.replace("SUPER + mouse_up", "Zoom out", function() scale_zoom(0.9) end)
o.replace("SUPER + equal", "Zoom in", function() scale_zoom(1.1) end, { repeating = true })
o.replace("SUPER + minus", "Zoom out", function() scale_zoom(0.9) end, { repeating = true })
o.replace("SUPER + KP_ADD", "Zoom in", function() scale_zoom(1.1) end, { repeating = true })
o.replace("SUPER + KP_SUBTRACT", "Zoom out", function() scale_zoom(0.9) end, { repeating = true })
o.replace("SUPER + SHIFT + mouse_up", "Reset zoom", function() set_zoom(1) end)
o.replace("SUPER + SHIFT + mouse_down", "Reset zoom", function() set_zoom(1) end)
o.replace("SUPER + SHIFT + minus", "Reset zoom", function() set_zoom(1) end)
o.replace("SUPER + SHIFT + KP_SUBTRACT", "Reset zoom", function() set_zoom(1) end)
o.replace("SUPER + CTRL + 1", "Reset zoom", function() set_zoom(1) end)

o.replace("SUPER + V", "Clipboard history", "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")
o.replace("SUPER + Z", "Toggle Quickshell", "quickshell kill --path ~/.config/quickshell/shell.qml || quickshell --path ~/.config/quickshell/shell.qml --no-duplicate --daemonize")
o.replace("SUPER + 4", "Master layout left", "hyprctl dispatch layoutmsg orientationleft && hyprctl dispatch layoutmsg swapwithmaster")
o.replace("SUPER + SHIFT + S", "Screenshot with editing", "infinity-capture-screenshot")
o.replace("SUPER + SHIFT + G", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))
o.replace("SUPER + U", "Toggle special workspace", hl.dsp.workspace.toggle_special("special"))
o.replace("SUPER + SHIFT + U", "Move window to special workspace", hl.dsp.window.move({ workspace = "special:special" }))
o.replace("SUPER + N", "Toggle split", hl.dsp.layout("togglesplit"))
