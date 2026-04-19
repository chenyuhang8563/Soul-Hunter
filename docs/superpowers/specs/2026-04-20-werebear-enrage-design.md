# Werebear Enrage Design

## Goal

Add a new werebear boss enrage mechanic that triggers once when its health falls to 50% or below. While enraged, the boss is covered by the same red overlay used by the possession haste effect and gains +25% move speed, +25% attack speed, and +25% attack damage.

## Current Context

- `res://Character/Werebear/werebear.gd` already tracks a one-time phase-two transition through `_update_boss_phase()`.
- `res://Character/Common/Buffs/` already provides a reusable stat-modifier buff system.
- `res://Character/Common/character.gd` already renders a red overlay when `possession_combo_haste` is active.

## Design Choice

Use a dedicated permanent buff for werebear enrage instead of hand-editing stats inside the boss script.

This keeps the mechanic inside the existing stat pipeline, avoids special-case math in the boss controller, and lets the visual overlay key off buff presence instead of phase-only state.

## Behavior

### Trigger

- The mechanic triggers when the werebear's HP ratio is less than or equal to `0.5`.
- It only triggers once per life.
- Trigger timing remains tied to the existing phase-two transition in `Werebear._update_boss_phase()`.

### Buff Effects

The enrage buff applies these multiplicative modifiers:

- `move_speed`: `+0.25`
- `attack_speed_multiplier`: `+0.25`
- `light_attack_damage`: `+0.25`
- `hard_attack_damage`: `+0.25`
- `ultimate_attack`: `+0.25`

The buff has no duration timeout. It lasts until the werebear dies or is otherwise reset by the normal character lifecycle.

### Visuals

- Reuse the current red overlay appearance used for `possession_combo_haste`.
- Do not duplicate a separate overlay implementation.
- Extend the overlay visibility condition so it appears when either:
	- `possession_combo_haste` is active, or
	- `werebear_enrage` is active.

## File-Level Changes

### `res://Character/Common/Buffs/werebear_enrage_buff.gd`

Create a new buff class that:

- uses the existing buff-effect base class
- exposes a stable stack key and buff id, `werebear_enrage`
- builds the five stat modifiers listed above
- does not expire during normal combat

### `res://Character/Werebear/werebear.gd`

When phase two starts:

- keep the current phase-two bookkeeping
- add the new enrage buff to the werebear exactly once

### `res://Character/Common/character.gd`

Update possession-haste overlay syncing so the same overlay is shown for either supported buff.

## Testing Strategy

### Automated

Add coverage for:

- phase-two transition applying enrage only once
- the enrage buff producing 1.25x effective values for move speed, attack speed, and all three attack-damage stats
- overlay gating accepting `werebear_enrage` in addition to `possession_combo_haste`

If the current project has no stable automated harness for one of these layers, prefer the smallest focused test surface possible around the buff/stat logic and keep scene/runtime validation manual.

### Runtime Verification

Verify in Godot that:

- the red overlay appears as soon as the werebear crosses 50% HP
- movement and attack cadence visibly increase
- damage output is increased after the trigger
- the effect does not retrigger repeatedly below 50% HP

## Risks And Mitigations

- **Risk:** Overlay logic becomes tied to a single buff name again later.
	- **Mitigation:** centralize the visibility check in one helper or one condition update.
- **Risk:** The buff could accidentally refresh or stack.
	- **Mitigation:** use a single-stack identity and only add it during the guarded phase-two transition.
- **Risk:** Attack damage math may miss one attack type.
	- **Mitigation:** explicitly modify `light_attack_damage`, `hard_attack_damage`, and `ultimate_attack` in the buff.

## Out Of Scope

- Any redesign of werebear phase-two attack patterns
- New UI iconography for enrage
- Any change to possession haste balance or visuals beyond shared overlay reuse
