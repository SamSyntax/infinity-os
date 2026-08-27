# Theme system

Theme bundles are JSON files validated by `desktop/themes/schema.json` and `bin/infinity-validate`.

Each theme describes semantic colors, typography, icon/cursor themes, GTK/Qt names, terminal/tmux/Neovim palettes, Hyprland decoration, Quickshell tokens, lock/greeter/Plymouth treatment, and wallpaper/art licensing.

Use:

```sh
./bin/infinity-theme list
./bin/infinity-theme preview nocturne
./bin/infinity-theme apply nocturne --dry-run --target-user sam
```

Apply writes generated files to a target config/state tree through a staging directory, then atomically promotes the staged tree. It never invokes live applications.
