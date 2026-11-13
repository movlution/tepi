## 2026-11-12T23:16:37Z
You are the Worker for Milestone 2 of the Tepi UI/UX Production Visual Overhaul project.

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\worker_m2_1\
Parent orchestrator conversation ID: 789fb24f-4dc5-451b-991c-640bde73cdc8

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

You MUST read these foundation documents before starting:
1. ORIGINAL_REQUEST.md: d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md
2. Global project plan: d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md
3. Milestone 2 scope: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m2\SCOPE.md
4. Milestone 2 synthesis: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m2\synthesis.md
5. Explorer analysis reports:
   - d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_1\analysis.md
   - d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_2\analysis.md
   - d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_3\analysis.md

Exclusive Write Boundaries (You MUST modify ONLY these files):
- src/Kit.cs
- src/Menus.cs
- src/TaskEditor.cs
- src/ColorPicker.cs
- src/Kulia.cs
- src/Prefs.cs
- src/WorkWindow.cs

Implementation Tasks:
1. KitInk.Faint: In src/Kit.cs:28, raise mix from 0.57f to 0.65f in light mode: Ink.Light ? 0.65f : 0.57f.
2. MenuLook Submenu & Disabled Contrast: In src/Menus.cs:97, increase Sub mix factor to Ink.Light ? 0.65f : 0.62f.
3. KitButton: In src/Kit.cs, implement pressed visual state (pressed field, OnMouseDown/Up/Leave, offset r.Offset(0, 0.75f * s) and deeper tint) and a contrasting focus ring (>= 3:1 contrast against button surface).
4. KitSwitch: In src/Kit.cs, add hovered tracking on track/knob via OnMouseEnter/OnMouseLeave, subtle luminance boost on track and knob expansion when hovered.
5. KitSlider: In src/Kit.cs:362, render thumb using Enabled ? KitInk.Text : KitInk.Disabled.
6. KitRow.MarkGlyph: In src/Kit.cs:587, replace hardcoded Brushes.Black with KitInk.Text for pill background and KitInk.Window for dot.
7. Semantic Red: Replace all 5 hardcoded red occurrences with Ink.Base.Negative:
   - src/TaskEditor.cs:103
   - src/TaskEditor.cs:125
   - src/WorkWindow.cs:314
   - src/WorkWindow.cs:601 (replace Color.FromArgb(224, 96, 84))
   - src/WorkWindow.cs:673
8. KitWindow.BroadcastThemeChange(): In src/Kit.cs, add static registry of KitWindow instances and implement public static void BroadcastThemeChange(). In src/Prefs.cs (ApplyThemeMode, SetAccentHex, etc.), invoke KitWindow.BroadcastThemeChange().
9. KitAsk: In src/Kit.cs, make title dynamic from argument (default to Lang.T("Pemberitahuan")), and wrap action button labels in Lang.T.
10. KuliaLogin: In src/Kulia.cs, refactor to inherit from KitWindow, use KitButton for primary and back, remove ad-hoc colors, implement Relayout(), clean up obsolete P/Invoke & Escape handlers.
11. ColorPicker: In src/ColorPicker.cs, align Loupe with KitInk.Window, KitInk.Text, KitInk.Line, use Ink.Semi(13f), and implement dual-stroke contrast reticle.
12. Settings Appearance & Theme: In src/Prefs.cs, redesign appearance section with curated macOS-like presets (KitPalette control with 8 curated presets: Blue, Purple, Pink, Red, Orange, Yellow, Green, Graphite), clean light/dark/system mode, and elegant controls.

Compilation & Verification:
- Compile using `.\build.cmd` and ensure zero errors and clean Tepi.exe generation.
- Run tests:
  - tests\tier1_features\test_f12_semantic_negative.ps1
  - tests\tier1_features\test_f15_kulia_login.ps1
  - tests\tier2_boundaries\test_b12_semantic_red.ps1
  - tests\tier2_boundaries\test_b15_kulia_tokens.ps1
  - tests\tier2_boundaries\test_b16_loupe_tokens.ps1
- Document your changes and verification in changes.md and handoff.md in your state folder.
- Send a completion message to the parent sub-orchestrator (789fb24f-4dc5-451b-991c-640bde73cdc8) when done.
