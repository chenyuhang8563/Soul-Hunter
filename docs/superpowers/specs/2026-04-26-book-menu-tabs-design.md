# Book Menu Tabs Design

## Goal

整理 `BookMenu` 的层级结构，让右侧标签页可以在背包和设置之间切换，并为以后继续扩展装备、天赋、任务等页面预留清晰边界。

本次只实现两个页面状态：

- `BackpackPage`：现有背包页面，显示物品格子。
- `SettingsPage`：占位设置页面，只显示标题 `Settings`，不包含具体设置项。

## Current State

`res://Scenes/UI/book_menu.tscn` 当前已经包含 `Tabs/BackpackTab` 和 `Tabs/SettingsTab`，但背包页面内容仍直接挂在 `BookMenu` 根节点下：

- `TitleLabel`
- `ItemContainer1`
- `ItemContainer2`
- `Divider`
- `PageCorner`

`res://Scenes/UI/book_menu.gd` 当前也把打开书本和显示背包耦合在一起：

- `_set_pages_visible()` 逐个控制背包相关节点。
- `_on_animation_finished()` 固定调用 `_populate_backpack()`。
- 背包容器和标题是根节点级引用，不利于增加新页面。

此外，脚本中的部分节点路径与当前场景层级不一致，需要在实现时一起修正，避免运行时找不到节点。

`res://Scenes/arena.tscn` 只负责把 `BookMenu` 实例挂到 `MenuLayer` 下，并设置暂停时仍可处理输入；这层集成方式不需要调整。

## Design

### 1. Scene Hierarchy

将书本菜单拆成三类节点：书本动画、打开后公共 UI、具体页面内容。

目标层级：

```text
BookMenu
├─ BookSprite
└─ OpenContent
   ├─ PageChrome
   │  ├─ Divider
   │  └─ PageCorner
   │     ├─ PageFoldRight
   │     └─ PageFoldLeft
   ├─ Tabs
   │  ├─ BackpackTab
   │  │  └─ BackPackIcon
   │  └─ SettingsTab
   │     └─ SettingsIcon
   └─ Pages
      ├─ BackpackPage
      │  ├─ TitleLabel
      │  ├─ ItemContainer1
      │  └─ ItemContainer2
      └─ SettingsPage
         └─ TitleLabel
```

`OpenContent` 表示书本打开后才出现的全部 UI。翻书动画播放期间隐藏 `OpenContent`，动画完成后显示。

`PageChrome` 放公共装饰，不属于任何具体页面。`Tabs` 放右侧导航。`Pages` 放互斥页面，当前只包含 `BackpackPage` 和 `SettingsPage`。

### 2. Page Switching

`BookMenu` 维护当前页面状态，建议使用简单字符串或枚举表达：

- `backpack`
- `settings`

打开菜单时默认选择 `backpack`。

点击 `BackpackTab` 时：

- 显示 `Pages/BackpackPage`
- 隐藏 `Pages/SettingsPage`
- 背包标题为 `BackPack`
- 刷新背包物品槽

点击 `SettingsTab` 时：

- 显示 `Pages/SettingsPage`
- 隐藏 `Pages/BackpackPage`
- 设置标题为 `Settings`
- 不刷新背包物品槽

切换标签页不播放翻书动画，也不关闭或重新打开菜单。

### 3. Script Responsibilities

本次可以继续保留单个 `res://Scenes/UI/book_menu.gd`，但职责需要拆清楚：

- `open()` / `close()` / `toggle()`：控制书本开关、暂停状态、翻书动画。
- `_set_open_content_visible(visible)`：控制 `OpenContent` 整体显示隐藏。
- `_select_page(page_id)`：控制 `BackpackPage` 和 `SettingsPage` 互斥显示，并处理页面进入时的刷新。
- `_populate_backpack()`：只服务背包页面。
- `_connect_slot_signals()` / `_on_slot_used()`：只绑定和响应背包物品槽。

暂不拆出 `book_backpack_page.gd` 或 `book_settings_page.gd`。如果后续设置页出现音量、按键、退出等具体控件，再考虑将每个页面拆成独立脚本。

### 4. Tab Visual State

当前需求重点是功能切换。实现时应至少保证按钮点击能切换页面。

如果现有素材已经提供 normal 和 selected 两套 tab 图，可同步更新 tab 的选中视觉状态：

- 当前页 tab 使用 selected 纹理。
- 非当前页 tab 使用 normal 纹理。

如果 TextureButton 的现有 hover/pressed 配置暂不适合 selected 状态，允许先只完成页面切换，后续再单独整理 tab 视觉状态。

### 5. Input And Pause Behavior

保持现有交互语义：

- 按 `Tab` 打开或关闭 BookMenu。
- 打开 BookMenu 时暂停游戏。
- 关闭 BookMenu 时恢复游戏。
- `BookMenu` 在暂停状态下仍能处理输入。

`SettingsTab` 和 `BackpackTab` 点击行为不改变暂停状态。

## Error Handling

- 如果当前页未知，回退到 `BackpackPage`。
- 如果背包数据为空，物品槽继续调用 `clear()`。
- 设置页目前没有动态数据，不需要额外错误处理。
- 切换到设置页时不能调用 `_populate_backpack()`，避免设置页依赖背包节点。

## Testing

优先通过 Godot MCP 或 Gut artifacts 验证，不依赖 `godot.exe` shell log capture。

建议验证点：

- 打开 BookMenu 后默认显示背包页。
- 点击 `SettingsTab` 后只显示设置页，标题为 `Settings`。
- 点击 `BackpackTab` 后恢复背包页，标题为 `BackPack`，物品槽正常刷新。
- 切换页面时书本不重新播放翻书动画。
- 打开和关闭菜单仍正确暂停与恢复游戏。

## Implementation Scope

本次包含：

- 调整 `book_menu.tscn` 中 BookMenu 的页面层级。
- 增加 `SettingsPage` 占位页面。
- 更新 `book_menu.gd` 的节点引用和页面切换逻辑。
- 连接 `BackpackTab` 和 `SettingsTab` 点击事件。

本次不包含：

- 设置页具体功能项。
- 新增装备、天赋、任务页面。
- 修改 `arena.tscn` 的集成方式。
- 重做 BookMenu 美术素材或翻书动画。
- 将页面拆成多个独立脚本。

## Files Expected To Change

- `res://Scenes/UI/book_menu.tscn`
- `res://Scenes/UI/book_menu.gd`

## Open Decisions

当前无未决需求。设置页已确定为占位界面，只显示标题 `Settings`。
