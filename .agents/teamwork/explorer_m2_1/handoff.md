# Handoff Report: UI Toolkit Core Controls & Menus Contrast (Milestone 2)

**Author**: Explorer 1 (`teamwork_explorer`)  
**State Folder**: `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_1\`  
**Target Recipient**: Parent Sub-Orchestrator M2 (`789fb24f-4dc5-451b-991c-640bde73cdc8`)  
**Type**: Hard Handoff (Task Complete)

---

## 1. Observation

### 1.1 Target Source Locations & Lines
1. **`KitInk.Faint`**:
   - Path: `src/Kit.cs:27-28`
   - Verbatim:
     ```csharp
     // 0.57 keeps settings-window metadata above 4.5:1 (0.38 measured ~2.5-3.3:1)
     public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.57f)); } }
     ```
2. **`MenuLook.Sub`**:
   - Path: `src/Menus.cs:97`
   - Verbatim:
     ```csharp
     static Color Sub { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.5f)); } }
     ```
   - Referenced in `src/Menus.cs:127`: `e.TextColor = e.Item.Enabled ? Text : Sub;`
   - Referenced in `src/Menus.cs:149`: `e.ArrowColor = Sub;`
3. **`KitButton`**:
   - Path: `src/Kit.cs:383-422`
   - Verbatim:
     ```csharp
     Color bg = Primary ? (hovered ? Ink.Mix(KitInk.Text, KitInk.Window, 0.15f) : KitInk.Text) : (hovered ? KitInk.Hover : KitInk.Line);
     ...
     if (ringOn)
     {
         var ring = new RectangleF(1, 1, Width - 2.5f, Height - 2.5f);
         using (var path = Ink.Round(ring, ring.Height / 2f))
         using (var pen = new Pen(KitInk.Text, 1.6f)) g.DrawPath(pen, path);
     }
     ```
   - `OnMouseDown` only sets `KitInk.ByMouse = true;`. There is no `pressed` tracking or `OnMouseUp` override.
4. **`KitSwitch`**:
   - Path: `src/Kit.cs:168-214`
   - Verbatim: Does not override `OnMouseEnter` or `OnMouseLeave`. Track and knob retain fixed colors/sizes when hovered.
5. **`KitSlider`**:
   - Path: `src/Kit.cs:360-363`
   - Verbatim:
     ```csharp
     Fill(g, new RectangleF(t.X, t.Y, Math.Max(t.Height, t.Width * f), t.Height), t.Height / 2, Enabled ? KitInk.Text : KitInk.Disabled);
     float r = (dragging || Hovered ? 9 : 8) * s, cx = t.X + t.Width * f, cy = t.Y + t.Height / 2;
     using (var b = new SolidBrush(KitInk.Text)) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
     ```
   - Line 362 unconditionally uses `new SolidBrush(KitInk.Text)` for the thumb even when `Enabled == false`.
6. **`KitRow.MarkGlyph`**:
   - Path: `src/Kit.cs:584-590`
   - Verbatim:
     ```csharp
     if (Glyph == MarkGlyph)
     {
         var pill = new RectangleF(tile.X + 5 * s, tile.Y + 10 * s, 20 * s, 10 * s);
         using (var p2 = Ink.Round(pill, 5 * s)) g.FillPath(Brushes.Black, p2);
         using (var dot = new SolidBrush(KitInk.Text)) g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);
         return;
     }
     ```
   - Hardcoded `Brushes.Black` for pill background. In light mode, `KitInk.Text` is RGB(12, 12, 14).
7. **Dialog Theme Broadcast**:
   - Path: `src/Kit.cs:613-685` (`KitWindow`), `src/Prefs.cs:58-81` (`ApplyThemeMode`, `SetAccentHex`)
   - `KitWindow` has no static registry of active windows. `Prefs.cs:65-66` hardcodes calls to only `prefs.Relayout()` and `chatWin.Relayout()`.
8. **`KitAsk`**:
   - Path: `src/Kit.cs:713-755`
   - Line 738: `Text = "Tugas dan catatan";` (hardcoded title).
   - Lines 745-746: `yes.Text = confirm; no.Text = dismiss; ok.Text = "Tutup";` (not wrapped in `Lang.T`).

### 1.2 Quantitative Measurements & Tool Verifications
- Executed PowerShell relative luminance & WCAG contrast calculation script:
  - `KitInk.Faint` (0.57f) Light Mode:
    - Window: 4.54:1
    - Group: 4.19:1 (FAIL)
    - Side: 4.07:1 (FAIL)
    - Hover: 3.75:1 (FAIL)
    - Line: 3.50:1 (FAIL)
  - `KitInk.Faint` (0.65f) Light Mode:
    - Window: 6.03:1 (PASS)
    - Group: 5.57:1 (PASS)
    - Side: 5.42:1 (PASS)
    - Hover: 4.98:1 (PASS)
    - Line: 4.66:1 (PASS)
  - `MenuLook.Sub` Light Mode:
    - Current (0.50f) vs Menu Bg (231, 231, 231): **3.19:1** (FAIL WCAG AA text)
    - Proposed (0.62f) vs Menu Bg: **4.71:1** (PASS WCAG AA text $\ge 4.5:1$, arrow $\ge 3.0:1$)
    - Proposed (0.65f) vs Menu Bg: **5.24:1** (PASS WCAG AA)
  - `KitRow.MarkGlyph` Light Mode:
    - Dot (RGB 12, 12, 14) vs Pill (`Brushes.Black` RGB 0, 0, 0): **1.08:1** (INVISIBILITY BUG)
    - With `KitInk.Text` pill & `KitInk.Window` dot: **17.92:1** (PASS WCAG AAA)

---

## 2. Logic Chain

1. **Light Mode Surface Backgrounds Require Higher Text Mix**:
   - Observation 1.1 & 1.2 show that while `Faint` at 0.57f meets 4.5:1 against bare `Window` (`#F5F5F5`), real UI elements place faint text inside `KitGroup` (mix 0.035), `Side` (mix 0.05), `Hover` (mix 0.09), and `Line` (mix 0.12).
   - Raising the mix factor to `0.65f` in Light Mode lowers luminance to $L = 0.1096$. Even against the darkest light surface (`Line`, $L = 0.6931$), contrast is $4.66:1 \ge 4.5:1$.
   - Preserving `0.57f` in dark mode prevents faint text from becoming overly bright ($L = 0.2580$, contrast $5.89:1$). Hence `Ink.Light ? 0.65f : 0.57f` is mathematically sound.

2. **Menu Arrow & Disabled Item Contrast Alignment**:
   - `MenuLook.Sub` currently uses `0.5f`, resulting in 3.19:1 against menu background.
   - Submenu arrows and disabled items fail readability standards.
   - Aligning `MenuLook.Sub` with `KitInk.Sub` (`0.62f` or `Ink.Light ? 0.65f : 0.62f`) yields 4.71:1 (or 5.24:1), passing WCAG AA.

3. **Primary Button Focus Ring Must Be Inverted or Accent-Colored**:
   - On a Primary button, the button fill is `KitInk.Text`.
   - Drawing a focus ring using `new Pen(KitInk.Text, 1.6f)` produces identical stroke and fill colors with 0 contrast.
   - Shifting the focus ring to `KitInk.Accent` (with a fallback to system blue `#1668E8`/`#3B82F6` for monochrome mode) provides guaranteed $\ge 3.38:1$ contrast against the button body and $\ge 4.82:1$ against the window, satisfying WCAG 2.1 SC 2.4.7 and SC 1.4.11.

4. **Tactile Interaction Requires State Dynamics**:
   - `KitButton` and `KitSwitch` currently lack pressed/hover feedback.
   - Adding `pressed` tracking with a downward offset (`r.Offset(0, 0.75f)`) and deeper tone mix provides instant tactile confirmation.
   - Adding `hovered` tracking to `KitSwitch` with track illumination and knob enlargement (`9.0s` $\to$ `9.5s`) provides modern OS affordance.

5. **Token Alignment Fixes Semantic Rendering Bugs**:
   - `KitSlider` hardcoding `KitInk.Text` on line 362 defeats the purpose of `KitInk.Disabled`. Replacing with `Enabled ? KitInk.Text : KitInk.Disabled` aligns thumb and track.
   - `KitRow.MarkGlyph` hardcoding `Brushes.Black` while drawing `KitInk.Text` dot causes complete dot invisibility in light mode. Replacing pill with `KitInk.Text` and dot with `KitInk.Window` gives $> 17.9:1$ contrast across all themes.

6. **Decoupled Theme Propagation via Static Registry**:
   - `KitWindow` is the base class for all Tepi dialog forms (`Prefs`, `SuruhChat`, `TaskEditor`, `ColorPicker`, `KitAsk`, `KuliaLogin`).
   - Tracking instances in `KitWindow.openWindows` and broadcasting via `KitWindow.BroadcastThemeChange()` ensures theme updates trigger `Native.DarkFrame`, color refresh, and `Relayout()` across all open dialogs without hardcoding specific form references.

---

## 3. Caveats

- **No Caveats on Mathematical Soundness**: Contrast calculations are verified via standard WCAG 2.1 relative luminance algorithms.
- **Worker File Scoping**: Explorer 1 is strictly read-only. Source code modification in `src/Kit.cs`, `src/Menus.cs`, and `src/Prefs.cs` must be executed by the designated worker (`teamwork_worker`).
- **Thread Safety**: WinForms controls and forms operate on the UI message pump (STA thread). `openWindows` manipulation in `KitWindow` constructor, `OnClosed`, `Dispose`, and `BroadcastThemeChange()` is entirely thread-safe within the UI thread.
- **Language Dictionary**: `Lang.cs` contains `"Batal"` $\to$ `"Cancel"`, `"Tutup"` $\to$ `"Close"`, `"Hapus"` $\to$ `"Delete"`, `"Pemberitahuan"` $\to$ `"Alerts"`. If `"Konfirmasi"` is not yet mapped in `en` dictionary, `Lang.T("Konfirmasi")` gracefully returns `"Konfirmasi"`, but adding `{ "Konfirmasi", "Confirm" }` is recommended for full English localization.

---

## 4. Conclusion

All 8 focus items assigned to Explorer 1 have been analyzed down to exact source file lines, root causes, contrast mathematics, and drop-in code replacements:
1. `src/Kit.cs:28` $\to$ `Mix(Base.Bg, Base.Text, Ink.Light ? 0.65f : 0.57f)`
2. `src/Menus.cs:97` $\to$ `Mix(Base.Bg, Base.Text, Ink.Light ? 0.65f : 0.62f)`
3. `src/Kit.cs:383-422` $\to$ `KitButton` pressed state handling, offset, and contrasting focus ring
4. `src/Kit.cs:170-211` $\to$ `KitSwitch` hover state tracking on track and knob
5. `src/Kit.cs:361-363` $\to$ `KitSlider` disabled thumb using `KitInk.Disabled`
6. `src/Kit.cs:587-588` $\to$ `KitRow.MarkGlyph` pill in `KitInk.Text` and dot in `KitInk.Window`
7. `src/Kit.cs:613-685` $\to$ `KitWindow.BroadcastThemeChange()` static registry and tree refresh; wired in `src/Prefs.cs:65, 80`
8. `src/Kit.cs:723-755` $\to$ `KitAsk` dynamic title and `Lang.T` button localization

Full source snippets and contrast tables are documented in `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_1\analysis.md`.

---

## 5. Verification Method

To independently verify the findings and prospective changes:
1. **Mathematical Contrast Verification**:
   Run the PowerShell contrast script against the proposed RGB values:
   ```powershell
   $ch = { param($v) $s = $v / 255.0; if ($s -le 0.03928) { $s / 12.92 } else { [Math]::Pow(($s + 0.055) / 1.055, 2.4) } }
   function Lum($r,$g,$b) { 0.2126 * (& $ch $r) + 0.7152 * (& $ch $g) + 0.0722 * (& $ch $b) }
   function Contrast($l1, $l2) { ([Math]::Max($l1, $l2) + 0.05) / ([Math]::Min($l1, $l2) + 0.05) }

   # Check Line surface (217, 217, 217) vs Proposed Faint 0.65 (93, 93, 94):
   $c = Contrast (Lum 217 217 217) (Lum 93 93 94)
   Write-Output "Line vs Faint 0.65 Contrast: $c" # Yields 4.66:1 (>= 4.5:1)
   ```
2. **Code Inspection**:
   Inspect `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_1\analysis.md` for exact before/after code blocks.
3. **Compilation & Build Verification (for Worker / Reviewer)**:
   Once implemented by Worker, verify build using:
   `.\build.cmd`
   Check for zero compilation errors and clean `Tepi.exe` generation.
4. **Invalidation Condition**:
   If `Ink.Paper.Bg` or `Ink.Paper.Text` base values change, contrast ratios must be recalculated to ensure the $\ge 4.5:1$ floor is maintained.
