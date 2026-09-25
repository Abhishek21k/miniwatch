# miniwatch

A tiny stopwatch that lives in the MacBook notch.

- **Idle:** invisible. The notch looks stock; the menu bar shows a small stopwatch glyph.
- **Running:** the notch grows two wings — a dot on the left, the time on the right.
- **Hover:** it springs open into big time, Lap / Reset, Start / Pause, and your last three laps.
- **No notch** (external display, lid closed): the same thing floats as a pill under the menu bar.
- **Clock app mirror (optional):** turn on *Show Clock App Stopwatch* to see the macOS Clock app's
  stopwatch in the island while miniwatch's own is idle (view-only).

## Controls

| | |
|---|---|
| Click menu bar glyph | Start / pause |
| Right-click menu bar glyph | Lap, Reset, settings, Quit |
| Hover the notch while idle | Reveals a play button |
| `⌃⌥S` / `⌃⌥L` / `⌃⌥R` | Start–pause / Lap / Reset, from anywhere |

The time is derived from a start date plus banked time, so it doesn't drift, keeps counting through sleep, and survives quitting.

## Build

Needs only the Command Line Tools (Swift 6), no Xcode. macOS 14+.

```sh
make run       # build build/miniwatch.app and launch it
make install   # copy to /Applications and launch (needed for Launch at Login)
make test
```

## Clock app mirror

Clock keeps its stopwatch in `mobiletimerd`, which persists it to the `com.apple.mobiletimerd`
preferences domain. When the mirror is on (it's off by default), miniwatch polls that once a
second and never writes to it. While
miniwatch's own stopwatch is idle, the island shows Clock's. Clicks never open Clock: they
start miniwatch's own stopwatch, which then takes over the island.
The format is private and undocumented:

| Key | Meaning |
|---|---|
| `MTStopwatchState` | 0 stopped, 1 paused, 2 running |
| `MTStopwatchStartDate` | start of the current run of the current lap (running only) |
| `MTStopwatchOffset` | current-lap time banked before the latest resume |
| `MTStopwatchPreviousLapsTotalInterval` | sum of completed laps |
| `MTStopwatchLaps` | completed lap durations, oldest first |

Elapsed = previous laps total + offset + (now − start date, if running).
If a macOS update changes the format, miniwatch stops mirroring rather than guessing.

**Why view-only?** Only Clock itself may talk to `mobiletimerd`. Clock does expose Start / Stop /
Lap / Reset Stopwatch as Shortcuts actions, and miniwatch once drove them — but Stop, Lap and
Reset run inside Clock.app, which always brings its window forward to do it: closed, Clock quits;
hidden, it unhides; minimized, it restores itself. That flicker isn't avoidable, so miniwatch's
controls run its own stopwatch instead.

## Debug flags

Debug builds (`scripts/bundle.sh debug`) accept:

```sh
open build/miniwatch.app --args -debugHover YES     # pin the expanded state
open build/miniwatch.app --args -debugNoNotch YES   # preview the floating pill
```

With `defaults write io.github.miniwatch debugHooks -bool YES`, any build also listens for the
distributed notifications `miniwatch.debug.toggle`, `.lap` and `.reset`, so the controls can be
scripted.
