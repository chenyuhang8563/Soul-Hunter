# Book Menu Settings Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old pause menu with BookMenu Settings controls for continue/save/quit and BGM/SFX volume.

**Architecture:** Keep BookMenu as the pause/settings owner, add SettingsPage controls inside `book_menu.tscn`, and route all volume changes through `AudioManager`. Simplify audio routing to two buses, `BGM` and `SFX`, reflected in `Resources/default_bus_layout.tres`.

**Tech Stack:** Godot 4.6, GDScript with tabs, `.tscn` scene resources, Gut tests, Godot MCP validation.

---

## File Structure

- Modify `Scenes/UI/book_menu.tscn`: add Settings controls and slider nodes, using `Resources/cn.tres` and slider textures.
- Modify `Scenes/UI/book_menu.gd`: wire Continue/Save/Quit buttons, pause input, BGM blur, and slider-to-AudioManager calls.
- Modify `Global/audio_manager.gd`: expose BGM/SFX volume APIs and route all SFX to `SFX`.
- Modify `Resources/default_bus_layout.tres`: define `BGM` and `SFX`, remove `SFX_Battle`.
- Modify `Scenes/arena.tscn`: remove PauseUI instance and resource reference.
- Delete `Scenes/UI/pause_ui.tscn` and `Scenes/UI/pause_ui.gd` after confirming no remaining references.
- Modify tests: extend `tests/test_book_menu_tabs.gd`; add audio manager assertions where practical.

## Task 1: Tests First

- [ ] Extend `tests/test_book_menu_tabs.gd` with assertions that SettingsPage contains Continue/Save/Quit, BGM/SFX sliders, Continue closes/unpauses, Save is inert, and tab switching still works.
- [ ] Add or extend an audio test to assert AudioManager exposes BGM/SFX volume APIs and sound names route to `SFX`.
- [ ] Run Gut and verify these tests fail because controls/APIs do not exist yet.

## Task 2: Audio Bus and AudioManager

- [ ] Update `Resources/default_bus_layout.tres` so bus 1 is `BGM` and bus 2 is `SFX`, both sending to `Master`.
- [ ] Update `Global/audio_manager.gd` so `sword_swing`, `sword_clash`, and `hit_flesh` all return `SFX`.
- [ ] Add `get/set_bgm_volume_linear()` and `get/set_sfx_volume_linear()` helpers that clamp `0.0..1.0`, map 0 to `-80 dB`, and use `linear_to_db` otherwise.
- [ ] Preserve BGM low-pass pause blur behavior on the `BGM` bus.
- [ ] Run audio tests and fix until green.

## Task 3: SettingsPage UI and Behavior

- [ ] Add SettingsPage buttons: `ContinueButton`, `SaveButton`, `QuitButton` with Chinese text using `res://Resources/cn.tres`.
- [ ] Add `BgmLabel`, `BgmSlider`, `SfxLabel`, `SfxSlider`, using slider textures `Slider01_Box.png` and `Slider02_Bar04.png`.
- [ ] Wire `ContinueButton` to close BookMenu and restore pause/blur.
- [ ] Wire `SaveButton` to no-op.
- [ ] Wire `QuitButton` to `get_tree().quit()`.
- [ ] Wire sliders to AudioManager public APIs.
- [ ] Make `pause` input toggle BookMenu, preserving `Tab` behavior.
- [ ] Run BookMenu tests and fix until green.

## Task 4: Remove Old PauseUI

- [ ] Remove PauseUI ext_resource and instance from `Scenes/arena.tscn`.
- [ ] Delete `Scenes/UI/pause_ui.tscn` and `Scenes/UI/pause_ui.gd` after confirming no references remain.
- [ ] Run static reference check for `pause_ui` / `PauseUI`.

## Task 5: Verification and Commit

- [ ] Run `Gut` for BookMenu and audio/prop tests.
- [ ] Load `res://Scenes/UI/book_menu.tscn` with Godot MCP and verify no errors.
- [ ] Load `res://Scenes/arena.tscn` with Godot MCP and verify no new errors.
- [ ] Commit only implementation files; leave user-owned `.gitignore` and `AGENTS.md` untouched unless explicitly requested.

## Self-Review Notes

- Covers all spec requirements: Settings controls, no-op Save, audio sliders, cn.tres font, BGM/SFX bus simplification, old PauseUI removal.
- Scope excludes save persistence, volume persistence, and non-audio settings.
- Tests are updated before implementation per TDD.
