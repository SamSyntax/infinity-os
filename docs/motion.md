# Motion contract

Motion communicates state and spatial origin.

- Panels grow from their anchor.
- Launcher search transitions from idle art to results.
- Theme previews animate before commit and never flash unthemed states.
- Workspace transitions remain directional where available.
- OSDs enter from one predictable region and decay cleanly.
- Reduced-motion mode must collapse nonessential animation while preserving state changes.

The current QML slice uses shared duration tokens, transform/opacity transitions, anchored popup growth, theme-card selection, wallpaper crossfades, and OSD decay. `ShellState.reducedMotion` collapses shell durations to zero; `motionScale` adjusts them without editing components. Both values persist in `~/.config/infinity-os/shell.json`.

The login visual layer uses slow counter-rotating field lines behind ReGreet and accepts `INFINITY_REDUCED_MOTION=1`. ReGreet remains the authentication UI.

Hyprlock 0.9.6 renders the lock clock as separate HOURS and MINUTES folios above its native password field. `/usr/bin/date` refreshes the two digit labels once per second, but the digits do not mechanically flip: upstream hyprlock cannot tween label text, position, or opacity. The folio plates, seam, and register marks are static shapes. Current lockscreen motion is limited to the supported `fadeIn`, `fadeOut`, `inputFieldColors`, `inputFieldDots`, and `inputFieldWidth` animation nodes.

Hyprlock remains the real session-lock protocol client and authentication boundary; the folio is presentation only. Hyprlock reduced motion currently requires changing its own `animations.enabled` setting, while `hyprlock --no-fade-in` suppresses only startup fade-in. There is no bridge from the persisted Quickshell reduced-motion setting to either control. Display-off remains a later hypridle state, not a fake fullscreen overlay.

The repository validator checks the lockscreen structure, property allowlists, fixed commands, stacking, and security invariants. It does not prove runtime rendering: hyprlock is unavailable on the development host, so the final appearance and authentication flow still require VM or sacrificial-machine validation.
