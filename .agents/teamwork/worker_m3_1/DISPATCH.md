## 2026-11-13T00:12:30Z
You are Worker 1 for Milestone 3 (Island, Navigation & Views Polish).
Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\worker_m3_1\
Parent conversation ID: 99735988-ac39-4926-a99d-2575d2f2b8b2

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY DOCUMENTS TO READ FIRST:
1. `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md` (MUST read verbatim before starting work)
2. `d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md`
3. `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m3\SCOPE.md`
4. `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m3\synthesis.md`
5. Explorer reports:
   - `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m3_1\report.md`
   - `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m3_2\report.md`
   - `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m3_3\report.md`

Your Scope & Implementation Tasks:
Write ownership: You exclusively own modifications to:
- `src/Island.cs`
- `src/Tabs.cs`
- `src/Views.cs`
- `src/Panel.cs`
- `src/Parts.cs`
- `src/WorkWindow.cs`
(and updating callers of EmptyState in `src/Clips.cs`, `src/ConvertPage.cs`, `src/Handset.cs`, `src/Music.cs`, `src/Schedule.cs`, `src/Shelf.cs`, `src/Sources.cs`).

Detailed Tasks:
1. `src/Island.cs`:
   - Text contrast on glass: Apply `tone.OnGlass()` during text rendering (lines 805, 846, 867, 871, 1242-1245) so secondary text maintains WCAG AA >= 4.5:1 contrast against bright glass/wallpapers.
   - Glass pill elevation shadow: Render a subtle elevation shadow for the glass pill when H <= 60 (lines 815-821) using `float shadowStr = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f;`.
   - Approval halo reduced motion guard: In line 1143, guard breathing pulse with `Anim.Reduced` (`float breath = Anim.Reduced ? 0.75f : 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);`).
2. `src/Tabs.cs`:
   - Correct inverted ternary logic from `down ? p.T.FillHover : p.T.FillPressed` (or equivalent inverted fill) to `fill = down ? p.T.FillPressed : p.T.FillHover;` at lines 519, 821, 832, 847 and any related tab drawing routines.
3. `src/Views.cs`:
   - Toast notification meta text collision: In `DrawNotif` (lines 749-762), fix width measurement and text clipping so long app names / meta text do not collide with or overlap the notification title:
     - `float mw = Math.Min(w * 0.35f, p.Measure(meta, Ink.Caption));`
     - `p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far);`
     - Title width: `Math.Max(40, w - 66 - 22 - mw - 12)`
     - Use `Ink.Headline` for title, `Ink.Callout` for body, `Ink.Caption` for meta text.
   - Standardize `ViewRadius` (lines 60-79) from arbitrary 30, 26, 28 to `Math.Min(Ink.RadiusShell, s.Height / 2)`.
   - Standardize approval action button radii (lines 662-673) to `Ink.RadiusControl` (12px).
4. `src/Parts.cs`:
   - Expand `Parts.EmptyState` with overloads (no button, single button primary/secondary, dual buttons) with `p.Module(circle, 24, p.T.Fill)` for icon squircle, `Ink.Headline` for title, `p.TextBox` with `Ink.Callout` for description, and `Pill(...)` action buttons.
5. `src/Panel.cs`:
   - Provide backward compatibility delegating `Empty(...)` and `Button(...)` (lines 13-39) to `Parts.EmptyState` and `Parts.Pill`.
   - Consolidate legacy call sites across `Panel.cs` to `EmptyState(...)`.
   - Standardize typography and radii to tokens (`Ink.Headline`, `Ink.Callout`, `Ink.Body`, `Ink.Caption`, `Ink.RadiusControl`).
6. `src/WorkWindow.cs`:
   - Standardize typography (`UiFont(Ink.Body.Size)`, `UiFont(Ink.Callout.Size)`, `UiFont(Ink.Caption.Size)`, `new Font(Ink.MenuFamily, Ink.Headline.Size * s, FontStyle.Bold, GraphicsUnit.Pixel)`).
   - Standardize radii: well card containers to `Ink.RadiusModule * s` (20 * s), item hovers to `Ink.RadiusControl * s` (12 * s).
7. EmptyState Call Sites across `src/Clips.cs`, `src/ConvertPage.cs`, `src/Handset.cs`, `src/Music.cs`, `src/Schedule.cs`, `src/Shelf.cs`, `src/Sources.cs`:
   - Migrate calls to unified `EmptyState(...)`.
