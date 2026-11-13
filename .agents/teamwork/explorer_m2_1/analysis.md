# Technical Analysis Report: UI Toolkit Core Controls & Menus Contrast

**Agent**: Explorer 1 (Milestone 2)  
**Date**: 2026-11-12  
**Target Files**: `src/Kit.cs`, `src/Menus.cs`, `src/Prefs.cs`  
**Reference Standards**: WCAG 2.1 AA (Text Contrast $\ge 4.5:1$, Non-Text/UI Contrast $\ge 3.0:1$)

---

## Executive Summary

This report delivers the architectural inspection, mathematical contrast proof, and concrete replacement code for the UI Toolkit core controls and context menus within the Tepi application (`src/Kit.cs` and `src/Menus.cs`). 

Key findings:
1. **`KitInk.Faint` Contrast Elevation**: Raising light mode mix from `0.57f` to `0.65f` resolves WCAG AA failures across `Side`, `Group`, `Hover`, and `Line` surfaces (e.g. `Hover` lifts from 3.75:1 to 4.98:1; `Line` lifts from 3.50:1 to 4.66:1), ensuring all light mode surfaces satisfy $\ge 4.5:1$.
2. **`MenuLook` Submenu & Disabled Item Contrast**: Elevating `Sub` mix in `src/Menus.cs:97` from `0.50f` to `0.62f` increases disabled menu text and submenu arrow contrast against the menu surface from 3.19:1 (failing) to 4.71:1 (passing WCAG AA $\ge 4.5:1$).
3. **`KitButton` Pressed State & Focus Ring Contrast**: Replaces the static button implementation with an interactive pressed state (visual down-state and tone deepening) and resolves the primary button focus ring bug (which previously rendered identical text-colored stroke with 0 contrast) by deploying a dedicated contrasting focus ring ($\ge 3.38:1$ against the button surface).
4. **`KitSwitch` Hover State & Dynamic Sizing**: Introduces mouse hover tracking on track and knob with subtle luminance shifts and tactile knob expansion (`9.0s` $\to$ `9.5s`).
5. **`KitSlider` Disabled Thumb Contrast**: Rectifies line 362 where active `KitInk.Text` was unconditionally used for disabled slider thumbs, switching to semantic `KitInk.Disabled`.
6. **`KitRow.MarkGlyph` Light Mode Invisibility**: Replaces hardcoded `Brushes.Black` with `KitInk.Text` and `KitInk.Window` dot fill, eliminating the 1.08:1 invisible dot flaw in light mode and achieving $> 17.9:1$ contrast in both themes.
7. **Centralized Dialog Theme Propagation**: Establishes a static instance registry and `BroadcastThemeChange()` on `KitWindow` to automatically propagate theme and accent switches to all open modeless and modal dialogs.
8. **`KitAsk` Localization & Dynamic Title**: Un-hardcodes the legacy `"Tugas dan catatan"` window title into a dynamic/contextual title parameter and routes all action buttons through `Lang.T`.

---

## Item 1: `KitInk.Faint` Light Mode Contrast Calibration

### 1. File & Line
- **File**: `src/Kit.cs`
- **Line**: 28

### 2. Current Code
```csharp
// src/Kit.cs:27-28
// 0.57 keeps settings-window metadata above 4.5:1 (0.38 measured ~2.5-3.3:1)
public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.57f)); } }
```

### 3. Problem Analysis
In `src/Kit.cs`, `KitInk.Faint` is used for tertiary/dimmed text, metadata, suffixes, and secondary labels across dialog windows.
Currently, `Faint` uses a fixed mix factor of `0.57f` across both light and dark modes:
- In Light mode (`Tone.Paper()`), `Base.Bg` = `#F5F5F5` (RGB: 245, 245, 245) and `Base.Text` = `#0C0C0E` (RGB: 12, 12, 14).
- A mix of `0.57f` produces RGB(112, 112, 113) with relative luminance $L = 0.1623$.
- While `Faint` achieved 4.54:1 against the raw `Window` background (#F5F5F5), controls inside dialogs sit on various container surfaces: `Side` (mix 0.05), `Group` (mix 0.035), `Hover` (mix 0.09), and `Line` (mix 0.12).
- Against these container surfaces, `Faint` at 0.57f drops to **3.75:1 on Hover** and **3.50:1 on Line**, failing the WCAG AA minimum threshold of 4.5:1.

### 4. Mathematical Calculations & Contrast Table

Relative Luminance Formula:
$$L = 0.2126 \cdot R_{lin} + 0.7152 \cdot G_{lin} + 0.0722 \cdot B_{lin}$$
Contrast Ratio:
$$C = \frac{\max(L_1, L_2) + 0.05}{\min(L_1, L_2) + 0.05}$$

**Light Mode Color Values**:
- `Window` (mix 0.00): RGB(245, 245, 245), $L = 0.9160$
- `Group` (mix 0.035): RGB(236, 236, 236), $L = 0.8412$
- `Side` (mix 0.05): RGB(233, 233, 233), $L = 0.8164$
- `Hover` (mix 0.09): RGB(224, 224, 224), $L = 0.7410$
- `Line` (mix 0.12): RGB(217, 217, 217), $L = 0.6931$

**Faint Candidate Luminance**:
- Current `Faint` (0.57f): RGB(112, 112, 113), $L = 0.1623$
- Proposed `Faint` (0.65f): RGB(93, 93, 94), $L = 0.1096$

| Surface | Surface RGB & Luminance | Current (0.57f) Contrast | Proposed (0.65f) Contrast | WCAG AA Status ($\ge 4.5:1$) |
|:---|:---|:---:|:---:|:---:|
| **Window** | RGB(245, 245, 245), $L=0.9160$ | 4.54:1 | **6.03:1** | PASS |
| **Group**  | RGB(236, 236, 236), $L=0.8412$ | 4.19:1 (FAIL) | **5.57:1** | PASS |
| **Side**   | RGB(233, 233, 233), $L=0.8164$ | 4.07:1 (FAIL) | **5.42:1** | PASS |
| **Hover**  | RGB(224, 224, 224), $L=0.7410$ | 3.75:1 (FAIL) | **4.98:1** | PASS |
| **Line**   | RGB(217, 217, 217), $L=0.6931$ | 3.50:1 (FAIL) | **4.66:1** | PASS |

In Dark Mode (`Tone.Dark()`):
- `Base.Bg` = RGB(0, 0, 0), `Base.Text` = RGB(245, 245, 247).
- Mix `0.57f` yields RGB(140, 140, 141), $L = 0.2580$.
- Contrast vs Dark Window: 5.89:1, Group: 5.39:1, Line: 4.56:1, Hover: 4.45:1.
- Retaining `0.57f` for dark mode prevents tertiary text from becoming excessively bright, while `0.65f` in light mode provides the necessary contrast boost.

### 5. Proposed Replacement Code
```csharp
// src/Kit.cs:27-28
// 0.65 in light mode guarantees >= 4.5:1 across Window, Side, Group, Hover, and Line
public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)); } }
```

---

## Item 2: `MenuLook` Submenu & Disabled Item Contrast

### 1. File & Line
- **File**: `src/Menus.cs`
- **Lines**: 97, 127, 149

### 2. Current Code
```csharp
// src/Menus.cs:95-99
static Color Bg { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.06f)); } }
static Color Text { get { return Opaque(Ink.Base.Text); } }
static Color Sub { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.5f)); } }
static Color Hover { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.16f)); } }
static Color Line { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.14f)); } }
```

```csharp
// src/Menus.cs:125-130
protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
{
    e.TextColor = e.Item.Enabled ? Text : Sub;
    e.TextFont = MenuFont;
    base.OnRenderItemText(e);
}
```

```csharp
// src/Menus.cs:147-151
protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
{
    e.ArrowColor = Sub;
    base.OnRenderArrow(e);
}
```

### 3. Problem Analysis
In `MenuLook`:
- `Sub` is used directly for rendering disabled menu item text (`OnRenderItemText:127`) and submenu cascade arrows (`OnRenderArrow:149`).
- Currently, `Sub` is mixed at `0.5f` (`Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.5f)`).
- In Light mode:
  - Menu `Bg` (mix 0.06) is RGB(231, 231, 231) ($L = 0.7991$).
  - Current `Sub` (mix 0.50) is RGB(128, 128, 130) ($L = 0.2155$).
  - Contrast ratio of `Sub` vs Menu `Bg` is only **3.19:1**.
  - This severely fails WCAG AA text contrast ($\ge 4.5:1$) for disabled items and provides weak visual clarity for submenu cascade arrows.
- Note that in `Kit.cs:26`, `KitInk.Sub` is already defined as `0.62f`:
  `public static Color Sub { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.62f)); } }`
  `MenuLook.Sub` at `0.5f` was an un-synchronized outlier.

### 4. Mathematical Calculations & Contrast Table

**Light Mode**:
- Menu `Bg` (mix 0.06): RGB(231, 231, 231), $L = 0.7991$
- Menu `Hover` (mix 0.16): RGB(207, 207, 207), $L = 0.6200$
- Current `Sub` (mix 0.50): RGB(128, 128, 130), $L = 0.2155$
- Proposed `Sub` (mix 0.62): RGB(101, 101, 102), $L = 0.1301$
- Alternative `Sub` (mix 0.65): RGB(94, 94, 95), $L = 0.1123$

| State / Mix | Color (Light) | Contrast vs Menu `Bg` | Contrast vs Menu `Hover` | WCAG Status |
|:---|:---|:---:|:---:|:---:|
| Current `Sub` (0.50f) | RGB(128, 128, 130) | 3.19:1 | 2.56:1 | **FAIL** (< 4.5:1) |
| Proposed `Sub` (0.62f) | RGB(101, 101, 102) | **4.71:1** | **3.77:1** | **PASS** ($\ge 4.5:1$ text, $\ge 3.0:1$ arrow) |
| Conditional `Sub` (`Light ? 0.65f : 0.62f`) | RGB(94, 94, 95) | **5.24:1** | **4.20:1** | **PASS** (Optimal legibility) |

**Dark Mode**:
- Menu `Bg` (mix 0.06): RGB(15, 15, 15), $L = 0.0048$
- Current `Sub` (mix 0.50): RGB(122, 122, 124), $L = 0.1947$ $\to$ Contrast = 4.47:1
- Proposed `Sub` (mix 0.62): RGB(152, 152, 153), $L = 0.3146$ $\to$ Contrast = **6.65:1** (PASS)

### 5. Proposed Replacement Code
```csharp
// src/Menus.cs:97
// 0.62f elevates disabled items and submenu arrows above WCAG AA (>= 4.71:1)
static Color Sub { get { return Opaque(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.62f)); } }
```

---

## Item 3: `KitButton` Pressed State & Focus Ring Contrast

### 1. File & Line
- **File**: `src/Kit.cs`
- **Lines**: 383–422

### 2. Current Code
```csharp
// src/Kit.cs:383-422
class KitButton : Button
{
    public bool Primary;
    bool hovered;

    public KitButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        BackColor = Color.Transparent;
        UseVisualStyleBackColor = false;
    }

    protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hovered = true; Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e) { KitInk.ByMouse = true; base.OnMouseDown(e); }
    protected override void OnKeyUp(KeyEventArgs e) { if (KitInk.ByMouse) { KitInk.ByMouse = false; Invalidate(); } base.OnKeyUp(e); }
    protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); hovered = false; Invalidate(); }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        KitInk.Smooth(g);
        g.Clear(KitInk.Under(this));
        bool ringOn = Focused && ShowFocusCues && !KitInk.ByMouse;
        // Focused pill shrinks so its ring fits
        var r = ringOn ? new RectangleF(3.5f, 3.5f, Width - 7, Height - 7) : new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
        Color bg = Primary ? (hovered ? Ink.Mix(KitInk.Text, KitInk.Window, 0.15f) : KitInk.Text) : (hovered ? KitInk.Hover : KitInk.Line);
        if (!Enabled) bg = KitInk.Line;
        using (var path = Ink.Round(r, r.Height / 2f))
        using (var b = new SolidBrush(bg)) g.FillPath(b, path);
        KitInk.Draw(g, Text, Font, !Enabled ? KitInk.Faint : Primary ? KitInk.Window : KitInk.Text, r, ContentAlignment.MiddleCenter);
        if (ringOn)
        {
            var ring = new RectangleF(1, 1, Width - 2.5f, Height - 2.5f);
            using (var path = Ink.Round(ring, ring.Height / 2f))
            using (var pen = new Pen(KitInk.Text, 1.6f)) g.DrawPath(pen, path);
        }
    }
}
```

### 3. Problem Analysis
1. **Missing Pressed State**:
   - In `OnMouseDown` (line 398), the control sets `KitInk.ByMouse = true` but fails to track whether the mouse button is pressed.
   - There is no `OnMouseUp` override to release the state.
   - When users click or hold the button, there is zero tactile visual change (no background deepening, no displacement).
2. **Primary Focus Ring Contrast Failure (0:1 Contrast)**:
   - On a Primary button (`Primary == true`), the pill background is `KitInk.Text` (line 410).
   - On line 419, the focus ring is drawn using:
     `using (var pen = new Pen(KitInk.Text, 1.6f)) g.DrawPath(pen, path);`
   - The focus ring stroke color is **identical to the primary button surface color** (`KitInk.Text`)!
   - While the pill shrinks by 3.5px, the 1.6px stroke drawn in `KitInk.Text` over `Window` merges visually into the dark primary pill, giving zero contrast against the button's own identity.
   - WCAG 2.1 SC 2.4.7 (Focus Visible) and SC 1.4.11 (Non-Text Contrast) require a distinct, contrasting focus indicator with at least **3.0:1 contrast** against adjacent surfaces.

### 4. Mathematical Calculations & Contrast Analysis

**Focus Ring Contrast Requirements**:
- Must have $\ge 3.0:1$ contrast against the button surface `bg`.
- Must have $\ge 3.0:1$ contrast against the surrounding window background `KitInk.Window`.
- Must be visually distinct from button text color (`KitInk.Window` for primary, `KitInk.Text` for secondary).

**Using Curated Accents (`KitInk.Accent`)**:
- In Light Mode (`Window` = #F5F5F5, Primary `bg` = #0C0C0E):
  - Primary Accent "Biru" (`#1668E8`, $L = 0.1504$):
    - Contrast vs Button Surface (#0C0C0E, $L = 0.0039$): $\frac{0.1504 + 0.05}{0.0039 + 0.05} = \mathbf{3.72:1}$ ($\ge 3.0:1$, PASS)
    - Contrast vs Window (#F5F5F5, $L = 0.9160$): $\frac{0.9160 + 0.05}{0.1504 + 0.05} = \mathbf{4.82:1}$ ($\ge 3.0:1$, PASS)
    - Distinct from button text (`KitInk.Window` white).
  - All 7 light accents achieve $C \ge 3.13:1$ vs #0C0C0E and $C \ge 4.61:1$ vs #F5F5F5.
- In Dark Mode (`Window` = #000000, Primary `bg` = #F5F5F7):
  - Calibrated focus blue `#3B82F6` ($L = 0.2355$):
    - Contrast vs Button Surface (#F5F5F7, $L = 0.9160$): $\frac{0.9160 + 0.05}{0.2355 + 0.05} = \mathbf{3.38:1}$ ($\ge 3.0:1$, PASS)
    - Contrast vs Dark Window (#000000, $L = 0.0027$): $\frac{0.2355 + 0.05}{0.0027 + 0.05} = \mathbf{5.38:1}$ ($\ge 3.0:1$, PASS)
- Fallback for Monochrome Theme:
  - When user selects "Monokrom", `Accent == Text`. On a primary button, the algorithm falls back to the calibrated system focus blue (`#1668E8` in light mode, `#3B82F6` in dark mode) ensuring universal $\ge 3.0:1$ compliance.

**Pressed State Surface Values**:
- Primary Button:
  - Normal: `KitInk.Text`
  - Hover: `Ink.Mix(KitInk.Text, KitInk.Window, 0.15f)`
  - Pressed: `Ink.Light ? Color.FromArgb(255, 0, 0, 0) : Ink.Mix(KitInk.Text, KitInk.Window, 0.30f)`
  - In addition, applying an offset `r.Offset(0, 0.75f)` creates an immediate, tactile down-state.
- Secondary Button:
  - Normal: `KitInk.Line` (mix 0.12 light / 0.15 dark)
  - Hover: `KitInk.Hover` (mix 0.09 light / 0.16 dark)
  - Pressed: `Ink.Light ? Ink.Mix(KitInk.Base.Bg, KitInk.Base.Text, 0.20f) : Ink.Mix(KitInk.Base.Bg, KitInk.Base.Text, 0.25f)` (clearly darker/pressed than normal `Line`).

### 5. Proposed Replacement Code
```csharp
// src/Kit.cs:383-422
class KitButton : Button
{
    public bool Primary;
    bool hovered, pressed;

    public KitButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.SupportsTransparentBackColor, true);
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        BackColor = Color.Transparent;
        UseVisualStyleBackColor = false;
    }

    protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hovered = true; Invalidate(); }
    protected override void OnMouseDown(MouseEventArgs e)
    {
        KitInk.ByMouse = true;
        if (e.Button == MouseButtons.Left) { pressed = true; Invalidate(); }
        base.OnMouseDown(e);
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (pressed) { pressed = false; Invalidate(); }
    }
    protected override void OnKeyUp(KeyEventArgs e) { if (KitInk.ByMouse) { KitInk.ByMouse = false; Invalidate(); } base.OnKeyUp(e); }
    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        hovered = false;
        if (pressed) { pressed = false; }
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        KitInk.Smooth(g);
        g.Clear(KitInk.Under(this));
        bool ringOn = Focused && ShowFocusCues && !KitInk.ByMouse;
        // Focused pill shrinks so its ring fits
        var r = ringOn ? new RectangleF(3.5f, 3.5f, Width - 7, Height - 7) : new RectangleF(0.5f, 0.5f, Width - 1, Height - 1);
        
        Color bg;
        if (!Enabled)
        {
            bg = KitInk.Line;
        }
        else if (Primary)
        {
            bg = pressed ? (Ink.Light ? Color.FromArgb(255, 0, 0, 0) : Ink.Mix(KitInk.Text, KitInk.Window, 0.30f))
                         : hovered ? Ink.Mix(KitInk.Text, KitInk.Window, 0.15f)
                         : KitInk.Text;
        }
        else
        {
            bg = pressed ? (Ink.Light ? Ink.Mix(KitInk.Base.Bg, KitInk.Base.Text, 0.20f) : Ink.Mix(KitInk.Base.Bg, KitInk.Base.Text, 0.25f))
                         : hovered ? KitInk.Hover
                         : KitInk.Line;
        }

        if (pressed && Enabled) r.Offset(0, 0.75f);

        using (var path = Ink.Round(r, r.Height / 2f))
        using (var b = new SolidBrush(bg)) g.FillPath(b, path);

        KitInk.Draw(g, Text, Font, !Enabled ? KitInk.Faint : Primary ? KitInk.Window : KitInk.Text, r, ContentAlignment.MiddleCenter);

        if (ringOn)
        {
            var ring = new RectangleF(1, 1, Width - 2.5f, Height - 2.5f);
            Color ringColor = KitInk.Accent;
            if (Island.Contrast(ringColor, bg) < 3.0 || (Primary && (ringColor == KitInk.Text || ringColor == bg)))
                ringColor = Ink.Light ? Color.FromArgb(255, 22, 104, 232) : Color.FromArgb(255, 59, 130, 246);
            using (var path = Ink.Round(ring, ring.Height / 2f))
            using (var pen = new Pen(ringColor, 1.8f)) g.DrawPath(pen, path);
        }
    }
}
```

---

## Item 4: `KitSwitch` Hover State & Dynamics

### 1. File & Line
- **File**: `src/Kit.cs`
- **Lines**: 168–214

### 2. Current Code
```csharp
// src/Kit.cs:193-211
protected override void OnPaint(PaintEventArgs e)
{
    var g = e.Graphics;
    KitInk.Smooth(g);
    g.Clear(KitInk.Under(this));
    float s = Height / 24f;
    var track = new RectangleF(1, (Height - 22 * s) / 2, 40 * s, 22 * s);
    using (var path = Ink.Round(track, 11 * s))
    using (var b = new SolidBrush(Enabled ? Ink.Mix(KitInk.Line, KitInk.Accent, knob) : KitInk.Line)) g.FillPath(b, path);
    float r = 9 * s;
    float cx = track.X + 11 * s + knob * 18 * s, cy = track.Y + 11 * s;
    using (var b = new SolidBrush(Enabled ? Ink.Mix(KitInk.Text, KitInk.OnAccent, knob) : KitInk.Disabled)) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
    if (Focused && ShowFocusCues && !KitInk.ByMouse)
    {
        var ring = KitControl.Inside(RectangleF.Inflate(track, 2, 2), Width, Height);
        using (var path = Ink.Round(ring, ring.Height / 2))
        using (var pen = new Pen(KitInk.Text, 1.6f)) g.DrawPath(pen, path);
    }
}
```

### 3. Problem Analysis
- `KitSwitch` does not implement `OnMouseEnter` or `OnMouseLeave`.
- When hovering over the toggle switch, neither the track nor the knob provides visual feedback.
- On modern OS controls (macOS / iOS / Fluent), hovering over an inactive or active switch subtly illuminates the track and slightly highlights/expands the knob to communicate target affordance before clicking.

### 4. Proposed Design
1. Track `bool hovered;` via `OnMouseEnter` / `OnMouseLeave`.
2. When hovered and enabled:
   - Inactive track (`knob == 0`): shift from `KitInk.Line` to `KitInk.Hover`.
   - Active track (`knob == 1`): shift from `KitInk.Accent` with subtle brightness contrast (`Ink.Mix(KitInk.Accent, Color.White, 0.10f)` in dark mode or `Color.Black, 0.08f` in light mode).
   - Knob radius expands subtly from `9.0 * s` to `9.5 * s` (tactile expansion affordance, well within the `22 * s` track height).
   - Inactive knob shifts from `KitInk.Text` to `Ink.Mix(KitInk.Text, KitInk.Window, 0.08f)`.

### 5. Proposed Replacement Code
```csharp
// src/Kit.cs:170
bool hovered;
protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); hovered = true; Invalidate(); }
protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); hovered = false; Invalidate(); }
```

```csharp
// src/Kit.cs:193-211
protected override void OnPaint(PaintEventArgs e)
{
    var g = e.Graphics;
    KitInk.Smooth(g);
    g.Clear(KitInk.Under(this));
    float s = Height / 24f;
    var track = new RectangleF(1, (Height - 22 * s) / 2, 40 * s, 22 * s);
    using (var path = Ink.Round(track, 11 * s))
    {
        Color offTrack = hovered && Enabled ? KitInk.Hover : KitInk.Line;
        Color onTrack = hovered && Enabled ? (Ink.Light ? Ink.Mix(KitInk.Accent, Color.Black, 0.08f) : Ink.Mix(KitInk.Accent, Color.White, 0.12f)) : KitInk.Accent;
        using (var b = new SolidBrush(Enabled ? Ink.Mix(offTrack, onTrack, knob) : KitInk.Line)) g.FillPath(b, path);
    }
    float r = (hovered && Enabled ? 9.5f : 9f) * s;
    float cx = track.X + 11 * s + knob * 18 * s, cy = track.Y + 11 * s;
    Color offKnob = hovered && Enabled ? Ink.Mix(KitInk.Text, KitInk.Window, 0.08f) : KitInk.Text;
    Color onKnob = hovered && Enabled ? Ink.Mix(KitInk.OnAccent, KitInk.Text, 0.08f) : KitInk.OnAccent;
    using (var b = new SolidBrush(Enabled ? Ink.Mix(offKnob, onKnob, knob) : KitInk.Disabled)) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
    if (Focused && ShowFocusCues && !KitInk.ByMouse)
    {
        var ring = KitControl.Inside(RectangleF.Inflate(track, 2, 2), Width, Height);
        using (var path = Ink.Round(ring, ring.Height / 2))
        using (var pen = new Pen(KitInk.Text, 1.6f)) g.DrawPath(pen, path);
    }
}
```

---

## Item 5: `KitSlider` Disabled Thumb Contrast

### 1. File & Line
- **File**: `src/Kit.cs`
- **Lines**: 360–363

### 2. Current Code
```csharp
// src/Kit.cs:360-363
Fill(g, new RectangleF(t.X, t.Y, Math.Max(t.Height, t.Width * f), t.Height), t.Height / 2, Enabled ? KitInk.Text : KitInk.Disabled);
float r = (dragging || Hovered ? 9 : 8) * s, cx = t.X + t.Width * f, cy = t.Y + t.Height / 2;
using (var b = new SolidBrush(KitInk.Text)) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
using (var pen = new Pen(KitInk.Line, 1f)) g.DrawEllipse(pen, cx - r, cy - r, r * 2, r * 2);
```

### 3. Problem Analysis
- On line 360, the slider track fill correctly differentiates enabled vs disabled:
  `Enabled ? KitInk.Text : KitInk.Disabled`
- But on line 362, the slider thumb (knob) is filled with `new SolidBrush(KitInk.Text)` unconditionally!
- As documented in `src/Kit.cs:29-31`:
  `// Disabled chrome (switch knob, slider fill): dimmer than tertiary text so raising Faint for readability does not make disabled controls look enabled`
  `public static Color Disabled { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.30f)); } }`
- Because line 362 hardcodes `KitInk.Text`, a disabled slider presents a prominent, fully-enabled-looking thumb, confusing users and violating disabled UI semantics.
- Additionally, line 361 allows `Hovered` expansion (`r = 9`) even when `Enabled == false`.

### 4. Proposed Replacement Code
```csharp
// src/Kit.cs:361-363
float r = ((dragging || Hovered) && Enabled ? 9 : 8) * s, cx = t.X + t.Width * f, cy = t.Y + t.Height / 2;
using (var b = new SolidBrush(Enabled ? KitInk.Text : KitInk.Disabled)) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
using (var pen = new Pen(Enabled ? KitInk.Line : KitInk.Disabled, 1f)) g.DrawEllipse(pen, cx - r, cy - r, r * 2, r * 2);
```

---

## Item 6: `KitRow.MarkGlyph` Light Mode Contrast Bug

### 1. File & Line
- **File**: `src/Kit.cs`
- **Lines**: 584–590

### 2. Current Code
```csharp
// src/Kit.cs:584-590
// Mark glyph: Tepi's own pill
if (Glyph == MarkGlyph)
{
    var pill = new RectangleF(tile.X + 5 * s, tile.Y + 10 * s, 20 * s, 10 * s);
    using (var p2 = Ink.Round(pill, 5 * s)) g.FillPath(Brushes.Black, p2);
    using (var dot = new SolidBrush(KitInk.Text)) g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);
    return;
}
```

### 3. Problem Analysis
The `MarkGlyph` represents Tepi's iconic Island pill mark (a rounded pill with a status dot indicator at the right).
- On line 587, the pill background is hardcoded to `Brushes.Black` (RGB 0, 0, 0).
- On line 588, the dot inside the pill is drawn using `KitInk.Text`.
- In **Dark Mode**:
  - Pill = `Brushes.Black` (RGB 0, 0, 0)
  - Dot = `KitInk.Text` (RGB 245, 245, 247)
  - The white dot is visible on the black pill.
- In **Light Mode**:
  - Pill = `Brushes.Black` (RGB 0, 0, 0)
  - Dot = `KitInk.Text` (RGB 12, 12, 14)
  - Contrast between Dot and Pill:
    $$L_{dot} = 0.0039, \quad L_{pill} = 0.0000 \implies C = \frac{0.0039 + 0.05}{0.0000 + 0.05} = \mathbf{1.08:1}$$
  - The dot is **completely invisible** in Light Mode! The mark renders as an unbranded flat black rectangle without the signature status camera/dot.

### 4. Mathematical Calculations & Contrast Analysis

If we use semantic tokens:
- Pill = `KitInk.Text`
- Dot = `KitInk.Window`

**Light Mode**:
- Tile background: `KitInk.Hover` = RGB(224, 224, 224), $L = 0.7410$
- Pill: `KitInk.Text` = RGB(12, 12, 14), $L = 0.0039$
  - Contrast Pill vs Tile: $\frac{0.7410 + 0.05}{0.0039 + 0.05} = \mathbf{14.67:1}$ (Passes AAA)
- Dot: `KitInk.Window` = RGB(245, 245, 245), $L = 0.9160$
  - Contrast Dot vs Pill: $\frac{0.9160 + 0.05}{0.0039 + 0.05} = \mathbf{17.92:1}$ (Passes AAA)

**Dark Mode**:
- Tile background: `KitInk.Hover` = RGB(39, 39, 39), $L = 0.0205$
- Pill: `KitInk.Text` = RGB(245, 245, 247), $L = 0.9160$
  - Contrast Pill vs Tile: $\frac{0.9160 + 0.05}{0.0205 + 0.05} = \mathbf{13.70:1}$ (Passes AAA)
- Dot: `KitInk.Window` = RGB(10, 10, 10), $L = 0.0027$
  - Contrast Dot vs Pill: $\frac{0.9160 + 0.05}{0.0027 + 0.05} = \mathbf{18.32:1}$ (Passes AAA)

Both themes achieve pristine $> 13.7:1$ contrast and preserve brand integrity.

### 5. Proposed Replacement Code
```csharp
// src/Kit.cs:584-590
// Mark glyph: Tepi's own pill
if (Glyph == MarkGlyph)
{
    var pill = new RectangleF(tile.X + 5 * s, tile.Y + 10 * s, 20 * s, 10 * s);
    using (var p2 = Ink.Round(pill, 5 * s))
    using (var b2 = new SolidBrush(KitInk.Text)) g.FillPath(b2, p2);
    using (var dot = new SolidBrush(KitInk.Window)) g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);
    return;
}
```

---

## Item 7: Centralized Dialog Theme Propagation

### 1. Files & Lines
- **Definition**: `src/Kit.cs:613-685` (`KitWindow`)
- **Invocation**: `src/Prefs.cs:58-81` (`ApplyThemeMode`, `SetAccentHex`)

### 2. Current Architecture
In `src/Prefs.cs:65-67`:
```csharp
void ApplyThemeMode()
{
    bool light = ThemeLight();
    if (light == Ink.Light) return;
    Ink.Apply(light);
    WallApply();
    ResetFrost();
    if (prefs != null && !prefs.IsDisposed) prefs.Relayout();
    if (chatWin != null && !chatWin.IsDisposed) chatWin.Relayout();
    if (dockWin != null) dockWin.Changed();
    Kick();
}
```
Only `prefs` and `chatWin` were explicitly referenced. Any other active dialogs—such as `TaskEditor`, `ColorPicker`, `KitAsk`, `KuliaLogin`, `Feedback`, `Tour`, `Prompter`, or `WhatsNew`—are not notified. When a user changes the theme in Settings, open dialogs remain stranded in their prior theme colors until reopened or recreated.

### 3. Proposed Design
1. In `KitWindow`, maintain a static registry of active instances:
   `static readonly List<KitWindow> openWindows = new List<KitWindow>();`
2. Automatically add `this` in `KitWindow()` constructor, and remove `this` in `OnClosed` and `Dispose(bool disposing)`.
3. Provide a public static broadcast method:
   `public static void BroadcastThemeChange()`
4. For each registered window:
   - Check disposal / handle status.
   - Reapply DWM window frame mode: `Native.DarkFrame(w.Handle, !Ink.Light);`
   - Refresh root colors: `w.BackColor = KitInk.Window; w.ForeColor = KitInk.Text;`
   - Invoke `w.Relayout();` (which already exists as a virtual method for rebuilding layouts).
   - Invalidate control trees: refresh container backgrounds like `KitGroup.BackColor = KitInk.Group;` and invoke `w.Invalidate(true);`.
5. Call `KitWindow.BroadcastThemeChange()` inside `Prefs.cs` `ApplyThemeMode()` and `SetAccentHex()`.

### 4. Proposed Implementation Code

**In `src/Kit.cs` (`KitWindow`)**:
```csharp
// src/Kit.cs: inside class KitWindow : Form
static readonly List<KitWindow> openWindows = new List<KitWindow>();

public KitWindow()
{
    AutoScaleMode = AutoScaleMode.None;
    BackColor = KitInk.Window;
    ForeColor = KitInk.Text;
    KeyPreview = true;
    ShowInTaskbar = true;
    if (AppIcon != null) Icon = AppIcon;
    openWindows.Add(this);
}

protected override void OnClosed(EventArgs e)
{
    base.OnClosed(e);
    openWindows.Remove(this);
}

protected override void Dispose(bool disposing)
{
    if (disposing) openWindows.Remove(this);
    base.Dispose(disposing);
}

public static void BroadcastThemeChange()
{
    for (int i = openWindows.Count - 1; i >= 0; i--)
    {
        var w = openWindows[i];
        if (w == null || w.IsDisposed)
        {
            openWindows.RemoveAt(i);
            continue;
        }
        try
        {
            if (w.IsHandleCreated) Native.DarkFrame(w.Handle, !Ink.Light);
            w.BackColor = KitInk.Window;
            w.ForeColor = KitInk.Text;
            w.Relayout();
            RefreshTree(w);
            w.Invalidate(true);
        }
        catch (Exception ex)
        {
            Log.Write("theme broadcast: " + ex.Message);
        }
    }
}

static void RefreshTree(Control parent)
{
    if (parent is KitGroup) parent.BackColor = KitInk.Group;
    foreach (Control c in parent.Controls)
    {
        if (c is KitGroup) c.BackColor = KitInk.Group;
        c.Invalidate();
        RefreshTree(c);
    }
}
```

**In `src/Prefs.cs`**:
```csharp
// src/Prefs.cs:58-69
void ApplyThemeMode()
{
    bool light = ThemeLight();
    if (light == Ink.Light) return;
    Ink.Apply(light);
    WallApply();
    ResetFrost();
    KitWindow.BroadcastThemeChange();
    if (dockWin != null) dockWin.Changed();
    Kick();
}

// src/Prefs.cs:71-81
void SetAccentHex(string hex)
{
    settings.Set("accent", hex);
    settings.Save();
    Ink.SetAccent(hex);
    albumAccentFor = null;
    albumTinted = false;
    AlbumAccent();
    WallApply();
    KitWindow.BroadcastThemeChange();
    Kick();
}
```

---

## Item 8: `KitAsk` Universal Title & Localization

### 1. File & Line
- **File**: `src/Kit.cs`
- **Lines**: 713–784

### 2. Current Code
```csharp
// src/Kit.cs:713-755
sealed class KitAsk : KitWindow
{
    readonly Label text = new Label { AutoSize = false };
    readonly KitButton yes = new KitButton { Primary = true };
    readonly KitButton no = new KitButton { Text = "Batal" };
    readonly KitButton ok = new KitButton { Text = "Tutup", Visible = false };
    bool two;
    Font uiFont;

    public static bool Confirm(Form owner, string message, string confirm = "Hapus", string dismiss = "Batal")
    {
        using (var d = new KitAsk(message, true, confirm, dismiss))
            return d.ShowDialog(owner ?? Form.ActiveForm) == DialogResult.Yes;
    }

    public static void Notice(Form owner, string message)
    {
        using (var d = new KitAsk(message, false, "", ""))
            d.ShowDialog(owner ?? Form.ActiveForm);
    }

    KitAsk(string message, bool question, string confirm, string dismiss)
    {
        two = question;
        Text = "Tugas dan catatan";
        ...
        yes.Text = confirm;
        no.Text = dismiss;
        ...
    }
```

### 3. Problem Analysis
1. **Hardcoded Window Title**:
   Line 738 unconditionally sets `Text = "Tugas dan catatan";`. Regardless of whether `KitAsk` is summoned to confirm deleting a custom theme preset, notify of a network error, confirm overwriting notes, or prompt for unsaved changes, the title bar always reads "Tugas dan catatan".
2. **Missing Localization in Action Buttons**:
   Button labels (`confirm`, `dismiss`, and `ok`) were not passed through `Lang.T`. In `Lang.cs`, standard translations exist:
   `"Batal" -> "Cancel"`, `"Tutup" -> "Close"`, `"Hapus" -> "Delete"`.
   Without `Lang.T`, English UI users see Indonesian button labels in modal confirmation boxes.

### 4. Proposed Design
1. Extend `Confirm` and `Notice` to accept an optional `title` parameter (defaulting to contextual standard titles: `Lang.T("Konfirmasi")` or `Lang.T("Pemberitahuan")`).
2. Wrap all button labels with `Lang.T(...)`.

### 5. Proposed Replacement Code
```csharp
// src/Kit.cs:723-755
public static bool Confirm(Form owner, string message, string confirm = "Hapus", string dismiss = "Batal", string title = null)
{
    using (var d = new KitAsk(message, true, confirm, dismiss, title))
        return d.ShowDialog(owner ?? Form.ActiveForm) == DialogResult.Yes;
}

public static void Notice(Form owner, string message, string title = null, string close = "Tutup")
{
    using (var d = new KitAsk(message, false, "", "", title, close))
        d.ShowDialog(owner ?? Form.ActiveForm);
}

KitAsk(string message, bool question, string confirm, string dismiss, string title = null, string close = "Tutup")
{
    two = question;
    Text = Lang.T(!string.IsNullOrEmpty(title) ? title : (question ? "Konfirmasi" : "Pemberitahuan"));
    FormBorderStyle = FormBorderStyle.FixedDialog;
    MaximizeBox = MinimizeBox = false;
    StartPosition = FormStartPosition.CenterParent;
    ShowInTaskbar = false;
    text.Text = message;
    text.AccessibleName = message;
    yes.Text = Lang.T(string.IsNullOrEmpty(confirm) ? "Ya" : confirm);
    no.Text = Lang.T(string.IsNullOrEmpty(dismiss) ? "Batal" : dismiss);
    ok.Text = Lang.T(string.IsNullOrEmpty(close) ? "Tutup" : close);
    yes.Click += delegate { DialogResult = DialogResult.Yes; Close(); };
    no.Click += delegate { DialogResult = DialogResult.No; Close(); };
    ok.Click += delegate { DialogResult = DialogResult.OK; Close(); };
    Controls.AddRange(new Control[] { text, yes, no, ok });
    yes.Visible = two;
    no.Visible = two;
    ok.Visible = !two;
}
```

---

## Summary of Code Changes Matrix

| Target File | Affected Lines | Change Type | Summary |
|---|---|---|---|
| `src/Kit.cs` | 27–28 | Value Calibration | `KitInk.Faint`: `Light ? 0.65f : 0.57f` |
| `src/Kit.cs` | 170–211 | Feature Enhancement | `KitSwitch`: add hover state tracking and track/knob dynamics |
| `src/Kit.cs` | 361–363 | Bug Fix | `KitSlider`: use `KitInk.Disabled` for disabled thumb and track |
| `src/Kit.cs` | 385–422 | Feature & Accessibility | `KitButton`: pressed visual down-state and contrasting focus ring ($\ge 3:1$) |
| `src/Kit.cs` | 584–590 | Bug Fix / Contrast | `KitRow.MarkGlyph`: replace `Brushes.Black` with `KitInk.Text` and `KitInk.Window` |
| `src/Kit.cs` | 613–685 | Architecture | `KitWindow`: static registry, `BroadcastThemeChange()`, tree refresh |
| `src/Kit.cs` | 723–755 | Feature & Localization | `KitAsk`: dynamic title parameter and `Lang.T` button localization |
| `src/Menus.cs`| 97 | Value Calibration | `MenuLook.Sub`: elevate mix from `0.5f` to `Ink.Light ? 0.65f : 0.62f` |
| `src/Prefs.cs`| 65, 80 | Integration | Call `KitWindow.BroadcastThemeChange()` in `ApplyThemeMode` and `SetAccentHex` |
