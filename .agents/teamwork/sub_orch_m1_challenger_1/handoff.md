# Handoff Report: Milestone 1 Adversarial Review & Empirical Challenge

**Challenger**: Challenger 1 (`sub_orch_m1_challenger_1`)  
**Parent Conversation ID**: `2e923bc6-0cc8-4584-9a2a-480dec472f3b`  
**Milestone**: Milestone 1 - Design Token Core, Glass Contrast & Color Science  
**Date**: 2026-11-12T19:00:00Z  
**Verdict**: **`REQUEST_CHANGES`**

---

## 1. Observation

### Build Verification
Ran compilation command:
```cmd
cmd /c build.cmd
```
Verbatim output:
```
Build OK: D:\PROJECT\Other\tepi\Tepi.exe
```
Exit code: 0.

### Automated Test Suites Executed
1. **Adversarial Test Harness**: `tests\adversarial\adversarial_m1.ps1`
   - Command: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\adversarial\adversarial_m1.ps1`
   - Output highlights:
     - `P01 [Identical #808080]`: `text=#000000` (CR=5.32:1), `sub=#161616` (CR=4.58:1), `faint=#303030` (CR=3.34:1), `accent=#292929` (CR=3.68:1), `onAccent=#FFFFFF` (CR=14.55:1) -> PASS
     - `P02 [Low Dark #202020]`: `text=#ADADAD` (CR=7.26:1), `sub=#8B8B8B` (CR=4.78:1), `accent=#777777` (CR=3.64:1) -> PASS
     - `P03 [Zero Lum #000000]`: `text=#9F9F9F` (CR=7.93:1), `sub=#797979` (CR=4.82:1), `accent=#7A7A7A` (CR=4.89:1) -> PASS
     - `P04 [Pastels on White]`: All text CR $\ge 7.06:1$, sub CR $\ge 5.15:1$, accent CR $\ge 3.74:1$, onAccent CR $\ge 4.5:1$ -> PASS
     - `P05 [Worst-Case Luminance #757575..#787878]`: text CR $\ge 4.61:1$, sub CR $\ge 4.51:1$, accent CR $\ge 3.63:1$, onAccent CR $\ge 4.5:1$ -> PASS
     - `P06 [Preset Accents in Light & Dark]`: All 7 presets (Biru, Hijau, Kuning, Oranye, Merah muda, Ungu, Navy) achieve accent CR $4.61:1$–$5.73:1$ in light mode and $6.53:1$–$14.57:1$ in dark mode, onAccent CR $\ge 4.81:1$ in light mode and $\ge 6.15:1$ in dark mode -> PASS
     - `P07 [Custom Accent #00FFFF Light]`:
       ```
       P07 [Custom Accent #00FFFF Light]: Final Accent=#008585 (CR=4.1), OnAccent=#0A0A0A (CR=4.43)
       [FAIL] P07: Stress-tests Ink.SetAccent with arbitrary and adversarial inputs in Light Mode (26.08ms)
              Error: Assert-True failed. Expected $true, but got: [False]. Context: OnAccent on custom accent #00FFFF must achieve >= 4.5:1 (actual: 4.42507654098022)
       ```
     - `P08 [Tone.OnGlass Contract]`: Sub Alpha = 189 in both Light and Dark modes -> PASS
     - `P09 [Fuzzing 1,000 Random Inputs]`: Worst Text CR=4.58:1, Worst Sub CR=4.50:1, Worst Accent CR=3.50:1, Worst OnAccent CR=4.58:1, Violations = 0 -> PASS
     - `P10 [Ink.SetPack Degenerate Input Safety]`: Null, empty, and malformed dictionaries handled safely without exceptions -> PASS

2. **50,000-Sample Monte Carlo Stress Fuzzer for `Colors.DerivePalette`**:
   - Tested 50,000 random RGB triplets `(bg, text, accent)` against `DerivePalette` logic.
   - Result: **0 violations** across all 10 palette token contrast floors.

3. **Code Inspection of Vulnerable Regions in `src/Ink.cs`**:
   - Lines 206–214:
     ```csharp
     if (light && Island.Contrast(c, Base.Bg) < 3.5)
         c = Island.EnforceContrast(c, Base.Bg, 3.5);
     Base.Accent = Base.Progress = c;
     // Ink on the accent: pick whichever actually wins on WCAG contrast,
     // not a luma guess. Blue and navy presets used to land at ~3.07:1.
     var darkInk = Color.FromArgb(255, 10, 10, 10);
     var lightInk = Color.FromArgb(255, 250, 250, 250);
     Base.OnAccent = Island.Contrast(c, darkInk) >= Island.Contrast(c, lightInk) ? darkInk : lightInk;
     ```

---

## 2. Logic Chain

1. **Robustness of `Colors.DerivePalette`**:
   - In `src/Colors.cs:83-135`, `EnforceContrast` is applied systematically to `text`, `sub`, `faint`, `accent`, `onAccent`, and all card tokens.
   - For any background in sRGB, the minimum attainable maximum contrast (between pure black and pure white) occurs at $L_{bg} \approx 0.1791288$, where $\max(C_{black}, C_{white}) \ge 4.58257:1 > 4.5:1$.
   - Because `Colors.DerivePalette` uses pure endpoints `Color.White` (`#FFFFFF`) and `Color.FromArgb(255,0,0,0)` and calls `EnforceContrast(onAccent, accent, 4.5)`, every token is mathematically guaranteed to meet its contrast floor. 50,000 empirical fuzzed inputs confirmed zero failures.

2. **Vulnerability 1 — Sub-4.5:1 `OnAccent` Dead-Zone in `Ink.Apply`**:
   - In `src/Ink.cs:211-213`, `Base.OnAccent` is chosen strictly between `darkInk = Color.FromArgb(255, 10, 10, 10)` ($L \approx 0.003035$) and `lightInk = Color.FromArgb(255, 250, 250, 250)` ($L \approx 0.955973$).
   - Solving for when contrast is $< 4.5:1$ against `darkInk`: $L_c < 4.5 \times (0.003035 + 0.05) - 0.05 = 0.188659$.
   - Solving for when contrast is $< 4.5:1$ against `lightInk`: $L_c > (0.955973 + 0.05) / 4.5 - 0.05 = 0.173550$.
   - **Vulnerability gap**: For any accent color whose luminance $L_c \in [0.173550, 0.188659]$, neither `darkInk` nor `lightInk` can achieve 4.5:1 contrast.
   - When a user or dynamic source selects custom accent `#00FFFF` in light mode, `EnforceContrast(c, Base.Bg, 3.5)` clamps it to `#008585` ($L_c = 0.1862 \in [0.17355, 0.18866]$).
   - `Island.Contrast(#008585, darkInk)` produces **4.425:1**, failing the WCAG AA minimum readable contrast floor of **4.5:1**.
   - If `darkInk` had been pure black (`Color.FromArgb(255, 0, 0, 0)`), contrast would be $4.72:1 \ge 4.5:1$. Calling `Island.EnforceContrast(onAccent, c, 4.5)` guarantees compliance across all colors.

3. **Vulnerability 2 — Asymmetric Accent Contrast Guard in Dark Mode**:
   - In `src/Ink.cs:206`, the guard is conditioned on `if (light && Island.Contrast(c, Base.Bg) < 3.5)`.
   - When `light == false` (Dark mode), no contrast floor is enforced on `c` against `Base.Bg` (`#000000`).
   - If a custom dark accent (e.g., `#101010` from user picker or `AlbumAccent.CoverAccent` which only lifts to 3:1) is applied in dark mode, the accent contrast against the black surface is only **1.06:1 to 1.1:1**, rendering the accent completely unreadable.
   - Symmetrizing the guard to `if (Island.Contrast(c, Base.Bg) < 3.5)` protects both light mode (against `#F5F5F5`) and dark mode (against `#000000`).

---

## 3. Caveats

1. **Preset Immunity**: All 7 built-in presets (`Biru`, `Hijau`, `Kuning`, `Oranye`, `Merah muda`, `Ungu`, `Navy`) were explicitly calibrated by Worker 1 and have luminances outside the dead zone ($L \notin [0.17355, 0.18866]$). The issue is strictly isolated to custom/dynamic accents in `Ink.Apply`.
2. **Pack Palette Immunity**: When `CustomOn` is active via `Colors.cs:SaveCustomPack()`, `DerivePalette` overrides `pack["onAccent"]` with its own enforced value, which does not suffer from this issue.

---

## 4. Conclusion

**Verdict: `REQUEST_CHANGES`**

While `Colors.DerivePalette`, typography fixes, glass shaders, and built-in preset calibrations are implemented robustly, `Ink.Apply` in `src/Ink.cs` contains two reproducible contrast floor defects when handling custom or dynamic accents:
1. `Base.OnAccent` drops to **4.425:1** (< 4.5:1 WCAG AA) for custom accents with luminance in $[0.17355, 0.18866]$ (reproducible with `#00FFFF`).
2. Custom dark accents in dark mode are not guarded against `Base.Bg` (`#000000`), allowing contrast as low as **1.06:1**.

### Actionable Mitigation for Worker 1
In `src/Ink.cs`, replace lines 206–214:
```csharp
<<<< ORIGINAL (src/Ink.cs:206-214)
                if (light && Island.Contrast(c, Base.Bg) < 3.5)
                    c = Island.EnforceContrast(c, Base.Bg, 3.5);
                Base.Accent = Base.Progress = c;
                // Ink on the accent: pick whichever actually wins on WCAG contrast,
                // not a luma guess. Blue and navy presets used to land at ~3.07:1.
                var darkInk = Color.FromArgb(255, 10, 10, 10);
                var lightInk = Color.FromArgb(255, 250, 250, 250);
                Base.OnAccent = Island.Contrast(c, darkInk) >= Island.Contrast(c, lightInk) ? darkInk : lightInk;
==== REPLACEMENT
                if (Island.Contrast(c, Base.Bg) < 3.5)
                    c = Island.EnforceContrast(c, Base.Bg, 3.5);
                Base.Accent = Base.Progress = c;
                var darkInk = Color.FromArgb(255, 0, 0, 0);
                var lightInk = Color.FromArgb(255, 255, 255, 255);
                var onAccent = Island.Contrast(c, darkInk) >= Island.Contrast(c, lightInk) ? darkInk : lightInk;
                Base.OnAccent = Island.EnforceContrast(onAccent, c, 4.5);
>>>>
```

---

## 5. Verification Method

1. **Clean Build**:
   ```cmd
   cmd /c build.cmd
   ```
   Must output `Build OK: D:\PROJECT\Other\tepi\Tepi.exe` with exit code 0.

2. **Adversarial Test Suite**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tests\adversarial\adversarial_m1.ps1
   ```
   After applying the mitigation, all 10 tests (including `P07`) must pass with 0 failures.

3. **Invalidation Conditions**:
   - If `OnAccent` contrast on `#00FFFF` in light mode is $< 4.5:1$, changes remain incomplete.
   - If `Accent` contrast on `#101010` in dark mode is $< 3.5:1$ against `#000000`, dark mode guard has failed.
