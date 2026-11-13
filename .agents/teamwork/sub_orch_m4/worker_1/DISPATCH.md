## 2026-11-13T00:59:27Z

You are Worker 1 for Milestone 4 (Dock & Mini Polish).

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\worker_1\

You MUST read these documents first before making any edits:
1. Original user request: `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md`
2. Global project plan: `d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md`
3. Milestone 4 scope: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\SCOPE.md`
4. Synthesis of Explorer findings: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\synthesis.md`
5. Explorer 1 report: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_1\handoff.md`
6. Explorer 2 report: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_2\handoff.md`
7. Explorer 3 report: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\explorer_3\handoff.md`

Your exclusive write boundaries:
- `src/DockPaint.cs`
- `src/DockCard.cs`
- `src/DockSheet.cs`
- `src/DockCal.cs`
- `src/Mini.cs`
DO NOT modify any other files in `src/`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implementation tasks:
1. In `src/DockPaint.cs`:
   - Tokenize `RimLight`, `Sheen`, and `Rim` to use `p.T.Highlight` instead of hardcoded white `Color.FromArgb(..., 255, 255, 255)` per Explorer 1 Diff DP-1.
   - Tokenize `BadgeRed` to `p.T.Negative`, and badge text to `p.T.IsDark ? p.T.Bg : Color.White` per Explorer 1 Diff DP-2.
   - Update halo background from `Ink.A(Ink.Base.Bg, 0.55f)` to `Ink.A(p.T.Bg, 0.55f)`.
2. In `src/DockCard.cs`:
   - Tokenize card sheen and border to use `p.T.Highlight` per Explorer 1 Diff DC-1.
   - Tokenize `BadgeRedSoft` close button to `p.T.Negative` and close glyph to `hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub` per Explorer 1 Diff DC-2.
   - Remove redundant `BadgeRedSoft` field definition.
3. In `src/DockSheet.cs`:
   - Tokenize sheet sheen and border to use `p.T.Highlight` per Explorer 1 Diff DS-1.
   - In `OnMouseLeave`, clear `pressId = null;` to prevent stuck pressed state on mouse drag-out.
   - In `OnMouseMove`, add `if (e.Button == MouseButtons.None && pressId != null) pressId = null;`.
   - In `GlassSheet.Button`, add tactile displacement `if (down) r.Offset(0, 0.75f);`.
   - Expose `protected bool Down(string id) { return pressId == id && hotId == id; }`.
4. In `src/DockCal.cs`:
   - Add `pressedId` field and `selectedDay` property.
   - Add `Down(string id)` and `Pressed(string id)` helper methods.
   - Override `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave` to track `pressedId`.
   - Update `"clear"` button with `Down("clear")`, tactile offset `b.Offset(0, 0.75f)`, and `p.T.FillPressed`.
   - Update delete button `del` with `Down(del)` and tactile offset.
   - Update month jump button `"today"` with hit-testing, `Down("today")`, tactile offset, and hover/pressed states.
   - Make day cells interactive with `Hit`, hover (`p.T.FillHover`), pressed state (`p.T.FillPressed` / accent active mix), and tactile displacement `0.75f`.
   - Update `"quiet"` toggle button with tactile offset and pressed state tint.
5. In `src/Mini.cs`:
   - Introduce `const float MiniDotR = 2.5f, MiniTrackThick = 4f;`.
   - Update notification dot radius from 1.7f to `MiniDotR` (2.5f) in `MiniClockOn`, plain sliver, and `MiniFace`.
   - Adjust right margin in plain sliver: `right = dot ? w - 16 : w - 12;` for clean 4.5px clearance.
   - Thicken horizontal status track from 2px to 4px (`MiniTrackThick`), centered at `cy - MiniTrackThick / 2`.
   - Thicken vertical status track (`OnSide`) from 2px to 4px (`MiniTrackThick`), centered at `cx - MiniTrackThick / 2`.
   - Replace legacy `p.T.Quaternary` background track with `p.T.Faint` in `Hair` and `OnSide`.
   - Adjust `Breath` baseline alpha to `0.38f + 0.32f * k`.

Build & Verification:
- Run `build.cmd` from project root to ensure `Tepi.exe` builds with zero errors.
- Run `powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1`.
- Verify static code cleanliness: ensure `BadgeRed` and `BadgeRedSoft` and hardcoded white rim lights are completely gone from the 3 files.

Write your handoff report to `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\worker_1\handoff.md` with:
- Summary of changes per file
- Build output
- Test results
- Static verification output
Message the orchestrator when finished.
