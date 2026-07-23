# Arch-Dot-files-Fork

A Hyprland + [Quickshell](https://quickshell.outfoxxed.me/) desktop setup for
Arch Linux: window manager config, a custom app launcher, notification
popups, a wallpaper picker, MPRIS media controls, and an audio-sink switcher
script — plus a menu-driven installer that can safely apply all of it (or
just preview what it would do) on a fresh machine.

## Features

- **Hyprland** config (`~/.config/hypr/hyprland.conf`) — gaps, animations,
  keybinds, window rules, and a multi-monitor-safe catch-all monitor rule
  (commented examples for per-monitor setups).
- **Quickshell** shell (`~/.config/quickshell/`), split into small modules:
  - `applauncher/` — searchable app launcher, filtered to an allow-list of
    desktop entries (`common/Whitelist.qml`).
  - `notifications/` — themed notification popups (urgency colors, icons,
    dismiss/expire handling).
  - `wallpaper/` — wallpaper picker/grid with live preview and search.
  - `media/` — MPRIS-backed media transport widget (play/pause/next/prev).
  - `common/` — the shared `Theme.qml` and `Whitelist.qml` every module
    above imports, so there is exactly one place to edit colors or the
    launcher's allowed apps.
- **`audioswitch.sh`** — round-robins the default PipeWire sink between
  devices you configure by name or ID (bound to a media key in
  `hyprland.conf`); self-healing and machine-independent (see below).
- **`setup.sh`** — a from-scratch installer: checks/installs dependencies,
  backs up anything it would overwrite, links this repo's `~/` tree onto
  your real `$HOME`, and can be run as a single `curl | bash` command on a
  fresh install.

## Requirements

- Arch Linux (or an Arch-based derivative) with `pacman`.
- `git` (the installer will tell you if it's missing).
- An AUR helper (`yay` or `paru`) if you want `quickshell-git` installed
  automatically — Quickshell isn't in the official repos.

Everything else (`hyprland`, `kitty`, `dolphin`, `wofi`, `pipewire`, etc.) is
declared in [`setup.conf`](setup.conf) and offered for install automatically.

## Install

### Quick install (fresh system)

```sh
curl -fsSL https://raw.githubusercontent.com/Tristan-Phillips/Arch-Dot-files-Fork/main/setup.sh | bash
```

This clones the repo to `~/.local/share/arch-dotfiles-fork` and re-execs
`setup.sh` from inside the clone. Run in a real terminal, it opens an
**interactive menu** (arrow keys + Enter, no extra dependency like
`dialog`/`whiptail` required):

- **Install / update dotfiles** — resolves dependencies, then links files.
- **Dry run (preview only, no changes)** — walks the exact same steps and
  prints exactly what would happen, without installing or moving anything.
- **Configure optional packages** — a checklist (space to toggle) to pick
  which optional/AUR packages to install *for this run*.
- **View log & backup locations** — shows where this run's log file and any
  backups are/would be written.

Piped into a non-interactive shell, or when you pass `-y`/`-n`/`--no-menu`,
it skips the menu and just runs.

### Manual install (from a clone)

```sh
git clone https://github.com/Tristan-Phillips/Arch-Dot-files-Fork.git
cd Arch-Dot-files-Fork
./setup.sh
```

### Command-line flags

| Flag | Effect |
|---|---|
| `-y`, `--yes` | Assume "yes" on every prompt; skips the menu (non-interactive/scriptable). |
| `-n`, `--dry-run` | Preview every step — no packages installed, no files touched, no backups moved. Skips the menu. |
| `-v`, `--verbose` | Print extra debug detail (also written to the log regardless). |
| `--no-menu` | Run the plain step-by-step flow even on a real terminal. |
| `-h`, `--help` | Show usage. |

`-y` and `-n` combine (`./setup.sh -y -n`) for a fully unattended preview,
e.g. in CI.

## Configuration

All installer behavior is driven by [`setup.conf`](setup.conf) — every
setting there is documented inline with exactly which script consumes it
(there's nothing unused/decorative in it). To customize without touching a
tracked file (and without fighting `git pull` afterwards), create
**`setup.conf.local`** next to it — sourced automatically if present, and
ignored by git:

```sh
# setup.conf.local
DOTFILES_OPTIONAL_PKGS=(playerctl brightnessctl libnotify ttf-hack-nerd)
DOTFILES_TARGET_HOME="$HOME"
```

Key settings:

| Variable | Purpose |
|---|---|
| `DOTFILES_BACKUP_DIR` | Where overwritten files are moved (timestamped per run). |
| `DOTFILES_LOG_DIR` | Where install logs are written. |
| `DOTFILES_TARGET_HOME` | Home directory to link into (defaults to `$HOME`). |
| `DOTFILES_ENSURE_DIRS` | Paths kept as real directories instead of symlinks (e.g. `Pictures/Wallpapers`, since that's personal data, not tracked here). |
| `DOTFILES_REQUIRED_PKGS` / `_OPTIONAL_PKGS` / `_AUR_PKGS` / `_CONFLICT_PKGS` | The dependency manifest used by `lib/deps.sh`. |
| `DOTFILES_APP_WHITELIST` | The app launcher's allow-list. `setup.sh` regenerates `common/Whitelist.qml` from this array every run (see "App whitelist" below). |

`DOTFILES_REPO_URL` and `DOTFILES_CLONE_DIR` are **environment variables**
(not `setup.conf` settings) read only during the initial `curl | bash`
bootstrap, e.g.:

```sh
DOTFILES_CLONE_DIR=/opt/dotfiles curl -fsSL .../setup.sh | bash
```

## App whitelist

The launcher only shows apps whose desktop-entry ID is in `DOTFILES_APP_WHITELIST`
(in `setup.conf`/`setup.conf.local`) — that's the single place to edit it.
`common/Whitelist.qml` is a generated file regenerated from that array on every
run; don't hand-edit it directly. See what's currently configured at any time
with:

```sh
./setup.sh --list-whitelist
```

(also available as "View whitelisted apps" in the interactive menu). Find the
exact ID for an app with:

```sh
find /usr/share/applications ~/.local/share/applications -name '*.desktop'
```

## How linking works

`setup.sh` never symlinks whole directories — only the individual files
that actually exist in this repo's `~/` tree, creating real (non-symlinked)
parent directories along the way. That means anything else already living
under `~/.config` or `~/Pictures` is left completely untouched. Any file
`setup.sh` would overwrite is moved (never deleted) into
`DOTFILES_BACKUP_DIR` first.

## Keybindings (Hyprland, `$mainMod` = Super)

| Bind | Action |
|---|---|
| `Super + Q` | Open terminal (kitty) |
| `Super + C` | Close active window |
| `Super + E` | Open file manager (dolphin) |
| `Super + V` | Toggle floating |
| `Super + L` | Lock screen |
| `Super + R` | Toggle app launcher |
| `Super + Shift + R` | Toggle wofi (fallback launcher) |
| `Super + W` | Toggle wallpaper picker |
| `Super + P` | Toggle pseudotile (dwindle) |
| `Super + J` | Toggle split direction (dwindle) |
| `Super + M` | Exit Hyprland / `hyprshutdown` if present |
| `Super + S` / `Super + Shift + S` | Toggle / move to scratchpad |
| `Super + [1-0]` | Switch workspace |
| `Super + Shift + [1-0]` | Move window to workspace |
| `Super + arrows` | Move focus |
| `Super + mouse wheel` | Scroll workspaces |
| `XF86Audio*`, `XF86MonBrightness*` | Volume / mic mute / brightness |
| `Super + XF86AudioPlay` | Run `audioswitch.sh` |

## `audioswitch.sh`

Cycles the default PipeWire sink between devices you configure — by name
(recommended, stable across reboots) or by numeric PipeWire ID. Configure it
via **`~/.config/hypr/audioswitch.conf`**, not an environment variable —
Hyprland's `exec` (used by the keybind in `hyprland.conf`) does not inherit
variables merely exported in your shell's rc file, so an env-var-only setup
silently never applies when triggered by the actual keybind:

```sh
echo 'AUDIOSWITCH_SINK_NAMES="Razer,Speaker"' > ~/.config/hypr/audioswitch.conf
```

```sh
~/.config/hypr/audioswitch.sh --list   # see available sinks (ID + name)
```

If nothing is configured at all, it cycles through every currently available
sink — a safe, universal default rather than failing on a fresh machine.

## Updating

```sh
cd ~/.local/share/arch-dotfiles-fork   # or wherever you cloned it
git pull
./setup.sh
```

Re-running is always safe: unchanged files are left alone, and anything
that would be overwritten is backed up first.

## Uninstalling / rolling back

Nothing is ever deleted. To restore what was there before, copy files back
out of the timestamped folder shown in a run's summary (or under
`~/.local/share/arch-dotfiles-fork/backups/`), then remove the symlinks
`setup.sh` created.

## Project structure

```
setup.sh            entry point: bootstrap, CLI flags, orchestration
setup.conf           tracked default configuration (see above)
setup.conf.local     optional, git-ignored personal overrides
lib/
  log.sh             logger (single shared instance + log file)
  ui.sh              tty detection, y/n prompts, danger banners
  menu.sh            pure-bash interactive menu (arrow keys, checklists)
  net.sh             connectivity check + retry-with-backoff
  pkg.sh             pacman/AUR-helper strategy (install, self-heal stale locks)
  deps.sh            dependency + conflict policy, built on pkg.sh
  backup.sh          timestamped backup-before-overwrite
  link.sh            file-level symlinking of the repo's `~/` tree
~/                   the actual dotfiles, mirroring $HOME's layout
```

The installer is organized around a few recognizable patterns, applied
where they genuinely fit a shell script:

- **Strategy** (`pkg.sh`) — install logic is uniform (`pkg::install_official`
  / `pkg::install_aur`) regardless of which concrete backend (pacman, yay,
  paru) actually runs.
- **Template Method** (`run_pipeline` in `setup.sh`) — the install sequence
  is fixed; each step's real behavior is implemented in its own module.
- **Singleton-style module state** (`log.sh`) — one shared logger instance,
  initialized once, used everywhere through its function API only.

## License

GPLv3 — see [LICENSE](LICENSE).
