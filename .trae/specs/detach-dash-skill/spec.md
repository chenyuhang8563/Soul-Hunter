# Detach Dash Skill Spec

## Why
玩家在附身敌人后，需要一种主动脱离当前附身躯体（变回原初 Soldier）并进行位移（Dash）的机制。这样不仅增加了玩法的灵活性和操作上限，还能让玩家在战斗中利用子弹时间（时间缓速）进行精准的策略转移。

## What Changes
- 添加新按键绑定 `detach`，默认绑定为 `R` 键。
- 创建 `DetachModule` 模块，用于处理脱离技能的状态机、时间缓速、倒计时以及生成新 Soldier 等核心逻辑。
- 创建 `ArrowPointer` 节点/脚本，用于在时间缓速期间，根据玩家的输入方向绘制一个小巧的像素风格箭头（长度约40px）。
- 在 `character.gd` 中引入 `DetachModule`。当角色处于被玩家控制状态且**非原初 Soldier**时，允许触发该技能。
- 修改/新增 Soldier 冲刺逻辑：当 Soldier 作为脱离产物生成时，会获得一个瞬间的高速 Dash（基于玩家在时间缓速期间所指的方向）。
- **BREAKING**: 原有的附身目标在玩家脱离后将会死亡。

## Impact
- Affected specs: 玩家控制系统、时间缩放系统、技能模块。
- Affected code:
  - `Characer/Common/character.gd` (集成脱离检测逻辑)
  - `Characer/Soldier/soldier.gd` (增加初始 Dash 逻辑的支持)
  - 新增 `Characer/Common/detach_module.gd`
  - 新增 `Characer/Common/arrow_pointer.gd`

## ADDED Requirements
### Requirement: Detach Aiming (Bullet Time)
The system SHALL provide a time-slowdown aiming state when the player holds 'R'.
#### Scenario: Success case
- **WHEN** 玩家按下并保持 `R` 键。
- **THEN** 游戏进入时间缓速（`Engine.time_scale` 降低），禁用玩家控制的角色移动，角色周围出现一个长度为 40px 的像素风格箭头，箭头方向随玩家的上下左右输入而实时改变。

### Requirement: Execute Detach & Dash
The system SHALL spawn a Soldier and make it dash when aiming is confirmed or times out.
#### Scenario: Success case
- **WHEN** 玩家松开 `R` 键，或保持 `R` 键满 3 秒（真实时间）。
- **THEN** 时间流速恢复正常。当前的附身躯体死亡（调用类似 `consume_for_possession` 或受到致死伤害）。在当前位置生成一个新的 Soldier 并将控制权转移给它。新的 Soldier 将朝箭头指示的方向执行一段 Dash 位移。

## MODIFIED Requirements
### Requirement: Soldier Base Constraint
- 原初的 Soldier 不允许使用脱离技能（只有在附身了其他敌人后才能脱离）。
