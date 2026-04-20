# Werebear Knockback Resist Design

## Goal

Implement a new boss mechanic where the werebear only receives half of the normal knockback effect when damaged.

The design must follow the reusable buff/stat pipeline instead of hard-coding a werebear special case in shared damage lifecycle code.

## Current Context

- `res://Character/Common/character_lifecycle.gd` currently applies horizontal knockback in `on_damaged()` by assigning `owner.knockback_velocity = direction * owner.KNOCKBACK_VELOCITY`.
- `res://Character/Common/character.gd` already exposes a shared stat lookup path through `get_stat_value()`, which combines base stats, active buffs, and run modifiers.
- `res://Character/Common/Buffs/` already supports permanent or temporary stat-changing buffs through `BuffEffect`, `BuffController`, and `StatModifier`.
- `res://Character/Common/character_stats.gd` does not yet expose any stat related to knockback resistance or knockback taken.

## Design Choice

Adopt the buff-driven design ("scheme 3") by introducing a new stat, `knockback_taken_multiplier`, then implement the werebear mechanic as a permanent buff that reduces that multiplier to `0.5`.

This keeps shared lifecycle code generic, makes knockback resistance reusable for future buffs/debuffs, and avoids spreading boss-specific logic into global character code.

## Behavior

### Base Rule

- Every character gets a new stat named `knockback_taken_multiplier`.
- The default value is `1.0`, meaning unchanged knockback.
- Final horizontal knockback becomes:

`KNOCKBACK_VELOCITY * knockback_taken_multiplier`

### Werebear Rule

- The werebear receives a permanent knockback-resistance buff when it enters phase two.
- That buff reduces `knockback_taken_multiplier` to `0.5`.
- Result: the werebear receives 50% of the normal horizontal knockback.

### Scope

- This mechanic begins when the werebear enters phase two and persists for the rest of that life.
- It is tied to the phase-two transition, not to the pre-phase-two state.
- It only changes how much knockback is taken, not the damage, hurt animation, or posture logic.

## Data Model

### New Stat

Add a new stat entry:

- stat id: `knockback_taken_multiplier`
- default/base value: `1.0`

This stat must be reachable through:

- `CharacterStats.get_value()`
- `Character.get_base_stat_value()`
- `Character.get_stat_value()`

No custom special-case lookup path should be introduced.

### New Buff

Create a dedicated permanent buff for the werebear, for example:

- `buff_id = werebear_knockback_resist`
- `stack_key = werebear_knockback_resist`
- display name can be internal-facing
- no icon required
- permanent duration

Its modifier should target:

- `stat_id = knockback_taken_multiplier`
- multiplicative adjustment resulting in final value `0.5`

Given the current modifier system multiplies as `base * (1.0 + value)`, the buff should use:

- value: `-0.5`
- mode: `MULTIPLY`

## Code-Level Changes

### `res://Character/Common/character_stats.gd`

Add the exported base stat:

- `@export var knockback_taken_multiplier := 1.0`

Update `get_value()` so the new stat id resolves correctly.

### `res://Character/Common/character_lifecycle.gd`

Change `on_damaged()` so knockback is calculated from the shared stat pipeline instead of using a fixed multiplier of `1.0`.

Conceptually:

- resolve direction the same way as today
- read `owner.get_stat_value(&"knockback_taken_multiplier", 1.0)`
- apply that multiplier to `owner.KNOCKBACK_VELOCITY`

No werebear name/class checks should appear in this file.

### `res://Character/Common/Buffs/werebear_knockback_resist_buff.gd`

Create the new permanent buff file that contributes:

- one multiplicative modifier for `knockback_taken_multiplier`

This buff should be focused and single-purpose.

### `res://Character/Werebear/werebear.gd`

Apply the permanent knockback-resistance buff when the werebear enters phase two.

This should reuse the existing guarded phase-two transition path so the buff is only added once per life.

## Why This Is Preferred

Compared with a werebear-specific branch inside `character_lifecycle.gd`, this design:

- keeps shared combat code generic
- makes future knockback resistance effects easy to add
- allows future debuffs or phase-based changes to reuse the same stat
- preserves the existing buff architecture as the source of truth for combat modifiers

## Testing Strategy

### Automated

Add focused tests for:

1. `knockback_taken_multiplier` default stat resolves to `1.0`
2. the werebear knockback-resistance buff changes that stat to `0.5`
3. a pre-phase-two werebear still takes normal knockback
4. a phase-two werebear hit by a source receives half the normal `knockback_velocity`

Keep the tests local to the shared stat/buff layer and the werebear behavior layer.

### Runtime Verification

Verify in Godot that:

- the werebear still enters hurt animation when hit
- pre-phase-two knockback remains unchanged
- after entering phase two, the werebear is displaced noticeably less than before
- the werebear is displaced noticeably less than a normal enemy under the same hit
- existing werebear phase-two/enrage/BGM behavior still works

## Risks And Mitigations

- **Risk:** The new stat is added to buffs but not to `CharacterStats.get_value()`.
	- **Mitigation:** include a focused stat-resolution test.
- **Risk:** The multiplier is interpreted incorrectly because current multiply modifiers apply as `base * (1 + value)`.
	- **Mitigation:** explicitly document and test the `-0.5 => 0.5 final multiplier` rule.
- **Risk:** The buff accidentally becomes visible in UI as a player-facing icon.
	- **Mitigation:** keep the buff iconless unless a UI requirement is later introduced.

## Out Of Scope

- Full knockback immunity
- Vertical knockback redesign
- New UI icon or tooltip for boss knockback resistance
