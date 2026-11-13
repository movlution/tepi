# Visual & Contrast Review Report — Milestone 2
**Reviewer**: Reviewer 2 (Visual & Contrast Reviewer & Adversarial Critic)  
**Date**: 2026-11-12T23:50:00Z  
**Verdict**: **APPROVE**  
**Integrity Status**: **CLEAN — NO INTEGRITY VIOLATIONS DETECTED**

---

## 1. Executive Summary
This independent review validates the implementation of Milestone 2 (UI Toolkit & Dialog Modernization) for the Tepi visual overhaul. The evaluation encompassed independent mathematical calculations of WCAG relative luminance and contrast ratios, static code analysis across all 7 modified source files within the Exclusive Write Boundaries, execution of the full automated test suite (36/36 suites passing), adversarial stress-testing of interactive controls, and an integrity audit for facades or hardcoded shortcuts.

All 12 milestone feature requirements are implemented genuinely, cleanly, and robustly. Visual design and accessibility exceed WCAG 2.1 AA standards.

---

## 2. Independent Mathematical Verification: Contrast & Relative Luminance

All measurements were performed using standard WCAG 2.1 relative luminance formulas:
$$L = 0.2126 \cdot R_{lin} + 0.7152 \cdot G_{lin} + 0.0722 \cdot B_{lin}$$
$$\text{Contrast Ratio} = \frac{L_1 + 0.05}{L_2 + 0.05} \quad (\text{where } L_1 \ge L_2)$$

### 2.1 `KitInk.Faint` (Light Mode mix = 0.65f)
In Light Mode, `KitInk.Faint` is defined as `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.65f)`, yielding:
- **RGB**: `(93, 93, 94)` / `#5D5D5E`
- **Relative Luminance**: $L = 0.1096$

| Surface Container | Hex Color | Surface Luminance ($L$) | Contrast Ratio | WCAG AA Requirement | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Window** | `#F5F5F5` | 0.9131 | **6.03:1** | $\ge 4.5:1$ | **PASS** |
| **Side** | `#E9E9E9` | 0.8148 | **5.42:1** | $\ge 4.5:1$ | **PASS** |
| **Group** | `#ECECEC` | 0.8388 | **5.57:1** | $\ge 4.5:1$ | **PASS** |
| **Hover** | `#E0E0E0` | 0.7454 | **4.98:1** | $\ge 4.5:1$ | **PASS** |
| **Line** | `#D9D9D9` | 0.6939 | **4.66:1** | $\ge 4.5:1$ | **PASS** |

*Evaluation*: Prior to Milestone 2, `KitInk.Faint` used mix factor `0.57f` which produced 3.50:1 to 4.19:1 on non-window surfaces. Raising the mix to `0.65f` in Light Mode guarantees that every single container and control boundary exceeds the 4.5:1 threshold.

In Dark Mode (`0.57f` mix, `#8B8B8C`, $L = 0.2585$):
- vs Window (`#090909`, $L = 0.0027$): **5.85:1** (PASS)
- vs Side (`#111111`, $L = 0.0056$): **5.55:1** (PASS)
- vs Group (`#161616`, $L = 0.0080$): **5.32:1** (PASS)
- vs Line (`#242425`, $L = 0.0177$): **4.56:1** (PASS)

---

### 2.2 `MenuLook.Sub` Contrast
In `src/Menus.cs:97`, `Sub` is defined as `Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.62f))`:
- **Light Mode**:
  - Menu Background (`MenuLook.Bg`): `#E7E7E7` ($L = 0.7991$)
  - Submenu Text/Chevron (`MenuLook.Sub`): `#5D5D5E` ($L = 0.1096$)
  - **Contrast Ratio**: **5.32:1** ($\ge 4.5:1$, **PASS**)
  - *Baseline comparison*: Baseline mix `0.5f` yielded 3.19:1, failing WCAG AA. The calibrated mix elevates contrast by +66.7% above baseline.
- **Dark Mode**:
  - Menu Background: `#0E0E0E` ($L = 0.0044$)
  - Submenu Text/Chevron: `#979799` ($L = 0.3101$)
  - **Contrast Ratio**: **6.62:1** ($\ge 4.5:1$, **PASS**)

---

### 2.3 `Ink.Base.Negative` Semantic Token
All hardcoded instances of `Color.IndianRed` (`TaskEditor.cs:100, 122`, `WorkWindow.cs:314, 673`) and `Color.FromArgb(224, 96, 84)` (`WorkWindow.cs:601`) were replaced with `Ink.Base.Negative`.

- **Light Mode** (`#BE3232`, $L = 0.1346$):
  - vs `KitInk.Window` (`#F5F5F5`, $L = 0.9131$): **5.22:1** (PASS $\ge 4.5:1$)
  - vs `KitInk.Group` (`#ECECEC`, $L = 0.8388$): **4.82:1** (PASS $\ge 4.5:1$)
- **Dark Mode** (`#F07878`, $L = 0.3331$):
  - vs `KitInk.Window` (`#090909`, $L = 0.0027$): **7.27:1** (PASS $\ge 4.5:1$)
  - vs `KitInk.Group` (`#161616`, $L = 0.0080$): **6.60:1** (PASS $\ge 4.5:1$)

*Evaluation*: The calibrated negative semantic token ensures that all error, warning, late task, and save failure indications remain legible across all background and grouping containers in both themes.

---

### 2.4 `KitRow.MarkGlyph` Pill & Dot Contrast
In `src/Kit.cs:587`, the hardcoded `Brushes.Black` pill was replaced with `KitInk.Text` and the dot fill was replaced with `KitInk.Window`.

- **Light Mode**:
  - Pill Fill: `KitInk.Text` (`#0C0C0E`, $L = 0.0039$)
  - Dot Fill: `KitInk.Window` (`#F5F5F5`, $L = 0.9131$)
  - **Contrast Ratio**: **17.93:1** (PASS $\ge 4.5:1$)
- **Dark Mode**:
  - Pill Fill: `KitInk.Text` (`#F5F5F7`, $L = 0.9131$)
  - Dot Fill: `KitInk.Window` (`#090909`, $L = 0.0027$)
  - **Contrast Ratio**: **18.29:1** (PASS $\ge 4.5:1$)

*Evaluation*: Resolves the severe light-mode bug where the dot was previously `#0C0C0E` drawn on a black `#000000` pill (1.08:1 contrast, completely invisible). The mark glyph is now distinct and legible in both modes.

---

### 2.5 `KitButton` Focus Ring & Interactive States
- **Pressed Down-State**:
  - Tracked via `pressed` boolean on mouse down/up/leave.
  - Tactile displacement: `r.Offset(0, 0.75f * s)`.
  - Fill tone depth:
    - Primary: Darkened by 15-30% via `Ink.Mix`.
    - Secondary: Deepened from `Line` (0.12f/0.15f) to 0.20f/0.25f text mix.
- **Focus Ring Non-Text Contrast**:
  - Renders a 1.8px rounded pill outline enclosing the focused button.
  - Ring color logic:
    ```csharp
    Color ringColor = KitInk.Accent;
    if (Island.Contrast(ringColor, bg) < 3.0 || (Primary && (ringColor == KitInk.Text || ringColor == bg)))
        ringColor = Ink.Light ? Color.FromArgb(255, 22, 104, 232) : Color.FromArgb(255, 59, 130, 246);
    ```
  - Measurements for Fallback Focus Blue:
    - **Light Mode** (`#1668E8`, $L = 0.1590$):
      - vs Secondary Button Bg (`#D9D9D9`): **3.56:1** ($\ge 3:1$, **PASS**)
      - vs Primary Button Bg (`#0C0C0E`): **3.89:1** ($\ge 3:1$, **PASS**)
      - vs Window Container (`#F5F5F5`): **4.61:1** ($\ge 3:1$, **PASS**)
    - **Dark Mode** (`#3B82F6`, $L = 0.2355$):
      - vs Secondary Button Bg (`#242425`): **4.22:1** ($\ge 3:1$, **PASS**)
      - vs Primary Button Bg (`#F5F5F7`): **3.38:1** ($\ge 3:1$, **PASS**)
      - vs Window Container (`#090909`): **5.41:1** ($\ge 3:1$, **PASS**)

---

### 2.6 `KitSwitch` Hover State & Knob Expansion
- **Track Luminance Shift**:
  - `OnMouseEnter` / `OnMouseLeave` tracks `hovered` state.
  - Track background shifts 6% toward `KitInk.Text`: `trackBg = Ink.Mix(trackBg, KitInk.Text, 0.06f)`.
- **Knob Dynamics**:
  - Idle knob radius: $9.0f \cdot s$.
  - Hovered knob radius: $9.5f \cdot s$ (+5.5% expansion), providing responsive tactile feedback.
  - Off-knob hover luminance: shifts 8% toward Window to increase tactile salience.

---

### 2.7 `KitSlider` Disabled Thumb Contrast
- `KitSlider.OnPaint` now renders the thumb with:
  ```csharp
  using (var b = new SolidBrush(Enabled ? KitInk.Text : KitInk.Disabled))
      g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
  ```
- Contrast of `KitInk.Disabled` (`#AFAFAF` in Light Mode, `#49494A` in Dark Mode):
  - Light Mode vs Window: **2.01:1**
  - Dark Mode vs Window: **2.21:1**
- *Evaluation*: Disabled user interface elements are intentionally below 3:1 contrast in compliance with WCAG 2.1 SC 1.4.11 (Inactive User Interface Components Exception). Previously, the disabled slider thumb was drawn with active `KitInk.Text` (> 18:1 contrast), which gave users the false impression that the control was interactable. Using `KitInk.Disabled` visually indicates the inactive state.

---

## 3. Visual Design & Modernization Review

### 3.1 `KuliaLogin`
1. **Inheritance & Components**:
   - Refactored from raw `Form` to inherit from `KitWindow`.
   - Adopts `KitButton` for primary (`primary.Primary = true`) and secondary (`back`) buttons.
   - Adopts `KitText` for email/code inputs.
2. **DPI Awareness & Relayout**:
   - Implements `public override void Relayout()`.
   - Uses `float s = Ui; Func<float, int> u = v => (int)Math.Round(v * s);`.
   - Proportional padding (`u(24)`), window width (`u(400)`), button heights (`u(34)`), and button widths (`u(140)`).
   - Fonts use `Ink.Display(20f * s)` and type scale helpers `UiFont(12.5f)`, `UiFont(13f)`, `UiFont(14f)`.
3. **Absence of Ad-Hoc Colors**:
   - Zero hardcoded colors.
   - Window: `KitInk.Window`, `KitInk.Text`.
   - Field: `KitInk.Group`, `KitInk.Text`.
   - Error status: `Ink.Base.Negative`.
   - Obsolete `Style()` method and raw P/Invoke `DwmSetWindowAttribute` removed.

---

### 3.2 `ColorPicker.Loupe`
1. **Dual-Stroke High-Contrast Reticle**:
   - Outer stroke: `mid - 1, mid - 1, Zoom + 2, Zoom + 2` with `Pen(Color.FromArgb(160, 0, 0, 0), 1f)`.
   - Inner stroke: `mid, mid, Zoom, Zoom` with `Pen(Color.White, 1.5f)`.
   - Over pure black (`#000000`): Inner white box provides sharp contrast.
   - Over pure white (`#FFFFFF`): Outer dark box provides sharp contrast.
   - Over mid-tones: Both strokes provide dual-sided contrast.
2. **Typography & Token Alignment**:
   - Hex code renders using cached type scale token `Ink.Semi(13f)` with `KitInk.Text`.
   - Swatch border and loupe window border use `KitInk.Line`.
   - Background uses `KitInk.Window`.
   - Per-frame GDI+ `Font` instantiation leak resolved.

---

### 3.3 macOS-Style Appearance & Theme Presets (`src/Prefs.cs`)
1. **Curated Preset Architecture**:
   - 8 curated accents defined in `Accents` and `AccentsLight`:
     1. Blue: `#4C8DFF` / `#1668E8`
     2. Purple: `#A78BFA` / `#6C3CE0`
     3. Pink: `#FF6B9A` / `#C2185B`
     4. Red: `#FF5252` / `#C5221F`
     5. Orange: `#FF9F43` / `#A84B00`
     6. Yellow: `#FFD24A` / `#855E00`
     7. Green: `#3DD68C` / `#107C41`
     8. Graphite: `""` (renders `#8E8E93` light / `#A0A0A5` dark)
2. **`KitPalette` Swatch Control**:
   - Circular swatch layout with 15px diameter dots.
   - Active accent highlighted with concentric outline ring.
   - Hover state displays subtle translucent halo (`90` alpha).
   - Keyboard accessible: `Left`, `Right`, `Space`, `Enter`.
   - Clutter eliminated: Unnecessary sliders removed; clear segmented controls for Theme (`[ Gelap | Terang | Otomatis ]`) and Material (`[ Liquid | Frost | Hitam ]`).

---

### 3.4 Centralized Theme Propagation (`KitWindow.BroadcastThemeChange()`)
- Maintains a thread-safe registry of `WeakReference<KitWindow>`.
- Also sweeps `Application.OpenForms` to guarantee open dialogs are reached.
- On theme or accent change:
  - Invokes `Native.DarkFrame(w.Handle, !Ink.Light)` for title bar theme synchronization.
  - Updates `w.BackColor` and `w.ForeColor`.
  - Executes `w.Relayout()`.
  - Recursively updates child `KitGroup` controls and calls `w.Invalidate(true)`.
  - Safely handles cross-thread calls via `InvokeRequired` / `BeginInvoke`.
- Integrated into `Prefs.cs` at `ApplyThemeMode()`, `SetAccentHex()`, and `look.custom` toggle.

---

## 4. Integrity Audit

A comprehensive integrity audit was conducted across all changes:
- **No hardcoded test results or expected values**: All classes perform genuine GDI+ drawing, arithmetic blending, and state management.
- **No dummy or facade implementations**: All methods implement complete, working logic with zero stubs.
- **No shortcuts or rule bypasses**: The changes strictly adhered to the 7 target files within the Milestone 2 Exclusive Write Boundaries without touching other modules.
- **No fabricated verification**: Build outputs and test passes were reproduced and verified independently in this turn.
- **Integrity Finding**: **NO INTEGRITY VIOLATION FOUND. CLEAN.**

---

## 5. Adversarial Stress-Testing & Failure Mode Analysis

| # | Stress Scenario | Attack Hypothesis | Observed Behavior / Defense | Result |
| :--- | :--- | :--- | :--- | :--- |
| **A1** | Primary button with identical accent and text colors | Focus ring will blend into button fill (0:1 contrast) | Code explicitly falls back to calibrated blue if `Island.Contrast(ringColor, bg) < 3.0` or `Primary && (ringColor == KitInk.Text \|\| ringColor == bg)`. Fallback achieves 3.89:1 in light mode and 3.38:1 in dark mode. | **PASS** |
| **A2** | Reticle over pure white `#FFFFFF` and pure black `#000000` | Single-stroke reticle disappears over matching background | Dual-stroke reticle (outer dark + inner white) ensures one pen always contrasts against background. | **PASS** |
| **A3** | `Relayout()` called on unmapped / offscreen window | P/Invoke `Native.DarkFrame` or `Native.RoundCorners` throws exception on invalid HWND | Guarded by `if (!IsHandleCreated) return;`. Safely executes in offscreen test harnesses. | **PASS** |
| **A4** | Zero or negative DPI scaling factor `Ui` | Divide-by-zero or negative bounds in `KitButton` / `KitWindow` | Explicitly guarded with `if (s <= 0) s = 1f;`. Bounds and offsets remain valid. | **PASS** |
| **A5** | Theme broadcast with closed or garbage-collected windows | Memory leak or `NullReferenceException` during iteration | Stored as `WeakReference<KitWindow>`; dead targets are pruned during traversal. | **PASS** |

---

## 6. Build and Automated Test Suite Results

1. **Compilation (`build.cmd`)**:
   - Exit code: `0`
   - Output: `Build OK: D:\PROJECT\Other\tepi\Tepi.exe`
2. **Primary Milestone 2 Automated Tests**:
   - `test_f12_semantic_negative.ps1`: **5/5 PASS**
   - `test_f15_kulia_login.ps1`: **5/5 PASS**
   - `test_b12_semantic_red.ps1`: **5/5 PASS**
   - `test_b15_kulia_tokens.ps1`: **5/5 PASS**
   - `test_b16_loupe_tokens.ps1`: **5/5 PASS**
3. **Comprehensive Regression Test Suite**:
   - Total test suites run: **36**
   - Passed: **36**
   - Failed: **0**
   - Success rate: **100%**

---

## 7. Review Verdict
**Verdict**: **APPROVE**  
Milestone 2 implementation is thoroughly verified, accessible, visually cohesive, and production-ready.
