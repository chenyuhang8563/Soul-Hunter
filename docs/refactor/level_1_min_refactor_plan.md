# Level 1 最小可行重构方案

## 目标

本轮重构只解决以下 3 件事：

1. 让 `Scenes/level_1.gd` 成为真正的关卡流程控制器
2. 让“弓箭手对话 -> 开箱拿钥匙 -> 开门 -> 到达出口”形成明确链路
3. 给玩家补上足够的目标提示和基础流程反馈

默认假设：

- 保留现有战斗、附身、脱离手感不改
- 不重做对话系统，只在关卡层接入
- 不增加新资源图，优先复用现有 UI 和场景节点
- 不做“门后遮罩”相关改造

## 方案总览

建议把 `level_1` 重构成一个轻量状态机，中心逻辑放在 `Scenes/level_1.gd`，环境对象通过信号回传事件。

推荐状态枚举：

```gdscript
enum LevelState {
	INTRO,
	TALKING_TO_ARCHER,
	FIND_KEY,
	DOOR_OPENING,
	REACH_EXIT,
	COMPLETED
}
```

推荐流程：

1. 开场进入 `INTRO`
2. 玩家可以自由探索，也可以靠近弓箭手并对话，进入 `TALKING_TO_ARCHER`
3. 对话结束后如果还未拿到钥匙，则切到 `FIND_KEY`
4. 拿到钥匙后触发开门，进入 `DOOR_OPENING`
5. 门开后切到 `REACH_EXIT`
6. 玩家进入终点区后切到 `COMPLETED`，再调用 `SceneManager.change_scene()`

## 具体改动

### 1. 改 `Scenes/level_1.gd`

这里是第一优先级，建议新增以下内容：

- `LevelState` 枚举和 `current_state`
- `_set_level_state(next_state)`，统一处理状态切换
- `_update_objective_text()`，同步 UI 提示
- `_can_start_archer_dialogue()`，避免重复触发对话
- `_on_archer_dialogue_ended()`，把对话结束映射到关卡状态推进
- `_on_key_collected()`，从钥匙事件推进到开门状态
- `_on_door_opened()`，解锁出口和相机边界
- `_can_finish_level(body)`，只允许合法玩家进入终点后过关

建议新增变量：

```gdscript
var current_state: LevelState = LevelState.INTRO
var has_archer_dialogue_finished := false
var has_key := false
var is_exit_unlocked := false
```

建议方法骨架：

```gdscript
func _set_level_state(next_state: LevelState) -> void:
	if current_state == next_state:
		return
	current_state = next_state
	_update_objective_text()
	_apply_state_side_effects()

func _apply_state_side_effects() -> void:
	match current_state:
		LevelState.INTRO:
			_lock_exit()
		LevelState.FIND_KEY:
			pass
		LevelState.DOOR_OPENING:
			pass
		LevelState.REACH_EXIT:
			_unlock_exit()
```

建议保留当前 `_process` 中基于距离的弓箭手交互作为过渡版本，但加上状态保护：

- 只要当前不在对话中，就允许触发弓箭手对话
- 对话进行中不再接受重复交互
- 门没开时，即使进入 `LevelFinishArea` 也不切场景

### 2. 改 `Scenes/level_1.tscn`

场景层建议补 2 类节点：

新增一个目标提示节点：

- `UI/ObjectiveLabel`
- 用来显示“与 Archer 交谈”“找到钥匙”“前往出口”等当前目标

新增一个弓箭手交互触发区：

- 例如 `Characters/Archer/InteractionArea`
- 类型 `Area2D + CollisionShape2D`
- 先不强制把逻辑全搬过去，但为后续从 `_process + distance_to` 升级到触发式交互埋好结构

这样后续继续扩关时，`level_1.gd` 不需要继续堆更多硬编码距离判断。

### 3. 小改 `Environment/scenes_key.gd`

这部分建议从“直接广播开门”改成“先发关卡事件”。

当前拾取钥匙后直接执行：

```gdscript
get_tree().call_group("doors", "open_door")
```

建议新增信号：

```gdscript
signal key_collected
```

在 `pick_up()` 里先发出 `key_collected.emit()`，再由 `Scenes/level_1.gd` 决定是否开门、开哪扇门。

如果需要兼容旧逻辑，可以保留一版过渡行为，但推荐最终由关卡控制器接管。

### 4. 小改 `Environment/scene_door.gd`

这个脚本已经有 `door_opened` 信号，基础不错。建议补两个保护：

- 增加 `is_opening` 或 `is_opened`，避免重复调用 `open_door()`
- 开门完成后不要立刻 `queue_free()`，改为保留门节点，只关闭碰撞

更稳的行为建议：

1. 播放开门动画
2. 禁用碰撞
3. 保留门节点
4. 发出“开门完成”信号给 `level_1`

### 5. `Environment/chests.gd` 暂不做前置门禁

本轮不把“先对话”作为“先开箱”的前置条件，也不在箱子上加锁。

原因：

- 玩家自由探索优先，不把对话做成强制门槛
- “先对话再开箱”不属于当前版本的真实需求
- 只要关卡状态机能正确处理“先拿钥匙、后对话”这种顺序，就不会出现软锁

因此这里不新增对话前置交互限制，只保留现有开箱逻辑。

## 推荐的关卡联动方式

本轮推荐由 `Scenes/level_1.gd` 在 `_ready()` 中统一连接这些信号：

- `DialogueManager.dialogue_ended` 根据当前进度更新状态
- `ScenesKey.key_collected` 推进到 `DOOR_OPENING`
- `SceneDoor.door_opened` 推进到 `REACH_EXIT`
- `LevelFinishArea.body_entered` 在 `REACH_EXIT` 状态下才允许通关

建议连接关系：

```gdscript
DialogueManager.dialogue_ended.connect(_on_archer_dialogue_ended)
key.key_collected.connect(_on_key_collected)
door.door_opened.connect(_on_door_opened)
level_finish_area.body_entered.connect(_on_level_finish_area_body_entered)
```

建议状态推进规则：

- 若玩家先对话再拿钥匙：对话后进入 `FIND_KEY`，拿钥匙后开门
- 若玩家先拿钥匙再对话：拿钥匙后直接开门；对话结束时只更新目标或补充叙事，不阻断通关
- 若玩家全程不对话：只要已经拿到钥匙、门已打开、到达出口，依然允许正常通关

## UI 与反馈

第一轮只做最小反馈，不上复杂 HUD。

建议目标文本如下：

- `INTRO`: `探索前方区域`
- `TALKING_TO_ARCHER`: `聆听 Archer 的建议`
- `FIND_KEY`: `找到钥匙`
- `DOOR_OPENING`: `门已开启`
- `REACH_EXIT`: `前往出口`
- `COMPLETED`: `关卡完成`

补充两类流程反馈：

- 门未开时，出口不可触发
- 开门后放宽当前玩家相机的 `limit_right`，让玩家明确知道前路已开放

## 实现顺序

建议按以下顺序落地：

1. 先改 `Scenes/level_1.gd`，加状态机和目标文本逻辑
2. 再改 `Scenes/level_1.tscn`，补 `ObjectiveLabel` 和交互触发区
3. 再改 `Environment/scenes_key.gd`，把拾取行为改成信号驱动
4. 最后改 `Environment/scene_door.gd`，补状态保护

## 验收标准

做到下面这些，这轮就算成功：

- 开局时出口不可用
- 玩家可以不对话先探索和开箱
- 对话后目标文本会根据当前进度正确更新
- 拿到钥匙后门打开
- 门开后目标文本更新为前往出口
- 玩家进入终点区时才切场景
- 重复按 `E`、重复拾取、重复开门，以及“先拿钥匙后对话”都不会把流程搞乱
