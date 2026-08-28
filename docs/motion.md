# Motion contract

Motion communicates state and spatial origin.

- Panels grow from their anchor.
- Launcher search transitions from idle art to results.
- Theme previews animate before commit and never flash unthemed states.
- Workspace transitions remain directional where available.
- OSDs enter from one predictable region and decay cleanly.
- Reduced-motion mode must collapse nonessential animation while preserving state changes.

The current QML slice uses shared duration tokens, transform/opacity transitions, anchored popup growth, theme-card selection, and OSD decay. `ShellState.reducedMotion` collapses durations to zero. Directional workspace motion and full preview-to-commit continuity remain future integration work.
