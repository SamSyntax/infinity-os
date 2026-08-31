# Canonical compatibility and migration matrix

This file is the canonical compatibility inventory. `docs/compatibility/hyprland.md` and `docs/compatibility/apps.md` keep focused summaries that should stay consistent with this matrix.

| source app | source key combination | source command/action | intended behavior | implementation in new distro | conflicts/notes |
|---|---|---|---|---|---|
| Hyprland | Super+Return | `ghostty` | open terminal | `ghostty` | preserved |
| Hyprland | Super+Shift+F | `uwsm app -- nautilus --new-window` | open file manager | same command | preserved |
| Hyprland | Super+M | layout toggle | toggle split/layout behavior | `hl.dsp.layout("togglesplit")` | final effective binding overrides older Spotify intent |
| Hyprland | Super+D | lazydocker | open lazydocker in terminal | `uwsm app -- ghostty -e lazydocker` | preserved intent |
| Hyprland | Super+O | Obsidian command without private path | open Obsidian workspace | `uwsm app -- obsidian` | private path omitted |
| Hyprland | Super+Slash | keepassxc | open password manager | `uwsm app -- keepassxc` | preserved |
| Hyprland | Super+B | browser | open browser | `xdg-open about:blank` | default browser decides target |
| Hyprland | Super+T | Unicode via kitty | Unicode input workflow | pending | terminal mismatch; do not bind until replacement is chosen |
| Hyprland | Super+Ctrl+H/J/K/L | resize directional | resize focused window | `hl.dsp.window.resize` repeating | preserved |
| Hyprland | Super+Shift+H/J/K/L | move window directional | move focused window | `hl.dsp.window.move` | preserved |
| Hyprland | Super+H/J/K/L | focus directional | focus neighboring window | `hl.dsp.focus` | preserved |
| Hyprland | Super+Q | close window | close focused window | `hl.dsp.window.close()` | preserved |
| Hyprland | Super+F | fullscreen | fullscreen focused window | `hl.dsp.window.fullscreen` | preserved |
| Hyprland | Super+R | apps menu | open app launcher | `fuzzel` | official Arch package replaces AUR-only Walker |
| Infinity distro | Super+Shift+M | distro-only session exit | exit manual Hyprland preview | `hyprctl dispatch exit` | new non-conflicting VM preview escape hatch |
| Infinity distro | Alt+1…9 | workspace selection | switch directly to numbered workspace | `hl.dsp.focus({ workspace = N })` | uses the configured `mainMod`; avoids preserved Super+4 layout binding |
| Infinity distro | Alt+Shift+1…9 | move focused window | move window to numbered workspace | `hl.dsp.window.move({ workspace = N })` | paired with Alt workspace selection |
| Hyprland | Super+mouse_down/up | cursor zoom | zoom in/out | cursor zoom helper | preserved |
| Hyprland | Super+equal/minus/KP_ADD/KP_SUBTRACT | cursor zoom | keyboard zoom in/out | cursor zoom helper | preserved |
| Hyprland | Super+Shift+mouse_up/down/minus/KP_SUBTRACT, Super+Ctrl+1 | reset cursor zoom | return zoom to 1 | cursor zoom reset helper | preserved |
| Hyprland | Super+V | `cliphist list | walker --dmenu | cliphist decode | wl-copy` | clipboard history picker | `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy` | intent preserved with official Arch launcher |
| Hyprland | Super+Z | quickshell toggle | toggle desktop shell | repo path-compatible `quickshell kill ... || quickshell ...` | preserved |
| Hyprland | Super+4 | `hyprctl dispatch layoutmsg orientationleft && hyprctl dispatch layoutmsg swapwithmaster` | orient master left | same command | preserved |
| Hyprland | Super+Shift+S | final effective screenshot command `omarchy-capture-screenshot` | capture/edit screenshot | `infinity-capture-screenshot` | repository replacement supplied |
| Hyprland | Super+Shift+G | toggle floating | toggle focused window float | `hl.dsp.window.float` | preserved |
| Hyprland | Super+U | special workspace | toggle scratch/special workspace | `hl.dsp.workspace.toggle_special("special")` | preserved |
| Hyprland | Super+Shift+U | move special workspace | move window to special workspace | `hl.dsp.window.move({ workspace = "special:special" })` | preserved |
| Hyprland | Super+N | toggle split | toggle split behavior | `hl.dsp.layout("togglesplit")` | preserved |
| tmux | C-a | prefix | command prefix muscle memory | pending app config deployment | exact file unavailable; preserve in future tmux config |
| tmux | vi copy keys | vi copy mode | select/copy with vi motions | pending app config deployment | exact mappings unavailable |
| tmux | C-h/j/k/l | pane/editor navigation | move between panes and editor splits | pending app config deployment | coordinate with Neovim mappings |
| tmux | split bindings | split at current path | create panes in current working directory | pending app config deployment | exact keys unavailable |
| tmux | TPM/resurrect workflow | plugin/session restore | plugin management and session recovery | pending app config deployment | no secrets/state copied |
| Neovim | h/j/k/l navigation family | window navigation | editor window movement | pending app config deployment | exact mappings unavailable |
| Neovim | format/action mappings | format and code actions | fast code maintenance | pending app config deployment | exact mappings unavailable |
| Neovim | Harpoon workflow | mark and jump | rapid project navigation | pending app config deployment | exact mappings unavailable |
| Neovim | search/tree/buffer workflows | fuzzy search, file tree, buffer switching | project navigation | pending app config deployment | exact mappings unavailable |
| Neovim | Rust mappings | Rust build/test/actions | Rust development flow | pending app config deployment | exact mappings unavailable |
| fish | Ctrl-r | history/search | recall previous commands | pending shell config deployment | exact function unavailable |
| fish | Ctrl-o | source-specific command workflow | user shell workflow | pending shell config deployment | private-path items excluded |
| fish | aliases/functions | assorted user workflows | preserve public intent | pending shell config deployment | private paths and secrets must not be copied |
| launcher | Super+R | app launcher | launch applications | `fuzzel` | official Arch package preserves launcher intent |
| launcher | Super+V | clipboard launcher mode | choose clipboard item | `cliphist` plus `fuzzel --dmenu` | intent preserved |
