# Repository Notes

- When editing source files, prefer `apply_patch` for small and medium changes instead of shell-based read/modify/write flows.
- If a script or command must rewrite a text file, always force UTF-8 output explicitly.
- Be extra careful when touching files that contain Chinese text or existing mojibake; avoid whole-file rewrites unless necessary.
- Do not use PowerShell `Set-Content` / `Get-Content` round-trips for source rewrites unless encoding is explicitly controlled.
- After any nontrivial text rewrite, verify the touched file still loads as valid UTF-8.
- For GDScript, indentation must use tabs only; do not use spaces for indentation.
