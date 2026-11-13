# Review & Handoff Report: Milestone 4 — Dock & Mini Polish

**Reviewer**: Reviewer 1 (Roles: Reviewer, Adversarial Critic)  
**Milestone**: Milestone 4 (Dock & Mini Polish)  
**Working Directory**: `d:\PROJECT\Other\tepi`  
**State Folder**: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m4\reviewer_1\`  
**Date**: 2026-11-13  
**Verdict**: **APPROVE**  

---

## 1. Observation

A rigorous, independent review and adversarial evaluation of Worker 1's implementation across all Milestone 4 target files was conducted:
- `src/DockPaint.cs`
- `src/DockCard.cs`
- `src/DockSheet.cs`
- `src/DockCal.cs`
- `src/Mini.cs`

### 1.1 Integrity Audit Observations
- **Source Code Verification**:
  - `src/DockPaint.cs`:
    - `RimLight` (lines 214–224): Replaced hardcoded `Color.White, Color.White` and `Color.FromArgb(..., 255, 255, 255)` with `p.T.Highlight` across all stops.
    - `Sheen` (lines 234–251): Linear gradient stops tokenized to `Color.FromArgb(Ink.Light ? 80 : 24, p.T.Highlight)` and `Color.FromArgb(0, p.T.Highlight)`. Hover radial glow tokenized to `Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), p.T.Highlight)` and `Color.FromArgb(0, p.T.Highlight)`.
    - `Rim` (lines 254–269): Gradient stops and peak cursor reflection tokenized to `p.T.Highlight`.
    - `Badge` (lines 647–657): `BadgeRed` eliminated. Halo backdrop uses `Ink.A(p.T.Bg, 0.55f)`. Badge fill uses `p.T.Negative`. Text uses dynamic contrast formula `p.T.IsDark ? p.T.Bg : Color.White`.
  - `src/DockCard.cs`:
    - `DrawWindows` (lines 369–372): Sheen linear gradient and outline pen tokenized to `p.T.Highlight`.
    - Close button (lines 411–415): Hover fill tokenized to `p.T.Negative`. Close glyph `\uE711` tokenized to `hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub`.
    - Static definition `BadgeRedSoft` completely eliminated.
  - `src/DockSheet.cs`:
    - `Render` (lines 267–275): Sheen gradient and border pen tokenized to `p.T.Highlight`.
    - `OnMouseMove` (line 322): Stale press tracking cleared when `e.Button == MouseButtons.None`.
    - `OnMouseLeave` (line 336): `pressId = null;` prevents sticky press state.
    - `Button` (lines 474–477): Added `bool down = Down(id); if (down) r.Offset(0, 0.75f);` and fill `down ? p.T.FillPressed : p.T.FillHover`.
  - `src/DockCal.cs`:
    - Pressed state tracking: `pressedId` field, `selectedDay` / `SelectedDay` property, `Down(string id)` and `Pressed(string id)` methods.
    - Event overrides: `OnMouseDown` records `pressedId = HitAt(e.Location)`, `OnMouseUp` and `OnMouseLeave` reset `pressedId = null`.
    - Buttons updated: "clear" (`b.Offset(0, 0.75f)` + `p.T.FillPressed`), notification item delete (`0.75f` offset + `p.T.FillPressed`), month header `today` jump (`tb.Offset(0, 0.75f)` + `p.T.FillPressed`), quiet toggle (`0.75f` offset + pressed accent/tint), and all day cells (`did = "d" + YYYYMMDD` with hover, pressed displacement `0.75f`, and selection outline).
    - `Clicked`: Navigates month when clicking dates from adjacent months.
  - `src/Mini.cs`:
    - Constants: `const float MiniDotR = 2.5f, MiniTrackThick = 4f;`.
    - Dot radius updated to `MiniDotR` (2.5f) across all 3 call sites (`MiniClockOn`, plain sliver, `MiniFace`).
    - Plain sliver right margin: `right = dot ? w - 16 : w - 12;`, guaranteeing $4.5\text{px}$ clearance between track and enlarged dot.
    - Track thickened to $4.0\text{px}$ (`MiniTrackThick`) for both horizontal and vertical orientations.
    - Background track uses `p.T.Faint`.
- **Integrity Findings**: ZERO facade logic, ZERO hardcoded test outputs, ZERO shortcuts. All implementations are genuine, functional, and clean.

### 1.2 Build & Test Execution Observations
- **Independent Build (`build.cmd`)**:
  ```cmd
  cmd /c build.cmd
  ```
  *Result*: `Build OK: D:\PROJECT\Other\tepi\Tepi.exe` (Exit Code 0).
- **Smoke Test Suite (`tests/smoke_test.ps1`)**:
  *Result*: 18/18 checks PASSED (100% pass, Exit Code 0).
- **E2E Test Runner (`tests/run_e2e.ps1`)**:
  *Result*: Tier 1 (78/78 passed), Tier 2 (105/105 passed). Grand Total: 183/183 passed (100% pass, Exit Code 0).
- **Adversarial Regression Suite (`tests/adversarial/run_adversarial.ps1`)**:
  *Result*: All suites passed (Exit Code 0).
- **Challenger Suites (`tests/challenger1_empirical_stress.ps1`, `tests/challenger2_m3_stress.ps1`)**:
  *Result*: 31/31 passed, 11/11 passed (Exit Code 0).

### 1.3 Mathematical WCAG Contrast Calculations
Calculated via authoritative relative luminance oracle ($L = 0.2126 R + 0.7152 G + 0.0722 B$ in linearized sRGB space):
1. **Unread Badge in Dark Mode**:
   - Background: `p.T.Negative` = `#F07878` ($L = 0.3331$)
   - Text: `p.T.Bg` = `#000000` ($L = 0.0000$)
   - Contrast Ratio: **7.66:1** ($\ge 4.5:1$, **PASS WCAG AA**)
   - Contrast of Badge on Dock Surface (`#000000`): **7.66:1** ($\ge 4.5:1$, **PASS WCAG AA**)
2. **Unread Badge in Light Mode**:
   - Background: `p.T.Negative` = `#BE3232` ($L = 0.1346$)
   - Text: `Color.White` = `#FFFFFF` ($L = 1.0000$)
   - Contrast Ratio: **5.69:1** ($\ge 4.5:1$, **PASS WCAG AA**)
   - Contrast of Badge on Dock Surface (`#F5F5F5`): **5.22:1** ($\ge 4.5:1$, **PASS WCAG AA**)
3. **DockCard Close Button**:
   - Dark Mode Glyph vs Negative: **7.66:1** ($\ge 4.5:1$, **PASS WCAG AA**)
   - Light Mode Glyph vs Negative: **5.69:1** ($\ge 4.5:1$, **PASS WCAG AA**)
4. **Mini Status Track & Notification Dot**:
   - Dark Mode Track (`p.T.Faint` blended on black bezel `#000000`): **6.42:1** ($\ge 3:1$, **PASS**)
   - Dark Mode Dot (`p.T.Negative` on black bezel): **7.66:1** ($\ge 3:1$, **PASS**)
   - Light Mode Track (`p.T.Faint` blended on light bezel `#F0F0F0`): **4.60:1** ($\ge 3:1$, **PASS**)
   - Light Mode Dot (`p.T.Negative` on light bezel): **4.99:1** ($\ge 3:1$, **PASS**)

### 1.4 Independent Adversarial Test Suite (`adversarial_m4_stress.ps1`)
Executed `.agents/teamwork/sub_orch_m4/reviewer_1/adversarial_m4_stress.ps1`:
```
[SUITE] Adversarial Stress Suite: Milestone 4 - Dock & Mini Polish
    [PASS] 1. Sweeps for hardcoded legacy colors and verify complete elimination (39.78ms)
    [PASS] 2. Stress-tests unread badge contrast across all 7 curated preset accents and modes (86.82ms)
    [PASS] 3. Verifies DockCard close button glyph contrast in hot state (5.69ms)
    [PASS] 4. Stress-tests CalendarSheet pressed state tracking, drag-out, and methods (113.16ms)
    [PASS] 5. Tests calendar day click navigation and cross-month calculation (20.96ms)
    [PASS] 6. Verifies Mini indicator geometry, dot area, track thickness, and clearance (61.35ms)
    [PASS] 7. Verifies Mini track and dot contrast against monitor bezel boundaries (32.66ms)
```

---

## 2. Logic Chain

1. **Token Conformance & Elimination of Hardcoded Colors**:
   - `git grep -i "BadgeRed"` returned 0 occurrences across the entire repository.
   - All sheen and rim lights in `DockPaint.cs`, `DockCard.cs`, and `DockSheet.cs` reference `p.T.Highlight`, eliminating arbitrary hardcoded white ARGB gradients.
   - Unread badges and close buttons reference `p.T.Negative`.

2. **Accessibility & Contrast Verification**:
   - A common pitfall in dark mode notification badges is using white text on light red (`#F07878`), which fails WCAG AA with only 2.74:1.
   - Worker 1's dynamic formula `p.T.IsDark ? p.T.Bg : Color.White` provides black text on `#F07878` in dark mode (7.66:1) and white text on `#BE3232` in light mode (5.69:1). Both exceed the 4.5:1 WCAG AA threshold.
   - The close button in `DockCard.cs` applies the exact same contrast logic (`hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub`), achieving identical contrast compliance.

3. **Interactive Down States & Drag Stability**:
   - In `DockCal.cs` and `DockSheet.cs`, interactive elements combine visual color changes (`p.T.FillPressed`) with physical displacement (`r.Offset(0, 0.75f)`).
   - In `CalendarSheet`, `Down(id)` evaluates `(pressedId == id || pressId == id) && hotId == id`.
   - Adversarial simulation confirmed that dragging the cursor outside the hit bounds deactivates `Down(id)`, returning the button to its resting state, and dragging back in restores the pressed state without triggering accidental clicks. Releasing the mouse or leaving the control safely nullifies `pressedId`.

4. **Mini Salience & Subpixel Invariants**:
   - With `MiniDotR = 2.5f`, circle area is $\pi \times 2.5^2 = 19.635\text{ px}^2$, meeting the $\ge 19.6\text{ px}^2$ specification.
   - The status track thickness of $4.0\text{px}$ centers with exact 2px symmetrical padding inside the 8px sliver height.
   - The track right margin in the plain sliver (`right = dot ? w - 16 : w - 12`) ensures that when the notification dot is active (center at $w - 9$, left perimeter at $w - 11.5$), there is a clear $4.5\text{px}$ gap, completely eliminating visual collisions.
   - Upgrading from `p.T.Quaternary` to `p.T.Faint` elevates track contrast on host monitor bezels above 6.0:1 in dark mode and 4.6:1 in light mode, comfortably satisfying the $\ge 3:1$ requirement.

---

## 3. Caveats

- Win32 layered window requirement: `Color.FromArgb(1, 0, 0, 0)` in `DockPaint.cs:92` is an invisible hit-test bar required by Windows per-pixel alpha layered window semantics (`UpdateLayeredWindow`). This was appropriately preserved and does not constitute a design token violation.
- GDI+ canvas clearing calls `g.Clear(Color.Transparent)` were correctly preserved for double-buffered layered window rendering.
- No other caveats.

---

## 4. Conclusion

Worker 1's implementation for Milestone 4 (Dock & Mini Polish) is fully verified, robust, and completely compliant with design token specifications, accessibility standards, and the interface contracts outlined in `PROJECT.md` and `SCOPE.md`.

**Verdict**: **APPROVE**

---

## 5. Verification Method

To independently reproduce and verify this review:
1. **Compilation**:
   ```cmd
   cmd /c build.cmd
   ```
   Confirm output `Build OK: D:\PROJECT\Other\tepi\Tepi.exe`.
2. **Smoke Test**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1
   ```
3. **E2E Test Runner**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1
   ```
4. **Adversarial M4 Stress Suite**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/teamwork/sub_orch_m4/reviewer_1/adversarial_m4_stress.ps1
   ```
5. **Static Sweep**:
   ```powershell
   git grep -i "BadgeRed"
   ```
   Confirm 0 results.

### Invalidation Conditions
- Any code change that drops badge text contrast below 4.5:1 in either theme.
- Re-introduction of hardcoded white ARGB gradients into dock files.
- Shrinking Mini notification dot radius below 2.5px or track thickness below 4px.
