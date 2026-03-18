# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zooom3 is a macOS menu bar utility (Objective-C) that adds modifier key + mouse window move/resize, inspired by X11/Linux window managers. It's a fork of [Easy Move+Resize](https://github.com/dmarcotte/easy-move-resize) with additional features like hover mode and separate resize modifiers.

Bundle ID: `com.supagroova.zooom3`

## Build & Test

Build and run via Xcode:
```bash
xcodebuild -project zooom3.xcodeproj -scheme zooom3 build
xcodebuild -project zooom3.xcodeproj -scheme zooom3 test
```

The app requires macOS Accessibility permissions (uses `CGEventTap` and `AXUIElement` APIs). The test host is the app itself — tests run inside `Zooom3.app`. The `applicationDidFinishLaunching:` method skips the accessibility check when `XCTestCase` is present.

## Architecture

**EMRAppDelegate** — Central controller. Sets up a `CGEventTap` to intercept mouse/keyboard events system-wide. The static `myCGEventCallback` function is the core event handler that routes mouse down/drag/up events to move or resize logic. It reads cached preference values (ivars, not NSUserDefaults) for performance in the hot path. Handles both click-drag mode and hover mode (modifier-only activation).

**EMRMoveResize** — Singleton state holder for the active move/resize operation. Stores the target `AXUIElementRef` window, current position/size, resize section (thirds grid), and tracking timestamp. Manual `CFRetain`/`CFRelease` for the window reference.

**EMRPreferences** — Persists settings to `NSUserDefaults` (suite: `userPrefs`). Manages modifier flags, mouse button assignments, disabled apps, hover mode. Can also be read/written via `defaults` CLI: `defaults read com.supagroova.zooom3 ModifierFlags`.

**EMRPopoverViewController** — Programmatic NSPopover UI (no storyboard). Controls are wired by identifier convention: checkboxes use `move.CMD`, `resize.CTRL`, `hoverMode`, `bringToFront`, `resizeOnly`, `resetToDefaults`, `quit`; popup buttons use `moveMouseButton`, `resizeMouseButton`.

## Key Design Patterns

- **Event tap callback is a C function** — not an ObjC method. It bridges to `EMRAppDelegate` via the `refcon` pointer. Keep this function fast; it runs on every mouse/keyboard event.
- **Resize direction uses a thirds grid** — the window is divided into a 3x3 grid; click position determines which edges resize.
- **Conflict detection** — when move and resize have identical button + modifier config, resize takes priority.
- **Hover mode requires recreating the event tap** (`recreateEventTap`) to add/remove `kCGEventFlagsChanged` and `kCGEventMouseMoved` from the event mask.
- **Refresh rate throttling** — move/resize updates are throttled to the minimum screen refresh interval across all displays.

## Preferences Keys

Defined as macros in `EMRPreferences.h`: `ModifierFlags`, `ResizeModifierFlags`, `MoveMouseButton`, `ResizeMouseButton`, `HoverModeEnabled`, `BringToFront`, `ResizeOnly`, `DisabledApps`.

## Development Approach

Follow TDD: write a failing test first, then implement until the test passes.

## Testing

Tests are in `zooom3Tests/` using XCTest. Test files mirror the main classes: `EMRPreferencesTest`, `EMRMoveResizeTest`, `EMRAppDelegateTest`, `EMRPopoverViewControllerTest`. Tests use isolated `NSUserDefaults` instances to avoid polluting real preferences.
