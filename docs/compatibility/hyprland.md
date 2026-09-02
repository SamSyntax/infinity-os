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
| Super+R | apps | `fuzzel` | preserved intent with an official Arch launcher |
| Super+Shift+M | distro-only session exit | `hyprctl dispatch exit` | new non-conflicting VM preview escape hatch |
| Super+1…9 | distro workspace selection | `hl.dsp.focus({ workspace = N })` | requested primary workspace navigation; layout action moved away from Super+4 |
| Super+Shift+1…9 | distro move-to-workspace | `hl.dsp.window.move({ workspace = N })` | paired with Super workspace selection |
| Super+mouse/equal/minus/KP | zoom/reset | cursor zoom helpers | preserved |
| Super+V | clipboard | `cliphist | fuzzel --dmenu | wl-copy` | preserved intent with Fuzzel |
| Super+Z | Quickshell toggle | repo path aware command | preserved |
| Super+Ctrl+4 | master left | `hyprctl dispatch layoutmsg orientationleft && ...` | intent preserved while freeing Super+4 for workspace selection |
| Super+Shift+S | final effective screenshot: `omarchy-capture-screenshot` | `infinity-capture-screenshot` | replacement provided |
| Super+Shift+G | toggle float | `hl.dsp.window.float` | preserved |
| Super+U | special workspace | `toggle_special("special")` | preserved |
| Super+Shift+U | move special | `move special:special` | preserved |
| Super+N | toggle split | `hl.dsp.layout("togglesplit")` | preserved |

Effective overrides/conflicts: Super+M is the final layout toggle and supersedes an older Spotify intent. Screenshot command is replaced because Omarchy helpers are not part of this repository. Super+Shift+M is distro-only so a manually launched VM preview has an obvious exit path. Super+1…9 is the requested workspace contract; the preserved master-left intent moves from Super+4 to Super+Ctrl+4. No other broad new keymap is introduced.
