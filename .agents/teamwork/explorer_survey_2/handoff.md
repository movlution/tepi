# Handoff Report: Core UI Architecture & Visual Survey (Island, Dock, Mini, Views/Panels)

**Explorer Role**: Core UI Explorer  
**Date**: 2026-11-12  
**Target Repository**: `d:\PROJECT\Other\tepi`  
**Build Status**: Verified clean build via `build.cmd` (`Tepi.exe` built successfully)  

---

## 1. Observation

### 1.1 Architecture & Component Mapping
Inspection of the codebase confirms that Tepi does **not** use XAML, WPF, or WinUI. It is an entirely custom, owner-drawn Windows Forms (.NET Framework 4.8) application rendering to per-pixel alpha layered windows (`UpdateLayeredWindow`) via GDI+ (`System.Drawing`) with custom double buffering and tokenized painters (`Painter`, `Tone`, `Ink`).

All core UI components map to the following C# files in `src/`:
- **Island (Main Floating HUD & Pill)**:
  - `src/Island.cs` (1,901 lines): Primary window lifecycle, layout, layered rendering, elevation shadows, squircle clipping, backdrop/glass orchestration.
  - `src/Tabs.cs` (892 lines): Island tab bar navigation, page switching, hover/pressed pill animations.
  - `src/Keyboard.cs` (175 lines): Island keyboard navigation focus ring (`DrawFocusRing`), hotkeys, accessibility announcements.
  - `src/EdgeLight.cs` (10,284 bytes): Island edge border glow effects.
- **Dock (Taskbar Alternative / Application Dock)**:
  - `src/DockWindow.cs` (30,752 bytes): Dock window lifecycle, positioning, monitor tracking, autohide, tray integration.
  - `src/DockPaint.cs` (1,024 lines): Dock surface rendering, center/left/right pill composition, glass sheen, rim lights, unread badges.
  - `src/DockCard.cs` (24,955 bytes): Thumbnail preview popups and window flyouts.
  - `src/DockSheet.cs` (21,814 bytes): Dock expanded sheets and sliders.
  - `src/DockShell.cs` (25,632 bytes): Shell integration, pinning, process monitoring.
  - `src/DockCal.cs`, `src/DockQuick.cs`, `src/DockStart.cs`, `src/DockApps.cs`, `src/DockTray.cs`: Dock module popouts.
- **Mini (Minimalist Sliver Indicator)**:
  - `src/Mini.cs` (488 lines): Sliver geometry (`56x6` px / `40x14` px), dwell/peek edge detection, click-through (`WS_EX_TRANSPARENT`), activity progress rendering.
- **Panels, Views, and Controls**:
  - `src/Panel.cs` (472 lines): Shared panel containers, headers, scroll states, search bars, empty states.
  - `src/Views.cs` (949 lines): Primary view router (`DrawView`), view dimensions (`ViewRadius`), header rows, clock rendering.
  - `src/Parts.cs` (413 lines): Core reusable UI primitives (`Module`, `Pill`, `Button`, `EmptyState`, `Ring`, `CircleToggle`).
  - `src/Kit.cs` (785 lines): Custom WinForms controls for dialogs and settings (`KitButton`, `KitSwitch`, `KitSlider`, `KitRow`, `KitGroup`, `KitText`).
  - View modules: `src/Overview.cs`, `src/Suara.cs`, `src/Schedule.cs`, `src/Clips.cs`, `src/Reminders.cs`, `src/Music.cs`, `src/Control.cs`, `src/Handset.cs`, `src/Mixer.cs`, `src/SuruhChat.cs`, `src/WorkWindow.cs`, `src/Kulia.cs`.
- **Design Tokens & Surface Infrastructure**:
  - `src/Ink.cs` (1,065 lines): Single source of truth for color tokens (`Tone`), type scale, squircle geometry, cached symbols, Painter.
  - `src/Colors.cs` (209 lines): Palette derivation, WCAG contrast calculation (`Contrast`, `Luminance`).
  - `src/Glass.cs` (745 lines): Multi-threaded backdrop capture, blur passes, Frosted and Liquid glass composition.

---

### 1.2 Direct Code Observations & Evidence Chain

#### A. Island Component (`src/Island.cs`, `src/Tabs.cs`)
1. **Missing `OnGlass()` Contrast Adjustment in Island Content**:
   - In `src/Island.cs:805`: `p.T = Ink.Base;`
   - In `src/Island.cs:846`: `DrawContent(now, Ink.Base, flip < 0.5f);`
   - In `src/Island.cs:1240-1244`:
     ```csharp
     void DrawContent(DateTime now, Tone tone, bool registerHits)
     {
         p.T = tone;
         p.Shadow = GlassOn && !LiquidOn && tone.Bg.R < 128 && current != View.Panel;
     ```
   - Contrast with Dock in `src/DockPaint.cs:35`:
     ```csharp
     p.T = Glass ? Ink.Base.OnGlass() : Ink.Base;
     ```
   - **Observation**: `Tone.OnGlass()` (`src/Ink.cs:28-33`) explicitly raises `Sub` alpha to $\ge 189$ (74%) to ensure 4.5:1 WCAG contrast on bright wallpapers. Dock properly utilizes `OnGlass()`, but Island applies raw `Ink.Base`, leaving secondary text on Island glass surfaces vulnerable to sub-3:1 contrast on bright wallpapers.

2. **Drop Shadow Completely Suppressed on Pill State with Glass**:
   - In `src/Island.cs:816-821`:
     ```csharp
     // Glass pills skip the drop shadow
     if ((!GlassOn || H > 60) && current != View.Prompter)
     {
         DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), 1f);
         if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, 0.7f);
     }
     ```
   - **Observation**: When `GlassOn == true` and Island is in pill state ($H \le 60$), the 9-slice drop shadow is completely skipped. On light desktop wallpapers, the pill loses elevation separation and appears flat and disconnected.

3. **Approval Halo Animation Ignores "Kurangi Gerak" (`Anim.Reduced`)**:
   - In `src/Island.cs:1139-1144`:
     ```csharp
     void DrawGlow(DateTime now, RectangleF r, float radius)
     {
         if (flip < 0.05f) return;
         float breath = 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
     ```
   - **Observation**: The breathing pulse runs a trigonometric oscillation without checking `Anim.Reduced`. When users request reduced motion, this halo continues pulsing continuously.

4. **Inverted Fill State Logic Bug in `Tabs.cs`**:
   - In `src/Tabs.cs:519`:
     ```csharp
     if (Hover("tab" + to) && to != page) p.FillRound(rects[i], TabH / 2, Pressed("tab" + to) ? p.T.FillHover : p.T.Fill);
     ```
   - In `src/Tabs.cs:821`:
     ```csharp
     if (Hover("prefsOpen")) p.FillRound(r, TabH / 2, Pressed("prefsOpen") ? p.T.FillHover : p.T.Fill);
     ```
   - In `src/Tabs.cs:832`:
     ```csharp
     if (Hover(id)) p.FillRound(r, TabH / 2, Pressed(id) ? p.T.FillHover : p.T.Fill);
     ```
   - In `src/Tabs.cs:847`:
     ```csharp
     if (Hover("musicView")) p.FillRound(r, TabH / 2, Pressed("musicView") ? p.T.FillHover : p.T.Fill);
     ```
   - Compare with correct implementation in `src/Parts.cs:103`:
     ```csharp
     return Pressed(id) ? p.T.FillPressed : Hover(id) ? p.T.FillHover : p.T.Fill;
     ```
   - **Observation**: When hovered, `Tabs.cs` renders `p.T.Fill` (the un-hovered background). When pressed, it renders `p.T.FillHover` instead of `p.T.FillPressed`. The hover and pressed visual affordances are inverted and degraded.

---

#### B. Dock Component (`src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`)
1. **Hardcoded Color Literals Bypassing `Ink.cs` Tokens**:
   - In `src/DockPaint.cs:648`:
     ```csharp
     static readonly Color BadgeRed = Color.FromArgb(255, 217, 48, 37);
     ```
   - In `src/DockPaint.cs:659`:
     ```csharp
     p.TextCenter(s, f, Color.White, b.X + b.Width / 2, b.Y + h / 2);
     ```
   - In `src/DockCard.cs:414`:
     ```csharp
     p.Icon('\uE711', 9.5f, hot == "x" + id ? Color.White : p.T.Sub, t.Close.X + t.Close.Width / 2, ...);
     ```
   - In `src/DockCard.cs:434`:
     ```csharp
     static readonly Color BadgeRedSoft = Color.FromArgb(230, 196, 43, 28);
     ```
   - In `src/DockPaint.cs:219`:
     ```csharp
     cb.Colors = new[] { Color.FromArgb(Ink.Light ? 170 : 120, 255, 255, 255), Color.FromArgb(Ink.Light ? 50 : 16, 255, 255, 255), Color.FromArgb(Ink.Light ? 110 : 52, 255, 255, 255) };
     ```
   - In `src/DockCard.cs:372` & `src/DockSheet.cs:275`:
     ```csharp
     g.DrawPath(p.P(Color.FromArgb(Ink.Light ? 70 : 40, 255, 255, 255), 1f), ...);
     ```
   - **Observation**: Hardcoded white and red RGB values are used for badges, close icons, and rim borders rather than referencing `p.T.Negative`, `p.T.Highlight`, or semantic tokens. In light mode or custom themes, these hardcoded values break palette coherence.

2. **Incomplete Interaction States in Dock Modules**:
   - In `src/DockCal.cs:56`:
     ```csharp
     p.FillRound(b, 8, hotId == "clear" ? p.T.FillHover : p.T.Fill);
     ```
   - In `src/DockCal.cs:143`:
     ```csharp
     p.FillRound(b, 15, quiet ? p.T.Accent : hotId == "quiet" ? p.T.FillHover : p.T.Fill);
     ```
   - **Observation**: Buttons only evaluate hover state (`hotId`) without handling `pressId == id ? p.T.FillPressed : p.T.FillHover`, leading to a dead click feel with no downward tactile feedback.

---

#### C. Mini Component (`src/Mini.cs`)
1. **Sub-Minimal Visual Target Sizing**:
   - In `src/Mini.cs:15`:
     ```csharp
     const float MiniW = 56, MiniH = 6, MiniBusyW = 64, MiniBusyH = 8;
     ```
   - In `src/Mini.cs:390, 399, 433`:
     ```csharp
     if (dot) p.Circle(w - 9, h / 2, 1.7f, MicSilenced || RapatOn ? p.T.Negative : p.T.Accent);
     ```
   - In `src/Mini.cs:407`:
     ```csharp
     var track = new RectangleF(cx - 1, 8, 2, h - 16);
     ```
   - **Observation**: A notification dot with radius $1.7\text{ px}$ (diameter $3.4\text{ px}$) and a vertical progress track of $2\text{ px}$ width fail standard visual salience guidelines. Users cannot reliably perceive urgent privacy or meeting notification states at a glance.

---

#### D. Views, Panels, and Custom Controls (`src/Panel.cs`, `src/Views.cs`, `src/Kit.cs`, `src/Parts.cs`)
1. **Ad-Hoc Font Scale Drift (19 Distinct Font Sizes)**:
   - `src/Ink.cs:231-237` establishes 7 standard roles:
     - `Hero` (40px), `Title1` (22px), `Title2` (17px), `Headline` (14.5px), `Body` (13.5px), `Callout` (12.5px), `Caption` (11px).
   - In practice, `src/Panel.cs`, `src/Views.cs`, and view files make 417 calls to `Ink.*(px)` with 19 non-standard sizes, including half-pixel values:
     - `10f`, `10.5f` (`Panel.cs:244, 357`), `11f`, `11.5f` (`Panel.cs:262, 362, 455`), `12f` (`Panel.cs:258, 370`), `12.5f`, `13f` (`Panel.cs:31, 141, 326, 385`), `13.5f`, `14f`, `14.5f`, `15f` (`Panel.cs:17`), `15.5f` (`Panel.cs:105`, `Views.cs:230`), `17f`, `18f`, `20f`, `22f`, `26f`, `34f`, `44f`.
   - **Observation**: Over-specification of intermediate sizes creates typographic disharmony and misaligned baseline rhythms across screens.

2. **Arbitrary Literal Corner Radii (21 Distinct Radius Literals)**:
   - `src/Ink.cs:189-192` specifies concentric geometric rules:
     - `RadiusShell` = 32, `RadiusModule` = 20, `RadiusControl` = 12, `ModuleInset` = 12.
   - In `src/Views.cs:66`, `ViewRadius` hardcodes `30` for Panel/Approve, `26` for Track/Notif, `28` for Mirror, leaving `RadiusShell` with zero calls.
   - Across `FillRound` calls in views, 21 arbitrary literals are used: `1`, `1.5`, `2`, `2.5`, `5`, `6`, `7`, `8`, `9`, `10`, `10.5`, `11`, `12`, `13`, `14`, `15`, `16`, `18`, `20`, `22`.

3. **Duplicated Empty State Implementation**:
   - `src/Panel.cs:13-20` declares:
     ```csharp
     float Empty(float w, char glyph, string title, string detail)
     {
         float top = PanelTop + 20;
         p.Icon(glyph, 20f, p.T.Sub, w / 2, top + 12);
         p.TextCenter(title, Ink.Semi(15f), p.T.Text, w / 2, top + 44);
         p.TextBox(detail, Ink.Text(12.5f), p.T.Sub, new RectangleF(48, top + 58, w - 96, 38), StringAlignment.Center);
         return top + 104;
     }
     ```
   - `src/Parts.cs:374-387` defines a standardized component:
     ```csharp
     void EmptyState(RectangleF area, char icon, string title, string line, string action, string id, Action act)
     ```
   - **Observation**: `Panel.cs` bypasses the shared `EmptyState` component, introducing inconsistent padding, ad-hoc font sizes (`15f`), and omitting the modular icon enclosure circle.

4. **Interactive State Deficiencies in `Kit.cs`**:
   - **`KitButton` lacks pressed feedback** (`src/Kit.cs:383-421`): Tracks `hovered`, but has no `pressed` state in `OnPaint` (`Color bg = Primary ? (hovered ? ... : ...) : (hovered ? ... : ...)`). Clicking the button yields no visual depression.
   - **`KitSwitch` lacks hover feedback** (`src/Kit.cs:168-214`): Does not override `OnMouseEnter`/`OnMouseLeave` and does not alter track or knob color on mouseover.
   - **`KitSlider` disabled thumb contrast bug** (`src/Kit.cs:360-363`): Track responds to `Enabled ? KitInk.Text : KitInk.Disabled`, but thumb at line 362 always executes `using (var b = new SolidBrush(KitInk.Text)) g.FillEllipse(...)`, making the thumb appear active even when the slider is disabled.
   - **`KitRow` hardcoded black pill** (`src/Kit.cs:587`): `using (var p2 = Ink.Round(pill, 5 * s)) g.FillPath(Brushes.Black, p2);` draws pure black on `KitInk.Hover` (dark gray `#1C1C1E` in dark mode), rendering the glyph mark invisible.

5. **Hardcoded Colors in Other Panel Views**:
   - `src/Kulia.cs:363-377`: Direct hardcoded `Color.FromArgb(245, 245, 245)`, `Color.FromArgb(10, 10, 10)`, `Color.FromArgb(88, 88, 88)`, and `Color.White` instead of `Ink.Base` tokens.
   - `src/SuruhChat.cs:268`: Hardcoded `Color.FromArgb(255, 18, 18, 20)`.
   - `src/WorkWindow.cs:601`: Hardcoded `Color.FromArgb(224, 96, 84)` for overdue task indicators rather than `p.T.Negative`.

6. **Contrast Failures on Light Theme Preset Accents**:
   - In `src/Prefs.cs:181-182`, preset accents include Biru (`#4C8DFF`), Hijau (`#3DD68C`), and Kuning (`#FFD24A`).
   - On light theme (`Tone.Paper.Bg = #F5F5F5`):
     - Kuning (`#FFD24A`) yields **1.32:1** contrast.
     - Hijau (`#3DD68C`) yields **1.72:1** contrast.
     - Biru (`#4C8DFF`) yields **2.94:1** contrast.
   - **Observation**: For non-text UI elements (progress bars, focus borders, active indicators), WCAG 2.1 Success Criterion 1.4.11 mandates $\ge 3:1$ contrast against adjacent background. Three official preset accents fail this standard on light theme.

---

## 2. Logic Chain

1. **Premise 1 (WCAG AA Compliance)**:
   Requirements R2 and R3 demand strict adherence to WCAG AA ($\ge 4.5:1$ for normal text, $\ge 3:1$ for large text and key UI components).
2. **Step 2 (Island Secondary Text & Glass)**:
   Observation 1.2.A.1 shows `Island.cs` directly uses `Ink.Base` when rendering content over glass, rather than `Ink.Base.OnGlass()`. Because `Ink.Base.Sub` has alpha 158 (62%), when drawn over frosted glass against a light wallpaper, the effective luminance results in contrast dropping below 3.5:1. Therefore, Island must use `tone.OnGlass()` during glass rendering to guarantee 4.5:1 contrast.
3. **Step 3 (Island Pill Elevation)**:
   Observation 1.2.A.2 proves that `H <= 60 && GlassOn` skips `DrawShadow`. Without an elevation shadow, a translucent white/gray pill over a light wallpaper lacks edge boundary definition and optical separation. Therefore, a subtle glass-adapted elevation shadow is required.
4. **Step 4 (Interaction State Integrity)**:
   Observations 1.2.A.4, 1.2.B.2, and 1.2.D.4 document broken or inverted states across `Tabs.cs` (`Hover` applying default fill, `Pressed` applying hover fill), `KitButton` (missing pressed state), `KitSwitch` (missing hover state), and `KitSlider` (thumb failing disabled state). User interactions in production must provide clear, predictable visual affordance for all 4 states (rest, hover, pressed, disabled).
5. **Step 5 (Design System Unification)**:
   Observations 1.2.D.1, 1.2.D.2, 1.2.D.3, and 1.2.B.1 show rampant ad-hoc values: 19 font sizes vs. 7 defined type roles, 21 arbitrary radius literals vs. 3 concentric tokens (`RadiusShell`, `RadiusModule`, `RadiusControl`), duplicate `Empty` implementations, and hardcoded `Color.FromArgb` values in Dock, Kit, and views. Consolidating these to `Ink.cs` tokens directly satisfies Requirement R2 and eliminates maintenance drift.
6. **Step 6 (Preset & Theme Safety)**:
   Observation 1.2.D.6 shows Yellow (1.32:1) and Green (1.72:1) failing WCAG 3:1 against light backgrounds. Applying theme-adaptive luminance adjustments for light mode (darkening light-mode accents or using a darker ink tone) will ensure WCAG AA compliance across all presets.

---

## 3. Caveats

1. **GDI+ Hardware Acceleration Limitations**:
   Because Tepi relies on GDI+ (`System.Drawing`) with CPU rasterization onto layered windows, adding dynamic heavy blur or multi-pass drop shadows per frame must be cached or sliced (as done in `SliceShadow`) to avoid frame rate degradation.
2. **Third-Party Theme Packs**:
   External theme packs loaded via `theme.ini` can provide arbitrary `#hex` strings. While the core tokens can enforce contrast floors (as in `Colors.DerivePalette`), theme authors may supply arbitrary backgrounds unless an automatic luminance clamp is enforced.
3. **High Contrast Mode**:
   Windows system High Contrast (`SystemInformation.HighContrast`) is currently not hooked into `Tone.Dark()` or `Tone.Paper()`. System accessibility mode detection remains an enhancement area beyond basic token cleanup.

---

## 4. Conclusion & Concrete Improvement Recommendations

The visual foundation of Tepi is high quality (squircle geometry, physics-based springs, monochrome design tokens, layered window composition). However, production readiness is hindered by partial token enforcement, hardcoded color leaks, typographic fragmentation, and interaction state bugs.

### Summary of Priority Recommendations & Files to Modify:

| Priority | Component | Issue | File & Line Location | Recommended Fix |
|---|---|---|---|---|
| **P1** | **Island** | Secondary text on glass fails 4.5:1 WCAG | `src/Island.cs:846, 1244` | Apply `tone.OnGlass()` when `GlassOn == true` (`var t = GlassOn ? tone.OnGlass() : tone;`). |
| **P1** | **Island / Tabs** | Inverted hover/pressed fill bug on tabs & buttons | `src/Tabs.cs:519, 821, 832, 847` | Change `Pressed(id) ? p.T.FillHover : p.T.Fill` to `Pressed(id) ? p.T.FillPressed : p.T.FillHover`. |
| **P1** | **Accents** | Preset accents fail 3:1 on light theme | `src/Ink.cs:150-158`, `src/Prefs.cs:181` | Adapt accent luminance for light mode (clamp minimum 3:1 contrast against `#F5F5F5`). |
| **P1** | **Dock** | Hardcoded colors & white rim light | `src/DockPaint.cs:219, 648, 659`, `src/DockCard.cs:414, 434` | Replace with `p.T.Negative`, `p.T.Highlight`, and `p.T.Text`. |
| **P2** | **Island** | Missing drop shadow on glass pill ($H \le 60$) | `src/Island.cs:816` | Render subtle thin shadow on glass pill to preserve elevation on light wallpaper. |
| **P2** | **Island** | Approval glow halo pulses during `Anim.Reduced` | `src/Island.cs:1142` | Add check: `float breath = Anim.Reduced ? 0.8f : (0.55f + 0.45f * (float)Math.Sin(...));`. |
| **P2** | **Kit Controls** | Missing pressed/hover states & disabled thumb bug | `src/Kit.cs:193-210, 362, 402-414, 587` | Add pressed state to `KitButton`, hover to `KitSwitch`, use `KitInk.Disabled` for disabled `KitSlider` thumb, replace `Brushes.Black` with `KitInk.Text` on `KitRow`. |
| **P2** | **Panels / Views** | Typographic fragmentation (19 font sizes) | `src/Panel.cs`, `src/Views.cs` | Standardize font invocations to 7 type roles (`Hero`, `Title1`, `Title2`, `Headline`, `Body`, `Callout`, `Caption`). |
| **P2** | **Panels / Views** | 21 literal corner radius values | `src/Views.cs:66`, `src/Panel.cs`, view files | Unify around concentric tokens: `RadiusShell` (32), `RadiusModule` (20), `RadiusControl` (12). |
| **P2** | **Panels** | Duplicated `Empty` implementation | `src/Panel.cs:13-20` | Refactor `Panel.Empty` to delegate to `Parts.EmptyState` (`src/Parts.cs:374`). |
| **P3** | **Mini** | Sub-scale notification dot ($3.4\text{ px}$) | `src/Mini.cs:390, 399, 433` | Increase notification dot radius from $1.7\text{ px}$ to $\ge 2.5\text{ px}$ (diameter $5\text{ px}$). |

---

## 5. Verification Method

To independently verify these findings:
1. **Compilation Verification**:
   Execute the root build script:
   ```powershell
   .\build.cmd
   ```
   Confirm output displays `Build OK: D:\PROJECT\Other\tepi\Tepi.exe` with exit code 0.
2. **Code Inspection**:
   - Inspect `src/Tabs.cs:519, 821, 832, 847` to confirm the inverted ternary logic (`Pressed ? FillHover : Fill`).
   - Inspect `src/Island.cs:816` to verify shadow suppression when `H <= 60 && GlassOn`.
   - Inspect `src/Island.cs:846` and `1244` to verify `Ink.Base` is passed without `.OnGlass()`.
   - Inspect `src/Kit.cs:362` and `410` to verify `KitSlider` and `KitButton` state oversights.
3. **Contrast Mathematical Verification**:
   - Calculate WCAG 2.1 relative luminance for `Kuning (#FFD24A)` vs `Paper Bg (#F5F5F5)`:
     $L_1 = 0.67$, $L_2 = 0.91 \implies \text{Contrast} = \frac{0.91 + 0.05}{0.67 + 0.05} = \frac{0.96}{0.72} = 1.33:1 < 3.0:1$.
   - Calculate WCAG 2.1 relative luminance for `Faint (alpha 148)` over `#252527` card background against translucent glass.
