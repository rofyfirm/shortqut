# Shortqut

**English** · [Bahasa Indonesia](README.id.md)

A lightweight action ring for macOS, inspired by the Logitech action ring. Tap the trackpad with 4 fingers and a ring of actions appears right at the cursor. Move the cursor to an action and click to run it.

Built with SwiftUI and AppKit so it feels native on macOS, including dark mode and system materials.

## Features

- **4-finger activation:** tap the trackpad with 4 fingers to open or close the ring at the cursor.
- **Command activation:** quickly press Command twice to open or close the ring.
- **Your own apps:** add apps to the ring from **Settings…**. The app's real icon is shown in the ring.
- **Configurable native actions:** choose from Screenshot (⇧⌘4), Mission Control, Lock Screen (⌃⌘Q), Record Screen (⇧⌘5), and Play/Pause, or add a shortcut from the Shortcuts app with **Run Shortcut…**. Only Screenshot is enabled by default.
- **More actions:** open a folder/file, a web link, or send any hotkey (recorded live in a dialog) from the **Add** menu.
- **Reorder, relabel, and change icons:** drag items in Settings to reorder them, then click the pencil icon to change the label and icon (SF Symbol).
- **Ring limit:** native actions and apps together are capped at 12 items.
- **No Dock icon:** Shortqut lives only in the menu bar.
- **Easy to dismiss:** click outside the ring or in the center to close it without running an action.
- **Localized UI:** English and Indonesian, following the system language.

## Requirements

- macOS 14 (Sonoma) or later
- A trackpad
- Xcode Command Line Tools (to build from source)

## Installation

### From DMG

1. Open `Shortqut-<version>.dmg`.
2. Drag **Shortqut** into the **Applications** folder.
3. Launch Shortqut from Applications.

If macOS blocks the app because it isn't notarized, right-click Shortqut → **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Shortqut.app
```

### Build from source

```bash
git clone https://github.com/<username>/shortqut.git
cd shortqut
./scripts/make-app.sh        # creates build/Shortqut.app
open build/Shortqut.app
```

To build a DMG:

```bash
./scripts/make-dmg.sh        # creates build/Shortqut-<version>.dmg
```

## Permissions

Shortqut needs the **Accessibility** permission to send keyboard actions (for example Screenshot).

1. Open the Shortqut menu bar item → **Grant Accessibility Permission…**
2. Enable Shortqut in **System Settings → Privacy & Security → Accessibility**.

If double-pressing Command doesn't work, also enable Shortqut in **Privacy & Security → Input Monitoring**.

## Usage

| Action | How |
| --- | --- |
| Open the ring | Tap the trackpad with 4 fingers, or press Command twice |
| Choose an action | Move the cursor to a slice, then click |
| Close without an action | Click outside the ring or in the center |
| Open Settings | Menu bar → **Settings…** (⌘,) |

In Settings, you can add apps with **Add → Application…** and remove them with the − button. Finder and Terminal are added by default.

## Project structure

```
Sources/Shortqut/
├── ShortqutApp.swift            # Entry point, menu bar, and AppDelegate
├── TrackpadGestureMonitor.swift # 4-finger tap detection (MultitouchSupport)
├── CommandDoubleTapMonitor.swift# Command double-press detection
├── RingPanelController.swift    # Transparent panel and cursor positioning
├── RingView.swift               # Ring geometry and drawing
├── RingStore.swift              # Ring items (apps, actions, sub rings)
├── ShortcutItem.swift           # Action model and execution
├── SettingsView.swift           # Settings window
└── Permissions.swift            # Accessibility permission
Resources/
├── en.lproj/Localizable.strings # English UI strings (source keys)
└── id.lproj/Localizable.strings # Indonesian UI strings
scripts/
├── make-app.sh                  # Release build and .app bundle
├── make-dmg.sh                  # Builds a DMG (optional signing and notarization)
├── make-icon.swift              # Draws the 1024×1024 icon
└── make-icon.sh                 # Creates AppIcon.icns
```

## Customization

- **Ring item limit:** change `RingLimits.maxItems` in [RingStore.swift](Sources/Shortqut/RingStore.swift).
- **Native actions:** add or edit `NativeShortcut` cases in [NativeShortcut.swift](Sources/Shortqut/NativeShortcut.swift).
- **Ring size:** change `canvas`, `inner`, and `outer` in [RingView.swift](Sources/Shortqut/RingView.swift), and `size` in `RingController` in [RingPanelController.swift](Sources/Shortqut/RingPanelController.swift).
- **Gap between slices:** change `gapPoints` in [RingView.swift](Sources/Shortqut/RingView.swift).
- **Tap sensitivity:** change `maxTapDuration`, `maxDrift`, and `cooldown` in [TrackpadGestureMonitor.swift](Sources/Shortqut/TrackpadGestureMonitor.swift).
- **Command double-press interval:** change `maxInterval` in [CommandDoubleTapMonitor.swift](Sources/Shortqut/CommandDoubleTapMonitor.swift).
- **UI strings:** edit the `Localizable.strings` files in `Resources/<lang>.lproj/`. Keys are the English text; add a new `<lang>.lproj` folder for another language.
- **Icon:** run `./scripts/make-icon.sh` after editing [make-icon.swift](scripts/make-icon.swift).

## Technical notes

- Trackpad tap detection uses the private **MultitouchSupport** framework, loaded with `dlopen`. It isn't a public Apple API, so it may change in future macOS versions.
- Because it relies on a private API, Shortqut **cannot be shipped on the Mac App Store**. Distribution is via DMG.
- Keyboard actions are sent through `CGEvent` and require the Accessibility permission.

## License

Not yet specified.
