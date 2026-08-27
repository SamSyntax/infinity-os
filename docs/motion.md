# Motion contract

Motion communicates state and spatial origin.

- Panels grow from their anchor.
- Launcher search transitions from idle art to results.
- Theme previews animate before commit and never flash unthemed states.
- Workspace transitions remain directional where available.
- OSDs enter from one predictable region and decay cleanly.
- Reduced-motion mode must collapse nonessential animation while preserving state changes.

Current foundation exposes duration/easing tokens in `desktop/themes/*.json`; QML implementation is pending.
