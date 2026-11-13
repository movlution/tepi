# Handoff Report: Test Infrastructure & Testability Survey (TM0)

**Date**: 2026-11-12T15:42:00Z  
**Author**: Test Infrastructure Explorer (`explorer_tm0`)  
**Recipient**: E2E Testing Track Orchestrator (`sub_orch_e2e_testing`)  
**Milestone**: TM0 - Survey & Test Entrypoints  

---

## 1. Observation

### 1.1 `build.cmd` Build Mechanics
Inspection of `d:\PROJECT\Other\tepi\build.cmd`:
```cmd
1: @echo off
2: rem Builds Tepi.exe with the C# compiler bundled in Windows (.NET Framework 4.8)
3: rem Optional: build.cmd [output.exe] [extra source files]
4: setlocal
5: set FW=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319
6: set WMD=%WINDIR%\System32\WinMetadata
7: set ROOT=%~dp0
8: set OUT=%~1
9: if "%OUT%"=="" set OUT=%ROOT%Tepi.exe
10: set EXTRA=
11: if not "%~2"=="" set EXTRA="%~2"
12: 
13: "%FW%\csc.exe" /nologo /target:winexe /optimize+ /platform:x64 /warn:4 ^
14:   /out:"%OUT%" ^
15:   /win32manifest:"%ROOT%src\app.manifest" /win32icon:"%ROOT%src\Tepi.ico" /resource:"%ROOT%src\Tepi.ico",Tepi.ico ^
16:   /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Web.Extensions.dll /r:System.Security.dll /r:System.Management.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:Microsoft.VisualBasic.dll ^
17:   /r:"%WMD%\Windows.Foundation.winmd" /r:"%WMD%\Windows.Media.winmd" /r:"%WMD%\Windows.Storage.winmd" /r:"%WMD%\Windows.Networking.winmd" ^
18:   /r:"%WMD%\Windows.UI.winmd" /r:"%WMD%\Windows.ApplicationModel.winmd" /r:"%WMD%\Windows.Devices.winmd" /r:"%WMD%\Windows.Graphics.winmd" /r:"%WMD%\Windows.Data.winmd" /r:"%WMD%\Windows.Globalization.winmd" ^
19:   /r:"%FW%\System.Runtime.dll" /r:"%FW%\System.Runtime.InteropServices.WindowsRuntime.dll" /r:"%FW%\System.Runtime.WindowsRuntime.dll" ^
20:   "%ROOT%src\*.cs" %EXTRA%
21: if errorlevel 1 (
22:   echo Build gagal.
23:   exit /b 1
24: )
25: echo Build OK: %OUT%
```
- **Compiler**: Uses the Windows-bundled Roslyn/C# compiler at `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe` (.NET Framework 4.8 runtime, 64-bit).
- **Target & Architecture**: `/target:winexe /platform:x64 /optimize+ /warn:4`.
- **References**: Standard .NET framework assemblies, plus WinRT metadata contracts from `%WINDIR%\System32\WinMetadata\*.winmd` and WinRT runtime interop assemblies.
- **Sources**: Compiles all `src\*.cs` files together.
- **Execution**: Verified via `cmd.exe /c "build.cmd"`. Build completed with exit code `0` in ~3.8 seconds, producing `d:\PROJECT\Other\tepi\Tepi.exe` (size ~926 KB).

### 1.2 Existing Test Infrastructure
- Directory search across entire repository (`Get-ChildItem -Recurse -Filter *test*`):
  - Result: Zero test files, test directories (`tests/`, `test/`), or test projects exist in the current repository.
  - The repository has no pre-existing unit test runner, NUnit/xUnit project, or PowerShell test harness.

### 1.3 `src/Program.cs` & CLI Execution Capabilities
Inspection of `src/Program.cs:8-19`:
```csharp
8:     static class Program
9:     {
10:         [STAThread]
11:         static int Main(string[] args)
12:         {
13:             // Agent hook bridge: no window, no mutex
14:             if (args.Length > 0 && args[0] == "--relay") return Relay.Run(args);
15:             if (args.Length > 0 && args[0] == "--notify") return NotifyCommand.Run(args);
16:             if (args.Length > 0 && args[0] == "--run") return RunCommand.Run(args);
17:             if (args.Length > 0 && args[0] == "--statusline") return StatusLine.Run(args);
18:             return RunIsland();
19:         }
```
- CLI arguments recognized:
  1. `--relay <agent> ...`: Hook bridge for agent communications (`Relay.cs:12-57`).
  2. `--notify <title> [detail] [--progress 0-100] [--id name]`: Posts toast notification via local HTTP relay (`Plugin.cs:63-83`). Returns code `2` on missing args, `1` if relay offline, `0` on success.
  3. `--run <cmd>`: Attaches console, runs command, and notifies Relay (`Run.cs:113-140`).
  4. `--statusline`: Consumes JSON on stdin, formats quota statusline, posts to `/usage` (`Quota.cs:12-47`).
  5. `--after <pid>`: Used during update restarts to wait for prior process PID to exit before acquiring mutex.
- When launched without recognized args, `RunIsland()` executes:
  - Checks named mutex `Settings.MutexName` (`"Tepi.App.Mutex"`).
  - If another instance is running, exits immediately with code `0`.
  - Otherwise, initializes DPI awareness, accessibility switches (`Switch.UseLegacyAccessibilityFeatures`), and calls `Application.Run(new Island())`.
- Currently, there are no `--version`, `--help`, `--check`, or dedicated headless test CLI switches in `Main`.

### 1.4 Reflection Loading & Opaque-Box Execution in PowerShell
Direct empirical validation using Windows PowerShell (`powershell.exe`):
1. **Assembly Loading**:
   ```powershell
   $asm = [System.Reflection.Assembly]::LoadFrom("d:\PROJECT\Other\tepi\Tepi.exe")
   $asm.GetTypes().Length # Returns 821 types
   ```
2. **Type Visibility & Internal Access**:
   All core token and engine classes (`Tepi.Ink`, `Tepi.KitInk`, `Tepi.Tone`, `Tepi.Island`, `Tepi.KitButton`, `Tepi.KitSwitch`, `Tepi.KitSlider`, `Tepi.KitWindow`) are compiled as `internal` (`IsPublic = False`).
   However, .NET Reflection in PowerShell cleanly accesses all internal types and members using:
   `[System.Reflection.BindingFlags]'NonPublic,Public,Static,Instance'`.
3. **WCAG Contrast Endpoint (`Island.Contrast`)**:
   Method `public static double Contrast(Color a, Color b)` in `src/Colors.cs:110` (part of `partial class Island`) was invoked:
   ```powershell
   $contrast = $islandType.GetMethod('Contrast', [System.Reflection.BindingFlags]'Public,NonPublic,Static')
   $contrast.Invoke($null, @([Drawing.Color]::Black, [Drawing.Color]::White)) # Returns exactly 21.0
   ```
4. **Direct Validation of 7 Light Mode Accent Presets vs `#F5F5F5`**:
   Measured using `Island.Contrast` via PowerShell:
   | Accent Preset | Hex Code | Measured Contrast vs `#F5F5F5` | Requirement (>=3.5:1) | Status |
   |---|---|---|---|---|
   | Biru | `#4C8DFF` | 2.94:1 | >= 3.5:1 | **FAIL** |
   | Hijau | `#3DD68C` | 1.72:1 | >= 3.5:1 | **FAIL** |
   | Kuning | `#FFD24A` | 1.32:1 | >= 3.5:1 | **FAIL** |
   | Oranye | `#FF9F43` | 1.87:1 | >= 3.5:1 | **FAIL** |
   | Merah muda | `#FF6B9A` | 2.46:1 | >= 3.5:1 | **FAIL** |
   | Ungu | `#A78BFA` | 2.50:1 | >= 3.5:1 | **FAIL** |
   | Navy | `#7F8DC6` | 2.95:1 | >= 3.5:1 | **FAIL** |
   *Every single preset fails the >= 3.5:1 non-text contrast requirement in light mode.*
5. **Direct Validation of `KitInk.Faint` Contrast**:
   Evaluated in light mode (`Ink.Apply(true)`):
   - `Faint` vs `Side`: 5.55:1 (PASS)
   - `Faint` vs `Group`: 5.32:1 (PASS)
   - `Faint` vs `Hover`: **4.39:1** (**FAIL**, < 4.5:1)
   - `Faint` vs `Line`: 4.56:1 (PASS)
6. **Direct Validation of Font Typo in `Ink.families`**:
   Invoking `Ink.Init()` populates `families`:
   - `families[0]` = `'Segoe UI Variable Display Semib'` (typo in `src/Ink.cs:207`)
   - `families[6]` = `'Segoe UI Variable Small Semibol'` (typo in `src/Ink.cs:213`)
7. **Headless Offscreen UI Control Rendering**:
   PowerShell successfully instantiated `KitButton`, set bounds to 120x36, and rendered it headlessly to an offscreen `System.Drawing.Bitmap` via `DrawToBitmap`:
   `KitButton instantiated and drawn to bitmap: Width=120, Height=36`.
   No desktop window was spawned, no taskbar icon appeared, and no focus was stolen.

### 1.5 Visual Audit Criteria in `docs/analisis/`
- `01-visual.md` & `next-visual.md` establish specific quantifiable standards:
  - Normal text contrast: $\ge 4.5:1$ WCAG AA.
  - Large text & graphic / non-text components: $\ge 3.0:1$ (UI tokens target $\ge 3.5:1$ for accents).
  - Material contrast guards: Frost glass luminance guard and Liquid glass linear luminance blending ($L \le 0.09$ for light text, $L \ge 0.62$ for dark text).
  - Palette derivation: Minimum contrast floor enforcing `text >= 7:1`, `sub >= 4.5:1`, `faint >= 3:1`.
  - Design tokens: 7 type scale roles (`Hero` 40, `Title1` 22, `Title2` 17, `Headline` 14.5, `Body` 13.5, `Callout` 12.5, `Caption` 11); 3 concentric radii (`RadiusShell` 32, `RadiusModule` 20, `RadiusControl` 12); spacing tokens (`Sp4` through `Sp32`).

---

## 2. Logic Chain

1. **Premise 1**: The E2E test runner must run as an opaque box against the target binary `Tepi.exe` produced by `build.cmd`, without modifying internal production source code or adding third-party test framework dependencies (such as npm, Python, or NuGet packages).
2. **Premise 2**: `build.cmd` targets .NET Framework 4.8 x64 winexe. Windows 10/11 comes preinstalled with Windows PowerShell (`powershell.exe`) running CLR 4.0/4.8, which natively links with .NET Framework assemblies (`System.Drawing`, `System.Windows.Forms`).
3. **Premise 3**: Our empirical investigation (Observation 1.4) proved that Windows PowerShell can load `Tepi.exe` via `[System.Reflection.Assembly]::LoadFrom()`, access all internal types, call static/instance methods, evaluate color/contrast mathematics, inspect design tokens, and instantiate owner-drawn UI controls headlessly into memory bitmaps via `DrawToBitmap()`.
4. **Premise 4**: In addition, PowerShell can launch `Tepi.exe` as an external process to verify CLI argument handling (`--notify`, `--run`, `--statusline`), verify process exit codes, and verify mutex behavior.
5. **Premise 5**: The project requirements mandate testing 26 features across 4 distinct tiers:
   - Tier 1: Feature Coverage ($\ge 5$ tests per feature $\to \ge 130$ tests)
   - Tier 2: Boundary & Corner Cases ($\ge 5$ boundary tests per feature $\to \ge 130$ tests)
   - Tier 3: Cross-Feature Interactions ($\ge 26$ pairwise interaction tests)
   - Tier 4: Real-World Application Workloads ($\ge 13$ realistic workflow scenarios)
   Total minimum test count: $\ge 130 + 130 + 26 + 13 = 299$ ($\ge 300$ tests).
6. **Conclusion**: A pure PowerShell test architecture centered around `tests/run_e2e.ps1` with modular tier directories (`tests/tier1_features/`, `tests/tier2_boundaries/`, `tests/tier3_interactions/`, `tests/tier4_scenarios/`) and shared reflection/assertion helpers (`tests/common/`) is the optimal, zero-dependency, robust, and completely opaque-box test runner for Tepi.

---

## 3. Caveats

1. **Desktop Window Manager (DWM) Blur Shaders**:
   Windows layered window blur effects (`UpdateLayeredWindow` + DWM acrylic/glass backdrop sampling) require live desktop windowing and active screen capture. However, all internal glass computation functions (`FrostJob`, `Plate.Ensure`, `LiquidPass`, `BakePlate`, luminance calculations, and contrast guards) execute pure CPU byte-array and GDI+ bitmap manipulations and can be 100% verified headlessly via reflection.
2. **PowerShell Execution Policy & Bit Architecture**:
   `Tepi.exe` is compiled as `x64` (`/platform:x64`). When loading `Tepi.exe` via reflection in PowerShell, the test runner must run in 64-bit PowerShell (default on 64-bit Windows), not 32-bit `SysWOW64\powershell.exe`, to prevent `BadImageFormatException`. The test runner script should include an architecture check guard.
3. **Mutating Static State in Reflection**:
   Because `Ink.Apply`, `Ink.SetAccent`, and `KitInk` mutate static fields in the loaded `Tepi` assembly, each test tier or test suite execution should reset tokens to a baseline state (e.g. via a helper `Reset-TepiTheme`) to ensure test isolation and prevent cascading side-effects across test cases.

---

## 4. Conclusion & Recommended Test Architecture

### 4.1 Recommended File Structure for `tests/`
```
tests/
├── run_e2e.ps1                      # Master test runner CLI orchestrator
├── common/
│   ├── TestHarness.ps1              # Assertion engine (Assert-Equal, Assert-Contrast, Assert-True)
│   └── TepiLoader.ps1               # Binary loader, reflection helpers, theme reset utilities
├── tier1_features/                  # Tier 1: Feature Coverage (>=5 tests per feature, >=130 tests)
│   ├── test_f01_typography.ps1      # Feature 1: Font Family Typo Corrections
│   ├── test_f02_accents.ps1         # Feature 2: Light Mode Accent Preset Calibration
│   ├── test_f03_frost_guard.ps1     # Feature 3: Frost Glass Adaptive Contrast Guard
│   ├── test_f04_liquid_blend.ps1    # Feature 4: Liquid Glass Color Space Blending
│   ├── test_f05_palette_floor.ps1   # Feature 5: Custom Palette Contrast Floor
│   ├── test_f06_kitink_faint.ps1    # Feature 6: Elevate KitInk.Faint Light Contrast
│   ├── test_f07_kitbutton.ps1       # Feature 7: KitButton Interactive States & Focus Ring
│   ├── test_f08_kitswitch.ps1       # Feature 8: KitSwitch Hover State & Dynamics
│   ├── test_f09_kitslider.ps1       # Feature 9: KitSlider Disabled Thumb Contrast
│   ├── test_f10_kitrow.ps1          # Feature 10: KitRow.MarkGlyph Contrast Fix
│   ├── test_f11_menulook.ps1        # Feature 11: MenuLook Submenu & Disabled Contrast
│   ├── test_f12_semantic_red.ps1    # Feature 12: Eliminate Hardcoded Semantic Red
│   ├── test_f13_dialog_theme.ps1    # Feature 13: Centralized Dialog Theme Propagation
│   ├── test_f14_kitask.ps1          # Feature 14: KitAsk Universal Title & Localization
│   ├── test_f15_kulialogin.ps1      # Feature 15: KuliaLogin Tokenization & Modernization
│   ├── test_f16_colorpicker.ps1     # Feature 16: ColorPicker Loupe Token Alignment
│   ├── test_f17_island_glass.ps1    # Feature 17: Island OnGlass() Contrast Enforcement
│   ├── test_f18_island_shadow.ps1   # Feature 18: Island Pill Elevation Shadow on Glass
│   ├── test_f19_reduced_motion.ps1  # Feature 19: Island Approval Halo Reduced Motion
│   ├── test_f20_tabs_states.ps1     # Feature 20: Tabs Inverted Hover/Pressed Fill Fix
│   ├── test_f21_toast_collision.ps1 # Feature 21: Toast Notification Meta Text Collision
│   ├── test_f22_emptystate.ps1      # Feature 22: Standardize Empty State Component
│   ├── test_f23_scale_tokens.ps1    # Feature 23: Typography & Radius Scale Consolidation
│   ├── test_f24_dock_tokens.ps1     # Feature 24: Dock Hardcoded Colors Tokenization
│   ├── test_f25_dock_states.ps1     # Feature 25: Dock Module Interactive States
│   └── test_f26_mini_salience.ps1   # Feature 26: Mini Indicator Visual Salience
├── tier2_boundaries/                # Tier 2: Boundary & Corner Cases (>=5 tests per feature, >=130 tests)
│   ├── test_b01_font_fallbacks.ps1
│   ├── test_b02_accent_extremes.ps1
│   ├── test_b03_glass_extremes.ps1
│   ├── ...
│   └── test_b26_mini_extremes.ps1
├── tier3_interactions/              # Tier 3: Cross-Feature Interactions (>=26 tests)
│   ├── test_x01_theme_dialogs.ps1   # Theme toggle while dialogs are open
│   ├── test_x02_accent_glass.ps1    # Accent change with Glass Frost / Liquid
│   ├── ...
│   └── test_x26_palette_dock.ps1
└── tier4_scenarios/                 # Tier 4: Real-World Workloads (>=13 tests)
    ├── test_s01_onboarding_tour.ps1
    ├── test_s02_settings_customization.ps1
    ├── test_s03_task_management.ps1
    ├── ...
    └── test_s13_cli_notifications.ps1
```

### 4.2 Core Architecture of `run_e2e.ps1`
The master runner should support:
- `.\tests\run_e2e.ps1`: Runs all tiers (1-4).
- `.\tests\run_e2e.ps1 -Tier 1`: Runs specific tier.
- `.\tests\run_e2e.ps1 -Feature 2`: Runs all tests for Feature 2.
- `.\tests\run_e2e.ps1 -Rebuild`: Recompiles `Tepi.exe` using `build.cmd` before running.
- Clean formatted summary table displaying: Tier, Total Tests, Passed, Failed, Duration, and Overall Status.
- Exit code: `0` if all tests pass, `1` if any test fails.

### 4.3 Recommendations for Writing `TEST_INFRA.md`
1. **Document the 4 Testing Modalities**:
   - Modality A: *Mathematical & Contract Reflection* (`Island.Contrast`, `Island.DerivePalette`, `Ink.Mix`, `Luma`, `Linear`).
   - Modality B: *Design Token & Typography Registry* (`Ink.families`, `Tone` tokens, `KitInk` tokens, `Radius*` constants).
   - Modality C: *Headless WinForms Control Lifecycle & Offscreen Rendering* (`KitButton`, `KitSlider`, `KitSwitch`, `DrawToBitmap`, state transitions).
   - Modality D: *CLI & External Process Invocations* (`build.cmd`, `Tepi.exe --notify`, `--run`, `--statusline`, mutex concurrency).
2. **Specify Strict Assertion Criteria**:
   - Contrast assertions must use standard WCAG formula matching `Island.Contrast`.
   - Text contrast threshold: minimum `4.50:1`.
   - Non-text / accent threshold: minimum `3.50:1` in light mode against `#F5F5F5`.
   - Radius tokens: must match 32 (`RadiusShell`), 20 (`RadiusModule`), 12 (`RadiusControl`).
   - Font family typos: must verify `Segoe UI Variable Display Semibold` (not `Semib`) and `Segoe UI Variable Small Semibold` (not `Semibol`).
3. **Test Isolation Protocol**:
   - Require every test file to call `Reset-TepiTheme` in `beforeEach` to guarantee deterministic state.

---

## 5. Verification Method

To independently verify all findings and testability mechanisms in this report:

1. **Verify `build.cmd`**:
   ```powershell
   cmd.exe /c "build.cmd"
   # Verify output ends with "Build OK: ...\Tepi.exe" and exit code is 0.
   ```
2. **Verify Reflection Type Loading**:
   ```powershell
   Add-Type -AssemblyName System.Drawing
   Add-Type -AssemblyName System.Windows.Forms
   $asm = [System.Reflection.Assembly]::LoadFrom("d:\PROJECT\Other\tepi\Tepi.exe")
   Write-Host "Types loaded:" $asm.GetTypes().Length
   ```
3. **Verify Contrast Calculation via Reflection**:
   ```powershell
   $island = $asm.GetType('Tepi.Island')
   $contrast = $island.GetMethod('Contrast', [System.Reflection.BindingFlags]'Public,NonPublic,Static')
   $res = $contrast.Invoke($null, @([Drawing.Color]::Black, [Drawing.Color]::White))
   Write-Host "Black vs White Contrast:" $res # Expected: 21
   ```
4. **Verify Accent Preset Failures (Feature 2 Baseline)**:
   ```powershell
   $paper = [Drawing.ColorTranslator]::FromHtml('#F5F5F5')
   $blue = [Drawing.ColorTranslator]::FromHtml('#4C8DFF')
   $c = $contrast.Invoke($null, @($blue, $paper))
   Write-Host "Blue vs Paper Contrast:" $c # Expected: ~2.94:1 (< 3.5:1)
   ```
5. **Verify Headless Offscreen Rendering**:
   ```powershell
   $btn = [Activator]::CreateInstance($asm.GetType('Tepi.KitButton'))
   $btn.Text = "Verify"
   $bmp = New-Object System.Drawing.Bitmap 100, 30
   $btn.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle 0, 0, 100, 30))
   Write-Host "Bitmap rendered successfully:" $bmp.Width "x" $bmp.Height
   ```
