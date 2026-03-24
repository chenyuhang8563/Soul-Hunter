# Level 1 Door Transition & Room Masking Plan

## 1. 关卡跳转逻辑 (Level Transition)
- **目标**：玩家进入开启的门后跳转到下一关。
- **实现步骤**：
  1. 在 `scene_door.tscn` 中添加一个 `Area2D`（命名为 `TransitionArea`）和对应的 `CollisionShape2D`，放置在门的位置。
  2. 在 `scene_door.gd` 中添加 `@export var next_scene_path: String = ""`，允许在编辑器中为每个门配置不同的下一关路径。
  3. 初始状态下禁用 `TransitionArea` 的碰撞检测，防止门未打开时提前触发跳转。
  4. 当调用 `open_door()` 时，启用 `TransitionArea` 的碰撞检测。
  5. 监听 `TransitionArea` 的 `body_entered` 信号，当检测到玩家（处于 `player_controlled` 组）进入时，调用 `get_tree().change_scene_to_file(next_scene_path)` 进行场景切换。

## 2. 隐藏门后场景 (Visual Masking / Fog of War)
- **目标**：在门打开前，门后的场景被黑色遮挡，玩家无法看见；门打开时，黑色遮挡平滑消失。
- **实现步骤**：
  1. 在 `scene_door.gd` 中新增自定义信号 `signal door_opened`，并在 `open_door()` 被调用时发出该信号。
  2. 在 `level_1.tscn` 中，门后的区域上方添加一个纯黑色的 `ColorRect` 节点（调整图层层级以覆盖地图和敌人）。
  3. 在关卡的脚本（如 `level_1.gd`）中，在 `_ready()` 阶段将 `ColorRect` 的初始透明度设为不透明。
  4. 将门的 `door_opened` 信号连接到关卡脚本的响应函数。
  5. 在响应函数中，使用 `Tween` 动画将 `ColorRect` 的 `modulate:a`（透明度）在 0.5 秒内渐变到 0.0，并在渐变完成后销毁该遮罩节点，以实现平滑的“揭开”效果。

  测试git