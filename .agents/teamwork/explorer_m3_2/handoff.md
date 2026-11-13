# Handoff Report — Explorer 2 (Milestone 3: Tabs & Views Collision Focus)

## 1. Observation
1. **Tabs Inverted Hover/Pressed Fill Logic (`src/Tabs.cs`)**:
   - At line 519: `if (Hover("tab" + to) && to != page) p.FillRound(rects[i], TabH / 2, Pressed("tab" + to) ? p.T.FillHover : p.T.Fill);`
   - At line 821: `if (Hover("prefsOpen")) p.FillRound(r, TabH / 2, Pressed("prefsOpen") ? p.T.FillHover : p.T.Fill);`
   - At line 832: `if (Hover(id)) p.FillRound(r, TabH / 2, Pressed(id) ? p.T.FillHover : p.T.Fill);`
   - At line 847: `if (Hover("musicView")) p.FillRound(r, TabH / 2, Pressed("musicView") ? p.T.FillHover : p.T.Fill);`
   - In all four routines, hovering without pressing renders idle `p.T.Fill` (no hover highlight), and pressing renders `p.T.FillHover`. `p.T.FillPressed` is completely omitted.
   - In contrast, `src/Tabs.cs:602` (in `DrawDots`) already contains the correct pattern:
     `p.FillRound(new RectangleF(dotHotX.Value - (pitch - 4) / 2, cy - 12, pitch - 4, 24), 12, Pressed(hid) ? p.T.FillPressed : p.T.FillHover);`

2. **Toast Notification Meta Text Collision (`src/Views.cs`)**:
   - In `DrawNotif` at lines 755–759:
     ```csharp
     string meta = notifBurst > 1 ? notifBurst + Lang.T(" pesan · ") + item.AppName : item.AppName;
     float mw = Math.Min(130, p.Measure(meta, Ink.Small(11f)));
     p.TextRight(meta, Ink.Small(11f), p.T.Sub, w - 22, cy - 10);
     p.Text(NotifTitle(item), Ink.Semi(13.5f), p.T.Text, 66, cy - 10, w - 66 - 32 - mw, StringAlignment.Near);
     p.Text(NotifBody(item), Ink.Text(12.5f), p.T.Sub, 66, cy + 10, w - 66 - 22, StringAlignment.Near);
     ```
   - In `src/Ink.cs:945`, `TextRight` is defined as:
     `public void TextRight(string s, Font f, Color c, float right, float cy) { Text(s, f, c, right, cy, 2000, StringAlignment.Far); }`
   - `TextRight` passes `maxWidth = 2000`. In `Painter.LineBox` (`src/Ink.cs:921`), `left = right - maxWidth = (w - 22) - 2000 = w - 2022`.
   - `G.DrawString` with `StringAlignment.Far` draws the full string backwards from $w - 22$. Because `maxWidth = 2000`, it is **not** clipped to `mw = 130`.
   - For a 220px metadata string, `meta` begins at $(w - 22) - 220 = w - 242$.
   - Meanwhile, the title's allocated width is $w - 66 - 32 - 130 = w - 228$, allowing the title to extend rightwards from 66 to $66 + (w - 228) = w - 162$.
   - The region from $w - 242$ to $w - 162$ (80px wide) has both the title and the metadata drawn on top of each other at $Y = cy - 10$.

3. **Typography and Corner Radii (`src/Tabs.cs`, `src/Views.cs`)**:
   - `src/Views.cs:65-76` contains ad-hoc literals in `ViewRadius`:
     `View.Panel` and `View.Approve` return `30` (violating `Ink.RadiusShell` = 32).
     `Track`, `Done`, `Notif`, `Deadline`, `Shot`, `Drive`, `Otp`, `Prompter`, `Convert` return `26`.
     `Mirror` returns `28`.
   - `src/Views.cs:662-673` uses ad-hoc radius `10` for approval buttons (`allow`, `deny`, `always`, `term`) instead of `Ink.RadiusControl` (12).
   - `src/Tabs.cs:403, 461, 537, 653` use raw `Ink.Semi(12f)`.

## 2. Logic Chain
1. **Tabs Inverted State Fix**:
   - Since `Hover(...)` is already guaranteed by the outer `if`, the button only has two states: Hovered (mouse down = false) and Pressed (mouse down = true).
   - Tone defines `FillHover` for hovered state and `FillPressed` for pressed state.
   - Changing `Pressed(...) ? p.T.FillHover : p.T.Fill` to `Pressed(...) ? p.T.FillPressed : p.T.FillHover` guarantees that mouse down renders `FillPressed` and mouse hover renders `FillHover`.
   - This directly matches `src/Tabs.cs:602` and `src/Parts.cs:103`.

2. **Toast Meta Text Collision Fix**:
   - In `DrawNotif`, `p.Text` (`src/Ink.cs:926`) accepts `maxWidth` and `StringAlignment`.
   - Calling `p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far)` creates a `LineBox` with `left = (w - 22) - mw` and `width = mw`.
   - GDI+ clips and ellipsizes `meta` at `mw` (max 130px), confining it strictly to $[w - 22 - mw, w - 22]$.
   - The title is drawn at $X = 66$ with max width $w - 66 - 32 - mw$, confining it to $[66, w - 32 - mw]$.
   - The gap between title and meta is $(w - 22 - mw) - (w - 32 - mw) = 10\text{ px}$.
   - Collision is mathematically impossible under all text lengths and window widths.

3. **Design Token Scale Consolidation**:
   - Outer full shells (`Panel`, `Approve`, `Prompter`, `Mirror`, `Convert`) map to `Ink.RadiusShell` (32).
   - Inner flyouts and toasts (`Track`, `Done`, `Notif`, `Deadline`, `Shot`, `Drive`, `Otp`) map to `Ink.RadiusModule` (20).
   - Interactive buttons map to `Ink.RadiusControl` (12).
   - Text styles in `DrawNotif` map to `Ink.Headline` (title), `Ink.Callout` (body), and `Ink.Caption` (meta).

## 3. Caveats
- No caveats. The exact line numbers, ASTs, and rendering mechanics have been fully explored and verified against the existing test suite in `tests/tier2_boundaries/`.

## 4. Conclusion
The implementation requires:
1. In `src/Tabs.cs` lines 519, 821, 832, 847:
   Replace `Pressed(...) ? p.T.FillHover : p.T.Fill` with `Pressed(...) ? p.T.FillPressed : p.T.FillHover`.
2. In `src/Views.cs` lines 756–759:
   Replace `p.TextRight(meta, Ink.Small(11f), p.T.Sub, w - 22, cy - 10);` with:
   `p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far);`
   Update title font to `Ink.Headline` and body font to `Ink.Callout`.
3. In `src/Views.cs` lines 65–76 (`ViewRadius`):
   Consolidate shells (`Panel`, `Approve`, `Prompter`, `Mirror`, `Convert`) to `Ink.RadiusShell` (32) and toasts to `Ink.RadiusModule` (20).
   In lines 662–673, consolidate button radii `10` to `Ink.RadiusControl` (12).

## 5. Verification Method
1. Build verification:
   `.\build.cmd` $\implies$ Must exit with code 0 and output `Build OK: D:\PROJECT\Other\tepi\Tepi.exe`.
2. Automated boundary tests:
   `powershell -ExecutionPolicy Bypass -File tests\tier2_boundaries\test_b20_tabs_fill_states.ps1` $\implies$ All 5 assertions PASS.
   `powershell -ExecutionPolicy Bypass -File tests\tier2_boundaries\test_b21_toast_collision.ps1` $\implies$ All 5 assertions PASS.
3. Full regression verification:
   `powershell -ExecutionPolicy Bypass -File tests\smoke_test.ps1` $\implies$ PASS without regression.
