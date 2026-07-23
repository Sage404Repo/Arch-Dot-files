# Changelog

This document is not a typical changelog. A typical changelog is a terse list
for people who already know the codebase: "Fixed X. Added Y." This one is
written for someone learning **git** and **programming** at the same time,
using this repository's real history as the example. Every section explains
not just *what* changed, but *why it was a problem*, *how the fix works*, and
in several cases *why something was deliberately left alone*. Where it's
useful, it also explains the underlying git or programming concept in plain
language, since the point is to learn from this, not just read about it.

If you only want the short, standard-format version, skip to
[The short version](#the-short-version). Everything after that is the long,
teaching version.

## How to read this document

A **commit** is a saved snapshot of every file in the project at one point in
time, plus a message explaining what changed and why. Commits are identified
by a long random-looking ID (a "hash"), usually shown shortened to 7
characters, like `a1609cd`. This changelog references real commit hashes from
this repository's history — you can look up any of them yourself:

```sh
git log --oneline              # list every commit, oldest at the bottom
git show a1609cd                # see exactly what one commit changed
git diff c4c62f8 HEAD           # see everything that changed between two points
git log -p -- path/to/file      # see every change ever made to one specific file
```

Doing this yourself is genuinely one of the best ways to learn — reading a
description of a diff is fine, but looking at the actual diff, in your own
terminal, and seeing exactly which lines moved, is much better. Nothing in
this document is a substitute for that.

A short glossary of terms used throughout is at the
[bottom of this document](#glossary).

## The short version

This fork started as one person's personal, hardcoded, single-machine
Hyprland + Quickshell setup (7 commits, `2bb4c7e` through `c4c62f8`). Since
then it has been turned into something installable on a different machine:
shared/deduplicated Quickshell config, a from-scratch installer
(`setup.sh` + `lib/`), a way to visually test the QML without installing
Quickshell or Hyprland (`dev/preview/`), and two rounds of real bug fixes —
including a `.gitignore` bug that was silently hiding new files from git
entirely, and a subtle QML engine quirk that silently broke three different
features at once. See the commit list below for the full breakdown.

```
39fde9e Document the code-review follow-up fixes and deferred findings
832f697 Fix real bugs surfaced by an independent 8-angle code review
0aa6710 Update README and add session handoff notes
48869a5 Add dev/preview/ QML harness
db1ff37 Add setup.sh installer
dddddc0 Quickshell/Hyprland hardening + singleton registration fixes
a1609cd Fix .gitignore *~ pattern silently ignoring the entire ~/ tree
──────── (everything above this line is new; everything below is the original fork) ────────
c4c62f8 Create Wallpapers folder
3aaa6cf Added application manager
3e4e2fc Added notification manager
9b206e2 Added wallpaper manager
aeed3b7 Create shell.qml
c361270 Added audio swicther for Razer Blackwidow V3
28cc645 Create hyprland.conf
2bb4c7e Initial commit
```

---

## Part 0 — Where this fork started

Before reading what changed, it's worth seeing what the *original* fork
actually looked like, warts and all — you can't appreciate "why" a change was
made without seeing the "before." The original 7 commits were all by one
author, building a setup for their own single machine. That's a completely
reasonable way to start a personal dotfiles repo! But it means certain
shortcuts get taken that only work *because* it's one person's one machine —
and this changelog's whole first half is about what breaks when that
assumption is removed.

Some concrete examples, straight from the original commits (you can run
`git show c4c62f8:"path"` yourself to see these exact files):

- **`~/.config/hypr/hyprland.conf`** hardcoded `monitor = HDMI-A-1, highres,
  auto, 1` — this tells Hyprland "there is a monitor named exactly
  `HDMI-A-1`, use this resolution for it." On any other machine, with a
  different monitor name (laptop panels are usually `eDP-1`, for example),
  Hyprland would have no monitor rule that applies at all.
- **`~/.config/hypr/audioswitch.sh`** hardcoded
  `TARGET_SINKS=(51 52)` — two numeric IDs that PipeWire (the audio system)
  assigns to audio devices *at runtime*. These numbers are not guaranteed to
  stay the same even on the *same* machine after a reboot, let alone a
  different one.
- **Three separate, drifted copies of the same idea**:
  `applauncher/DefaultTheme.qml`, `notifications/DefaultTheme.qml`, and
  `wallpaper/DefaultTheme.qml` were meant to be "the app's color theme," but
  each one had different values, and some had genuinely broken ones —
  `wallpaper/DefaultTheme.qml` had `textSecondary: "#ff0000"` (bright red,
  clearly a leftover debug color) and `textMuted: "#000000"` (black text,
  invisible against the app's black background). `notifications/
  DefaultTheme.qml` had `bgOverlay`, `bgHover`, and `bgSelected` all set to
  `"#ff0000"` too. These are the kind of bugs that happen naturally when the
  "same" value is copy-pasted into multiple files instead of kept in one
  place — eventually someone edits one copy and not the others, or leaves a
  debug value in by accident, and nothing catches it.
- **`applauncher/Whitelist.qml`** (a *different, dead* file from the
  `Whitelist.qml` that exists today) had entries `"scrcpy.dekstop"` and
  `"steam.dekstop"` — both misspelled ("dekstop" instead of "desktop"). Since
  the app launcher matches these strings exactly against real
  `.desktop` file names, a typo like this doesn't crash anything — it just
  means Steam and scrcpy would silently never appear in the launcher, with no
  error telling you why. This file also wasn't even imported by
  `AppLauncher.qml` — it existed in the repo but did nothing at all.

None of this is a criticism of the original author — a personal setup that
works on your own machine has done its job. The rest of this document is
about the specific, deliberate work of turning "works on my machine" into
"works on a machine I've never seen," which is a genuinely different (and
harder) goal.

---

## Part 1 — Fixing git itself

**Commit:** `a1609cd` — *Fix .gitignore \*~ pattern silently ignoring the
entire ~/ tree*

Before any of the "real" work could be trusted, a bug in git's own
configuration had to be found and fixed — and it's a great example of how a
tool can fail *silently*, which is often worse than failing loudly.

**Background you need first:** a `.gitignore` file tells git "don't track
these files" — usually things like compiled build output or editor backup
files that shouldn't be shared. Each line is a *pattern*. The pattern `*~` is
a very common one: many text editors (Vim, Emacs) save a backup copy of a
file you're editing as `filename~` (your original filename with a `~`
appended), and `*~` means "ignore anything ending in `~`."

This repository's files are organized in a slightly unusual way: everything
that's meant to eventually live under your real home directory (like
`~/.config/hypr/hyprland.conf`) is stored in this git repo *inside a folder
that is itself literally named `~`* — so the real path in the repo is
`Arch-Dot-files-Fork/~/.config/hypr/hyprland.conf`. This mirrors where the
installer will eventually put it.

Here's the bug: gitignore patterns match **any part of a file's path**, not
just the very end of the filename. The folder `~` is, by itself, a single
character that *ends in* `~`. So the pattern `*~` — meant to catch editor
backup files — also matched the `~` folder itself. And once git considers a
*folder* ignored, it ignores **everything inside it**, no matter what those
files are actually named. So `*~` was silently telling git "ignore this
entire folder and everything anyone ever puts in it," which was never the
intent.

**How this was found:** while adding new files inside that `~` folder during
this session, they kept not showing up when running `git status` (the
command that lists what's changed and what's new). Running
`git check-ignore -v <path>` — a command that explains *why* git is ignoring
a specific file — pointed straight at line 17 of `.gitignore`.

**The consequence, concretely:** two files from *before* this session
(`common/Theme.qml`, `common/Whitelist.qml`) and one more
(`media/MediaControl.qml`) had been written and were sitting on disk, but had
**never actually been added to git at all** — despite being described
elsewhere as finished, done work. If someone had trusted `git status`,
committed, and pushed, those three files would have simply not existed for
anyone else who cloned the repository, with no error or warning anywhere.

**The fix:** change the pattern from `*~` to `?*~`. In this pattern language,
`?` means "exactly one of any character" and `*` means "zero or more of any
character," so `?*~` means "at least one character, then a `~`" — i.e., at
least two characters total. A real backup file like `notes.txt~` (10
characters) still matches. The single-character folder name `~` (1
character) cannot match, because there's no room left for the mandatory `?`.

**Why this matters as a lesson:** `git status` only shows you what git is
*aware of*. A file being invisible to `git status` doesn't mean nothing is
wrong — it can mean git has been told to actively ignore it. Whenever "a file
I just made isn't showing up," `git check-ignore -v <path>` is the tool that
answers "is something ignoring it, and which rule?"

---

## Part 2 — Making the desktop config shared and machine-independent

**Commit:** `dddddc0` — *Quickshell/Hyprland hardening: shared theme,
whitelist, media control, per-monitor wallpaper, and singleton registration
fixes*

This is the largest single commit, so it's broken down into its pieces.

### 2a. One shared theme and whitelist instead of three drifted copies

**Where:** `~/.config/quickshell/common/Theme.qml`,
`~/.config/quickshell/common/Whitelist.qml`

**Why:** as shown in Part 0, having the "same" color palette copy-pasted into
three files (one per Quickshell module) meant they drifted apart, and at
least two of the three had genuinely broken debug colors left in. The fix is
a standard programming principle sometimes abbreviated **DRY** ("Don't
Repeat Yourself"): put a piece of information in exactly one place, and have
everything else *refer to* that one place, instead of copying the value
around. Now every module imports the same `common/Theme.qml` — change a
color once, every screen updates.

The app launcher's whitelist (the list of apps allowed to show up in it)
works the same way, but goes one step further: `common/Whitelist.qml` is
itself *generated* from `setup.conf` by a script (`lib/whitelist.sh`), so the
*true* source of truth is one plain config value
(`DOTFILES_APP_WHITELIST`), not a `.qml` file at all. This also fixed the
`"dekstop"` typos from Part 0, since the list is now typed once in
`setup.conf` and mechanically copied into the `.qml` file — no second,
hand-maintained copy to drift out of sync.

### 2b. A component that was imported but never existed

**Where:** `~/.config/quickshell/media/MediaControl.qml` (new file)

**Why:** `shell.qml` — the file that loads every other Quickshell module —
had a line `import "media" as Media`, but no `media/` folder existed
anywhere in the repository. In QML (Quickshell's UI language, similar in
spirit to how a web page is built from HTML/CSS/JS), a missing import isn't
a small cosmetic issue — it prevents the *entire file* from loading. This
means the whole desktop shell would have failed to start at all on a real
machine, not just the media widget. This is a good example of why it's worth
actually *running* code (or something close to it — see Part 4) rather than
only reading it: a missing file is easy to miss by eye if you're not the one
who deleted it, but instantly obvious the moment something tries to load it.

### 2c. The `pragma Singleton` bug — the most important bug in this whole project

**Where:** new `qmldir` files in `common/`, `wallpaper/`, and
`notifications/`

This is worth reading closely even if you don't know QML, because the
underlying lesson — **"this looks like it should work, and appears to work,
but doesn't, and fails silently"** — comes up in every programming language
eventually.

**The concept:** QML has a feature called a *singleton* — a component that
exists exactly once and is shared by anyone who refers to it, rather than
being a fresh copy each time (this repository uses singletons for things
like "the current wallpaper state" and "the list of active notifications,"
where you want exactly one shared answer, not a different one in every file
that asks). You mark a file as a singleton by putting `pragma Singleton` at
its very top.

**The bug:** in this project's version of Qt (6.11.1), `pragma Singleton`
*by itself* does not actually register anything as a singleton. You also
need a separate, plain-text file named `qmldir` sitting next to it that
explicitly says so — for example, `singleton Whitelist 1.0 Whitelist.qml`.
Without that `qmldir` entry, referring to the singleton doesn't produce an
error. It silently gives you back some kind of empty, non-functional
stand-in object instead — one that exists, but is missing all the real
properties and functions the actual file defines.

**What this actually broke, concretely:** three separate features, all for
the same underlying reason:

- `common/Whitelist.qml` — the app launcher's `allowedAppIds` list came back
  as `undefined`, which crashed the filtering logic with a "cannot call
  `.includes()` of undefined" error.
- `wallpaper/WallpaperService.qml` — every function on it (`wallpapersFor`,
  `currentFor`, etc.) came back missing, so the wallpaper picker broke.
- `notifications/NotificationService.qml` — the exact same failure mode.

**How this was actually confirmed** (this part matters — see also Part 5,
"the false all-clear"): rather than guess, the fix was verified with a
minimal, unrelated, from-scratch test file with nothing else in it:

```qml
// MyService.qml
pragma Singleton
import QtQuick
QtObject { function doThing(x) { return "did " + x; } }
```

Without a `qmldir` next to it, `MyService.doThing("x")` fails — `doThing` is
"not a function." Add a `qmldir` containing
`singleton MyService 1.0 MyService.qml`, and it works. This kind of tiny,
isolated reproduction — stripping a bug down to the smallest possible
example that still shows it — is one of the single most useful debugging
techniques in programming, because it removes every other possible
explanation ("maybe it's something else in my real file") and leaves only
the one thing you're actually testing.

**Why it's worth remembering:** the previous version of this project's
internal notes had *guessed* these three bugs might be artifacts of an
imperfect testing setup, rather than real bugs — a completely reasonable
guess at the time, but wrong. "This looks like it might just be a testing
artifact" and "this is a testing artifact" are different claims, and only
one of them was actually checked.

### 2d. `hyprland.conf` — one line for any monitor instead of one hardcoded name

**Where:** `~/.config/hypr/hyprland.conf`

`monitor = HDMI-A-1, highres, auto, 1` became
`monitor = , preferred, auto, auto` — an empty first field in Hyprland's
monitor syntax means "match any monitor," so this one line now works
regardless of what your monitor is actually named, with commented examples
left in the file for anyone who *does* want to target a specific named
monitor later.

### 2e. `audioswitch.sh` — config file instead of hardcoded IDs

**Where:** `~/.config/hypr/audioswitch.sh`

The hardcoded `TARGET_SINKS=(51 52)` from Part 0 was replaced with support
for a small config file (`~/.config/hypr/audioswitch.conf`) that names
devices instead of guessing at runtime-assigned numeric IDs, plus a fallback
that cycles through *whatever* audio devices actually exist if nothing is
configured — so a fresh machine gets *something* useful instead of an error,
without needing to know that machine's specific hardware in advance.

---

## Part 3 — Building an installer

**Commit:** `db1ff37` — *Add setup.sh installer*

**Why an installer at all?** Up to this point, every fix made the
*configuration* less dependent on one specific machine. But getting the
files from this repository *onto* a real machine — safely, without
overwriting something important — is a separate problem. `setup.sh` (289
lines) plus several helper scripts under `lib/` solve that:

- **`setup.conf`** is a single plain config file listing what packages to
  install, the app whitelist, and wallpaper directories — the "one place to
  edit" principle from Part 2a, applied to the whole installer.
- **Backups before any overwrite** (`lib/backup.sh`) — if a file already
  exists where this installer wants to put one of its own, the existing file
  is *moved* into a timestamped backup folder, never deleted. This is a
  general engineering principle worth internalizing: prefer reversible
  actions over irreversible ones whenever the cost of doing so is small.
- **A `--dry-run` mode** — every step can be asked to just *print* what it
  would do, without actually doing it. This exists specifically so a change
  to the installer can be sanity-checked without any risk, which is exactly
  how all of this installer's own logic was checked during development,
  since there was never a real machine available to run it on for real (see
  the note at the very end of this document about that limitation).
- **Retries and self-healing** (`lib/net.sh`, `lib/pkg.sh`) — real machines
  have flaky networks and can be left with a stale, stuck package-manager
  lock file from a previous crashed run; the installer detects and recovers
  from both instead of just failing.
- **A plain-bash interactive menu** (`lib/menu.sh`) with no dependency on
  external menu programs (`dialog`/`whiptail`), so it works even when piped
  straight from `curl | bash` on a completely fresh machine that hasn't
  installed anything yet.

**Why `curl | bash` at all, and the tradeoff involved:** the install command
in this project's README (`curl -fsSL <url> | bash`) is a common pattern for
"run this script directly from the internet without cloning first," but it
comes with a real, well-known tradeoff: you are trusting that URL and
whoever controls it completely, since you're executing whatever it returns
without reading it first. It's convenient, but it is worth understanding
*why* some people are cautious about this pattern before using it (or
copying it into a project of your own) — the safer alternative is always
"download it, read it, then run it."

---

## Part 4 — Testing QML without installing Quickshell or Hyprland

**Commit:** `48869a5` — *Add dev/preview/ QML harness*

**The problem this solves:** none of this project's QML files could be
*run* on the machine this work was done on — there was no Hyprland, no
Quickshell, not even a graphical Wayland session available for most of the
work. But "does this file have a mistake in it?" is a question you can't
fully answer just by reading code, especially in a UI language like QML
where a lot of behavior only shows up once something actually tries to
display it (as Part 2b's missing-import bug demonstrates).

**The technique: shimming (a form of mocking).** `dev/preview/qmlshim/`
contains small, fake, stand-in versions of Quickshell's real building
blocks — its notification system, its media-player integration, its list of
installed apps, and so on. None of them do anything real (the fake app list
is just a few hardcoded names); their only job is to be *just similar
enough* to the real thing that the actual, real, unmodified `.qml` files in
this repository can load and run against them in an ordinary window, using
nothing but Qt's own generic `qml` tool. This general technique — building a
lightweight fake of something you don't have access to, purely so you can
test code that depends on it — is called **mocking** or **shimming**, and is
extremely common in professional software testing (a program that talks to
a real payment processor, for example, is almost never tested against the
*real* payment processor during development).

**A crucial finding while building this: silent failures, again.** The very
first time the preview harness was re-run during this session, all five
components loaded with *zero* errors — which seemed like great news. It was
wrong. This desktop session runs under `systemd`/`journald` (Linux's system
logging service), and Qt's default behavior is to send its warning messages
to the system log instead of the terminal whenever it detects the terminal
isn't a normal interactive one (which is exactly the case when a command's
output is redirected to a file, as it was here). The three real bugs from
Part 2c were actually happening the entire time — they just weren't visible
until a specific environment variable
(`QT_ASSUME_STDERR_HAS_CONSOLE=1`) was set to force Qt to print to the
terminal regardless. This is now set unconditionally at the top of
`dev/preview/run.sh`, with a comment explaining why, specifically so nobody
removes it and reintroduces the same false sense of safety.

**The lesson, stated plainly:** "I ran it and saw no errors" is not the same
claim as "there are no errors" — it also depends on whether errors would
have been visible to you *at all* in that specific setup. Whenever a
tool's cleanliness is surprising or is a critical claim you're relying on,
it's worth asking what would happen if something *did* go wrong — would you
actually see it?

**Smaller shim fixes along the way** (each one specific and narrow, not a
rewrite): a missing `Singleton` base type the shim never provided at all;
`Variants` (Quickshell's way of creating one window per screen) had been
faked using Qt's ordinary `Repeater`, which can only create simple on-screen
items, not entire separate windows — swapped for `Instantiator`, which can;
and a property name collision where the fake test data couldn't be assigned
to a real, built-in Qt property of the same name. Each of these is documented
in the shim files themselves at the point where it was fixed, so the reason
is visible right next to the code, not just in this changelog.

---

## Part 5 — Documentation

**Commit:** `0aa6710` — *Update README and add session handoff notes*

This added `conclusion.md`, a working-notes document tracking what's done,
what's verified, and what's still open — distinct from this file. The
difference matters: `conclusion.md` is a snapshot of *project state at a
point in time* for someone continuing the work; this `CHANGELOG.md` is a
permanent, chronological record of *what changed and why*, meant to still
make sense long after the project has moved on. Keeping these separate
avoids a working-notes document quietly rotting into a wrong-but-trusted
changelog, which is exactly what nearly happened here — see the next part.

---

## Part 6 — A second, independent review

**Commits:** `832f697` — *Fix real bugs surfaced by an independent 8-angle
code review*, `39fde9e` — *Document the code-review follow-up fixes and
deferred findings*

After Part 5, a separate, independent code review was run — several
reviewers, each looking at the same code from a different specific angle
(one purely for correctness bugs, one for duplicated code, one for
efficiency, and so on), without seeing each other's conclusions. This is a
useful practice in general: a second, independent look, ideally from a
different perspective than the one that wrote the code, tends to catch
different mistakes than re-reading your own work does — you already know
what you *meant* to write, which makes it easy to read past what you
*actually* wrote.

### The most serious bug found: reusing a shared object inside a loop

**Where:** `~/.config/quickshell/wallpaper/WallpaperService.qml`

This is a good general lesson about **shared mutable state** — a common
source of bugs across almost every programming language. The wallpaper
picker's "apply to every monitor at once" feature worked by looping over
every connected monitor and, for each one, reusing the *same* single
"process launcher" object to run the command that actually changes the
wallpaper. The problem: that object has an on/off switch (`running`), and
setting a switch that's already on to "on" again does *nothing* — it doesn't
restart it with the new instructions. So in a loop over three monitors, only
the *first* monitor's command ever actually ran; the second and third
iterations updated the object's instructions and flipped a switch that was
already in the "on" position, silently accomplishing nothing.

The fix turned out to be simpler than patching around the loop: the
underlying wallpaper tool already treats "no monitor specified" as "apply to
every monitor," which the code was *already relying on* for one edge case,
just never using for the actual common case. So instead of looping and
fighting the shared-object reuse problem, the fix removes the loop entirely
and asks the tool to do what it already knows how to do.

**The secondary bug this caused:** because the "apply to all" path never
called the single-monitor code path with "no specific monitor," a specific
internal state key that was supposed to represent "the current wallpaper
when applied to everything" was never actually being set — so a part of the
interface (which thumbnail shows as "currently active") silently never
updated after using that feature. Both bugs shared one root cause, and both
were fixed by the same change.

### Other fixes from this same review round

- A part of the wallpaper-scanning logic redundantly copied its entire
  results-so-far on *every single file found*, instead of once at the end —
  harmless for a small folder, needlessly slow for a large one. This is an
  example of algorithmic complexity mattering in practice, not just in
  theory: copying a growing list on every step is quadratic
  work (roughly "n × n" instead of "n") for what should be linear work.
- `lib/backup.sh` computed backup paths by assuming your home directory was
  always the real, literal `$HOME` — but the installer supports being
  pointed at a fake, scratch "home" for testing (exactly the kind of testing
  approach described in Part 3), and the backup logic didn't account for
  that, producing a nonsense path in that specific mode.
- `audioswitch.sh` claimed to support two different audio tools
  (`wpctl` and `pactl`) interchangeably, but the actual "switch the audio
  device" step only ever used one of them — so a machine with only the
  other tool installed would pass every check and then fail on the very
  last line. Fixed by being honest about the actual requirement instead of
  advertising support that didn't exist.
- The same script also called out to the audio system three separate times
  per keypress to gather three pieces of information it could have gotten
  from one call — consolidated into one.

### What was deliberately *not* fixed, and why that's a legitimate answer

Not every valid observation should turn into a code change immediately —
part of maturing as a programmer is learning to tell the difference between
"this is a real bug, fix it" and "this is a real observation, but not worth
the risk or effort right now." A few examples, with the reasoning kept
alongside them in `conclusion.md`:

- A migration path for an *old* config file format was suggested — but this
  feature has never actually been installed on any real machine yet, so
  there is no real file anywhere that would ever need migrating. Writing
  code to handle a situation that has never occurred and currently cannot
  occur is a common trap (sometimes called **YAGNI**, "You Aren't Gonna Need
  It") — it adds real complexity and risk for zero present benefit, on the
  chance it might matter someday.
- A handful of small, genuine code-duplication observations (two
  near-identical parsing functions, two near-identical config-generation
  scripts) were left alone because each case only has two copies with
  already-slightly-different behavior — collapsing them into one shared
  version has a real risk of subtly changing behavior to save a small amount
  of repetition. The general rule of thumb used here: duplication becomes
  worth removing once there's a *third* copy, not before.
- Cleaning up leftover symlinks from files this project has since deleted
  was flagged as a gap, but a *correct* fix needs the installer to remember
  exactly which files it personally created in the past (so it can tell "a
  file I made, safe to remove" apart from "a file that happens to have the
  same name, don't touch it"). That's a real feature that deserves careful,
  deliberate design — not a rushed patch, given that getting it wrong means
  the installer could delete something that belongs to the person running
  it.

---

## Glossary

- **Commit** — a saved snapshot of the whole project at one point in time,
  with a message explaining the change.
- **`git status`** — lists what's changed, new, or staged, right now.
- **`.gitignore`** — a file listing patterns for what git should never track.
- **Tracked / untracked** — whether git is currently keeping history for a
  file at all. A file can exist on disk and still be untracked.
- **Singleton** — a single, shared instance of something, rather than a
  fresh separate copy every time it's referred to.
- **Mocking / shimming** — building a small, fake, simplified stand-in for
  something you don't have (a real service, a real device, a real library)
  purely so you can test code that depends on it.
- **DRY ("Don't Repeat Yourself")** — the principle that a given piece of
  information should exist in exactly one place in a codebase, with
  everything else referring to it, rather than being copy-pasted around.
- **YAGNI ("You Aren't Gonna Need It")** — the principle that you shouldn't
  build support for a situation that hasn't happened and isn't concretely
  expected, just in case.
- **Race condition** — a bug that only happens because of the specific
  timing or order two things happen to run in, rather than because of what
  either one does on its own.
- **Idempotent** — describes an operation that produces the same result no
  matter how many times you run it; running it twice isn't harmful or
  different from running it once.
- **Dry run** — actually executing all the logic of a program *except* the
  final step that would change anything real, purely to see what it
  *would* do.

---

## An honest limitation, stated plainly

Nothing described in this document has been run on a real Arch Linux +
Hyprland + Quickshell machine. Every verification technique used here — the
preview harness in Part 4, the installer's dry-run mode in Part 3, isolated
reproductions like the one in Part 2c — exists specifically *because* no
such machine was available. These techniques catch a real, meaningful class
of bugs (and did, repeatedly, throughout this history), but they are not a
substitute for the real thing. If you're reading this while setting this
project up on an actual machine, you are doing something no one has done
yet with this code, and you may find things these techniques couldn't catch.
That's not a flaw in the effort — it's just an honest description of what
"tested without the real hardware" can and can't promise.
