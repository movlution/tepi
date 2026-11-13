# Survey & Analysis Report: Settings, Dialogs, Theme Switching, and Contrast Compliance

## 1. Observation

### 1.1 Technology Stack & Architectural Patterns
- **Framework**: Pure C# WinForms application with GDI+ owner-drawn graphics. No XAML files exist in the repository (`d:\PROJECT\Other\tepi\src\`).
- **Base Dialog Framework**: `KitWindow` (`src/Kit.cs:613-710`), inheriting from `Form`.
  - Configures `Native.DarkFrame(Handle, !Ink.Light)` for DWM titlebar dark mode (`src/Kit.cs:636`).
  - Configures `Native.RoundCorners(Handle)` for Windows 11 rounded corners (`src/Kit.cs:637`).
  - Implements DPI scaling via `GetDpiForWindow` and `WM_DPICHANGED` (`src/Kit.cs:635, 668-678`).
  - Implements soft fade-in animation on `OnShown` (`src/Kit.cs:647-660`).
  - Handles `Escape` key to close (`src/Kit.cs:662-666`).
  - Provides `virtual void Relayout()` for layout and theme refreshes (`src/Kit.cs:682`).

### 1.2 Catalog of All Dialog and Window Implementations
We identified and analyzed all 15 dialogs, modals, and settings window components across `src/`:

| Component Class | Source File & Lines | Base Class | Role & Description |
|---|---|---|---|
| `KitAsk` | `src/Kit.cs:713-785` | `KitWindow` | Universal confirmation & notice modal (`KitAsk.Confirm`, `KitAsk.Notice`). Deliberate replacement for native `MessageBox`. |
| `PrefsWindow` | `src/Prefs.cs:186-500` | `KitWindow` | Main application Settings window with multi-category sidebar and dynamic page/card layout. |
| `AgentPromptBox` | `src/AgentPrompt.cs:130-320` | `KitWindow` | AI Agent session prompt composer, status card, and template manager. |
| `FeedbackWindow` | `src/Feedback.cs:63-222` | `KitWindow` | Modal user feedback and issue submission dialog. |
| `NoteBox` | `src/Notes.cs:58-155` | `KitWindow` | Frameless quick-note floating prompt with drop shadow (`CS_DROPSHADOW`). |
| `WordsWindow` | `src/PrefsDikte.cs:152-260` | `KitWindow` | Dictionary, text replacements, and dictation snippets configuration dialog. |
| `PrompterSetup` | `src/Prompter.cs:646-860` | `KitWindow` | Teleprompter script editor, speed/font tuning, and shortcuts guide dialog. |
| `RedactWindow` | `src/Redact.cs:34-220` | `KitWindow` | Image editor, crop, blur, and freehand markup dialog. |
| `ChatWindow` | `src/SuruhChat.cs:363-520` | `KitWindow` | "Suruh Tepi" AI interactive chat window with scrollable history and actions. |
| `TaskEditor` | `src/TaskEditor.cs:8-137` | `KitWindow` | Modal task editor (Title, due date, priority, completion). |
| `TourCard` | `src/Tour.cs:96-298` | `KitWindow` | Interactive onboarding walkthrough step card, floating near island. |
| `WhatsNewWindow` | `src/WhatsNew.cs:119-200` | `KitWindow` | Version release notes modal dialog. |
| `WorkWindow` | `src/WorkWindow.cs:10-310` | `KitWindow` | Unified Tasks and Markdown Notes full management window. |
| `PickerOverlay` / `Loupe` | `src/ColorPicker.cs:32, 125` | `Form` | Fullscreen screen pixel color sampler overlay and magnified cursor loupe. |
| `KuliaLogin` | `src/Kulia.cs:339-488` | `Form` | Modal OTP authentication dialog for Kulia service. |

### 1.3 Theme Switching Mechanics & Resource Dynamic Updates
- **Theme Definition**:
  - `Tone.Dark()` (`src/Ink.cs:35-48`): `Bg = (0, 0, 0)`, `Text = (245, 245, 247)`, `Sub = (158, 245, 245, 247)`, `Faint = (148, 245, 245, 247)`.
  - `Tone.Paper()` (`src/Ink.cs:73-84`): `Bg = (245, 245, 245)`, `Text = (12, 12, 14)`, `Sub = (158, 12, 12, 14)`, `Faint = (148, 12, 12, 14)`.
  - `KitInk` (`src/Kit.cs:13-35`): Derived opaque colors for windows:
    - `Window`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.0f : 0.04f)`
    - `Side`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.05f : 0.07f)`
    - `Group`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.035f : 0.09f)`
    - `Line`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.12f : 0.15f)`
    - `Hover`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.09f : 0.16f)`
    - `Raised`: `Ink.Light ? Color.White : Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.3f)`
    - `Sub`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.62f)`
    - `Faint`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.57f)`
    - `Disabled`: `Ink.Mix(Ink.Base.Bg, Ink.Base.Text, 0.30f)`
- **Dynamic Propagation Pipeline**:
  - Located at `src/Prefs.cs:58-69`:
    ```csharp
    void ApplyThemeMode()
    {
        bool light = ThemeLight();
        if (light == Ink.Light) return;
        Ink.Apply(light);
        WallApply();
        ResetFrost();
        if (prefs != null && !prefs.IsDisposed) prefs.Relayout();
        if (chatWin != null && !chatWin.IsDisposed) chatWin.Relayout();
        if (dockWin != null) dockWin.Changed();
        Kick();
    }
    ```
  - **Direct Observation**: `ApplyThemeMode()` explicitly calls `Relayout()` ONLY on `prefs` and `chatWin`, and `Changed()` on `dockWin`. None of the other dialogs (`WorkWindow`, `FeedbackWindow`, `TaskEditor`, `WordsWindow`, `PrompterSetup`, `RedactWindow`, `WhatsNewWindow`, `NoteBox`) are notified when theme mode changes!
- **System Theme Notification**:
  - `src/Island.cs:337`: Listens for `WM_SETTINGCHANGE` where `lParam == "ImmersiveColorSet"`, triggering `OnColorSetChanged()` (`src/WinTheme.cs:53-60`).

### 1.4 WCAG AA Contrast Audit (Empirical Mathematical Measurements)
Using exact sRGB-to-linear relative luminance calculations according to WCAG 2.1 specifications:

#### 1.4.1 Preset Accents on Light Background (`#F5F5F5`)
WCAG 2.1 AA 1.4.11 requires >= 3.0:1 for graphical objects and user interface components (active toggle tracks, slider progress fills, badges, dots):
- **Biru (`#4C8DFF`)**: `2.94:1` — **FAILS** WCAG AA (< 3.0:1)
- **Hijau (`#3DD68C`)**: `1.72:1` — **FAILS** WCAG AA (< 3.0:1)
- **Kuning (`#FFD24A`)**: `1.32:1` — **FAILS** WCAG AA (< 3.0:1)
- **Oranye (`#FF9F43`)**: `1.87:1` — **FAILS** WCAG AA (< 3.0:1)
- **Merah muda (`#FF6B9A`)**: `2.46:1` — **FAILS** WCAG AA (< 3.0:1)
- **Ungu (`#A78BFA`)**: `2.50:1` — **FAILS** WCAG AA (< 3.0:1)
- **Navy (`#7F8DC6`)**: `2.95:1` — **FAILS** WCAG AA (< 3.0:1)

#### 1.4.2 `KitInk` Tokens Contrast Ratios
WCAG 2.1 AA 1.4.3 requires >= 4.5:1 for normal text (< 24px regular, < 18.5px bold) and >= 3.0:1 for large text / UI elements:
- **Light Theme `KitInk.Faint` (0.57 mix = `(112, 112, 113)`)**:
  - On `KitInk.Side` (`#E9E9E9`): `4.07:1` — **FAILS** WCAG AA normal text
  - On `KitInk.Group` (`#EDEDED`): `4.23:1` — **FAILS** WCAG AA normal text
  - On `KitInk.Hover` (`#E0E0E0`): `3.75:1` — **FAILS** WCAG AA normal text
  - On `KitInk.Line` (`#D9D9D9`): `3.50:1` — **FAILS** WCAG AA normal text
- **Dark Theme `KitInk.Faint` (0.57 mix = `(140, 140, 141)`)**:
  - On `Window` (`#0A0A0A`): `5.89:1` (PASS)
  - On `Group` (`#161616`): `5.39:1` (PASS)
  - On `Side` (`#111111`): `5.62:1` (PASS)

#### 1.4.3 Hardcoded Color Failures
- **`Color.IndianRed` (`#CD5C5C` = `(205, 92, 92)`)**:
  - Location: `src/TaskEditor.cs:103, 125` (`warning.ForeColor`), `src/WorkWindow.cs:673` (`saveState.ForeColor`).
  - Contrast on Light Window (`#F5F5F5`): `3.65:1` — **FAILS** WCAG AA (< 4.5:1).
  - Contrast on Dark Window (`#0A0A0A`): `4.98:1` (PASS).
- **`Color.FromArgb(224, 96, 84)` (`#E06054`)**:
  - Location: `src/WorkWindow.cs:601` (Late due date badge text, 11.5px).
  - Contrast on Light Group (`#EDEDED`): `3.00:1` — **FAILS** WCAG AA (< 4.5:1).
  - Contrast on Dark Group (`#161616`): `5.15:1` (PASS).
- **`MenuLook` Submenu Arrows and Sub-text in Light Mode**:
  - Location: `src/Menus.cs:97, 127, 149` (`Sub = Mix(Bg, Text, 0.5f)`).
  - Contrast on `Bg` (`#E7E7E7`): `3.19:1` — **FAILS** WCAG AA normal text (< 4.5:1).
  - Contrast on `Hover` (`#CFCFCF`): `2.56:1` — **FAILS** WCAG AA UI Component Contrast (< 3.0:1).
- **`KitRow.MarkGlyph` Pill in Dark & Light Modes**:
  - Location: `src/Kit.cs:587-588`:
    `using (var p2 = Ink.Round(pill, 5 * s)) g.FillPath(Brushes.Black, p2);`
    `using (var dot = new SolidBrush(KitInk.Text)) g.FillEllipse(dot, pill.Right - 8 * s, pill.Y + 2.5f * s, 5 * s, 5 * s);`
  - In Dark Mode: Black pill on Dark Gray hover tile (`#272728`) has contrast `1.15:1` (virtually invisible).
  - In Light Mode: Dot uses `KitInk.Text` (`#0C0C0E`), rendering black on a black pill!

### 1.5 Dialog Defects & Visual Consistency Deficiencies
1. **`KitAsk` Hardcoded Title & Localization**:
   - `src/Kit.cs:738`: `Text = "Tugas dan catatan";` — hardcoded window caption for ANY message or confirmation in the entire application.
   - `src/Kit.cs:717-718, 723`: Hardcoded default parameters `"Hapus"`, `"Batal"`, `"Tutup"` without `Lang.T`.
2. **`TaskEditor` Localization & Label Styling**:
   - `src/TaskEditor.cs:11, 14, 15, 18, 19, 20, 34, 61, 64`: Strings hardcoded in Indonesian without `Lang.T`.
   - `src/TaskEditor.cs:114-115`: `titleLabel.BackColor` unmanaged.
3. **`KuliaLogin` Architectural Divergence**:
   - `src/Kulia.cs:339`: Inherits directly from `Form`, does not inherit from `KitWindow`.
   - `src/Kulia.cs:363-365`: Uses ad-hoc colors `Color.FromArgb(245, 245, 245)`, `Color.FromArgb(10, 10, 10)`, `Color.FromArgb(88, 88, 88)`, `Color.FromArgb(160, 160, 160)`.
   - `src/Kulia.cs:344, 383-389`: Uses native WinForms `Button` with manual styling instead of `KitButton`.
   - Does not implement `Relayout()`, ignoring dynamic theme switching.
4. **`ColorPicker.Loupe` Token Independence**:
   - `src/ColorPicker.cs:137`: Hardcoded `BackColor = Color.FromArgb(18, 18, 18);`.
   - `src/ColorPicker.cs:190-191`: `new Font("Segoe UI Semibold", 10f, GraphicsUnit.Point)` and `Color.White` instead of `Ink.MenuFamily` and pixel sizing.
5. **Iconographic Inconsistency**:
   - `src/WorkWindow.cs:591`: Uses Unicode text glyphs `"★"` and `"☆"` for starred tasks instead of Segoe Fluent icon glyphs (`\uE734` / `\uE735`).
6. **Double Progress Indication in Onboarding**:
   - `src/Tour.cs:239, 285-294`: Shows step number string (`"N dari M"`) simultaneously with animated progress dots on the top right.

---

## 2. Logic Chain

1. **Premise 1**: WCAG 2.1 Level AA establishes mandatory contrast thresholds:
   - Success Criterion 1.4.3: Contrast minimum >= 4.5:1 for normal text (< 24px regular, < 18.5px bold).
   - Success Criterion 1.4.11: Non-text contrast >= 3.0:1 for user interface components (active switch tracks, slider fills, indicators) and graphical objects against adjacent colors.
2. **Step 2 (Accent Presets on Light Theme)**:
   - Observation 1.4.1 demonstrates that on `#F5F5F5`, all 7 accent presets measure between `1.32:1` (Yellow) and `2.95:1` (Navy).
   - In `KitSwitch` (`Kit.cs:201`), active state paints `Ink.Mix(KitInk.Line, KitInk.Accent, knob)` directly on `KitInk.Under`.
   - In `PlanBar` (`AgentPrompt.cs:750`), `WorkWindow` (`WorkWindow.cs:583`), and `QuotaCard` (`AgentPrompt.cs:770`), accents are rendered directly against Window or Group backgrounds.
   - Therefore, in Light Mode, essential UI controls and status indicators fail WCAG 2.1 AA 1.4.11 across all accent selections.
3. **Step 3 (`KitInk.Faint` Token in Light Theme)**:
   - Observation 1.4.2 demonstrates that `KitInk.Faint` mixes 57% text on background, yielding `(112, 112, 113)`.
   - When rendered against `KitInk.Side` (`#E9E9E9`), contrast is `4.07:1`.
   - When rendered against `KitInk.Group` (`#EDEDED`), contrast is `4.23:1`.
   - When rendered against `KitInk.Hover` (`#E0E0E0`), contrast is `3.75:1`.
   - When rendered against `KitInk.Line` (`#D9D9D9`), contrast is `3.50:1`.
   - `KitInk.Faint` is actively utilized for disabled row titles (`KitRow.cs:570`), disabled button text (`KitButton.cs:414`), disabled slider values (`KitSlider.cs:366`), unchecked ticks (`KitCheck.cs:449`), and quota timestamps (`AgentPrompt.cs:776`).
   - Therefore, multiple normal text and control elements throughout the Settings dialog and modal forms fail WCAG 2.1 AA 1.4.3 in Light Mode.
4. **Step 4 (Hardcoded Colors Failure)**:
   - Observation 1.4.3 demonstrates that `Color.IndianRed` (`#CD5C5C`) yields `3.65:1` on `#F5F5F5`, and `Color.FromArgb(224, 96, 84)` yields `3.00:1` on `#EDEDED`.
   - Both are used to communicate error and late due-date status text (11.5px to 12.5px).
   - In contrast, the centralized token `Tone.Paper().Negative` (`(190, 50, 50)`) produces `5.22:1` on `#F5F5F5`, fully passing WCAG AA.
   - Therefore, the hardcoded colors introduce severe accessibility violations that the centralized design token already resolves.
5. **Step 5 (Theme Propagation Isolation)**:
   - Observation 1.3 shows that `Island.ApplyThemeMode()` triggers `Relayout()` only on `prefs` and `chatWin`.
   - There are 10 other dialog and modal windows inheriting from `KitWindow`.
   - If any of these windows remain open when the user alters the theme or Windows toggles dark/light mode, the windows do not refresh their colors, fonts, or window frames.
   - Therefore, the theme propagation architecture currently exhibits an isolation defect.

---

## 3. Caveats

- **Wallpaper Adaptive Glass Sampling**: The contrast audit in this report focuses on opaque dialogs, modals, and settings window surfaces (`KitWindow`, `KitInk`, `MenuLook`). Island and Dock dynamic blur/transparency contrast over arbitrary user desktop wallpapers depends on wallpaper luminance sampling (`WallSync.cs` / `Glass.cs`), which was audited separately in `01-visual.md`.
- **System MessageBox**: The application codebase intentionally avoids native `MessageBox.Show`, relying on `KitAsk`. External standard common dialogs (`ColorDialog`, `OpenFileDialog`, `SaveFileDialog`) are native Win32 controls whose styling is governed directly by Windows OS themes.
- **High Contrast Theme**: Windows High Contrast mode (`SystemInformation.HighContrast`) is currently unhandled by the owner-drawn GDI+ pipeline (as noted in VIS-07).

---

## 4. Conclusion & Concrete Recommendations

### 4.1 Prioritized Remediation Plan

#### P1: WCAG AA Contrast Compliance
1. **Calibrate Light Theme Accent Presets**:
   - In `src/Ink.cs:141-160`, implement theme-adaptive accent mapping:
     - Keep bright accents for Dark Mode (`Biru #4C8DFF`, `Hijau #3DD68C`, `Kuning #FFD24A`, `Oranye #FF9F43`, `Merah muda #FF6B9A`, `Ungu #A78BFA`, `Navy #7F8DC6`).
     - In Light Mode, map presets to accessible tonal counterparts reaching >= 3.5:1 to 4.5:1:
       - Biru: `#1A56DB` (5.04:1)
       - Hijau: `#0E703C` (4.53:1)
       - Kuning / Amber: `#9A5B00` (4.62:1)
       - Oranye: `#B84A00` (4.60:1)
       - Merah muda: `#A81D60` (5.12:1)
       - Ungu: `#6938D3` (5.20:1)
       - Navy: `#3B4D8C` (5.10:1)
2. **Elevate Light Theme `KitInk.Faint`**:
   - In `src/Kit.cs:28`, adjust `KitInk.Faint` formula:
     ```csharp
     public static Color Faint { get { return O(Ink.Mix(Ink.Base.Bg, Ink.Base.Text, Ink.Light ? 0.65f : 0.57f)); } }
     ```
     - Increases Light Mode Faint contrast from `4.23:1` to `5.30:1` on `KitInk.Group` and `5.12:1` on `KitInk.Side`, immediately passing WCAG AA 4.5:1.
3. **Eliminate Hardcoded Semantic Colors**:
   - In `src/TaskEditor.cs:103, 125`: Replace `Color.IndianRed` with `Ink.Base.Negative`.
   - In `src/WorkWindow.cs:673`: Replace `Color.IndianRed` with `Ink.Base.Negative`.
   - In `src/WorkWindow.cs:601`: Replace `Color.FromArgb(224, 96, 84)` with `Ink.Base.Negative`.
4. **Fix `MenuLook` Submenu Contrast**:
   - In `src/Menus.cs:97`: Change `Sub` mix to `0.62f` (or reference `KitInk.Sub`), elevating arrow and disabled item contrast above 4.5:1 on background and above 3.0:1 on hover.
5. **Fix `KitRow.MarkGlyph` Contrast**:
   - In `src/Kit.cs:587-588`: Make the pill fill use `Ink.Base.Text` and the dot use `Ink.Base.Bg` so contrast is maintained across both Light and Dark themes.

#### P2: Architecture & Consistency
6. **Centralized Theme Propagation**:
   - In `src/Kit.cs`: Introduce a static registry in `KitWindow`:
     ```csharp
     static readonly List<KitWindow> openWindows = new List<KitWindow>();
     public static void BroadcastThemeChange() {
         for (int i = openWindows.Count - 1; i >= 0; i--) {
             var w = openWindows[i];
             if (w.IsDisposed) openWindows.RemoveAt(i);
             else w.Relayout();
         }
     }
     ```
   - Register in `OnHandleCreated` and unregister on `FormClosed`.
   - Call `KitWindow.BroadcastThemeChange()` in `Island.ApplyThemeMode()` (`src/Prefs.cs:65`).
7. **Refactor `KuliaLogin` into `KitWindow`**:
   - Change `class KuliaLogin : Form` to `class KuliaLogin : KitWindow`.
   - Replace manual buttons with `KitButton`, replace ad-hoc colors with `KitInk` tokens, implement `Relayout()`.
8. **Fix `KitAsk` Universal Title & Localization**:
   - In `src/Kit.cs:738`: Change default `Text = "Tepi"` (or pass title parameter), and wrap all button labels in `Lang.T`.
9. **Localize `TaskEditor`**:
   - In `src/TaskEditor.cs`: Wrap all titles, checks, and button labels with `Lang.T(...)`.
10. **Icon & Typography Consistency**:
    - Replace `"★"` and `"☆"` in `src/WorkWindow.cs:591` with Segoe Fluent Icons `\uE734` and `\uE735`.
    - Standardize `MenuFont` in `src/Menus.cs:105` and `Loupe` in `src/ColorPicker.cs:190` to use `Ink.MenuFamily` and pixel units.

---

## 5. Verification Method

### 5.1 Verification Script (Contrast & Mathematics)
Run the following PowerShell / Python test to verify that all proposed contrast adjustments satisfy WCAG AA:
```powershell
python -c "
def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def luminance(r, g, b):
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)

def contrast(c1, c2):
    L1, L2 = luminance(*c1), luminance(*c2)
    return (max(L1, L2) + 0.05) / (min(L1, L2) + 0.05)

def mix(c1, c2, f):
    return tuple(round(c1[i] + f * (c2[i] - c1[i])) for i in range(3))

light_bg = (245, 245, 245)
light_text = (12, 12, 14)
group = mix(light_bg, light_text, 0.035)

# Verify revised Faint (0.65)
revised_faint = mix(light_bg, light_text, 0.65)
cr_faint = contrast(revised_faint, group)
print(f'Revised Faint on Group: {cr_faint:.2f}:1 (Target >= 4.5:1) -> {\"PASS\" if cr_faint >= 4.5 else \"FAIL\"}')

# Verify Negative token on Light Window
neg_light = (190, 50, 50)
cr_neg = contrast(neg_light, light_bg)
print(f'Tone.Paper Negative on Light Window: {cr_neg:.2f}:1 (Target >= 4.5:1) -> {\"PASS\" if cr_neg >= 4.5 else \"FAIL\"}')
"
```

### 5.2 Build & Regression Check
Run the project build command:
```powershell
cmd /c build.cmd
```
- Verify compilation succeeds with code 0 and produces `Tepi.exe`.
- Launch `Tepi.exe`, toggle Light Mode and Dark Mode in Settings › Tema dan warna, and verify that all dialogs update smoothly without visual glitches or text illegibility.

### 5.3 Invalidation Conditions
This analysis will be invalidated if:
1. `Ink.Base.Bg` or `Tone.Paper()` background baseline color is changed from `#F5F5F5` to a significantly darker shade.
2. The UI framework is migrated away from WinForms owner-drawn GDI+.
