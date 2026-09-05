---
name: test-storyteller-in-flipbook
description: Build Storyteller into a specific local Flipbook checkout and verify Storyteller behavior end to end through FlipbookAgentGateway and Roblox Studio MCP. Use for Storyteller changes that need real Flipbook Studio validation.
---

# Test Storyteller In Flipbook

Use an isolated Flipbook worktree whose branch includes `FlipbookAgentGateway`. Do not modify or install from an unrelated Flipbook checkout.

## Prepare The Integration Build

From the Storyteller repository, install its toolchain and overlay the development package into the exact Flipbook checkout:

```bash
rokit install
lute run install
lute run try-in-flipbook --flipbook /absolute/path/to/flipbook-worktree
```

The overlay script updates both the installed package contents and Wally's generated Storyteller type link. Run it again after reinstalling Flipbook dependencies because `wally install` replaces the package overlay.

From the target Flipbook worktree, run local checks and build the Studio artifacts:

```bash
lute run lint
lute run analyze
lute run build plugin --channel dev --clean
lute run build storybook --channel dev --clean
```

The Storyteller and Flipbook test tasks upload a place to Roblox. Obtain explicit authorization before running those test tasks when the code is private.

## Connect Studio MCP

This repository registers Studio MCP as `Roblox_Studio` in `.mcp.json`. A task started before `.mcp.json` existed may not expose the server; start a fresh task from the Storyteller worktree in that case. Do not implement a second protocol client as a workaround.

Before opening the place, install the integration plugin under a distinct filename so it cannot be confused with the normal Flipbook development plugin. Then:

1. Call `list_roblox_studios` to record the baseline.
2. Open the target Flipbook worktree's `build/flipbook-storybook.rbxl`.
3. Poll `list_roblox_studios` until a new Studio id appears with that filename.
4. Call `get_studio_state` and confirm the Edit data model is available.
5. Use `execute_luau` with `datamodel_type = "Edit"` for gateway checks.

If no Studio appears, verify Studio MCP is enabled in the open Studio session. If a tool reports `Not connected to the WS host`, stop and ask for that setting to be enabled; selecting another data model does not repair the connection.

## Drive Flipbook Through Its Gateway

Find `CoreGui.FlipbookAgentGateway`, call `getInstructions`, and call the gateway's `list` method before using actions. Treat that runtime response as the source of truth for current action schemas.

For multi-story verification:

1. Open the Flipbook widget and refresh storybooks.
2. Call `listStories` and verify the target module produces separate concrete entries with distinct `id` and `name` values.
3. Call `openStory` once per entry, passing its module path, storybook path, and `storyId`.
4. Poll `getCurrentStory` until the requested id matches and `isMounted` is true; do not use a fixed sleep.
5. Exercise controls when present and verify state with `getControls`.

Studio MCP viewport captures do not include dock widgets. For visual evidence, call `embedFlipbook`, enter play mode, and capture the embedded Flipbook UI in the viewport. Stop play mode when finished. Semantic gateway results are still required because screenshots alone do not prove which concrete story id Flipbook selected.
