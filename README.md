# Lönn Visual Previews

English | [简体中文](README.zh-CN.md)

Tile icons, decal hover previews, and entity hover previews for Lönn's material lists.
This is a Lua editor plugin; no DLL or Lönn rebuild is required.

## Features

- **Tile icons:** show a 3×3 tile sample before foreground/background tile names, alongside favorite stars.
- **Decal previews:** hover over foreground/background decals to see their texture and pixel dimensions.
- **Entity previews:** hover over entity entries to see a static thumbnail of the placement with its default properties.
- **Preview delay:** choose how long to hover before decal/entity previews appear, including instant previews.

Previews scale with the UI font, use a checkerboard to show transparency, and stay within the window.
They close when the pointer leaves the entry, the list changes, dragging starts, or the corresponding option is disabled.
The popup does not intercept mouse input. Search, selection, descriptions, and favorites remain available.

## Installation

Current version: **0.3.2**. Tested with **Lönn 1.0.10 (OlympUI)**.

1. Place the release file `LoennVisualPreviews.zip` in Celeste's `Mods/` directory. Leave it zipped.
   For development, you can instead use a `Mods/LoennVisualPreviews/` directory containing `everest.yaml` and `Loenn/` directly.
2. Restart Lönn.

Use either the ZIP or the directory installation to avoid loading the plugin twice.

## Settings

Open **Settings → Editor → Visual previews**:

| Option | Default | Description |
| --- | --- | --- |
| Tile icons | On | Show foreground/background tile icons. |
| Decal previews | On | Show decal hover previews. |
| Entity previews | On | Show entity hover previews. |
| Preview delay (seconds) | 0.35 | Shared hover delay for decal and entity previews, in seconds. |

The delay accepts any finite, nonnegative number. Set it to **0** for instant previews.
Empty, negative, or nonnumeric input is highlighted in red and leaves the last valid setting in effect.

All settings apply immediately and save automatically; there is no need to click the native **Save changes** button.
Preferences are stored under `Plugins/LoennVisualPreviews/settings.conf` in Lönn's configuration directory.

## Preview behavior and limitations

Entities use Lönn's registered renderers, including sprites, multiple sprites, rectangles, and custom `draw` callbacks.
The plugin copies the placement's default properties and the selected room, supplies required nodes, and renders a static thumbnail without placing an entity in the map.
If no room is selected, it uses an empty preview room. Node paths and effects depend on the entity's renderer.
Entities that rely on game runtime behavior, selection state, or special context may differ from their appearance in the game.
If rendering fails, the popup displays **Preview unavailable** and the list remains usable.

Entity thumbnails are generated on demand, use canvases no larger than 512×512, and are released when the hover target changes.
Decals load on demand through Lönn's atlas cache; animated decals show the static frame associated with the list entry.
Tile icons use a fixed variation and support the current map's vanilla and custom tilesets.

The plugin wraps the Tools window and UI drawing functions. Future Lönn UI changes or other plugins replacing those functions may require adjustments.

## Development

From the plugin root, run `python3 scripts/check.py`.
See the [development guide](docs/development.md) for the directory layout and local integration checks.
