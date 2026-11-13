# Handoff Report: Challenger 1 — Milestone 4 (Dock & Mini Polish)

**Author**: Challenger 1 (Empirical Challenger: Critic & Specialist)  
**Milestone**: Milestone 4 (Dock & Mini Polish)  
**Assigned Scope**: Adversarial empirical testing of Dock badge contrast, RimLight/Sheen tokenization, Mini dot/track geometry & contrast, and calendar module pressed states  
**Date**: 2026-11-13  
**Verdict**: **APPROVE**  

---

## 1. Observation

### 1.1 Direct Source Code Observations
- **`src/DockPaint.cs`**:
  - Line 216–220: `LinearGradientBrush` in `RimLight` uses `p.T.Highlight` for start/end colors, and blend stops:
    ```csharp
    cb.Colors = new[] { Color.FromArgb(Ink.Light ? 170 : 120, p.T.Highlight), Color.FromArgb(Ink.Light ? 50 : 16, p.T.Highlight), Color.FromArgb(Ink.Light ? 110 : 52, p.T.Highlight) };
    ```
  - Line 237–248: `Sheen` uses `Color.FromArgb(Ink.Light ? 80 : 24, p.T.Highlight)` and `Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), p.T.Highlight)`.
  - Line 260–264: `Rim` uses `Color.FromArgb(0, p.T.Highlight)` and `Color.FromArgb(peak, p.T.Highlight)`.
  - Line 654–656: `Badge` renders with:
    ```csharp
    p.FillRound(Inset(b, -1.2f), (h + 2.4f) / 2, Ink.A(p.T.Bg, 0.55f));
    p.FillRound(b, h / 2, p.T.Negative);
    p.TextCenter(s, f, p.T.IsDark ? p.T.Bg : Color.White, b.X + b.Width / 2, b.Y + h / 2);
    ```
    Hardcoded `BadgeRed` constant was completely removed.

- **`src/DockCard.cs`**:
  - Line 369–372: Sheen gradient stops use `p.T.Highlight`; border pen is `Color.FromArgb(Ink.Light ? 70 : 40, p.T.Highlight)`.
  - Line 413–414: Thumbnail close button hover fill uses `p.T.Negative` and close glyph icon uses:
    ```csharp
    hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub
    ```
    Hardcoded `BadgeRedSoft` constant was completely removed.

- **`src/DockSheet.cs`**:
  - Line 267–275: Sheen gradient stops and border pen use `p.T.Highlight`.
  - Line 326: `if (e.Button == MouseButtons.None && pressId != null) pressId = null;` clears stale press tracking.
  - Line 335: `pressId = null;` clears press state on `OnMouseLeave`.
  - Line 443: Helper `protected bool Down(string id) { return pressId == id && hotId == id; }`.
  - Line 475: Button tactile displacement `if (down) r.Offset(0, 0.75f);` and fill `down ? p.T.FillPressed : p.T.FillHover`.

- **`src/DockCal.cs`**:
  - Line 27: Tracking field `string pressedId;` and property `public DateTime? selectedDay { get; set; }`.
  - Line 45–46: Helper methods `public bool Pressed(string id)` and `public new bool Down(string id)`.
  - Line 48–56: `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave` event handlers managing `pressedId`.
  - Lines 80, 115, 144, 172, 200: Tactile displacement ($0.75\text{px}$) and `p.T.FillPressed` implemented on "clear", "del", month/today jump, day cells, and "quiet" toggle buttons.

- **`src/Mini.cs`**:
  - Line 17: Constants `const float MiniDotR = 2.5f, MiniTrackThick = 4f;`.
  - Lines 392, 401, 435: All 3 dot render sites (`MiniClockOn`, plain sliver, `MiniFace`) invoke `p.Circle(..., MiniDotR, ...)`.
  - Line 399: `right = dot ? w - 16 : w - 12;` providing layout clearance.
  - Lines 410, 414: Horizontal and vertical tracks thickened to `MiniTrackThick = 4f` using `p.T.Faint` background.

### 1.2 Binary AST & Compiled IL Observations
- In `Tepi.exe`, AST scan across `DockPaint.cs`, `DockCard.cs`, and `DockSheet.cs` revealed exactly **0** instances of `Color.FromArgb(..., 255, 255, 255)`.
- Disassembly and byte-level scanning of compiled IL in `Tepi.exe` revealed **20** distinct `ldfld` instructions loading field token `Tone.Highlight` (`0x04000021`) across:
  - `GlassSheet.Render` (3 instructions)
  - `DockCard.Render` (3 instructions)
  - `DockWindow.RimLight` (5 instructions)
  - `DockWindow.Sheen` (4 instructions)
  - `DockWindow.Rim` (5 instructions)
- Zero `ldc.i4 255` instructions feed `Color.FromArgb` in these rendering methods.

### 1.3 Mathematical Contrast & Geometry Oracles Output
Executing `tests/challenger1_m4_stress.ps1`:
```
[SUITE] 1. Dock Badge Contrast Empirical Oracles
       Dark Mode Badge Text (Color [A=255, R=0, G=0, B=0]) vs Pill (Color [A=255, R=240, G=120, B=120]): 7.66:1
       Dark Mode Badge Pill (Color [A=255, R=240, G=120, B=120]) vs Dock Surface (Color [A=255, R=0, G=0, B=0]): 7.66:1
       Adversarial verification: Hardcoded White on Dark Negative yields 2.74:1 (< 4.5:1 failure)
    [PASS] Verifies Dark Mode Dock Badge Text and Pill Contrast (>= 4.5:1) (140.64ms)
       Preset [Biru]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Biru]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Ungu]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Ungu]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Merah muda]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Merah muda]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Merah]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Merah]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Oranye]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Oranye]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Kuning]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Kuning]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Hijau]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Hijau]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
       Preset [Grafit]: Text (Color [White]) vs Pill (Color [A=255, R=190, G=50, B=50]) = 5.69:1
       Preset [Grafit]: Pill (Color [A=255, R=190, G=50, B=50]) vs Dock Surface (Color [A=255, R=245, G=245, B=245]) = 5.22:1
    [PASS] Verifies Light Mode Dock Badge Text and Pill Contrast Across All 8 Light Presets (>= 4.5:1) (131.04ms)
       DockCard Close Glyph (Dark=True): Glyph vs Pill = 7.66:1
       DockCard Close Glyph (Dark=False): Glyph vs Pill = 5.69:1
    [PASS] Verifies DockCard Close Button Glyph and Pill Contrast Across All Themes (10.65ms)

[SUITE] 2. RimLight and Sheen Tokenization Verification
    [PASS] Asserts complete absence of Color.FromArgb(..., 255, 255, 255) in Dock source files (25.69ms)
       DockPaint.cs p.T.Highlight occurrences: 14
       DockCard.cs p.T.Highlight occurrences: 3
       DockSheet.cs p.T.Highlight occurrences: 3
    [PASS] Asserts p.T.Highlight is explicitly used in DockPaint, DockCard, and DockSheet (11.06ms)
       Total compiled IL ldfld instructions to Tone.Highlight: 20 across methods: GlassSheet.Render, GlassSheet.Render, GlassSheet.Render, DockCard.Render, DockCard.Render, DockCard.Render, DockWindow.RimLight, DockWindow.RimLight, DockWindow.RimLight, DockWindow.RimLight, DockWindow.RimLight, DockWindow.Sheen, DockWindow.Sheen, DockWindow.Sheen, DockWindow.Sheen, DockWindow.Rim, DockWindow.Rim, DockWindow.Rim, DockWindow.Rim, DockWindow.Rim
    [PASS] Disassembles compiled IL to verify Tone.Highlight field is loaded in compiled rendering paths (163.28ms)

[SUITE] 3. Mini Indicator Geometry & Bezel Contrast Oracles
       Island.MiniDotR value: 2.5
       Calculated indicator circle area: 19.6349540849362 px^2 (Spec >= 19.6 px^2)
       p.Circle calls using MiniDotR: 3
    [PASS] Empirically validates MiniDotR radius and area against geometric specification (23.8ms)
       Island.MiniTrackThick value: 4
       Calculated clearance between progress track and indicator dot: 4.5px
       Sliver vertical track padding: 2px on top and bottom
    [PASS] Empirically validates MiniTrackThick thickness and layout bounds clearance (12.52ms)
       Dark Negative Dot (Color [A=255, R=240, G=120, B=120]) vs Black Bezel: 7.66:1, vs Charcoal: 6.35:1
       Light Negative Dot (Color [A=255, R=190, G=50, B=50]) vs Black Bezel: 3.69:1, vs Charcoal: 3.06:1
       Dark Track Background (Faint eff Color [A=255, R=142, G=142, B=143]) vs Black Bezel: 6.42:1, vs Charcoal: 5.32:1
    [PASS] Empirically verifies Indicator Dot and Status Track Contrast against Host Monitor Bezels (>= 3:1) (28.19ms)

[SUITE] 4. Dock Module Interactive Pressed State & Tactile Feedback Verification
    [PASS] Validates CalendarSheet pressedId tracking field and helper methods (16.01ms)
    [PASS] Validates GlassSheet base Down method and pressId clearance (26.8ms)
       Calendar buttons tactile displacement occurrences (0.75f): 5
       Calendar buttons FillPressed occurrences: 6
    [PASS] Validates tactile displacement (0.75f) and p.T.FillPressed in DockCal buttons (6.87ms)

========================================================
                TEST EXECUTION SUMMARY                  
========================================================
  Total Tests Run : 12
  Passed          : 12
  Failed          : 0
  Duration        : 596.55 ms
  Status          : ALL TESTS PASSED
========================================================
```

---

## 2. Logic Chain

1. **Dock Badge Contrast**:
   - In Dark Mode, `p.T.Negative` is `#F07878` ($L = 0.3324$). Prior legacy code rendered text as hardcoded `Color.White` ($L = 1.0$), resulting in $(1.0 + 0.05) / (0.3324 + 0.05) = 2.74:1$, which critically failed WCAG AA ($\ge 4.5:1$).
   - The tokenized formula `p.T.IsDark ? p.T.Bg : Color.White` switches badge text to `p.T.Bg` (`#000000`, $L = 0.0$) in dark mode. The resulting contrast is $(0.3324 + 0.05) / (0.0 + 0.05) = \mathbf{7.66:1} \ge 4.5:1$.
   - The badge pill (`#F07878`) on the dock surface (`p.T.Bg` = `#000000`) likewise achieves $\mathbf{7.66:1} \ge 4.5:1$.
   - In Light Mode, `p.T.Negative` is `#BE3232` ($L = 0.1340$). Badge text renders as `Color.White` ($L = 1.0$). Contrast is $(1.0 + 0.05) / (0.1340 + 0.05) = \mathbf{5.69:1} \ge 4.5:1$.
   - Across all 8 light mode presets (`Biru`, `Ungu`, `Merah muda`, `Merah`, `Oranye`, `Kuning`, `Hijau`, `Grafit`), the dock surface (`p.T.Bg` = `#F5F5F5`, $L = 0.9105$) against the badge pill (`#BE3232`) yields $(0.9105 + 0.05) / (0.1340 + 0.05) = \mathbf{5.22:1} \ge 4.5:1$. On extreme pure white wallpapers ($L = 1.0$), contrast is $\mathbf{5.71:1}$.
   - Thus, Dock badge contrast strictly satisfies $\ge 4.5:1$ across all theme modes and accent presets.

2. **RimLight and Sheen Tokenization**:
   - Hardcoded white (`Color.FromArgb(..., 255, 255, 255)`) previously bypassed theme customization, washing out glass highlights on bright wallpapers.
   - Replacing these with `p.T.Highlight` guarantees that highlight intensities adapt dynamically to `Ink.Light ? 110 : 23` alphas.
   - Static AST inspection confirms 0 remaining `255, 255, 255` occurrences in `DockPaint.cs`, `DockCard.cs`, and `DockSheet.cs`.
   - Reflection and IL byte analysis in `Tepi.exe` confirms 20 compiled `ldfld` operations on `Tone.Highlight` directly driving gradient and pen creation in rendering paths, with zero hardcoded constant pushes.

3. **Mini Indicator Salience & Bezel Contrast**:
   - The indicator dot radius was increased from legacy $1.7\text{px}$ to `MiniDotR = 2.5f`.
   - The geometric circle area is $\pi \times 2.5^2 = \mathbf{19.635\text{ px}^2} \ge 19.6\text{ px}^2$, meeting the required visual perceptibility threshold.
   - Status track thickness was doubled from $2\text{px}$ to `MiniTrackThick = 4.0f`, providing clean symmetrical $2.0\text{px}$ padding inside the $8\text{px}$ sliver.
   - Right margin was expanded to `right = dot ? w - 16 : w - 12;`. With dot center at $w - 9$ and radius $2.5$, the dot's left edge is at $w - 11.5$, leaving a guaranteed $(w - 11.5) - (w - 16) = \mathbf{4.5\text{px}}$ clearance, preventing layout collision between track and dot.
   - Contrast evaluation against black monitor bezel (`#000000`) and dark charcoal bezel (`#1A1A1A`) confirms:
     - Dark negative dot: $7.66:1$ and $6.35:1$ ($\ge 3:1$)
     - Light negative dot: $3.69:1$ and $3.06:1$ ($\ge 3:1$)
     - Background track (`p.T.Faint` effective): $6.42:1$ and $5.32:1$ ($\ge 3:1$)
     - All preset accents: $\ge 3.5:1$ up to $14.5:1$ ($\ge 3:1$).

4. **DockCal & DockSheet Interactive Pressed States**:
   - Mouse interaction requires down-state visual confirmation and tactile displacement.
   - In `DockCal.cs`, fields `pressedId` and `selectedDay`, methods `Down()` and `Pressed()`, and mouse handlers `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave` provide click tracking.
   - Buttons ("clear", "del", month/today jump, day cells, "quiet") implement $0.75\text{px}$ displacement (`b.Offset(0, 0.75f)` / `cy + 0.75f`) and `p.T.FillPressed` (or accent mix) when down.
   - `DockSheet.cs` ensures `pressId = null` is executed on mouse leave or when `e.Button == MouseButtons.None`, preventing sticky pressed states when dragging outside the control.

---

## 3. Caveats

- Win32 layered window hit-testing in `DockPaint.cs:92` uses `Color.FromArgb(1, 0, 0, 0)` by design to register pointer hits without visible obstruction. This is intentional Win32 architecture and not an un-tokenized color defect.
- Full multi-tier cross-feature permutation testing will run in Milestone 5 (E2E Integration & Verification).

---

## 4. Conclusion

The implementation delivered by Worker 1 has been rigorously stress-tested through white-box AST inspection, compiled IL disassembly, and mathematical WCAG 2.1 contrast and layout oracles. All four challenge dimensions passed empirical verification without defects.

**Final Verdict**: **APPROVE**

---

## 5. Verification Method

To independently reproduce and verify this assessment:

1. **Compile Application**:
   ```cmd
   cmd /c build.cmd
   ```
   *Expected: `Build OK: D:\PROJECT\Other\tepi\Tepi.exe`*

2. **Execute Challenger 1 M4 Stress Harness**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/challenger1_m4_stress.ps1 -Detailed
   ```
   *Expected: 12/12 tests pass (100% PASS)*

3. **Execute Smoke Test Suite**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1
   ```
   *Expected: 16/16 tests pass (100% PASS)*

4. **Execute Tier 1 E2E Regression Suite**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1 -Tier 1
   ```
   *Expected: 78/78 tests pass (100% PASS)*

### Invalidation Conditions
- Any code alteration modifying `p.T.Negative` in dark or light mode such that badge contrast falls below $4.5:1$.
- Any reintroduced hardcoded RGB `255, 255, 255` constants in Dock painting pipelines.
- Changing `MiniDotR` to $< 2.5\text{px}$ or `MiniTrackThick` to $< 4.0\text{px}$.
