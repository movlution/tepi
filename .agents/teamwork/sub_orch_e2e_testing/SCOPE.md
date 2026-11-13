# Scope: E2E Testing Track Orchestrator

## Architecture
- Target Binary: `Tepi.exe` built via `build.cmd`
- Test Runner: Requirement-driven, opaque-box PowerShell test runner (`tests/run_e2e.ps1`) executing automated assertions across reflection contracts, visual design tokens, WCAG contrast calculations, headless offscreen control rendering via `DrawToBitmap`, and CLI process invocations.
- Zero External Dependencies: Pure Windows PowerShell utilizing .NET Framework 4.8 CLR pre-installed on Windows.
- Output Deliverables:
  - `TEST_INFRA.md` (at project root)
  - `tests/` directory with test runner harness and test suites across Tiers 1-4
  - `TEST_READY.md` (at project root)

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Font Family Typo Corrections | Verify font weights resolve correctly in Display and Small Semibold roles | TM2 | survey |
| 2 | Light Mode Accent Preset Calibration | Verify all 7 preset accents maintain >= 3.5:1 non-text contrast against #F5F5F5 | TM2 | survey |
| 3 | Frost Glass Adaptive Contrast Guard | Verify Frost material luminance contrast guard keeps text >= 4.5:1 on pure white wallpaper | TM2 | survey |
| 4 | Liquid Glass Color Space Blending | Verify linear luminance blending maintains target luminance and contrast on dark wallpapers | TM2 | survey |
| 5 | Custom Palette Contrast Floor | Verify minimum contrast floor in palette derivation rejects low-contrast combinations | TM2 | survey |
| 6 | Elevate KitInk.Faint Light Contrast | Verify KitInk.Faint light-mode contrast >= 4.5:1 across Kit surfaces | TM2 | survey |
| 7 | KitButton Interactive States & Focus Ring | Verify KitButton pressed visual state and distinct contrasting focus ring | TM2 | survey |
| 8 | KitSwitch Hover State & Dynamics | Verify KitSwitch hover feedback on track and knob | TM2 | survey |
| 9 | KitSlider Disabled Thumb Contrast | Verify KitSlider disabled thumb renders with Disabled token rather than active Text token | TM2 | survey |
| 10 | KitRow.MarkGlyph Contrast Fix | Verify KitRow mark glyph contrast and theme compatibility | TM2 | survey |
| 11 | MenuLook Submenu & Disabled Contrast | Verify MenuLook submenu arrow and disabled item contrast >= WCAG AA | TM2 | survey |
| 12 | Eliminate Hardcoded Semantic Red | Verify semantic negative token replaces hardcoded IndianRed / ad-hoc red | TM2 | survey |
| 13 | Centralized Dialog Theme Propagation | Verify theme switching propagates immediately to all open dialogs | TM2 | survey |
| 14 | KitAsk Universal Title & Localization | Verify KitAsk title is dynamic and button labels pass through Lang.T | TM2 | survey |
| 15 | KuliaLogin Tokenization & Modernization | Verify KuliaLogin inherits KitWindow, KitButton, and tokenized palette | TM2 | survey |
| 16 | ColorPicker Loupe Token Alignment | Verify ColorPicker loupe adheres to theme tokens and scale | TM2 | survey |
| 17 | Island OnGlass() Contrast Enforcement | Verify Island OnGlass() guarantees secondary text contrast >= 4.5:1 | TM2 | survey |
| 18 | Island Pill Elevation Shadow on Glass | Verify Island pill elevation drop shadow renders on light wallpapers | TM2 | survey |
| 19 | Island Approval Halo Reduced Motion | Verify Island approval halo respects system reduced motion setting | TM2 | survey |
| 20 | Tabs Inverted Hover/Pressed Fill Fix | Verify Tabs hover vs pressed states are correctly differentiated | TM2 | survey |
| 21 | Toast Notification Meta Text Collision | Verify long app names do not collide or overlap with notification title in Toast | TM2 | survey |
| 22 | Standardize Empty State Component | Verify shared EmptyState component is used consistently | TM2 | survey |
| 23 | Typography & Radius Scale Consolidation | Verify consolidated typography scale and corner radii | TM2 | survey |
| 24 | Dock Hardcoded Colors Tokenization | Verify Dock badge and rim lights use theme tokens | TM2 | survey |
| 25 | Dock Module Interactive States | Verify Dock popout buttons have interactive pressed feedback | TM2 | survey |
| 26 | Mini Indicator Visual Salience | Verify Mini notification dot salience (radius >= 2.5px) and track thickness | TM2 | survey |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| TM0 | Survey & Test Entrypoints | Survey existing test harness, CLI arguments, build script, and test infrastructure | none | DONE |
| TM1 | Test Infra & Harness | Design opaque-box test runner, harness format, and create `TEST_INFRA.md` | TM0 | IN_PROGRESS |
| TM2 | Tier 1 Feature Coverage Tests | Implement Tier 1 test suite (>= 5 tests per feature, >= 130 tests total) | TM1 | PLANNED |
| TM3 | Tier 2 Boundary & Corner Tests | Implement Tier 2 test suite (>= 5 boundary tests per feature, >= 130 tests total) | TM2 | PLANNED |
| TM4 | Tier 3 & 4 Cross-Feature & Scenarios | Implement Tier 3 pairwise and Tier 4 real-world workload scenarios (>= 39 tests total) | TM3 | PLANNED |
| TM5 | Test Suite Verification & Publication | Run full test suite against build.cmd, verify zero crashes, publish `TEST_READY.md` | TM4 | PLANNED |
