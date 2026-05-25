# BPM

A lightweight beats-per-minute tapper that lives in the macOS menu bar. Click the icon in time with the beat and it reports the average BPM. Useful for figuring out whether a track will fit into a set.

## Usage

- **Click** — register a tap. After the second tap, the menu bar shows the running average BPM.
- **Right-click** — reset.
- **⌘-Click** — copy the current BPM to the clipboard.
- **⌥-Click** — show the instructions popup.
- **⌃-Click** — quit the app.

The display auto-resets to the placeholder glyph after ~1.5 seconds without a tap.

## Building

Open `bpm.xcodeproj` in Xcode and build. The project produces a Universal Binary (Apple Silicon + Intel) and targets macOS 11.0 Big Sur or later.

## License & attribution

This work is licensed under the [Creative Commons Attribution 3.0 Unported License (CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/).

Originally created by **Ben Brook** ([@bencmbrook](https://github.com/bencmbrook)) — upstream repository: <https://github.com/bencmbrook/bpm>. Subsequently modified by **Harry Clegg** ([@harryclegg](https://github.com/harryclegg)) — upstream fork: <https://github.com/harryclegg/bpm>. Further modified in this fork by **Tim Erickson** ([@t1merickson](https://github.com/t1merickson)).

This is a modified version of the original work; modifications are summarized in the changelog below.

---

## Changelog

### This fork — [@t1merickson](https://github.com/t1merickson)

- **Menu bar UI polish:**
  - Replaced the "bpm" text in the ready state with the `music.quarternote.3` SF Symbol (template-rendered so it tints with the menu bar).
  - Status item now has a fixed width sized for the widest possible 3-digit BPM ("888"), so it no longer jumps around as the BPM digit count changes.
  - Menu bar text is rendered 1pt smaller than the system default for a slightly more refined look.
  - SF Symbol weight and size tuned (`pointSize: 15, weight: .medium`) to sit comfortably next to other menu bar glyphs.
  - Tooltip is now dynamic: shows "BPM Tapper — click to tap" in the ready state, "Keep tapping…" after the first tap, and "<N> BPM — ⌘-click to copy" once a BPM is being measured.
- **New behavior:**
  - **⌘-Click copies the current BPM to the clipboard**, for quickly pasting tempo into a DAW or notes. Beeps if there's nothing to copy yet.
  - Removed the splash/instructions dialog that appeared on every launch. Instructions are still available via ⌥-Click.
- **Code health:**
  - Bumped deployment target from macOS 10.13 → macOS 11.0 (required for SF Symbols).
  - Fixed a latent force-unwrap of `NSApp.currentEvent` in the click handler that could crash on programmatic / accessibility-driven invocation.
  - Tightened the instructions popup copy and switched it from a `.warning` alert style to `.informational` (it was using the yellow caution triangle for what is really just a help dialog).
  - Removed the now-dead `noShowDialogOnStart` preference plumbing and "Do not show this message on launch" suppression checkbox.
  - Removed the demo gif from the repo.

### v1.3 — [@harryclegg](https://github.com/harryclegg)

- Re-wrote the application logic from the ground up. Tap-interval tracking was split out into a dedicated `BPMTapper` class with explicit reset / averaging behavior; `AppDelegate` is now just the menu bar wiring.
- Fixed the timing logic so the running average correctly weights every tap interval ([#3](https://github.com/harryclegg/bpm/pull/3)).
- Upgraded the Xcode project files to build cleanly on modern Xcode versions ([#1](https://github.com/harryclegg/bpm/pull/1)).
- Small user-interface and user-experience tweaks throughout.
- Added an option to suppress the instructions popup at launch (later removed in this fork, since the popup itself no longer fires on launch).

### Original — [@bencmbrook](https://github.com/bencmbrook)

- Initial release of the menu bar BPM tapper for OS X.
- Click in time with the beat; the menu bar shows the running average BPM.
- Right-click to reset, control-click to quit.
- Instructions popup on first launch with a "don't show again" option.
- Yosemite (OS X 10.10) compatibility.
- Packaged as a downloadable `.zip` once the original hosting site went down.
