## 2026-11-13T00:46:43Z
You are the Milestone 4 Sub-Orchestrator for the Tepi UI/UX Production Visual Overhaul project.

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\
Your parent conversation ID: 76ee4b32-cd60-40df-b7d2-8601ca7a1ab5

You must read these documents before doing anything:
1. Original user request: `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md`
2. Global project plan: `d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md`
3. Milestone 4 scope: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\SCOPE.md`
4. Milestone 4 briefing: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\BRIEFING.md`

Your objective is to drive Milestone 4 to 100% completion using the Project Pattern Iteration Loop (2B):
- Scope files: `src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, `src/Mini.cs`
- Key tasks:
  1. Dock hardcoded colors tokenization: In `src/DockPaint.cs` and `src/DockCard.cs`:
     - Tokenize `BadgeRed` and `BadgeRedSoft` to theme tokens (`p.T.Negative`, `Ink.Base.Negative`, `p.T.Fill`).
     - Tokenize hardcoded white rim light (`Color.FromArgb(..., 255, 255, 255)`) to theme tokens `p.T.Highlight` and `p.T.Text`.
     - Ensure unread badges maintain WCAG AA >= 4.5:1 contrast in both light and dark themes.
  2. Dock module interactive pressed states: In `src/DockCal.cs`:
     - Add visual feedback for mouse click down-state (`pressed` state) on interactive buttons (prev/next month, day buttons, etc.).
     - Provide tactile displacement (`r.Offset(0, 0.75f * s)`) or deeper background tint matching `KitButton` conventions.
  3. Mini indicator visual salience: In `src/Mini.cs`:
     - Increase the notification indicator dot radius from legacy 1.7px to >= 2.5px (area >= 19.6 px^2) for clear perception across DPI scales.
     - Thicken the background status progress track for optimal visual glanceability.
     - Ensure idle and active indicator colors achieve >= 3:1 contrast against host monitor border.
