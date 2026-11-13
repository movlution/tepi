# Milestone 1: Technical Synthesis & Implementation Specification

## Consensus & Findings Summary
All three Explorers have delivered high-precision handoffs that provide exact mathematical formulas, system architecture analyses, and tested code patterns for Milestone 1.

### 1. Typography System & GDI+ Font Resolution (`src/Ink.cs`)
- **Root Cause**: GDI Win32 subsystem `LOGFONT` has `LF_FACESIZE = 32`. `InstalledFontCollection` returns names truncated to 31 characters:
  - `"Segoe UI Variable Display Semibold"` (34 chars) -> enumerated as `"Segoe UI Variable Display Semib"` (31 chars).
  - `"Segoe UI Variable Small Semibold"` (32 chars) -> enumerated as `"Segoe UI Variable Small Semibol"` (31 chars).
- **Resolution Strategy**:
  - `Ink.Init()` candidate lists must include BOTH the canonical 34/32-char names AND the 31-char truncated names, followed by `Segoe UI Semibold` and `Segoe UI`.
  - Harden `Ink.Pick()` to check `if (n.Length > 31 && have.Contains(n.Substring(0, 31))) return n.Substring(0, 31);`.
  - Add static constructor `static Ink() { Init(); }` to ensure font dictionary is initialized before any static field (such as `Menus.MenuFont`) accesses `Ink.MenuFamily`.

### 2. Light Mode Accent Preset Calibration (`src/Ink.cs`, `src/Prefs.cs`)
- **Root Cause**: The 7 preset accents were chosen with high luminance for dark backgrounds, causing all of them to fail WCAG AA non-text (< 3.5:1) and text (< 4.5:1) against Paper `#F5F5F5`.
- **Calibrated Light Mode Presets**:
  - Biru: `#1668E8` (CR 4.61:1 vs Paper `#F5F5F5`, 4.81:1 on pill)
  - Hijau: `#107C41` (CR 4.84:1 vs Paper `#F5F5F5`, 5.05:1 on pill)
  - Kuning: `#855E00` (CR 5.35:1 vs Paper `#F5F5F5`, 5.59:1 on pill)
  - Oranye: `#A84B00` (CR 5.25:1 vs Paper `#F5F5F5`, 5.48:1 on pill)
  - Merah muda: `#C2185B` (CR 5.39:1 vs Paper `#F5F5F5`, 5.63:1 on pill)
  - Ungu: `#6C3CE0` (CR 5.73:1 vs Paper `#F5F5F5`, 5.99:1 on pill)
  - Navy: `#4D5F9E` (CR 5.59:1 vs Paper `#F5F5F5`, 5.84:1 on pill)
- **Integration**:
  - In `Ink.Apply(bool light)`: map presets through calibrated values in light mode, with defensive guard `Island.Contrast(Base.Accent, Base.Bg) >= 3.5`.
  - Synchronize `Prefs.cs` so swatches and theme switches reflect the calibrated colors.

### 3. Glass Contrast Guards (`src/Glass.cs`, `src/DockFrost.cs`, `src/Island.cs`)
- **Frost Material**:
  - Introduce `ComputeFrostTint(byte[] sig, int len, Color bg, bool light)` in `Glass.cs`.
  - Dynamically scale scrim opacity $\alpha \in [0.42, 0.67]$ in dark mode ($L_{surface} \le 0.0908$, text 6.84:1, subtext 4.64:1) and up to $0.84$ in light mode ($L_{surface} \ge 0.6172$, text 12.43:1, subtext 4.66:1).
  - Apply in `Glass.cs:326-328`.
- **Liquid Material**:
  - Eliminate Jensen's inequality non-linear byte lerp.
  - Implement 4096-entry `SrgbLut` and `ToSrgb(float lin)`.
  - Convert backdrop to linear light (`Linear[(int)channel]`), blend in linear light, then convert to sRGB via `ToSrgb(...)`.
  - Apply in both `src/Glass.cs:405-424` and `src/DockFrost.cs:149-162`.
- **Island Integration**:
  - Pass `tone.OnGlass()` in `src/Island.cs:846, 1244` when `GlassOn` is active.

### 4. Custom Palette Contrast Floor (`src/Colors.cs`)
- Add `public static Color EnforceContrast(Color c, Color bg, double minContrast)` to `Island` in `src/Colors.cs`.
- Update `DerivePalette(Color bg, Color text, Color accent)` to enforce the contrast hierarchy:
  - `text` $\ge 7.0:1$ (fallback 4.5:1)
  - `sub` $\ge 4.5:1$
  - `faint` $\ge 3.0:1$
  - `accent` $\ge 3.5:1$
  - `onAccent` $\ge 4.5:1$
  - Apply symmetric enforcement to `card.*` palette entries.

### 5. Build Verification
- Execute `build.cmd` to verify clean compilation with zero warnings/errors.
