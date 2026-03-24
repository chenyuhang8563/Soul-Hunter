# Role 项目优化清单

> 生成时间: 2026-03-24
> 基于 Godot 4.6 + Jolt Physics 项目代码审查

---

## 优先级分类

| 级别 | 说明 | 修复时机 |
|------|------|----------|
| P0 | 崩溃风险/内存泄漏 | 立即 |
| P1 | 性能瓶颈 | 本周内 |
| P2 | 代码质量 | 迭代中 |
| P3 | 功能完善 | 按需 |
| P4 | 最佳实践 | 可选 |

---

## P0 - 必须立即修复

### 1. 信号连接未断开 (内存泄漏)

**文件**: `Character/Common/character.gd`
**位置**: L82-84
**问题**: health 信号在 `_ready()` 中连接但从未断开

```gdscript
# 问题代码
func _setup_health() -> void:
    health.health_changed.connect(_on_health_changed)
    health.damaged.connect(_on_damaged)
    health.died.connect(_on_died)
```

**修复方案**: 添加 `_exit_tree()` 断开信号

```gdscript
func _exit_tree() -> void:
    if health.health_changed.is_connected(_on_health_changed):
        health.health_changed.disconnect(_on_health_changed)
    if health.damaged.is_connected(_on_damaged):
        health.damaged.disconnect(_on_damaged)
    if health.died.is_connected(_on_died):
        health.died.disconnect(_on_died)
```

---

### 2. SceneManager 信号泄漏

**文件**: `Scenes/level_1.gd`
**位置**: L21
**问题**: 连接 SceneManager.camera_changed 信号但未断开

```gdscript
# 问题代码
func _ready() -> void:
    SceneManager.camera_changed.connect(_on_camera_changed)
```

**修复方案**: 添加 `_exit_tree()` 断开连接

```gdscript
func _exit_tree() -> void:
    if SceneManager.camera_changed.is_connected(_on_camera_changed):
        SceneManager.camera_changed.disconnect(_on_camera_changed)
```

---

### 3. dialogue_ui 信号泄漏和资源未释放

**文件**: `Global/dialogue_manager.gd`
**位置**: L17-18, L62-72
**问题**: 
- 信号连接未断开
- dialogue_ui 被 add_child 但未 remove_child

**修复方案**:

```gdscript
func end_dialogue():
    if dialogue_ui:
        # 断开信号
        if dialogue_ui.dialogue_finished.is_connected(_on_dialogue_ui_finished):
            dialogue_ui.dialogue_finished.disconnect(_on_dialogue_ui_finished)
        if dialogue_ui.option_selected.is_connected(_on_option_selected):
            dialogue_ui.option_selected.disconnect(_on_option_selected)
        dialogue_ui.hide_dialogue()
    
    current_dialogue_data.clear()
    current_node_id = ""
    
    await get_tree().create_timer(0.1).timeout
    get_tree().paused = false
    
    dialogue_ended.emit()
```

---

### 4. 场景切换无错误处理

**文件**: `Global/scene_manager.gd`
**位置**: L25
**问题**: `change_scene_to_file()` 无返回值检查

```gdscript
# 问题代码
get_tree().change_scene_to_file(target_scene_path)
```

**修复方案**:

```gdscript
func change_scene(target_scene_path: String) -> void:
    if is_transitioning:
        return
    
    # 检查场景文件是否存在
    if not ResourceLoader.exists(target_scene_path):
        push_error("Scene file not found: " + target_scene_path)
        is_transitioning = false
        return
    
    is_transitioning = true
    
    animation_player.play("fade_out")
    await animation_player.animation_finished
    
    var error = get_tree().change_scene_to_file(target_scene_path)
    if error != OK:
        push_error("Failed to change scene to: " + target_scene_path)
        is_transitioning = false
        return
    
    await get_tree().process_frame
    
    animation_player.play("fade_in")
    await animation_player.animation_finished
    
    is_transitioning = false
```

---

### 5. Variant 类型反模式

**文件**: `Character/Common/character.gd:35`, `Character/Common/ai_module.gd:10`
**问题**: 使用 `Variant` 类型声明 attack_module，失去类型安全

**修复方案**: 已存在 `attack_module_base.gd`，将其改为 `class_name` 并使用具体类型

```gdscript
# attack_module_base.gd 顶部添加
class_name AttackModuleBase extends RefCounted

# character.gd 修改
var attack_module: AttackModuleBase = null

# ai_module.gd 修改
var attack_module: AttackModuleBase = null
```

---

## P1 - 性能瓶颈

### 6. _process 每帧重复计算

**文件**: `Character/Common/character.gd`
**位置**: L395-407
**问题**: `_check_environment_hazards()` 每帧执行 TileMap 查询

**修复方案**: 添加计时器节流

```gdscript
var _hazard_check_timer := 0.0
const HAZARD_CHECK_INTERVAL := 0.1  # 每0.1秒检查一次

func _process(delta: float) -> void:
    if is_dead:
        return
    
    # 节流：降低环境检测频率
    _hazard_check_timer += delta
    if _hazard_check_timer >= HAZARD_CHECK_INTERVAL:
        _check_environment_hazards()
        _hazard_check_timer = 0.0
    
    _check_fall_death()
    _update_possession_prompt_icon()
    # ...
```

---

### 7. AI 悬崖检测每帧执行

**文件**: `Character/Common/ai_module.gd`
**位置**: L160-180
**问题**: TileMap 悬崖检测每帧执行

**修复方案**: 添加计时器节流

```gdscript
var _cliff_check_timer := 0.0
const CLIFF_CHECK_INTERVAL := 0.15  # 每0.15秒检查一次

func physics_process_ai(delta: float) -> float:
    _sync_target_state()
    # ... 其他逻辑
    
    # 节流：降低悬崖检测频率
    _cliff_check_timer += delta
    var should_check_cliff = _cliff_check_timer >= CLIFF_CHECK_INTERVAL
    
    if input_dir != 0.0 and character.is_on_floor() and should_check_cliff:
        _cliff_check_timer = 0.0
        # ... 悬崖检测逻辑
```

---

### 8. 每帧获取 player_controlled 组

**文件**: `Character/Common/character.gd`
**位置**: L272
**问题**: `_update_possession_prompt_icon()` 每帧调用 `get_tree().get_nodes_in_group()`

**修复方案**: 缓存玩家引用，通过信号更新

```gdscript
var _cached_player: CharacterBody2D = null

func _ready() -> void:
    # ... 原有代码
    _connect_player_cache_signals()

func _connect_player_cache_signals() -> void:
    # 监听场景树变化来更新缓存
    if not get_tree().node_added.is_connected(_on_tree_node_added):
        get_tree().node_added.connect(_on_tree_node_added)
    if not get_tree().node_removed.is_connected(_on_tree_node_removed):
        get_tree().node_removed.connect(_on_tree_node_removed)

func _on_tree_node_added(node: Node) -> void:
    if node is CharacterBody2D and node.is_in_group("player_controlled"):
        _cached_player = node

func _on_tree_node_removed(node: Node) -> void:
    if node == _cached_player:
        _cached_player = null
```

---

### 9. ui_presenter 每次创建新实例

**文件**: `Character/Common/character.gd`
**位置**: L40
**问题**: `var ui_presenter = CharacterUIPresenterScript.new()` 在类级别立即创建

**修复方案**: 延迟创建

```gdscript
var ui_presenter = null  # 延迟创建

func _ready() -> void:
    # ... 
    _ensure_ui_presenter()
    ui_presenter.setup(hp_bar, posture_bar)

func _ensure_ui_presenter() -> void:
    if ui_presenter == null:
        ui_presenter = CharacterUIPresenterScript.new()
```

---

## P2 - 代码质量 (待处理)

| # | 问题 | 文件 | 建议 |
|---|------|------|------|
| 10 | 角色子类重复代码 | soldier/swordsman/slime/orc.gd | 提取到基类 |
| 11 | 硬编码数值 | 多处 | 提取为 const 或 @export |
| 12 | 对话数据内嵌 | level_1.gd:56-84 | 外部化到 JSON |
| 13 | 重复 TileMap 查找 | character.gd, ai_module.gd | 提取工具函数 |
| 14 | 场景路径硬编码 | level_1.gd:31 | 使用 @export_file |

---

## P3 - 功能完善 (策划案要求)

| # | 功能 | 状态 | 建议 |
|---|------|------|------|
| 15 | 灵魂值系统 | 未实现 | 添加 SoulComponent + UI |
| 16 | 连锁附身奖励 | 未实现 | 添加 ComboManager |
| 17 | 弃壳冲击波 | 未实现 | detach_module 添加伤害 |
| 18 | 存档/读档 | 未实现 | 添加 SaveManager |

---

## P4 - 最佳实践 (可选)

| # | 问题 | 建议 |
|---|------|------|
| 19 | 目录名拼写错误 | ✅ 已修复 (Characer → Character) |
| 20 | 组件挂载无编辑器支持 | 使用 @tool 脚本 |
| 21 | 缺少单元测试 | 使用 Gut/GdUnit 框架 |
| 22 | 日志散落各处 | 添加 Logger 单例 |

---

## 修复进度追踪

| 优先级 | 总数 | 已完成 | 状态 |
|--------|------|--------|------|
| P0 | 5 | 5 | ✅ 全部完成 |
| P1 | 4 | 4 | ✅ 全部完成 |
| P2 | 5 | 5 | ✅ 全部完成 |
| P3 | 4 | 0 | 待开始 |
| P4 | 4 | 0 | 待开始 |

**最后更新**: 2026-03-24

### 已完成的修复详情

#### P0 修复 (2026-03-24)
1. **character.gd** - 添加 `_exit_tree()` 断开 health/animation 信号
2. **level_1.gd** - 添加 `_exit_tree()` 断开 SceneManager.camera_changed 信号
3. **dialogue_manager.gd** - 修复信号泄漏，添加断开/重连机制
4. **scene_manager.gd** - 添加 `ResourceLoader.exists()` 场景存在性检查
5. **attack_module_base.gd** - 添加 `class_name AttackModuleBase`
   **detach_module.gd** - 添加 `class_name DetachModule`
   **character.gd** - 将 `Variant` 改为具体类型

#### P1 性能优化 (2026-03-24)
6. **character.gd** - `_process` 添加计时器节流
   - 环境危害检查: 每 0.1 秒
   - 提示图标更新: 每 0.05 秒
7. **ai_module.gd** - 悬崖检测添加节流 (每 0.15 秒)
8. **character.gd** - 添加 `_cached_player` 缓存玩家引用
9. **character.gd** - `ui_presenter` 延迟创建，避免不必要的实例化

#### P2 代码质量优化 (2026-03-24)
10. **character.gd + 子类** - 提取重复代码到基类
    - 新增 `_set_locomotion_conditions()` 通用方法
    - 新增 `_set_scope_monitoring()` 通用方法
    - 新增 `_physics_process_ai_default()` 默认 AI 处理
    - 删除 soldier/swordsman/slime/orc 中的重复函数
11. **character.gd / level_1.gd / ai_module.gd** - 提取硬编码数值为命名常量
    - `KNOCKBACK_VELOCITY = 140.0`
    - `FALL_DEATH_Y = 500.0`
    - `CAM_OFFSET = 9.0`
    - `INTERACTION_DISTANCE = 40.0`
    - `LOOK_AHEAD_DISTANCE = 15.0`
12. **level_1.gd** - 对话数据外部化到 JSON
    - 新增 `Data/Dialogues/archer_dialogue.json`
    - 新增 `Global/dialogue_data_loader.gd` 加载工具
13. **Global/tilemap_utils.gd** - 新建 TileMap 工具函数
    - `TileMapUtils.get_tilemap_from_scene()` 静态方法
    - character.gd 和 ai_module.gd 改用工具函数
14. **level_1.gd / detach_module.gd** - 场景路径使用 @export_file
    - `@export_file("*.tscn") var next_scene_path`
    - Soldier 场景路径改为运行时加载

---

## 相关文档

- [对话系统规范](./dialogue_system/spec.md)
- [对话系统任务](./dialogue_system/tasks.md)
- [策划案](../策划案.md)
