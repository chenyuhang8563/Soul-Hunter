# Repository Notes

- Small/medium edits: use `apply_patch`.
- Text rewrites: force UTF-8.
- Chinese/mojibake files: avoid whole-file rewrites.
- GDScript: tabs only, no spaces.
- Do not rely on `godot.exe` shell log capture for test results; use Godot MCP or Gut artifacts instead.

# Agent Notes
- For any file search or grep in the current git indexed directory use fff tools.