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
  - `wallpaper/` — wallpaper picker/grid with live preview, search, and
    optional per-monitor directories/tabs (see "Per-monitor wallpapers"
    below).
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
- **`dev/preview/`** — a way to visually sanity-check the Quickshell QML in
  an ordinary window, without installing Quickshell or Hyprland at all (see
  "Previewing the UI without Hyprland/Quickshell" below).

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
| `--list-whitelist` | Print the configured app-launcher whitelist and exit — no other action taken. |
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
| `DOTFILES_WALLPAPER_DIRS` | Optional per-monitor wallpaper directories. `setup.sh` regenerates `~/.config/quickshell/wallpaper/monitors.conf` from this array every run (see "Per-monitor wallpapers" below). |

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

## Per-monitor wallpapers

By default the wallpaper picker shows one shared library
(`~/Pictures/Wallpapers`, `~/Pictures`) applied to every monitor at once. To
give specific monitors their own directory, add entries to
`DOTFILES_WALLPAPER_DIRS` in `setup.conf`/`setup.conf.local`:

```sh
DOTFILES_WALLPAPER_DIRS=(
  "DP-1:Pictures/Wallpapers/ultrawide"
  "HDMI-A-1:Pictures/Wallpapers/portrait"
)
```

Find your monitor names with `hyprctl monitors`. `setup.sh` regenerates
`~/.config/quickshell/wallpaper/monitors.conf` from this array every run (a
real file written into `$HOME`, not tracked in git — it embeds
machine-specific absolute paths). The picker then shows an "All Monitors"
tab plus one tab per connected screen: picking a monitor's own tab restricts
the grid to its configured directory and applies only to that output;
"All Monitors" applies to every connected output at once and uses the
shared library. A monitor not listed here just falls back to the shared
library, same as before this feature existed.

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
~/.config/hypr/audioswitch.sh --help   # usage
~/.config/hypr/audioswitch.sh          # actually switch (what the keybind runs)
```

If nothing is configured at all, it cycles through every currently available
sink — a safe, universal default rather than failing on a fresh machine.
Requires `wpctl` (from `wireplumber`) to actually switch the sink; `pactl`
is used opportunistically for reading the current default but isn't a
substitute for `wpctl` — `check_dependencies` will tell you if it's missing.

## Previewing the UI without Hyprland/Quickshell installed

`dev/preview/` renders any of this repo's real, unmodified `.qml` files in
an ordinary desktop window, using small fake stand-ins for Quickshell's
building blocks (`dev/preview/qmlshim/`) instead of a real Quickshell
install — useful for sanity-checking layout/color/spacing changes on a
machine that doesn't have Hyprland or Quickshell at all (including, notably,
the machine this repo's own installer development happens on).

**Requirements:** only Qt6's own `qml` binary
(`pacman -S --needed qt6-declarative`) — nothing from this repo needs to be
installed or linked into `$HOME` to use it.

```sh
dev/preview/run.sh launcher        # applauncher/AppLauncher.qml
dev/preview/run.sh notifications   # notifications/NotificationPopup.qml
dev/preview/run.sh wallpaper       # wallpaper/WallpaperManager.qml
dev/preview/run.sh media           # media/MediaControl.qml
dev/preview/run.sh shell           # shell.qml — all four components at once
dev/preview/run.sh --help          # usage
```

IPC-triggered panels (the launcher, wallpaper picker, and notifications) open
automatically shortly after the window appears, since there's no real
`qs ipc call` bridge to trigger them by hand outside a real Quickshell
session. Close the window (or `Ctrl-C` in the terminal) to stop.

**What this does and doesn't verify:** it confirms the QML actually
*loads and runs* — imports resolve, singletons work, functions exist,
bindings don't throw — which has caught real bugs before (a missing import
that would have crashed the whole shell on startup; a singleton
registration bug that silently broke the app launcher and wallpaper picker).
It does **not** exercise real wlr-layer-shell rendering/anchoring, real
D-Bus notifications, real MPRIS players, real desktop entries, or real
wallpaper application — `qmlshim/` feeds each component small, fake sample
data instead. Treat a clean run as "this code isn't broken," not as
"this looks and behaves exactly like it will under Hyprland."

Every `.qml` file's own comments in `qmlshim/` explain exactly what's faked
and why, and `dev/preview/run.sh --help`'s output (plus the comments at the
top of that file) cover the rest of its behavior and known limitations in
more depth than belongs in this README.

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
  whitelist.sh       regenerates common/Whitelist.qml from DOTFILES_APP_WHITELIST
  wallpaperconf.sh   regenerates wallpaper/monitors.conf from DOTFILES_WALLPAPER_DIRS
dev/preview/         QML preview harness — see "Previewing the UI" above
  run.sh             preview launcher (requires only qt6-declarative)
  qmlshim/           fake Quickshell types the preview loads instead of the real thing
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

## More documentation

- [`CHANGELOG.md`](CHANGELOG.md) — the full history of this fork, written as
  a teaching document (what changed, why, how, and why not) for anyone
  learning git or programming alongside this project.
- [`conclusion.md`](conclusion.md) — working session notes: what's verified,
  what's still open, for anyone picking the project back up.

## License

GPLv3 — see [LICENSE](LICENSE).
