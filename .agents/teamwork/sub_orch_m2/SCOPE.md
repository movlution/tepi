# Scope: Milestone 2 — UI Toolkit & Dialog Modernization

**Status**: **DONE** (Gate Passed on Iteration 1)

## Mission
Implement complete modernization of the UI Toolkit, custom controls, and modal dialogs (`src/Kit.cs`, `src/Menus.cs`, `src/TaskEditor.cs`, `src/ColorPicker.cs`, `src/Kulia.cs`, `src/Prefs.cs`) for production readiness and full WCAG AA contrast compliance.

## Target Source Files (Exclusive Write Boundaries)
- `src/Kit.cs`: Custom controls (`KitInk`, `KitButton`, `KitSwitch`, `KitSlider`, `KitRow`, `KitWindow`, `KitAsk`)
- `src/Menus.cs`: Submenu contrast and disabled menu item styling in `MenuLook`
- `src/TaskEditor.cs`: Elimination of hardcoded `IndianRed` with `Ink.Base.Negative`
- `src/ColorPicker.cs`: Loupe theme tokenization and type scale alignment
- `src/Kulia.cs`: Refactor `KuliaLogin` to inherit from `KitWindow`, use `KitButton`, and adopt `KitInk` tokens
- `src/Prefs.cs`: Curated modern macOS-like appearance & theme preset customization, wire `KitWindow.BroadcastThemeChange()` into `ApplyThemeMode`
- `src/WorkWindow.cs`: Replace hardcoded `Color.IndianRed` (line 673) and `Color.FromArgb(224, 96, 84)` (line 601) with `Ink.Base.Negative`

## Feature Requirements & Acceptance Criteria
1. **Elevate `KitInk.Faint` Contrast (Light Mode)**:
   - In `src/Kit.cs:28`, raise mix factor from `0.57f` to `0.65f` in light mode:
     `Mix(Base.Bg, Base.Text, Light ? 0.65f : 0.57f)`
   - Guarantees >= 4.5:1 text contrast across `Side`, `Group`, `Hover`, and `Line` surfaces.
2. **`MenuLook` Submenu & Disabled Contrast**:
   - In `src/Menus.cs:97`, increase `Sub` mix factor to `>= 0.62f` to ensure submenu arrows and disabled menu items pass WCAG AA contrast against menu surface.
3. **`KitButton` Pressed State & Contrasting Focus Ring**:
   - In `src/Kit.cs` `KitButton.OnPaint`:
     - Implement visible pressed state (e.g., darker/deeper background tint or offset).
     - Fix focus ring: ensure a distinct, contrasting focus ring (>= 3:1 contrast against button surface/background, not identical to button text color).
4. **`KitSwitch` Hover State & Dynamics**:
   - In `src/Kit.cs` `KitSwitch`: add `OnMouseEnter`/`OnMouseLeave` visual hover feedback on track and knob (e.g. subtle luminance shift / highlight).
5. **`KitSlider` Disabled Thumb Contrast**:
   - In `src/Kit.cs` `KitSlider.OnPaint`: render disabled thumb using `KitInk.Disabled` instead of active `KitInk.Text`.
6. **`KitRow.MarkGlyph` Contrast Fix**:
   - In `src/Kit.cs:587`: replace hardcoded `Brushes.Black` with `KitInk.Text` and contrasting dot fill for dark and light theme compatibility.
7. **Eliminate Hardcoded Semantic Red**:
   - Replace all instances of `Color.IndianRed` (`TaskEditor.cs:103, 125`, `WorkWindow.cs:673`) and `Color.FromArgb(224, 96, 84)` (`WorkWindow.cs:601`) with semantic token `Ink.Base.Negative`.
8. **Centralized Dialog Theme Propagation**:
   - In `src/Kit.cs`: add static registry and method `public static void BroadcastThemeChange()` on `KitWindow`.
   - Maintain weak references or list of open `KitWindow` instances.
   - When called, each open window refreshes its colors, invalidates controls, and repaints.
   - In `src/Prefs.cs`: invoke `KitWindow.BroadcastThemeChange()` inside `ApplyThemeMode` (and wherever theme/accent changes).
9. **`KitAsk` Localization & Dynamic Title**:
   - In `src/Kit.cs` `KitAsk`: replace hardcoded title `"Tugas dan catatan"` with the title parameter passed to `KitAsk`, and wrap button labels in `Lang.T`.
10. **`KuliaLogin` Modernization**:
    - Refactor `KuliaLogin` to inherit from `KitWindow` instead of raw `Form`.
    - Adopt `KitButton` for login/cancel actions.
    - Replace ad-hoc background and text colors with `KitInk` tokens.
11. **`ColorPicker` Loupe Token Alignment**:
    - In `src/ColorPicker.cs`: align loupe magnification window with `KitInk` tokens (replace hardcoded dark background and raw point font with `KitInk` tokens and standard type scale from `Ink`).
12. **Settings Appearance & Theme Customization (macOS-like)**:
    - In `src/Prefs.cs`: redesign the theme & appearance section to be simple, clean, and curated ala macOS:
      - Curated palette accent presets (e.g. Blue, Purple, Pink, Red, Orange, Yellow, Green, Graphite).
      - Clean visual style choices (Light / Dark / System Auto).
      - Simple, elegant toggles without cluttered or redundant sliders.

## Orchestration Procedure (Iteration Loop 2B)
1. **Survey / Explore**: Spawn 3 Explorers (`teamwork_explorer`, `teamwork_spec_miner`) to analyze target files, exact line numbers, ASTs, and recommend concrete diffs.
2. **Worker Implementation**: Spawn 1 `teamwork_worker` with mandatory integrity warning to apply the code changes, compile via `build.cmd`, and run test scripts.
3. **Reviewers**: Spawn 2 `teamwork_reviewer` to review correctness, accessibility, and visual compliance.
4. **Challengers**: Spawn 2 `teamwork_challenger` to verify interactive control states, contrast ratios, and theme broadcasting.
5. **Auditor**: Spawn 1 `teamwork_auditor` for binary forensic integrity audit.
6. **Gate Evaluation**: Evaluate `GATE_STATUS.md`. Gate passes ONLY if build succeeds, all reviewers approve, all challengers confirm, and auditor is CLEAN.
