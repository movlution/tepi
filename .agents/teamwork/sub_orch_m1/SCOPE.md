# Scope: Milestone 1 - Design Token Core, Glass Contrast & Color Science

## Architecture
Milestone 1 establishes the foundational design tokens, WCAG contrast guarantees, and glass shader mathematics for Tepi:
- `src/Ink.cs`: Central design tokens (Tone, Type Scale, Fonts, Accents, Semantics).
- `src/Colors.cs`: Color mathematics, contrast ratios (WCAG 2.1), palette derivation and contrast floor enforcement.
- `src/Glass.cs`: Frosted & Liquid glass material shaders, background wallpaper sampling, adaptive luminance contrast guards, sRGB linear blending correction.
- `src/WinTheme.cs`: Windows system theme integration and accent polling.

## Feature Inventory for Milestone 1
| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 1 | Font Family Typo Corrections | Fix typos in `Ink.cs:207, 213` (`Display Semib` -> `Display Semibold`, `Small Semibol` -> `Small Semibold`) to ensure proper Segoe UI Variable fallback/weights. | PENDING |
| 2 | Light Mode Accent Preset Calibration | Calibrate all 7 preset accents in `Ink.cs` / `Prefs.cs` for light mode to satisfy WCAG AA >= 3.5:1 non-text contrast against Paper background (`#F5F5F5`). | PENDING |
| 3 | Frost Glass Adaptive Contrast Guard | Implement adaptive luminance contrast guard in `Glass.cs:326-327` for Frost material to ensure minimum contrast on bright wallpapers. | PENDING |
| 4 | Liquid Glass Color Space Blending | Correct sRGB byte blending from linear luminance calculation in `Glass.cs:419-421` for Liquid material. | PENDING |
| 5 | Custom Palette Contrast Floor | Enforce minimum contrast floors in `Colors.DerivePalette` to prevent unreadable palettes. | PENDING |
| 6 | Build Clean Verification | Verify clean compilation of the solution via `build.cmd` producing `Tepi.exe`. | PENDING |

## Write Ownership Boundaries
Exclusive write ownership for Milestone 1:
- `src/Ink.cs`
- `src/Colors.cs`
- `src/Glass.cs`
- `src/WinTheme.cs`
(Note: If `Prefs.cs` mirrors accent presets, verify how presets are synchronized or refactored so `Ink.cs` remains authoritative).

## Interface Contracts
- `Ink.Apply(bool light, Color? accent)` updates `Ink.Base` and `Ink.Flip`:
  - Any light mode accent preset guarantees >= 3.5:1 against `Ink.Paper.Bg` (`#F5F5F5`).
  - `Tone.OnGlass()` guarantees `Sub` alpha >= 189 (74%) to maintain >= 4.5:1 on bright wallpapers.
  - `Ink.Base.Negative` provides accessible semantic red (>= 4.5:1 on light/dark backgrounds).
- `Colors.DerivePalette(Color baseColor)` guarantees minimum contrast floor against standard surfaces.
- `Glass.cs` provides adaptive tinting/opacity adjustment for Frost/Liquid materials ensuring foreground legibility regardless of desktop wallpaper brightness.
