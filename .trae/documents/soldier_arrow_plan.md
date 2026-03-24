# Soldier Arrow & Attack Probability Plan

## Goal
1. Modify Swordsman and Soldier AI attack probabilities to **50% Light / 30% Hard / 20% Ultimate**.
2. Implement functional arrow shooting for the Soldier's Ultimate Attack using the existing `arrow.tscn`.

## Current State
- **Swordsman**: Probabilities are 60/30/10.
- **Soldier**: Probabilities are 60/30/10. Ultimate attack applies instant melee damage via `_queue_damage_event`.
- **Arrow**: `Scenes/arrow.tscn` exists as a `Node2D` with a `Sprite2D`, but lacks collision logic and scripts.
- **Orc**: Probabilities are 60/40 (will remain unchanged as it lacks Ultimate).

## Proposed Changes

### 1. Update Attack Probabilities
- **File**: `Characer/Common/swordsman_attack_module.gd`
  - Adjust `start_ai_attack` probabilities:
    - Light: `< 0.5` (50%)
    - Hard: `< 0.8` (30%)
    - Ultimate: `else` (20%)
- **File**: `Characer/Common/soldier_attack_module.gd`
  - Adjust `start_ai_attack` probabilities similarly (50/30/20).

### 2. Implement Arrow Logic
- **File**: `Scenes/arrow.gd` (Create new)
  - Extends `Node2D` (or `Area2D` if root changes, but keeping `Node2D` root is fine).
  - Properties: `speed`, `damage`, `direction`, `shooter` (owner).
  - Methods:
    - `_process`: Move arrow based on direction and speed.
    - `_on_body_entered`: Detect collision with enemies.
    - `setup`: Initialize properties.
- **File**: `Scenes/arrow.tscn`
  - Add `Area2D` child with `CollisionShape2D` (Circle/Rectangle).
  - Attach `Scenes/arrow.gd`.
  - Connect `body_entered` signal.

### 3. Update Soldier Attack Module
- **File**: `Characer/Common/soldier_attack_module.gd`
  - Preload `arrow.tscn`.
  - Override `_try_apply_damage_event`:
    - Check if `current_attack` is `"ultimate_attack"`.
    - If so, instance `Arrow` scene.
    - Set arrow position to Soldier's position (plus offset).
    - Set arrow direction based on Soldier's facing or target direction.
    - Add arrow to the scene tree (e.g., `owner.get_parent().add_child(arrow)`).
    - Return early (do not apply immediate damage).
    - If not ultimate, call `super._try_apply_damage_event(event)`.

## Verification
- **Swordsman/Soldier AI**: Observe attack frequency in a test scene to confirm 50/30/20 distribution.
- **Soldier Shooting**:
  - Trigger Ultimate Attack (or wait for AI).
  - Confirm arrow spawns at correct time.
  - Confirm arrow flies in facing direction.
  - Confirm arrow damages targets upon collision and destroys itself.
