# Handoff Report: Settings Appearance, Theme Presets & Propagation Architecture

**Agent**: Explorer 3 (Milestone 2)  
**Date**: 2026-11-12T23:16:00Z  
**Parent Sub-Orchestrator**: `789fb24f-4dc5-451b-991c-640bde73cdc8`  
**Working Directory**: `d:\PROJECT\Other\tepi`  
**State Folder**: `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_3\`

---

## 1. Observation

1. **`src/Prefs.cs:179-191`**: `Accents` and `AccentsLight` define 9 preset rows:
   ```csharp
   static readonly string[][] Accents =
   {
       new[] { "Monokrom", "" }, new[] { "Biru", "#4C8DFF" }, new[] { "Hijau", "#3DD68C" }, new[] { "Kuning", "#FFD24A" },
       new[] { "Oranye", "#FF9F43" }, new[] { "Merah muda", "#FF6B9A" }, new[] { "Ungu", "#A78BFA" }, new[] { "Navy", "#7F8DC6" },
       new[] { "Dari sampul album", AccentAlbum },
   };
   ```
   The presets omit Red, and they are rendered in `PrefsWindow` via a plain dropdown combobox:
   `accentPick = Popup(names.ToArray(), at, i => island.SetAccentHex(activeAccents[i][1]));` (`src/Prefs.cs:1092`).
2. **`src/Prefs.cs:58-69`**: In `ApplyThemeMode()`:
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
   Only `prefs` and `chatWin` are checked. Any other active modal or utility window (`TaskEditor`, `WorkWindow`, `KuliaLogin`, `FeedbackWindow`, etc.) is completely ignored on theme change.
3. **`src/Prefs.cs:71-81`**: In `SetAccentHex(string hex)`:
   ```csharp
   void SetAccentHex(string hex)
   {
       settings.Set("accent", hex);
       settings.Save();
       Ink.SetAccent(hex);
       albumAccentFor = null;
       albumTinted = false;
       AlbumAccent();
       WallApply();
       Kick();
   }
   ```
   When accent color is updated, neither `prefs.Relayout()` nor any dialog update is performed.
4. **`src/Kit.cs:613-710`**: `KitWindow : Form` is the base class for all standard dialogs (`AgentPromptBox`, `FeedbackWindow`, `KitAsk`, `NoteBox`, `PrefsWindow`, `WordsWindow`, `PrompterSetup`, `RedactWindow`, `ChatWindow`, `TaskEditor`, `TourCard`, `WhatsNewWindow`, `WorkWindow`, and M2 `KuliaLogin`). It exposes `public virtual void Relayout() { }` and controls caption bar dark mode via `Native.DarkFrame(Handle, !Ink.Light);`. Currently, `KitWindow` has no static registry or theme change broadcast method.
5. **`src/SettingsIO.cs:16-17`**:
   `"theme"` and `"accent"` are explicitly members of `Portable = new HashSet<string>(StringComparer.OrdinalIgnoreCase)`, ensuring reliable serialization and round-trip restore.

---

## 2. Logic Chain

1. **Preset Modernization (Observation 1)**:
   - macOS appearance settings present curated accents as an inline horizontal row of color circle swatches with concentric selection rings, rather than a text combobox.
   - Introducing `KitPalette : KitControl` (drawing 8 curated presets: Blue, Purple, Pink, Red, Orange, Yellow, Green, Graphite) provides immediate visual affordance and single-click selection.
   - Incorporating Red (`#FF5252` dark, `#C5221F` light) completes the standard macOS palette while maintaining 5.83:1 contrast against `#F5F5F5`.
2. **Theme Broadcast Architecture (Observations 2, 4)**:
   - Because all major dialogs inherit from `KitWindow` and implement `Relayout()`, registering open windows in `KitWindow` via weak references (with an `Application.OpenForms` fallback) enables centralized theme propagation.
   - Implementing `KitWindow.BroadcastThemeChange()` ensures that when `ApplyThemeMode` is called, every open window receives:
     1. Caption bar update: `Native.DarkFrame(w.Handle, !Ink.Light)`
     2. Base colors update: `w.BackColor = KitInk.Window; w.ForeColor = KitInk.Text;`
     3. Component relayout: `w.Relayout()`
     4. Visual invalidation: `w.Invalidate(true)`
3. **Accent Change Propagation (Observation 3)**:
   - Invoking `KitWindow.BroadcastThemeChange()` inside `SetAccentHex()`, `RefreshColors()`, and `ApplyPack()` guarantees that accent changes immediately reflect across all active dialogs (primary buttons, checkmarks, stars, icons) without app restart.

---

## 3. Caveats

1. **`KuliaLogin` Refactoring Dependency**:
   - `KuliaLogin` currently inherits directly from `Form` (`src/Kulia.cs:339`). In Milestone 2, it is being refactored to inherit from `KitWindow`. `BroadcastThemeChange()` will automatically pick up `KuliaLogin` once this refactoring is applied by the Worker.
2. **Transient Overlays**:
   - `PickerOverlay` (`src/ColorPicker.cs:32`) is a short-lived full-screen capture canvas and intentionally inherits from `Form` rather than `KitWindow`; it does not require theme change broadcasting.
3. **No Caveats Beyond Above**.

---

## 4. Conclusion

1. **`src/Prefs.cs` Appearance Redesign**:
   - Replace the combobox popup in `case "look"` with `KitPalette` displaying 8 curated presets:
     - Blue (`#4C8DFF` / `#1668E8`)
     - Purple (`#A78BFA` / `#6C3CE0`)
     - Pink (`#FF6B9A` / `#C2185B`)
     - Red (`#FF5252` / `#C5221F`)
     - Orange (`#FF9F43` / `#A84B00`)
     - Yellow (`#FFD24A` / `#855E00`)
     - Green (`#3DD68C` / `#107C41`)
     - Graphite (`""`)
   - Maintain 3-state segmented controls for Theme (`[ Gelap | Terang | Otomatis ]`) and Material (`[ Liquid | Frost | Hitam ]`).
   - Group settings cleanly under "Gaya visual" and "Kustomisasi" (`look.custom`).
2. **`KitWindow.BroadcastThemeChange()`**:
   - Implement `KitWindow.BroadcastThemeChange()` in `src/Kit.cs` using weak references and `Application.OpenForms`.
   - Wire `KitWindow.BroadcastThemeChange()` into:
     - `Island.ApplyThemeMode()` (`src/Prefs.cs:68`)
     - `Island.SetAccentHex()` (`src/Prefs.cs:79`)
     - `Island.RefreshColors()` (`src/Colors.cs:64`)
     - `Island.ApplyPack()` (`src/Theme.cs:314`)
     - `WallSync.cs` line 144 (when wallpaper accent changes).

---

## 5. Verification Method

1. **Codebase Inspection**:
   - Inspect `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m2_3\analysis.md` for exact line-by-line diffs and component code.
2. **Compilation**:
   - Run `build.cmd` from project root; verify exit code 0 (`Tepi.exe` generated cleanly).
3. **Functional Theme & Accent Broadcast Test**:
   - Launch `Tepi.exe`.
   - Open Settings (`PrefsWindow`), open Task Editor (`TaskEditor`), and open Work & Notes (`WorkWindow`).
   - In Settings > Tampilan, click the "Merah" accent swatch.
   - Verify that:
     1. The active ring wraps the red swatch.
     2. The "Warna aksen" detail text reads "Merah".
     3. The Save button in `TaskEditor` immediately turns red.
     4. Checkmarks and stars in `WorkWindow` immediately turn red.
     5. The Island HUD indicator turns red.
   - In Settings > Tampilan, switch Theme from "Gelap" to "Terang".
   - Verify that:
     1. Settings window, `TaskEditor`, and `WorkWindow` caption bars transition to light mode.
     2. Window backgrounds turn to `#F5F5F5` (`KitInk.Window`).
     3. Red accent transitions to calibrated light mode `#C5221F` (5.83:1 contrast).
   - Close and restart `Tepi.exe`; verify that theme mode and accent color are restored accurately.
