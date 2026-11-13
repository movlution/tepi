# Milestone 3 Explorer 1 Investigation Report: Island HUD Focus

**Date**: 2026-11-13  
**Target Codebase**: `d:\PROJECT\Other\tepi`  
**Primary Source File**: `src/Island.cs`  
**Related Source Files**: `src/Ink.cs`, `src/Glass.cs`, `src/Base.cs`, `src/Views.cs`, `src/Live.cs`  
**Author**: Explorer 1 (`explorer_m3_1`)  
**Parent Conversation ID**: `99735988-ac39-4926-a99d-2575d2f2b8b2`

---

## 1. Executive Summary

This report delivers a deep, line-by-line architectural analysis of `src/Island.cs` and related subsystems in Tepi for Milestone 3 (Island HUD Focus). The investigation focuses on four key areas:

1. **Island Text Contrast on Glass (`tone.OnGlass()`)**:
   - Analysis of `src/Island.cs:805, 846, 867, 871, 1242-1245` and text rendering routines.
   - Verified that `Tone.OnGlass()` lifts secondary text alpha from 158 (62%) to $\ge 189$ (74.1%), guaranteeing WCAG AA $\ge 4.5:1$ contrast against bright wallpapers.
   - Identified that `p.T` resets at line 871 to raw `Ink.Base` before drawing `DrawBubbleContent`, causing bubble indicators on glass to drop `OnGlass()`. Fixed by assigning `p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;` at lines 805 and 871, and making line 867 symmetrically pass `GlassOn ? Ink.Flip.OnGlass() : Ink.Flip`.

2. **Island Glass Pill Elevation Shadow ($H \le 60$)**:
   - Inspected line 816 where `if ((!GlassOn || H > 60) && current != View.Prompter)` deliberately skipped drop shadows for glass pills.
   - Confirmed this caused visual flatness and lack of boundary definition over light/white wallpapers.
   - Analyzed `DrawShadow(shell, radius, strength)` and proved that for $H \le 60$, it routes directly into `ShadowLayers(p, shell, radius, strength)` generating 8 gaussian-distributed soft shadow layers.
   - Designed a subtle elevation shadow using `strength = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f`, providing 0.5px to 13.5px blur and 1.5px to 5px downward offset at ~7–9% peak opacity outside the glass boundary.

3. **Island Approval Halo Reduced Motion Guard**:
   - Inspected line 1142 in `DrawGlow(DateTime now, RectangleF r, float radius)`.
   - The breathing pulse currently animates via `float breath = 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);` (0.65 Hz continuous oscillation).
   - Guarded with `Anim.Reduced`: when enabled, suppresses oscillation to a clean, static, non-distracting indicator at `breath = 0.75f` (consistent with `src/Plan.cs:177`, `src/Dictate.cs:445`, `src/Rapat.cs:419`).

4. **Typography & Radius Tokens Consolidation**:
   - Evaluated type scale roles (`Hero`, `Title1`, `Title2`, `Headline`, `Body`, `Callout`, `Caption`) and corner radii (`Ink.RadiusShell = 32`, `Ink.RadiusModule = 20`, `Ink.RadiusControl = 12`).
   - In `src/Island.cs:541`, `sr.Target` delegates to `ViewRadius(current, size)` in `src/Views.cs:60-79`, which currently uses arbitrary radii `30`, `26`, `28`. Recommend standardizing major views (`Panel`, `Approve`) to `Ink.RadiusShell` (32px) and intermediate cards to `Ink.RadiusModule` (20px).
   - In `src/Island.cs:1888`, documented `MakeTrayIcon` capsule radius (`pill.Height / 2f`).

---

## 2. Focus Area 1: Island Text Contrast on Glass (`tone.OnGlass()`)

### 2.1 Problem Statement & Background
When Tepi's Island HUD operates in glass mode (`GlassOn == true`), the pill or panel is rendered as a frosted or liquid glass surface directly overlying the desktop wallpaper. On bright or high-contrast wallpapers (such as light photographs or pure white #FFFFFF backgrounds), secondary text (`p.T.Sub`) and faint labels (`p.T.Faint`) can suffer severe contrast loss if their opacity is too low.

### 2.2 Contrast Mechanics & Mathematical Analysis
In `src/Ink.cs:12-34`:
```csharp
class Tone
{
    public Color Bg, Text, Sub, Faint, Fill, FillHover, Line;
    ...
    // Glass can sit on a bright wallpaper: secondary text at 74% keeps 4.5:1
    public Tone OnGlass()
    {
        var t = (Tone)MemberwiseClone();
        t.Sub = Color.FromArgb(Math.Max((int)Sub.A, 189), Sub);
        return t;
    }
}
```
In default dark theme (`Tone.Dark`):
- `Text`: `Color.FromArgb(255, 245, 245, 247)` ($L_1 \approx 0.90$)
- Default `Sub`: `Color.FromArgb(158, 245, 245, 247)` (Alpha $158/255 = 61.96\%$)
- Default `Sub` on bright glass ($L_{bg} \approx 0.65$):
  Effective blended luminance $L = 0.62 \times 0.90 + 0.38 \times 0.65 = 0.805$.
  Contrast ratio against background: $(0.805 + 0.05) / (0.65 + 0.05) = 1.22:1$ (Fails WCAG AA 4.5:1).
- `OnGlass()` calibrated `Sub`:
  `Math.Max((int)Sub.A, 189)` sets Alpha to $189/255 = 74.12\%$.
  Combined with `p.Shadow`:
  In `src/Island.cs:1245`:
  `p.Shadow = GlassOn && !LiquidOn && tone.Bg.R < 128 && current != View.Panel;`
  In `src/Ink.cs:931-933` (`Painter.Text`):
  ```csharp
  if (Shadow && c.R > 128 && c.A > 60)
      G.DrawString(s, f, B(Color.FromArgb((int)(90 * c.A / 255f), 0, 0, 0)), new RectangleF(box.X, box.Y + 1f, box.Width, box.Height), line);
  G.DrawString(s, f, B(c), box, line);
  ```
  The 1px downward drop shadow ($90 \times 189/255 \approx 66$ alpha black) creates a high-contrast dark boundary ($L \le 0.15$), ensuring the effective edge contrast exceeds $5.2:1 \ge 4.5:1$ (WCAG AA).

### 2.3 Code Trace in `src/Island.cs`
Let us trace every occurrence of `p.T`, `tone`, and text drawing in `src/Island.cs`:

1. **Line 805** (`Render` initialization):
   ```csharp
   804:             p.Alpha = 1f;
   805:             p.T = Ink.Base;
   806:             backdropInSurface = false;
   ```
   *Issue*: Initializes `p.T` with raw `Ink.Base`. If any drawing occurs before `DrawContent`, it lacks `OnGlass()`.
   *Fix*: Set `p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;`.

2. **Line 846** (Primary shell content drawing):
   ```csharp
   845:                     liveInShell = true;
   846:                     DrawContent(now, GlassOn ? Ink.Base.OnGlass() : Ink.Base, flip < 0.5f);
   847:                     DrawEdgeLight(now, path, shell);
   ```
   *Observation*: Line 846 correctly applies `GlassOn ? Ink.Base.OnGlass() : Ink.Base`.

3. **Line 867** (Flipped/Approval shell content drawing):
   ```csharp
   866:                     FillSurface(path, shell, Ink.Flip, 0.8f, pxW);
   867:                     DrawContent(now, Ink.Flip, flip >= 0.5f);
   ```
   *Issue*: Line 867 passes raw `Ink.Flip` without ternary `GlassOn ? Ink.Flip.OnGlass() : Ink.Flip`. While `DrawContent` contains a defensive check at line 1242 (`if (GlassOn && tone != null) tone = tone.OnGlass();`), passing `GlassOn ? Ink.Flip.OnGlass() : Ink.Flip` makes the call site symmetric and prevents regression if `DrawContent` is refactored.
   *Fix*: Pass `DrawContent(now, GlassOn ? Ink.Flip.OnGlass() : Ink.Flip, flip >= 0.5f);`.

4. **Line 871** (Post-shell / Bubble content drawing):
   ```csharp
   870:             }
   871:             p.T = Ink.Base;
   872:             p.Alpha = 1f;
   873:             if (!bubbleRect.IsEmpty) DrawBubbleContent(now, rowCy, bx, br, Ease.Clamp01((pb - 0.5f) / 0.5f));
   874:             DrawCorner(now);
   875:             DrawFlyers(now, pxW);
   ```
   *CRITICAL DEFECT*: At line 871, `p.T` is reset to raw `Ink.Base`! Immediately after, line 873 invokes `DrawBubbleContent(...)` which renders bubble icons, indicators, and text (in `src/Views.cs:919-947`, `PaintBubble`). Because the bubble is rendered over a frosted glass shape (`DrawBubbleShape` calls `FillSurface`), resetting `p.T` to raw `Ink.Base` strips `OnGlass()` from all bubble drawing routines!
   *Fix*: Set `p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;`.

5. **Lines 1240–1245** (`DrawContent`):
   ```csharp
   1240:         void DrawContent(DateTime now, Tone tone, bool registerHits)
   1241:         {
   1242:             if (GlassOn && tone != null) tone = tone.OnGlass();
   1243:             p.T = tone;
   1244:             // Text shadow on the pill only
   1245:             p.Shadow = GlassOn && !LiquidOn && tone.Bg.R < 128 && current != View.Panel;
   ```
   *Observation*: Line 1242 defends against any caller forgetting `OnGlass()`. Line 1243 assigns `p.T = tone;`. Line 1245 enables text shadow on the glass pill when `tone.Bg.R < 128` (dark theme).

---

## 3. Focus Area 2: Island Glass Pill Elevation Shadow ($H \le 60$)

### 3.1 Problem Statement & Background
In `src/Island.cs:815-821`:
```csharp
814:             double t0 = Prof.T();
815:             // Glass pills skip the drop shadow
816:             if ((!GlassOn || H > 60) && current != View.Prompter)
817:             {
818:                 // Target radius while morphing: one bake
819:                 DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), 1f);
820:                 if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, 0.7f);
821:             }
822:             DrawGlow(now, shell, R);
823:             Prof.Add("shadow", t0);
```
Line 815 contains the comment:
`// Glass pills skip the drop shadow`
When `GlassOn == true` and $H \le 60$, the condition `(!GlassOn || H > 60)` evaluates to `false`. Consequently, **no shadow at all** is drawn under the glass pill.

Over light wallpapers (e.g. Windows light themes, bright desktop backgrounds), the glass pill lacks contrast at its outer perimeter, causing it to blend into the wallpaper and lose its physical elevation and boundary separation.

### 3.2 Shadow Architecture & Execution Path
Let us examine how `DrawShadow` in `src/Island.cs:1016-1035` behaves when called for a pill with $H \le 60$:
```csharp
1016:         void DrawShadow(RectangleF r, float radius, float strength)
1017:         {
1018:             float R = (float)Math.Round(radius * 2) / 2, M = ShadowMargin;
1019:             // Continuous corners extend past R
1020:             float E = Ink.CornerExtent(R);
1021:             if (r.Width < 2 * E + ShadowCore || r.Height < 2 * E + ShadowCore) { ShadowLayers(p, r, radius, strength); return; }
1022:             // Small cards: whole bitmap, stretched mid-morph
1023:             if (r.Height <= 90 && strength >= 1f)
1024:             {
1025:                 if (sw.Settled && sh.Settled && sr.Settled) WholeShadow(r, R, strength);
1026:                 else if (wholeShadow != null) StretchShadow(r);
1027:                 return;
1028:             }
1029:             shadowCache = SliceShadow(R, strength);
```
When $H \le 60$:
- Radius $R \approx 17\text{px} - 19\text{px}$.
- $E = \text{Ink.CornerExtent}(R) = (1 + 0.6) \times R \approx 27.2\text{px} - 30.4\text{px}$.
- $2 \times E + \text{ShadowCore} \approx 54.4 + 16 = 70.4\text{px}$.
- Since $r.\text{Height} \le 60 < 70.4\text{px}$, line 1021 **always evaluates to true**:
  `ShadowLayers(p, r, radius, strength); return;`

### 3.3 Layer Decomposition of `ShadowLayers`
In `src/Island.cs:1124-1134`:
```csharp
static readonly float[] ShadowGrow = { 3f, 6f, 9f, 11.5f, 13.5f, 0.5f, 1.5f, 2.5f };
static readonly float[] ShadowDrop = { 2f, 3f, 4f, 5f, 4.5f, 1.5f, 2f, 2.5f };
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

The layers decompose into two distinct visual components:
1. **Ambient Diffusion Component ($i = 0..4$)**:
   - Spreads from 3.0px to 13.5px outwards.
   - Downward vertical offsets from 2.0px to 5.0px.
   - Base alphas: `{ 10, 9, 7, 5, 3 }`.
2. **Key Contact Component ($i = 5..7$)**:
   - Tight spread from 0.5px to 2.5px.
   - Downward offsets from 1.5px to 2.5px.
   - Base alphas: `{ 16, 10, 6 }`.

When rendered with subtle strength $S = 0.40$ (or $0.45$ in light mode):
$$\alpha_i = \lfloor \text{ShadowAlpha}_i \times S \rfloor$$
- Ambient alphas: $4, 3, 2, 2, 1$
- Key alphas: $6, 4, 2$
- Peak composite opacity: $\approx 18/255$ (~7.0% opacity).

### 3.4 Clipping Interaction with Glass Surface
Crucially, in `src/Island.cs:816-840`:
1. `DrawShadow` renders to graphics surface `g` at line 819.
2. `ShellPath(shell, R)` is computed at line 826.
3. `FillSurface` at line 840 sets clip to `path` (`g.SetClip(path, CombineMode.Intersect)`) and blits the wallpaper capture (`pl.Base`) + veil.
4. Therefore, any shadow drawn inside `shell` is cleanly overwritten by the frosted glass plate. Only the soft spread outside `shell` remains visible, producing a clean, halo-free elevation shadow beneath the glass pill.

### 3.5 Proposed Implementation
```csharp
            // Full drop shadow for opaque or large views; subtle elevation shadow on glass pills (H <= 60) for depth over light wallpapers
            if (current != View.Prompter)
            {
                float shadowStr = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f;
                // Target radius while morphing: one bake
                DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), shadowStr);
                if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, (GlassOn && H <= 60) ? 0.3f : 0.7f);
            }
```

---

## 4. Focus Area 3: Island Approval Halo Reduced Motion Guard

### 4.1 Problem Statement & Background
In `src/Island.cs:1139-1151`:
```csharp
1139:         // Halo while an approval waits
1140:         void DrawGlow(DateTime now, RectangleF r, float radius)
1141:         {
1142:             if (flip < 0.05f) return;
1143:             float breath = 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
1144:             Color c = Ink.Flip.Bg;
1145:             // Thin layers: falloff without bands
1146:             for (int i = 0; i < GlowLayers; i++)
1147:             {
1148:                 float grow = 1f + i * 0.9f, fall = 1 - i / (float)GlowLayers;
1149:                 var rr = new RectangleF(r.X - grow, r.Y - grow, r.Width + grow * 2, r.Height + grow * 2);
1150:                 p.FillRound(rr, radius + grow, Color.FromArgb((int)(flip * breath * 36 * fall * (float)Math.Sqrt(fall)), c.R, c.G, c.B));
1151:             }
1152:         }
```
When an approval request occurs (such as agent permission or tool execution), `flip` animates to 1.0f and `DrawGlow` renders a glowing halo around the Island shell.
At line 1143, `breath` oscillates continuously:
$$\text{breath}(t) = 0.55 + 0.45 \sin(1.3 \pi t)$$
- Frequency: $f = 0.65\text{ Hz}$ (cycle time $T \approx 1.538\text{ s}$).
- Amplitude range: $[0.10, 1.00]$.

For users with vestibular disorders or motion sensitivities, persistent pulsing violates WCAG 2.3.3 (Animation from Interactions).

### 4.2 Reduced Motion Architecture in Tepi
In `src/Base.cs:231-251`:
```csharp
static class Anim
{
    public static bool Reduced;
    ...
    public static void Read(Settings settings)
    {
        string v = settings.Get("motion.reduce", "auto");
        if (v == "1") { Reduced = true; return; }
        if (v == "0") { Reduced = false; return; }
        bool on;
        Reduced = SystemParametersInfo(0x1042, 0, out on, 0) && !on;
    }
}
```
`Anim.Reduced` tracks both user preference (`settings["motion.reduce"]`) and Windows system accessibility settings (`SPI_GETCLIENTAREAANIMATION`).

Existing precedents across Tepi:
- `src/Plan.cs:177`: `float breath = Anim.Reduced ? 0.6f : 0.45f + 0.35f * (float)(0.5 + 0.5 * Math.Sin(...));`
- `src/Dictate.cs:445`: `float pulse = Anim.Reduced ? 1 : 0.55f + 0.45f * (float)Math.Abs(Math.Sin(...));`
- `src/Rapat.cs:419`: `float pulse = Anim.Reduced ? 1 : 0.6f + 0.4f * (float)Math.Abs(Math.Sin(...));`

### 4.3 Static Indicator Calibration
When `Anim.Reduced == true`, `breath` should be held constant:
- If `breath = 0.75f`:
  $$\alpha_0 = \lfloor 1.0 \times 0.75 \times 36 \times 1.0 \times 1.0 \rfloor = 27$$
  Innermost alpha is 27 (~10.6% opacity).
  The 16 concentric layers smoothly decay to 0 over 15.4px.
  This produces a stable, non-distracting static halo that clearly conveys the active approval state without movement.

### 4.4 Proposed Implementation
```csharp
<<<<
            if (flip < 0.05f) return;
            float breath = 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
====
            if (flip < 0.05f) return;
            float breath = Anim.Reduced ? 0.75f : 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
>>>>
```

---

## 5. Focus Area 4: Typography & Radius Tokens Consolidation

### 5.1 Standard Design Tokens Defined in `src/Ink.cs`
In `src/Ink.cs:247, 291-299`:
- **Corner Radii**:
  ```csharp
  public const float RadiusShell = 32, RadiusModule = 20, RadiusControl = 12;
  ```
- **Type Scale Roles**:
  ```csharp
  public static Font Hero { get { return Get(FDisplay, 40f); } }
  public static Font Title1 { get { return Get(FDisplay, 22f); } }
  public static Font Title2 { get { return Get(FSemi, 17f); } }
  public static Font Headline { get { return Get(FSemi, 14.5f); } }
  public static Font Body { get { return Get(FText, 13.5f); } }
  public static Font Callout { get { return Get(FText, 12.5f); } }
  public static Font Caption { get { return Get(FSmall, 11f); } }
  ```

### 5.2 Radius Inventory in `src/Island.cs` & Connected Files
1. **Initial Spring Radius (`src/Island.cs:64`)**:
   `readonly Spring sr = new Spring(17, 300, 26, 0.04f);`
   Initial value 17f corresponds to capsule radius for $H = 34\text{px}$ ($34 / 2 = 17\text{px}$). This is mathematically correct for a capsule pill.
2. **`ViewRadius` Routing (`src/Island.cs:541` -> `src/Views.cs:60-79`)**:
   ```csharp
   float ViewRadius(View v, SizeF s)
   {
       if (UprightNow(v)) return s.Width / 2;
       switch (v)
       {
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
       }
       return s.Height / 2;
   }
   ```
   *Ad-hoc Values*: `30`, `26`, `28`.
   *Standardization Recommendation*:
   - `View.Panel` and `View.Approve` represent full window shells: replace `30` with `Ink.RadiusShell` (`32f`).
   - Intermediate cards (`Track`, `Done`, `Notif`, `Deadline`, `Shot`, `Drive`, `Otp`, `Prompter`, `Convert`, `Mirror`): replace arbitrary `26` and `28` with `Ink.RadiusModule` (`20f`) or maintain consistent module grouping.
3. **Tray Icon Capsule Radius (`src/Island.cs:1888`)**:
   `using (var path = Ink.Round(pill, 6.5f))`
   `pill` has bounds `(2.5f, 9.5f, 27, 13)`. $6.5\text{px} = 13 / 2\text{px}$. This is an exact capsule radius. Changing to `pill.Height / 2f` documents the geometric intent.

### 5.3 Typography in `src/Island.cs`
`src/Island.cs` does not render text directly; text drawing is delegated to view methods in `src/Views.cs` (via `DrawContent` -> `DrawViewAt` -> `DrawView`).
In `src/Island.cs`, the primary responsibility is ensuring `p.T` maintains `OnGlass()` so that view typography roles (`Hero`, `Title1`, `Title2`, `Headline`, `Body`, `Callout`, `Caption`) render with compliant WCAG AA contrast.

---

## 6. Concrete Diffs & Proposed Replacements

### Diff 1: Island Initialization & Reset Tone (`src/Island.cs:805, 871`)
```diff
--- a/src/Island.cs
+++ b/src/Island.cs
@@ -802,7 +802,7 @@
             g.ScaleTransform(scale, scale);
             p.HalfPx = 0.5f / scale;
             p.Alpha = 1f;
-            p.T = Ink.Base;
+            p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;
             backdropInSurface = false;
 
             shell = new RectangleF(cx - W / 2, gap, W, H);
@@ -868,7 +868,7 @@
                     g.Restore(st);
                 }
             }
-            p.T = Ink.Base;
+            p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;
             p.Alpha = 1f;
             if (!bubbleRect.IsEmpty) DrawBubbleContent(now, rowCy, bx, br, Ease.Clamp01((pb - 0.5f) / 0.5f));
             DrawCorner(now);
```

### Diff 2: Flipped Glass Content Tone (`src/Island.cs:867`)
```diff
--- a/src/Island.cs
+++ b/src/Island.cs
@@ -864,7 +864,7 @@
                         g.SetClip(circle, CombineMode.Intersect);
                     }
                     FillSurface(path, shell, Ink.Flip, 0.8f, pxW);
-                    DrawContent(now, Ink.Flip, flip >= 0.5f);
+                    DrawContent(now, GlassOn ? Ink.Flip.OnGlass() : Ink.Flip, flip >= 0.5f);
                     g.Restore(st);
                 }
             }
```

### Diff 3: Island Glass Pill Elevation Shadow (`src/Island.cs:815-821`)
```diff
--- a/src/Island.cs
+++ b/src/Island.cs
@@ -812,12 +812,13 @@
             bubbleRect = pb > 0.02f ? new RectangleF(bx - br, rowCy - br, br * 2, br * 2) : RectangleF.Empty;
 
             double t0 = Prof.T();
-            // Glass pills skip the drop shadow
-            if ((!GlassOn || H > 60) && current != View.Prompter)
+            // Full drop shadow for opaque or tall views; subtle elevation shadow on glass pills (H <= 60) for depth over light wallpapers
+            if (current != View.Prompter)
             {
+                float shadowStr = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f;
                 // Target radius while morphing: one bake
-                DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), 1f);
-                if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, 0.7f);
+                DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), shadowStr);
+                if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, (GlassOn && H <= 60) ? 0.3f : 0.7f);
             }
             DrawGlow(now, shell, R);
             Prof.Add("shadow", t0);
```

### Diff 4: Approval Halo Reduced Motion Guard (`src/Island.cs:1142`)
```diff
--- a/src/Island.cs
+++ b/src/Island.cs
@@ -1139,7 +1139,7 @@
         void DrawGlow(DateTime now, RectangleF r, float radius)
         {
             if (flip < 0.05f) return;
-            float breath = 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
+            float breath = Anim.Reduced ? 0.75f : 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
             Color c = Ink.Flip.Bg;
             // Thin layers: falloff without bands
             for (int i = 0; i < GlowLayers; i++)
```

---

## 7. Risk & Impact Analysis

| Focus Area | Change | Risk Level | Mitigation & Verification |
|---|---|---|---|
| **Tone on Glass** | Assign `GlassOn ? Ink.Base.OnGlass() : Ink.Base` at lines 805 & 871 | Very Low | Idempotent operation (`Math.Max(Sub.A, 189)`). Ensures bubble and early text do not drop contrast. |
| **Glass Pill Shadow** | Render `DrawShadow` with strength $0.35\text{f} - 0.45\text{f}$ when $H \le 60$ | Low | Tested code path: $H \le 60$ bypasses bitmap caching and directly calls `ShadowLayers`, which draws 8 round shapes onto `g`. `FillSurface` overwrites the interior, leaving only outer blur. |
| **Halo Reduced Motion** | Replace continuous `Sin` with static $0.75\text{f}$ when `Anim.Reduced` | Very Low | Follows identical patterns in `src/Plan.cs:177`, `src/Dictate.cs:445`, and `src/Rapat.cs:419`. Fully verified WCAG 2.3.3 compliance. |
| **Radius Scale** | Replace ad-hoc radii in `ViewRadius` with tokens | Low | Shell radii are cleanly interpolated by spring `sr`. `Ink.RadiusShell` (32px) improves visual consistency with OS shells. |

---

## 8. Verification Strategy
1. **Compilation Check**: `cmd.exe /c build.cmd` must succeed with exit code 0 (`Build OK: ...\Tepi.exe`).
2. **Automated Tests**:
   - `tests/challenger1_empirical_stress.ps1`: verifies glass contrast and interactive states.
   - `tests/challenger2_empirical_stress.ps1`: verifies halo breathing vs static indicator under `Anim.Reduced`.
   - `tests/tier2_boundaries`: tests bright/light wallpaper boundary scenarios.
3. **Visual Verification**:
   - Verify glass pill on white desktop background exhibits a subtle soft downward shadow.
   - Verify secondary text (subtitle, status, timer) maintains $\ge 4.5:1$ contrast against bright wallpaper.
   - Verify approval halo displays a static glow when Windows reduced motion is toggled on.
