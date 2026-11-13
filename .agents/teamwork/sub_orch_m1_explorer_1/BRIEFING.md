# BRIEFING — 2026-11-12T15:42:00Z

## Mission
Investigate and document the typography system, font family strings, and Segoe UI Variable fallback chains in Tepi (Milestone 1).

## 🔒 My Identity
- Archetype: explorer
- Roles: investigation, synthesis
- Working directory: d:\PROJECT\Other\tepi
- State folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1_explorer_1\
- Original parent: 2e923bc6-0cc8-4584-9a2a-480dec472f3b
- Milestone: Milestone 1 (Visual Polish & Typography)

## 🔒 Key Constraints
- Read-only investigation — do NOT implement / modify source code
- Files for content delivery, messages for coordination
- Handoff report in state folder following 5-component protocol
- Use send_message to report to parent

## Current Parent
- Conversation ID: 2e923bc6-0cc8-4584-9a2a-480dec472f3b
- Updated: 2026-11-12T15:42:00Z

## Investigation State
- **Explored paths**:
  - `src/Ink.cs` (lines 180-340: typography scale, families, font caching, CapShift, IconNudge)
  - `src/Menus.cs` (line 105: MenuFont initialization and static timing)
  - `src/ColorPicker.cs` (line 190: hardcoded Point font)
  - `src/Kit.cs` (UiFont, MenuFamily, IconFamily usages)
  - `src/Island.cs` (line 114: Ink.Init invocation)
  - `docs/analisis/01-visual.md` & `next-visual.md` (VIS-09, VIS-15 audit items)
  - Windows 11 GDI+ font family enumeration via `InstalledFontCollection`
- **Key findings**:
  1. "Display Semib" and "Small Semibol" are NOT typos! They are GDI's 31-character truncation of "Segoe UI Variable Display Semibold" (34 chars) and "Segoe UI Variable Small Semibold" (32 chars) due to Win32 `LF_FACESIZE = 32`.
  2. In GDI+ `InstalledFontCollection`, `f.Name` returns `"Segoe UI Variable Display Semib"` and `"Segoe UI Variable Small Semibol"`.
  3. If changed blindly to ONLY `"Segoe UI Variable Display Semibold"`, `have.Contains(...)` returns `False`, breaking Segoe UI Variable on Windows 11 and falling back to `Segoe UI Semibold`!
  4. Robust solution: Provide BOTH full and truncated strings in `Pick()`, and add a 31-char truncation fallback inside `Pick()`.
  5. `Ink` lacks a static constructor `static Ink() { Init(); }`; if `Ink.MenuFamily` is accessed before `Island` calls `Ink.Init()`, it returns null, causing `Menus.MenuFont` to permanently bind to `Microsoft Sans Serif`.
- **Unexplored areas**: None for typography M1. All tasks completed.

## Key Decisions Made
- Confirmed the root cause of the truncated font names is the Win32 `LOGFONT` 31-character limit.
- Verified that providing both full and truncated names + automatic truncation fallback in `Pick()` ensures 100% compatibility across Windows 10 and 11.
- Documented recommendation for Worker to add `static Ink() { Init(); }` to prevent null `MenuFamily` binding.

## Artifact Index
- DISPATCH.md — incoming dispatch instructions
- BRIEFING.md — persistent memory
- progress.md — liveness heartbeat
- test_font.ps1 — verification of InstalledFontCollection vs Font creation
- test_font_styles.ps1 — verification of available font styles (Regular/Bold)
- test_pick.ps1 — demonstration of bug when changing strings blindly
- test_fontfamily.ps1 — verification of GDI+ FontFamily constructor behavior
- test_trunc.ps1 — calculation of string lengths against 31-char limit
- test_robust_pick.ps1 — verification of resilient Pick implementation
- test_unknown_font.ps1 — GDI+ fallback behavior for non-existent fonts
- find_fonts.ps1 / find_hardcoded_font_names.ps1 / find_init.ps1 — codebase audit scripts
- handoff.md — comprehensive final report for Worker and Sub-Orchestrator
