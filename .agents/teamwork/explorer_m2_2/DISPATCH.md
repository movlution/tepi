# Dispatch - Explorer 2 (Milestone 2)
Focus: Dialogs & Semantic Red (TaskEditor.cs, WorkWindow.cs, Kulia.cs, ColorPicker.cs)

## 2026-11-12T23:02:07Z
You are Explorer 2 for Milestone 2 of the Tepi UI/UX Production Visual Overhaul project.

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_2\
Parent orchestrator conversation ID: 789fb24f-4dc5-451b-991c-640bde73cdc8

You MUST read these documents first before beginning:
1. ORIGINAL_REQUEST.md: d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md
2. Global project plan: d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md
3. Milestone 2 scope: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m2\SCOPE.md

Your primary focus is Dialogs & Semantic Red tokens in `src/TaskEditor.cs`, `src/WorkWindow.cs`, `src/Kulia.cs`, and `src/ColorPicker.cs`:
1. Hardcoded semantic red replacement:
   - In `src/TaskEditor.cs` (lines 103, 125) and `src/WorkWindow.cs` (line 673): find all `Color.IndianRed`.
   - In `src/WorkWindow.cs` (line 601): find `Color.FromArgb(224, 96, 84)`.
   - Inspect all uses and design replacement with semantic token `Ink.Base.Negative`. Ensure using directives and imports are correct.
2. `KuliaLogin` Modernization:
   - Inspect `src/Kulia.cs` (specifically `KuliaLogin` form).
   - Trace its current base class, window styling, borders, colors, and button implementations.
   - Design refactoring so `KuliaLogin` inherits from `KitWindow` instead of `Form`.
   - Replace standard/custom buttons with `KitButton`, and ad-hoc colors with `KitInk` tokens (`KitInk.Bg`, `KitInk.Text`, `KitInk.Sub`, etc.).
   - Ensure dialog layout, authentication flow, and modal behavior remain completely functional.
3. `ColorPicker` Loupe Token Alignment:
   - Inspect `src/ColorPicker.cs` (loupe magnification window, overlay, text rendering).
   - Identify hardcoded dark background and raw point font sizes.
   - Design alignment with `KitInk` tokens and standard type scale from `Ink` (`Ink.FontUi`, etc.).

Your output requirements:
- Produce a comprehensive analysis report in `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_2\analysis.md` and `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_2\handoff.md`.
- Include exact file lines, current code, proposed replacement code, and layout details.
- Send a completion message to the parent sub-orchestrator (`789fb24f-4dc5-451b-991c-640bde73cdc8`) when done.
- REMEMBER: You are read-only. Do NOT edit source files or run builds.
