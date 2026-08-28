# Deployment and backup model

Declared mappings live in `deployment/mappings.tsv`.

Rules:

- Source paths must be repository-local.
- Target paths are target-user home paths, `etc/...`, or the narrowly allowed `usr/share/...` asset path.
- Target users and relative paths are validated before use. Privileged writes reject symlink destinations and use exclusive temporary files plus atomic replacement.
- Existing user-owned config marked `preserve_override=yes` is backed up before replacement.
- Backups are written under `.local/share/infinity-os/backups/<timestamp-random>/` in the target user's home.
- Deployment records `.local/share/infinity-os/deployment-manifest.json`.
- Secrets, browser profiles, shell history, SSH keys, credentials, caches, and runtime state are never deployment sources.

Preview:

```sh
./bin/infinity-deploy --dry-run --target-root / --target-user sam
```
