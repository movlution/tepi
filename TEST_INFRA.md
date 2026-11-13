# Tepi End-to-End (E2E) Test Infrastructure Specification

**Document Version**: 1.0.0  
**Target Application**: Tepi (`Tepi.exe`)  
**Target Platform**: Windows 10/11 x64, .NET Framework 4.8  
**Author**: Test Infrastructure Architect & Test Writer  
**Milestone**: TM1 — Test Infrastructure & Harness Foundation  
**Status**: ACTIVE  

---

## 1. Test Philosophy & Design Principles

### 1.1 Opaque-Box, Requirement-Driven Verification
The Tepi E2E Test Suite operates strictly from an **opaque-box** perspective. Tests treat the compiled target binary (`Tepi.exe`) as a black box with observable interfaces. Tests are authored strictly against documented requirements from `ORIGINAL_REQUEST.md`, architectural specifications in `PROJECT.md`, and design token guidelines in `docs/analisis/`.

Key principles:
1. **Zero Source Code Mutation for Testing**: Production source files (`src/*.cs`) are never altered to accommodate test fixtures or bypass production logic.
2. **Binary Verification**: All assertions run against the executable produced by `build.cmd`.
3. **No Facade Tests**: Every test exercises real code paths, mathematical computations, design token registries, or rendered GDI+ surfaces. Hardcoding expectations without authoritative derivations or creating dummy passes is strictly forbidden.
4. **Authoritative Expected Outputs**: Expected values are derived from mathematical formulas (WCAG 2.1 relative luminance and contrast), documented design token values, or system invariants.

### 1.2 Zero External Dependencies
To ensure complete portability, frictionless continuous integration, and seamless local reproduction on standard developer machines, the test infrastructure requires **zero third-party dependencies**:
- **No external frameworks**: No Pester, NUnit, xUnit, or MSTest installation required.
- **No external package managers**: No NuGet, npm, pip, or Chocolatey packages.
- **Native Windows Tooling**: Powered entirely by native Windows PowerShell 5.1+ (or PowerShell 7+ on Windows) and the .NET Framework 4.8 CLR already bundled with the Windows operating system.

### 1.3 Determinism and State Isolation
Tepi's design tokens and theme engine rely on static singletons (`Ink.Base`, `Ink.Flip`, `Ink.Light`, `KitInk`). To prevent cross-test contamination and non-deterministic cascading failures:
- Every test suite and test case must operate within an isolated context.
- Before and after each test execution, the environment is restored using `Reset-TepiTheme`.
- In-memory bitmap rendering resources, GDI+ handles, and control instances are cleanly disposed via `.Dispose()`.

---

## 2. Comprehensive Feature Inventory

The following table provides the authoritative inventory of all 26 features under test, mapped from `PROJECT.md`, including their target milestone, impacted source files, and test coverage allocation across Tiers 1 through 4.

| # | Feature Name | Description | Source Files | Milestone | Test Modality | Target Tiers | Min. Tests |
|---|--------------|-------------|--------------|-----------|---------------|--------------|------------|
| 1 | Font Family Typo Corrections | Correct font family names in `Ink.cs` (`Display Semib` $\to$ `Display Semibold`, `Small Semibol` $\to$ `Small Semibold`) to guarantee valid GDI+ font weight resolution. | `src/Ink.cs:207,213` | M1 | Token Registry & GDI+ Font Resolution | T1, T2, T3, T4 | 12 |
| 2 | Light Mode Accent Preset Calibration | Calibrate all 7 preset accents (Biru, Hijau, Kuning, Oranye, Merah muda, Ungu, Navy) in light mode to achieve $\ge 3.5:1$ non-text contrast against `#F5F5F5`. | `src/Ink.cs:72-88`, `src/Prefs.cs:40-48` | M1 | Mathematical Reflection | T1, T2, T3, T4 | 14 |
| 3 | Frost Glass Adaptive Contrast Guard | Implement adaptive luminance contrast guard in `Glass.cs` for Frost material to prevent white text dropping below $4.5:1$ on pure white/high-luminance wallpapers. | `src/Glass.cs:326-327` | M1 | Mathematical Reflection & Image Processing | T1, T2, T3, T4 | 12 |
| 4 | Liquid Glass Color Space Blending | Fix linear luminance blending into non-linear sRGB bytes in `Glass.cs` to maintain target luminance ($\ge 0.62$) and $\ge 4.5:1$ contrast on dark wallpapers in light mode. | `src/Glass.cs:419-421` | M1 | Mathematical Reflection & Image Processing | T1, T2, T3, T4 | 12 |
| 5 | Custom Palette Contrast Floor | Enforce minimum contrast threshold in `Colors.DerivePalette` preventing user-selected low-contrast combinations (`text >= 7:1`, `sub >= 4.5:1`, `faint >= 3:1`). | `src/Colors.cs:69-95` | M1 | Mathematical Reflection | T1, T2, T3, T4 | 14 |
| 6 | Elevate `KitInk.Faint` Light Contrast | Increase `KitInk.Faint` light-mode mix from 0.57 to 0.65 in `src/Kit.cs:28` to ensure $\ge 4.5:1$ contrast across `Side`, `Group`, `Hover`, and `Line` surfaces. | `src/Kit.cs:28` | M2 | Token Registry & Mathematical Contrast | T1, T2, T3, T4 | 12 |
| 7 | `KitButton` Interactive States & Focus Ring | Implement pressed visual state in `KitButton.OnPaint` and replace text-colored focus stroke with a distinct, contrasting focus ring ($\ge 3:1$). | `src/Kit.cs:175-225` | M2 | Headless Offscreen Rendering | T1, T2, T3, T4 | 12 |
| 8 | `KitSwitch` Hover State & Dynamics | Add `OnMouseEnter`/`OnMouseLeave` hover feedback and visual transition on `KitSwitch` track and knob. | `src/Kit.cs:270-320` | M2 | Headless Offscreen Rendering | T1, T2, T3, T4 | 11 |
| 9 | `KitSlider` Disabled Thumb Contrast | Update `KitSlider.OnPaint` so disabled thumb renders using `KitInk.Disabled` instead of active `KitInk.Text`. | `src/Kit.cs:420-475` | M2 | Headless Offscreen Rendering | T1, T2, T3, T4 | 11 |
| 10 | `KitRow.MarkGlyph` Contrast Fix | Replace hardcoded `Brushes.Black` in `Kit.cs:587` with `KitInk.Text` and contrasting dot fill for dark/light theme compatibility. | `src/Kit.cs:587` | M2 | Token Registry & Offscreen Rendering | T1, T2, T3, T4 | 11 |
| 11 | `MenuLook` Submenu & Disabled Contrast | Adjust `Sub` mix in `src/Menus.cs:97` to $\ge 0.62$ to elevate light-mode submenu arrows and disabled items above WCAG AA $\ge 4.5:1$. | `src/Menus.cs:97` | M2 | Token Registry & Mathematical Contrast | T1, T2, T3, T4 | 11 |
| 12 | Eliminate Hardcoded Semantic Red | Replace hardcoded `Color.IndianRed` (`TaskEditor.cs:103,125`, `WorkWindow.cs:673`) and `Color.FromArgb(224,96,84)` (`WorkWindow.cs:601`) with `Ink.Base.Negative`. | `src/TaskEditor.cs`, `src/WorkWindow.cs` | M2 | Token Registry & Reflection | T1, T2, T3, T4 | 11 |
| 13 | Centralized Dialog Theme Propagation | Introduce static `KitWindow.BroadcastThemeChange()` and call in `ApplyThemeMode` to update all active open dialogs without reload. | `src/Kit.cs`, `src/Prefs.cs` | M2 | Reflection & Headless Form Lifecycle | T1, T2, T3, T4 | 11 |
| 14 | `KitAsk` Universal Title & Localization | Ensure `KitAsk` title is parameter-driven rather than hardcoded `"Tugas dan catatan"`, and wrap dialog action buttons in `Lang.T`. | `src/Kit.cs:690-745` | M2 | Reflection & String Invariant Verification | T1, T2, T3, T4 | 11 |
| 15 | `KuliaLogin` Tokenization & Modernization | Refactor `KuliaLogin` to inherit from `KitWindow`, adopt `KitButton`, and replace ad-hoc background/text colors with `KitInk` tokens. | `src/Kulia.cs:25-95` | M2 | Reflection & Type Hierarchy Analysis | T1, T2, T3, T4 | 11 |
| 16 | `ColorPicker` Loupe Token Alignment | Align loupe magnification window in `ColorPicker.cs` with theme tokens (replace hardcoded dark background and raw point font). | `src/ColorPicker.cs:140-210` | M2 | Token Registry & Offscreen Rendering | T1, T2, T3, T4 | 11 |
| 17 | Island `OnGlass()` Contrast Enforcement | Pass `tone.OnGlass()` during glass rendering in `Island.cs:846, 1244` ensuring secondary text maintains $\ge 4.5:1$ contrast on bright glass. | `src/Island.cs:846, 1244` | M3 | Mathematical Reflection & Token Registry | T1, T2, T3, T4 | 12 |
| 18 | Island Pill Elevation Shadow on Glass | Render subtle elevation shadow on glass pill ($H \le 60$) in `Island.cs:816` to maintain depth and visual separation over light wallpapers. | `src/Island.cs:816` | M3 | Offscreen Rendering & Pixel Sampling | T1, T2, T3, T4 | 11 |
| 19 | Island Approval Halo Reduced Motion | Guard halo breathing pulse animation in `Island.cs:1142` with system `Anim.Reduced` motion preference. | `src/Island.cs:1142` | M3 | Reflection & Invariant State Check | T1, T2, T3, T4 | 11 |
| 20 | Tabs Inverted Hover/Pressed Fill Fix | Correct inverted ternary state rendering in `src/Tabs.cs:519, 821, 832, 847` to `Pressed ? FillPressed : FillHover`. | `src/Tabs.cs:519, 821, 832, 847` | M3 | Headless Offscreen Rendering & Pixel Sampling | T1, T2, T3, T4 | 11 |
| 21 | Toast Notification Meta Text Collision | Fix width measurement and layout clipping in `src/Views.cs:755` so long application names do not overlap with notification title. | `src/Views.cs:755` | M3 | Offscreen Rendering & Layout Geometry | T1, T2, T3, T4 | 11 |
| 22 | Standardize Empty State Component | Consolidate `Panel.Empty` (`src/Panel.cs:13-20`) into shared `Parts.EmptyState` (`src/Parts.cs:374`). | `src/Panel.cs`, `src/Parts.cs` | M3 | Type Analysis & Rendering Invariants | T1, T2, T3, T4 | 11 |
| 23 | Typography & Radius Scale Consolidation | Replace ad-hoc font sizes with the 7 type scale roles and consolidate arbitrary corner radii to `RadiusShell/Module/Control`. | `src/Ink.cs`, `src/Parts.cs`, `src/Views.cs` | M3 | Token Registry & Geometry Invariants | T1, T2, T3, T4 | 12 |
| 24 | Dock Hardcoded Colors Tokenization | Replace `BadgeRed`, `BadgeRedSoft`, and white rim lights in `DockPaint.cs` & `DockCard.cs` with `p.T.Negative`, `p.T.Highlight`, and `p.T.Text`. | `src/DockPaint.cs`, `src/DockCard.cs` | M4 | Token Registry & Pixel Sampling | T1, T2, T3, T4 | 12 |
| 25 | Dock Module Interactive States | Add pressed state feedback and visual click depth to buttons in `DockCal.cs` and related dock popouts. | `src/DockCal.cs:110-160` | M4 | Headless Offscreen Rendering | T1, T2, T3, T4 | 11 |
| 26 | Mini Indicator Visual Salience | Increase notification dot radius from 1.7px to $\ge 2.5$px and thicken status track in `src/Mini.cs` for reliable visual perception. | `src/Mini.cs:65-120` | M4 | Token Registry & Offscreen Pixel Geometry | T1, T2, T3, T4 | 11 |

---

## 3. Test Architecture: The 4 Testing Modalities

Testing a custom GDI+ owner-drawn WinForms application in an opaque-box manner requires four complementary testing modalities. Each modality targets a specific architectural layer of `Tepi.exe`.

```
+-----------------------------------------------------------------------------------+
|                            Tepi E2E Test Runner                                   |
+-----------------------------------------------------------------------------------+
        |                         |                         |                    |
        v                         v                         v                    v
+---------------+         +---------------+         +---------------+    +---------------+
|  Modality A   |         |  Modality B   |         |  Modality C   |    |  Modality D   |
| Mathematical  |         | Design Token  |         |   Headless    |    |  Process/CLI  |
|  & Contract   |         |  & Typo Scale |         |   Offscreen   |    |   Execution   |
|  Reflection   |         |   Registry    |         |   Rendering   |    |   & Concur.   |
+---------------+         +---------------+         +---------------+    +---------------+
| WCAG Contrast |         | Font Families |         | DrawToBitmap  |    | build.cmd     |
| Luma / Linear |         | Spacing Scale |         | Pixel Color   |    | --notify      |
| Palette Floor |         | Radii Tokens  |         | Button States |    | --run         |
| Color Mix/Over|         | Tone Values   |         | Focus Rings   |    | Mutex Guard   |
+---------------+         +---------------+         +---------------+    +---------------+
```

### 3.1 Modality A: Mathematical & Contract Reflection
- **Scope**: Direct validation of algorithmic color transformations, luminance calculations, and WCAG contrast evaluations.
- **Execution Mechanism**: Reflection invocation via `Invoke-TepiStaticMethod` and direct field inspection via `Get-TepiStaticField`.
- **Target Subsystems**:
  - `Tepi.Island.Contrast(Color a, Color b)`
  - `Tepi.Island.DerivePalette(Color bg, Color text, Color accent)`
  - `Tepi.Ink.Mix(Color a, Color b, float k)`
  - `Tepi.Ink.Over(Color top, Color bottom)`
  - Relative luminance calculations:
    $$\text{Luminance}(C) = 0.2126 \times R_{\text{lin}} + 0.7152 \times G_{\text{lin}} + 0.0722 \times B_{\text{lin}}$$
    $$\text{Contrast}(C_1, C_2) = \frac{\max(L_1, L_2) + 0.05}{\min(L_1, L_2) + 0.05}$$
- **Verification Criteria**:
  - All normal text vs background contrast $\ge 4.5:1$ (WCAG AA).
  - All large text & graphical UI components $\ge 3.0:1$.
  - All 7 preset accents in light mode $\ge 3.5:1$ against `#F5F5F5`.
  - Palette floor enforcement guaranteeing `text >= 7:1`, `sub >= 4.5:1`, `faint >= 3:1`.

### 3.2 Modality B: Design Token & Typography Registry Inspection
- **Scope**: Verification of centralized token structures, elimination of arbitrary hardcoded values, and validation of typographic hierarchy.
- **Execution Mechanism**: Inspection of static properties and fields on `Tepi.Ink`, `Tepi.KitInk`, and `Tepi.Tone`.
- **Target Tokens**:
  - **Typography Scale**: `Hero` (40pt), `Title1` (22pt), `Title2` (17pt), `Headline` (14.5pt), `Body` (13.5pt), `Callout` (12.5pt), `Caption` (11pt).
  - **Corner Radii Tokens**: `RadiusShell` (32px), `RadiusModule` (20px), `RadiusControl` (12px).
  - **Spacing Tokens**: `Sp4` (4px), `Sp8` (8px), `Sp12` (12px), `Sp16` (16px), `Sp20` (20px), `Sp24` (24px), `Sp32` (32px).
  - **Font Families**: Verification of correct weight resolution (`Segoe UI Variable Display Semibold` and `Segoe UI Variable Small Semibold`).
  - **Semantic Negative**: Verification that `Ink.Base.Negative` is used in place of ad-hoc `IndianRed`.

### 3.3 Modality C: Headless Offscreen WinForms Rendering via `DrawToBitmap`
- **Scope**: Verification of interactive visual states, focus rings, hover transitions, and owner-drawn rendering without displaying desktop windows.
- **Execution Mechanism**:
  1. Instantiation of WinForms controls via reflection (`[Activator]::CreateInstance([Type])`).
  2. Configuration of control dimensions and states (`Size`, `Text`, `Enabled`, `Checked`).
  3. Direct offscreen rendering into a memory-backed GDI+ `System.Drawing.Bitmap` using `Control.DrawToBitmap(Bitmap, Rectangle)`.
  4. Pixel-level inspection via `Bitmap.GetPixel(x, y)` to sample rendered borders, backgrounds, glyphs, and focus indicators.
  5. Deterministic disposal of GDI+ bitmaps and control handles.
- **Key Advantages**:
  - 100% headless execution (safe for CI and automated pipelines).
  - No focus stealing, window flashing, or display resolution dependencies.
  - Sub-millisecond rendering cycle per control.

### 3.4 Modality D: Process & CLI Execution
- **Scope**: Verification of command-line entrypoints, exit codes, IPC bridge behavior, and instance concurrency.
- **Execution Mechanism**: Launching `Tepi.exe` as a subprocess using PowerShell `Start-Process` or `System.Diagnostics.Process`.
- **Target Invocations**:
  - `build.cmd`: Clean compilation and zero exit code verification.
  - `Tepi.exe --notify <title> <detail>`: Toast notification parameter validation and exit code verification.
  - `Tepi.exe --run <command>`: Headless command runner invocation.
  - `Tepi.exe --statusline`: Standard input JSON processing and statusline formatting.
  - Single-instance mutex validation (`Settings.MutexName`).

---

## 4. Multi-Tier Testing Hierarchy & Coverage Thresholds

The test suite is structured into four distinct tiers to provide exhaustive verification across individual features, edge boundaries, system interactions, and realistic end-user workflows.

```
+-----------------------------------------------------------------------------------+
|                        Tier 4: Real-World Scenarios                               |
|                13 End-to-End User Journeys (>= 13 Tests)                          |
+-----------------------------------------------------------------------------------+
|                     Tier 3: Cross-Feature Interactions                            |
|             Pairwise Subsystem Matrix & Transitions (>= 26 Tests)                 |
+-----------------------------------------------------------------------------------+
|                     Tier 2: Boundary & Corner Cases                               |
|             Wallpapers, Extremes, Motion, Locales (>= 130 Tests)                  |
+-----------------------------------------------------------------------------------+
|                     Tier 1: Feature Coverage (Happy Path)                         |
|             >= 5 Dedicated Tests per Feature (>= 130 Tests)                       |
+-----------------------------------------------------------------------------------+
```

### 4.1 Coverage Thresholds by Tier
- **Tier 1 (Feature Coverage)**: $\ge 5$ test assertions per feature $\times 26$ features = **$\ge 130$ tests**.
- **Tier 2 (Boundary & Corner Cases)**: $\ge 5$ boundary assertions per feature $\times 26$ features = **$\ge 130$ tests**.
- **Tier 3 (Cross-Feature Interactions)**: $\ge 26$ pairwise interaction test cases = **$\ge 26$ tests**.
- **Tier 4 (Real-World Scenarios)**: $\ge 13$ end-to-end application scenarios = **$\ge 14$ tests**.
- **Total Minimum Target**: **$\ge 300$ automated tests**.

---

## 5. Tier 4 Real-World Application Scenario Specifications

Tier 4 tests model realistic, comprehensive user workloads that integrate multiple subsystems simultaneously.

### Scenario S01: First-Run Onboarding Tour & Default Theme Initialization
- **Description**: Simulates the initial startup experience of a new user. The application boots with default settings, initializes design tokens, loads system fonts, and establishes the default dark theme.
- **Subsystems Exercised**: `Ink.Init()`, `Ink.Apply(false)`, `TypeScale`, `ToneOf`, `RadiusControl`.
- **Verification Criteria**:
  - Default theme initializes with `Ink.Light = false`.
  - All 7 type scale font instances resolve without font-fallback degradation.
  - `Ink.Base.Bg` and `Ink.Base.Text` maintain $\ge 7.0:1$ contrast ratio.
  - Default radius tokens match 32px (Shell), 20px (Module), 12px (Control).

### Scenario S02: Theme Switcher & Accent Preset Cycling
- **Description**: Simulates a user navigating Settings and cycling through all 7 accent presets in both Light Mode and Dark Mode.
- **Subsystems Exercised**: `Ink.SetAccent()`, `Ink.Apply()`, `Prefs.ApplyThemeMode()`, `KitInk`.
- **Verification Criteria**:
  - In light mode (`Ink.Light = true`), all 7 presets maintain $\ge 3.5:1$ non-text contrast against `#F5F5F5`.
  - `KitInk.Accent` and `KitInk.OnAccent` achieve $\ge 4.5:1$ contrast across all 14 theme/accent combinations.
  - `KitInk.Faint` maintains $\ge 4.5:1$ against `KitInk.Side`, `KitInk.Group`, `KitInk.Hover`, and `KitInk.Line`.

### Scenario S03: High-Contrast Custom Palette Derivation & Persistence
- **Description**: Simulates a user selecting custom background, text, and accent colors via the Color Picker or theme configuration file.
- **Subsystems Exercised**: `Island.DerivePalette()`, `Island.Contrast()`, contrast floor guards.
- **Verification Criteria**:
  - Extreme low-contrast inputs (e.g. low-luminance yellow on white) are automatically adjusted by the palette contrast floor.
  - Derived `text` achieves $\ge 7:1$ against `bg`.
  - Derived `sub` achieves $\ge 4.5:1$ against `bg`.
  - Derived `faint` achieves $\ge 3:1$ against `bg`.
  - Derived `card.text` and `card.onAccent` satisfy standard readability minimums.

### Scenario S04: Frosted Glass HUD over Dynamic Wallpaper Transitions
- **Description**: Simulates the floating Island HUD positioned over diverse desktop wallpapers (pure black, pure white, and vibrant saturated backgrounds).
- **Subsystems Exercised**: `FrostJob`, `Plate`, `Glass.cs`, `Island.OnGlass()`.
- **Verification Criteria**:
  - On pure white background (`#FFFFFF`), the adaptive Frost contrast guard prevents text contrast from dropping below $4.5:1$.
  - On pure black background (`#000000`), text contrast is maintained above $4.5:1$.
  - Glass pill elevation shadow renders with appropriate opacity ($H \le 60$) over light backgrounds.

### Scenario S05: Liquid Glass Shader Rendering under Extreme Background Luminance
- **Description**: Simulates the Liquid Glass material pass across extreme luminance gradients.
- **Subsystems Exercised**: `LiquidPass`, `Luma`, `Linear` blending tables.
- **Verification Criteria**:
  - Linear luminance blending in sRGB byte space preserves target luminance ($\ge 0.62$ in light mode).
  - Background edges maintain vivid contrast without color saturation clipping or overflow artifacts.

### Scenario S06: Task & Note Management Lifecycle with Semantic Status Badges
- **Description**: Simulates opening the Task Editor, creating tasks, flagging items as overdue/urgent, and deleting notes.
- **Subsystems Exercised**: `TaskEditor`, `WorkWindow`, `Ink.Base.Negative`, `Parts.EmptyState`.
- **Verification Criteria**:
  - Overdue and destructive actions render using `Ink.Base.Negative` instead of hardcoded `IndianRed`.
  - Contrast of `Ink.Base.Negative` against dialog backgrounds is $\ge 4.5:1$ in both light and dark modes.
  - Empty task list renders unified `Parts.EmptyState` with consistent typography and iconography.

### Scenario S07: Settings Window Configuration & Interactive Control States
- **Description**: Simulates a user interacting with all controls inside the Settings dialog (`KitWindow`, `KitButton`, `KitSwitch`, `KitSlider`, `KitRow`).
- **Subsystems Exercised**: `KitButton`, `KitSwitch`, `KitSlider`, `KitRow`, `KitInk`.
- **Verification Criteria**:
  - `KitButton` in Normal, Hover, and Pressed states renders distinctly with $\ge 3:1$ focus ring contrast.
  - `KitSwitch` displays clear hover feedback on track and knob upon mouse enter.
  - `KitSlider` in disabled state renders thumb with `KitInk.Disabled` rather than active text color.
  - `KitRow` mark glyph renders with `KitInk.Text` without black-brush clipping on dark backgrounds.

### Scenario S08: Modal Dialog Stacking & Dynamic Broadcast Theme Propagation
- **Description**: Simulates opening multiple stacked modal dialogs (`KitAsk`, `TaskEditor`, `Prefs`), followed by triggering an external theme switch.
- **Subsystems Exercised**: `KitWindow.BroadcastThemeChange()`, `Prefs.ApplyThemeMode()`, `KitAsk`.
- **Verification Criteria**:
  - Invoking `KitWindow.BroadcastThemeChange()` instantly propagates token updates to all registered dialog instances.
  - `KitAsk` displays dynamic, localized title and action button text via `Lang.T`.
  - Window frame, background, and child control colors update synchronously without window recreation.

### Scenario S09: Color Picker Loupe Sampling & Precision Visual Display
- **Description**: Simulates activating the screen color picker loupe to inspect pixel colors.
- **Subsystems Exercised**: `ColorPicker`, `ColorLoupe`, token alignment.
- **Verification Criteria**:
  - Loupe magnification form renders using `KitInk` background and text tokens.
  - Hex readouts and coordinates use standard typography scale rather than hardcoded point fonts.
  - Contrast between crosshairs and sampled pixels remains visually distinguishable.

### Scenario S10: Media Player Island HUD & Dynamic Approval Breathing Halo
- **Description**: Simulates media playback notifications on the Island HUD with album art backdrop and approval halo pulses.
- **Subsystems Exercised**: `Island.cs`, `Anim.Reduced`, `Tone.OnGlass()`.
- **Verification Criteria**:
  - When `Anim.Reduced` is enabled, halo breathing animation is cleanly suppressed to static indicator.
  - Secondary metadata (track title, artist, duration) rendered on glass passes `tone.OnGlass()` with contrast $\ge 4.5:1$.

### Scenario S11: Toast Notification Ingestion under Extreme Metadata Collisions
- **Description**: Simulates the external CLI posting toast notifications with exceptionally long app names and detailed notification payloads.
- **Subsystems Exercised**: `Tepi.exe --notify`, `Views.cs` toast measurement, text truncation.
- **Verification Criteria**:
  - Notifications with titles exceeding 100 characters and long application headers do not collide or overlap.
  - Geometry measurements enforce text clipping with ellipses without overlapping sibling labels.
  - CLI exit code returns `0` on successful dispatch.

### Scenario S12: Dock Surface Interaction, Rim Lighting & Unread Pill Indicators
- **Description**: Simulates desktop edge docking, displaying unread notification badges, and opening dock flyout cards.
- **Subsystems Exercised**: `DockPaint.cs`, `DockCard.cs`, `p.T.Negative`, `p.T.Highlight`.
- **Verification Criteria**:
  - Unread badge pills render using semantic negative token `p.T.Negative` with white text contrast $\ge 4.5:1$.
  - Dock surface rim light adapts dynamically to theme tokens (`p.T.Highlight` and `p.T.Text`) rather than hardcoded white.
  - Flyout card close buttons maintain interactive hover and pressed depth.

### Scenario S13: Minimalist Edge Sliver (Mini) Status Visualization & Salience Verification
- **Description**: Simulates collapsing the application into the minimal edge sliver mode (`Mini`) on the screen border.
- **Subsystems Exercised**: `Mini.cs`, dot salience, progress track.
- **Verification Criteria**:
  - Notification indicator dot radius measures $\ge 2.5$px (area $\ge 19.6\text{ px}^2$, up from legacy 1.7px).
  - Background status track thickness is increased for immediate visual glanceability.
  - Active and idle indicator colors maintain $\ge 3:1$ contrast against the host monitor edge border.

---

## 6. Test Suite Directory Structure & Execution Architecture

```
tests/
├── run_e2e.ps1                      # Master CLI Test Runner orchestrator
├── smoke_test.ps1                   # Infrastructure & reflection smoke test suite
├── common/
│   ├── TestHarness.ps1              # Core assertion library and test execution harness
│   └── TepiLoader.ps1               # Binary loader, reflection helpers, and offscreen renderers
├── tier1_features/                  # Tier 1: Feature Coverage (>= 5 tests/feat, >= 130 tests)
│   ├── test_f01_typography.ps1
│   ├── test_f02_accents.ps1
│   ├── ...
│   └── test_f26_mini_salience.ps1
├── tier2_boundaries/                # Tier 2: Boundary & Corner Cases (>= 5 tests/feat, >= 130 tests)
│   ├── test_b01_font_fallbacks.ps1
│   ├── test_b02_accent_extremes.ps1
│   ├── ...
│   └── test_b26_mini_boundaries.ps1
├── tier3_interactions/              # Tier 3: Cross-Feature Pairwise Interactions (>= 26 tests)
│   ├── test_x01_theme_dialogs.ps1
│   ├── test_x02_accent_glass.ps1
│   ├── ...
│   └── test_x26_palette_dock.ps1
└── tier4_scenarios/                 # Tier 4: Real-World Application Workloads (>= 13 scenarios)
    ├── test_s01_onboarding.ps1
    ├── test_s02_theme_cycling.ps1
    ├── ...
    └── test_s13_mini_salience.ps1
```

### 6.1 CLI Test Runner Usage (`run_e2e.ps1`)
The test runner provides a standardized command-line interface with exit code contracts:

```powershell
# Run the complete test suite (all tiers)
.\tests\run_e2e.ps1

# Run a specific tier (e.g. Tier 1 or Tier 4)
.\tests\run_e2e.ps1 -Tier 1
.\tests\run_e2e.ps1 -Tier 4

# Run all tests targeting a specific feature (e.g. Feature 2: Light Mode Accents)
.\tests\run_e2e.ps1 -Feature 2

# Force recompilation of Tepi.exe using build.cmd before running tests
.\tests\run_e2e.ps1 -Rebuild

# Run a single specific test file
.\tests\run_e2e.ps1 -TestFile tests\smoke_test.ps1

# Verbose output with per-assertion traces
.\tests\run_e2e.ps1 -Verbose
```

### 6.2 Exit Code Contract
- Exit Code `0`: All executed tests passed cleanly.
- Exit Code `1`: One or more tests failed, or a fatal build/runtime error occurred.

---

## 7. Quality Gates & Acceptance Criteria

A milestone track is considered **TEST_READY** only when:
1. `build.cmd` compiles cleanly without warnings or errors.
2. All Tier 1 through Tier 4 test suites execute cleanly via `run_e2e.ps1`.
3. Total automated test count across all tiers is $\ge 300$ tests.
4. Pass rate is 100% (zero failures, zero regressions).
5. All 26 features in the inventory have verified coverage across all four testing modalities.
