# Hyprland compatibility inventory

Source: active `/home/sam/.config/hypr/bindings.lua`, read-only. Private paths are not copied.

| Binding | Source action | Infinity implementation | Status |
|---|---|---|---|
| Super+Return | ghostty | `ghostty` | preserved |
| Super+Shift+F | nautilus | `uwsm app -- nautilus --new-window` | preserved |
| Super+M | layout toggle, overrides prior Spotify binding | `hl.dsp.layout("togglesplit")` | preserved effective behavior |
| Super+D | lazydocker | `uwsm app -- ghostty -e lazydocker` | preserved intent |
| Super+O | Obsidian with private path-free command | `uwsm app -- obsidian` | private path omitted |
| Super+Slash | keepassxc | `uwsm app -- keepassxc` | preserved |
| Super+B | browser | `xdg-open about:blank` | preserved intent; default browser decides |
| Super+T | Unicode via kitty | not bound by default | pending terminal mismatch |
| Super+Ctrl+H/J/K/L | resize | `hl.dsp.window.resize` repeating | preserved |
| Super+Shift+H/J/K/L | move window | `hl.dsp.window.move` | preserved |
| Super+H/J/K/L | focus | `hl.dsp.focus` | preserved |
| Super+Q | close | `hl.dsp.window.close` | preserved |
| Super+F | fullscreen | `hl.dsp.window.fullscreen` | preserved |
| Super+R | apps | `walker` | preserved intent; no Omarchy command |
| Super+mouse/equal/minus/KP | zoom/reset | cursor zoom helpers | preserved |
| Super+V | clipboard | `cliphist | walker | wl-copy` | preserved |
| Super+Z | Quickshell toggle | repo path aware command | preserved |
| Super+4 | master left | `hyprctl dispatch layoutmsg orientationleft && ...` | preserved |
| Super+Shift+S | final effective screenshot: `omarchy-capture-screenshot` | `infinity-capture-screenshot` | replacement provided |
| Super+Shift+G | toggle float | `hl.dsp.window.float` | preserved |
| Super+U | special workspace | `toggle_special("special")` | preserved |
| Super+Shift+U | move special | `move special:special` | preserved |
| Super+N | toggle split | `hl.dsp.layout("togglesplit")` | preserved |

Effective overrides/conflicts: Super+M is the final layout toggle and supersedes an older Spotify intent. Screenshot command is replaced because Omarchy helpers are not part of this repository. No broad new keymap is introduced.
