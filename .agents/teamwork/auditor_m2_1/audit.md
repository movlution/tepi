# Forensic Audit Report — Milestone 2

**Work Product**: Milestone 2 UI Toolkit & Dialog Modernization (`src/Kit.cs`, `src/Menus.cs`, `src/TaskEditor.cs`, `src/ColorPicker.cs`, `src/Kulia.cs`, `src/Prefs.cs`, `src/WorkWindow.cs`)  
**Profile**: General Project (C# / .NET Framework 4.8 WinForms)  
**Integrity Mode**: Development (defined in `ORIGINAL_REQUEST.md:8`)  
**Verdict**: **CLEAN**

---

### Phase 1: Mode-Agnostic Forensic Investigation

| # | Forensic Check | Result | Evidence / Finding |
|---|----------------|:------:|---------------------|
| 1 | **Hardcoded test results** | **PASS** | No test bypasses, no hardcoded expected output strings or test condition shortcuts found in project source. |
| 2 | **Facade implementations** | **PASS** | All controls (`KitButton`, `KitSwitch`, `KitSlider`, `KitPalette`, `KitRow`), dialogs (`KitAsk`, `KuliaLogin`, `ColorPicker.Loupe`), and broadcast routines implement authentic, complete GDI+ rendering and event handling logic. Zero dummy stubs or `NotImplementedException` facades. |
| 3 | **Pre-populated artifacts** | **PASS** | Workspace scan for pre-populated `.log`, `*result*`, and `*output*` files returned zero files. |
| 4 | **Build and run** | **PASS** | `cmd.exe /c build.cmd` executes cleanly with exit code 0. Binary `Tepi.exe` built at 1,783,808 bytes (SHA256: `A669EC7E1591D06D0332FE436C3D130AACB62E4345190BCA62045C48D958420F`). |
| 5 | **Behavioral verification** | **PASS** | 10 Tier 1 Feature suites (50 tests) and 11 Tier 2 Boundary suites (55 tests) executed independently and passed 100%. |
| 6 | **Semantic token audit** | **PASS** | Codebase scan across all `src/*.cs` confirmed zero remaining instances of `Color.IndianRed` or `Color.FromArgb(224, 96, 84)`. Replaced with `Ink.Base.Negative`. |

---

### Phase 2: Mode-Specific Flagging (Development Mode)

Under **Development Mode** (`ORIGINAL_REQUEST.md` line 8):
- Hardcoded test results: None detected (CLEAN)
- Facade implementation: None detected (CLEAN)
- Fabricated verification output: None detected (CLEAN)
- Genuine code implementation: Verified across all 12 target features (CLEAN)

---

### Detailed Component Integrity Analysis

#### 1. `KitInk.Faint` (`src/Kit.cs:28`)
- **Baseline**: Mix was `0.57f`, producing 3.50:1–4.19:1 contrast in light mode on non-window surfaces.
- **Audited Logic**:
  ```csharp
  public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)); } }
  ```
- **Verification**: Evaluated mathematically and empirically. In Light Mode ($L_{bg}=0.916$, $L_{text}=0.007$, mix 0.65 yields $L=0.1096$). Contrast ratios:
  - Window: 6.03:1 ($\ge 4.5:1$)
  - Group: 5.57:1 ($\ge 4.5:1$)
  - Side: 5.42:1 ($\ge 4.5:1$)
  - Hover: 4.98:1 ($\ge 4.5:1$)
  - Line: 4.66:1 ($\ge 4.5:1$)
- **Status**: Genuine, compliant with WCAG AA.

#### 2. `MenuLook.Sub` (`src/Menus.cs:97`)
- **Baseline**: Mix was `0.5f`, producing 3.19:1 contrast in light mode (failing WCAG AA).
- **Audited Logic**:
  ```csharp
  static Color Sub { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.62f)); } }
  ```
- **Verification**: Light mode yields 5.24:1 contrast against menu background (`0.06f` mix), comfortably exceeding the 4.5:1 threshold.
- **Status**: Genuine, compliant.

#### 3. `KitButton` (`src/Kit.cs:546-626`)
- **Baseline**: No pressed visual feedback. Focus ring stroke matched `KitInk.Text` on primary button (0 contrast).
- **Audited Logic**:
  - `bool pressed;` field tracked via `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave`.
  - On left click: `r.Offset(0, 0.75f * s);` tactile displacement.
  - Background tint deepened during pressed state:
    - Primary: `Ink.Light ? Color.FromArgb(255, 0, 0, 0) : Ink.Mix(KitInk.Text, KitInk.Window, 0.30f)`
    - Normal: `Ink.Light ? Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.20f) : Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.25f)`
  - Contrasting focus ring:
    ```csharp
    Color ringColor = KitInk.Accent;
    if (Island.Contrast(ringColor, bg) < 3.0 || (Primary && (ringColor == KitInk.Text || ringColor == bg)))
        ringColor = Ink.Light ? Color.FromArgb(255, 22, 104, 232) : Color.FromArgb(255, 59, 130, 246);
    ```
- **Status**: Genuine, high-contrast, robust mouse state management.

#### 4. `KitSwitch` (`src/Kit.cs:168-223`)
- **Baseline**: Static track and knob with no hover affordance.
- **Audited Logic**:
  - `bool hovered;` tracked via `OnMouseEnter` and `OnMouseLeave`.
  - In `OnPaint`:
    - Track luminance boost: `if (hovered && Enabled) trackBg = Ink.Mix(trackBg, KitInk.Text, 0.06f);`
    - Knob expansion: `float r = (hovered && Enabled ? 9.5f : 9f) * s;`
    - Knob highlight: `if (hovered && Enabled && knob == 0) knobColor = Ink.Mix(knobColor, KitInk.Window, 0.08f);`
- **Status**: Genuine dynamic rendering and event handling.

#### 5. `KitSlider` (`src/Kit.cs:524-527`)
- **Baseline**: Thumb rendered using active `KitInk.Text` even when `Enabled == false`.
- **Audited Logic**:
  - Line 524: `Fill(..., Enabled ? KitInk.Text : KitInk.Disabled);`
  - Line 526: `using (var b = new SolidBrush(Enabled ? KitInk.Text : KitInk.Disabled)) g.FillEllipse(...)`
  - Line 527: `using (var pen = new Pen(Enabled ? KitInk.Line : KitInk.Disabled, 1f)) g.DrawEllipse(...)`
- **Status**: Genuine tokenization.

#### 6. `KitRow.MarkGlyph` (`src/Kit.cs:788-796`)
- **Baseline**: Hardcoded `Brushes.Black` pill with `KitInk.Text` dot, rendering dot invisible (1.08:1) in Light Mode.
- **Audited Logic**:
  - Pill brush: `using (var pb = new SolidBrush(KitInk.Text)) g.FillPath(pb, p2);`
  - Dot brush: `using (var dot = new SolidBrush(KitInk.Window)) g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);`
- **Verification**: Contrast between `KitInk.Text` and `KitInk.Window` exceeds 14:1 in both light and dark themes (WCAG AAA compliant).
- **Status**: Genuine, high-contrast fix.

#### 7. Centralized Dialog Theme Propagation (`src/Kit.cs:826-913`)
- **Audited Logic**:
  - `static readonly List<WeakReference> openWindows = new List<WeakReference>();`
  - Registered in `KitWindow` constructor: `lock (openWindows) openWindows.Add(new WeakReference(this));`
  - Pruned in `OnClosed`, `Dispose(bool disposing)`, and in `BroadcastThemeChange()`.
  - Checked against `Application.OpenForms`.
  - Safely invokes `Native.DarkFrame`, `BackColor`, `ForeColor`, `Relayout()`, `RefreshTree(w)`, and `Invalidate(true)` via `BeginInvoke` when `InvokeRequired == true`.
- **Status**: Genuine, thread-safe, leak-free design.

#### 8. `KitAsk` (`src/Kit.cs:1008-1042`)
- **Baseline**: Hardcoded title `"Tugas dan catatan"`, hardcoded button text without localization.
- **Audited Logic**:
  - Constructor accepts `string title = null, string close = "Tutup"`.
  - Dynamic fallback: `Text = string.IsNullOrEmpty(title) ? Lang.T(question ? "Konfirmasi" : "Pemberitahuan") : title;`
  - Button text: `yes.Text = Lang.T(...)`, `no.Text = Lang.T(...)`, `ok.Text = Lang.T(...)`.
- **Status**: Genuine parameter-driven localization.

#### 9. `KuliaLogin` (`src/Kulia.cs:339-420`)
- **Baseline**: Inherited from raw WinForms `Form`, used raw `Button`, ad-hoc colors `Color.FromArgb(245, 245, 245)`, and manual P/Invoke.
- **Audited Logic**:
  - `class KuliaLogin : KitWindow`
  - Adopts `KitButton primary` and `KitButton back`
  - Adopts `KitText field`
  - Colors use `KitInk.Window`, `KitInk.Text`, `KitInk.Sub`, `KitInk.Group`
  - Validation errors use `Ink.Base.Negative`
  - Implements `public override void Relayout()`
  - Ad-hoc colors and obsolete P/Invoke removed.
- **Status**: Genuine architectural refactoring.

#### 10. `ColorPicker.Loupe` (`src/ColorPicker.cs:137-206`)
- **Baseline**: Hardcoded `BackColor = Color.FromArgb(18, 18, 18);`, point font allocations, hardcoded white text.
- **Audited Logic**:
  - `BackColor = KitInk.Window; ForeColor = KitInk.Text;`
  - Dual-stroke high-contrast reticle: outer dark stroke (`160, 0, 0, 0`) and inner light stroke (`Color.White`).
  - Swatch border: `KitInk.Line`.
  - Hex label: uses type scale token `Ink.Semi(13f)` and `KitInk.Text`.
  - Borderless window outline: `KitInk.Line`.
- **Status**: Genuine tokenization and contrast alignment.

#### 11. Elimination of Hardcoded Semantic Red (`src/TaskEditor.cs`, `src/WorkWindow.cs`)
- **Locations audited**:
  1. `src/TaskEditor.cs:103`: `warning.ForeColor = Ink.Base.Negative;`
  2. `src/TaskEditor.cs:125`: `warning.ForeColor = Ink.Base.Negative;`
  3. `src/WorkWindow.cs:314`: `saveState.ForeColor = saveFailed ? Ink.Base.Negative : KitInk.Sub;`
  4. `src/WorkWindow.cs:601`: `late ? Ink.Base.Negative : KitInk.Sub`
  5. `src/WorkWindow.cs:673`: `saveState.ForeColor = saveFailed ? Ink.Base.Negative : KitInk.Sub;`
- **Scan**: 0 occurrences of `IndianRed` or `224, 96, 84` across all `src/*.cs`.
- **Status**: Cleanly eradicated.

#### 12. Settings Appearance & Curated macOS Presets (`src/Prefs.cs:198-220, 1105-1160`)
- **Audited Logic**:
  - 8 curated accent presets in `Accents` and `AccentsLight`: Biru, Ungu, Merah muda, Merah, Oranye, Kuning, Hijau, Grafit.
  - Interactive circular swatch palette `KitPalette` embedded in `case "look"`.
  - Automatic accent sync across theme changes in `ApplyThemeMode()`.
  - `KitWindow.BroadcastThemeChange()` wired into `ApplyThemeMode()`, `SetAccentHex()`, and `SetCustom()`.
- **Status**: Genuine, elegant macOS-style appearance customization.

---

### Empirical Verification Results

#### 1. Compilation
- Command: `cmd.exe /c build.cmd`
- Exit Code: `0`
- Output: `Build OK: D:\PROJECT\Other\tepi\Tepi.exe`
- Binary SHA256: `A669EC7E1591D06D0332FE436C3D130AACB62E4345190BCA62045C48D958420F`

#### 2. Tier 1 Feature Test Suites (M2)
- `test_f06_kit_faint.ps1`: 6/6 PASS (100%)
- `test_f07_kit_button.ps1`: 5/5 PASS (100%)
- `test_f08_kit_switch.ps1`: 5/5 PASS (100%)
- `test_f09_kit_slider.ps1`: 5/5 PASS (100%)
- `test_f10_kit_row.ps1`: 5/5 PASS (100%)
- `test_f11_menu_look.ps1`: 5/5 PASS (100%)
- `test_f12_semantic_negative.ps1`: 5/5 PASS (100%)
- `test_f13_dialog_broadcast.ps1`: 5/5 PASS (100%)
- `test_f14_kit_ask.ps1`: 5/5 PASS (100%)
- `test_f15_kulia_login.ps1`: 5/5 PASS (100%)
- **Total**: 50/50 PASS (100%)

#### 3. Tier 2 Boundary Test Suites (M2)
- `test_b06_kit_faint_contrast.ps1`: 5/5 PASS (100%)
- `test_b07_button_states.ps1`: 5/5 PASS (100%)
- `test_b08_switch_hover.ps1`: 5/5 PASS (100%)
- `test_b09_slider_disabled.ps1`: 5/5 PASS (100%)
- `test_b10_mark_glyph.ps1`: 5/5 PASS (100%)
- `test_b11_menu_look.ps1`: 5/5 PASS (100%)
- `test_b12_semantic_red.ps1`: 5/5 PASS (100%)
- `test_b13_dialog_theme.ps1`: 5/5 PASS (100%)
- `test_b14_kit_ask.ps1`: 5/5 PASS (100%)
- `test_b15_kulia_tokens.ps1`: 5/5 PASS (100%)
- `test_b16_loupe_tokens.ps1`: 5/5 PASS (100%)
- **Total**: 55/55 PASS (100%)

#### 4. Auditor Adversarial Stress Suite (`adversarial_audit.ps1`)
- KitInk.Faint mix mathematical contrast: PASS
- Dark Mode KitInk.Faint contrast: PASS
- MenuLook.Sub contrast in Light & Dark: PASS
- KitButton pressed tracking and focus ring contrast: PASS
- KitRow.MarkGlyph inner dot vs pill contrast (WCAG AAA): PASS
- KitWindow weak registry pruning & zero memory leaks: PASS
- Codebase scan for Color.IndianRed and RGB(224,96,84): PASS
- KuliaLogin architecture & token inheritance: PASS
- Prefs curated 8 presets verification: PASS
- ColorPicker Loupe tokens & dual reticle: PASS
- **Total**: 10/10 PASS (100%)

---

### Final Assessment & Verdict

All requirements for Milestone 2 in `ORIGINAL_REQUEST.md` (R1) and `SCOPE.md` have been fully, authentically, and robustly implemented. No facades, no mocks, no cheating, and no shortcuts were found. All modified code adheres to high-standard design token contracts, WCAG AA/AAA contrast floors, and clean WinForms architecture.

**Final Audit Verdict**: **CLEAN**
