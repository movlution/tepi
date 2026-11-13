## 2026-11-12T15:47:43Z
You are Worker 1 for Milestone 1 in project Tepi.
Your task is to implement Milestone 1: Design Token Core, Glass Contrast & Color Science.

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1_worker_1\
Path to ORIGINAL_REQUEST.md: d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md (You MUST read this first).
Path to PROJECT.md: d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md
Path to SCOPE.md: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1\SCOPE.md
Path to technical synthesis: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1\synthesis.md
Path to Explorer 1 handoff: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1_explorer_1\handoff.md
Path to Explorer 2 handoff: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1_explorer_2\handoff.md
Path to Explorer 3 handoff: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m1_explorer_3\handoff.md

Write ownership:
Primary files: `src/Ink.cs`, `src/Colors.cs`, `src/Glass.cs`, `src/WinTheme.cs`.
Coordinated files: `src/Prefs.cs`, `src/DockFrost.cs`, `src/Island.cs`.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Features to implement:
1. Font Family & Resolution in `src/Ink.cs`:
   - In `Ink.Init()`, update candidate lists for `FDisplay` and `FSmallSemi` to include both full names and 31-character truncated names ("Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI" and "Segoe UI Variable Small Semibold", "Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI").
   - Harden `Pick()` to automatically match 31-character truncated names (`if (n.Length > 31 && have.Contains(n.Substring(0, 31))) return n.Substring(0, 31);`).
   - Add static constructor `static Ink() { Init(); }` to prevent static fields in other classes from getting null font family names.
2. Light Theme Accent Calibration in `src/Ink.cs` & `src/Prefs.cs`:
   - Calibrate all 7 light theme presets so they guarantee WCAG AA >= 3.5:1 non-text and >= 4.5:1 text contrast against Paper background (#F5F5F5) while preserving hue identity:
     - Biru: #1668E8 (4.61:1)
     - Hijau: #107C41 (4.84:1)
     - Kuning: #855E00 (5.35:1)
     - Oranye: #A84B00 (5.25:1)
     - Merah muda: #C2185B (5.39:1)
     - Ungu: #6C3CE0 (5.73:1)
     - Navy: #4D5F9E (5.59:1)
   - In `Ink.Apply(bool light)`: map presets through calibrated values in light mode, and guard with `Island.Contrast(Base.Accent, Base.Bg) >= 3.5`.
   - Update `Prefs.cs` so swatches and theme switches reflect the calibrated colors.
3. Adaptive Contrast Guard for Frost Material in `src/Glass.cs`:
   - Implement `ComputeFrostTint(byte[] sig, int len, Color bg, bool light)` in `Glass.cs` to sample wallpaper background luminance.
   - Adjust tint alpha dynamically between 0.42 and 0.67 in dark mode (guaranteeing L_surface <= 0.0908, text >= 6.84:1, subtext >= 4.64:1 on white wallpapers) and up to 0.84 in light mode (guaranteeing L_surface >= 0.6172, text >= 12.43:1, subtext >= 4.66:1 on black wallpapers).
   - In `src/Island.cs:846, 1244`: pass `tone.OnGlass()` when `GlassOn` is active.
4. Correct Linear Color Space Blending for Liquid Material in `src/Glass.cs` and `src/DockFrost.cs`:
   - Implement 4096-entry `SrgbLut` and `ToSrgb(float lin)`.
   - In `LiquidPass`, convert backdrop RGB to linear light via `Linear[]`, blend in linear light, and encode to sRGB bytes via `ToSrgb(...)`.
5. Custom Palette Contrast Floor in `src/Colors.cs`:
   - Add `public static Color EnforceContrast(Color c, Color bg, double minContrast)` in `src/Colors.cs`.
   - In `DerivePalette(Color bg, Color text, Color accent)`: enforce contrast floors for text (>= 7.0:1 / 4.5:1), sub (>= 4.5:1), faint (>= 3.0:1), accent (>= 3.5:1), onAccent (>= 4.5:1), and symmetric card palette floors.
6. Build Verification:
   - Run `build.cmd` and verify clean build producing `Tepi.exe`.
