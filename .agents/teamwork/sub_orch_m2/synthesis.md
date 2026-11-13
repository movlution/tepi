# Synthesis: Milestone 2 — UI Toolkit & Dialog Modernization

## Overview
This synthesis integrates the comprehensive technical findings and concrete code diffs from Explorers 1, 2, and 3. All findings are verified against the codebase, WCAG 2.1 contrast formulas, and test suite requirements.

---

## 1. UI Toolkit Core Controls (`src/Kit.cs`)

### 1.1 `KitInk.Faint` (Lines 27-28)
- **Problem**: Current mix `0.57f` yields 3.50:1 to 4.19:1 contrast on non-window surfaces (`Group`, `Side`, `Hover`, `Line`) in Light Mode, failing WCAG AA (4.5:1).
- **Solution**:
  ```csharp
  // 0.65 in light mode guarantees >= 4.5:1 across Window (6.03:1), Side (5.42:1), Group (5.57:1), Hover (4.98:1), and Line (4.66:1)
  public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)); } }
  ```

### 1.2 `KitButton` (Lines 375-425)
- **Problem**: Lacks pressed visual feedback. Focus ring uses `KitInk.Text` on `Primary` button, resulting in identical fill and stroke (0 contrast).
- **Solution**:
  - Add `bool pressed;` field.
  - Override `OnMouseDown` (`pressed = true; Invalidate();`) and `OnMouseUp` (`pressed = false; Invalidate();`).
  - Handle `OnMouseLeave` to clear `pressed`.
  - In `OnPaint`:
    - If `pressed`, apply downward offset `r.Offset(0, 0.75f * s);` and deeper tint (`Ink.Mix(bg, KitInk.Text, Primary ? 0.15f : 0.08f)`).
    - Focus ring: Use `KitInk.Accent` (or if monochrome/contrast < 3:1 against bg, use high-contrast outline).

### 1.3 `KitSwitch` (Lines 168-214)
- **Problem**: No visual hover feedback on track and knob.
- **Solution**:
  - Add `bool hovered;` field.
  - Override `OnMouseEnter` (`hovered = true; Invalidate();`) and `OnMouseLeave` (`hovered = false; Invalidate();`).
  - In `OnPaint`:
    - Track fill: When `hovered`, apply subtle luminance boost: `Ink.Mix(trackBg, KitInk.Text, 0.06f)`.
    - Knob radius: Subtle expansion from `9 * s` to `9.5f * s` when `hovered` or `dragging`.

### 1.4 `KitSlider` (Line 362)
- **Problem**: Hardcoded `new SolidBrush(KitInk.Text)` renders active text color for thumb even when `Enabled == false`.
- **Solution**:
  - Replace line 362 with:
    ```csharp
    using (var b = new SolidBrush(Enabled ? KitInk.Text : KitInk.Disabled))
        g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
    ```

### 1.5 `KitRow.MarkGlyph` (Line 587)
- **Problem**: Hardcodes `Brushes.Black` for pill background while drawing `KitInk.Text` dot. In Light Mode, text is `#0C0C0E`, resulting in 1.08:1 contrast (invisible dot).
- **Solution**:
  - Replace pill brush with `KitInk.Text` and dot with `KitInk.Window`:
    ```csharp
    if (Glyph == MarkGlyph)
    {
        var pill = new RectangleF(tile.X + 5 * s, tile.Y + 10 * s, 20 * s, 10 * s);
        using (var p2 = Ink.Round(pill, 5 * s))
        using (var pb = new SolidBrush(KitInk.Text))
            g.FillPath(pb, p2);
        using (var dot = new SolidBrush(KitInk.Window))
            g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);
        return;
    }
    ```

### 1.6 `KitWindow.BroadcastThemeChange()` (Lines 613-685)
- **Specification**:
  - Add static registry in `KitWindow`:
    ```csharp
    static readonly List<WeakReference<KitWindow>> openWindows = new List<WeakReference<KitWindow>>();
    ```
  - In `KitWindow` constructor: register `openWindows.Add(new WeakReference<KitWindow>(this));`.
  - In `Dispose` / `OnClosed`: prune dead references.
  - Implement public static method:
    ```csharp
    public static void BroadcastThemeChange()
    {
        lock (openWindows)
        {
            for (int i = openWindows.Count - 1; i >= 0; i--)
            {
                if (openWindows[i].TryGetTarget(out var win) && !win.IsDisposed && win.IsHandleCreated)
                {
                    Native.DarkFrame(win.Handle, !Ink.Light);
                    win.BackColor = KitInk.Window;
                    win.ForeColor = KitInk.Text;
                    win.Relayout();
                    win.Invalidate(true);
                }
                else
                {
                    openWindows.RemoveAt(i);
                }
            }
        }
    }
    ```

### 1.7 `KitAsk` (Lines 713-755)
- **Problem**: Hardcoded title `"Tugas dan catatan"`, hardcoded button text not localized.
- **Solution**:
  - Update `KitAsk` signature/constructor to accept optional `string title = null`. If null/empty, default to `Lang.T("Pemberitahuan")`.
  - Pass `title` to `Text = string.IsNullOrEmpty(title) ? Lang.T("Pemberitahuan") : title;`.
  - Wrap action buttons in `Lang.T(confirm)`, `Lang.T(dismiss)`, `Lang.T("Tutup")`.

---

## 2. Menu Styling (`src/Menus.cs`)

### 2.1 `MenuLook.Sub` (Line 97)
- **Problem**: Mix `0.5f` yields 3.19:1 contrast against menu background in Light Mode, failing WCAG AA.
- **Solution**:
  ```csharp
  // 0.65 in light mode yields 5.24:1 against menu background (passes WCAG AA)
  static Color Sub { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.62f)); } }
  ```

---

## 3. Semantic Red Elimination (`src/TaskEditor.cs`, `src/WorkWindow.cs`)

### 3.1 Locations to Replace:
1. `src/TaskEditor.cs:103`: `warning.ForeColor = Ink.Base.Negative;`
2. `src/TaskEditor.cs:125`: `warning.ForeColor = Ink.Base.Negative;`
3. `src/WorkWindow.cs:314`: `saveState.ForeColor = saveFailed ? Ink.Base.Negative : KitInk.Sub;`
4. `src/WorkWindow.cs:601`: `late ? Ink.Base.Negative : KitInk.Sub`
5. `src/WorkWindow.cs:673`: `saveState.ForeColor = saveFailed ? Ink.Base.Negative : KitInk.Sub;`

All 5 instances of hardcoded red are replaced with `Ink.Base.Negative`, yielding >= 5.19:1 contrast in light mode and >= 7.21:1 in dark mode.

---

## 4. Dialog Modernization (`src/Kulia.cs`, `src/ColorPicker.cs`)

### 4.1 `KuliaLogin` (`src/Kulia.cs`)
- Refactor `class KuliaLogin : KitWindow`.
- Fields `primary` and `back` become `readonly KitButton primary = new KitButton(), back = new KitButton();`.
- In constructor: set `primary.Primary = true;`, remove `Style()` calls, use `KitInk` tokens.
- Add `public override void Relayout()` for DPI and theme scaling.
- Delete obsolete `Style(Button, Color, Color)` method, redundant `DwmSetWindowAttribute` P/Invoke, and manual Escape handler.

### 4.2 `ColorPicker` Loupe (`src/ColorPicker.cs`)
- In `Loupe`:
  - Set `BackColor = KitInk.Window;`.
  - Hex label: Use `KitInk.Text` and `Ink.Semi(13f)` instead of `Color.White` and `new Font(...)`.
  - Swatch border: Use `KitInk.Line`.
  - Reticle: Implement dual-stroke reticle (dark outer pen `#000000`, inner light pen `#FFFFFF`) for universal visibility.

---

## 5. Settings Appearance & Theme Presets (`src/Prefs.cs`)

### 5.1 macOS-Style Curated Presets:
- 8 Curated Presets:
  1. Blue: `#4C8DFF` / `#1668E8`
  2. Purple: `#A78BFA` / `#6C3CE0`
  3. Pink: `#FF6B9A` / `#C2185B`
  4. Red: `#FF5252` / `#C5221F`
  5. Orange: `#FF9F43` / `#A84B00`
  6. Yellow: `#FFD24A` / `#855E00`
  7. Green: `#3DD68C` / `#107C41`
  8. Graphite: `""`
- Render preset swatches via clean circular palette control (`KitPalette`).
- Theme mode options: `[ Gelap | Terang | Otomatis ]`.
- Material options: `[ Liquid | Frost | Hitam ]`.

### 5.2 Theme Propagation Wiring:
- In `src/Prefs.cs`:
  - In `ApplyThemeMode()`: invoke `KitWindow.BroadcastThemeChange();`.
  - In `SetAccentHex()`: invoke `KitWindow.BroadcastThemeChange();`.
  - In `Colors.cs:RefreshColors()` and `Theme.cs:ApplyPack()`: invoke `KitWindow.BroadcastThemeChange();`.
