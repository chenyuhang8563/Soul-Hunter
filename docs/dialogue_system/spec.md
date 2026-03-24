# Dialogue System Specification

## 1. 概述 (Overview)
本模块旨在实现一个完整的游戏对话系统，支持显示角色头像、角色名称、对话文本（带打字机效果）、进度指示器（右下角箭头），以及带分支的选择项（右上角选项）。

## 2. 核心功能需求 (Core Features)
### 2.1 界面元素 (UI Elements)
- **Avatar (头像)**：展示当前说话角色的头像。
- **Name (名字)**：展示当前说话角色的名称。
- **Text (对话文本)**：逐步显示的对话内容（打字机效果）。
- **Next Indicator (向下小箭头)**：位于对话框右下角，当单句文本显示完毕时出现并带有简单的上下浮动提示动画。
- **Options (选项)**：位于对话框右上角，当该段对话存在分支选择时显示。

### 2.2 交互逻辑 (Interaction Logic)
- **推进对话**：
  - 点击对话框本体或按下 `Space` 键（或其他确认键，如 `Enter`）。
  - 如果文本正在进行“打字机”播放，触发推进操作会**立即显示全部文本**。
  - 如果文本已全显且无选项，触发推进操作会**进入下一句对话**或结束对话。
- **选项交互**：
  - 当存在选项时，对话框右上角出现对应的按钮（通常为1-3个）。
  - 玩家可以通过鼠标点击对应选项，或者直接按下键盘上的数字键（例如 `1` 和 `2`）来做出选择。
  - 选项触发后，系统根据选择的分支ID跳转到对应的对话节点。

## 3. 技术实现方案 (Technical Design)
### 3.1 节点结构 (Node Hierarchy)
```text
DialogueUI (CanvasLayer)
└── Control (全屏，拦截下层鼠标点击)
    ├── PanelContainer (对话框背景，位于屏幕底部)
    │   ├── HBoxContainer
    │   │   ├── TextureRect (头像 Avatar)
    │   │   └── VBoxContainer
    │   │       ├── Label (名字 Name)
    │   │       ├── RichTextLabel (对话文本 Text)
    │   └── TextureRect/Control (向下箭头 Next Indicator，置于右下角)
    └── VBoxContainer (选项容器 OptionsContainer，置于对话框上方或右上角)
        ├── Button (Option 1)
        └── Button (Option 2)
```

### 3.2 数据结构 (Data Structure)
采用基于字典/JSON格式的节点式对话结构：
```gdscript
var dialog_data = {
    "start": {
        "name": "NPC",
        "avatar": preload("res://Assets/NPC_Avatar.png"),
        "text": "你好，勇士。你需要什么帮助吗？",
        "options": [
            {"text": "我要接任务", "next_id": "quest_node"},
            {"text": "只是路过", "next_id": "bye_node"}
        ]
    },
    "quest_node": { ... }
}
```

### 3.3 全局管理器 (DialogueManager)
通过单例或自动加载脚本 `DialogueManager` 负责触发对话界面的弹出、传递数据以及抛出结束信号。

## 4. UI 动画与表现 (UI Animations)
- **打字机效果**：通过 `Tween` 或 `Timer` 动态修改 `RichTextLabel` 的 `visible_ratio` 或 `visible_characters`。
- **小箭头动画**：使用 `AnimationPlayer` 或 `Tween` 让箭头在 Y 轴上循环轻微位移。