# 修复刺 (Spike) 不生效的问题

## 1. 总结 (Summary)
当前游戏中，尽管在 `TileSet` 中配置了 `is_spike` 标识，但所有角色触碰地刺时都不会死亡。经过排查，问题出在两方面：一是代码无法正确获取到 `TileMapLayer` 节点；二是检测瓦片时使用的坐标不正确，导致检测到了角色身体中心悬空的位置，而非脚底的瓦片。此外，同样的节点获取问题也导致了 AI 的悬崖边缘检测失效。

## 2. 当前状态分析 (Current State Analysis)
1. **节点路径错误**：在 `character.gd` 和 `ai_module.gd` 中，代码使用 `parent.get_node_or_null("TileMapLayer")` 来获取地图层。但在实际场景（如 `level_1.tscn`）中，角色节点通常被放置在 `Characters` 父节点下，而 `TileMapLayer` 被放置在 `Environment` 父节点下。因此，`parent` 并没有 `TileMapLayer` 子节点，导致返回值始终为 `null`，后续伤害判定直接 `return`。
2. **检测坐标偏移错误**：在 `character.gd` 中，检测瓦片使用的是 `global_position`。但角色的 `global_position` 是在身体中心（距离脚底有 10~15 像素左右的距离）。这导致代码将身体中心的坐标转换为地图网格时，往往获取到的是地刺上方为空的格子，而不是地刺本身。
3. **豁免逻辑正常**：`character.gd` 中现有的豁免逻辑 `if self.name.contains("Slime") or self.is_in_group("immune_to_spikes"): return` 是正确的，只需修复上述检测问题即可生效。

## 3. 提议的更改 (Proposed Changes)

### 3.1 修改 `Characer/Common/character.gd`
- **目标函数**：`_check_environment_hazards()`
- **修改内容**：
  1. 替换 `TileMapLayer` 的查找逻辑。从 `get_tree().current_scene` 开始查找，依次尝试获取 `Environment/TileMapLayer` 和 `TileMapLayer`，确保兼容不同的场景结构。
  2. 修正 `foot_position` 的计算方式。给 `global_position.y` 增加一个向下探测的深度偏移（例如 `15.0` 像素），确保获取到的是角色脚底真实踩着的瓦片：
     `var foot_position = global_position + Vector2(0, 15.0)`

### 3.2 修改 `Characer/Common/ai_module.gd`
- **目标函数**：`physics_process_ai()` （约在 154 行前后的悬崖边缘检测逻辑）
- **修改内容**：
  1. 使用与上述相同的方法修复 `TileMapLayer` 的获取逻辑（使用 `character.get_tree().current_scene...` 替代 `parent.get_node_or_null`），以修复 AI 走到悬崖边无法正确停下的潜在问题。

## 4. 假设与决策 (Assumptions & Decisions)
- 假设地刺瓦片主要绘制在名为 `TileMapLayer` 的主地形层上（与现有代码的预设一致）。
- `15.0` 像素的 Y 轴向下偏移量足以覆盖角色中心到脚底地面的距离。参考了 `ai_module.gd` 中现有的 `check_depth = 20.0` 逻辑，`15.0` 是一个合理且安全的探测深度。
- Slime 的节点名称确实包含 `"Slime"`，因此现有的豁免判定无需修改。

## 5. 验证步骤 (Verification Steps)
1. 运行游戏，控制普通角色（如 Soldier, Swordsman, Orc, Archer）走上地刺，验证是否会瞬间死亡（受到 9999.0 伤害）。
2. 控制或观察 Slime 走上地刺，验证 Slime 是否能够免疫地刺伤害正常存活。
3. 观察 AI 敌人在靠近悬崖或地刺时的寻路/移动表现，确保 `TileMapLayer` 获取修复后 AI 不会发生异常。