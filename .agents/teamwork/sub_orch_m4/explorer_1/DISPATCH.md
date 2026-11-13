## 2026-11-13T00:47:54Z
You are Explorer 1 for Milestone 4 (Dock & Mini Polish).

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_1\

You MUST read these documents first before inspecting any code:
1. `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md`
2. `d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md`
3. `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\SCOPE.md`

Your specific focus is Task 1: Dock Hardcoded Colors Tokenization in `src/DockPaint.cs`, `src/DockCard.cs`, and `src/DockSheet.cs`.
Detailed tasks:
1. Inspect `src/DockPaint.cs`, `src/DockCard.cs`, and `src/DockSheet.cs` to locate all hardcoded colors, specifically:
   - `BadgeRed` and `BadgeRedSoft` definitions and usages.
   - Hardcoded white rim light (`Color.FromArgb(..., 255, 255, 255)`) or similar hardcoded highlights/rims.
   - Any other hardcoded colors in Dock surfaces/cards/sheets.
2. Determine how to properly tokenize them using theme tokens from `Tone` (`p.T.Negative`, `p.T.Highlight`, `p.T.Text`, `p.T.Fill`) and `Ink.Base.Negative`.
3. Check and verify WCAG AA contrast (>= 4.5:1) for badge text on badge background and badge on dock surface in both light and dark themes.
4. Provide exact line numbers, verified evidence, and recommended drop-in code diffs.
5. Write your complete handoff report to `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_1\handoff.md` and message the orchestrator when finished.
