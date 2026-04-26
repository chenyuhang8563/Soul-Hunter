# Soul Hunter

Godot 4.6 像素风格动作游戏，核心玩法为**角色附身系统**。

## 快速开始

```bash
# 用 Godot 4.6+ 打开项目
godot4 project.godot
```

## 核心特性

- **附身系统** - 附身敌人操控其能力
- **多角色** - 剑士、士兵、史莱姆、兽人、弓箭手
- **对话系统** - JSON 驱动的分支对话
- **AI 行为** - 巡逻、追击

## 项目结构

```
Character/     # 角色基类与子类
Global/        # 单例 (SceneManager, DialogueManager, AudioManager)
Scenes/        # 关卡与 UI
Environment/   # 环境交互物
Data/          # 外部数据 (对话 JSON)
```
