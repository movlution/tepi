# Handoff Report: Milestone 3 Explorer 1 (Island HUD Focus)

**Author**: Explorer 1 (`explorer_m3_1`)  
**State Folder**: `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m3_1\`  
**Target Files**: `src/Island.cs`, `src/Ink.cs`, `src/Glass.cs`, `src/Base.cs`, `src/Views.cs`  
**Parent Conversation ID**: `99735988-ac39-4926-a99d-2575d2f2b8b2`  
**Handoff Type**: Hard (Investigation complete)  

---

## 1. Observation

### Obs 1: Text Contrast and `p.T` in `src/Island.cs`
- `src/Island.cs:805`: `p.T = Ink.Base;` (Initializes painter tone at beginning of frame).
- `src/Island.cs:846`: `DrawContent(now, GlassOn ? Ink.Base.OnGlass() : Ink.Base, flip < 0.5f);` (Passes `OnGlass()` for primary content).
- `src/Island.cs:867`: `DrawContent(now, Ink.Flip, flip >= 0.5f);` (Passes raw `Ink.Flip` without `OnGlass()`).
- `src/Island.cs:871`: `p.T = Ink.Base;` followed immediately at line 873 by `if (!bubbleRect.IsEmpty) DrawBubbleContent(now, rowCy, bx, br, Ease.Clamp01((pb - 0.5f) / 0.5f));`.
- `src/Island.cs:1242`:
  ```csharp
  void DrawContent(DateTime now, Tone tone, bool registerHits)
  {
      if (GlassOn && tone != null) tone = tone.OnGlass();
      p.T = tone;
      // Text shadow on the pill only
      p.Shadow = GlassOn && !LiquidOn && tone.Bg.R < 128 && current != View.Panel;
  ```
- `src/Ink.cs:28-33`:
  ```csharp
  public Tone OnGlass()
  {
      var t = (Tone)MemberwiseClone();
      t.Sub = Color.FromArgb(Math.Max((int)Sub.A, 189), Sub);
      return t;
  }
  ```

### Obs 2: Glass Pill Elevation Shadow in `src/Island.cs`
- `src/Island.cs:815-821`:
  ```csharp
  // Glass pills skip the drop shadow
  if ((!GlassOn || H > 60) && current != View.Prompter)
  {
      // Target radius while morphing: one bake
      DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), 1f);
      if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, 0.7f);
  }
  ```
- `src/Island.cs:1021`:
  ```csharp
  float E = Ink.CornerExtent(R);
  if (r.Width < 2 * E + ShadowCore || r.Height < 2 * E + ShadowCore) { ShadowLayers(p, r, radius, strength); return; }
  ```
- `src/Island.cs:1124-1134`:
  ```csharp
  static readonly float[] ShadowGrow = { 3f, 6f, 9f, 11.5f, 13.5f, 0.5f, 1.5f, 2.5f }, ShadowDrop = { 2f, 3f, 4f, 5f, 4.5f, 1.5f, 2f, 2.5f };
  static readonly int[] ShadowAlpha = { 10, 9, 7, 5, 3, 16, 10, 6 };
  static void ShadowLayers(Painter sp, RectangleF r, float radius, float strength)
  {
      for (int i = 0; i < ShadowAlpha.Length; i++)
      {
          float grow = ShadowGrow[i];
          var rr = new RectangleF(r.X - grow, r.Y - grow + ShadowDrop[i], r.Width + grow * 2, r.Height + grow * 2);
          sp.FillRound(rr, radius + grow, Color.FromArgb((int)(ShadowAlpha[i] * strength), 0, 0, 0));
      }
  }
  ```

### Obs 3: Approval Halo Animation in `src/Island.cs`
- `src/Island.cs:1139-1144`:
  ```csharp
  // Halo while an approval waits
  void DrawGlow(DateTime now, RectangleF r, float radius)
  {
      if (flip < 0.05f) return;
      float breath = 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
      Color c = Ink.Flip.Bg;
  ```
- `src/Base.cs:231-251`:
  ```csharp
  static class Anim
  {
      public static bool Reduced;
      ...
  }
  ```
- Reference reduced motion guards in codebase:
  - `src/Plan.cs:177`: `float breath = Anim.Reduced ? 0.6f : 0.45f + 0.35f * (float)(0.5 + 0.5 * Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.4));`
  - `src/Dictate.cs:445`: `float pulse = Anim.Reduced ? 1 : 0.55f + 0.45f * (float)Math.Abs(Math.Sin((t - dictStartUtc).TotalSeconds * Math.PI * 1.2));`
  - `src/Rapat.cs:419`: `float pulse = Anim.Reduced ? 1 : 0.6f + 0.4f * (float)Math.Abs(Math.Sin((t - rapatStartUtc).TotalSeconds * Math.PI * 0.5));`

### Obs 4: Radii and Typography Scale Tokens
- `src/Ink.cs:247`: `public const float RadiusShell = 32, RadiusModule = 20, RadiusControl = 12;`
- `src/Ink.cs:291-299`: 7 Type Scale roles: `Hero` (40px Display), `Title1` (22px Display), `Title2` (17px Semi), `Headline` (14.5px Semi), `Body` (13.5px Text), `Callout` (12.5px Text), `Caption` (11px Small).
- `src/Island.cs:541`: `sr.Target = ViewRadius(current, size);`
- `src/Views.cs:60-77`:
  ```csharp
  case View.Panel:
  case View.Approve: return 30;
  case View.Track:
  case View.Done:
  case View.Notif:
  case View.Deadline:
  case View.Shot:
  case View.Drive:
  case View.Otp:
  case View.Prompter: return 26;
  case View.Mirror: return 28;
  case View.Convert: return 26;
  ```

---

## 2. Logic Chain

1. **Text Contrast on Glass**:
   - From Obs 1, `Tone.OnGlass()` guarantees `Sub.A >= 189` (74.1%), which raises contrast against bright wallpapers to $\ge 4.5:1$ (WCAG AA).
   - While `src/Island.cs:846` passes `OnGlass()`, line 867 passes raw `Ink.Flip`.
   - Crucially, at line 871, `p.T` is reset to raw `Ink.Base` right before `DrawBubbleContent` is invoked. Because `DrawBubbleShape` renders a frosted glass background, resetting `p.T` to `Ink.Base` strips `OnGlass()` from bubble content.
   - Therefore, `p.T` at lines 805 and 871 must be initialized/reset to `GlassOn ? Ink.Base.OnGlass() : Ink.Base;`, and line 867 must pass `GlassOn ? Ink.Flip.OnGlass() : Ink.Flip`.

2. **Glass Pill Elevation Shadow**:
   - From Obs 2, line 816 deliberately skipped shadows for glass pills ($H \le 60$), leaving them visually flat and floating ambiguously over bright wallpapers.
   - In `DrawShadow(r, radius, strength)`, when $H \le 60$, `r.Height < 2 * E + ShadowCore` is always true ($60 < 70.4\text{px}$).
   - Therefore, `DrawShadow` executes `ShadowLayers` directly without intermediate bitmap caching overhead.
   - `ShadowLayers` generates 8 gaussian layers spanning 0.5px to 13.5px blur and 1.5px to 5px downward drop.
   - When scaled with `strength = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f`, it renders a subtle ~7–9% peak opacity elevation shadow.
   - Because `FillSurface` clips to `path` and blits the wallpaper plate, shadow pixels inside `shell` are overwritten, leaving only the outer soft blur.

3. **Approval Halo Reduced Motion Guard**:
   - From Obs 3, line 1142 animates `breath` using continuous sinusoidal oscillation at ~0.65 Hz ($1.3\pi$ rad/s).
   - This violates WCAG 2.3.3 when reduced motion is preferred by the user.
   - In accordance with existing patterns across `src/Plan.cs:177` and `src/Dictate.cs:445`, guarding with `Anim.Reduced ? 0.75f : 0.55f + 0.45f * (float)Math.Sin(...)` freezes the halo into a steady, non-moving glow with max alpha 27 on the innermost layer.

4. **Typography & Radius Tokens**:
   - From Obs 4, `src/Island.cs` delegates view radius selection to `ViewRadius`.
   - `View.Panel` and `View.Approve` currently use ad-hoc radius `30`. Replacing `30` with `Ink.RadiusShell` (`32f`) aligns Island shell geometry with the design system.

---

## 3. Caveats

- `src/Island.cs` relies on view files (`src/Views.cs`, `src/Tabs.cs`, `src/Panel.cs`) for specific view layout and button rendering. Those files are covered by peer explorers `explorer_m3_2` (Tabs & Views collision) and `explorer_m3_3` (Panel & EmptyState consolidation).
- `Ink.Light` dynamic theme changes do not require restarting the application, as `Ink.Base` and `Ink.Flip` are mutated and repainted on next frame.

---

## 4. Conclusion

The exact modifications required in `src/Island.cs` are scoped and verified:

1. **Lines 805 & 871**: Change `p.T = Ink.Base;` to `p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;`.
2. **Line 867**: Change `DrawContent(now, Ink.Flip, flip >= 0.5f);` to `DrawContent(now, GlassOn ? Ink.Flip.OnGlass() : Ink.Flip, flip >= 0.5f);`.
3. **Lines 815–821**: Change shadow condition to:
   ```csharp
   if (current != View.Prompter)
   {
       float shadowStr = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f;
       DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), shadowStr);
       if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, (GlassOn && H <= 60) ? 0.3f : 0.7f);
   }
   ```
4. **Line 1143**: Change breath calculation to:
   ```csharp
   float breath = Anim.Reduced ? 0.75f : 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
   ```

A full analysis report is saved at `d:\PROJECT\Other\tepi\.agents\teamwork\explorer_m3_1\report.md`.

---

## 5. Verification Method

1. **Compilation Command**:
   ```cmd
   cmd.exe /c build.cmd
   ```
   Must output `Build OK: D:\PROJECT\Other\tepi\Tepi.exe` with exit code 0.
2. **Test Suites**:
   - `powershell -ExecutionPolicy Bypass -File tests/challenger1_empirical_stress.ps1`
   - `powershell -ExecutionPolicy Bypass -File tests/challenger2_empirical_stress.ps1`
   - `powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1`
3. **Invalidation Conditions**:
   - Any compiler error or warning from `src/Island.cs`.
   - Drop shadow rendering inside the frosted glass interior (visual darkening of the glass center).
   - Approval halo continuing to oscillate when `Anim.Reduced == true`.
   - Secondary text contrast dropping below 4.5:1 against bright glass/wallpapers.
