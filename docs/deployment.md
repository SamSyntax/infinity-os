# Deployment and backup model

Declared mappings live in `deployment/mappings.tsv`.

Rules:

- Source paths must be repository-local.
- Target paths are either target-user home relative paths or explicit target-root `etc/...` paths.
- Existing user-owned config marked `preserve_override=yes` is backed up before replacement.
- Backups are written under `.local/share/infinity-os/backups/<timestamp>/` in the target user's home.
- Deployment records `.local/share/infinity-os/deployment-manifest.json`.
- Secrets, browser profiles, shell history, SSH keys, credentials, caches, and runtime state are never deployment sources.

Preview:

```sh
./bin/infinity-deploy --dry-run --target-root / --target-user sam
```
