# Theme system

Theme bundles are JSON files validated by `desktop/themes/schema.json` and `bin/infinity-validate`.

Each theme describes semantic colors, typography, icon/cursor themes, GTK/Qt names, terminal/tmux/Neovim palettes, Hyprland decoration, Quickshell tokens, lock/greeter/Plymouth treatment, and wallpaper/art licensing.

Use:

```sh
./bin/infinity-theme list
./bin/infinity-theme preview nocturne
./bin/infinity-theme preview signal-archive
./bin/infinity-theme wallpapers
./bin/infinity-theme wallpaper aurora --dry-run --target-user sam
./bin/infinity-theme apply nocturne --dry-run --target-user sam
```

`list` and `preview` only read repository data. `apply --dry-run` prints target paths without writing. A real `apply` snapshots every existing regular destination, writes each new file through an exclusive temporary file in the same directory, and atomically replaces the destination. If any write fails, all earlier destinations are restored. Symlink destinations, unsafe user names, theme traversal, and wallpaper paths outside `desktop/wallpapers/` are rejected.

Generated outputs cover Quickshell, Hyprland, hyprlock, Ghostty, tmux, Neovim, selected-theme state, wallpaper state, and the current wallpaper. Hyprland receives `.config/hypr/generated-theme.lua`; hyprlock receives `.config/hypr/generated-lock.conf`. Both are loaded after static defaults and before user overrides.

The deployed shell carries a self-contained runtime copy under `~/.local/share/infinity-os/runtime/`. This lets unprivileged theme and wallpaper UI actions use the same validated, symlink-safe atomic transaction as the CLI. Theme cards preview palette tokens in memory; Apply commits all outputs. Wallpaper selection changes only the wallpaper and preserves the active theme.

The greetd/ReGreet login surface is system-owned. It receives repository-authored default styling during privileged deployment but deliberately does not change from an unprivileged user theme click. Live greeter propagation requires a future privileged, authenticated system service; the shell does not bypass that boundary.
