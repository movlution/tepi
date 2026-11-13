# Handoff Report — Visual Specification Mining & Design Token Survey

## 1. Observation

A systematic static and dynamic code inspection was executed on the Tepi codebase (`src/*.cs`, 144 source files) together with verification of the authoritative specifications:
- `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md`
- `docs/analisis/01-visual.md` (Initial comprehensive visual audit)
- `docs/analisis/next-visual.md` (Recent audit follow-up post commit `9f6f904`)
- Direct AST/token analysis of `src/Ink.cs`, `src/Colors.cs`, `src/Theme.cs`, `src/WinTheme.cs`, `src/Kit.cs`, `src/Glass.cs`, `src/Island.cs`, `src/DockPaint.cs`, `src/Views.cs`, `src/Prefs.cs`, `src/Mini.cs`, `src/ColorPicker.cs`, `src/Tour.cs`, `src/WhatsNew.cs`, `src/WorkWindow.cs`, and `src/Kulia.cs`.

### Exact File Paths & Code Evidence
1. **Design Tokens & Geometry**:
   - `src/Ink.cs:188`: `public const float Sp4 = 4, Sp8 = 8, Sp12 = 12, Sp16 = 16, Sp20 = 20, Sp24 = 24, Sp32 = 32;` — Audit discovered **0 usages** across the entire repository.
   - `src/Ink.cs:190`: `public const float RadiusShell = 32, RadiusModule = 20, RadiusControl = 12;` — `RadiusShell` has **0 usages**. `Views.cs:66` uses literal `30`, `Views.cs:74` uses `26`, `Views.cs:75` uses `28`.
   - `src/Ink.cs:207, 213`: Font family names have typos:
     - Line 207: `"Segoe UI Variable Display Semib"` (missing "old").
     - Line 213: `"Segoe UI Variable Small Semibol"` (missing "d").
   - `src/Ink.cs:231-237`: 7 type scale roles (`Hero` 40, `Title1` 22, `Title2` 17, `Headline` 14.5, `Body` 13.5, `Callout` 12.5, `Caption` 11).
     - Audit found **371 ad-hoc calls** to `Ink.*(px)` with **19 distinct pixel sizes**: `[10.0, 10.5, 11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5, 15.0, 15.5, 17.0, 18.0, 20.0, 22.0, 26.0, 34.0, 44.0]`.
   - **34 instances of `new Font(...)`** created outside `Ink.cs`:
     - `Kit.cs`: 9 instances (e.g. lines 266, 267, 365, 565, 566, 591, 599, 684, 702).
     - `Prefs.cs`: 9 instances (e.g. lines 399, 619, 620, 632, 638, 1904, 1905, 1906, 2019).
     - `WhatsNew.cs`: 6 instances in paint routines (lines 226, 227, 261, 263, 264, 265).
     - `Prompter.cs`: 3 instances (lines 1012, 1092, 1093).
     - `WorkWindow.cs`: 2 instances (lines 249, 605).
     - `ColorPicker.cs`: line 190 (`new Font("Segoe UI Semibold", 10f, GraphicsUnit.Point)` — point units instead of pixel).
     - `Menus.cs`: line 105 (`new Font(Ink.MenuFamily, 9.5f)`).
     - `Integrations.cs`: line 24.
     - `PrefsDikte.cs`: line 231.
     - `PrefsTabs.cs`: line 57.

2. **Hardcoded Colors & Non-Token Literals**:
   - Total `Color.FromArgb(...)` outside `Ink.cs`/`Colors.cs`: **62 instances** across 18 files.
     - `DockPaint.cs` (14 instances): Line 92 (sensor `1, 0, 0, 0`), line 219 (rim light gradient), line 237 (sheen gradient), line 246 (hover glow), line 264 (specular highlight), line 648 (`BadgeRed = Color.FromArgb(255, 217, 48, 37)`).
     - `DockCard.cs` (4 instances): Line 369, 372, line 434 (`BadgeRedSoft = Color.FromArgb(230, 196, 43, 28)`).
     - `DockSheet.cs` (3 instances): Lines 267, 275.
     - `Kulia.cs` (7 instances): Lines 363-365 hardcoded dark/light palette (`bg`, `fg`, `sub`), line 377 (`BackColor`).
     - `ColorPicker.cs` (3 instances): Line 137 (`BackColor = Color.FromArgb(18, 18, 18)` — ignores theme), line 189.
     - `Island.cs` (3 instances): Line 1132 (shadow alpha), line 1149 (halo breath glow), line 1890.
     - `WorkWindow.cs` (1 instance): Line 601 (`late ? Color.FromArgb(224, 96, 84) : KitInk.Sub` — hardcoded late task color).
     - `SuruhChat.cs` (1 instance): Line 268.
     - `Music.cs` (7 instances): Vinyl graphics lines 511, 513, 514, 519, 565.
     - `Glass.cs` (7 instances): Lines 483, 573, 614, 615, 624, 645 (sheen and rim highlights).
   - Hex color string literals (26 instances):
     - `Prefs.cs:181-182`: 7 preset accents (`#4C8DFF`, `#3DD68C`, `#FFD24A`, `#FF9F43`, `#FF6B9A`, `#A78BFA`, `#7F8DC6`).
     - `Prefs.cs:922-923`: Palette swatches (`#000000`, `#1C1C1E`, `#0E1734`, `#0F2A22`, `#FFFFFF`, `#F5EFE6`, `#EEF4FF`, `#111111`, `#3B2F2F`).
     - `Redact.cs:50-51, 96`: Marker tool colors (`#FF3B30`, `#FFD24A`, `#3DD68C`, `#4C8DFF`, `#FF9F43`, `#A78BFA`, `#FFFFFF`, `#111111`).

3. **WCAG Contrast & Theme Materials**:
   - `Tone.Dark()`:
     - Text on Bg: `19.29:1` (PASS)
     - Sub (alpha 158) on Bg: `7.29:1` (PASS)
     - Faint (alpha 148) on Bg: `6.42:1` (PASS)
   - `Tone.Paper()`:
     - Text on Bg: `17.93:1` (PASS)
     - Sub (alpha 158) on Bg: `5.34:1` (PASS)
     - Faint (alpha 148) on Bg: `4.67:1` (PASS)
   - `OnGlass()` (`Ink.cs:28-33`):
     - Sets Sub alpha to `>=189` (74%) to maintain `>=4.5:1` over translucent glass.
     - Called in `DockCard.cs:343`, `DockPaint.cs:35`, `DockSheet.cs:241`.
     - **NEVER called in `Island.cs`** (lines 805, 871, 1242 use `Ink.Base` or unadjusted tone).
   - `Frost` Material (`Glass.cs:326-327`):
     - No contrast guard. Tints with constant `BaseTint = 0.42f`.
     - On white wallpaper (`#FFFFFF`) with dark mode, background becomes `#949494`.
     - Text contrast drops to `3.0:1` (FAILS WCAG AA 4.5:1).
     - Sub drops to `2.72:1`, Faint drops to `1.86:1`.
   - `Liquid` Material (`Glass.cs:389-421`):
     - Contrast alpha is computed from linear luminance (`Linear[...]`), but blended directly onto non-linear sRGB bytes (`outPx[i] = (byte)(b + (bg.B - b) * a)`).
     - Result: Light theme on dark wallpaper lands on luminance 0.38 instead of `>=0.62`, resulting in Sub text contrast of `3.81:1` (FAILS WCAG AA).
     - Dark theme on white wallpaper hits `aMax = 0.9` (`#191919`), rendering almost completely opaque black and losing translucent glass character.
   - `Accent Presets`:
     - `OnAccent` text contrast is fixed (picks dark `#0A0A0A` for all 7 presets, achieving `6.15:1` to `13.74:1` PASS).
     - Non-text contrast (accents as progress bar, badge, active indicator) on Paper background (`#F5F5F5`):
       - Biru: `2.94:1` (FAILS WCAG 3:1)
       - Hijau: `1.72:1` (FAILS WCAG 3:1)
       - Kuning: `1.32:1` (FAILS WCAG 3:1)
       - Oranye: `1.87:1` (FAILS WCAG 3:1)
       - Merah muda: `2.46:1` (FAILS WCAG 3:1)
       - Ungu: `2.50:1` (FAILS WCAG 3:1)
       - Navy: `2.95:1` (FAILS WCAG 3:1)
       - **All 7 presets fail WCAG 3:1 non-text contrast** on light theme when rendered without outline/stroke.
   - Custom palette derivation (`Colors.cs:69-95`):
     - Does not enforce contrast on user-selected `bg` and `text` (permits combinations like `#222222` and `#333333` with contrast `1.26:1`).
   - Windows High Contrast & Large Text (`SystemInformation.HighContrast`, `SystemColors`):
     - 0 references across all files.

4. **Component Defects & Alignment**:
   - `Island.cs:1139-1151`: Halo glow `DrawGlow` continuously oscillates via `Math.Sin(...) * 1.3` without checking `Anim.Reduced`.
   - `Views.cs:755-758`: Toast notification meta text width `mw` is measured with `Math.Min(130, ...)`, but drawn with `TextRight`, causing overlap with `NotifTitle` when meta is long.
   - `Panel.cs:13-20` vs `Parts.cs:374-387`: Divergent empty state patterns with different spacing, module cards, and typography.
   - `Kit.cs`:
     - `KitButton`: No pressed state (`OnMouseDown` sets `KitInk.ByMouse`, but doesn't set a pressed visual state); focus ring uses `KitInk.Text` which has 1:1 contrast against primary button fill `KitInk.Text`.
     - `KitSwitch`: No hover state; fixed 75ms lerp instead of spring.
     - `KitSlider`: Thumb is always `KitInk.Text` even when `Enabled == false`.
     - `KitRow`: No hover feedback; instantiates fonts on every paint call.
   - `Tour.cs:239, 285-294`: Shows progress text (`"1 dari 9"`) and dot indicators simultaneously in the header area.
   - `ColorPicker.cs`: Loupe dialog hardcodes `BackColor = Color.FromArgb(18, 18, 18)` and `10f GraphicsUnit.Point`.
   - `Mini.cs`: Minimal target sizes (`MiniW = 56, MiniH = 6`, tab dots `3.2px`, `TabH = 28`).
   - `Prefs.cs:963`: Mixed Indonesian and English terminology ("Liquid", "Frost", "Hitam").

---

## 2. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Theme & Tokens | `Tone` System | Dual monochrome token definitions (`Base` and `Flip` swapping on theme mode) providing `Bg`, `Text`, `Sub`, `Faint`, `Fill`, `FillHover`, `Line`, `Quaternary`, `FillPressed`, `Highlight`, `Lip`, `Accent`, `OnAccent`, `Progress`, `Positive`, `Negative`. | Theme mode boolean (`light`), custom pack overrides | Dynamic `Tone` object with calculated RGB/alpha values | Missing hex keys default to fallback defaults | `src/Ink.cs:11-85` |
| 2 | Theme & Tokens | `Tone.OnGlass()` | Boosts secondary text (`Sub`) alpha channel to minimum 189 (74%) to maintain `>=4.5:1` contrast over bright wallpapers. | `Sub.A` | Cloned `Tone` with modified `Sub` | Alpha clamped between 189 and 255 | `src/Ink.cs:28-33` |
| 3 | Theme & Tokens | `Ink.Apply` & `OnAccent` Selection | Selects theme palette and calculates `OnAccent` ink by comparing WCAG contrast against dark (`#0A0A0A`) vs light (`#FAFAFA`) ink. | `bool light`, `Color? accent` | Updated `Ink.Base`, `Ink.Flip` | Falls back to monochrome text/bg if accent null | `src/Ink.cs:141-160` |
| 4 | Theme & Tokens | Squircle Geometry (`AddRound`) | Renders iOS-style squircles using figma-squircle curvature math with smoothing parameter 0.6. | `RectangleF r`, `float radius`, `GraphicsPath` | Mutated `GraphicsPath` with 4 smooth squircle corners | Falls back to standard rectangle if radius < 0.5 | `src/Ink.cs:404-452` |
| 5 | Theme & Tokens | Edge Notches (`Notch`, `SideNotch`) | Shapes continuous top and side notches for island docking with flared shoulders. | `RectangleF r`, `float radius`, `float shoulder`, `bool right` | `GraphicsPath` containing flared notch | Clamps shoulder to `r.Height / 3` | `src/Ink.cs:357-388` |
| 6 | Typography | Type Scale Hierarchy | 7 standardized type scale roles: `Hero` (40px Display), `Title1` (22px Display), `Title2` (17px Semi), `Headline` (14.5px Semi), `Body` (13.5px Text), `Callout` (12.5px Text), `Caption` (11px Small). | Role property getter | Cached `System.Drawing.Font` instance | Falls back to `SystemFonts.MessageBoxFont` if family missing | `src/Ink.cs:230-249` |
| 7 | Typography | Font Family Fallback Chain | Dynamically resolves available installed families from `Segoe UI Variable Display/Text/Small`, `Cascadia Mono`, `Segoe Fluent Icons`, to `Segoe UI`. | `InstalledFontCollection` | Array of 7 resolved family names | Fallback to `Segoe UI` or system messagebox family | `src/Ink.cs:202-220` |
| 8 | Typography | Optical Glyph Centering (`IconNudge`, `CapShift`) | Measures exact vector bounding box of glyph or capital 'H' and offsets drawing box to center optical ink rather than font em box. | `char glyph`, `float px`, `Font f` | `PointF nudge`, `float capShift` | Returns `PointF.Empty` / default lift on measure exception | `src/Ink.cs:265-326` |
| 9 | Vector Graphics | Vector Symbols (`Sym`, `SymbolPath`) | Generates resolution-independent vector paths for media controls and UI glyphs: `Play`, `Pause`, `Next`, `Prev`, `Stop`, `Check`, `Plus`, `Minus`, `Xmark`, `ChevronDown`, `ChevronUp`, `ChevronRight`. | `Sym kind`, `float size` | Cached `GraphicsPath` and stroke width | Clamped size cache (max 256 paths) | `src/Ink.cs:454-558` |
| 10 | Motion | Spring Dynamics (`Springs`) | Physics-based spring animations with 4 standard presets: `Snappy` (0.26s / 0.86d), `Smooth` (0.42s / 1.0d), `Bouncy` (0.42s / 0.75d), `Interactive` (0.16s / 0.86d). | `Spring s`, `response`, `damping` | Computed `s.K` (stiffness) and `s.D` (damping) | Clamps response to minimum 0.05s | `src/Ink.cs:659-692` |
| 11 | Motion | Reduced Motion (`Anim.Reduced`) | Universal guard checking user accessibility preference to eliminate springs, transitions, eye animations, and long blurs. | Global flag | Boolean gate in 59 call sites | Reverts to step change or linear cubic clamp | `src/Base.cs:230-260` |
| 12 | Color Science | Album Cover & Content Tone Extraction | Extracts dominant saturated mid-luminance hue from album art, converts to monochrome grayscale, and adjusts hue for readable contrast. | `Image src`, `int size` | Grayscale `Bitmap` with attached `Color` Tag, or readable tone | Returns `Color.Empty` if image has low saturation/grey | `src/Ink.cs:560-656` |
| 13 | Color Science | WCAG Contrast Engine (`Colors.Contrast`) | Computes relative luminance and contrast ratio according to WCAG 2.1 formula. | `Color a`, `Color b` | Double ratio `(L1 + 0.05) / (L2 + 0.05)` (range 1.0 to 21.0) | Clamps channels 0 to 255 | `src/Colors.cs:103-114` |
| 14 | Color Science | Palette Derivation (`Colors.DerivePalette`) | Generates a 19-key theme palette (`bg`, `text`, `sub`, `faint`, `fill`, `line`, `accent`, `card.*`) from 3 user picks (`bg`, `text`, `accent`). | `Color bg`, `Color text`, `Color accent` | `Dictionary<string, string>` hex palette | Loop iterates up to 14 times for card accent contrast | `src/Colors.cs:69-95` |
| 15 | Material | Liquid Glass (`LiquidPass`) | Captures screen backdrop, performs dual box blurs, saturation boost, and applies vignette with per-pixel adaptive luminance contrast guard. | `Bitmap tiny`, `byte[] raw`, `Color bg`, `bool light` | Processed 32bpp bitmap buffer | Vignette falls off to floor alpha | `src/Glass.cs:382-427` |
| 16 | Material | Frost Glass (`FrostJob`) | Downsamples screen backdrop by factor of 5 (`FrostDiv`), blurs, and overlays uniform tint brush with `BaseTint = 0.42`. | Screen capture rect | Cached `Plate` bitmap | Falls back to solid fill if capture fails | `src/Glass.cs:315-345` |
| 17 | Material | Window Frame & Caption Theming | Interops with DWM via `DwmSetWindowAttribute` to set dark mode window frame, caption color, and border color. | `IntPtr hwnd`, `bool dark` | Native DWM window properties | Fails silently on unsupported Windows builds (<Win10 1809) | `src/Native.cs:133-155` |
| 18 | Theme Sync | Windows System Theme Listener | Monitors `Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` and handles `WM_SETTINGCHANGE` / `"ImmersiveColorSet"` broadcast. | Registry key `AppsUseLightTheme` | Triggers `ApplyThemeMode` on change | Catches registry access exceptions | `src/WinTheme.cs:1-62` |
| 19 | Controls | Custom WinForms Toolkit (`Kit.*`) | Custom owner-drawn controls: `KitWindow`, `KitButton`, `KitSwitch`, `KitSlider`, `KitSegmented`, `KitText`, `KitRow`, `KitGroup`. | WinForms paint events | Rendered UI matching Island design language | Degrades focus cues when input is from mouse | `src/Kit.cs:1-785` |
| 20 | Island | Two-Tone Keyboard Focus Ring | Renders 3px outer ring contrasting with surface, plus 1.2px inner ring contrasting with control fill during Ctrl+Alt+I keyboard navigation. | `HitTarget`, `RectangleF r`, active `Tone` | Double squircle outline | Only renders when `keyboardMode && focusId != null` | `src/Keyboard.cs:152-173` |
| 21 | Island | Dynamic Island Morphology | Smoothly transitions dimensions and corner radii between `Idle`, `Media`, `Lyric`, `Track`, `Agent`, `Approve`, `Done`, `Notif`, `Volume`, `Mini`, `Panel`. | Target `View`, state springs | Interpolated size, position, and radius | Clamps to screen work area bounds | `src/Views.cs:10-90` |
| 22 | Island | Rolling Odometer Typography (`Roller`) | Smoothly animates changing digits vertically using clipped ease transitions for timers and counters. | New numeric string, `DateTime now` | Rendered scrolling glyphs | Reverts to simple text when `Anim.Reduced` is true | `src/Ink.cs:999-1064` |
| 23 | Dock | Edge Dock Bar & Sheen Rendering | Auto-hiding shelf on screen edge with hover sheen, rim light, nine-slice elevation shadow, and translucent material. | Cursor position, dock items | Layered layered window update (`UpdateLayeredWindow`) | Sensor strip kept at 2px height when bar is hidden | `src/DockPaint.cs:30-100` |
| 24 | Dock | Notification Badging | Displays badge count on dock app tiles using rounded rectangle and badge color. | `int count`, `RectangleF tile` | Rendered badge pill with white text | Truncates numbers >99 to `"99+"` | `src/DockPaint.cs:640-670` |
| 25 | Mini | Edge Sliver Indicator (`Mini`) | Displays ultra-compact collapsed status sliver on screen edge with optional eye gaze or clock. | Edge position, busy state | 6px or 14px sliver on edge | Disables click-through when hovered or expanded | `src/Mini.cs:10-100` |
| 26 | Dialogs | Loupe Color Picker (`ColorPicker`) | Full-screen interactive magnifier tool displaying zoomed pixels, center reticle, and hex code. | Mouse coordinate, screen pixels | Magnified loupe form with color feedback | Excluded from display capture via `WdaExclude` | `src/ColorPicker.cs:130-200` |
| 27 | Onboarding | Interactive Step Tour (`Tour`) | 9-step guided walkthrough with focused spotlight overlay, action detection, and dual progress tracking. | Tour step array | Modeless floating card next to island | Dismissable with Esc or Tutup button | `src/Tour.cs:220-298` |

---

## 3. Edge Cases

| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | Frost Glass Contrast | Dark theme (`#000000`) over 100% white wallpaper (`#FFFFFF`) | Frost applies 42% black tint -> background becomes `#949494`. Primary white text contrast drops to `3.0:1` (FAILS WCAG AA 4.5:1); secondary text drops to `2.72:1`, tertiary drops to `1.86:1`. |
| 2 | Frost Glass Contrast | Light theme (`#F5F5F5`) over 100% black wallpaper (`#000000`) | Background becomes `#686868`. Primary dark text (`#0C0C0E`) drops to `3.46:1` (FAILS WCAG AA); secondary drops to `2.36:1`. |
| 3 | Liquid Glass Color Space | Light theme over pitch black wallpaper | Surface luminance resolves to 0.38 instead of `>=0.62` due to sRGB byte blending from linear formula; secondary text contrast reaches only `3.81:1` (FAILS WCAG AA). |
| 4 | Liquid Glass Translucency | Dark theme over pure white wallpaper | Adaptive guard hits `aMax = 0.9`, creating a nearly solid `#191919` surface and completely losing translucent liquid glass look. |
| 5 | Island Secondary Text | Translucent glass enabled on Island | Island sets `p.T = Ink.Base` (never calling `OnGlass()`), so Sub text remains at alpha 158 (62%) rather than bumping to 189 (74%), rendering secondary text faded on complex wallpapers. |
| 6 | Accent Preset Graphical Elements | Any of the 7 accent presets drawn as progress track or icon on Paper background (`#F5F5F5`) | All 7 presets fail WCAG 3:1 non-text contrast: Biru `2.94:1`, Hijau `1.72:1`, Kuning `1.32:1`, Oranye `1.87:1`, Merah muda `2.46:1`, Ungu `2.50:1`, Navy `2.95:1`. |
| 7 | Custom Color Palette | User chooses `bg = #222222` and `text = #333333` | `DerivePalette` accepts the input and generates a palette with contrast `1.26:1`; island becomes completely illegible with only a passive text warning in Settings. |
| 8 | Windows High Contrast | User activates Windows High Contrast Mode (`LeftAlt + LeftShift + PrintScreen`) | Application does not query `SystemInformation.HighContrast`; window continues rendering custom dark/light theme with low contrast translucent borders. |
| 9 | Windows Large Text Scaling | User configures text scaling in Windows Accessibility Settings (e.g. 150%) | All text sizes are defined in absolute device pixels (`Graphics.MeasureString` with px font); text remains small and does not scale. |
| 10 | Primary Button Focus | Keyboard focus navigates to a `KitButton` with `Primary = true` | `KitButton` draws focus ring using `new Pen(KitInk.Text, 1.6f)`. The button background is also `KitInk.Text`, producing zero contrast between the button edge and its focus ring. |
| 11 | Disabled Slider Thumb | `KitSlider` has `Enabled = false` | The slider track dims to `KitInk.Disabled`, but the thumb ellipse continues to render with `new SolidBrush(KitInk.Text)`, confusing users as to whether the control is disabled. |
| 12 | Reduced Motion with Active Approval | `Anim.Reduced = true` while approval dialog / permission prompt is pending | Approval halo continues to pulse continuously via `Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3)` in `Island.cs:1142`, violating reduced motion requirements. |
| 13 | Notification Burst Meta Text | Incoming notification with long app name and count (e.g. "5 pesan · Microsoft Visual Studio Code") | `mw` is clamped to 130px in measurement, but `meta` is drawn right-aligned in full, colliding and overlapping with the notification title. |
| 14 | Font Resolution on Clean Windows 10 Install | Windows 10 build prior to Segoe UI Variable installation | `Ink.Init` resolves fallback to `Segoe UI`, but typos in `FDisplay` (`"Display Semib"`) and `FSmallSemi` (`"Small Semibol"`) prevent intermediate weights from resolving properly. |
| 15 | Color Picker on Light Theme | User opens color picker loupe while Light theme is active | Loupe form hardcodes `BackColor = Color.FromArgb(18, 18, 18)` and ignores `KitInk.Window`, presenting a mismatched dark window. |

---

## 4. Logic Chain

1. **Step 1: Audit of Requirements vs Reality**:
   - `ORIGINAL_REQUEST.md` requires eliminating ad-hoc visual values, enforcing centralized tokens in `Ink.cs`, and meeting WCAG AA contrast (4.5:1 normal text, 3:1 non-text/large text) across Light and Dark themes.
   - `01-visual.md` identified 24 distinct findings (VIS-01 through VIS-24).
   - `next-visual.md` noted quick-win fixes for `Faint` and `OnAccent`, but recorded persisting gaps: 103 `Color.FromArgb` usages, 26 hex literals, 19 typography sizes, and 0 `Ink.Sp*` usages.

2. **Step 2: Verification of Codebase Token Infrastructure**:
   - `Tone.Dark()` and `Tone.Paper()` now have base tokens that pass WCAG AA on solid backgrounds (`Faint` at alpha 148 achieves `6.42:1` on dark and `4.67:1` on paper).
   - However, the token system is **not adopted** across major functional modules:
     - Spacing tokens (`Ink.Sp4` to `Ink.Sp32`) have 0 callers; layout code uses ad-hoc pixel offsets (`+ 12`, `+ 16`, `+ 22`, `+ 30`).
     - Shell radius token (`Ink.RadiusShell = 32`) has 0 callers; `Views.cs` hardcodes 30, 26, and 28.
     - Type scale tokens (`Hero` to `Caption`) are bypassed in 371 call sites in favor of manual pixel sizes (`10f`, `10.5f`, `11.5f`, `12f`, `13.5f`, `14.5f`, etc.).
     - 34 instances of `new Font(...)` are constructed outside `Ink.cs`, bypassing font caching and creating garbage on paint cycles.

3. **Step 3: Verification of Translucency & Contrast Failures**:
   - `Frost`: `Glass.cs:327` applies a raw 42% tint with no background luminance adaptation. Mathematical proof: on white wallpaper, surface luminance drops to 0.30, forcing white text to `3.0:1` (fails WCAG AA 4.5:1).
   - `Liquid`: `Glass.cs:419-421` applies linear luminance calculations into non-linear sRGB bytes. Mathematical proof: on dark wallpaper with light theme, surface luminance is 0.38 (target `>=0.62`), causing secondary text to drop to `3.81:1`.
   - `OnGlass()`: `Ink.cs:28` raises Sub alpha to 74% specifically for wallpaper contrast, but `Island.cs` never calls it.

4. **Step 4: Verification of UI Component States and Guidelines**:
   - In `Kit.cs`, `KitButton` lacks pressed state feedback and has an invisible focus ring on primary buttons (text color on text color).
   - In `Kit.cs`, `KitSlider` disabled state fails to dim the thumb.
   - In `Island.cs`, the halo glow breath animation ignores `Anim.Reduced`.
   - In `DockPaint.cs`, hardcoded colors exist for sensors, rim lighting, sheen, and badges (`BadgeRed`, `BadgeRedSoft`).
   - In `Views.cs`, toast notification meta text collides with title text when strings exceed 130px.

---

## 5. Caveats

1. **Hardware / Display Capture**:
   - The test environment does not have a live secondary monitor or live wallpaper rotation service active; wallpaper luminance tests were conducted mathematically using exact colorimetric and sRGB transfer function formulas against the implemented algorithm in `Glass.cs`.
2. **Dynamic DPI Scaling**:
   - High DPI scaling logic in `Kit.cs:631-705` scales fonts via `float Ui` factor; while `Ink.*(px)` caches fonts by integer key `px * 10`, `new Font(...)` in `Kit.cs` creates unmanaged GDI+ font handles directly.
3. **No Code Modification**:
   - Per role constraints (Visual Spec Miner), no source files were altered during this survey.

---

## 6. Conclusion

The visual foundation and design token architecture of Tepi (`Tone`, `Ink`, squircle math, spring dynamics, and vector rendering) are robust and high quality, but **token governance is fragmented**:
1. **Ad-hoc Literals**: 62 hardcoded `Color.FromArgb` calls and 26 literal hex strings exist outside `Ink.cs`, notably in `DockPaint.cs`, `Kulia.cs`, `ColorPicker.cs`, and `DockCard.cs`.
2. **Typography Drift**: The 7-role type scale is bypassed in 371 call sites with 19 distinct px sizes, and 34 `new Font(...)` calls bypass font caching. Font family names in `Ink.cs` contain typos.
3. **Unused Design Tokens**: `Ink.Sp*` (spacing) and `Ink.RadiusShell` have 0 usages in the entire codebase.
4. **Contrast Vulnerabilities**:
   - `Frost` material lacks any contrast guard and drops to `3.0:1` on light wallpapers.
   - `Liquid` material misapplies linear calculations to sRGB bytes, dropping to `3.81:1` in light mode on dark wallpapers.
   - `OnGlass()` is implemented for Dock but omitted from Island.
   - All 7 accent presets fail WCAG 3:1 non-text contrast when drawn on Paper background without stroke/outline.
   - Custom palette creation allows unreadable combinations (`1.26:1`).
5. **Component Defects**: Keyboard focus ring invisible on primary buttons, disabled slider thumb not dimmed, approval halo ignoring reduced motion, toast title/meta collision, and dual empty state implementations.

Resolution of these issues provides a direct path to full production readiness without architectural changes.

---

## 7. Verification Method

### Automated Independent Verification

1. **Compile & Run Clean Build**:
   ```cmd
   d:\PROJECT\Other\tepi\build.cmd
   ```
   *Expected Result*: Exits with code 0 and produces `d:\PROJECT\Other\tepi\Tepi.exe`.

2. **Run Token & Contrast Audit Script**:
   Execute the survey audit script created in this state folder:
   ```cmd
   python d:\PROJECT\Other\tepi\.agents\teamwork\spec_miner_survey_1\audit.py
   python d:\PROJECT\Other\tepi\.agents\teamwork\spec_miner_survey_1\dump_details.py
   ```
   *Expected Output*:
   - Validates WCAG contrast for dark, paper, and on-glass tokens.
   - Confirms 62 `Color.FromArgb` instances outside `Ink.cs`/`Colors.cs`.
   - Confirms 26 literal `#hex` instances.
   - Confirms 34 `new Font(...)` instances outside `Ink.cs`.
   - Confirms 19 distinct px sizes passed to `Ink.*(px)`.
   - Confirms 0 usages of `Ink.Sp*` and `Ink.RadiusShell`.

3. **Grep Token Invalidation Checks**:
   - Check `Ink.Sp*` usages:
     ```powershell
     powershell -Command "Get-ChildItem -Path 'd:\PROJECT\Other\tepi\src\*.cs' | Select-String -Pattern 'Ink\.Sp\d+'"
     ```
     *(Outputs 0 matches outside Ink.cs declaration)*
   - Check `RadiusShell` usages:
     ```powershell
     powershell -Command "Get-ChildItem -Path 'd:\PROJECT\Other\tepi\src\*.cs' | Select-String -Pattern 'RadiusShell'"
     ```
     *(Outputs 0 matches outside Ink.cs declaration)*
   - Check `OnGlass` usages:
     ```powershell
     powershell -Command "Get-ChildItem -Path 'd:\PROJECT\Other\tepi\src\*.cs' | Select-String -Pattern 'OnGlass'"
     ```
     *(Outputs only DockCard.cs, DockPaint.cs, DockSheet.cs, Ink.cs — 0 in Island.cs)*
