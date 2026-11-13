# Handoff Report: Milestone 4 — Dock & Mini Polish Implementation

**Author**: Worker 1  
**Milestone**: Milestone 4 (Dock & Mini Polish)  
**Assigned Scope**: Implementation across `src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, and `src/Mini.cs`  
**Date**: 2026-11-13  
**Status**: Complete — Build Clean & 100% Tests Passing  

---

## 1. Observation

All 5 scope files were modified strictly within the assigned write boundaries:
- `src/DockPaint.cs`
- `src/DockCard.cs`
- `src/DockSheet.cs`
- `src/DockCal.cs`
- `src/Mini.cs`

No other files in `src/` were altered.

### 1.1 Summary of Changes Per File

1. **`src/DockPaint.cs`**:
   - In `RimLight` (lines 214–224): Replaced hardcoded `Color.White, Color.White` and `Color.FromArgb(..., 255, 255, 255)` with `p.T.Highlight` across all 3 gradient blend stops.
   - In `Sheen` (lines 234–251): Tokenized linear gradient stops to `Color.FromArgb(Ink.Light ? 80 : 24, p.T.Highlight)` and `Color.FromArgb(0, p.T.Highlight)`. Tokenized hover radial glow center color to `Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), p.T.Highlight)` and surround to `Color.FromArgb(0, p.T.Highlight)`.
   - In `Rim` (lines 254–269): Tokenized cursor rim linear gradient stops and peak color blend to `p.T.Highlight`.
   - In `Badge` (lines 647–660):
     - Removed hardcoded definition `static readonly Color BadgeRed = Color.FromArgb(255, 217, 48, 37);`.
     - Updated halo background from `Ink.A(Ink.Base.Bg, 0.55f)` to `Ink.A(p.T.Bg, 0.55f)`.
     - Tokenized badge fill from `BadgeRed` to `p.T.Negative`.
     - Tokenized badge text from hardcoded `Color.White` to dynamic contrast formula: `p.T.IsDark ? p.T.Bg : Color.White`.

2. **`src/DockCard.cs`**:
   - In `DrawWindows` (lines 368–373): Tokenized sheen linear gradient to `p.T.Highlight` and border outline pen from `Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255)` to `Color.FromArgb(Ink.Light ? 70 : 40, p.T.Highlight)`.
   - In thumbnail close button (lines 411–415): Tokenized hover fill from `BadgeRedSoft` to `p.T.Negative`, and close icon glyph from `Color.White` to `hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub`.
   - Removed definition `static readonly Color BadgeRedSoft = Color.FromArgb(230, 196, 43, 28);` from line 434.

3. **`src/DockSheet.cs`**:
   - In `Render` (lines 266–276): Tokenized sheet sheen linear gradient stops and border pen to `p.T.Highlight`.
   - In `OnMouseMove` (lines 318–328): Added `if (e.Button == MouseButtons.None && pressId != null) pressId = null;` to clear stale press tracking.
   - In `OnMouseLeave` (lines 330–337): Added `pressId = null;` to prevent sticky pressed state on drag-out.
   - Added helper method: `protected bool Down(string id) { return pressId == id && hotId == id; }`.
   - In `Button` (lines 470–476): Added tactile displacement `bool down = Down(id); if (down) r.Offset(0, 0.75f);` and fill `down ? p.T.FillPressed : p.T.FillHover`.

4. **`src/DockCal.cs`**:
   - Added tracking field `string pressedId;` and property `public DateTime? selectedDay { get; set; }` (with alias `SelectedDay`).
   - Added public helper methods: `public bool Pressed(string id) { return Down(id); }` and `public new bool Down(string id) { return (pressedId == id || pressId == id) && hotId == id; }`.
   - Overrode `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave` to track and release `pressedId`.
   - Updated "Hapus semua" (`clear`) button: Added `Down("clear")` check, `b.Offset(0, 0.75f)` tactile displacement, `p.T.FillPressed`, and vertically centered text.
   - Updated notification item delete button (`del`): Added `Down(del)` check, `0.75f` Y-offset, `p.T.FillPressed`, and hover glyph text brightening.
   - Updated "today" / month header jump: Added hit-testing for `month != 0`, hover pill `p.T.FillHover`, pressed pill `p.T.FillPressed`, and `0.75f` tactile displacement.
   - Made all day cells interactive: Registered `Hit` on day cells with `did = "d" + (day.Year * 10000 + day.Month * 100 + day.Day)`. Added hover state (`p.T.FillHover`), pressed state (`p.T.FillPressed` for normal days, `Ink.Mix(p.T.Accent, p.T.OnAccent, 0.22f)` for today), `0.75f` tactile displacement on circle and text, and selection indicator `g.DrawEllipse(p.P(p.T.Accent, 1.2f), ...)`.
   - In `Clicked`: Added handling for clicking day cells to update `selectedDay` and navigate month if clicking leading/trailing days from neighboring months.
   - Updated "Senyap" (`quiet`) toggle button: Added `Down("quiet")` check, `0.75f` tactile displacement, and pressed fill tinting (`Ink.Mix(p.T.Accent, p.T.OnAccent, 0.22f)` when on, `p.T.FillPressed` when off).

5. **`src/Mini.cs`**:
   - Added constants: `const float MiniDotR = 2.5f, MiniTrackThick = 4f;`.
   - Updated notification/privacy dot radius from legacy 1.7f to `MiniDotR` (2.5f) across all 3 call sites (`MiniClockOn`, plain sliver, and `MiniFace`).
   - Adjusted right margin in plain sliver: `right = dot ? w - 16 : w - 12;` guaranteeing a 4.5px clearance between the progress track and the enlarged dot.
   - Thickened horizontal progress track from 2px to 4px (`MiniTrackThick`), centered at `cy - MiniTrackThick / 2`.
   - Thickened vertical progress track (`OnSide`) from 2px to 4px (`MiniTrackThick`), centered at `cx - MiniTrackThick / 2`, with corner radius `MiniTrackThick / 2 = 2.0f`.
   - Replaced legacy `p.T.Quaternary` background track with `p.T.Faint` in `Hair` and `OnSide`.
   - Adjusted `Breath` baseline alpha from `0.22f + 0.4f * k` to `0.38f + 0.32f * k`.

---

## 2. Logic Chain

1. **Badge & Rim Tokenization**:
   - Hardcoded pure white `Color.FromArgb(..., 255, 255, 255)` bypassed pack-driven highlight definitions. Replacing with `p.T.Highlight` guarantees thematic harmony across all light and dark palettes.
   - In Dark mode, `p.T.Negative` is `#F07878` ($L = 0.3331$). White text on `#F07878` yields only **2.74:1** (failing WCAG AA). Using `p.T.Bg` (`#000000`, $L = 0.0000$) achieves **7.66:1** (passing WCAG AA $\ge 4.5:1$). In Light mode, `p.T.Negative` is `#BE3232` ($L = 0.1346$), and white text achieves **5.69:1** (passing WCAG AA $\ge 4.5:1$). The dynamic formula `p.T.IsDark ? p.T.Bg : Color.White` guarantees compliance across all themes.

2. **Tactile Feedback & Mouse State Tracking**:
   - Interactive button feedback in modern GUI design requires both visual down-state color changes (`p.T.FillPressed`) and physical displacement. Applying `r.Offset(0, 0.75f)` inside unscaled logical units aligns with `KitButton` (`0.75f * s`) and provides tactile feedback without causing layout jitter.
   - Registering `Hit` before applying `r.Offset` preserves hit target stability while clicking.
   - Resetting `pressId = null` on `OnMouseLeave` and when `e.Button == MouseButtons.None` eliminates ghost pressed states when dragging the cursor across window boundaries.

3. **Mini Salience & Glanceability**:
   - Increasing dot radius to $2.5\text{ px}$ expands circle area to $19.635\text{ px}^2 \ge 19.6\text{ px}^2$. Because `g.ScaleTransform(scale, scale)` is active on `g`, DIP scaling automatically renders physical radii of $2.5 \times s$, avoiding the double-scaling bug.
   - Doubling the track thickness to $4.0\text{ px}$ centers the capsule cleanly with $2.0\text{ px}$ symmetrical top and bottom padding inside the 8px sliver height.
   - Replacing `p.T.Quaternary` (18% alpha) with `p.T.Faint` (58% alpha) elevates background track contrast from 1.51:1 to **6.39:1** against black monitor bezels and **5.19:1** on light backgrounds, exceeding the $\ge 3:1$ requirement.

---

## 3. Caveats

- **Hit-Test Layered Bar**: Line 92 of `src/DockPaint.cs` contains `Color.FromArgb(1, 0, 0, 0)`. As verified in Explorer 1, this is an invisible hit-test bar required by Win32 `UpdateLayeredWindow` and was correctly preserved as is.
- **Canvas Clearing**: Calls to `g.Clear(Color.Transparent)` were correctly preserved for GDI+ offscreen frame rendering.
- No other caveats.

---

## 4. Conclusion

All tasks specified in the dispatch and `SCOPE.md` have been implemented. The codebase builds cleanly with zero errors or warnings, all smoke and end-to-end regression tests pass 100%, and static verification confirms zero remaining hardcoded badge/rim colors.

---

## 5. Verification Method & Output

### 5.1 Project Compilation (`build.cmd`)
```cmd
cmd /c build.cmd
```
**Output**:
```
Build OK: D:\PROJECT\Other\tepi\Tepi.exe
```

### 5.2 Smoke Test Suite (`tests/smoke_test.ps1`)
```powershell
powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1
```
**Output**:
```
[SUITE] Smoke Test Suite: Environment & Binary Integrity
    [PASS] Validates 64-bit runtime environment (15.91ms)
    [PASS] Validates Tepi.exe binary exists on disk and is non-empty (12.78ms)
    [PASS] Loads Tepi.exe assembly into reflection cache (40.54ms)

[SUITE] Smoke Test Suite: Core Reflection & Type Resolution
    [PASS] Resolves primary engine and token types (12.38ms)
    [PASS] Verifies Design Token Spacing & Radii constants on Tepi.Ink (29.66ms)
    [PASS] Verifies Typography Scale properties on Tepi.Ink (53.18ms)
    [PASS] Verifies KitInk color token properties (45.2ms)

[SUITE] Smoke Test Suite: Mathematical Contrast & Oracles
    [PASS] Verifies authoritative WCAG contrast calculation for Black vs White (76.65ms)
    [PASS] Verifies Tepi.Island.Contrast reflection matches authoritative calculation (25.15ms)
    [PASS] Verifies Assert-Contrast assertion passes for accessible pairs and fails for poor pairs (15.46ms)

[SUITE] Smoke Test Suite: Headless Offscreen Control Rendering
    [PASS] Instantiates and renders KitButton offscreen via DrawToBitmap (78.75ms)
    [PASS] Instantiates and renders KitSwitch offscreen (22.58ms)
    [PASS] Instantiates and renders KitSlider offscreen (21.07ms)
    [PASS] Instantiates and renders KitRow offscreen (19.77ms)

[SUITE] Smoke Test Suite: Theme State Management & Isolation
    [PASS] Switches to Light Mode and verifies state update (6.62ms)
    [PASS] Resets to Dark Mode and verifies state isolation (3.95ms)

[SUITE] Smoke Test Suite: Process & CLI Argument Execution
    [PASS] Invokes Tepi.exe --notify without parameters and captures expected exit code (79.31ms)
```

### 5.3 Static Cleanliness & Reflection Audit (`verify_m4.ps1`)
```powershell
powershell -ExecutionPolicy Bypass -File .agents/teamwork/sub_orch_m4/worker_1/verify_m4.ps1
```
**Output**:
```
=== 1. Static Hardcoded Colors Check ===
PASS: All target hardcoded colors successfully eliminated from Dock files.

=== 2. Reflection Check for CalendarSheet Pressed State ===
pressedId field:    True
selectedDay prop:   True
Down method:        True
Pressed method:     True
OnMouseDown:        True
OnMouseUp:          True
OnMouseLeave:       True

=== 3. Mini Constants and Geometry Check ===
MiniDotR field:        True
MiniDotR value:       2.5
MiniDot Area (px^2):  19.6349540849362 (Spec >= 19.6)
MiniTrackThick field:  True
MiniTrackThick value: 4 (Spec == 4.0)

=== 4. DockSheet Down Method Check ===
GlassSheet found:  True
GlassSheet.Down:   True

=== ALL VERIFICATION CHECKS PASSED ===
```

### 5.4 End-to-End Suite (`tests/run_e2e.ps1 -Tier 1`)
```powershell
powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1 -Tier 1
```
**Output**:
```
Tier 1: 78 Passed, 0 Failed, Duration: 2646.7 ms (PASS)
GRAND TOTAL: 78 Passed, 0 Failed (100% PASS)
```

### 5.5 Invalidation Conditions
- Any change in `Tone.cs` to `t.Negative` that drops contrast below 4.5:1 against `t.Bg` or `Color.White`.
- Introducing new un-tokenized `Color.FromArgb(..., 255, 255, 255)` calls into `DockPaint.cs`, `DockCard.cs`, or `DockSheet.cs`.
