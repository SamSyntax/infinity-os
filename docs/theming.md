# Theme system

Theme bundles are JSON files validated by `desktop/themes/schema.json` and `bin/infinity-validate`.

Each theme describes semantic colors, typography, icon/cursor themes, GTK/Qt names, terminal/tmux/Neovim palettes, Hyprland decoration, Quickshell tokens, lock/greeter/Plymouth treatment, and wallpaper/art licensing.

Use:

```sh
./bin/infinity-theme list
./bin/infinity-theme preview nocturne
./bin/infinity-theme preview signal-archive
./bin/infinity-theme apply nocturne --dry-run --target-user sam
```

`list` and `preview` only read repository data. `apply --dry-run` prints target paths without writing. A real `apply` snapshots every existing regular destination, writes each new file through an exclusive temporary file in the same directory, and atomically replaces the destination. If any write fails, all earlier destinations are restored. Symlink destinations, unsafe user names, theme traversal, and wallpaper paths outside `desktop/wallpapers/` are rejected.

Generated outputs currently cover Quickshell, Hyprland, Ghostty, tmux, Neovim, the selected-theme state file, and the current wallpaper. Hyprland receives `.config/hypr/generated-theme.lua`, which is loaded by `desktop/hypr/modules/theme.lua` after static decoration and before user overrides. GTK, Qt, greeter, lock, and Plymouth values are represented in the schema but live propagation for those surfaces is not implemented yet.
