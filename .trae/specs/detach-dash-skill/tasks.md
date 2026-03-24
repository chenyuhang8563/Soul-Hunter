# Tasks

- [x] Task 1: Setup Input Map
  - [x] SubTask 1.1: 打开 Godot 项目配置，检查并确保 `R` 键未被占用。
  - [x] SubTask 1.2: 添加新的 Input Action `detach`，并绑定到 `R` 键。

- [x] Task 2: Create ArrowPointer Node
  - [x] SubTask 2.1: 在 `Characer/Common/` 下创建 `arrow_pointer.gd`，继承自 `Node2D`。
  - [x] SubTask 2.2: 使用 `_draw()` 方法绘制一个长度约 40px 的像素风格箭头，确保箭头指向节点的旋转方向（`rotation`）。

- [x] Task 3: Create DetachModule
  - [x] SubTask 3.1: 在 `Characer/Common/` 下创建 `detach_module.gd` 脚本，用于解耦核心逻辑。
  - [x] SubTask 3.2: 实现状态机管理（未激活、瞄准中）。在瞄准状态下：禁用宿主的移动（修改宿主的速度或状态），设置 `Engine.time_scale = 0.1`（子弹时间），并实例化 `ArrowPointer` 显示方向。
  - [x] SubTask 3.3: 监听方向键输入，动态更新 `ArrowPointer` 的旋转角度。
  - [x] SubTask 3.4: 计时器逻辑（不受 time_scale 影响）：记录开始按下的真实时间，如果达到 3 秒或者玩家松开 `R` 键，触发脱离执行逻辑。

- [x] Task 4: Execute Detach & Dash Logic
  - [x] SubTask 4.1: 在 `detach_module.gd` 的执行逻辑中：恢复 `Engine.time_scale = 1.0`。
  - [x] SubTask 4.2: 加载 `res://Characer/Soldier/soldier.tscn`，在当前坐标实例化。
  - [x] SubTask 4.3: 为新生成的 Soldier 提供一个初始的 Dash 速度（基于最后的箭头方向），并将其设置为玩家控制（`set_player_controlled(true)`）。
  - [x] SubTask 4.4: 当前的宿主角色调用死亡逻辑（如 `consume_for_possession()`）销毁或进入死亡状态。

- [x] Task 5: Integrate with Character
  - [x] SubTask 5.1: 在 `character.gd` 中实例化 `DetachModule`，并在 `_physics_process_player` 中调用其 `update(delta)`。
  - [x] SubTask 5.2: 增加判定条件：只有在当前角色不是原生 Soldier（例如判断类名或场景名）且处于被玩家控制状态时，才允许模块工作。

# Task Dependencies
- Task 3 depends on Task 2 (ArrowPointer needs to be ready for visual feedback).
- Task 4 depends on Task 3 (Execution logic is part of the module).
- Task 5 depends on Task 3 and Task 4 (Integration is the final step).
