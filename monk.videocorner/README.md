# VideoCorner

Search YouTube from the Omarchy bar and pop the selected video into a floating,
pinned player window.

## Features

- YouTube search through `yt-dlp`
- Floating, pinned player that auto-matches the video's real aspect ratio
- Video-only layout (no page chrome) via a bundled Chromium extension
- Full native YouTube controls — play, pause, seek, volume, captions, settings
- Configurable corner and size

## Usage

Click the **▶** bar icon to open the panel, type to search, then click a video
or press `Ctrl+1…9` to play it. Move/resize the player from the panel.

## Keys

| Key | Action |
|---|---|
| `Ctrl+1…9` | play the numbered video |
| `↑↓←→` / `h j k l` | move the player to a corner |
| `Ctrl+=` / `Ctrl+-` | resize up / down |
| `Ctrl+Q` | close the video |
| `Esc` / `Ctrl+[` | close the panel (back to main view from results) |
| `Tab` | switch bar panel |

## Install

```sh
omarchy plugin add https://github.com/brianspragge/videocorner.git --enable
```

Then register the Chromium extension for the video-only player layout and
restart Chromium:

```sh
~/.config/omarchy/plugins/monk.videocorner/scripts/install-extension.sh
```

Add the widget to your bar in `~/.config/omarchy/shell.json` under
`bar.layout.right`.

**Optional: add a keyboard shortcut**

To open and close VideoCorner from anywhere, add this line to your personal
Hyprland keybindings file, `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + Y", "VideoCorner", "omarchy-shell shell toggle monk.videocorner")
```

Then reload Hyprland (`hyprctl reload` or re-source your config). Clicking the
**▶** bar icon also works, so this keybind is optional.

## Requirements

- Omarchy with `omarchy-shell`
- Chromium
- `yt-dlp`

## Remove

```sh
omarchy plugin remove monk.videocorner
~/.config/omarchy/plugins/monk.videocorner/scripts/remove-extension.sh
```

## Transparency

VideoCorner runs only when you open its panel or play a video. It does not
intercept or change input for any other application or window.

**What the extension installer touches**

The `install-extension.sh` script edits exactly one file:

`~/.config/chromium-flags.conf`

- It appends the VideoCorner extension path to the existing `--load-extension=`
  line (or adds that line if it's absent).
- Every other line in the file is left untouched.
- It is idempotent: running it again does nothing.

**What it does not touch**

- Hyprland, its input handling, or any keybindings
- `~/.config/omarchy/shell.json` or any other Omarchy settings
- Browser history, bookmarks, cookies, or other Chromium data
- Any other application, window, or remote session (e.g. browser-based
  environments like GitHub Codespaces)

**Player extension scope**

The bundled Chromium extension only activates for URLs containing
`videocorner=1` (your selected video). Regular YouTube tabs and all other sites
are unaffected.

**Removal**

`scripts/remove-extension.sh` strips only the VideoCorner entry from
`~/.config/chromium-flags.conf`, leaving every other flag and file intact.

## License

[MIT](LICENSE) © 2026 Brian Spragge
