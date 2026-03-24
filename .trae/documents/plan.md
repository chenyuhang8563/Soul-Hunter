# 拼刀系统 (Clash System) 实现方案

## 1. 方案摘要

基于您选择的\*\*“弹反窗口触发”**、**“先手优势”**以及**“包含特效、音效和顿帧”**，本方案将实现一个动作感强烈的拼刀系统。
当角色A的攻击即将命中角色B时，如果角色B也正在发起攻击，且处于攻击的**弹反窗口（前摇阶段）**内，则触发“拼刀”。
触发拼刀后，根据**先手优势\*\*，先命中方（A）的攻击不会被中断，而是打断防守方（B）的当前攻击；但防守方（B）将**免受此次伤害**，仅进入受击硬直（模拟被武器弹开的效果）。同时触发强烈的视觉火花、金属碰撞音效以及全局顿帧（Hitstop）。

## 2. 当前代码状态分析

* 所有的攻击伤害目前由 `attack_module_base.gd` 中的 `_try_apply_damage_event` 方法统一分发和处理。

* `_try_apply_damage_event` 目前只检查目标是否有效（`_is_valid_damage_target`），然后直接调用 `target.apply_damage()`。

* 角色状态（受击、死亡）由 `character.gd` 和其子类管理。`_on_damaged` 方法负责播放受击动画和进入硬直状态。

* 目前缺少“弹反窗口”的概念，也缺少时间缩放（顿帧）和特效生成的通用机制。

## 3. 具体修改步骤

### 3.1 增加弹反窗口 (Parry Window) 机制

**文件**: `Characer/Common/attack_module_base.gd`

* **新增变量**: `var parry_window_duration := 0.20`（攻击前摇的0.2秒内为弹反窗口）。

* **新增方法**: `is_in_parry_window() -> bool`。

  * 判断逻辑：`is_attacking() and (attack_duration - attack_time_left) <= parry_window_duration`。

### 3.2 拦截伤害并触发拼刀

**文件**: `Characer/Common/attack_module_base.gd`

* **修改** `_try_apply_damage_event` 方法：

  * 在找到 `hit_target` 后，不再直接造成伤害，而是先调用 `_check_clash(hit_target)` 判断是否触发拼刀。

  * 如果触发拼刀，调用 `_handle_clash(hit_target)`。

  * 否则，正常调用 `_apply_damage_to_target(hit_target, damage)`。

* **新增** `_check_clash(target: CharacterBody2D) -> bool`：

  * 检查 `target` 是否拥有 `attack_module`。

  * 检查 `target` 是否面向攻击者（背刺无法拼刀）。

  * 检查 `target.attack_module.is_in_parry_window()` 是否为 `true`。

* **新增** `_handle_clash(target: CharacterBody2D) -> void`：

  * **打断对方**：调用 `target.attack_module.force_stop()` 强制停止对方的攻击模块。

  * **免伤受击**：直接调用 `target._on_damaged(0, target.health.current_health, target.health.max_health, owner)`，使对方进入受击动画和硬直，但不扣除生命值。

  * **触发表现**：计算两者的中心点坐标，调用全局/局部的表现函数生成特效和顿帧。

### 3.3 实现拼刀表现 (Hitstop, 特效, 音效)

**文件**: `Characer/Common/attack_module_base.gd` (或新建独立的 `combat_utils.gd` 脚本，视项目结构而定，为简单起见可直接在 AttackModuleBase 中实现)

* **顿帧 (Hitstop)**：

  * 将 `Engine.time_scale` 设置为 `0.1`（游戏速度降至10%）。

  * 使用 `get_tree().create_timer(0.1, true, false, true)` 创建一个**不受时间缩放影响**的定时器。

  * 定时器结束后，将 `Engine.time_scale` 恢复为 `1.0`。

* **特效与音效 (VFX & SFX)**：

  * 在两人坐标的中间位置动态生成一个 `Node2D`。

  * 挂载 `GPUParticles2D`（发射火花粒子）和 `AudioStreamPlayer2D`（播放“叮”的打铁音效）。

  * 绑定 `finished` 信号，在播放完毕后自动 `queue_free()` 销毁该节点。

## 4. 假设与决定

* **先手优势逻辑确认**：当前设计为“A的攻击判定先发生，B刚好处于起手阶段，A的武器压制了B的武器。B被打断并进入硬直，但由于武器格挡，B不掉血”。这符合您选择的“先判定命中的一方占据优势”。

* **通用性**：该机制直接实现在 `attack_module_base.gd` 中，因此不管是玩家（Swordsman）、杂兵（Soldier）还是兽人（Orc），只要它们互相攻击并满足条件，都可以触发拼刀。

* **资源**：特效和音效将使用代码动态生成的简单粒子（如黄色火花）和基础音效。后续您可以替换为您自己制作的高级预制体 (Scene)。

## 5. 验证步骤

1. 运行游戏，控制玩家（Swordsman）靠近敌人（Soldier 或 Orc）。
2. 在敌人抬手准备攻击的瞬间（前0.2秒内），玩家按下攻击键并先一步命中敌人。
3. 观察是否发生以下现象：

   * 画面短暂卡顿（顿帧）。

   * 两人中间爆出火花并伴有音效。

   * 敌人当前的攻击动作被打断，进入后仰/受击状态，但其头顶血条没有减少。
4. 反之亦然，如果玩家在抬手时被敌人先命中，玩家应该触发拼刀免伤并被打断。

