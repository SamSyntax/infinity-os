local function replace(keys, description, dispatcher, options)
	hl.unbind(keys)
	o.bind(keys, description, dispatcher, options)
end

replace("SUPER + RETURN", "Terminal", "ghostty")
replace("SUPER + SHIFT + F", "File manager", "uwsm app -- nautilus --new-window")
replace(
	"SUPER + CTRL + H",
	"Resize left",
	hl.dsp.window.resize({ x = -50, y = 0, relative = true }),
	{ repeating = true }
)
replace(
	"SUPER + CTRL + L",
	"Resize right",
	hl.dsp.window.resize({ x = 50, y = 0, relative = true }),
	{ repeating = true }
)
replace(
	"SUPER + CTRL + K",
	"Resize up",
	hl.dsp.window.resize({ x = 0, y = -50, relative = true }),
	{ repeating = true }
)
replace(
	"SUPER + CTRL + J",
	"Resize down",
	hl.dsp.window.resize({ x = 0, y = 50, relative = true }),
	{ repeating = true }
)

replace("SUPER + SHIFT + H", "Move window left", hl.dsp.window.move({ direction = "l" }))
replace("SUPER + SHIFT + L", "Move window right", hl.dsp.window.move({ direction = "r" }))
replace("SUPER + SHIFT + K", "Move window up", hl.dsp.window.move({ direction = "u" }))
replace("SUPER + SHIFT + J", "Move window down", hl.dsp.window.move({ direction = "d" }))

replace("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))
replace("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))
replace("SUPER + K", "Focus up", hl.dsp.focus({ direction = "u" }))
replace("SUPER + J", "Focus down", hl.dsp.focus({ direction = "d" }))

replace("SUPER + Q", "Close window", hl.dsp.window.close())
replace("SUPER + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- replace("SUPER + R", "Apps menu", "omarchy-menu toggle apps")

local function set_zoom(value)
	hl.config({ cursor = { zoom_factor = math.max(1, value) } })
end

local function scale_zoom(factor)
	set_zoom((hl.get_config("cursor.zoom_factor") or 1) * factor)
end

replace("SUPER + mouse_down", "Zoom in", function()
	scale_zoom(1.1)
end)
replace("SUPER + mouse_up", "Zoom out", function()
	scale_zoom(0.9)
end)
replace("SUPER + equal", "Zoom in", function()
	scale_zoom(1.1)
end, { repeating = true })
replace("SUPER + minus", "Zoom out", function()
	scale_zoom(0.9)
end, { repeating = true })
replace("SUPER + KP_ADD", "Zoom in", function()
	scale_zoom(1.1)
end, { repeating = true })
replace("SUPER + KP_SUBTRACT", "Zoom out", function()
	scale_zoom(0.9)
end, { repeating = true })

replace("SUPER + SHIFT + mouse_up", "Reset zoom", function()
	set_zoom(1)
end)
replace("SUPER + SHIFT + mouse_down", "Reset zoom", function()
	set_zoom(1)
end)
replace("SUPER + SHIFT + minus", "Reset zoom", function()
	set_zoom(1)
end)
replace("SUPER + SHIFT + KP_SUBTRACT", "Reset zoom", function()
	set_zoom(1)
end)
replace("SUPER + CTRL + 1", "Reset zoom", function()
	set_zoom(1)
end)

replace("SUPER + V", "Clipboard history", "cliphist list | walker --dmenu | cliphist decode | wl-copy")
replace(
	"SUPER + Z",
	"Toggle Quickshell",
	"quickshell kill --path ~/.config/quickshell/shell.qml || quickshell --path ~/.config/quickshell/shell.qml --no-duplicate --daemonize"
)
replace(
	"SUPER + 4",
	"Master layout left",
	"hyprctl dispatch layoutmsg orientationleft && hyprctl dispatch layoutmsg swapwithmaster"
)
replace("SUPER + SHIFT + S", "Screenshot with editing", "omarchy-cmd-screenshot")
replace("SUPER + SHIFT + G", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))

replace("SUPER + U", "Toggle special workspace", hl.dsp.workspace.toggle_special("special"))
replace("SUPER + SHIFT + U", "Move window to special workspace", hl.dsp.window.move({ workspace = "special:special" }))

hl.unbind("F9")

