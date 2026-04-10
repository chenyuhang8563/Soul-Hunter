# Pause Panel Design

**Date:** 2026-04-11

## Goal

Add an in-run pause panel for the 320 x 180 arena gameplay view.

The pause flow should:

- let the player pause during normal gameplay
- keep the main pause menu visually simple and centered
- expose a separate rewards details page instead of crowding the main menu
- show the rewards selected in the current run as text entries
- show the player's current base stats after permanent run rewards, while excluding temporary combat buffs

## Current Context

- [`Scenes/UI/pause_ui.tscn`](/C:/Users/16085/Documents/role/Scenes/UI/pause_ui.tscn) already exists as an empty `CanvasLayer`.
- [`Scenes/Arena/arena_scene.gd`](/C:/Users/16085/Documents/role/Scenes/Arena/arena_scene.gd) currently creates arena UI layers in code instead of relying on pre-placed scene children.
- [`Scenes/Arena/arena_run_controller.gd`](/C:/Users/16085/Documents/role/Scenes/Arena/arena_run_controller.gd) already owns run state and already pauses the tree for reward selection and defeat.
- [`Character/Common/run_modifier_controller.gd`](/C:/Users/16085/Documents/role/Character/Common/run_modifier_controller.gd) already tracks selected reward card ids and applies permanent-in-run stat modifiers.
- [`Character/Common/character.gd`](/C:/Users/16085/Documents/role/Character/Common/character.gd) already separates `get_base_stat_value()` from `get_stat_value()`, where `get_stat_value()` includes buffs and run modifiers.

This means the new pause panel should integrate with existing arena UI code, while reading reward and stat data from the player and run controller instead of inventing a parallel data model.

## Decision

Use `pause_ui.tscn` as the UI scene and attach a dedicated `PauseUI` script that manages two internal pages:

- a centered main pause menu
- a rewards details page

The arena scene will instantiate this UI alongside the existing HUD, reward selection UI, and run result UI.

## Layout

### Main Pause Page

The main page is intentionally minimal.

- Title: `Paused`
- Centered buttons, stacked vertically:
  - `Resume`
  - `Run Rewards`
  - `Settings`
  - `Exit`
- `Settings` is visible but disabled
- A small short hint such as `Coming Soon` is shown near the disabled settings button

For a 320 x 180 game resolution, the menu should sit in a centered compact panel instead of stretching edge-to-edge. The goal is to keep the first screen readable at a glance and avoid mixing actions with data-heavy information.

### Rewards Details Page

The rewards page is a secondary panel reached from the main pause page.

- Top row:
  - `Back` button on the left
  - centered title such as `Run Rewards`
- Middle area:
  - text-based list of currently selected rewards for this run
- Bottom row:
  - a single summary line for the player's current base stats

This page exists to move run-state information out of the main pause menu while still keeping it available during pause.

## Component Structure

Add a script for the pause scene, for example:

- [`Scenes/UI/pause_ui.gd`](/C:/Users/16085/Documents/role/Scenes/UI/pause_ui.gd)

Use the existing [`Scenes/UI/pause_ui.tscn`](/C:/Users/16085/Documents/role/Scenes/UI/pause_ui.tscn) as the root scene and build the following node structure inside it:

- `PauseUI` (`CanvasLayer`)
- `Root` (`Control`, full rect)
- `Overlay` (`ColorRect`, full rect, darkened background)
- `MainPanel` (`PanelContainer`)
- `MainMenu` (`VBoxContainer`)
- `TitleLabel` (`Label`)
- `ResumeButton` (`Button`)
- `RunRewardsButton` (`Button`)
- `SettingsButton` (`Button`, disabled)
- `SettingsHintLabel` (`Label`)
- `ExitButton` (`Button`)
- `RewardsPanel` (`PanelContainer`)
- `RewardsHeader` (`HBoxContainer`)
- `BackButton` (`Button`)
- `RewardsTitleLabel` (`Label`)
- `RewardsGrid` (`GridContainer`)
- `BaseStatsLabel` (`Label`)

Implementation can add wrapper `MarginContainer` or `CenterContainer` nodes as needed, but the design intent is:

- one full-screen overlay root
- one visible content panel at a time
- explicit references for the buttons and data labels

## Page State Model

The pause UI owns its own local page state:

- `MAIN_MENU`
- `REWARDS_DETAILS`

Behavior:

- opening the pause UI always starts on `MAIN_MENU`
- pressing `Run Rewards` switches to `REWARDS_DETAILS`
- pressing `Back` returns to `MAIN_MENU`
- pressing `Resume` closes the pause UI and unpauses gameplay

This local page state should stay entirely inside `PauseUI` and should not be added to `ArenaRunController.RunState`, because it is presentation state rather than run progression state.

## Pause Rules

Manual pause should only be allowed when the run is in normal playable states:

- `IN_WAVE`
- `REST`

Manual pause should not open while any of these are already active:

- reward selection
- victory screen
- defeat screen

Reasons:

- reward selection already pauses the tree and owns the screen
- result screens already represent terminal run states
- blocking manual pause during those moments avoids conflicting overlays

The pause UI should use `process_mode = PROCESS_MODE_ALWAYS` so it remains interactive while the scene tree is paused.

## Arena Integration

Integrate pause UI in [`Scenes/Arena/arena_scene.gd`](/C:/Users/16085/Documents/role/Scenes/Arena/arena_scene.gd) the same way the current HUD and reward UI are attached.

Add:

- one `PauseUI` instance during `_setup_ui()`
- one arena input path for pause toggle
- signal hookups for:
  - resume request
  - exit request

Recommended ownership split:

- `arena_scene.gd` decides whether pause is allowed and owns scene-level actions such as restart or exit
- `pause_ui.gd` owns visual state, page switching, and data presentation

## Input Behavior

Add a dedicated pause input action in [`project.godot`](/C:/Users/16085/Documents/role/project.godot), for example `pause`, and bind it to a keyboard key appropriate for desktop play.

Behavior:

1. When the player presses pause during `IN_WAVE` or `REST`, show the pause UI and set `get_tree().paused = true`.
2. When the player presses pause again while the pause UI is open and the current page is `MAIN_MENU`, close the pause UI and resume.
3. When the player presses pause while on the rewards details page, return to the main pause page first rather than instantly closing everything.

This keeps the input predictable and makes the secondary page behave like a submenu instead of a separate modal system.

## Rewards Data Presentation

The rewards details page should read selected rewards from the run modifier controller:

- call `player.ensure_run_modifier_controller()` if needed
- use `get_selected_cards()` to retrieve selected reward ids

To display readable text instead of raw ids:

- build a lookup from reward id to `RewardCardDefinition`
- source that lookup from the same reward pool already used by the arena run
- render each selected card as a short text entry, preferring `title`

If no rewards have been selected yet:

- show a short placeholder such as `No rewards selected yet`

### Grid Fill Rule

The reward list should fill downward first, then continue into a new column when the current column is full.

In practice for Godot UI this means:

- choose a fixed maximum row count per column
- compute the needed column count from the reward total
- feed items into a grid so the visual reading order is top-to-bottom within each column

The exact row count can be tuned in implementation, but the design target is to keep entries readable within 320 x 180 without shrinking text too aggressively.

## Base Stats Summary

The bottom line of the rewards details page should show:

- health
- attack
- defense
- crit chance
- lifesteal
- attack interval

The displayed values must follow this rule:

- include the character's base stats
- include permanent run rewards from the current run
- exclude temporary combat buffs

### Value Source Rules

Use character base stats from [`Character/Common/character.gd`](/C:/Users/16085/Documents/role/Character/Common/character.gd) and apply run modifiers directly through the run modifier controller.

Do not use `get_stat_value()` for this summary, because that would include temporary buffs.

Recommended source logic:

- base stat:
  - `player.get_base_stat_value(stat_id, fallback)`
- permanent run-adjusted stat:
  - `run_modifier_controller.modify_stat_value(stat_id, base_value)`
- lifesteal:
  - `run_modifier_controller.get_lifesteal_percent()`

### Display Mapping

Map the requested player-facing summary fields to current game stat data like this:

- `HP` -> `max_health`
- `ATK` -> `light_attack_damage`
- `DEF` -> `defense`
- `CRIT` -> `crit_chance`
- `LS` -> `lifesteal_percent`
- `INT` -> `attack_cooldown`

`ATK` should use a single representative attack value instead of trying to summarize every attack family in one line. `light_attack_damage` is the cleanest fit for the current request and current reward pool.

## Exit Behavior

`Exit` from the pause menu should leave the current arena run and use the existing scene transition path rather than implementing a special-case teardown inside the pause UI.

The pause UI should emit an exit signal. The arena scene should then:

- clear pause
- hide the panel
- hand off to the existing scene manager or current known exit route

If no reusable arena-exit path exists yet, the first implementation can safely choose a single explicit destination scene and keep that routing decision inside `arena_scene.gd`, not inside `pause_ui.gd`.

## Error Handling And Edge Cases

- If the player reference is missing, the pause UI should still open but show placeholder text for rewards and stats instead of erroring.
- If the run modifier controller is missing, rewards should show empty state and base stats should fall back to raw character base values.
- If the reward lookup cannot resolve a selected id, show the id as a fallback text entry instead of dropping the item.
- Reopening pause should always reset the UI to the main menu page.
- Entering reward selection, victory, or defeat while pause is open should force-close the pause UI so arena-owned modal flows remain authoritative.

## Testing

Add regression coverage in `tests/roguelike` for the following:

- pause can open during `IN_WAVE`
- pause can open during `REST`
- pause cannot open during reward selection
- pause main page opens by default
- `Run Rewards` switches to the rewards details page
- rewards details page shows selected reward titles in column-first order
- base stats summary includes run modifier changes
- base stats summary excludes temporary buff changes
- `Settings` stays disabled
- `Resume` closes pause and resumes the tree
- `Exit` emits the expected exit request signal

Favor Gut tests that validate UI state and data formatting through scene/script behavior, not through shell log inspection.

## Scope

This design intentionally includes:

- pause UI scene structure
- arena integration
- page switching
- reward text presentation
- base stat summary rules
- temporary disabled settings button

This design intentionally excludes:

- a full settings system
- icon-based reward presentation
- controller-specific navigation polish
- global pause support outside the arena flow
- visual art polish beyond a functional low-resolution layout
