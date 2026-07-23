# Session Handoff — Arch-Dot-files-Fork

Working directory: `/home/trap/git/forks/Arch-Dot-files-Fork` (fork of a Hyprland +
Quickshell Arch Linux dotfiles repo). Supersedes the previous version of this file,
which had gone stale mid-session — its "known-broken" list was written before the
final fixes landed, and a separate, real bug (below) was silently hiding new files
from git the whole time. This version reflects what was actually re-verified.

**Ground rule that held throughout:** nothing was ever installed on the real machine,
and the dotfiles were never symlinked into the real `$HOME`. All validation was via
`bash -n`, `qmllint`, and the `dev/preview/` QML preview harness, run against the
real, installed `qt6-declarative` (`/usr/lib/qt6/bin/qml`). `~/.config/hypr` and
`~/.config/quickshell` do not exist on this machine outside this repo.

## Two real bugs found this session that the previous handoff missed entirely

**1. `.gitignore`'s `*~` pattern was silently ignoring entire new directories.**
This repo's tracked tree is rooted at a literal `~/` directory (mirroring `$HOME`).
gitignore patterns match *any path component*, not just filenames — so the
"ignore editor backup files" rule `*~` also matched the root `~` directory
component itself, and once a directory is ignored, everything under it is
invisible to `git status`/`git add` regardless of the file's own name.
**Practical effect: `common/Theme.qml`, `common/Whitelist.qml`, and
`media/MediaControl.qml` — three files the previous session explicitly built and
believed were tracked — were never actually added to git at all.** Had this been
committed as-is, those files would have simply vanished for anyone cloning the
repo fresh, with no error or warning. Fixed by changing the pattern to `?*~`
(requires ≥2 characters, so it still catches real backup files like `file.txt~`
but can't match the bare single-character `~` directory). Always sanity-check
`git status --short -uall` after adding new files anywhere under `~/` in this repo.

**2. `pragma Singleton` alone does nothing in this Qt 6.11.1 QML engine — it
needs an explicit `qmldir` declaring the type `singleton`, or it silently
resolves to a broken, non-functional stand-in instead of erroring loudly.**
Confirmed via isolated repro (see below) and via the real files. This is the
actual root cause of the previous session's three "known-broken" preview
errors — they were real, not preview-only artifacts:

- `common/Whitelist.qml` (referenced via `import "../common" as Common` in
  AppLauncher.qml/others) — `Common.Whitelist.allowedAppIds` was `undefined`,
  so `.includes()` threw. **Fixed** by adding `common/qmldir`.
- `wallpaper/WallpaperService.qml` (referenced bare, same-directory, from
  WallpaperManager.qml) — resolved to a broken stand-in object missing
  `wallpapersFor`/`currentFor`/etc. **Fixed** by adding `wallpaper/qmldir`.
- `notifications/NotificationService.qml` (same pattern) — same failure mode.
  **Fixed** by adding `notifications/qmldir`.

Isolated repro proving the general rule (not specific to this codebase):
```qml
// MyService.qml
pragma Singleton
import QtQuick
QtObject { function doThing(x) { return "did " + x; } }
```
Without a `qmldir` declaring `singleton MyService 1.0 MyService.qml` next to it,
`MyService.doThing` is not a function anywhere it's referenced — with the qmldir,
it works. **If this repo's other hand-written singletons are ever extended, or if
new ones are added, they need a qmldir entry too, or they will silently misbehave
exactly like this — not just in the preview harness, but for real, since Quickshell
uses the same underlying QML engine.**

The previous session's belief that these three errors might be preview-harness
artifacts (shim data shape, singleton caching across scratch-copy runs, etc.) was
a reasonable hypothesis at the time but was wrong — worth remembering that
"looks like a harness problem" and "is a harness problem" are different claims,
and the isolated repro above is what actually settled it.

### Why the first re-verification pass this session gave a false "all clear"

Worth recording since it nearly caused a second stale handoff: this desktop
session runs under `systemd`/`journald`, and Qt's default message handler routes
`qWarning()`/`console.warn()`/QML binding errors to the journal instead of this
terminal's stderr whenever stderr isn't a tty (e.g. redirected to a log file, or
run under `timeout ... > file`). The very first re-run of the preview harness
this session showed zero errors for all five targets — which was wrong; the
errors were firing, just invisible. Forcing `QT_ASSUME_STDERR_HAS_CONSOLE=1`
(now exported unconditionally at the top of `dev/preview/run.sh`) surfaced them.
**Lesson: a clean-looking `qml` run with redirected output is not trustworthy
on its own — this env var (or a real attached terminal) is required.**

## What's actually done and verified working (re-verified this session)

All five preview targets (`launcher`, `notifications`, `wallpaper`, `media`,
`shell`) now load and run with **zero errors or warnings** other than one
confirmed-benign internal Qt message (`qt.core.qobject.connect: ... invalid
nullptr parameter`, emitted by `Instantiator`'s internal bookkeeping when used
for per-screen `Variants` — nothing fails to load, nothing is missing).

- **QML hardening** (all confirmed via harness + manual trace, not just `bash -n`):
  - `common/Theme.qml` + `common/Whitelist.qml` — single shared theme +
    app-launcher allow-list. **Now properly registered as QML types via
    `common/qmldir`** (see bug #2 above) — this was the missing piece.
  - `media/MediaControl.qml` — created; renders correctly (confirmed via
    screenshot: track title/artist + working prev/pause/next buttons against a
    fake MPRIS player).
  - `bgSecondary`/`accentSecondary` theme property bug — fixed (properties
    that don't exist on the shared theme are gone from `WallpaperManager.qml`).
  - Shared-theme imports use `import "../common" as Common` (not the
    single-file `import "../common/Theme.qml" as Theme` form, confirmed broken
    in this Qt 6.11.1 engine).
  - `media/MediaControl.qml` imports `Quickshell.Io` (needed for `IpcHandler`).
- **App whitelist wired into config**: `setup.conf`'s `DOTFILES_APP_WHITELIST`
  is the source of truth; `lib/whitelist.sh` regenerates `common/Whitelist.qml`
  from it (idempotent). Confirmed via harness: AppLauncher's whitelist filter
  now genuinely works — screenshot shows exactly the 5 expected whitelisted
  apps (Discord, LibreWolf, Network, ProtonPlus, Steam), correctly sorted.
- **Per-monitor wallpaper feature** — **now confirmed actually working**, not
  just `bash -n`-clean. `WallpaperService.qml`'s `wallpapersFor`/`currentFor`/
  `setWallpaper`/`_parseMonitorDirs`/`_parseState` all execute correctly once
  the singleton registration bug (above) was fixed — confirmed via screenshot:
  the monitor-tab selector row (`All Monitors` / `preview-DP-1` /
  `preview-HDMI-A-1`) renders and the empty state ("No wallpapers found / Add
  images to ~/Pictures/Wallpapers/") displays correctly with no fake data
  configured.
- **`audioswitch.sh`**, **`hyprland.conf`**, **`setup.sh` + `lib/`** — unchanged
  from previous session's work, still `bash -n` clean, not touched this session
  beyond the `.gitignore` fix above (which affects whether new files anywhere
  in the repo get tracked, not these specific files, which were already tracked).

## `dev/preview/` harness — now fully working, not "known-broken"

Fixed for real (not worked around) this session, in the shim only — **the real,
tracked dotfiles were never modified for harness compatibility**:

- **`Quickshell/Singleton.qml` added** — the shim never defined Quickshell's
  `Singleton` base type at all, which `WallpaperService.qml`/
  `NotificationService.qml` extend. Implemented as `Item` (never shown/parented)
  rather than `QtObject`, so its built-in `data` default property can hold the
  arbitrary QtObject-derived children (`Process`, `FileView`,
  `NotificationServer`) those files nest inside it — a bare `QtObject` has no
  default property for that and a custom `default property list<QtObject>`
  does not work for this either (confirmed via isolated repro).
- **`Quickshell/Variants.qml`**: was `Repeater {}`, which requires Item-derived
  delegates and fails ("Delegate must be of Item type") on
  `NotificationPopup.qml`'s `PanelWindow` (Window-derived) delegate. Changed to
  `Instantiator {}` (from `QtQml`), Quickshell's own real base for `Variants`,
  which has no such restriction.
- **`Quickshell/Wayland/PanelWindow.qml`**: added `property var screen: null`
  to shadow the real, inherited `Window.screen` (a genuine `QScreen*`-typed C++
  property) — real Quickshell's `PanelWindow.screen` takes a `ShellScreen`, and
  the fake plain-object screens `Quickshell.qml`'s shim provides can't assign
  to the real property ("Unable to assign QVariantMap to QQuickScreenInfo*").
- **`Quickshell/Services/Notifications/NotificationServer.qml`**: previously
  an inert placeholder with a comment pointing to a `dev/preview/README` that
  was never written. Now fires three fake notifications (varying urgency,
  with/without actions) through the *real* `NotificationService.qml`'s actual
  `onNotification`/cap-at-5 logic, as plain JS objects (not `Notification {}`
  instances — real `NotificationService.qml` does `notification.tracked =
  true`, and a QML object instance isn't extensible from JS the way a plain
  object is). This is also what surfaced the missing `actionsSupported` /
  `bodySupported` / `bodyMarkupSupported` / `imageSupported` / `keepOnReload`
  properties on the shim, since the real file assigns all five — added.
- **`Quickshell/DesktopEntries.qml`**: fixture bug — a bare string
  `"com.vysp3r.ProtonPlus.desktop"` was mixed into the fake `applications.values`
  array alongside real entry objects, silently filtered out instead of
  exercising the whitelist match it was clearly meant to test. Fixed to a
  proper entry.
- **`dev/preview/run.sh`**:
  - Exports `QT_ASSUME_STDERR_HAS_CONSOLE=1` unconditionally (see the
    journald/false-negative issue above) — documented prominently in the
    header comment so it isn't silently reverted.
  - AppLauncher's `model: filteredApps` binds directly to a `ScriptModel`
    instance, matching real Quickshell (whose `ScriptModel` is C++-backed and
    implements a genuine list-model interface). The shim's `ScriptModel.qml`
    is plain QML and can't replicate that — Qt Quick treats a bare `QObject`
    assigned to `model:` as a single-row model exposing the object's own
    properties, not its `values` array (confirmed: this produced a
    misleadingly-not-crashing "1 application, blank row" result before the
    fix). Rewritten to `filteredApps.values` in the **scratch copy only**,
    narrowly scoped to that one line — the same pragmatic treatment already
    given to the anchors/margins stripping below.
  - A `PanelWindow` whose stripped `anchors {}` block filled all four screen
    edges (AppLauncher, WallpaperManager) had no size hint left at all and
    defaulted to a tiny window showing only a corner of the centered content.
    Scratch-copy-only default `width: 960; height: 720` injected right after
    `visible: false` for those two files; components with their own
    `implicitWidth`/`implicitHeight` (MediaControl's compact widget) are
    untouched.

All fixes above are scratch-copy-only or shim-only — **no tracked file outside
`dev/preview/` was modified for harness compatibility.**

### Remaining known limitation (not chased further, low value)

Under `niri` (this session's host compositor — a tiling Wayland compositor,
*not* Hyprland), the per-screen `PanelWindow` instances `Variants`/`Instantiator`
creates for `NotificationPopup.qml` don't visibly separate from the default
`qml` runtime host window in a screenshot — `niri msg windows` showed only one
window client during a notifications run. This is a host-compositor window
management quirk specific to previewing multi-window wlr-layer-shell-shaped
components in a plain non-Hyprland tiling compositor, not a QML correctness
issue (no errors are logged; the underlying code loads and runs cleanly) and
not something the real Hyprland target machine would exhibit. Not worth
chasing further for a visual-only preview.

## Follow-up round: fixes from an independent 8-angle code review

After the above was committed, a separately-run 8-agent code review (angles:
line-by-line diff, cross-file tracer, removed-behavior, simplification,
efficiency, reuse, altitude, CLAUDE.md conventions) surfaced a large list of
findings. Several were corroborated independently by 2-3 different agents —
those are the ones fixed below; the rest were single-agent style/reuse
suggestions, deferred (see "Deliberately not fixed" below).

**Fixed:**
- **`WallpaperService.qml`: "Apply to All Monitors" only ever actually applied
  the wallpaper to one output.** `setWallpaper`'s "all" path looped over every
  connected screen calling `_applyTo()` per screen, reusing the same shared
  `setProcess` Process object within one synchronous loop — re-setting
  `running = true` while it's already `true` does not restart a Process, so
  only the first screen's `awww` invocation ever ran. It also never populated
  the `"__default__"` state key, so the "All Monitors" tab's active-wallpaper
  indicator never updated after an apply. Fixed by calling `_applyTo()` once
  with no target — omitting `--outputs` is awww/swww's own native "every
  connected output" behavior, which the code already relied on for the
  zero-screens edge case but never used for the actual common case. This also
  now clears stale per-monitor pins on an all-monitors apply, since the
  compositor-level effect really does override every output.
- **`WallpaperService.qml`: per-monitor scan queue race + O(n²) commit.**
  Committing a full clone of `perMonitorWallpapers` on every single line a
  scan process printed was O(n²) for an n-wallpaper directory, and could
  misattribute results to the wrong monitor if `_parseMonitorDirs()`/
  `rescan()` reset the queue while a scan was still in flight. Now buffers a
  scan's output locally, commits once when that scan completes, and
  explicitly stops any in-flight scan first.
- **`WallpaperManager.qml`**: grid delegate called `currentFor()` 4x per item;
  cached in one `isCurrent` property per delegate.
- **`lib/backup.sh`**: hardcoded `$HOME` instead of `$DOTFILES_TARGET_HOME`
  when computing a backup's relative path — silently produced a bogus nested
  path layout under a non-default `DOTFILES_TARGET_HOME` (the documented
  scratch-directory testing mode).
- **`audioswitch.sh`**: tightened `check_dependencies` to require `wpctl`
  (it previously advertised pactl as a full alternative, but the actual
  switch call was hardcoded to `wpctl` regardless — a pactl-only machine
  would pass the check and then die on the last line); fixed
  `AUDIOSWITCH_SINK_IDS` to accept the same comma-or-space syntax as its
  sibling `AUDIOSWITCH_SINK_NAMES` (was silently parsing `"51,52"` as one
  bogus token); consolidated 2-3 separate `wpctl status` shell-outs per run
  into one fetch threaded through every call site.

**Deliberately not fixed, and why:**
- **No migration for the old `~/.config/quickshell/wallpaper.conf` path** (the
  per-monitor feature moved state to `wallpaper/wallpaper.conf`). Real gap in
  principle, but this feature has never been deployed to any real machine —
  there is no actual installation anywhere with the old path to migrate from.
  Writing migration code for a deployment that has never happened is exactly
  the "hypothetical future requirement" to avoid; revisit if/when this ever
  ships to a real machine that had the old file.
- **No cleanup of orphaned symlinks when a file is removed from the repo**
  (e.g. the four deleted `DefaultTheme.qml`/`Whitelist.qml` files would leave
  dangling symlinks in `$HOME` on a machine that had them linked from before).
  Real gap in `lib/link.sh`, but a correct fix needs a manifest of what this
  installer previously linked (so it can tell "safe to remove, I created
  this" from "user's own file, don't touch") — that's a real feature to design
  carefully, not a quick patch, and riskier to get wrong (deleting a user's
  file) than to leave alone for now.
- **Duplicated key=value parsers** (`_parseMonitorDirs` vs `_parseState` in
  `WallpaperService.qml`), **duplicated monitor-tab UI blocks**
  (`WallpaperManager.qml`), and **two divergent "generate config from
  setup.conf" strategies** (`lib/whitelist.sh` vs `lib/wallpaperconf.sh`) —
  legitimate reuse observations, but each is only 2 call sites with slightly
  different edge-case handling already, and no third case exists yet to
  justify the abstraction. Revisit if a third generated-config file or a
  third tab-like UI element is ever added.
- **`pkg::installed`/`pkg::missing` spawn one `pacman -Qi` per package**
  instead of one batched query — real, but the installer isn't a hot path
  (runs once per machine setup, not per keypress like `audioswitch.sh`), so
  the risk of a batching rewrite introducing a subtle diff bug outweighed the
  benefit here.

## Recommended next steps for a new session

1. **Nothing is committed yet as of this writing** — see the file inventory
   below for what should go in. Consider splitting into logical commits: the
   `.gitignore` fix (small, foundational), the QML/Hypr fixes, the `setup.sh` +
   `lib/` installer, and the `dev/preview/` harness, so the history stays
   legible.
2. **Get this onto a real Hyprland + Quickshell machine.** Everything above is
   about as verified as it can be without one — the preview harness confirms
   QML *loads and executes* the intended logic, but real wlr-layer-shell
   rendering, real D-Bus notifications, real MPRIS players, and real
   `awww`/`swww` wallpaper application are still completely unexercised.
3. If new hand-written QML singletons are ever added to this repo, remember
   bug #2 above: they need a `qmldir` entry, full stop.
4. If new files are ever added anywhere under this repo's `~/` tree, run
   `git status --short -uall` and confirm they actually appear before assuming
   they're tracked — bug #1 above was silent and easy to miss.
5. Nothing here needs any package installed to keep working on — `bash -n`,
   `qmllint`, and the already-installed `qt6-declarative`
   (`/usr/lib/qt6/bin/qml`, `/usr/lib/qt6/bin/qmllint`) are the only tools this
   session relied on, both already present.

## File inventory (new/changed since the original fork)

```
setup.sh                        installer entry point (bootstrap, CLI, orchestration)
setup.conf                       tracked default config (packages, whitelist, wallpaper dirs, etc.)
.gitignore                       fixed: *~ -> ?*~ (was silently ignoring everything under ~/)
lib/
  log.sh ui.sh menu.sh net.sh pkg.sh deps.sh backup.sh link.sh
  whitelist.sh                  regenerates common/Whitelist.qml from setup.conf
  wallpaperconf.sh               generates ~/.config/quickshell/wallpaper/monitors.conf
dev/preview/
  run.sh                         preview harness launcher — now fully working, all 5 targets clean
  qmlshim/                       fake Quickshell C++ types for the harness (see fixes above)
~/.config/hypr/hyprland.conf     multi-monitor catch-all, no more hardcoded monitor name
~/.config/hypr/audioswitch.sh    config-file support, universal fallback, self-healing
~/.config/quickshell/
  common/Theme.qml, Whitelist.qml, qmldir   (qmldir is new — was silently untracked before, see bug #1)
  media/MediaControl.qml                     (was silently untracked before, see bug #1)
  wallpaper/qmldir                           new — fixes WallpaperService singleton (see bug #2)
  notifications/qmldir                       new — fixes NotificationService singleton (see bug #2)
  applauncher/AppLauncher.qml, notifications/NotificationPopup.qml,
  wallpaper/WallpaperManager.qml, WallpaperService.qml   (theme import fix + per-monitor feature)
  shell.qml                      now actually imports a working media module
```
