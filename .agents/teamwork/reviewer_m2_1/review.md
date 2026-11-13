# Milestone 2: UI Toolkit & Dialog Modernization — Code & Architecture Review

## Review Summary

**Verdict**: APPROVE  
**Overall Risk Assessment**: LOW  
**Integrity Assessment**: CLEAN (Zero integrity violations; genuine implementations across all controls)

---

## Architectural & Code Quality Assessment

### 1. Correctness & Requirement Compliance
- **Feature 6: `KitInk.Faint` Contrast (Light Mode)**:
  In `src/Kit.cs:28`, `KitInk.Faint` raises the mix factor from `0.57f` to `0.65f` in Light Mode (`Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)`). Contrast verification confirms luminance $L \approx 0.1096$, exceeding the 4.5:1 WCAG AA threshold across all container surfaces: Window (6.03:1), Group (5.57:1), Side (5.42:1), Hover (4.98:1), and Line (4.66:1).
- **Feature 7: `KitButton` Interactive Feedback & Focus Ring**:
  In `src/Kit.cs:547-626`, `KitButton` properly captures mouse down/up/leave events, applies a physical downward displacement `r.Offset(0, 0.75f * s)`, deepens background tints for primary and secondary variants in both themes, and incorporates a focus ring contrast guard that guarantees $\ge 3.0:1$ contrast against the button fill (falling back to calibrated blue `#1668E8` / `#3B82F6` if monochrome or low contrast).
- **Feature 8: `KitSwitch` Hover State & Dynamics**:
  In `src/Kit.cs:167-214`, `KitSwitch` implements `OnMouseEnter` and `OnMouseLeave` hover detection, boosting track luminance by `0.06f` mix and dynamically expanding the knob radius from `9.0s` to `9.5s`. Knobs remain accessible and smoothly animated.
- **Feature 9: `KitSlider` Disabled Thumb Contrast**:
  In `src/Kit.cs:524-527`, the thumb solid brush and border pen conditionally render `Enabled ? KitInk.Text : KitInk.Disabled`. When disabled, the thumb dims properly rather than displaying active text brightness.
- **Feature 10: `KitRow.MarkGlyph` Contrast Fix**:
  In `src/Kit.cs:788-797`, the legacy hardcoded `Brushes.Black` has been replaced by `KitInk.Text` for the pill body and `KitInk.Window` for the inner dot. In Light Mode, this yields $> 14.6:1$ contrast (resolving the previous $1.08:1$ invisible dot failure).
- **Feature 11: `MenuLook` Submenu & Disabled Contrast**:
  In `src/Menus.cs:97`, `Sub` mix factor was increased to `Ink.Light ? 0.65f : 0.62f`, elevating submenu arrows and disabled menu items to $5.24:1$ against the menu background in Light Mode, passing WCAG AA.
- **Feature 12: Semantic Red Elimination**:
  All 5 occurrences of hardcoded `Color.IndianRed` (`src/TaskEditor.cs:100, 125`, `src/WorkWindow.cs:314, 673`) and `Color.FromArgb(224, 96, 84)` (`src/WorkWindow.cs:601`) were replaced with `Ink.Base.Negative`. Source tree grep confirms zero remaining instances of `IndianRed` or `224, 96, 84` across `src/`.
- **Feature 13: Centralized Dialog Theme Propagation**:
  `KitWindow.BroadcastThemeChange()` maintains a weak-reference registry (`List<WeakReference>`), handles window disposal/cleanup safely, searches `Application.OpenForms`, performs thread marshaling via `BeginInvoke`, and triggers `Native.DarkFrame`, `Relayout()`, and tree invalidation. It is correctly wired to `Prefs.cs:ApplyThemeMode()`, `SetAccentHex()`, and custom theme toggles.
- **Feature 14: `KitAsk` Localization & Dynamic Title**:
  In `src/Kit.cs:1008-1074`, `KitAsk` supports caller-provided titles, defaulting to `Lang.T("Konfirmasi")` or `Lang.T("Pemberitahuan")`. All action buttons (`yes`, `no`, `ok`) are wrapped in `Lang.T()`. Text layout adapts dynamically using word-break measurement.
- **Feature 15: `KuliaLogin` Modernization**:
  In `src/Kulia.cs:339-510`, `KuliaLogin` was refactored to inherit from `KitWindow`. Action buttons were upgraded to `KitButton`, input fields to `KitText`, and ad-hoc color literals were replaced with `KitInk.Window`, `KitInk.Text`, `KitInk.Sub`, `KitInk.Group`, and `Ink.Base.Negative`. Redundant P/Invoke calls and manual escape handlers were eliminated.
- **Feature 16: `ColorPicker` Loupe Token Alignment**:
  In `src/ColorPicker.cs:134-206`, the Loupe was updated to use `KitInk.Window`, `KitInk.Text`, `KitInk.Line`, and `Ink.Semi(13f)`. A dual-stroke reticle (dark outer + light inner) ensures cursor target visibility against any background pixel. Per-frame font handle allocations were eliminated.
- **macOS-like Appearance & Presets**:
  In `src/Kit.cs` and `src/Prefs.cs`, a custom owner-drawn `KitPalette` control provides circular swatches for 8 curated presets (Blue, Purple, Pink, Red, Orange, Yellow, Green, Graphite). Accents automatically switch to calibrated high-contrast light-mode values when switching theme mode.

---

## Adversarial Challenge & Stress-Testing

### Challenge 1: Memory & Weak Reference Retention in `KitWindow`
- **Assumption Challenged**: Static `openWindows` list could leak window instances or crash if targets are garbage collected concurrently.
- **Attack Scenario**: Rapid opening, closing, and theme toggling of dialogs while GC is running.
- **Stress-Test Result**: `test_b13_dialog_theme.ps1` executes rapid successive theme switches across open and closed dialog instances. In `BroadcastThemeChange()`, dead targets (`target == null || target.IsDisposed`) are automatically removed inside a `lock (openWindows)` block.
- **Blast Radius**: None. Weak references allow prompt collection; cleanup occurs on `OnClosed`, `Dispose`, and during broadcast.
- **Verdict**: PASS.

### Challenge 2: GDI Resource Leaks in `Loupe` Per-Frame Drawing
- **Assumption Challenged**: Frequent loupe repaints during mouse tracking could exhaust GDI font or pen handles.
- **Attack Scenario**: Mouse movement across screen triggers hundreds of `OnPaint` calls per second.
- **Stress-Test Result**: `Loupe.OnPaint` replaced `new Font("Segoe UI Semibold", 10f)` with cached `Ink.Semi(13f)`. All brushes and pens are wrapped in `using (...)` blocks. Tested offscreen in `test_b16_loupe_tokens.ps1` with zero handle leaks.
- **Blast Radius**: None.
- **Verdict**: PASS.

### Challenge 3: Negative Semantic Token Readability on White/Black Extremes
- **Assumption Challenged**: `Ink.Base.Negative` might lose contrast on extreme wallpapers or non-standard backgrounds.
- **Attack Scenario**: Sampling `Ink.Base.Negative` against pure `#FFFFFF`, `#000000`, and midtone `#808080`.
- **Stress-Test Result**: `test_b12_semantic_red.ps1` verified contrast $> 4.5:1$ on light background ($5.19:1$) and dark background ($7.21:1$), and tested pure white and black boundaries successfully.
- **Blast Radius**: None.
- **Verdict**: PASS.

### Challenge 4: Primary Button Focus Ring Contrast with Monochrome Accent
- **Assumption Challenged**: When accent is monochrome / graphite or matches button text (`#0C0C0E` in light mode), focus ring stroke would be invisible against the button body.
- **Attack Scenario**: Selecting "Grafit" accent in light mode and focusing a Primary `KitButton`.
- **Stress-Test Result**: Inspected `KitButton.OnPaint` (lines 619-622):
  ```csharp
  if (Island.Contrast(ringColor, bg) < 3.0 || (Primary && (ringColor == KitInk.Text || ringColor == bg)))
      ringColor = Ink.Light ? Color.FromArgb(255, 22, 104, 232) : Color.FromArgb(255, 59, 130, 246);
  ```
  The fallback condition explicitly detects low contrast ($< 3.0:1$) or identity with `KitInk.Text` on Primary buttons and activates high-visibility blue.
- **Blast Radius**: None.
- **Verdict**: PASS.

---

## Findings

### Minor Observation 1 (Cosmetic / Architectural Note)
- **What**: In `KitWindow.BroadcastThemeChange()`, both `openWindows` (weak references) and `Application.OpenForms` are inspected to aggregate targets.
- **Where**: `src/Kit.cs:866-885`
- **Why**: Redundant check is harmless and acts as defense-in-depth, ensuring dialogs opened without default registration are still captured.
- **Suggestion**: Keep as-is; provides excellent resiliency.

---

## Verified Claims

| Claim | Verification Method | Result |
|---|---|---|
| `Tepi.exe` builds cleanly via `.\build.cmd` | `cmd.exe /c build.cmd` executed | PASS (`Build OK`) |
| `KitInk.Faint` mix 0.65 yields $\ge 4.5:1$ contrast in light mode | `test_f06_kit_faint.ps1` & `test_b06_kit_faint_contrast.ps1` | PASS |
| `KitButton` interactive states (hover, pressed, focus ring) | `test_f07_kit_button.ps1` & `test_b07_button_states.ps1` | PASS |
| `KitSwitch` hover dynamics and track/knob feedback | `test_f08_kit_switch.ps1` & `test_b08_switch_hover.ps1` | PASS |
| `KitSlider` disabled thumb contrast uses `KitInk.Disabled` | `test_f09_kit_slider.ps1` & `test_b09_slider_disabled.ps1` | PASS |
| `KitRow.MarkGlyph` contrast fixed (pill `KitInk.Text`, dot `KitInk.Window`) | `test_f10_kit_row.ps1` & `test_b10_mark_glyph.ps1` | PASS |
| `MenuLook.Sub` mix $\ge 0.62f$ achieves WCAG AA in light mode | `test_f11_menu_look.ps1` & `test_b11_menu_look.ps1` | PASS |
| Semantic red hardcoded literals eliminated from source | `test_f12_semantic_negative.ps1` & `git grep` check | PASS (0 occurrences) |
| Dialog theme propagation via `KitWindow.BroadcastThemeChange()` | `test_f13_dialog_broadcast.ps1` & `test_b13_dialog_theme.ps1` | PASS |
| `KitAsk` dynamic title and `Lang.T` localization | `test_f14_kit_ask.ps1` & `test_b14_kit_ask.ps1` | PASS |
| `KuliaLogin` modernized to `KitWindow` and `KitButton` | `test_f15_kulia_login.ps1` & `test_b15_kulia_tokens.ps1` | PASS |
| `ColorPicker` loupe aligned with theme tokens and dual reticle | `test_b16_loupe_tokens.ps1` & source inspection | PASS |
| Settings appearance curated macOS presets (`KitPalette`) | `src/Prefs.cs` inspection & compilation | PASS |
| All Tier 1 and Tier 2 test suites pass with zero regressions | Automated test execution run of all 36 test files | PASS (36/36 suites) |

---

## Coverage Gaps
- None. All 12 feature items in Milestone 2 scope have corresponding code implementations and unit/boundary automated test coverage.

## Unverified Items
- None.

---

## Integrity Check Attestation
- **Hardcoded test results**: None detected. Tests exercise runtime reflection, GDI+ bitmaps, and actual contrast algorithms.
- **Dummy/Facade implementations**: None detected. Real event handlers, real brushes, real calculations.
- **Bypasses/Shortcuts**: None detected. Code adheres strictly to specified boundaries and contracts.
- **Attestation**: Work is genuine, robust, and verified independently.
