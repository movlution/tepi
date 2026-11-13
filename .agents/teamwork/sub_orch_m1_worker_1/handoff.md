# Handoff Report: Milestone 1 Implementation (Design Token Core, Glass Contrast & Color Science)

**Worker**: Worker 1 (sub_orch_m1_worker_1)  
**Parent Conversation ID**: `2e923bc6-0cc8-4584-9a2a-480dec472f3b`  
**Milestone**: Milestone 1 - Design Token Core, Glass Contrast & Color Science  
**Date**: 2026-11-12T16:05:00Z  

---

## 1. Observation

### Exact File Paths & Lines Modified
1. **`src/Ink.cs`**:
   - Lines 92–96: Added static constructor `static Ink() { Init(); }` to ensure font dictionary is initialized before static fields in other classes (such as `Menus.MenuFont`) access `Ink.MenuFamily`.
   - Lines 107–156: Added `DarkAccents` and `LightAccents` arrays with calibrated light presets. Added `SameRgb`, `GetLightAccent`, and `GetDarkAccent` mapping functions.
   - Lines 205–210: Updated `Ink.Apply(bool light)` to map presets to their calibrated light variants in light mode, and applied the contrast guard `if (light && Island.Contrast(c, Base.Bg) < 3.5) c = Island.EnforceContrast(c, Base.Bg, 3.5);`.
   - Lines 264, 270: Updated candidate lists for `FDisplay` and `FSmallSemi` in `Ink.Init()` to include both canonical 34/32-character names and GDI Win32 `LF_FACESIZE = 32` 31-character truncated names (`"Segoe UI Variable Display Semibold"`, `"Segoe UI Variable Display Semib"`, `"Segoe UI Semibold"`, `"Segoe UI"` and `"Segoe UI Variable Small Semibold"`, `"Segoe UI Variable Small Semibol"`, `"Segoe UI Semibold"`, `"Segoe UI"`).
   - Lines 275–280: Hardened `Pick()` to automatically check `if (n.Length > 31 && have.Contains(n.Substring(0, 31))) return n.Substring(0, 31);`.

2. **`src/Colors.cs`**:
   - Lines 68–80: Added `public static Color EnforceContrast(Color c, Color bg, double minContrast)` implementing iterative convergence towards polarity target (`white` or `dark = Color.FromArgb(255, 0, 0, 0)`).
   - Lines 83–135: Refactored `DerivePalette(Color bg, Color text, Color accent)` to enforce WCAG contrast floors across the token hierarchy:
     - Primary text $\ge 7.0:1$ (fallback $\ge 4.5:1$).
     - Secondary `sub` $\ge 4.5:1$.
     - Tertiary `faint` $\ge 3.0:1$.
     - Accent $\ge 3.5:1$.
     - `onAccent` $\ge 4.5:1$ against `accent`.
     - Symmetric card palette floors for `card.text`, `card.sub`, `card.faint`, `card.accent`, and `card.onAccent`.

3. **`src/Glass.cs`**:
   - Lines 326–330: Replaced hardcoded `BaseTint = 0.42f` in Frost plate rendering with dynamic adaptive tint:
     `float frostTint = ComputeFrostTint(sig, len, job.Bg, job.Light);`
     `using (var tintBrush = new SolidBrush(Ink.A(job.Bg, frostTint))) fg.FillRectangle(tintBrush, 0, 0, w, h);`
   - Lines 385–404: Added 4096-entry `SrgbLut`, `BuildSrgbLut()`, and `public static byte ToSrgb(float lin)`.
   - Lines 406–436: Implemented `ComputeFrostTint(byte[] sig, int len, Color bg, bool light)` sampling wallpaper backdrop luminance with a 60% worst-case peak bias, returning alpha $\in [0.42, 0.67]$ in dark mode and $\in [0.42, 0.84]$ in light mode.
   - Lines 456–483: Converted `LiquidPass` to perform optical channel blending in linear light space via `Linear[]`, then encode to sRGB bytes via `ToSrgb(...)`. Added clamping to avoid index overflow on saturated colors.

4. **`src/DockFrost.cs`**:
   - Lines 145–168: Converted `DockFrost.Liquid` to perform channel blending in linear light space using `Linear[]` and encode output bytes using `ToSrgb(...)`.

5. **`src/Island.cs`**:
   - Line 846: Passed `GlassOn ? Ink.Base.OnGlass() : Ink.Base` into `DrawContent`.
   - Lines 1242, 1251: Inside `DrawContent`, ensured `if (GlassOn && tone != null) tone = tone.OnGlass();` and preserved snapshot invocation `if (tone == Ink.Base || (GlassOn && tone != null && tone.Bg == Ink.Base.Bg)) DrawSnapshot(now);`.

6. **`src/Prefs.cs`**:
   - Lines 186–192: Added `AccentsLight` array with calibrated light mode hexes.
   - Lines 932–934: Updated `SwatchPresets` to return `Ink.Light ? AccentsLight : Accents` for accent swatches.
   - Lines 1089–1092: Updated `accentPick` dropdown to resolve selection matching against both dark and light hexes and pass `activeAccents[i][1]`.

---

## 2. Logic Chain

1. **Typography Resolution**:
   - Win32 GDI `LOGFONT` has `LF_FACESIZE = 32`. `InstalledFontCollection` returns names truncated to 31 characters.
   - Candidate lists with both canonical names and 31-character truncated names, along with `Pick()` length truncation matching (`n.Substring(0, 31)`), ensure `Segoe UI Variable Display Semib` and `Segoe UI Variable Small Semibol` are selected on Windows 11 instead of silently falling back to `Segoe UI Semibold`.
   - Static constructor `static Ink() { Init(); }` guarantees that classes accessing `Ink.MenuFamily` at static load time receive valid font family strings instead of `null` (which previously forced `Microsoft Sans Serif`).

2. **Light Mode Accent Calibration**:
   - Uncalibrated accents (e.g., Kuning `#FFD24A`, Hijau `#3DD68C`, Oranye `#FF9F43`) previously dropped to 1.32:1–2.94:1 against Paper `#F5F5F5`.
   - The calibrated presets (Biru `#1668E8`, Hijau `#107C41`, Kuning `#855E00`, Oranye `#A84B00`, Merah muda `#C2185B`, Ungu `#6C3CE0`, Navy `#4D5F9E`) achieve $4.61:1$ to $5.73:1$ contrast against `#F5F5F5`.
   - OnAccent text achieves $4.81:1$ to $5.99:1$ contrast against the accent fill.
   - Mapping through `GetLightAccent` in `Ink.Apply(true)` and guarding with `Island.Contrast(c, Base.Bg) < 3.5` guarantees compliance even for custom colors.

3. **Adaptive Contrast Guard for Frost Material**:
   - Hardcoded `BaseTint = 0.42f` allowed 58% of wallpaper light to pass through. On pure white wallpapers (`#FFFFFF`) in Dark Mode, surface luminance rose to $L = 0.2961$, dropping white text contrast to 2.79:1.
   - `ComputeFrostTint` samples wallpaper luminance:
     - On white wallpaper in dark mode: increases tint alpha dynamically up to $0.67$, fixing surface luminance at $L \le 0.0908$. Primary white text contrast reaches $6.95:1 \ge 4.5:1$, and secondary text (`OnGlass()`) reaches $4.64:1 \ge 4.5:1$.
     - On black wallpaper in light mode: increases tint alpha dynamically up to $0.84$, fixing surface luminance at $L \ge 0.6172$. Primary dark text contrast reaches $12.42:1 \ge 4.5:1$, and secondary text reaches $4.66:1 \ge 4.5:1$.
     - On normal wallpapers, translucency is preserved at `BaseTint = 0.42f`.

4. **Linear Color Space Blending for Liquid Material**:
   - Non-linear sRGB byte blending systematically darkened the surface output due to Jensen's inequality ($L = 0.3813$ instead of target $L \ge 0.62$).
   - Blending in linear light space via `Linear[]` followed by OETF conversion via 4096-entry `ToSrgb` LUT restores exact linear optical superposition, maintaining target luminance $L \ge 0.62$ in light mode and $L \le 0.09$ in dark mode.

5. **Custom Palette Contrast Floor**:
   - `Island.EnforceContrast` iteratively pulls candidate colors towards polarity boundaries (`Color.White` or `Color.FromArgb(255, 0, 0, 0)`) with 15% step increments.
   - In `DerivePalette`, enforcing the contrast ladder prevents low-contrast user color combinations from generating unreadable palettes.

---

## 3. Caveats

1. **Windows 10 Font Fallback**:
   On Windows 10 (which does not ship with Segoe UI Variable), `Pick()` cleanly and correctly falls back to `Segoe UI Semibold` and `Segoe UI`. This is the intended OS compatibility behavior.
2. **Wallpaper Capture API**:
   On Windows 10 versions older than build 2004, `WDA_EXCLUDEFROMCAPTURE` is not supported by the OS. In such environments, screen sampling falls back to standard capture.
3. **M2 Scope Separation**:
   Ad-hoc hardcoded font names and colors inside modal dialogs (`ColorPicker.cs:190`, `TaskEditor.cs`, `WorkWindow.cs`) are assigned to Milestone 2 and remain untouched in Milestone 1.

---

## 4. Conclusion

All 5 core requirements for Milestone 1 are completely implemented, verified, and passing:
1. **Font Family Resolution**: Segoe UI Variable Display and Small resolve accurately on Windows 11 with GDI 31-char truncation support and static constructor protection.
2. **Light Accent Calibration**: All 7 presets guarantee WCAG AA text ($\ge 4.5:1$) and non-text ($\ge 3.5:1$) contrast against Paper background (`#F5F5F5`).
3. **Adaptive Frost Contrast Guard**: Scrim opacity adapts dynamically between 0.42 and 0.67 in dark mode and up to 0.84 in light mode, preventing text contrast degradation on extreme wallpapers.
4. **Liquid Linear Blending**: Optical channel blending operates in linear light space with 4096-entry fast LUT sRGB encoding.
5. **Custom Palette Contrast Floor**: `DerivePalette` guarantees full contrast hierarchy across primary text, subtext, faint, accent, and card surfaces.
6. **Build Integrity**: Clean build verified via `build.cmd` producing `Tepi.exe`.

---

## 5. Verification Method

### 1. Build Verification
Run the standard build command:
```cmd
cmd /c build.cmd
```
Expected output:
```
Build OK: D:\PROJECT\Other\tepi\Tepi.exe
```

### 2. Automated Test Suites
Run the reflection-based verification scripts in the state folder:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .agents\teamwork\sub_orch_m1_worker_1\test_m1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .agents\teamwork\sub_orch_m1_worker_1\test_glass.ps1
```

**Verbatim test results recorded**:
- `test_m1.ps1`:
  - `MenuFamily`: Segoe UI Variable Text
  - `Hero`: Segoe UI Variable Display Semib
  - `Title1`: Segoe UI Variable Display Semib
  - `Headline`: Segoe UI Variable Text Semibold
  - `Caption`: Segoe UI Variable Small
  - Biru: Light=#1668E8 (CR=4.61:1, OnAccent=4.81:1) Dark=#4C8DFF (CR=6.56:1) -> Pass=True
  - Hijau: Light=#107C41 (CR=4.84:1, OnAccent=5.05:1) Dark=#3DD68C (CR=11.2:1) -> Pass=True
  - Kuning: Light=#855E00 (CR=5.35:1, OnAccent=5.59:1) Dark=#FFD24A (CR=14.57:1) -> Pass=True
  - Oranye: Light=#A84B00 (CR=5.25:1, OnAccent=5.48:1) Dark=#FF9F43 (CR=10.29:1) -> Pass=True
  - Merah muda: Light=#C2185B (CR=5.39:1, OnAccent=5.63:1) Dark=#FF6B9A (CR=7.82:1) -> Pass=True
  - Ungu: Light=#6C3CE0 (CR=5.73:1, OnAccent=5.99:1) Dark=#A78BFA (CR=7.72:1) -> Pass=True
  - Navy: Light=#4D5F9E (CR=5.59:1, OnAccent=5.84:1) Dark=#7F8DC6 (CR=6.53:1) -> Pass=True
  - Custom Palette Contrast Floors (Low Contrast Dark, White on White, Identical Gray): All checks Pass=True.
- `test_glass.ps1`:
  - `Linear -> ToSrgb roundtrip mismatches (>1 count): 0`
  - `Frost Tint on White Wall (Dark Mode): 0.67` -> Surface Byte: 84, Text Contrast: 6.95:1 (Required >= 4.5:1 -> True)
  - `Frost Tint on Black Wall (Light Mode): 0.84` -> Surface Byte: 206, Text Contrast: 12.42:1 (Required >= 4.5:1 -> True)
  - `Frost Tint on Black Wall (Dark Mode): 0.42` -> True
  - `Frost Tint on White Wall (Light Mode): 0.42` -> True

### 3. Invalidation Conditions
- If `Pick()` returns `"Segoe UI Semibold"` on Windows 11 for `FDisplay`, font resolution has failed.
- If switching to light mode with Kuning accent yields contrast < 4.5:1 against Paper (`#F5F5F5`), accent calibration has failed.
- If white text on Frost glass over pure white wallpaper drops below 4.5:1, the adaptive contrast guard has failed.
