# Review & Adversarial Challenge Report: Milestone 4 (Dock & Mini Polish)

**Author**: Reviewer 2 (Roles: Reviewer, Adversarial Critic)  
**Milestone**: Milestone 4 (Dock & Mini Polish)  
**Work Product Under Review**: Worker 1 implementation across `src/DockCal.cs`, `src/DockSheet.cs`, `src/Mini.cs`, `src/DockPaint.cs`, and `src/DockCard.cs`  
**Date**: 2026-11-13  
**Verdict**: **APPROVE**  

---

## Review Summary

**Verdict**: **APPROVE**  
**Overall Risk Assessment**: **LOW**  
**Integrity Audit**: **CLEAN** (Zero shortcuts, facades, or hardcoded test cheats detected)

Worker 1's implementation cleanly and thoroughly addresses all feature requirements and acceptance criteria in `SCOPE.md`:
1. **Dock Hardcoded Colors Tokenized**: Replaced `BadgeRed`, `BadgeRedSoft`, and all white rim lights with theme tokens (`p.T.Negative`, `p.T.Highlight`, `p.T.Text`). Unread badges and thumbnail close buttons achieve WCAG AA compliance ($\ge 4.5:1$) in both light mode ($5.69:1$) and dark mode ($7.66:1$).
2. **Dock Module Interactive Pressed States**: Added robust pressed state visual feedback and $0.75\text{f}$ tactile displacement across `DockCal.cs` ("clear", "del", "today" month jump, all 42 day cells, and "quiet" toggle) and `DockSheet.cs` (`GlassSheet.Button`). Crucially, hit testing is registered *before* the offset is applied, preventing hit-target jitter.
3. **Mouse Lifecycle Guards**: Implemented explicit lifecycle handlers in `OnMouseDown`, `OnMouseUp`, `OnMouseLeave`, and `OnMouseMove` (`if (e.Button == MouseButtons.None) pressId = null`), eliminating ghost/stuck pressed states during drag-out and cross-boundary mouse movements.
4. **Mini Salience & Layout Geometry**: Increased dot radius to $2.5\text{px}$ (area $19.635\text{ px}^2 \ge 19.6\text{ px}^2$), thickened status tracks to $4.0\text{px}$, achieved exact $4.5\text{px}$ clearance between horizontal progress track and indicator dot, and centered the track symmetrically with $2.0\text{px}$ top and bottom padding within the 8px container.
5. **No Regressions**: Full automated test suite passes 100% (Tier 1: 78 tests, Tier 2: 105 tests, Total: 183 tests; plus independent adversarial stress test suite).

---

## 1. Observation

Direct observations and evidence collected during review:

1. **Hit Testing Before Tactile Displacement**:
   - `src/DockCal.cs:78-82`:
     ```csharp
     Hit(b, "clear");
     bool down = Down("clear");
     if (down) b.Offset(0, 0.75f);
     p.FillRound(b, 8, down ? p.T.FillPressed : hotId == "clear" ? p.T.FillHover : p.T.Fill);
     p.TextCenter(label, f, p.T.Text, b.X + w / 2, b.Y + b.Height / 2);
     ```
   - `src/DockCal.cs:113-116`:
     ```csharp
     Hit(x, del);
     bool xdown = Down(del);
     float xcy = x.Y + 14 + (xdown ? 0.75f : 0);
     p.Circle(x.X + 14, xcy, 12, xdown ? p.T.FillPressed : hotId == del ? p.T.FillHover : p.T.Fill);
     ```
   - `src/DockCal.cs:142-146`:
     ```csharp
     Hit(tb, "today");
     bool tdown = Down("today");
     if (tdown) tb.Offset(0, 0.75f);
     ```
   - `src/DockCal.cs:170-176`:
     ```csharp
     Hit(new RectangleF(cx - 16, cy - 16, 32, 32), did);
     bool ddown = Down(did), dhot = hotId == did;
     float dcy = ddown ? cy + 0.75f : cy;
     ```
   - `src/DockCal.cs:198-202`:
     ```csharp
     Hit(b, "quiet");
     bool qdown = Down("quiet");
     if (qdown) b.Offset(0, 0.75f);
     ```
   - `src/DockSheet.cs:472-476`:
     ```csharp
     Hit(r, id);
     if (tip != null && hotId == id) Tip(r, tip);
     bool down = Down(id);
     if (down) r.Offset(0, 0.75f);
     ```
   In all cases, `Hit()` receives the un-offset geometry, while drawing consumes the offset position.

2. **Mouse Lifecycle Guards**:
   - `src/DockSheet.cs:322`:
     `if (e.Button == MouseButtons.None && pressId != null) pressId = null;`
   - `src/DockSheet.cs:336`:
     `pressId = null;` inside `OnMouseLeave`.
   - `src/DockCal.cs:33-47`:
     ```csharp
     protected override void OnMouseDown(MouseEventArgs e)
     {
         if (e.Button == MouseButtons.Left) pressedId = HitAt(e.Location);
         base.OnMouseDown(e);
     }
     protected override void OnMouseUp(MouseEventArgs e)
     {
         pressedId = null;
         base.OnMouseUp(e);
     }
     protected override void OnMouseLeave(EventArgs e)
     {
         pressedId = null;
         base.OnMouseLeave(e);
     }
     ```

3. **Mini Layout Clearance & Centering**:
   - `src/Mini.cs:17`:
     `const float MiniDotR = 2.5f, MiniTrackThick = 4f;`
   - Container size: $H = 8\text{px}$, $W = 64\text{px}$.
   - Dot center: $X = W - 9 = 55.0\text{px}$, $Y = H / 2 = 4.0\text{px}$. Left edge: $55.0 - 2.5 = 52.5\text{px}$.
   - Horizontal progress track: `right = dot ? w - 16 : w - 12;`. When `dot = true`, right edge $= 64 - 16 = 48.0\text{px}$.
   - Clearance: $52.5\text{px} - 48.0\text{px} = 4.5\text{px}$ exact margin.
   - Vertical centering: Track top $= 4.0 - 2.0 = 2.0\text{px}$, bottom $= 4.0 + 2.0 = 6.0\text{px}$. Symmetrical top/bottom padding $= 2.0\text{px}$.

4. **Dock Badge & Close Button Contrast**:
   - `src/DockPaint.cs:656`: `p.TextCenter(s, f, p.T.IsDark ? p.T.Bg : Color.White, b.X + b.Width / 2, b.Y + h / 2);`
   - `src/DockCard.cs:414`: `p.Icon('\uE711', 9.5f, hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub, ...);`
   - Measured Dark Mode contrast: Text `#000000` on `#F07878` $\to \mathbf{7.66:1}$ ($\ge 4.5:1$).
   - Measured Light Mode contrast: Text `#FFFFFF` on `#BE3232` $\to \mathbf{5.69:1}$ ($\ge 4.5:1$).

5. **Day Cell Navigation Arithmetic**:
   - `src/DockCal.cs:235-237`:
     ```csharp
     var currShown = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(month);
     int mDiff = (clicked.Year - currShown.Year) * 12 + (clicked.Month - currShown.Month);
     if (mDiff != 0) month += mDiff;
     ```

6. **Static Cleanliness**:
   - Zero occurrences of `BadgeRed` or `BadgeRedSoft` across all `.cs` files in `src/`.
   - Rim lights and gradients in `DockPaint.cs`, `DockCard.cs`, and `DockSheet.cs` exclusively reference `p.T.Highlight`.

7. **Compilation & Automated Test Executions**:
   - `cmd /c build.cmd`: Exited with code 0 (`Build OK: D:\PROJECT\Other\tepi\Tepi.exe`).
   - `powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1`:
     - Tier 1: 78 Passed, 0 Failed.
     - Tier 2: 105 Passed, 0 Failed.
     - Total: 183 Passed, 0 Failed (100% PASS).
   - Independent adversarial stress harness `.agents/teamwork/sub_orch_m4/reviewer_2/stress_test.ps1`: 16 Passed, 0 Failed (100% PASS).
   - `smoke_test.ps1`: 18 Passed, 0 Failed.
   - `challenger1_empirical_stress.ps1`: 31 Passed, 0 Failed.
   - `challenger2_m3_stress.ps1`: 11 Passed, 0 Failed.

---

## 2. Logic Chain

1. **Visual Stability & Hit Testing (Observations 1 & 2)**:
   - When interactive UI elements visually displace on press down (`Offset(0, 0.75f)`), if the hit rectangle is offset along with the drawing path, the cursor can fall outside the boundary near the top edge, causing high-frequency hit toggling (jitter).
   - Registering `Hit(b, ...)` with un-shifted coordinates before calling `b.Offset(0, 0.75f)` guarantees that the hit-test bounds remain stationary while the visual surface sinks.
   - The addition of `OnMouseLeave` resets (`pressId = null`, `pressedId = null`) and `OnMouseMove` button state validation (`e.Button == MouseButtons.None`) guarantees that releasing the mouse button outside the window or dragging across edges immediately releases any pressed state.

2. **Accessible Contrast (Observation 4)**:
   - Hardcoded `BadgeRed` previously used pure white text in all modes, yielding poor contrast in dark theme ($2.74:1$).
   - The dynamic color selector `p.T.IsDark ? p.T.Bg : Color.White` switches to dark text (`#000000`) in dark mode, boosting contrast to $7.66:1$, while maintaining white text in light mode ($5.69:1$). Both modes exceed WCAG AA ($\ge 4.5:1$).

3. **Mini Geometry Precision (Observation 3)**:
   - Expanding `MiniDotR` from 1.7px to 2.5px produces an area of $19.635\text{ px}^2$, fulfilling the $\ge 19.6\text{ px}^2$ specification.
   - Setting `right = dot ? w - 16 : w - 12` ensures the progress line ends at $X = 48.0\text{px}$, leaving a $4.5\text{px}$ clearance gap before the dot's left edge at $X = 52.5\text{px}$.
   - Centering the $4.0\text{px}$ track in the $8.0\text{px}$ container creates identical $2.0\text{px}$ top and bottom margins, ensuring vertical visual alignment.

4. **Calendar Navigation Robustness (Observation 5)**:
   - Calendar date indexing `IndexOf(id, 'd')` encodes and decodes full `YYYYMMDD` integers, avoiding string splits.
   - Month offset calculation `(clicked.Year - currShown.Year) * 12 + (clicked.Month - currShown.Month)` correctly evaluates negative and positive jumps across year boundaries (e.g. December 31 to January 1, leap days February 29 to March 1).

5. **Integrity & Code Quality (Observations 6 & 7)**:
   - No mock objects, bypass hacks, or hardcoded return assertions exist in the source code.
   - All tests run against the newly compiled binary `Tepi.exe`.

---

## 3. Caveats

- **Invisible Hit-Test Bar**: Line 92 of `src/DockPaint.cs` uses `Color.FromArgb(1, 0, 0, 0)`. This is a deliberate, required Win32 layered window hit-testing sentinel for `UpdateLayeredWindow` and is intentionally preserved.
- **Canvas Clearing**: Calls to `g.Clear(Color.Transparent)` in double-buffered layered window rendering are standard GDI+ idiom.
- No other caveats.

---

## 4. Conclusion

The implementation of Milestone 4 (Dock & Mini Polish) is complete, robust, accessible, and free of regressions. The code satisfies all requirements in `ORIGINAL_REQUEST.md`, `PROJECT.md`, and `SCOPE.md`.

**Verdict**: **APPROVE**

---

## 5. Verification Method & Output

To independently verify this report:

1. **Compile Application**:
   ```cmd
   cmd /c build.cmd
   ```
   *Expected Output*: `Build OK: D:\PROJECT\Other\tepi\Tepi.exe`

2. **Execute Full E2E Test Suite**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1
   ```
   *Expected Output*: Tier 1 (78/78), Tier 2 (105/105), 100% PASS.

3. **Execute Reviewer 2 Independent Adversarial Stress Test**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .agents/teamwork/sub_orch_m4/reviewer_2/stress_test.ps1
   ```
   *Expected Output*: `ALL ADVERSARIAL STRESS CHECKS PASSED!` (16 checks).

4. **Inspect Source Files**:
   - `src/DockCal.cs`: lines 33-55, 78-83, 113-118, 142-147, 170-188, 198-206, 230-239.
   - `src/DockSheet.cs`: lines 322, 336, 401, 472-477.
   - `src/Mini.cs`: lines 17, 392, 401, 409-414, 435, 478, 487.
   - `src/DockPaint.cs`: lines 214-224, 237-250, 260-268, 650-657.
   - `src/DockCard.cs`: lines 369-373, 412-415.

5. **Invalidation Conditions**:
   - Modifying `Badge` in `src/DockPaint.cs` to use hardcoded white text on dark themes.
   - Reordering `Hit(b, ...)` calls to occur after `b.Offset(0, 0.75f)`.
   - Modifying `MiniDotR` below 2.5 or `MiniTrackThick` away from 4.0.
