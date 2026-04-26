# Agent Notes
- For any file search or grep in the current git indexed directory use fff tools.

## Commands

- **Godot executable**: `E:\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe`
- **Run single test file**: `godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd --path "$PWD" -gtest=res://test/test_file_name.gd` (replace `test_file_name.gd` with the actual test file name)
- **GDScript**: tabs only, no spaces (AGENTS.md requirement)
- **Chinese/mojibake files**: avoid whole-file rewrites; use targeted edits
- **Text rewrites**: force UTF-8 encoding
- **Test results**: use Gut artifacts or Godot MCP — do not rely on `godot.exe` shell log capture