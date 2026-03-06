![icon](easy-move-resize/Images.xcassets/AppIcon.appiconset/icon_128x128.png)

# Zooom3

A macOS utility that adds **modifier key + mouse** window move and resize, inspired by X11/Linux window managers and the classic [Zooom2](https://roaringapps.com/app/zooom2) app.

Zooom3 is a fork of [Easy Move+Resize](https://github.com/dmarcotte/easy-move-resize) by Daniel Marcotte, with additional features to match the Zooom2 experience.

## Features

- **Move windows**: Hold modifier keys + left-click drag anywhere in a window
- **Resize windows**: Hold modifier keys + right-click drag (direction based on cursor position in the window's thirds grid)
- **Hover mode**: Hold modifier keys and windows move/resize as the mouse moves — no click needed (like Zooom2)
- **Customizable modifiers**: Choose any combination of Cmd, Ctrl, Alt, Shift, Fn
- **Separate resize modifiers**: Configure different modifier keys for resize
- **Per-app disable**: Disable Zooom3 for specific applications
- **Configurable mouse buttons**: Choose which mouse button triggers move vs resize

## Installation

Download the latest release from the [Releases page](https://github.com/supagroova/Zooom3/releases), unzip, and run.

### Troubleshooting

- If macOS refuses to launch Zooom3 because it "cannot check it for malicious software": Right-click the app and select "Open", then click "Open" in the dialog.
- If Accessibility permission is not working: Remove Zooom3 from System Preferences > Privacy & Security > Accessibility, then re-add it.

## Usage

Zooom3 runs as a menu bar app.

- **Move**: `Cmd + Ctrl + Left Mouse` drag anywhere in a window
- **Resize**: `Cmd + Ctrl + Right Mouse` drag anywhere in a window
  - Resize direction is based on which region of the window you click (thirds grid)
- **Hover mode**: Enable via menu, then just hold modifiers — no click needed
- Modifier keys can be customized from the menu bar icon
- Toggle `Disabled` to pause all functionality
- `Bring Window to Front` raises background windows when moving/resizing them
- `Reset to Defaults` restores original settings

## Contributing

[Contributions](contributing.md) welcome! File issues or submit pull requests on [GitHub](https://github.com/supagroova/Zooom3).

## License

MIT — see [LICENSE.txt](LICENSE.txt)
