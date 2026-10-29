# Development

[English README](../README.md) | [中文说明](../README.zh-CN.md)

## Plugin layout

The plugin follows Lönn's [plugin structure](https://github.com/CelestialCartographers/Loenn/wiki/Plugin-Structure):

```text
LoennVisualPreviews/
├── everest.yaml
├── README.md
├── README.zh-CN.md
├── docs/
│   └── development.md
├── scripts/
│   └── check.py
├── tests/
│   └── integration.lua
└── Loenn/
    ├── libraries/
    │   ├── entity_preview.lua
    │   ├── hover_preview.lua
    │   ├── preview_timing.lua
    │   └── settings_window.lua
    └── ui/
        └── windows/
            └── visual_previews.lua
```

`everest.yaml` defines the mod identifier (`LoennVisualPreviews`) and version.
`Loenn/ui/windows/visual_previews.lua` installs the Tools window hooks and tile icons.
The libraries provide entity rendering, shared hover popups, delay validation, and Settings integration.

English is the default README. Keep the Chinese README in sync when changing features or usage.
User documentation stays at the root; development documentation goes in `docs/`.
The integration test runner lives in `scripts/`, with its Lua checks in `tests/`.
These directories are outside `Loenn/`, so Lönn does not load test code as a plugin.

## Local integration checks

Run this command from the plugin root (the directory containing `everest.yaml`):

```sh
python3 scripts/check.py
```

Requirements:

- Python 3 and Xvfb on Linux.
- An installed Celeste game and Lönn `.love` archive.
- A local `loenn` launcher supporting `LOENN_LOVE_PATH` to select the test copy of Lönn.

The runner resolves the plugin and Lua checks relative to its own location, so it also works when invoked from another directory.
It accepts `--celeste`, `--loenn-archive`, and `--launcher` to override local paths.
It uses temporary preferences and read-only links to game resources in an isolated Xvfb session.
It checks vanilla placements, failing custom renderers, settings persistence, hover delays, room/template isolation, UI reloads, and tile/decal previews.
Preview screenshots are checked for visible artwork, not just the presence of a popup.
The window-size check resizes the existing SDL window; resetting the display mode can clear Lönn's cached canvases.
Logs, coverage results, and screenshots are written to a temporary directory printed by the runner.

## Packaging

Follow the Everest [mod packaging guidelines](https://github.com/EverestAPI/Resources/wiki/Mod-Structure#packaging-your-mod-for-publishing).
The release ZIP must contain `everest.yaml`, `Loenn/`, and the documentation directly at its root, without an enclosing `LoennVisualPreviews/` directory.
The ZIP also includes `scripts/` and `tests/` so the extracted package contains the integration checks.
Keep test output and previous release archives outside the ZIP.
