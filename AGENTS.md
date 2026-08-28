# Project Agent Instructions

## Mission

Build an original Arch Linux distribution/workstation environment inspired by the visual ambition and cohesion of Ryoku Arch, without cloning Ryoku wholesale. The first milestone is **not an ISO**. The first milestone is a repository that can reproducibly turn a fresh Arch installation into the complete desktop experience through a full setup/install script.

The finished system should feel like one designed product rather than a bag of dotfiles: boot experience, greeter, Hyprland session, Quickshell shell, launcher, notifications, lock screen, idle behavior, theme switching, wallpapers, terminal/editor integrations, and system utilities should share a coherent visual language and motion system.

Ryoku Arch is the primary aesthetic/product reference:
- https://github.com/neur0map/ryoku-arch

Use it to study ideas, interaction patterns, architecture, polish, animation philosophy, and product cohesion. Do not blindly copy its code, branding, artwork, names, or assets. Reimplement concepts in this repository with an original identity and maintainable structure.

## Absolute workspace rule

**Never modify the user's existing machine dotfiles or arbitrary files outside this repository while developing the project.**

The current repository is the only writable source workspace.

This rule has two distinct meanings:

1. **While acting as a coding agent:** only create, edit, rename, or delete files inside the repository root. Reading user configuration outside the repository is allowed only when the environment exposes it and only for compatibility analysis. Never write to the source dotfiles.
2. **For the installer we build:** the installer is intentionally allowed to modify a target Arch system when the user explicitly runs it. Those writes must be declared, scoped, idempotent where practical, backed up when replacing existing user config, and support a dry-run/plan mode.

Never use the development task itself as an excuse to change `~/.config`, `/etc`, `/usr`, `/boot`, the current machine's services, or the user's live desktop. Generate the files/scripts that will do those things later when deliberately executed.

## User configuration is a compatibility contract

The user already has established muscle memory and application workflows. Preserve them.

Highest-priority compatibility sources include:

- `~/.config/hypr/bindings.lua` (or the workspace-provided equivalent such as `.config/hypr/bindings.lua`)
- Hyprland input/workspace/window behavior surrounding those bindings
- Neovim configuration and keymaps
- tmux configuration and keybindings
- terminal configuration
- shell aliases/functions
- launcher bindings
- screenshot/recording bindings
- clipboard bindings
- media/volume/brightness bindings
- any other application keymaps discovered in the user's dotfiles

### Rules for importing user behavior

- Treat existing keybindings as **requirements**, not inspiration.
- Read and inventory them before defining conflicting defaults.
- Never edit the original files.
- Copy or translate required behavior into this repository's own config structure.
- Keep a compatibility manifest under `docs/compatibility/` showing the source action, source binding, new implementation, and conflict status.
- If the source files are unavailable, create explicit TODOs/placeholders and do not guess what the bindings are.
- New distro-only shortcuts may be added only when they do not conflict with preserved bindings.
- Prefer a small, discoverable set of new global shortcuts over a large new keymap.
- If an imported binding refers to a tool the new distro does not use, preserve the **intent** and map it to the replacement tool where reasonable.

## Product principles

### 1. Repository is the source of truth

A live system is a deployment target. Configuration is authored here and installed from here.

Avoid workflows that depend on hand-tuning the live system after installation.

### 2. One coherent desktop

The UI should share:

- spacing scale
- typography
- radii
- borders
- translucency/blur rules
- elevation/shadow rules
- palette tokens
- animation durations
- easing/spring curves
- icon style
- interaction states

Quickshell surfaces should consume shared design tokens instead of hardcoding unrelated values.

### 3. Motion is functional

Animations should communicate state and spatial relationships, not merely decorate.

Examples:

- panels grow from their anchor
- widgets morph into detail panels
- launcher results transition from idle/art state into search state
- theme previews animate into the committed theme
- lock/unlock transitions have continuity
- workspace changes feel directional
- OSDs enter from a predictable region and decay cleanly

Respect reduced-motion accessibility and low-power modes.

### 4. Original identity, Ryoku-level polish

Aim for the same degree of intentionality as Ryoku, not a pixel-for-pixel copy.

Build an original visual identity using:

- original project name/mark
- original artwork or properly licensed assets
- distinctive typography pairing
- curated wallpaper/art packs
- intentional light/dark themes
- a consistent visual motif

### 5. Reproducibility over cleverness

Prefer boring, understandable installation and deployment code over opaque magic.

- shell scripts should use strict mode
- operations should be decomposed into functions/modules
- installation steps should be logged
- package lists should be data files, not repeated inline everywhere
- target-state checks should make reruns safe where practical
- destructive operations require explicit confirmation

## First milestone

Do **not** start by building an ISO.

Build a complete repository-driven setup path first.

The first usable milestone should be able to take a fresh Arch environment and create the workstation experience, including at minimum:

- Arch package configuration
- user creation/configuration hooks where applicable
- networking
- audio
- Bluetooth
- fonts
- graphics stack detection/installation
- Hyprland
- portals and Wayland essentials
- Quickshell
- terminal
- shell
- tmux
- Neovim
- file manager
- browser integration/defaults
- notifications
- clipboard tooling
- screenshots and screen recording
- media controls
- power/session controls
- idle handling
- lock screen
- login/greeter
- bootloader configuration
- Plymouth boot splash
- theming engine
- wallpaper management
- animated theme chooser with visual previews
- app-theme propagation
- user service setup
- basic recovery/backups

A later milestone may wrap the same system definition in archiso. Do not create a separate second configuration universe for the ISO.

## Proposed repository architecture

Keep responsibilities separated. Adjust names if the project develops a better vocabulary, but preserve the separation of concerns.

```text
.
├── AGENTS.md
├── README.md
├── install.sh
├── bin/
│   └── <project-cli>
├── installation/
│   ├── lib/
│   ├── stages/
│   ├── hardware/
│   └── recovery/
├── system/
│   ├── packages/
│   ├── boot/
│   ├── plymouth/
│   ├── services/
│   ├── security/
│   ├── power/
│   └── hardware/
├── desktop/
│   ├── hypr/
│   ├── quickshell/
│   ├── lockscreen/
│   ├── greeter/
│   ├── themes/
│   ├── wallpapers/
│   ├── assets/
│   └── apps/
│       ├── nvim/
│       ├── tmux/
│       ├── terminal/
│       ├── shell/
│       └── ...
├── user/
│   ├── defaults/
│   ├── overrides/
│   └── migrations/
├── docs/
│   ├── architecture.md
│   ├── installation.md
│   ├── visual-language.md
│   ├── motion.md
│   ├── theming.md
│   └── compatibility/
└── tests/
```

### Ownership model

Use three layers where possible:

1. **Base/system layer** — packages, services, boot, hardware policy.
2. **Distro desktop layer** — maintained configs shipped by this repo.
3. **User override layer** — intentionally preserved/custom values that load last.

Never make routine updates overwrite user-specific overrides.

## Hyprland

Prefer modular configuration. If Lua-based Hyprland configuration is viable with the chosen tooling, it is acceptable and fits the user's existing `bindings.lua`; otherwise keep the binding data in Lua or another structured source and generate/load the required Hyprland form.

Separate at least:

- environment
- monitors
- input
- decoration
- animations
- workspaces
- window rules
- layer rules
- autostart
- bindings
- device-specific overrides
- user overrides

Before adding a binding, check the imported compatibility inventory for conflicts.

## Quickshell desktop shell

Quickshell should be a central part of the product, not just a bar.

Build reusable QML components and centralized tokens. Expected surfaces include:

- bar/rail
- status/control center
- app/command launcher
- workspace overview
- notification center/toasts
- OSD
- power/session menu
- wallpaper layer
- desktop art/widgets
- theme/appearance UI
- theme preview overlay
- lock-screen UI if supported by the chosen locking architecture
- optional first-run welcome

Use shared services/singletons for state such as:

- theme
- wallpaper
- network
- Bluetooth
- audio
- brightness
- battery/power
- media
- notifications
- workspaces/windows
- session actions

Do not create giant QML files containing unrelated concerns.

## Theme system

The theme system is a first-class feature.

A theme should be a data-driven bundle rather than scattered edits. It should be able to describe:

- semantic palette
- wallpaper/art selection
- font choices if supported
- icon theme
- cursor theme
- GTK theme
- Qt theme
- terminal palette
- Neovim flavor/accent where practical
- tmux status palette where practical
- Hyprland border/shadow/decoration values
- Quickshell tokens
- lock screen/greeter treatment
- Plymouth palette/assets where practical

### Animated theme switcher

Implement a polished visual theme chooser with previews.

Requirements:

- preview cards or live miniature compositions
- current theme clearly indicated
- keyboard and pointer navigation
- animated focus/selection states
- preview-before-commit behavior when feasible
- smooth transition from old to new shell palette
- no flashing unthemed intermediate state
- atomic theme application where possible
- rollback when an apply step fails
- persistent selected theme

Wallpaper-driven palette generation (for example via Matugen or an equivalent) may be offered, but curated themes should remain available and deterministic.

## Boot, greeter, lock, and session continuity

The system should feel designed before the desktop appears.

### Boot

- choose and document the bootloader architecture
- configure a polished boot menu
- integrate Plymouth cleanly with initramfs
- use matching branding/art direction
- avoid boot-time text flashes where reasonably possible
- retain useful recovery/fallback entries

### Greeter

Use a Wayland-compatible greeter/display manager stack that works reliably with Hyprland.

The login experience should match the desktop theme while remaining robust and easy to recover from.

### Lock screen

The lock screen must be secure first and beautiful second.

- never fake locking with a fullscreen overlay
- use a real locking protocol/locker
- Quickshell can provide visuals only when the architecture remains genuinely secure
- support idle -> dim -> lock -> display-off behavior
- preserve media/time/battery affordances without exposing sensitive data

## Installation script contract

The root `install.sh` should be a thin, readable entry point that dispatches to installation modules.

Support, at minimum:

- `--help`
- `--dry-run` or `--plan`
- non-destructive preflight inspection
- clear target detection
- explicit confirmation for destructive steps
- logs
- resumable/idempotent stages where practical
- package installation separated from config deployment
- hardware detection with user-visible decisions
- backups before replacing pre-existing target configs
- failure messages that explain recovery

Do not silently repartition disks. If fresh-disk provisioning is added, put it behind an explicit mode and multiple safety checks. A safe initial version may assume Arch is already bootstrapped/mounted and focus on making the installed system complete.

Keep installation data separate from the script logic, e.g. package manifests by concern.

## Hardware policy

Do not assume one machine.

Handle or clearly document:

- Intel/AMD CPUs
- AMD/Intel/NVIDIA GPUs
- laptops vs desktops
- HiDPI/mixed-DPI displays
- touchpads
- Bluetooth
- common audio stack
- brightness/backlight
- battery/power profiles
- suspend/hibernate considerations

Prefer detection + small policy modules over a giant conditional installer.

## Secrets and safety

- Never commit passwords, tokens, SSH private keys, Wi-Fi PSKs, cookies, browser profiles, or machine-specific secrets.
- Never copy secrets from the user's source dotfiles into this repo.
- Use placeholders and runtime prompts for secrets.
- Never weaken authentication merely to make theming easier.
- Never disable Secure Boot/security controls silently.

## Research rules

When external research is available, check current upstream documentation before making choices that depend on fast-moving projects such as:

- Arch Linux installation details
- Hyprland syntax/features
- Quickshell APIs
- display manager/greeter compatibility
- Plymouth hooks
- NVIDIA Wayland requirements
- xdg-desktop-portal behavior

Use Ryoku as a design/architecture reference, but also verify assumptions against upstream projects.

## Implementation workflow

For every substantial feature:

1. Inspect the repository for existing related code.
2. Read the relevant user compatibility source if available.
3. Write/update the design note when architecture changes.
4. Implement the smallest complete vertical slice.
5. Add validation/tests/lint checks where practical.
6. Run shell/QML/Lua syntax checks relevant to touched files.
7. Verify no files outside the repository were modified.
8. Summarize what is done, what remains, and any decision that needs future user input.

## Development teaching contract

The user wants to understand how this distribution is built, not only receive finished code. Treat every substantial work session as both implementation and instruction.

When reporting work:

- Explain the goal of each subsystem in plain language before describing its files. Assume the reader is new to building Linux distributions.
- Explain why consequential choices were made, what alternatives exist, and what tradeoffs the chosen approach introduces.
- Describe how the relevant parts connect from boot to greeter to Hyprland to Quickshell to applications. Do not present isolated configuration fragments without their place in the full system.
- Define unfamiliar Arch, systemd, Wayland, Hyprland, Quickshell, QML, packaging, and security terms when they first appear. Do not rely on unexplained jargon.
- For every command the user can run, explain what it does, where it writes, whether it needs root privileges, and how to recognize success or failure.
- Explain important code and configuration behavior step by step, including inputs, outputs, target paths, safety checks, backup behavior, and rerun behavior.
- Distinguish clearly between implemented, tested, planned, mocked, and placeholder behavior. Never let a visual prototype sound like a complete system integration.
- Include verification evidence and explain what each check proves and what it does not prove.
- Call out security boundaries explicitly, especially authentication, locking, privileged installation, target path validation, ownership, and secrets.
- Keep explanations approachable but technically honest. Prefer concrete examples and small diagrams or ordered flows when they make the system easier to understand.

Do not use “vibe coding” as the development model. Repository changes must be grounded in documented intent, current upstream behavior, observable tests, and an explanation the user can learn from.

## Testing expectations

At minimum, provide automated checks for:

- shell syntax
- duplicate keybindings where detectable
- missing commands referenced by bindings/autostart
- broken symlink/deployment mappings
- invalid package manifest entries where practical
- QML format/static checks available in the chosen stack
- Lua syntax
- theme schema validity
- required theme assets
- install-script dry-run behavior

Eventually add VM-based installation smoke tests.

## Definition of done for the first major milestone

The first setup milestone is done when the repository can reproducibly create a coherent system in a VM or sacrificial test machine and the user can:

- boot through the branded boot flow
- reach the themed greeter
- log into Hyprland
- use preserved core keybindings
- open and operate the Quickshell launcher/control surfaces
- use Neovim and tmux with preserved important mappings
- lock/unlock securely
- suspend/log out/reboot/shut down
- change wallpaper
- switch themes through an animated preview UI
- see the theme propagate across the major desktop surfaces
- rerun the installer/deployer without needless breakage
- understand how to recover if a deployment fails

Do not call the system complete merely because Hyprland launches.
