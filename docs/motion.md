# Motion contract

Motion communicates state and spatial origin.

- Panels grow from their anchor.
- Launcher search transitions from idle art to results.
- Theme previews animate before commit and never flash unthemed states.
- Workspace transitions remain directional where available.
- OSDs enter from one predictable region and decay cleanly.
- Reduced-motion mode must collapse nonessential animation while preserving state changes.

The current QML slice uses shared duration tokens, transform/opacity transitions, anchored popup growth, theme-card selection, wallpaper crossfades, and OSD decay. `ShellState.reducedMotion` collapses shell durations to zero; `motionScale` adjusts them without editing components. Both values persist in `~/.config/infinity-os/shell.json`.

The login visual layer uses slow counter-rotating field lines behind ReGreet and accepts `INFINITY_REDUCED_MOTION=1`. ReGreet remains the authentication UI. Hyprlock uses its upstream fade, color, width, and password-dot animation tree while remaining the real session-lock protocol client. Display-off remains a later hypridle state, not a fake fullscreen overlay.
