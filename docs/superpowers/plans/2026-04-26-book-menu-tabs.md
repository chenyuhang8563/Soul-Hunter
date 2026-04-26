# Book Menu Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `BookMenu` so the right-side tabs switch between the existing backpack page and a placeholder settings page.

**Architecture:** Keep one controller script on `BookMenu`, but group the scene into `OpenContent/PageChrome`, `OpenContent/Tabs`, and `OpenContent/Pages`. `BookMenu.gd` controls book open/close, tab signals, and mutually exclusive page visibility; backpack population remains isolated to the backpack page nodes.

**Tech Stack:** Godot 4 scene files (`.tscn`), GDScript with tabs for indentation, existing PropManager and prop item slot scenes, Gut/Godot MCP validation.

---

## File Structure

- Modify: `res://Scenes/UI/book_menu.tscn`
  - Move existing visual/content nodes under `OpenContent`.
  - Add `Pages/BackpackPage` and `Pages/SettingsPage`.
  - Keep `BookSprite` at the root so it can animate independently before page UI appears.
- Modify: `res://Scenes/UI/book_menu.gd`
  - Replace stale root-level node paths with the new grouped paths.
  - Add page IDs and `_select_page()`.
  - Connect `BackpackTab.pressed` and `SettingsTab.pressed`.
  - Ensure settings page does not call `_populate_backpack()`.
- Create: `res://tests/test_book_menu_tabs.gd`
  - Instantiate `book_menu.tscn`.
  - Verify default backpack page, settings switching, backpack switching, and unknown page fallback.

## Task 1: Add BookMenu Tab Tests

**Files:**
- Create: `tests/test_book_menu_tabs.gd`

- [ ] **Step 1: Create the failing Gut test file**

Create `tests/test_book_menu_tabs.gd` with tab indentation:

```gdscript
extends GutTest

const BookMenuScene := preload("res://Scenes/UI/book_menu.tscn")

var _menu: Control


func before_each() -> void:
	_menu = BookMenuScene.instantiate()
	add_child_autofree(_menu)
	_menu._ready()


func test_default_page_is_backpack() -> void:
	_menu._select_page("backpack")

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/BackpackPage/TitleLabel").text, "BackPack")


func test_settings_tab_switches_to_settings_page() -> void:
	_menu.get_node("OpenContent/Tabs/SettingsTab").pressed.emit()

	assert_false(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_true(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/SettingsPage/TitleLabel").text, "Settings")


func test_backpack_tab_switches_back_to_backpack_page() -> void:
	_menu.get_node("OpenContent/Tabs/SettingsTab").pressed.emit()
	_menu.get_node("OpenContent/Tabs/BackpackTab").pressed.emit()

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
	assert_eq(_menu.get_node("OpenContent/Pages/BackpackPage/TitleLabel").text, "BackPack")


func test_unknown_page_falls_back_to_backpack() -> void:
	_menu._select_page("unknown")

	assert_true(_menu.get_node("OpenContent/Pages/BackpackPage").visible)
	assert_false(_menu.get_node("OpenContent/Pages/SettingsPage").visible)
```

- [ ] **Step 2: Run the new test and verify it fails for the right reason**

Run the project test workflow with Godot MCP or Gut artifacts. Do not rely on `godot.exe` shell log capture as the source of truth.

Suggested command if the local workflow requires launching Gut:

```powershell
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gtest=res://tests/test_book_menu_tabs.gd
```

Expected result from Gut artifacts or MCP output:

```text
FAIL: Node not found: OpenContent/Pages/BackpackPage
```

This failure confirms the test is checking the new hierarchy before it exists.

- [ ] **Step 3: Commit the failing test**

```powershell
git add tests/test_book_menu_tabs.gd
git commit -m "test: cover book menu tab switching"
```

## Task 2: Restructure `book_menu.tscn`

**Files:**
- Modify: `Scenes/UI/book_menu.tscn`

- [ ] **Step 1: Move open-book UI under `OpenContent`**

Edit `Scenes/UI/book_menu.tscn` so these nodes have the target parents:

```text
Divider parent: OpenContent/PageChrome
PageCorner parent: OpenContent/PageChrome
PageFoldRight parent: OpenContent/PageChrome/PageCorner
PageFoldLeft parent: OpenContent/PageChrome/PageCorner
Tabs parent: OpenContent
BackpackTab parent: OpenContent/Tabs
BackPackIcon parent: OpenContent/Tabs/BackpackTab
SettingsTab parent: OpenContent/Tabs
SettingsIcon parent: OpenContent/Tabs/SettingsTab
TitleLabel parent: OpenContent/Pages/BackpackPage
ItemContainer1 parent: OpenContent/Pages/BackpackPage
ItemContainer2 parent: OpenContent/Pages/BackpackPage
```

Add these grouping nodes:

```text
[node name="OpenContent" type="Control" parent="."]
layout_mode = 3
anchors_preset = 0

[node name="PageChrome" type="Control" parent="OpenContent"]
layout_mode = 0

[node name="Pages" type="Control" parent="OpenContent"]
layout_mode = 0

[node name="BackpackPage" type="Control" parent="OpenContent/Pages"]
layout_mode = 0

[node name="SettingsPage" type="Control" parent="OpenContent/Pages"]
layout_mode = 0
visible = false
```

Keep `BookSprite` as a direct child of `BookMenu`.

- [ ] **Step 2: Add the settings placeholder title**

Add a label under `OpenContent/Pages/SettingsPage` using the same font/color/position style as the backpack title, but with text `Settings`:

```text
[node name="TitleLabel" type="Label" parent="OpenContent/Pages/SettingsPage"]
layout_mode = 0
offset_left = 91.0
offset_top = 30.0
offset_right = 148.0
offset_bottom = 42.0
theme_override_colors/font_color = Color(1, 1, 0.23137255, 1)
theme_override_colors/font_shadow_color = Color(0, 0.7411765, 1, 1)
theme_override_fonts/font = ExtResource("8_1bpp1")
theme_override_font_sizes/font_size = 11
text = "Settings"
```

Leave `SettingsPage` otherwise empty.

- [ ] **Step 3: Verify scene loads structurally**

Use Godot MCP to load `res://Scenes/UI/book_menu.tscn` or inspect the scene tree in the editor.

Expected hierarchy:

```text
BookMenu
BookMenu/BookSprite
BookMenu/OpenContent/PageChrome/Divider
BookMenu/OpenContent/PageChrome/PageCorner/PageFoldRight
BookMenu/OpenContent/PageChrome/PageCorner/PageFoldLeft
BookMenu/OpenContent/Tabs/BackpackTab/BackPackIcon
BookMenu/OpenContent/Tabs/SettingsTab/SettingsIcon
BookMenu/OpenContent/Pages/BackpackPage/TitleLabel
BookMenu/OpenContent/Pages/BackpackPage/ItemContainer1
BookMenu/OpenContent/Pages/BackpackPage/ItemContainer2
BookMenu/OpenContent/Pages/SettingsPage/TitleLabel
```

- [ ] **Step 4: Commit the scene hierarchy change**

```powershell
git add Scenes/UI/book_menu.tscn
git commit -m "refactor: group book menu pages"
```

## Task 3: Update `book_menu.gd` Page Switching

**Files:**
- Modify: `Scenes/UI/book_menu.gd`

- [ ] **Step 1: Replace stale node references**

Replace the node-reference section with paths that match the new hierarchy. Use tabs for GDScript indentation in functions; this top-level block has no indentation.

```gdscript
@onready var _book_sprite: AnimatedSprite2D = $BookSprite
@onready var _open_content: Control = $OpenContent
@onready var _backpack_tab: TextureButton = $OpenContent/Tabs/BackpackTab
@onready var _settings_tab: TextureButton = $OpenContent/Tabs/SettingsTab
@onready var _backpack_page: Control = $OpenContent/Pages/BackpackPage
@onready var _settings_page: Control = $OpenContent/Pages/SettingsPage
@onready var _container1: GridContainer = $OpenContent/Pages/BackpackPage/ItemContainer1
@onready var _container2: GridContainer = $OpenContent/Pages/BackpackPage/ItemContainer2
```

Add page IDs near the state block:

```gdscript
const PAGE_BACKPACK := "backpack"
const PAGE_SETTINGS := "settings"

var _current_page := PAGE_BACKPACK
```

- [ ] **Step 2: Update `_ready()` to hide grouped content and connect tabs**

Change `_ready()` so it calls `_set_open_content_visible(false)`, connects both tab signals, initializes backpack slots, and selects the default page without showing open content yet:

```gdscript
func _ready() -> void:
	_book_sprite.stop()
	_book_sprite.frame = 0

	_set_open_content_visible(false)

	if not _book_sprite.animation_finished.is_connected(_on_animation_finished):
		_book_sprite.animation_finished.connect(_on_animation_finished)
	if not _backpack_tab.pressed.is_connected(_on_backpack_tab_pressed):
		_backpack_tab.pressed.connect(_on_backpack_tab_pressed)
	if not _settings_tab.pressed.is_connected(_on_settings_tab_pressed):
		_settings_tab.pressed.connect(_on_settings_tab_pressed)

	_add_placeholder_items()
	_connect_slot_signals()
	_select_page(PAGE_BACKPACK)

	visible = false
```

- [ ] **Step 3: Replace page visibility helpers**

Remove `_set_pages_visible()` and add these functions:

```gdscript
func _set_open_content_visible(v: bool) -> void:
	_open_content.visible = v


func _select_page(page_id: String) -> void:
	if page_id != PAGE_BACKPACK and page_id != PAGE_SETTINGS:
		page_id = PAGE_BACKPACK

	_current_page = page_id
	_backpack_page.visible = page_id == PAGE_BACKPACK
	_settings_page.visible = page_id == PAGE_SETTINGS

	if page_id == PAGE_BACKPACK:
		_populate_backpack()
```

- [ ] **Step 4: Add tab signal handlers**

Add these handlers near the page-control section:

```gdscript
func _on_backpack_tab_pressed() -> void:
	_select_page(PAGE_BACKPACK)


func _on_settings_tab_pressed() -> void:
	_select_page(PAGE_SETTINGS)
```

- [ ] **Step 5: Update open, close, and animation-finished flow**

Replace references to `_set_pages_visible(false)` with `_set_open_content_visible(false)`.

Update `_on_animation_finished()` to show grouped content and select the current page:

```gdscript
func _on_animation_finished() -> void:
	_is_animating = false
	_book_sprite.stop()
	_book_sprite.frame = _book_sprite.sprite_frames.get_frame_count("default") - 1
	_set_open_content_visible(true)
	_select_page(_current_page)
```

In `open()`, reset the current page before the animation starts:

```gdscript
func open() -> void:
	if _is_open:
		return
	_is_animating = true
	_is_open = true
	_current_page = PAGE_BACKPACK

	_book_sprite.stop()
	_book_sprite.frame = 0
	_set_open_content_visible(false)
	_book_sprite.play("default")

	visible = true
	get_tree().paused = true
```

In `close()`, hide grouped content:

```gdscript
func close() -> void:
	_is_open = false
	_is_animating = false
	_book_sprite.stop()
	_book_sprite.frame = 0
	_set_open_content_visible(false)
	visible = false

	get_tree().paused = false
```

- [ ] **Step 6: Run the tab tests and verify they pass**

Use Godot MCP or Gut artifacts as the source of truth.

Suggested command if needed:

```powershell
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gtest=res://tests/test_book_menu_tabs.gd
```

Expected Gut result:

```text
4 passed, 0 failed
```

- [ ] **Step 7: Commit script update**

```powershell
git add Scenes/UI/book_menu.gd
git commit -m "feat: switch book menu tabs"
```

## Task 4: Integration Verification

**Files:**
- Verify: `Scenes/arena.tscn`
- Verify: `Scenes/UI/book_menu.tscn`
- Verify: `Scenes/UI/book_menu.gd`

- [ ] **Step 1: Verify `arena.tscn` integration remains unchanged**

Check that `BookMenu` is still instanced under `MenuLayer` and still processes while paused:

```text
[node name="MenuLayer" type="CanvasLayer" parent="."]
[node name="BookMenu" parent="MenuLayer" instance=ExtResource(...)]
process_mode = 3
visible = false
```

Expected: no implementation change is needed in `Scenes/arena.tscn`.

- [ ] **Step 2: Run the full relevant Gut suite**

Run the BookMenu test and the existing prop-manager test because backpack population depends on PropManager behavior.

Suggested command if needed:

```powershell
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gtest=res://tests/test_book_menu_tabs.gd,res://test/test_prop_manager.gd
```

Expected result from Gut artifacts or MCP output:

```text
All selected tests passed
```

If the local Gut configuration only scans `res://tests`, run `res://tests/test_book_menu_tabs.gd` through Gut and separately confirm `test_prop_manager.gd` with the repository's existing test workflow.

- [ ] **Step 3: Manual playtest through Godot MCP**

Use Godot MCP to run `res://Scenes/arena.tscn` and verify:

```text
Press Tab -> BookMenu opens and game pauses.
Wait for book animation -> BackpackPage appears.
Click SettingsTab -> BackpackPage hides, SettingsPage appears, title reads Settings.
Click BackpackTab -> BackpackPage appears, SettingsPage hides, title reads BackPack.
Press Tab -> BookMenu closes and game resumes.
```

- [ ] **Step 4: Commit verification-only adjustments if any**

If verification requires no file changes, do not create a commit.

If a small fix is needed, commit only the touched implementation files:

```powershell
git add Scenes/UI/book_menu.tscn Scenes/UI/book_menu.gd tests/test_book_menu_tabs.gd
git commit -m "fix: stabilize book menu tab behavior"
```

## Self-Review Notes

- Spec coverage: hierarchy, settings placeholder, default backpack page, tab switching, pause behavior, and testing are all covered by Tasks 1-4.
- Scope control: no concrete settings controls, no new pages beyond `SettingsPage`, no `arena.tscn` changes, and no page script split.
- GDScript formatting: implementation snippets use tab indentation inside functions.
- Verification source: plan explicitly avoids relying on `godot.exe` shell log capture as the source of truth and requires Godot MCP or Gut artifacts.
