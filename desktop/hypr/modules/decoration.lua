hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 18,
    border_size = 2,
    col = {
      active_border = { colors = { "rgba(8fb8ffee)", "rgba(c6a0ffee)" }, angle = 35 },
      inactive_border = "rgba(2a2f3aaa)",
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },
  decoration = {
    rounding = 12,
    rounding_power = 2,
    active_opacity = 1.0,
    inactive_opacity = 0.98,
    shadow = { enabled = true, range = 18, render_power = 3, color = "rgba(06091488)" },
    blur = { enabled = true, size = 4, passes = 2, vibrancy = 0.12 },
  },
  misc = { force_default_wallpaper = 0, disable_hyprland_logo = true },
})
