# Code Changes — Milestone 2: UI/UX Production Visual Overhaul

## Modified Files
All changes are strictly contained within the Exclusive Write Boundaries:
1. `src/Kit.cs`
2. `src/Menus.cs`
3. `src/TaskEditor.cs`
4. `src/ColorPicker.cs`
5. `src/Kulia.cs`
6. `src/Prefs.cs`
7. `src/WorkWindow.cs`

---

## Detailed Changes by File

### 1. `src/Kit.cs`
- **KitInk.Faint**: Raised Light Mode mix factor from `0.57f` to `0.65f`:
  `public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)); } }`
  Guarantees WCAG AA >= 4.5:1 text contrast across all container surfaces (`Window`, `Side`, `Group`, `Hover`, and `Line`).
- **KitSwitch**:
  - Added `bool hovered` tracking via `OnMouseEnter` and `OnMouseLeave`.
  - Added subtle luminance boost to track on hover (`Ink.Mix(trackBg, KitInk.Text, 0.06f)`).
  - Added knob expansion when hovered/enabled (`9.5f * s` vs `9f * s`) and subtle highlight on inactive knob.
- **KitPalette Control**:
  - Created interactive macOS-style circle swatch palette control (`KitPalette : KitControl`).
  - Supports 8 curated presets, selection concentric outer ring, hover halo, TabStop, keyboard navigation (Left/Right/Space/Enter), and click selection.
- **KitSlider**:
  - In `OnPaint`, fixed thumb rendering when disabled:
    `using (var b = new SolidBrush(Enabled ? KitInk.Text : KitInk.Disabled)) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);`
    `using (var pen = new Pen(Enabled ? KitInk.Line : KitInk.Disabled, 1f)) g.DrawEllipse(pen, cx - r, cy - r, r * 2, r * 2);`
    `float r = ((dragging || Hovered) && Enabled ? 9 : 8) * s;`
- **KitButton**:
  - Added `bool pressed` tracking via `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave`.
  - Added tactile down-state: offset `r.Offset(0, 0.75f * s)` and deeper background tint when pressed (`Color.FromArgb(255, 0, 0, 0)` in Light Primary, or deeper mix).
  - Contrasting focus ring: uses `KitInk.Accent`, and if contrast against surface < 3.0:1 or identical to text/surface, falls back to calibrated high-contrast focus blue (`#1668E8` in light mode, `#3B82F6` in dark mode).
- **KitRow.MarkGlyph**:
  - Replaced hardcoded `Brushes.Black` with `KitInk.Text` for pill background and `KitInk.Window` for the camera dot:
    `using (var pb = new SolidBrush(KitInk.Text)) g.FillPath(pb, p2);`
    `using (var dot = new SolidBrush(KitInk.Window)) g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);`
- **KitWindow.BroadcastThemeChange()**:
  - Added static registry: `static readonly List<WeakReference> openWindows = new List<WeakReference>();`.
  - Window registers in constructor and unregisters on `OnClosed` / `Dispose`.
  - Implemented `public static void BroadcastThemeChange()` to notify all open windows, invoke `Native.DarkFrame`, update `BackColor`/`ForeColor`, trigger `Relayout()`, refresh `KitGroup` tree, and invalidate.
- **KitAsk**:
  - Added constructor overloads and parameter `string title = null`, defaulting to `Lang.T("Pemberitahuan")` (or `Lang.T("Konfirmasi")` if question).
  - Wrapped action button labels in `Lang.T` (`Lang.T(confirm)`, `Lang.T(dismiss)`, `Lang.T(close)`).

### 2. `src/Menus.cs`
- **MenuLook.Sub**:
  - In line 97, elevated mix factor from `0.5f` to `Ink.Light ? 0.65f : 0.62f`:
    `static Color Sub { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.62f)); } }`
    Elevates disabled menu item text and submenu cascade arrows to >= 4.71:1 contrast against menu background.

### 3. `src/TaskEditor.cs`
- Replaced hardcoded `Color.IndianRed` in line 103 with `Ink.Base.Negative`.
- Replaced hardcoded `Color.IndianRed` in line 125 with `Ink.Base.Negative`.

### 4. `src/WorkWindow.cs`
- In line 314 (`Relayout()`): replaced `Color.IndianRed` with `Ink.Base.Negative`.
- In line 601 (`OnPaint` overdue badge): replaced `Color.FromArgb(224, 96, 84)` with `Ink.Base.Negative`.
- In line 673 (`SetSaveState`): replaced `Color.IndianRed` with `Ink.Base.Negative`.

### 5. `src/Kulia.cs`
- Refactored `KuliaLogin` to inherit from `KitWindow` instead of `Form`.
- Replaced standard `Button` with `KitButton` for `primary` (`Primary = true`) and `back`.
- Replaced ad-hoc colors (`Color.FromArgb(245, 245, 245)`, `(10, 10, 10)`, `(88, 88, 88)`, `(24, 24, 24)`) with `KitInk` tokens (`KitInk.Window`, `KitInk.Text`, `KitInk.Group`, `KitInk.Sub`, `Ink.Base.Negative`).
- Implemented `public override void Relayout()` for DPI and theme scaling.
- Cleaned up obsolete P/Invoke `DwmSetWindowAttribute`, manual Escape key handler, and `Style()` method.
- Used `Native.SetCue()` helper.

### 6. `src/ColorPicker.cs`
- In `Loupe`:
  - Aligned `BackColor = KitInk.Window; ForeColor = KitInk.Text;`.
  - Replaced per-frame `new Font(...)` allocation with `Ink.Semi(13f)`.
  - Replaced hardcoded white text with `KitInk.Text`.
  - Replaced semi-transparent white swatch border with `KitInk.Line`.
  - Implemented dual-stroke reticle (outer dark pen `#000000`, inner light pen `#FFFFFF`) for universal visibility on all sampled pixels.
  - Added subtle window boundary outline in `KitInk.Line`.

### 7. `src/Prefs.cs`
- Redesigned `Accents` and `AccentsLight` with the 8 curated macOS presets:
  1. Blue: `#4C8DFF` / `#1668E8` ("Biru")
  2. Purple: `#A78BFA` / `#6C3CE0` ("Ungu")
  3. Pink: `#FF6B9A` / `#C2185B` ("Merah muda")
  4. Red: `#FF5252` / `#C5221F` ("Merah")
  5. Orange: `#FF9F43` / `#A84B00` ("Oranye")
  6. Yellow: `#FFD24A` / `#855E00` ("Kuning")
  7. Green: `#3DD68C` / `#107C41` ("Hijau")
  8. Graphite: `""` / `""` ("Grafit")
- In `ApplyThemeMode()`, invoked `KitWindow.BroadcastThemeChange()`, and added auto-sync of preset accent hex when flipping between light and dark modes.
- In `SetAccentHex()`, invoked `KitWindow.BroadcastThemeChange()`.
- In `case "look":`, replaced dropdown popup with `KitPalette` control, cleaned up categories into "Gaya visual" and "Kustomisasi", and connected `KitWindow.BroadcastThemeChange()` on custom look toggle.
