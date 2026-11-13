## 2026-11-13T00:48:07Z
You are Explorer 2 for Milestone 4 (Dock & Mini Polish).

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_2\

You MUST read these documents first before inspecting any code:
1. `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md`
2. `d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md`
3. `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\SCOPE.md`

Your specific focus is Task 2: Dock Module Interactive Pressed States in `src/DockCal.cs` (and any related interactive dock modules/sheets in `src/DockSheet.cs` or `src/DockPaint.cs`).
Detailed tasks:
1. Inspect `src/DockCal.cs` to examine how mouse input and button rendering are handled:
   - Examine `OnMouseDown`, `OnMouseUp`, `OnMouseMove`, `OnMouseLeave`, hit testing for prev/next month buttons, day cells/buttons, today button.
   - Analyze how buttons are currently rendered (check if only hover state exists and pressed state is missing).
2. Examine `src/Kit.cs` (`KitButton`), `src/Tabs.cs`, or `src/Parts.cs` to see standard pressed feedback patterns (e.g. tactile offset `r.Offset(0, 0.75f * s)`, deeper background tint, active fill).
3. Design and recommend exact code changes for `src/DockCal.cs` to implement:
   - Pressed state tracking (e.g. `_pressed`, `_pressedBtn`, or `_down` field).
   - MouseDown / MouseUp / MouseLeave handlers to track pressed state and trigger invalidate/repaint.
   - Visual feedback during paint: tactile displacement or darker/deeper background tint matching project conventions.
4. Provide exact line numbers, verified evidence, and recommended drop-in code diffs.
5. Write your complete handoff report to `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_2\handoff.md` and message the orchestrator when finished.
