# Project: Tepi UI/UX Production Visual & Design Token Overhaul

## Architecture
Tepi is a Windows Forms (.NET Framework 4.8) application featuring custom, owner-drawn GDI+ graphics rendered to per-pixel alpha layered windows (`UpdateLayeredWindow`) with tokenized painters (`Painter`, `Tone`, `Ink`).
- **Core Design Tokens & Materials**: `src/Ink.cs`, `src/Colors.cs`, `src/Glass.cs`, `src/WinTheme.cs`
- **Component Primitives & Dialogs**: `src/Kit.cs`, `src/Parts.cs`, `src/Menus.cs`, `src/TaskEditor.cs`, `src/ColorPicker.cs`, `src/Kulia.cs`
- **Island & Navigation**: `src/Island.cs`, `src/Tabs.cs`, `src/Keyboard.cs`, `src/Views.cs`, `src/Panel.cs`, `src/WorkWindow.cs`, `src/Notes.cs`
- **Dock & Mini**: `src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, `src/DockWindow.cs`, `src/Mini.cs`

## Code Layout
- `src/Ink.cs`: Centralized design tokens (Tone, Type Scale, Squircles, Symbols, Springs, Fonts)
- `src/Colors.cs`: Palette generation, WCAG contrast calculation
- `src/Glass.cs`: Frosted & Liquid glass material shaders, background sampling, contrast guards
- `src/Kit.cs`: Custom owner-drawn WinForms controls (`KitWindow`, `KitButton`, `KitSwitch`, `KitSlider`, `KitRow`, `KitAsk`)
- `src/Island.cs`: Floating island HUD, layout, elevation shadows, layered rendering
- `src/Tabs.cs`: Island page navigation tabs, pill rendering, hit testing
- `src/Views.cs`: View layout, header routing, notification toasts, view radii
- `src/Panel.cs`: Standardized panel shell, search, headers, scroll states
- `src/Parts.cs`: Shared UI primitives (`Module`, `Pill`, `Button`, `EmptyState`)
- `src/DockPaint.cs`: Dock surface rendering, rim lights, sheen, unread badge pills
- `src/DockCard.cs`: Dock preview flyouts, close buttons, borders
- `src/Mini.cs`: Minimalist edge indicator sliver, privacy dots, progress track
- `src/Prefs.cs`: Settings window, theme switching orchestration (`ApplyThemeMode`), accent presets
- `src/TaskEditor.cs`, `src/ColorPicker.cs`, `src/Kulia.cs`, `src/WorkWindow.cs`: Modal windows and utilities

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Font Family Typo Corrections | Fix typos in `Ink.cs:207, 213` (`Display Semib` -> `Display Semibold`, `Small Semibol` -> `Small Semibold`) to ensure proper font weight resolution. | M1 | survey (spec_miner) |
| 2 | Light Mode Accent Preset Calibration | Calibrate all 7 preset accents in `Ink.cs` & `Prefs.cs` for light mode to achieve >= 3.5:1 non-text contrast against `#F5F5F5` (resolving Yellow 1.32:1, Green 1.72:1, Orange 1.87:1, etc.). | M1 | survey (spec_miner, explorer_3) |
| 3 | Frost Glass Adaptive Contrast Guard | Implement luminance contrast guard in `Glass.cs:326-327` for Frost material to prevent white text dropping to 3.0:1 on pure white wallpapers. | M1 | survey (spec_miner) |
| 4 | Liquid Glass Color Space Blending | Fix linear luminance blending into non-linear sRGB bytes in `Glass.cs:419-421` to restore target luminance (>=0.62) and >=4.5:1 contrast on dark wallpapers in light mode. | M1 | survey (spec_miner) |
| 5 | Custom Palette Contrast Floor | Enforce minimum contrast threshold in `Colors.DerivePalette` to prevent user-selected low contrast combinations (e.g. 1.26:1). | M1 | survey (spec_miner) |
| 6 | Elevate `KitInk.Faint` Light Contrast | Increase `KitInk.Faint` light-mode mix from 0.57 to 0.65 in `src/Kit.cs:28` to ensure >=4.5:1 contrast on `Side`, `Group`, `Hover`, and `Line`. | M2 | survey (explorer_3) |
| 7 | `KitButton` Interactive States & Focus Ring | Implement pressed visual state in `KitButton.OnPaint` and fix primary button focus ring contrast (replace identical text-colored stroke with distinct contrasting ring). | M2 | survey (spec_miner, explorer_2) |
| 8 | `KitSwitch` Hover State & Dynamics | Add `OnMouseEnter`/`OnMouseLeave` hover feedback to `KitSwitch` track/knob. | M2 | survey (spec_miner, explorer_2) |
| 9 | `KitSlider` Disabled Thumb Contrast | Update `KitSlider.OnPaint` so disabled thumb renders using `KitInk.Disabled` instead of active `KitInk.Text`. | M2 | survey (spec_miner, explorer_2) |
| 10 | `KitRow.MarkGlyph` Contrast Fix | Replace hardcoded `Brushes.Black` in `Kit.cs:587` with `KitInk.Text` and contrasting dot fill for theme compatibility. | M2 | survey (explorer_3) |
| 11 | `MenuLook` Submenu & Disabled Contrast | Adjust `Sub` mix in `src/Menus.cs:97` to >= 0.62f to elevate light-mode arrow and disabled item contrast above WCAG AA. | M2 | survey (explorer_3) |
| 12 | Eliminate Hardcoded Semantic Red | Replace hardcoded `Color.IndianRed` (`TaskEditor.cs:103, 125`, `WorkWindow.cs:673`) and `Color.FromArgb(224, 96, 84)` (`WorkWindow.cs:601`) with `Ink.Base.Negative`. | M2 | survey (explorer_3) |
| 13 | Centralized Dialog Theme Propagation | Introduce static `KitWindow.BroadcastThemeChange()` and call in `ApplyThemeMode` to update all open dialogs on theme switch. | M2 | survey (explorer_3) |
| 14 | `KitAsk` Universal Title & Localization | Fix `KitAsk` hardcoded title `"Tugas dan catatan"` and wrap button labels in `Lang.T`. | M2 | survey (explorer_3) |
| 15 | `KuliaLogin` Tokenization & Modernization | Refactor `KuliaLogin` to inherit from `KitWindow`, adopt `KitButton`, and replace ad-hoc colors with `KitInk` tokens. | M2 | survey (explorer_3) |
| 16 | `ColorPicker` Loupe Token Alignment | Align loupe form in `ColorPicker.cs` with theme tokens (replace hardcoded dark background and point font). | M2 | survey (spec_miner, explorer_3) |
| 17 | Island `OnGlass()` Contrast Enforcement | Pass `tone.OnGlass()` during glass rendering in `src/Island.cs:846, 1244` to ensure secondary text maintains >=4.5:1 contrast. | M3 | survey (spec_miner, explorer_2) |
| 18 | Island Pill Elevation Shadow on Glass | Render subtle elevation shadow on glass pill ($H \le 60$) in `Island.cs:816` to maintain depth over light wallpapers. | M3 | survey (explorer_2) |
| 19 | Island Approval Halo Reduced Motion | Guard halo breathing pulse in `Island.cs:1142` with `Anim.Reduced`. | M3 | survey (spec_miner, explorer_2) |
| 20 | Tabs Inverted Hover/Pressed Fill Fix | Correct inverted ternary state rendering in `src/Tabs.cs:519, 821, 832, 847` to `Pressed ? FillPressed : FillHover`. | M3 | survey (explorer_2) |
| 21 | Toast Notification Meta Text Collision | Fix width measurement and clipping in `src/Views.cs:755` so long app names do not collide with notification title. | M3 | survey (spec_miner, explorer_2) |
| 22 | Standardize Empty State Component | Consolidate `Panel.Empty` (`src/Panel.cs:13-20`) into shared `Parts.EmptyState` (`src/Parts.cs:374`). | M3 | survey (explorer_2) |
| 23 | Typography & Radius Scale Consolidation | Replace ad-hoc font sizes with the 7 type scale roles and consolidate arbitrary corner radii in views to `RadiusShell/Module/Control`. | M3 | survey (spec_miner, explorer_2) |
| 24 | Dock Hardcoded Colors Tokenization | Replace `BadgeRed`, `BadgeRedSoft`, and white rim lights in `DockPaint.cs` & `DockCard.cs` with `p.T.Negative`, `p.T.Highlight`, and `p.T.Text`. | M4 | survey (spec_miner, explorer_2) |
| 25 | Dock Module Interactive States | Add pressed state handling to buttons in `DockCal.cs` and related dock popouts. | M4 | survey (explorer_2) |
| 26 | Mini Indicator Visual Salience | Increase notification dot radius from 1.7px to >= 2.5px and thicken status track in `src/Mini.cs` for reliable visual perception. | M4 | survey (explorer_2) |
| 27 | E2E Test Suite Pass (Tiers 1-4) | Pass 100% of the opaque-box automated test suite across all 4 tiers (Feature, Boundary, Combinations, Scenarios). | M5 | dual track |
| 28 | Adversarial Coverage Hardening (Tier 5) | White-box stress testing, edge-case generation, and adversarial coverage hardening by Challenger. | M5 | dual track |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Design Token Core & Glass Contrast | `src/Ink.cs`, `src/Colors.cs`, `src/Glass.cs`, `src/WinTheme.cs`: Typo fixes, light accent contrast calibration, Frost/Liquid glass contrast shaders, palette contrast floor. | none | DONE |
| M2 | UI Toolkit & Dialog Modernization | `src/Kit.cs`, `src/Menus.cs`, `src/TaskEditor.cs`, `src/ColorPicker.cs`, `src/Kulia.cs`, `src/Prefs.cs`, `src/WorkWindow.cs`: `KitInk.Faint` contrast, `KitButton/Switch/Slider` interactive states, semantic red tokenization, `KitWindow` theme broadcast, `KuliaLogin` & `ColorPicker` tokenization, macOS-like Settings presets. | M1 | DONE |
| M3 | Island, Navigation & Views Polish | `src/Island.cs`, `src/Tabs.cs`, `src/Views.cs`, `src/Panel.cs`, `src/Parts.cs`, `src/WorkWindow.cs`: Island `OnGlass()`, pill drop shadow, halo reduced motion, `Tabs.cs` state fix, toast collision fix, empty state deduplication, type scale & radius consolidation. | M1, M2 | DONE |
| M4 | Dock & Mini Polish | `src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, `src/Mini.cs`: Dock badge & rim tokenization, dock module pressed states, Mini notification target salience. | M1, M2, M3 | IN_PROGRESS (conv: 44bb96df-8adf-4ed1-a44c-9a07495f91e7) |
| M5 | Final Milestone: 100% E2E Verification & Hardening | Full application integration: Pass 100% of E2E test suite (Tiers 1-4) published by E2E Testing track, then execute Tier 5 adversarial coverage hardening. | M2, M3, M4, TEST_READY | PLANNED |

---

## Interface Contracts

### M1 (Ink / Glass) ↔ M2 (Kit / Dialogs) & M3 (Island) & M4 (Dock)
- `Ink.Apply(bool light, Color? accent)` updates `Ink.Base` and `Ink.Flip` with guaranteed minimum contrast ratios:
  - Any light mode accent preset guarantees $\ge 3.5:1$ against `Ink.Paper.Bg` (`#F5F5F5`).
  - `Tone.OnGlass()` guarantees `Sub` alpha $\ge 189$ (74%) to maintain $\ge 4.5:1$ on bright wallpapers.
  - `Ink.Base.Negative` provides accessible semantic red ($\ge 4.5:1$ on light/dark backgrounds).
- `KitInk` derives from `Ink.Base` and `Ink.Light`:
  - `KitInk.Faint` returns `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)` ensuring $\ge 4.5:1$ contrast on all `KitInk` surfaces.
- `KitWindow.BroadcastThemeChange()` notifies all active `KitWindow` instances when `ApplyThemeMode` is triggered.

---

## E2E Testing Track Scope
The parallel E2E Testing Track is tasked with developing and publishing `TEST_READY.md` containing:
- Test runner executable or PowerShell harness running against `build.cmd` output (`Tepi.exe`).
- Tier 1: Feature coverage ($\ge 5$ tests per feature area).
- Tier 2: Boundary & Corner cases (light wallpaper, pitch black wallpaper, reduced motion, disabled controls, long notification titles).
- Tier 3: Cross-feature combinations (theme switching with open dialogs, accent preset toggles with glass materials).
- Tier 4: Real-world user workloads (onboarding tour, settings customization, task management, media playback, dock auto-hide).
- Minimum test cases: $\ge 11 \times 26 + \max(5, 13) \approx 300$ automated checks/assertions.
