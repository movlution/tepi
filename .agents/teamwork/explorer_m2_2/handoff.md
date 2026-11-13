# Milestone 2 Handoff Report: Dialogs & Semantic Red Tokens

## 1. Observation
1. **Target Hardcoded Semantic Red Locations**:
   - In `src/TaskEditor.cs`:
     - Line 103: `warning.ForeColor = Color.IndianRed;`
     - Line 125: `warning.SetBounds((int)(20*s), (int)(212*s), (int)(440*s), (int)(30*s)); warning.ForeColor = Color.IndianRed;`
   - In `src/WorkWindow.cs`:
     - Line 314 (in `Relayout()`): `saveState.Font = fSmall; saveState.ForeColor = saveFailed ? Color.IndianRed : KitInk.Sub;`
     - Line 601 (in task row painting): `KitInk.Draw(g, ds, fSmall, late ? Color.FromArgb(224, 96, 84) : KitInk.Sub, new RectangleF(right - w, row.Y, w, row.Height), ContentAlignment.MiddleRight);`
     - Line 673 (in `SetSaveState()`): `saveState.ForeColor = saveFailed ? Color.IndianRed : KitInk.Sub;`
   - Ripgrep/PowerShell inspection (`Select-String -Path 'src\*.cs' -Pattern 'IndianRed'`) confirmed these are the only four lines in the entire codebase referencing `Color.IndianRed`.
   - Inspection of `Select-String -Path 'src\WorkWindow.cs' -Pattern 'Color\.'` confirmed that lines 314, 601, and 673 are the only hardcoded color assignments in `src/WorkWindow.cs`.

2. **`KuliaLogin` Structure in `src/Kulia.cs`**:
   - Lines 339-344:
     ```csharp
     class KuliaLogin : Form
     {
         readonly KuliaClient client;
         readonly Label heading = new Label(), hint = new Label(), status = new Label();
         readonly TextBox field = new KitText();
         readonly Button primary = new Button(), back = new Button();
     ```
   - Lines 348, 411-416: Local `DwmSetWindowAttribute` P/Invoke and manual dark mode caption setup:
     ```csharp
     [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
     ...
     protected override void OnHandleCreated(EventArgs e)
     {
         base.OnHandleCreated(e);
         int dark = Ink.Light ? 0 : 1;
         try { DwmSetWindowAttribute(Handle, 20, ref dark, 4); } catch (Exception) { }
     }
     ```
   - Lines 358-359: `Load += delegate { KitWindow.ScaleToDpi(this); }; HandleCreated += delegate { Native.RoundCorners(Handle); };`
   - Lines 363-366: Ad-hoc hardcoded color definitions:
     ```csharp
     var bg = Ink.Light ? Color.FromArgb(245, 245, 245) : Color.FromArgb(10, 10, 10);
     var fg = Ink.Light ? Color.FromArgb(10, 10, 10) : Color.FromArgb(244, 244, 244);
     var sub = Ink.Light ? Color.FromArgb(88, 88, 88) : Color.FromArgb(160, 160, 160);
     field.BackColor = Ink.Light ? Color.White : Color.FromArgb(24, 24, 24);
     ```
   - Lines 401-409: Obsolete custom `Style(Button, Color, Color)` method applied to standard `Button` controls.
   - Lines 393-394: Manual `KeyDown += (s, e) => { if (e.KeyCode == Keys.Escape) Close(); };`.

3. **`ColorPicker` Loupe in `src/ColorPicker.cs`**:
   - Line 137: `BackColor = Color.FromArgb(18, 18, 18);` (hardcoded dark window background).
   - Line 186: `using (var pen = new Pen(Color.White, 2)) g.DrawRectangle(pen, mid, mid, Zoom, Zoom);` (single pure white reticle, invisible over white samples).
   - Line 189: `using (var edge = new Pen(Color.FromArgb(120, 255, 255, 255))) g.DrawRectangle(edge, Pad, Pad + side + 7, 14, 14);` (semi-transparent white border, invisible on light surfaces).
   - Lines 190-191:
     ```csharp
     using (var f = new Font("Segoe UI Semibold", 10f, GraphicsUnit.Point))
         TextRenderer.DrawText(g, Island.HexOf(color), f, new Point(Pad + 20, Pad + side + 5), Color.White);
     ```
     Allocates a new `Font` on every paint event; renders hardcoded `Color.White` text which would be completely unreadable (contrast ~1.08:1) against a light theme background.

4. **Automated Test Expectations**:
   - `tests/tier1_features/test_f12_semantic_negative.ps1`:
     - Verifies `Ink.Base.Negative` is opaque (`A == 255`).
     - Verifies contrast $\ge 4.5:1$ against `Ink.Base.Bg` and `KitInk.Window` in both light and dark modes.
     - Verifies `src/TaskEditor.cs` and `src/WorkWindow.cs` do NOT match `Color.IndianRed`.
     - Verifies `src/WorkWindow.cs` does NOT match `Color.FromArgb(224,\s*96,\s*84)`.
   - `tests/tier1_features/test_f15_kulia_login.ps1`:
     - Verifies `KuliaLogin` type inherits from `KitWindow`.
     - Verifies private instance fields `primary` and `back` are of type `KitButton`.
     - Verifies `src/Kulia.cs` does NOT match `Color.FromArgb(245,\s*245,\s*245)`.
   - `tests/tier2_boundaries/test_b16_loupe_tokens.ps1`:
     - Verifies `PickerOverlay+Loupe` instance creation and offscreen rendering for pure black (`#000000`) and pure white (`#FFFFFF`) samples.

---

## 2. Logic Chain
1. **Semantic Red Contrast Failure (Observed in 1.1)**:
   - In light mode (`KitInk.Window` = `#F5F5F5`, $L = 0.916$), `Color.IndianRed` (`#CD5C5C`, $L = 0.214$) yields a contrast ratio of $3.66:1$.
   - `Color.FromArgb(224, 96, 84)` ($L = 0.247$) yields a contrast ratio of $3.25:1$.
   - Both fail WCAG 2.1 AA for normal text ($\ge 4.5:1$).
   - Replacing them with `Ink.Base.Negative` (which evaluates to `#BE3232`, $L = 0.136$ in light mode and `#F07878`, $L = 0.332$ in dark mode) produces contrast ratios of **5.19:1** (light mode) and **7.21:1** (dark mode).
   - In `src/WorkWindow.cs`, `Relayout()` at line 314 re-applies `saveFailed ? Color.IndianRed : KitInk.Sub`. Therefore, updating both line 314 and line 673 is required so DPI or theme changes do not revert `saveState` to the failing color.

2. **`KuliaLogin` Refactoring to `KitWindow` (Observed in 1.2)**:
   - `KitWindow` already sets `AutoScaleMode = AutoScaleMode.None`, `BackColor = KitInk.Window`, `ForeColor = KitInk.Text`, handles `Native.DarkFrame` and `Native.RoundCorners`, processes Escape keys via `ProcessDialogKey`, and supports DPI scaling through `Ui` and `Relayout()`.
   - By inheriting `KitWindow`, `KuliaLogin` can delete redundant P/Invoke declarations (`DwmSetWindowAttribute`), remove manual `Native.RoundCorners`, remove `KitWindow.ScaleToDpi(this)`, and remove `KeyDown += Escape`.
   - Replacing `primary` and `back` with `KitButton` provides automatic theme-aware hover transitions, pressed down-states, and keyboard focus rings, allowing complete deletion of the custom `Style(Button, Color, Color)` method.
   - Implementing `public override void Relayout()` enables `KuliaLogin` to respond directly to `KitWindow.BroadcastThemeChange()` without requiring application restart or ad-hoc event wiring.

3. **`ColorPicker` Loupe Token Alignment (Observed in 1.3)**:
   - Aligning `Loupe.BackColor` to `KitInk.Window` makes the loupe respect the active application theme.
   - Hex text must change from `Color.White` to `KitInk.Text` (`#0C0C0E` in light mode, `#F5F5F7` in dark mode) to avoid rendering white text on `#F5F5F5` window backgrounds.
   - Replacing `new Font("Segoe UI Semibold", 10f, GraphicsUnit.Point)` with `Ink.Semi(13f)` adopts the centralized typography token and eliminates GDI+ allocations on every mouse move.
   - Changing the swatch border from `Color.FromArgb(120, 255, 255, 255)` to `KitInk.Line` ensures visible swatch delineation against both light and dark backgrounds.
   - Adding a dual-stroke reticle (dark outer stroke at `mid - 1` and white inner stroke at `mid`) ensures the sampled pixel target remains clearly visible regardless of whether the sampled pixel is pure white or pure black.

---

## 3. Caveats
1. **`Loupe` Base Class**: `Loupe` remains a direct subclass of `System.Windows.Forms.Form` rather than `KitWindow`. This is intentional: `Loupe` requires `WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW` and overrides `ShowWithoutActivation => true` so that it never steals keyboard/mouse focus from `PickerOverlay`. `KitWindow` has window activation, taskbar, and fade-in behaviors that conflict with an unactivated cross-screen cursor overlay.
2. **`KuliaLogin` Status Color**: In `KuliaLogin`, the `status` label handles both neutral feedback ("Mengirim kode…", "Memeriksa kode…") and error messages ("Format email belum lengkap", "Gagal memeriksa kode"). A boolean flag `statusIsError` is introduced in `KuliaLogin` so errors render with `Ink.Base.Negative` while normal progress text renders with `KitInk.Text`.
3. **No Code Modification**: In strict accordance with the Teamwork Explorer protocol, no source files have been altered and no builds have been executed by this agent.

---

## 4. Conclusion
1. **Semantic Red**:
   - Update `src/TaskEditor.cs` at lines 103 and 125 from `Color.IndianRed` to `Ink.Base.Negative`.
   - Update `src/WorkWindow.cs` at lines 314 and 673 from `Color.IndianRed` to `Ink.Base.Negative`.
   - Update `src/WorkWindow.cs` at line 601 from `Color.FromArgb(224, 96, 84)` to `Ink.Base.Negative`.
2. **`KuliaLogin`**:
   - Refactor `class KuliaLogin : KitWindow`.
   - Change `primary` and `back` fields to `KitButton`.
   - Remove obsolete `Style()` helper, `DwmSetWindowAttribute` P/Invoke, and ad-hoc RGB colors.
   - Implement `public override void Relayout()` with scaled UI fonts and bounds.
3. **`ColorPicker` Loupe**:
   - Align `Loupe` background to `KitInk.Window`, hex text to `KitInk.Text`, swatch border to `KitInk.Line`.
   - Replace raw point font with cached type scale token `Ink.Semi(13f)`.
   - Implement dual-stroke contrast reticle and borderless frame border.

Detailed before/after diffs are fully documented in `analysis.md`.

---

## 5. Verification Method

### 5.1 Static Code Invariants
Run the following PowerShell check from repository root:
```powershell
# 1. Verify no Color.IndianRed remains in TaskEditor or WorkWindow
$t = Get-Content 'src\TaskEditor.cs' -Raw
$w = Get-Content 'src\WorkWindow.cs' -Raw
if ($t -match 'Color\.IndianRed') { Write-Error "TaskEditor.cs still contains Color.IndianRed" }
if ($w -match 'Color\.IndianRed') { Write-Error "WorkWindow.cs still contains Color.IndianRed" }

# 2. Verify no ad-hoc red remains in WorkWindow
if ($w -match 'Color\.FromArgb\(224,\s*96,\s*84\)') { Write-Error "WorkWindow.cs still contains Color.FromArgb(224, 96, 84)" }

# 3. Verify KuliaLogin inherits KitWindow and uses KitButton
$k = Get-Content 'src\Kulia.cs' -Raw
if (-not ($k -match 'class\s+KuliaLogin\s*:\s*KitWindow')) { Write-Error "KuliaLogin does not inherit KitWindow" }
if ($k -match 'Color\.FromArgb\(245,\s*245,\s*245\)') { Write-Error "Kulia.cs still contains ad-hoc background color" }
if ($k -match 'readonly\s+Button\s+primary') { Write-Error "primary button is not KitButton" }

# 4. Verify ColorPicker Loupe uses KitInk tokens and Ink.Semi
$cp = Get-Content 'src\ColorPicker.cs' -Raw
if ($cp -match 'Color\.FromArgb\(18,\s*18,\s*18\)') { Write-Error "ColorPicker.cs still contains hardcoded dark background" }
if ($cp -match 'Font\("Segoe UI Semibold"') { Write-Error "ColorPicker.cs still allocates raw point font" }
```

### 5.2 Automated Test Suite Execution
Once changes are applied by the worker and compiled via `build.cmd`, execute:
```powershell
powershell -ExecutionPolicy Bypass -File tests\tier1_features\test_f12_semantic_negative.ps1
powershell -ExecutionPolicy Bypass -File tests\tier1_features\test_f15_kulia_login.ps1
powershell -ExecutionPolicy Bypass -File tests\tier2_boundaries\test_b12_semantic_red.ps1
powershell -ExecutionPolicy Bypass -File tests\tier2_boundaries\test_b15_kulia_tokens.ps1
powershell -ExecutionPolicy Bypass -File tests\tier2_boundaries\test_b16_loupe_tokens.ps1
```
All five test suites must exit with code 0 and 0 failures.
