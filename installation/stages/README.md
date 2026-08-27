# Installer stages

The first-pass implementation keeps stage logic in `installation/lib/installer.sh` to preserve a thin entry point while avoiding premature fragmentation. Split a stage into this directory once it gains real apply operations beyond planning/deployment delegation.
