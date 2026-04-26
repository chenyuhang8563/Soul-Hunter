# Book Menu Settings And Audio Design

## Goal

把旧暂停菜单的功能迁移到 `BookMenu` 的 `SettingsPage`，并在设置页加入两条运行时音量控制：背景音乐和音效。实现完成后，旧的 `PauseUI` 不再参与 arena 场景。

本需求只定义 Settings 页面和音频总线迁移，不改变背包页面逻辑。

## Current State

### BookMenu

`res://Scenes/UI/book_menu.tscn` 已经有书本式菜单结构：

- `OpenContent/Tabs/BackpackTab`
- `OpenContent/Tabs/SettingsTab`
- `OpenContent/Pages/BackpackPage`
- `OpenContent/Pages/SettingsPage`

`SettingsPage` 当前还是占位页面，只包含标题和分隔线。`BookMenu` 当前通过 `Tab` 键打开并暂停游戏，通过标签页动画在背包和设置之间切换。

### Old PauseUI

旧暂停菜单由 `res://Scenes/UI/pause_ui.tscn` 和 `res://Scenes/UI/pause_ui.gd` 实现，并在 `res://Scenes/arena.tscn` 根节点下实例化。

旧功能包括：

- 监听 `pause` 输入动作。
- 暂停游戏并显示遮罩面板。
- `ResumeButton`：恢复游戏。
- `QuitButton`：退出游戏。
- 暂停时调用 `AudioManager.set_bgm_pause_blur(true)`，恢复时调用 `false`。

旧 `PauseUI` 没有保存功能。

### Audio

`res://Global/audio_manager.gd` 当前负责：

- 播放普通战斗音乐：`res://Assets/SFX/battle.wav`
- 播放 boss 战音乐：`res://Assets/SFX/boss_fight.wav`
- 播放挥砍/碰撞/砍肉音效：`sword_swing`、`sword_clash`、`hit_flesh`
- 创建或查找 `BGM` 总线。
- 将部分音效发往 `SFX_Battle`，默认回退到 `SFX`。

`res://Resources/default_bus_layout.tres` 当前只有：

- `SFX`
- `SFX_Battle`，发送到 `SFX`

需求要求简化为两条总线：

- `BGM`
- `SFX`

不再区分 `SFX` 和 `SFX_Battle`。

## Design

### 1. SettingsPage 内容

`SettingsPage` 替代旧暂停菜单，显示在书本右侧/设置页内，不再使用旧的全屏 `PausePanel`。

建议节点结构：

```text
SettingsPage
├─ TitleLabel              # text = "Settings"
├─ Divider
├─ Actions
│  ├─ ContinueButton       # text = "继续"
│  ├─ SaveButton           # text = "保存"
│  └─ QuitButton           # text = "退出"
└─ AudioSettings
   ├─ BgmLabel             # text = "背景音乐"
   ├─ BgmSlider
   ├─ SfxLabel             # text = "音效"
   └─ SfxSlider
```

具体布局以当前书页可用区域为准，避免遮挡右侧标签页和书页折角。按钮和滑条都放在 `SettingsPage` 内，页面切换动画期间沿用已有规则：翻页开始前清空页面内容，动画结束后显示目标页面。

### 2. Text And Font

中文文本统一使用 `res://Resources/cn.tres`：

- 字体大小：8px，沿用 `cn.tres` 中的 `font_size = 8`。
- 需要使用中文的文本：`继续`、`保存`、`退出`、`背景音乐`、`音效`。
- `Settings` 标题可以继续使用当前英文标题和现有标题字体，除非实现时发现视觉不一致，再统一为中文 `设置`。本次默认保留 `Settings`，避免改变 tab 需求中已确定的标题文案。

### 3. Buttons

Settings 页面需要实现旧暂停菜单的实际功能：

- `ContinueButton`：关闭 BookMenu，恢复游戏。
- `SaveButton`：暂不实现保存，点击后无行为，不报错、不关闭菜单。
- `QuitButton`：退出游戏，等价于旧 `PauseUI.quit_game()` 的 `get_tree().quit()`。

`ContinueButton` 恢复游戏时也需要取消 BGM 暂停模糊效果，即调用 `AudioManager.set_bgm_pause_blur(false)`。

### 4. Input And Pause Behavior

移除旧 `PauseUI` 后，`BookMenu` 需要接管暂停入口：

- 按 `Tab`：继续打开/关闭 BookMenu。
- 按 `pause` 输入动作：打开/关闭 BookMenu，替代旧 PauseUI。
- 打开 BookMenu 时：`get_tree().paused = true`，并调用 `AudioManager.set_bgm_pause_blur(true)`。
- 关闭 BookMenu 或点击 `继续` 时：`get_tree().paused = false`，并调用 `AudioManager.set_bgm_pause_blur(false)`。
- BookMenu 在暂停状态下仍需处理输入和按钮点击，保持 `process_mode = 3`。

如果 BookMenu 已经打开并处于翻页动画中，暂停/Tab 关闭行为可以立即关闭菜单，不需要等待翻页动画结束。

### 5. Audio Sliders

设置页新增两条滑动条：

- `BgmSlider` 控制 `BGM` 总线音量。
- `SfxSlider` 控制 `SFX` 总线音量。

滑动条素材：

- 背景/槽：`res://Assets/Sprites/UI/BookMenu/Slider01_Box.png`
- 前景/进度条：`res://Assets/Sprites/UI/BookMenu/Slider02_Bar04.png`

两个素材当前尺寸均为 `48x16`。实现时可用 `TextureProgressBar`、`HSlider` 搭配自定义样式，或自定义 `Control` 组合；需求层面只要求视觉使用这两张素材，并能拖动改变音量。

推荐交互规则：

- 滑条值范围：`0.0` 到 `1.0`。
- 默认值：读取当前对应总线音量并转换为线性值。
- 拖动时立即更新对应总线。
- `0.0` 表示静音，建议设置为 `-80.0 dB`。
- `1.0` 表示原始音量，设置为 `0.0 dB`。
- 中间值使用 Godot 的 `linear_to_db(value)`。

本次不要求把音量写入存档或配置文件；音量只需要在本次运行期间生效。后续如果实现保存功能，再把音量持久化纳入保存系统。

### 6. Audio Bus Migration

`res://Resources/default_bus_layout.tres` 需要体现最终总线结构：

- `Master`
- `BGM`，发送到 `Master`
- `SFX`，发送到 `Master`

移除 `SFX_Battle`。

`res://Global/audio_manager.gd` 需要按新规则工作：

- 普通战斗音乐 `battle.wav` 属于 `BGM`。
- boss 战音乐 `boss_fight.wav` 属于 `BGM`。
- `sword_swing`、`sword_clash`、`hit_flesh` 全部属于 `SFX`。
- `_get_sound_bus()` 不再返回 `SFX_Battle`。
- `BGM` 总线应优先来自 `default_bus_layout.tres`；如果运行时找不到，仍可保留当前自动创建兜底逻辑。
- `set_bgm_pause_blur()` 继续只作用于 `BGM` 总线，不影响 `SFX`。

建议新增或整理 AudioManager API：

```gdscript
func set_bus_volume_linear(bus_name: StringName, value: float) -> void
func get_bus_volume_linear(bus_name: StringName) -> float
func get_bgm_volume_linear() -> float
func set_bgm_volume_linear(value: float) -> void
func get_sfx_volume_linear() -> float
func set_sfx_volume_linear(value: float) -> void
```

Settings 页面只调用公开 API，不直接散落 `AudioServer` 操作。这样后续保存音量时只需要改 AudioManager。

### 7. Remove Old Pause Menu

实现完成后，旧暂停菜单从 arena 集成中移除：

- `res://Scenes/arena.tscn` 不再实例化 `PauseUI`。
- `res://Scenes/arena.tscn` 不再需要 `pause_ui.tscn` 的 ext_resource。
- `res://Scenes/UI/pause_ui.tscn` 和 `res://Scenes/UI/pause_ui.gd` 可以删除，前提是全项目没有其他场景引用它们。

删除前需要搜索确认没有其他引用。若存在测试或临时场景引用，先迁移引用到 BookMenu 或移除对应旧引用。

## Error Handling

- 如果找不到 `AudioManager`，Settings 页面仍然显示；滑条拖动不报错，但不会改变音量。
- 如果找不到 `BGM` 或 `SFX` 总线，AudioManager 需要创建兜底总线或安全忽略，并发出 warning。
- SaveButton 当前无行为，不弹错误、不打印误导性保存成功信息。
- 点击 Continue 时，如果 BookMenu 已经关闭，不应报错。
- 切换页面动画期间点击 Settings 内按钮不可触发，因为页面内容已经隐藏。

## Testing

优先使用 Gut artifacts 或 Godot MCP，不依赖 `godot.exe` shell log capture。

建议测试覆盖：

- SettingsPage 存在 `ContinueButton`、`SaveButton`、`QuitButton`、`BgmSlider`、`SfxSlider`。
- `ContinueButton` 调用后 BookMenu 关闭，`get_tree().paused == false`。
- `SaveButton` 点击后不关闭菜单，不退出游戏，不报错。
- BGM slider 改变 `BGM` 总线音量。
- SFX slider 改变 `SFX` 总线音量。
- `AudioManager._get_sound_bus("sword_swing")`、`sword_clash`、`hit_flesh` 都返回 `SFX`。
- `AudioManager.play_default_bgm()` 和 Werebear boss BGM 都使用 `BGM` 总线。
- `default_bus_layout.tres` 包含 `BGM` 和 `SFX`，不包含 `SFX_Battle`。
- `arena.tscn` 不再实例化 `PauseUI`。

## Implementation Scope

本次包含：

- 完善 `BookMenu` 的 `SettingsPage` UI。
- 迁移旧 PauseUI 的继续/退出功能到 SettingsPage。
- 添加 SaveButton 占位行为。
- 添加 BGM/SFX 两条音量滑条。
- 使用 `cn.tres` 的 8px 中文字体显示中文控件文本。
- 将音频总线简化为 `BGM` 和 `SFX`。
- 更新 `AudioManager` 中 SFX 路由。
- 从 arena 场景中移除旧 PauseUI。
- 删除旧 PauseUI 场景和脚本，前提是无其他引用。
- 增加或更新对应测试。

本次不包含：

- 真正保存游戏。
- 持久化音量设置。
- 新增更多设置项，例如分辨率、全屏、语言、按键绑定。
- 重做 BookMenu 标签页、背包页或翻页动画。
- 改变普通战斗音乐和 boss 战音乐的触发时机。

## Files Expected To Change

- `res://Scenes/UI/book_menu.tscn`
- `res://Scenes/UI/book_menu.gd`
- `res://Global/audio_manager.gd`
- `res://Resources/default_bus_layout.tres`
- `res://Scenes/arena.tscn`
- `res://Scenes/UI/pause_ui.tscn`，删除或移除引用后删除
- `res://Scenes/UI/pause_ui.gd`，删除或移除引用后删除
- `res://tests/test_book_menu_tabs.gd` 或新的 Settings/Audio 测试文件

## Open Decisions

当前无未决需求。SaveButton 明确为占位无行为；音量不持久化；音频总线统一为 `BGM` 和 `SFX`。
