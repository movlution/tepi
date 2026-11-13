# Handoff Report — Explorer 2 (Specification Miner)
**Milestone 1**: Design Token Core, Glass Contrast & Color Science
**Sub-orchestrator Conversation ID**: `2e923bc6-0cc8-4584-9a2a-480dec472f3b`
**Date**: 2026-11-12T15:40:00Z

---

## 1. Observation

### 1.1 Direct Code Observations & Verbatim References
1. **Accent Preset Definition (`src/Prefs.cs:179-184`)**:
   ```csharp
   static readonly string[][] Accents =
   {
       new[] { "Monokrom", "" }, new[] { "Biru", "#4C8DFF" }, new[] { "Hijau", "#3DD68C" }, new[] { "Kuning", "#FFD24A" },
       new[] { "Oranye", "#FF9F43" }, new[] { "Merah muda", "#FF6B9A" }, new[] { "Ungu", "#A78BFA" }, new[] { "Navy", "#7F8DC6" },
       new[] { "Dari sampul album", AccentAlbum },
   };
   ```
   Single, static hex strings are defined for both Light and Dark themes.

2. **Accent Application in Theme Engine (`src/Ink.cs:141-157`)**:
   ```csharp
   public static void Apply(bool light)
   {
       Epoch++;
       Light = light;
       Base = light ? Tone.Paper() : Tone.Dark();
       Flip = light ? Tone.Dark() : Tone.Paper();
       foreach (var t in new[] { Base, Flip }) { t.Accent = t.Text; t.OnAccent = t.Bg; t.Progress = t.Sub; }
       if (accent.HasValue)
       {
           var c = accent.Value;
           Base.Accent = Base.Progress = c;
           var darkInk = Color.FromArgb(255, 10, 10, 10);
           var lightInk = Color.FromArgb(255, 250, 250, 250);
           Base.OnAccent = Island.Contrast(c, darkInk) >= Island.Contrast(c, lightInk) ? darkInk : lightInk;
       }
       Override(Base, "");
       Override(Flip, "card.");
   }
   ```
   When `Light` is true, `Base` is `Tone.Paper()` where `Bg = Color.FromArgb(255, 245, 245, 245)` (`#F5F5F5`). The `accent.Value` is assigned directly to `Base.Accent` and `Base.Progress` without adjusting for the light background.

3. **Accent Usage as Text and UI Components Across Codebase**:
   - As normal text:
     - `src/DockCal.cs:110`: `p.Text(shown.ToString("MMMM yyyy", ci), Ink.Small(12.5f), month == 0 ? p.T.Sub : p.T.Accent, ...)`
     - `src/DockQuick.cs:138`: `p.Text(sub, Ink.Small(11f), n.Connected ? p.T.Accent : p.T.Sub, ...)`
     - `src/DockWeather.cs:79`: `p.Text(rain, Ink.Small(12f), wet ? p.T.Accent : p.T.Sub, ...)`
     - `src/DockWeather.cs:126`: `p.Text(d.Pop + "%", Ink.Small(11f), p.T.Accent, ...)`
     - `src/Schedule.cs:121`: `p.Text(when, Ink.Small(11f), live ? p.T.Accent : p.T.Sub, ...)`
     - `src/Schedule.cs:197`: `p.Text(Fmt.Hm(c.Start), Ink.Semi(12.5f), live ? p.T.Accent : ink, ...)`
     - `src/Reminders.cs:792`: `p.TextCenter(Lang.T(PrayTimes.Names[i]), Ink.Caption, isNext ? p.T.Accent : ink, ...)`
     - `src/WorkWindow.cs:591`: `KitInk.Draw(g, t.Star ? "★" : "☆", fText, t.Star ? KitInk.Accent : KitInk.Faint, ...)`
   - As graphical components and fills:
     - `src/Tabs.cs:526`: `p.FillRound(pill, TabH / 2, p.T.Accent);` (active tab pill)
     - `src/Parts.cs:192`: `p.T.Accent` on primary action pills
     - `src/Kit.cs:201`: `KitInk.Accent` on switch track
     - `src/Control.cs:420`: slider track fill

4. **Palette Derivation (`src/Colors.cs:69-95`)**:
   ```csharp
   public static Dictionary<string, string> DerivePalette(Color bg, Color text, Color accent)
   {
       var white = Color.White;
       var d = new Dictionary<string, string>();
       d["bg"] = HexOf(bg);
       d["text"] = HexOf(text);
       d["accent"] = d["progress"] = HexOf(accent);
       d["sub"] = HexOf(MixRound(text, bg, 0.24));
       d["faint"] = HexOf(MixRound(text, bg, 0.44));
       var tint = MixRound(accent, white, 0.2);
       d["fill"] = AlphaHex(tint, 0x2E);
       d["fillHover"] = AlphaHex(tint, 0x4A);
       d["line"] = AlphaHex(tint, 0x3A);
       d["onAccent"] = HexOf(Contrast(bg, accent) >= Contrast(white, accent) ? bg : white);
       Color cbg = text, ca = accent;
       for (int i = 0; i < 14 && Contrast(ca, cbg) < 4.5; i++) ca = MixRound(ca, bg, 0.22);
       d["card.bg"] = HexOf(cbg);
       d["card.text"] = HexOf(bg);
       d["card.sub"] = HexOf(MixRound(bg, cbg, 0.3));
       d["card.faint"] = HexOf(MixRound(bg, cbg, 0.48));
       d["card.accent"] = HexOf(ca);
       d["card.fill"] = AlphaHex(ca, 0x1E);
       d["card.fillHover"] = AlphaHex(ca, 0x35);
       d["card.line"] = AlphaHex(ca, 0x30);
       d["card.onAccent"] = HexOf(Contrast(white, ca) >= 4.5 ? white : bg);
       return d;
   }
   ```
   There is zero contrast checking or clamping between user-selected `bg` and `text`, zero contrast checking between `accent` and `bg`, and no guarantee that `sub` or `faint` remain readable.

5. **Font Typo Observations (`src/Ink.cs:207, 213`)**:
   - Line 207: `"Segoe UI Variable Display Semib"` (missing `"old"` -> should be `"Segoe UI Variable Display Semibold"`).
   - Line 213: `"Segoe UI Variable Small Semibol"` (missing `"d"` -> should be `"Segoe UI Variable Small Semibold"`).

---

## 2. Features Discovered & Specification Mining Tables

### Features Discovered
| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Typography | Segoe UI Variable Font Name Resolution | Resolve installed variable font families without falling back to legacy Segoe UI | Font family strings in `Ink.cs:207, 213` | Correct `Font` handle loaded into `fonts` dictionary | Silent fallback to `Segoe UI Semibold` or default message box font due to typo string mismatch | Code inspection of `src/Ink.cs:203-220` |
| 2 | Color Tokens | Light Mode Accent Preset Calibration | Preset accent colors mapped to high-contrast variants when operating in Light theme (`#F5F5F5`) | Preset name or dark hex string (`#4C8DFF`, etc.) | Calibrated light-mode Color satisfying WCAG AA | Uncalibrated presets drop to as low as 1.32:1 on `#F5F5F5`, causing severe illegibility | Code inspection `Prefs.cs:179` & `Ink.cs:141` |
| 3 | Accessibility | Dual Role Accent Contrast (Text & Non-Text) | Accent color used simultaneously for UI fills (switches, tabs, progress) and normal text (dates, tags, weather) | `Ink.Base.Accent` / `Tone.Accent` | Element rendering in GDI+ | Normal text rendered below 4.5:1 violates WCAG 1.4.3; non-text below 3.0:1/3.5:1 violates WCAG 1.4.11 | Usage audit across `src/Dock*.cs`, `src/Schedule.cs` |
| 4 | Color Math | Custom Palette Contrast Floor Enforcement | Enforce minimum luminance distance between `bg`, `text`, `sub`, `faint`, and `accent` in `DerivePalette` | 3 user colors (`bg`, `text`, `accent`) | Fully compliant 19-key color dictionary (`d[key]`) | Custom colors like `#222222` and `#333333` yield 1.26:1 contrast; island becomes completely unreadable | Simulation of `src/Colors.cs:69-95` |
| 5 | Glass Shaders | Adaptive Frost Contrast Guard | Dynamically increase Frost background tint opacity on high-luminance wallpapers | Desktop wallpaper screenshot pixel data + `job.Bg` | Base plate bitmap with compensated alpha | White text drops to 2.79:1 on bright white desktop wallpapers without guard | Code inspection `src/Glass.cs:326-327` & `docs/analisis/01-visual.md` |
| 6 | Glass Shaders | sRGB Linear Blending Correction | Perform luminance-guided alpha blending in linear color space before converting to sRGB bytes | Linear luminance array `Linear[]` + sRGB wallpaper pixels | Output pixel buffer `outPx` | Inverted contrast on dark wallpapers in light mode (reaches only L=0.38 instead of >=0.62) | Code inspection `src/Glass.cs:413-421` |

### Edge Cases
| # | Feature | Input | Observed Behavior | Calibrated / Remediated Behavior |
|---|---------|-------|-------------------|----------------------------------|
| 1 | Accent Preset | Kuning (`#FFD24A`) on Paper (`#F5F5F5`) | Contrast ratio **1.32:1** (unreadable, fails AA non-text and text) | Remediated to `#855E00` (CR **5.35:1**, passes AA text and non-text) |
| 2 | Accent Preset | Hijau (`#3DD68C`) on Paper (`#F5F5F5`) | Contrast ratio **1.72:1** (fails AA non-text and text) | Remediated to `#107C41` (CR **4.84:1**, passes AA text and non-text) |
| 3 | Accent Preset | Biru (`#4C8DFF`) on Paper (`#F5F5F5`) | Contrast ratio **2.94:1** (fails AA non-text and text) | Remediated to `#1668E8` (CR **4.61:1**, passes AA text and non-text) |
| 4 | Accent Preset | Oranye (`#FF9F43`) on Paper (`#F5F5F5`) | Contrast ratio **1.87:1** (fails AA non-text and text) | Remediated to `#A84B00` (CR **5.25:1**, passes AA text and non-text) |
| 5 | Accent Preset | Merah muda (`#FF6B9A`) on Paper (`#F5F5F5`) | Contrast ratio **2.46:1** (fails AA non-text and text) | Remediated to `#C2185B` (CR **5.39:1**, passes AA text and non-text) |
| 6 | Accent Preset | Ungu (`#A78BFA`) on Paper (`#F5F5F5`) | Contrast ratio **2.50:1** (fails AA non-text and text) | Remediated to `#6C3CE0` (CR **5.73:1**, passes AA text and non-text) |
| 7 | Accent Preset | Navy (`#7F8DC6`) on Paper (`#F5F5F5`) | Contrast ratio **2.95:1** (fails AA non-text and text) | Remediated to `#4D5F9E` (CR **5.59:1**, passes AA text and non-text) |
| 8 | DerivePalette | Low-contrast dark user picks: `bg=#222222, text=#333333, accent=#444444` | Contrast drops to **1.26:1** (text), **1.19:1** (sub), **1.14:1** (faint), **1.23:1** (card accent) | Clamped by floor algorithm: text **7.50:1** (`#B2B2B2`), sub **4.92:1** (`#8F8F8F`), faint **3.36:1** (`#737373`), accent **3.60:1** (`#787878`) |
| 9 | DerivePalette | White on white user picks: `bg=#FFFFFF, text=#F5EFE6, accent=#FFD24A` | Contrast drops to **1.14:1** (text), **1.11:1** (sub), **1.44:1** (onAccent) | Clamped by floor algorithm: text **7.57:1** (`#555451`), sub **5.25:1** (`#6D6C6A`), accent **3.60:1** (`#A08431`), onAccent **5.51:1** |
| 10 | DerivePalette | Identical colors: `bg=#808080, text=#808080, accent=#808080` | Contrast drops to **1.00:1** (complete UI invisibility) | Directional polar shift pushes text to `#0F0F0F` (CR **4.85:1** against mid-gray) and card text to **7.60:1** |

---

## 3. Logic Chain & Mathematical Analysis

### 3.1 Relative Luminance and Contrast Ratio Mathematics
According to the W3C WCAG 2.1 specification (and implemented in `src/Colors.cs:104-114`):
1. For channel $c \in \{R, G, B\}$, normalized $s = c / 255.0$:
   $$s_{linear} = \begin{cases} \frac{s}{12.92} & s \le 0.03928 \\ \left(\frac{s + 0.055}{1.055}\right)^{2.4} & s > 0.03928 \end{cases}$$
2. Relative luminance $L$:
   $$L = 0.2126 \cdot R_{linear} + 0.7152 \cdot G_{linear} + 0.0722 \cdot B_{linear}$$
3. Contrast ratio between two colors with luminances $L_1$ and $L_2$ ($L_1 \ge L_2$):
   $$CR = \frac{L_1 + 0.05}{L_2 + 0.05}$$

For the Paper background (`#F5F5F5`):
$$R=245, G=245, B=245 \implies s = 0.960784 \implies s_{linear} = 0.913099 \implies L_{paper} = 0.913099$$
$$L_{paper} + 0.05 = 0.963099$$

To achieve a given contrast ratio $CR$ for any color darker than Paper:
$$CR = \frac{0.963099}{L_{color} + 0.05} \implies L_{color} \le \frac{0.963099}{CR} - 0.05$$
- For Non-Text ($CR \ge 3.5:1$): $L_{color} \le \frac{0.963099}{3.5} - 0.05 = \mathbf{0.22517}$
- For Normal Text ($CR \ge 4.5:1$): $L_{color} \le \frac{0.963099}{4.5} - 0.05 = \mathbf{0.16402}$

### 3.2 Evaluation of Existing 7 Presets
Comparing existing preset luminances to the Paper background threshold:

| Preset Name | Existing HEX | RGB | Luminance ($L$) | CR vs Paper (`#F5F5F5`) | WCAG Non-Text ($\ge 3.5:1$) | WCAG Text ($\ge 4.5:1$) | CR vs Dark (`#000000`) |
|---|---|---|---|---|---|---|---|
| **Biru** | `#4C8DFF` | (76, 141, 255) | 0.2781 | **2.94:1** | FAIL | FAIL | 6.56:1 |
| **Hijau** | `#3DD68C` | (61, 214, 140) | 0.5098 | **1.72:1** | FAIL | FAIL | 11.20:1 |
| **Kuning** | `#FFD24A` | (255, 210, 74) | 0.6785 | **1.32:1** | FAIL | FAIL | 14.57:1 |
| **Oranye** | `#FF9F43` | (255, 159, 67) | 0.4646 | **1.87:1** | FAIL | FAIL | 10.29:1 |
| **Merah muda**| `#FF6B9A` | (255, 107, 154) | 0.3411 | **2.46:1** | FAIL | FAIL | 7.82:1 |
| **Ungu** | `#A78BFA` | (167, 139, 250) | 0.3358 | **2.50:1** | FAIL | FAIL | 7.72:1 |
| **Navy** | `#7F8DC6` | (127, 141, 198) | 0.2764 | **2.95:1** | FAIL | FAIL | 6.53:1 |

**Core Finding**: All 7 presets fail both non-text and text contrast standards against `#F5F5F5`. This occurs because they were chosen solely with high luminance ($L \in [0.27, 0.68]$) to contrast against black (`#000000`).

---

## 4. Calibrated Light Mode Presets & Recommendations

### 4.1 Recommended Calibration (Dual Text & Non-Text WCAG AA Compliant)
Because `p.T.Accent` is used for both UI fills and inline text/symbols, calibrating to $CR \ge 4.5:1$ against `#F5F5F5` provides **100% universal compliance**:
1. Accents used for text satisfy $CR \ge 4.5:1$ (WCAG 1.4.3).
2. Accents used for graphical components satisfy $CR \ge 3.5:1$ (exceeding WCAG 1.4.11 $3.0:1$).
3. White text (`#FAFAFA`) placed on top of these accent fills (`OnAccent`) **simultaneously satisfies $CR \ge 4.5:1$** (between 4.81:1 and 5.99:1).

| Preset Name | Recommended Light HEX | RGB | Luminance ($L$) | CR vs Paper (`#F5F5F5`) | Text ($\ge 4.5:1$) | Non-Text ($\ge 3.5:1$) | OnAccent Ink & CR | Hue Angle ($H$) | Visual Color Appearance |
|---|---|---|---|---|---|---|---|---|---|
| **Biru** | `#1668E8` | (22, 104, 232) | 0.1587 | **4.61:1** | PASS | PASS | `#FAFAFA` (4.81:1) | 217° | Radiant Royal Blue |
| **Hijau** | `#107C41` | (16, 124, 65) | 0.1488 | **4.84:1** | PASS | PASS | `#FAFAFA` (5.05:1) | 147° | Vivid Emerald Green |
| **Kuning** | `#855E00` | (133, 94, 0) | 0.1300 | **5.35:1** | PASS | PASS | `#FAFAFA` (5.59:1) | 42° | Deep Golden Ochre / Warm Amber |
| **Oranye** | `#A84B00` | (168, 75, 0) | 0.1334 | **5.25:1** | PASS | PASS | `#FAFAFA` (5.48:1) | 27° | Deep Tangerine / Persimmon |
| **Merah muda**| `#C2185B` | (194, 24, 91) | 0.1287 | **5.39:1** | PASS | PASS | `#FAFAFA` (5.63:1) | 336° | Radiant Raspberry Rose |
| **Ungu** | `#6C3CE0` | (108, 60, 224) | 0.1182 | **5.73:1** | PASS | PASS | `#FAFAFA` (5.99:1) | 258° | Royal Violet |
| **Navy** | `#4D5F9E` | (77, 95, 158) | 0.1223 | **5.59:1** | PASS | PASS | `#FAFAFA` (5.84:1) | 227° | Deep Indigo Slate Navy |

*(Alternative Non-Text Only Tier: If the project team strictly requires lighter accents and moves all inline text to `Text`/`Sub`, the Tier 1 values are: Biru `#2F7AFF` (3.60:1), Hijau `#1F925B` (3.62:1), Kuning `#9E7400` (3.89:1), Oranye `#CB6300` (3.62:1), Merah muda `#D82A6A` (4.32:1), Ungu `#7C4DFF` (4.42:1), Navy `#5C6FB2` (4.41:1). However, the dual-compliant table above is strongly recommended to eliminate any risk of text contrast violations).*

---

## 5. Contrast Floor Enforcement Algorithm for `Colors.DerivePalette`

### 5.1 Root Cause of Custom Palette Degradation
1. **Unchecked Inputs**: `DerivePalette(Color bg, Color text, Color accent)` accepts arbitrary colors from user settings without checking if $Contrast(text, bg) \ge 4.5$.
2. **Downward Mixing**:
   - `sub = MixRound(text, bg, 0.24)` mixes 24% of `bg` into `text`.
   - `faint = MixRound(text, bg, 0.44)` mixes 44% of `bg` into `text`.
   Because mixing shifts the color towards `bg`, $CR(sub, bg)$ and $CR(faint, bg)$ are always strictly worse than $CR(text, bg)$. If $CR(text, bg)$ is weak (e.g. 1.26:1), `sub` and `faint` degrade to near-zero contrast.
3. **No Accent Guard**: Main accent has zero contrast enforcement against `bg`.
4. **Card Inversion Trap**: Card uses `text` as background and `bg` as text; when `bg` and `text` are close, the entire card UI collapses into illegibility.

### 5.2 Algorithmic Design for Worker Implementation
Add an iterative contrast enforcement function `EnforceContrast(Color c, Color bg, double minContrast)` to `src/Colors.cs`:

```csharp
// In src/Colors.cs:
public static Color EnforceContrast(Color c, Color bg, double minContrast)
{
    if (Contrast(c, bg) >= minContrast) return c;
    Color white = Color.FromArgb(255, 255, 255, 255);
    Color dark = Color.FromArgb(255, 12, 12, 14);
    
    // Choose polarity: if background is dark, brighten towards white; if light, darken towards dark ink
    Color target = Contrast(white, bg) >= Contrast(dark, bg) ? white : dark;
    
    Color res = c;
    for (int i = 0; i < 24 && Contrast(res, bg) < minContrast; i++)
        res = MixRound(res, target, 0.15);
        
    return res;
}
```

Update `DerivePalette` to enforce the complete contrast ladder:
```csharp
public static Dictionary<string, string> DerivePalette(Color bg, Color text, Color accent)
{
    var d = new Dictionary<string, string>();
    var white = Color.White;
    var dark = Color.FromArgb(255, 12, 12, 14);
    
    // 1. Enforce Primary Text Floor (min 7.0:1 so sub and faint have headroom, fallback >= 4.5)
    text = EnforceContrast(text, bg, 7.0);
    
    // 2. Derive and enforce Sub (>= 4.5:1) and Faint (>= 3.0:1)
    Color sub = EnforceContrast(MixRound(text, bg, 0.24), bg, 4.5);
    Color faint = EnforceContrast(MixRound(text, bg, 0.44), bg, 3.0);
    
    // 3. Enforce Accent Floor (>= 3.5:1 against bg)
    accent = EnforceContrast(accent, bg, 3.5);
    
    // 4. OnAccent contrast guarantee (>= 4.5:1)
    Color onAccent = Contrast(white, accent) >= Contrast(dark, accent) ? white : dark;
    onAccent = EnforceContrast(onAccent, accent, 4.5);
    
    d["bg"] = HexOf(bg);
    d["text"] = HexOf(text);
    d["sub"] = HexOf(sub);
    d["faint"] = HexOf(faint);
    d["accent"] = d["progress"] = HexOf(accent);
    d["onAccent"] = HexOf(onAccent);
    
    var tint = MixRound(accent, white, 0.2);
    d["fill"] = AlphaHex(tint, 0x2E);
    d["fillHover"] = AlphaHex(tint, 0x4A);
    d["line"] = AlphaHex(tint, 0x3A);
    
    // 5. Card Palette Derivation with Symmetric Floors
    Color cbg = text;
    Color ctext = EnforceContrast(bg, cbg, 7.0);
    Color csub = EnforceContrast(MixRound(ctext, cbg, 0.24), cbg, 4.5);
    Color cfaint = EnforceContrast(MixRound(ctext, cbg, 0.44), cbg, 3.0);
    Color ca = EnforceContrast(accent, cbg, 3.5);
    Color conAccent = Contrast(white, ca) >= Contrast(dark, ca) ? white : dark;
    conAccent = EnforceContrast(conAccent, ca, 4.5);
    
    d["card.bg"] = HexOf(cbg);
    d["card.text"] = HexOf(ctext);
    d["card.sub"] = HexOf(csub);
    d["card.faint"] = HexOf(cfaint);
    d["card.accent"] = HexOf(ca);
    d["card.fill"] = AlphaHex(ca, 0x1E);
    d["card.fillHover"] = AlphaHex(ca, 0x35);
    d["card.line"] = AlphaHex(ca, 0x30);
    d["card.onAccent"] = HexOf(conAccent);
    
    return d;
}
```

---

## 6. Concrete Implementation Strategy for Worker

### Step 1: Fix Font Typo (`src/Ink.cs:207, 213`)
- `src/Ink.cs:207`: replace `"Segoe UI Variable Display Semib"` with `"Segoe UI Variable Display Semibold"`.
- `src/Ink.cs:213`: replace `"Segoe UI Variable Small Semibol"` with `"Segoe UI Variable Small Semibold"`.

### Step 2: Implement Light Mode Accent Presets in `Ink.cs` & `Prefs.cs`
- In `src/Ink.cs`, introduce `GetLightAccent(Color darkAccent)` or an accent mapping dictionary mapping dark hexes `#4C8DFF`, `#3DD68C`, `#FFD24A`, `#FF9F43`, `#FF6B9A`, `#A78BFA`, `#7F8DC6` to their calibrated light mode counterparts `#1668E8`, `#107C41`, `#855E00`, `#A84B00`, `#C2185B`, `#6C3CE0`, `#4D5F9E`.
- In `Ink.Apply(bool light)`:
  When `light` is true and `accent.HasValue`, map `accent.Value` through `GetLightAccent(c)`.
  As a defensive guard: if `Island.Contrast(Base.Accent, Base.Bg) < 3.5`, execute `Island.EnforceContrast(Base.Accent, Base.Bg, 3.5)` to guarantee contrast even for arbitrary user-specified hexes.
- In `src/Prefs.cs`:
  Update `SwatchPresets("accent")` or `Accents` lookup so that when `ThemeLight()` is active, the swatches reflect the active theme's calibrated accents.

### Step 3: Implement Contrast Floor Enforcement in `src/Colors.cs`
- Add `public static Color EnforceContrast(Color c, Color bg, double minContrast)` to `Island` in `src/Colors.cs`.
- Refactor `public static Dictionary<string, string> DerivePalette` to apply the contrast ladder.

---

## 7. Caveats
- No caveats. The exact color mathematics and WCAG calculations have been verified with complete precision using automated Python and C# mathematical models.

---

## 8. Verification Method
1. **Compilation Check**:
   Run `build.cmd` from repository root:
   ```cmd
   build.cmd
   ```
   Must compile cleanly with zero errors producing `Tepi.exe`.
2. **Automated Contrast Ratio Verification Script**:
   Run `.agents/teamwork/sub_orch_m1_explorer_2/eval_candidates.py` and `test_enforcement.py` via `python` to re-verify contrast calculations against `#F5F5F5`.
3. **Interactive Verification**:
   - Open `Tepi.exe` -> Settings (`Ctrl+,`) -> Appearance (`Tampilan`).
   - Switch theme to `Terang` (Light).
   - Cycle through all 7 accents (`Kuning`, `Hijau`, `Biru`, `Oranye`, `Merah muda`, `Ungu`, `Navy`).
   - Verify that Yellow renders as a rich, readable Amber Gold (`#855E00`) with high contrast against the paper island and dock.
   - Test "Warna sendiri": pick `#222222` for background and `#333333` for text. Verify that the UI automatically enforces readable text and UI elements without washing out.
