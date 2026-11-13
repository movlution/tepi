# Handoff Report: Milestone 4 Task 1 — Dock Hardcoded Colors Tokenization

**Author**: Explorer 1  
**Target Milestone**: Milestone 4 (Dock & Mini Polish)  
**Assigned Scope**: Task 1 — Dock Hardcoded Colors Tokenization in `src/DockPaint.cs`, `src/DockCard.cs`, and `src/DockSheet.cs`  
**Date**: 2026-11-13  
**Status**: Complete

---

## 1. Observation

A full forensic AST and text analysis was conducted across `src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, and supporting design system files (`src/Ink.cs`, `src/Colors.cs`).

### 1.1 `src/DockPaint.cs`

1. **`BadgeRed` Definition and Usage (Lines 648, 658-659)**:
   - Line 648:
     ```csharp
     // White numbers on it reach 4.77:1
     static readonly Color BadgeRed = Color.FromArgb(255, 217, 48, 37);
     ```
   - Lines 651-660:
     ```csharp
     void Badge(RectangleF r, int n)
     {
         string s = n > 99 ? "99+" : n.ToString();
         var f = Ink.SmallSemi(11f);
         float h = 17, w = Math.Max(h, p.Measure(s, f) + 9);
         var b = new RectangleF(r.Right - w * 0.7f, r.Top - h * 0.28f, w, h);
         p.FillRound(Inset(b, -1.2f), (h + 2.4f) / 2, Ink.A(Ink.Base.Bg, 0.55f));
         p.FillRound(b, h / 2, BadgeRed);
         p.TextCenter(s, f, Color.White, b.X + b.Width / 2, b.Y + h / 2);
     }
     ```
   - Called at line 344 (`if (a.Badge > 0 && s.Show > 0.5f) Badge(s.Icon, a.Badge);`) and line 792 (`if (isle.unread > 0) Badge(r, isle.unread);`).
   - The badge background uses hardcoded `BadgeRed` = `#D93025` (`rgb(217, 48, 37)`).
   - The badge text uses hardcoded `Color.White`.

2. **Hardcoded White Rim Light in `RimLight` (Lines 214-224)**:
   ```csharp
   // Glass catches light on its top edge, a little on the bottom
   void RimLight(RectangleF r, GraphicsPath path)
   {
       using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, r.Height + 2), Color.White, Color.White, 90f))
       {
           var cb = new ColorBlend(3);
           cb.Colors = new[] { Color.FromArgb(Ink.Light ? 170 : 120, 255, 255, 255), Color.FromArgb(Ink.Light ? 50 : 16, 255, 255, 255), Color.FromArgb(Ink.Light ? 110 : 52, 255, 255, 255) };
           cb.Positions = new[] { 0f, 0.5f, 1f };
           lg.InterpolationColors = cb;
           using (var pen = new Pen(lg, 1f)) g.DrawPath(pen, path);
       }
   }
   ```
   - Brush initialized with hardcoded `Color.White, Color.White`.
   - Gradient color blend hardcodes pure white `Color.FromArgb(..., 255, 255, 255)` across all 3 stops.

3. **Hardcoded White Sheen in `Sheen` (Lines 234-251)**:
   ```csharp
   void Sheen(RectangleF r)
   {
       float h = Math.Min(r.Height * 0.55f, 28);
       using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, h + 2), Color.FromArgb(Ink.Light ? 80 : 24, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
           g.FillRectangle(lg, r.X, r.Y, r.Width, h);
       if (hover.Value < 0.01f || mouseX < r.Left - 60 || mouseX > r.Right + 60) return;
       float rx = Math.Max(70, r.Height * 1.7f), ry = r.Height * 1.05f;
       using (var gp = new GraphicsPath())
       {
           gp.AddEllipse(mouseX - rx, r.Top - ry * 0.55f, rx * 2, ry * 2);
           using (var pb = new PathGradientBrush(gp))
           {
               pb.CenterColor = Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), 255, 255, 255);
               pb.SurroundColors = new[] { Color.FromArgb(0, 255, 255, 255) };
               g.FillPath(pb, gp);
           }
       }
   }
   ```
   - Hardcoded white `Color.FromArgb(..., 255, 255, 255)` on line 237 (sheen gradient) and lines 246-247 (radial glow on hover).

4. **Hardcoded White Cursor Rim in `Rim` (Lines 254-269)**:
   ```csharp
   void Rim(RectangleF r, float radius)
   {
       if (hover.Value < 0.01f || mouseX < r.Left || mouseX > r.Right) return;
       float span = Math.Max(60, r.Height * 1.5f);
       float a = Math.Max(r.Left + radius * 0.7f, mouseX - span), b = Math.Min(r.Right - radius * 0.7f, mouseX + span);
       if (b - a < 2) return;
       using (var lg = new LinearGradientBrush(new PointF(mouseX - span, 0), new PointF(mouseX + span, 0), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(0, 255, 255, 255)))
       {
           var blend = new ColorBlend(3);
           int peak = (int)(hover.Value * (Ink.Light ? 230 : 150));
           blend.Colors = new[] { Color.FromArgb(0, 255, 255, 255), Color.FromArgb(peak, 255, 255, 255), Color.FromArgb(0, 255, 255, 255) };
           blend.Positions = new[] { 0f, 0.5f, 1f };
           lg.InterpolationColors = blend;
           using (var pen = new Pen(lg, 1.3f)) g.DrawLine(pen, a, r.Top + 0.65f, b, r.Top + 0.65f);
       }
   }
   ```
   - Hardcoded white `Color.FromArgb(..., 255, 255, 255)` on lines 260 and 264.

---

### 1.2 `src/DockCard.cs`

1. **`BadgeRedSoft` Definition and Usage (Lines 413-414, 434)**:
   - Line 413-414:
     ```csharp
     hits.Add(new KeyValuePair<RectangleF, string>(t.Close, "x" + id));
     if (hot == "x" + id) p.FillRound(t.Close, 6, BadgeRedSoft);
     p.Icon('\uE711', 9.5f, hot == "x" + id ? Color.White : p.T.Sub, t.Close.X + t.Close.Width / 2, t.Close.Y + t.Close.Height / 2);
     ```
   - Line 434:
     ```csharp
     static readonly Color BadgeRedSoft = Color.FromArgb(230, 196, 43, 28);
     ```
   - Thumbnail preview card close button uses `BadgeRedSoft` = `#E6C42B1C` (`rgba(196, 43, 28, 0.9)`).
   - Glyph icon uses hardcoded `Color.White` when hovered.

2. **Hardcoded White Card Sheen and Border (Lines 369-372)**:
   ```csharp
   using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, 40), Color.FromArgb((int)(fade * (Ink.Light ? 80 : 22)), 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
       g.FillRectangle(lg, r.X, r.Y, r.Width, 39);
   g.Restore(st);
   g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255), 1f), path);
   ```
   - Line 369 hardcodes pure white in the sheen gradient.
   - Line 372 hardcodes pure white `Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255)` in the border path outline.

---

### 1.3 `src/DockSheet.cs`

1. **Hardcoded White Sheet Sheen and Border (Lines 267-275)**:
   ```csharp
   using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, 58), Color.FromArgb((int)(fade * (Ink.Light ? 80 : 22)), 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
   {
       // No wrap: a tiled gradient leaves a bright seam
       lg.WrapMode = WrapMode.TileFlipXY;
       g.FillRectangle(lg, r.X, r.Y, r.Width, 54);
   }
   Backdrop(r);
   g.Restore(st);
   g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255), 1f), path);
   ```
   - Line 267 hardcodes pure white in the sheen gradient.
   - Line 275 hardcodes pure white `Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255)` in the sheet border path outline.

---

### 1.4 Theme Tokens in `src/Ink.cs`

1. **`Tone.cs:19, 23, 25, 56-57, 68`**:
   - `Negative`:
     - Dark mode: `Color.FromArgb(255, 240, 120, 120)` (`#F07878`, light pastel red).
     - Light mode: `Color.FromArgb(255, 190, 50, 50)` (`#BE3232`, deep ruby red).
   - `Highlight`:
     - Dark mode: `Color.FromArgb(23, 255, 255, 255)` (alpha 23).
     - Light mode: `Color.FromArgb(110, 255, 255, 255)` (alpha 110).
     - Modifiable via pack key `prefix + "highlight"`.
   - `IsDark`:
     - `public bool IsDark { get { return Bg.R + Bg.G + Bg.B < 384; } }`
   - `Bg`:
     - Dark mode: `Color.FromArgb(255, 0, 0, 0)` (`#000000`).
     - Light mode: `Color.FromArgb(255, 245, 245, 245)` (`#F5F5F5`).

---

## 2. Logic Chain

### 2.1 WCAG AA Contrast Analysis for Badges & Semantic Negative

The WCAG 2.1 relative luminance $L$ formula is:
$$L = 0.2126 \cdot R' + 0.7152 \cdot G' + 0.0722 \cdot B'$$
where $C' = C / 255 \le 0.03928 \; ? \; (C / 255) / 12.92 : ((C / 255 + 0.055) / 1.055)^{2.4}$.

The contrast ratio between two luminances $L_1$ and $L_2$ ($L_1 \ge L_2$) is:
$$\text{Ratio} = \frac{L_1 + 0.05}{L_2 + 0.05}$$

Calculating exact values:
| Color Token | Hex / RGB | Relative Luminance $L$ |
|---|---|---|
| Pure White (`Color.White`) | `#FFFFFF` (255, 255, 255) | 1.0000 |
| Pure Black (`Color.Black` / `Dark Bg`) | `#000000` (0, 0, 0) | 0.0000 |
| Light Paper Bg (`Tone.Paper.Bg`) | `#F5F5F5` (245, 245, 245) | 0.9131 |
| Light Paper Text (`Tone.Paper.Text`) | `#0C0C0E` (12, 12, 14) | 0.0037 |
| Dark Negative (`p.T.Negative`, Dark) | `#F07878` (240, 120, 120) | 0.3331 |
| Light Negative (`p.T.Negative`, Light) | `#BE3232` (190, 50, 50) | 0.1346 |
| Legacy `BadgeRed` | `#D93025` (217, 48, 37) | 0.1700 |

#### Step-by-Step Inference for Badge Text Contrast
1. **The Dark Mode Trap with `Color.White`**:
   - In Dark mode, `p.T.Negative` is `#F07878` ($L = 0.3331$), calibrated as a legible foreground text color on `#000000`.
   - If badge text remains hardcoded `Color.White` ($L = 1.0000$):
     $$\text{Contrast} = \frac{1.0000 + 0.05}{0.3331 + 0.05} = \frac{1.05}{0.3831} \approx \mathbf{2.74:1} \quad (\mathbf{FAILS} \text{ WCAG AA } \ge 4.5:1)$$
   - However, if badge text uses dark surface ink `p.T.Bg` (`#000000`, $L = 0.0000$):
     $$\text{Contrast} = \frac{0.3331 + 0.05}{0.0000 + 0.05} = \frac{0.3831}{0.05} = \mathbf{7.66:1} \quad (\mathbf{PASSES} \text{ WCAG AA } \ge 4.5:1)$$
   - Or with `Tone.Paper.Text` (`#0C0C0E`, $L = 0.0037$):
     $$\text{Contrast} = \frac{0.3331 + 0.05}{0.0037 + 0.05} = \frac{0.3831}{0.0537} = \mathbf{7.13:1} \quad (\mathbf{PASSES} \text{ WCAG AA } \ge 4.5:1)$$

2. **The Light Mode Text Contrast**:
   - In Light mode, `p.T.Negative` is `#BE3232` ($L = 0.1346$), a rich dark red.
   - Text using `Color.White` ($L = 1.0000$):
     $$\text{Contrast} = \frac{1.0000 + 0.05}{0.1346 + 0.05} = \frac{1.05}{0.1846} = \mathbf{5.69:1} \quad (\mathbf{PASSES} \text{ WCAG AA } \ge 4.5:1)$$
   - Dark text on `#BE3232` would yield only $\frac{0.1846}{0.0537} = 3.44:1$ (FAILS).

3. **Unified Badge Text Color Rule**:
   $$\text{Badge Text Color} = \texttt{p.T.IsDark ? p.T.Bg : Color.White}$$
   - Dark mode: **7.66:1** contrast (exceeds 4.5:1 requirement).
   - Light mode: **5.69:1** contrast (exceeds 4.5:1 requirement).
   - This single expression guarantees WCAG AA compliance across all themes.

4. **Badge Pill on Dock Surface Contrast**:
   - **Dark Mode**: Badge `#F07878` ($L = 0.3331$) on Dock Surface `#000000` ($L = 0.0000$):
     $$\text{Contrast} = \frac{0.3331 + 0.05}{0.0000 + 0.05} = \mathbf{7.66:1} \ge 4.5:1 \quad (\mathbf{PASSES})$$
   - **Light Mode**: Badge `#BE3232` ($L = 0.1346$) on Dock Surface `#F5F5F5` ($L = 0.9131$):
     $$\text{Contrast} = \frac{0.9131 + 0.05}{0.1346 + 0.05} = \frac{0.9631}{0.1846} = \mathbf{5.22:1} \ge 4.5:1 \quad (\mathbf{PASSES})$$
   - Both modes exceed the 4.5:1 threshold for the badge pill boundary itself against the dock surface. Additionally, the $1.2\text{px}$ halo (`Inset(b, -1.2f)`) using `Ink.A(p.T.Bg, 0.55f)` provides crisp local separation when rendered over translucent frosted glass or custom wallpapers.

### 2.2 Rim Light and Highlight Tokenization

1. In GDI+, `LinearGradientBrush` and `PathGradientBrush` take `Color` values.
2. In `src/Ink.cs`, `t.Highlight` is explicitly defined to represent specular highlight/rim light on surfaces:
   `t.Highlight = dark ? Color.FromArgb(23, 255, 255, 255) : Color.FromArgb(110, 255, 255, 255);`
   and can receive theme pack accent tints via `Hex(prefix + "highlight", out c)`.
3. Hardcoded `Color.FromArgb(..., 255, 255, 255)` ignores theme-pack highlight tinting.
4. Using `Color.FromArgb(alpha, p.T.Highlight)` preserves the exact alpha ramp calibrated for glass depth while routing RGB through the theme token.
5. In `DockCard.cs` and `DockSheet.cs`, card borders currently hardcode:
   `Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255)`
   Routing this through `Color.FromArgb(Ink.Light ? 70 : 40, p.T.Highlight)` ensures border highlights dynamically adapt to theme palette definitions while preserving subpixel edge clarity.

---

## 3. Caveats

1. **Win32 Layered Window Sensor**: Line 92 of `src/DockPaint.cs` contains `Color.FromArgb(1, 0, 0, 0)`:
   ```csharp
   g.FillRectangle(p.B(Color.FromArgb(1, 0, 0, 0)), 0, ch / scale - h, cw / scale, h);
   ```
   This is an invisible 1-alpha hit-test bar required by Windows `UpdateLayeredWindow` so mouse messages are received. It is NOT a visual surface color and must NOT be tokenized to theme colors.
2. **`Color.Transparent`**: Calls such as `g.Clear(Color.Transparent)` in `DockPaint.cs:40`, `DockCard.cs:348`, and `DockSheet.cs:246` are GDI+ canvas clearing calls required before redrawing layered alpha frames. They must remain `Color.Transparent`.
3. **`p.Split` Clear Fallback**: Line 433 of `DockSheet.cs` contains `Color.Transparent` as the second color in `p.Split(..., p.T.Accent, Color.Transparent)`. This is a gradient mask parameter and is correct as is.

---

## 4. Conclusion & Drop-In Code Diffs

All hardcoded semantic colors (`BadgeRed`, `BadgeRedSoft`, white text on badges, and white rim lights/sheen) can be cleanly tokenized with zero architectural overhead.

### 4.1 Target File: `src/DockPaint.cs`

#### Diff DP-1: RimLight, Sheen, and Rim Tokenization (Lines 214–268)

```csharp
<<<<
            // Glass catches light on its top edge, a little on the bottom
            void RimLight(RectangleF r, GraphicsPath path)
            {
                using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, r.Height + 2), Color.White, Color.White, 90f))
                {
                    var cb = new ColorBlend(3);
                    cb.Colors = new[] { Color.FromArgb(Ink.Light ? 170 : 120, 255, 255, 255), Color.FromArgb(Ink.Light ? 50 : 16, 255, 255, 255), Color.FromArgb(Ink.Light ? 110 : 52, 255, 255, 255) };
                    cb.Positions = new[] { 0f, 0.5f, 1f };
                    lg.InterpolationColors = cb;
                    using (var pen = new Pen(lg, 1f)) g.DrawPath(pen, path);
                }
            }

            static GraphicsPath Box(RectangleF r)
            {
                var gp = new GraphicsPath();
                gp.AddRectangle(r);
                return gp;
            }

            // Light from above; the pointer warms the glass under it
            void Sheen(RectangleF r)
            {
                float h = Math.Min(r.Height * 0.55f, 28);
                using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, h + 2), Color.FromArgb(Ink.Light ? 80 : 24, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                    g.FillRectangle(lg, r.X, r.Y, r.Width, h);
                if (hover.Value < 0.01f || mouseX < r.Left - 60 || mouseX > r.Right + 60) return;
                float rx = Math.Max(70, r.Height * 1.7f), ry = r.Height * 1.05f;
                using (var gp = new GraphicsPath())
                {
                    gp.AddEllipse(mouseX - rx, r.Top - ry * 0.55f, rx * 2, ry * 2);
                    using (var pb = new PathGradientBrush(gp))
                    {
                        pb.CenterColor = Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), 255, 255, 255);
                        pb.SurroundColors = new[] { Color.FromArgb(0, 255, 255, 255) };
                        g.FillPath(pb, gp);
                    }
                }
            }

            // Top edge catches the light near the pointer
            void Rim(RectangleF r, float radius)
            {
                if (hover.Value < 0.01f || mouseX < r.Left || mouseX > r.Right) return;
                float span = Math.Max(60, r.Height * 1.5f);
                float a = Math.Max(r.Left + radius * 0.7f, mouseX - span), b = Math.Min(r.Right - radius * 0.7f, mouseX + span);
                if (b - a < 2) return;
                using (var lg = new LinearGradientBrush(new PointF(mouseX - span, 0), new PointF(mouseX + span, 0), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(0, 255, 255, 255)))
                {
                    var blend = new ColorBlend(3);
                    int peak = (int)(hover.Value * (Ink.Light ? 230 : 150));
                    blend.Colors = new[] { Color.FromArgb(0, 255, 255, 255), Color.FromArgb(peak, 255, 255, 255), Color.FromArgb(0, 255, 255, 255) };
                    blend.Positions = new[] { 0f, 0.5f, 1f };
                    lg.InterpolationColors = blend;
                    using (var pen = new Pen(lg, 1.3f)) g.DrawLine(pen, a, r.Top + 0.65f, b, r.Top + 0.65f);
                }
            }
====
            // Glass catches light on its top edge, a little on the bottom
            void RimLight(RectangleF r, GraphicsPath path)
            {
                using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, r.Height + 2), p.T.Highlight, p.T.Highlight, 90f))
                {
                    var cb = new ColorBlend(3);
                    cb.Colors = new[] { Color.FromArgb(Ink.Light ? 170 : 120, p.T.Highlight), Color.FromArgb(Ink.Light ? 50 : 16, p.T.Highlight), Color.FromArgb(Ink.Light ? 110 : 52, p.T.Highlight) };
                    cb.Positions = new[] { 0f, 0.5f, 1f };
                    lg.InterpolationColors = cb;
                    using (var pen = new Pen(lg, 1f)) g.DrawPath(pen, path);
                }
            }

            static GraphicsPath Box(RectangleF r)
            {
                var gp = new GraphicsPath();
                gp.AddRectangle(r);
                return gp;
            }

            // Light from above; the pointer warms the glass under it
            void Sheen(RectangleF r)
            {
                float h = Math.Min(r.Height * 0.55f, 28);
                using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, h + 2), Color.FromArgb(Ink.Light ? 80 : 24, p.T.Highlight), Color.FromArgb(0, p.T.Highlight), 90f))
                    g.FillRectangle(lg, r.X, r.Y, r.Width, h);
                if (hover.Value < 0.01f || mouseX < r.Left - 60 || mouseX > r.Right + 60) return;
                float rx = Math.Max(70, r.Height * 1.7f), ry = r.Height * 1.05f;
                using (var gp = new GraphicsPath())
                {
                    gp.AddEllipse(mouseX - rx, r.Top - ry * 0.55f, rx * 2, ry * 2);
                    using (var pb = new PathGradientBrush(gp))
                    {
                        pb.CenterColor = Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), p.T.Highlight);
                        pb.SurroundColors = new[] { Color.FromArgb(0, p.T.Highlight) };
                        g.FillPath(pb, gp);
                    }
                }
            }

            // Top edge catches the light near the pointer
            void Rim(RectangleF r, float radius)
            {
                if (hover.Value < 0.01f || mouseX < r.Left || mouseX > r.Right) return;
                float span = Math.Max(60, r.Height * 1.5f);
                float a = Math.Max(r.Left + radius * 0.7f, mouseX - span), b = Math.Min(r.Right - radius * 0.7f, mouseX + span);
                if (b - a < 2) return;
                using (var lg = new LinearGradientBrush(new PointF(mouseX - span, 0), new PointF(mouseX + span, 0), Color.FromArgb(0, p.T.Highlight), Color.FromArgb(0, p.T.Highlight)))
                {
                    var blend = new ColorBlend(3);
                    int peak = (int)(hover.Value * (Ink.Light ? 230 : 150));
                    blend.Colors = new[] { Color.FromArgb(0, p.T.Highlight), Color.FromArgb(peak, p.T.Highlight), Color.FromArgb(0, p.T.Highlight) };
                    blend.Positions = new[] { 0f, 0.5f, 1f };
                    lg.InterpolationColors = blend;
                    using (var pen = new Pen(lg, 1.3f)) g.DrawLine(pen, a, r.Top + 0.65f, b, r.Top + 0.65f);
                }
            }
>>>>
```

#### Diff DP-2: Notification Badge Tokenization (Lines 647–660)

```csharp
<<<<
            // White numbers on it reach 4.77:1
            static readonly Color BadgeRed = Color.FromArgb(255, 217, 48, 37);

            // Unread count from Windows notifications
            void Badge(RectangleF r, int n)
            {
                string s = n > 99 ? "99+" : n.ToString();
                var f = Ink.SmallSemi(11f);
                float h = 17, w = Math.Max(h, p.Measure(s, f) + 9);
                var b = new RectangleF(r.Right - w * 0.7f, r.Top - h * 0.28f, w, h);
                p.FillRound(Inset(b, -1.2f), (h + 2.4f) / 2, Ink.A(Ink.Base.Bg, 0.55f));
                p.FillRound(b, h / 2, BadgeRed);
                p.TextCenter(s, f, Color.White, b.X + b.Width / 2, b.Y + h / 2);
            }
====
            // Unread count from Windows notifications
            void Badge(RectangleF r, int n)
            {
                string s = n > 99 ? "99+" : n.ToString();
                var f = Ink.SmallSemi(11f);
                float h = 17, w = Math.Max(h, p.Measure(s, f) + 9);
                var b = new RectangleF(r.Right - w * 0.7f, r.Top - h * 0.28f, w, h);
                p.FillRound(Inset(b, -1.2f), (h + 2.4f) / 2, Ink.A(p.T.Bg, 0.55f));
                p.FillRound(b, h / 2, p.T.Negative);
                p.TextCenter(s, f, p.T.IsDark ? p.T.Bg : Color.White, b.X + b.Width / 2, b.Y + h / 2);
            }
>>>>
```

---

### 4.2 Target File: `src/DockCard.cs`

#### Diff DC-1: Sheen & Border Tokenization (Lines 369–373)

```csharp
<<<<
                    using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, 40), Color.FromArgb((int)(fade * (Ink.Light ? 80 : 22)), 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                        g.FillRectangle(lg, r.X, r.Y, r.Width, 39);
                    g.Restore(st);
                    g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255), 1f), path);
====
                    using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, 40), Color.FromArgb((int)(fade * (Ink.Light ? 80 : 22)), p.T.Highlight), Color.FromArgb(0, p.T.Highlight), 90f))
                        g.FillRectangle(lg, r.X, r.Y, r.Width, 39);
                    g.Restore(st);
                    g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, p.T.Highlight), 1f), path);
>>>>
```

#### Diff DC-2: Close Button & `BadgeRedSoft` Tokenization (Lines 411–415 & Line 434)

```csharp
<<<<
                        hits.Add(new KeyValuePair<RectangleF, string>(t.Close, "x" + id));
                        if (hot == "x" + id) p.FillRound(t.Close, 6, BadgeRedSoft);
                        p.Icon('\uE711', 9.5f, hot == "x" + id ? Color.White : p.T.Sub, t.Close.X + t.Close.Width / 2, t.Close.Y + t.Close.Height / 2);
====
                        hits.Add(new KeyValuePair<RectangleF, string>(t.Close, "x" + id));
                        if (hot == "x" + id) p.FillRound(t.Close, 6, p.T.Negative);
                        p.Icon('\uE711', 9.5f, hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub, t.Close.X + t.Close.Width / 2, t.Close.Y + t.Close.Height / 2);
>>>>
```

And remove definition on line 434:
```csharp
<<<<
            static readonly Color BadgeRedSoft = Color.FromArgb(230, 196, 43, 28);
====
>>>>
```

---

### 4.3 Target File: `src/DockSheet.cs`

#### Diff DS-1: Sheen & Border Tokenization (Lines 267–276)

```csharp
<<<<
                    using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, 58), Color.FromArgb((int)(fade * (Ink.Light ? 80 : 22)), 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                    {
                        // No wrap: a tiled gradient leaves a bright seam
                        lg.WrapMode = WrapMode.TileFlipXY;
                        g.FillRectangle(lg, r.X, r.Y, r.Width, 54);
                    }
                    Backdrop(r);
                    g.Restore(st);
                    g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255), 1f), path);
====
                    using (var lg = new LinearGradientBrush(new RectangleF(r.X, r.Y - 1, r.Width, 58), Color.FromArgb((int)(fade * (Ink.Light ? 80 : 22)), p.T.Highlight), Color.FromArgb(0, p.T.Highlight), 90f))
                    {
                        // No wrap: a tiled gradient leaves a bright seam
                        lg.WrapMode = WrapMode.TileFlipXY;
                        g.FillRectangle(lg, r.X, r.Y, r.Width, 54);
                    }
                    Backdrop(r);
                    g.Restore(st);
                    g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, p.T.Highlight), 1f), path);
>>>>
```

---

## 5. Verification Method

### 5.1 Static Code Cleanliness Verification

To independently verify that all hardcoded colors have been eradicated from the 3 files:

```powershell
$files = @("src\DockPaint.cs", "src\DockCard.cs", "src\DockSheet.cs")
$pattern = "BadgeRed|BadgeRedSoft|Color\.FromArgb\([^)]*255,\s*255,\s*255\)"
$matches = Get-ChildItem $files | Select-String -Pattern $pattern
if ($matches) {
    Write-Error "Verification failed: Remaining hardcoded colors found:"
    $matches | ForEach-Object { Write-Host "$($_.Filename):$($_.LineNumber): $($_.Line)" }
} else {
    Write-Host "PASS: All target hardcoded colors successfully eliminated from Dock files."
}
```

### 5.2 Build Verification

Run the project build script from project root:
```cmd
build.cmd
```
**Pass Criteria**: `Tepi.exe` builds cleanly with zero compile errors and zero warnings.

### 5.3 Automated WCAG AA Contrast Verification Script

Run the following PowerShell assertion to independently verify contrast ratios:

```powershell
Add-Type -AssemblyName System.Drawing

function Get-Luminance($color) {
    $c = @($color.R, $color.G, $color.B) | ForEach-Object {
        $v = $_ / 255.0
        if ($v -le 0.03928) { $v / 12.92 } else { [Math]::Pow(($v + 0.055) / 1.055, 2.4) }
    }
    return 0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2]
}

function Get-ContrastRatio($c1, $c2) {
    $l1 = Get-Luminance $c1
    $l2 = Get-Luminance $c2
    $max = [Math]::Max($l1, $l2)
    $min = [Math]::Min($l1, $l2)
    return [Math]::Round(($max + 0.05) / ($min + 0.05), 2)
}

# Dark Theme tokens
$darkBg = [System.Drawing.Color]::FromArgb(255, 0, 0, 0)
$darkNeg = [System.Drawing.Color]::FromArgb(255, 240, 120, 120)
$darkBadgeText = $darkBg

# Light Theme tokens
$lightBg = [System.Drawing.Color]::FromArgb(255, 245, 245, 245)
$lightNeg = [System.Drawing.Color]::FromArgb(255, 190, 50, 50)
$lightBadgeText = [System.Drawing.Color]::White

# Assertions
$c1 = Get-ContrastRatio $darkBadgeText $darkNeg
$c2 = Get-ContrastRatio $darkNeg $darkBg
$c3 = Get-ContrastRatio $lightBadgeText $lightNeg
$c4 = Get-ContrastRatio $lightNeg $lightBg

Write-Host "Dark Mode Badge Text vs Badge Bg: $c1 : 1 (Expect >= 4.5)"
Write-Host "Dark Mode Badge Bg vs Dock Surface: $c2 : 1 (Expect >= 4.5)"
Write-Host "Light Mode Badge Text vs Badge Bg: $c3 : 1 (Expect >= 4.5)"
Write-Host "Light Mode Badge Bg vs Dock Surface: $c4 : 1 (Expect >= 4.5)"

if ($c1 -ge 4.5 -and $c2 -ge 4.5 -and $c3 -ge 4.5 -and $c4 -ge 4.5) {
    Write-Host "PASS: 100% WCAG AA compliance verified."
} else {
    Write-Error "FAIL: Contrast below 4.5:1 threshold."
}
```

### 5.4 Invalidation Conditions

The conclusions and diffs in this report would be invalidated if:
1. `Tone.cs` alters `t.Negative` definitions to values where luminance $L \in (0.17, 0.25)$, where neither pure black nor pure white achieves 4.5:1 contrast.
2. A refactoring decouples `Painter.T` (`p.T`) from `DockWindow`, `DockCard`, or `GlassSheet` rendering routines.
