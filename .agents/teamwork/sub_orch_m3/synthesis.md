# Synthesis: Milestone 3 — Island, Navigation & Views Polish

## Executive Summary
All three Explorers (`explorer_m3_1`, `explorer_m3_2`, `explorer_m3_3`) have completed their investigations and delivered consistent, harmonious, and cross-verified specifications across all 7 target areas of Milestone 3. The implementation plan has zero architectural conflicts, exact line numbers identified, and strict mathematical guarantees for contrast, geometry, and tokens.

---

## Unified Implementation Plan by Source File

### 1. `src/Island.cs` (Island HUD Polish)
1. **Glass Text Contrast (`tone.OnGlass()`)**:
   - In `Render` (line 805): Set `p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;`
   - In flipped content drawing (line 867): Pass `DrawContent(now, GlassOn ? Ink.Flip.OnGlass() : Ink.Flip, flip >= 0.5f);`
   - In post-shell reset (line 871): Set `p.T = GlassOn ? Ink.Base.OnGlass() : Ink.Base;` before calling `DrawBubbleContent` (preventing bubble indicators on glass from dropping contrast).
   - In `DrawContent` (line 1242-1245): Retain defensive `if (GlassOn && tone != null) tone = tone.OnGlass();` and `p.Shadow`.
2. **Glass Pill Elevation Shadow ($H \le 60$)**:
   - In `Render` (lines 815-821): Replace `if ((!GlassOn || H > 60) && current != View.Prompter)` with:
     ```csharp
     if (current != View.Prompter)
     {
         float shadowStr = (GlassOn && H <= 60) ? (Ink.Light ? 0.45f : 0.35f) : 1f;
         DrawShadow(shell, sr.Settled ? R : Math.Min(sr.Target, Math.Min(W, H) / 2), shadowStr);
         if (!bubbleRect.IsEmpty) DrawShadow(bubbleRect, br, (GlassOn && H <= 60) ? 0.3f : 0.7f);
     }
     ```
   - For $H \le 60$, `DrawShadow` directly invokes `ShadowLayers` without caching overhead, rendering 8 gaussian layers outside the shell boundary with ~7–9% peak opacity.
3. **Approval Halo Reduced Motion Guard**:
   - In `DrawGlow` (line 1143): Guard the sinusoidal breathing oscillation:
     ```csharp
     float breath = Anim.Reduced ? 0.75f : 0.55f + 0.45f * (float)Math.Sin(clock.Elapsed.TotalSeconds * Math.PI * 1.3);
     ```
   - When `Anim.Reduced == true`, freezes halo into a calm, static 16-layer indicator (max alpha 27) complying with WCAG 2.3.3.

---

### 2. `src/Tabs.cs` (Navigation Tabs Polish)
1. **Tabs Inverted Hover/Pressed Fill Fix**:
   - At lines 519, 821, 832, 847: Correct inverted ternary logic from `down ? p.T.FillHover : p.T.FillPressed` (or equivalent inverted fill) to:
     ```csharp
     fill = down ? p.T.FillPressed : p.T.FillHover;
     ```
   - Ensures pressed state consistently renders the darker/more prominent active press fill (`FillPressed`), while hovering renders `FillHover`.
2. **Corner Radii & Typography Tokens**:
   - Consolidate tab button radii and item hover bounds to `Ink.RadiusControl` (12px) or capsule `height / 2`.
   - Align tab label typography with `Ink.Callout` (12.5px) and `Ink.Caption` (11.0px).

---

### 3. `src/Views.cs` (View Layout & Collision Fixes)
1. **Toast Notification Meta Text Collision (`DrawNotif`, lines 749-762)**:
   - Calculate proportional bounded width for meta text:
     ```csharp
     float mw = Math.Min(w * 0.35f, p.Measure(meta, Ink.Caption));
     ```
   - Replace unbounded `TextRight` with bounded far-aligned text drawing:
     ```csharp
     p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far);
     ```
   - Allocate title width with guaranteed 12px safety buffer:
     ```csharp
     p.Text(NotifTitle(item), Ink.Headline, p.T.Text, 66, cy - 10, Math.Max(40, w - 66 - 22 - mw - 12), StringAlignment.Near);
     p.Text(NotifBody(item), Ink.Callout, p.T.Sub, 66, cy + 10, w - 66 - 22, StringAlignment.Near);
     ```
   - Guarantees meta text never overlaps or collides with the notification title.
2. **`ViewRadius` Shell Scale Consolidation (lines 60-79)**:
   - Consolidate arbitrary view radii (`30`, `26`, `28`) to `Ink.RadiusShell` (32px):
     ```csharp
     float ViewRadius(View v, SizeF s)
     {
         if (UprightNow(v)) return s.Width / 2;
         switch (v)
         {
             case View.Panel:
             case View.Approve:
             case View.Track:
             case View.Done:
             case View.Notif:
             case View.Deadline:
             case View.Shot:
             case View.Drive:
             case View.Otp:
             case View.Prompter:
             case View.Mirror:
             case View.Convert:
                 return Math.Min(Ink.RadiusShell, s.Height / 2);
         }
         return s.Height / 2;
     }
     ```
3. **Approval Dialog Action Button Radii (lines 662-673)**:
   - Consolidate arbitrary radius `10` on `allow`, `deny`, `always`, `term` buttons to `Ink.RadiusControl` (12px).

---

### 4. `src/Parts.cs` (Unified UI Primitives & EmptyState)
1. **Standardize `Parts.EmptyState`**:
   - Provide flexible, comprehensive overloads in `src/Parts.cs`:
     - Overload 1: Informative empty state (no button).
     - Overload 2: Single-action empty state with `PillKind kind = PillKind.Secondary` (supports `PillKind.Primary` or `Secondary`).
     - Overload 3: Dual-action empty state (for `Shelf.cs:254` with "Pilih berkas" and "Tempel").
   - Use `p.Module(circle, 24, p.T.Fill)` for icon container, `Ink.Headline` for title, `p.TextBox` with `Ink.Callout` for multi-line description, and `Pill(...)` for action buttons.

---

### 5. `src/Panel.cs` (Legacy Empty Delegation & View Tokens)
1. **Empty & Button Backward Compatibility Delegation (lines 13-39)**:
   - Delegate `Empty(float w, char glyph, string title, string detail)` to `EmptyState(area, glyph, title, detail)`.
   - Delegate `Button(RectangleF r, string id, string label, bool filled, Action act)` to `Pill(r, id, label, filled ? PillKind.Primary : PillKind.Secondary, act)`.
2. **Call Site Migrations**:
   - Update empty state call sites in `Panel.cs` and other view modules to invoke `EmptyState` directly.
3. **Typography & Radius Tokens**:
   - Standardize heading and body fonts in list rows to `Ink.Headline`, `Ink.Body`, `Ink.Callout`, `Ink.Caption`.
   - Standardize row hover highlights and button radii to `Ink.RadiusControl` (12px).

---

### 6. `src/WorkWindow.cs` (Modal Window Styling & Tokens)
1. **Typography Tokens**:
   - Replace arbitrary font initializations with token roles:
     - `fText = UiFont(Ink.Body.Size);` (13.5px)
     - `fSub = UiFont(Ink.Callout.Size);` (12.5px)
     - `fSmall = UiFont(Ink.Caption.Size);` (11.0px)
     - `fBold = new Font(Ink.MenuFamily, Ink.Headline.Size * s, FontStyle.Bold, GraphicsUnit.Pixel);` (14.5px)
2. **Radius Tokens**:
   - Standardize well card containers to `Ink.RadiusModule * s` (20 * s).
   - Standardize input containers to `Ink.RadiusControl * s` (12 * s).
   - Standardize task and notes list item hover highlights to `Ink.RadiusControl * s` (12 * s).

---

## Verification & Gate Criteria
1. Compilation: `cmd.exe /c build.cmd` succeeds with exit code 0 (`Build OK: ...\Tepi.exe`).
2. Smoke test: `powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1` passes 100%.
3. Challenger tests: Verify interactive tab hover/pressed states, glass pill elevation shadow, reduced motion static indicator, toast collision layout, and EmptyState consolidation.
4. Forensic integrity audit: `teamwork_auditor` reports CLEAN (zero cheating, zero dummy facades, zero regressions).
