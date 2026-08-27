# Application compatibility inventory

Read-only summaries from source configs. Private paths are excluded.

## tmux

- Prefix: `C-a`.
- Copy mode: vi-style navigation/selection.
- Pane navigation integrates with `C-h/j/k/l` muscle memory.
- Splits preserve/current-path behavior.
- TPM and tmux-resurrect are part of the expected workflow.

## Neovim

- Navigation: window movement mappings aligned with `h/j/k/l` conventions.
- Formatting/actions: formatter and code-action mappings are important preserved intents.
- Harpoon: quick mark and jump workflow must remain available.
- Search/tree/buffers: fuzzy search, file tree, and buffer switching are expected.
- Rust: Rust-specific build/test/action mappings are expected.

## fish/shell

- `Ctrl-r`: history/search workflow.
- `Ctrl-o`: source-specific command workflow.
- Aliases/functions: preserve public intents; private-path items are pending and must not be copied into this repo.

## Unavailable or pending configs

- Full terminal theme/keymap source beyond Hypr binding usage.
- Complete private fish functions with machine-specific paths.
- Exact Neovim and tmux files were not imported into the repository; this document records the compatibility contract for later concrete mapping.
