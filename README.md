# Blockdown

A 48-hour countdown timer for iOS, styled after the system Clock app (black + orange), with a Live Activity for the lock screen and Dynamic Island.

## Features

- Default 48-hour timer, adjustable from 1 second up to 168 hours (wheel pickers + 24h/48h/72h/1wk presets)
- Pause, resume, cancel, and restart
- Add or subtract time while running (quick ±15m/±1h chips, or granular amounts via Edit Timer)
- Renameable timer
- Live Activity: lock screen card + Dynamic Island countdown with progress bar
- Simple local notification when the timer ends (no alarm)
- History of every run: name, start → end, planned vs. actual duration, completed/stopped
- Liquid Glass buttons and chips; adapts to light and dark mode

## Project layout

- `Blockdown/` — app target (SwiftUI). `TimerEngine` is the state machine; views in `Views/`
- `BlockdownWidget/` — widget extension containing the Live Activity
- `Shared/` — `ActivityAttributes` and time formatting used by both targets
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; regenerate the project with `xcodegen generate`

## Building

```sh
xcodegen generate   # only needed after editing project.yml
open Blockdown.xcodeproj
```

Build and run the `Blockdown` scheme. Minimum iOS 26. To run on your iPhone, select your development team under Signing & Capabilities for both targets.

### Simulator test hook (DEBUG only)

```sh
xcrun simctl launch booted com.utkarsh.blockdown -autostart 60
```

starts a 60-second timer on launch, useful for testing the Live Activity and completion flow.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
