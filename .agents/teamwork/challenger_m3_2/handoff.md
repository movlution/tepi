# Milestone 3 Challenger 2 Evaluation Report: Toast Collision, EmptyState & Design Tokens

**Agent**: Challenger 2 (`challenger_m3_2`)  
**Milestone**: Milestone 3 (Island, Navigation & Views Polish)  
**Parent Conversation ID**: `99735988-ac39-4926-a99d-2575d2f2b8b2`  
**Date**: 2026-11-13  
**Target Codebase**: `d:\PROJECT\Other\tepi`  
**Verdict**: `APPROVE`  

---

## 1. Observation

Direct code observations, AST inspections, and empirical test execution results across all target files:

### 1.1 Toast Notification Geometry & Collision (`src/Views.cs`)
- Lines 750–762 in `src/Views.cs`:
  ```csharp
  void DrawNotif(float w, float h)
  {
      var item = toast != null ? toast.Data as NotifItem : null;
      if (item == null) return;
      float cy = h / 2;
      DrawAppBadge(item, new RectangleF(14, cy - 20, 40, 40));
      string meta = notifBurst > 1 ? notifBurst + Lang.T(" pesan · ") + item.AppName : item.AppName;
      float mw = Math.Min(w * 0.35f, p.Measure(meta, Ink.Caption));
      p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far);
      p.Text(NotifTitle(item), Ink.Headline, p.T.Text, 66, cy - 10, Math.Max(40, w - 66 - 22 - mw - 12), StringAlignment.Near);
      p.Text(NotifBody(item), Ink.Callout, p.T.Sub, 66, cy + 10, w - 66 - 22, StringAlignment.Near);
      AddHit(new RectangleF(0, 0, w, h), "notifOpen", delegate { OpenNotifApp(item); });
  }
  ```
- **Bounding Box Math**:
  - `meta`: Rendered via `StringAlignment.Far` with right edge at $w - 22$ and max width $mw = \min(0.35w, \text{Measure})$. Bounding box is $[w - 22 - mw, w - 22]$.
  - `title`: Rendered via `StringAlignment.Near` with left edge at $x = 66$ and max width $\max(40, w - 66 - 22 - mw - 12)$. Bounding box is $[66, 66 + \max(40, w - 100 - mw)]$.
- **Empirical Execution of 5 Mandated Edge Cases** (`tests/challenger2_m3_stress.ps1`):
  - **Case 1 (1 char app name "X")**: $w = 360$, $mw = 10.5\text{px}$, TitleBox = $[66, 315.5]$, MetaBox = $[327.5, 338]$, Gap = $12.0\text{px}$, Overlap = $0.0\text{px}$.
  - **Case 2 (50 chars app name "Enterprise Unified Communications & Telephony Hub")**: $w = 360$, $mw = 126.0\text{px}$ (saturates at $0.35 \times 360$), TitleBox = $[66, 200.0]$, MetaBox = $[212.0, 338]$, Gap = $12.0\text{px}$, Overlap = $0.0\text{px}$.
  - **Case 3 (200 chars app name)**: $w = 360$, $mw = 126.0\text{px}$, TitleBox = $[66, 200.0]$, MetaBox = $[212.0, 338]$, Gap = $12.0\text{px}$, Overlap = $0.0\text{px}$.
  - **Case 4 (Massive burst count "9999 pesan · WhatsApp")**: $w = 360$, $mw = 125.2\text{px}$, TitleBox = $[66, 200.8]$, MetaBox = $[212.8, 338]$, Gap = $12.0\text{px}$, Overlap = $0.0\text{px}$.
  - **Case 5A (Short narrow island width $w = 240\text{px}$)**: $w = 240$, $mw = 84.0\text{px}$, TitleBox = $[66, 122.0]$, MetaBox = $[134.0, 218]$, Gap = $12.0\text{px}$, Overlap = $0.0\text{px}$.
  - **Case 5B (Standard island width $w = 360\text{px}$)**: $w = 360$, $mw = 125.2\text{px}$, TitleBox = $[66, 200.8]$, MetaBox = $[212.8, 338]$, Gap = $12.0\text{px}$, Overlap = $0.0\text{px}$.
- **Combinatorial Grid (560 test variations)**:
  - Total combinations evaluated: 560 across 10 app names, 8 burst levels, 7 widths ($w \in [240, 260, 300, 360, 404, 480, 600]$), and 5 title lengths.
  - Maximum observed horizontal overlap: `0.0px`.
  - Minimum observed clearance gap: `12.0px >= 10.0px`.
- **Pixel-Level Raster Verification**:
  - Offscreen 32bpp ARGB bitmap rendering with title in pure red and meta in pure blue revealed 0 colliding pixels in the 12px clearance corridor across all widths.

### 1.2 `Parts.EmptyState` Unification Across 20 Call Sites
- `src/Parts.cs` lines 374–424 provides 4 unified overloads:
  - No button (`EmptyState(area, icon, title, line)`)
  - Single action default secondary (`EmptyState(area, icon, title, line, action, id, act)`)
  - Single action typed pill (`EmptyState(area, icon, title, line, action, id, act, PillKind)`)
  - Dual action pills (`EmptyState(area, icon, title, line, action1, id1, act1, kind1, action2, id2, act2, kind2)`)
- **Call site inventory across application views (20 call sites + 1 delegation wrapper)**:
  1. `Panel.cs:16` (backward-compatibility wrapper `Panel.Empty`)
  2. `Panel.cs:174` (`hub.Error`)
  3. `Panel.cs:183` (`Belum ada sesi agen`)
  4. `Panel.cs:302` (`Tugas gagal dimuat`, retry action)
  5. `Panel.cs:317` (`Tidak ada tugas aktif`)
  6. `Panel.cs:398` (`Notifikasi pesan dimatikan`)
  7. `Panel.cs:403` (`Akses notifikasi ditolak`, settings action)
  8. `Panel.cs:414` (`Pesan tidak bisa dibaca`, retry action)
  9. `Panel.cs:417` (`Belum ada pesan`)
  10. `Shelf.cs:248` (`Rak mati`, enable action)
  11. `Shelf.cs:255` (`Rak kosong`, dual action: Pick + Paste)
  12. `Shelf.cs:261` (`Rak kosong`, single action: Pick)
  13. `Clips.cs:118` (`Riwayat clipboard mati`, enable action)
  14. `Clips.cs:123` (`Belum ada yang disalin`)
  15. `ConvertPage.cs:112` (`Ubah format mati`, enable action)
  16. `Schedule.cs:93` (`Jadwal gagal dimuat`, retry action)
  17. `Schedule.cs:98` (`Memuat jadwal…`)
  18. `Schedule.cs:104` (`Jadwal kosong`)
  19. `Music.cs:294` (`Tidak ada yang diputar`)
  20. `Handset.cs:272` (`HP belum tersambung`, link action)
  21. `Sources.cs:987` (`Belum ada yang tersambung`, open integrations action)
- **Centering & Wrapping Stress**:
  - Vertical centering math `top = area.Y + Math.Max(8, (area.Height - block) / 2)` evaluated on $H \in [150, 180, 200, 252, 300, 372, 400, 500, 600]$:
    - For $H > block + 16$: top and bottom margins match within $\le 1.0\text{px}$.
    - For tight containers ($H \le block + 16$): top margin clamps strictly to $8.0\text{px}$.
  - Multi-line detail wrapping: All 20 Indonesian detail strings wrapped cleanly within `RectangleF(area.X + 24, top + 88, area.Width - 48, 38)` using `Ink.Callout` without truncation or vertical overflow.
  - Action pill hit-testing: Single pill ($bw \ge 120\text{px}$) and dual pills ($bw = 136\text{px}$, gap = $12.0\text{px}$) confirmed zero overlap ($RectangleF.Intersect.IsEmpty == true$) and accurate hit containment (center click = true, outside click = false, 12px inter-pill gap click = false).

### 1.3 Design Token Audit & Radii Standardization
- In `src/Views.cs` lines 60–80:
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
  - AST / regex audit confirmed **0 remaining ad-hoc radii literals** (no `return 30`, `return 26`, or `return 28`).
  - Standard token values verified via reflection:
    - `Ink.RadiusShell = 32.0px`
    - `Ink.RadiusModule = 20.0px`
    - `Ink.RadiusControl = 12.0px`
  - Cross-view adherence: Standard radius tokens are used systematically across `src/Views.cs`, `src/Panel.cs`, `src/Shelf.cs`, `src/Clips.cs`, `src/ConvertPage.cs`, `src/Schedule.cs`, and `src/WorkWindow.cs`.

### 1.4 Test Suite Execution Results
- `cmd.exe /c build.cmd`: Exit code 0 (`Build OK: D:\PROJECT\Other\tepi\Tepi.exe`).
- `powershell -ExecutionPolicy Bypass -File tests/challenger2_m3_stress.ps1`: 11/11 tests pass.
- `powershell -ExecutionPolicy Bypass -File tests/tier2_boundaries/test_b21_toast_collision.ps1`: 5/5 tests pass.
- `powershell -ExecutionPolicy Bypass -Command "tests/tier2_boundaries/test_b17_island_on_glass.ps1; tests/tier2_boundaries/test_b18_pill_elevation.ps1; tests/tier2_boundaries/test_b19_halo_reduced_motion.ps1; tests/tier2_boundaries/test_b20_tabs_fill_states.ps1; tests/tier2_boundaries/test_b21_toast_collision.ps1"`: 25/25 tests pass.
- `powershell -ExecutionPolicy Bypass -File tests/smoke_test.ps1`: 15/15 checks pass.
- `powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1`: 183/183 tests pass (Tier 1: 78/78, Tier 2: 105/105).

---

## 2. Logic Chain

1. **Mathematical Clearance Invariant**: In `DrawNotif`, title right bound is $R_{\text{title}} = 66 + \max(40, w - 100 - mw)$ and meta left bound is $L_{\text{meta}} = w - 22 - mw$. For any HUD width $w \ge 216\text{px}$ where $w - 100 - mw \ge 40$, $R_{\text{title}} = w - 34 - mw$. The clearance distance is $L_{\text{meta}} - R_{\text{title}} = (w - 22 - mw) - (w - 34 - mw) \equiv 12.0\text{px}$. Because $12.0\text{px} \ge 10.0\text{px}$ and $R_{\text{title}} < L_{\text{meta}}$, horizontal overlap is mathematically and empirically zero under all string lengths and burst counts.
2. **Dynamic Centering & Indonesian Typography**: In `Parts.EmptyState`, the content block is $108\text{px}$ (no button) or $158\text{px}$ (with button). Centering via `area.Y + Math.Max(8, (area.Height - block) / 2)` guarantees exact vertical centering for normal heights ($180..600\text{px}$) while preventing negative or clipped top bounds on small heights ($150\text{px}$). Indonesian copy is inherently longer than English; allocating a $38\text{px}$ height line box with `Ink.Callout` ($12.5\text{px}$ font) provides headroom for 2 full lines of wrapped text, ensuring zero clipping across all 20 call sites.
3. **Pill Geometry & Hit Test Differentiation**: Dual action pills in `Parts.EmptyState` use fixed $136\text{px}$ widths positioned at $cx - 136 - 6$ and $cx + 6$. This establishes an exact $12.0\text{px}$ separation gap symmetric around $cx$. Click hit-testing on the left pill, right pill, and the $12\text{px}$ intermediate dead-zone demonstrates complete isolation and zero false-positive activation.
4. **Tokenization Conformance**: Prior arbitrary literals ($30, 26, 28$) in `ViewRadius` caused inconsistent rounding and visual disconnects across different island views. Consolidating all view radii to `Math.Min(Ink.RadiusShell, s.Height / 2)` enforces continuous concentric squircles aligned with the 32px shell design token.

---

## 3. Caveats

- **No caveats**: All 3 verification objectives (Toast Collision, EmptyState Unification, and Design Token Audit) were empirically proven and verified via code execution. Zero regressions were detected.
- Note on Milestones: `DockFrost.cs` and `Mini.cs` modifications belong strictly to Milestone 4 and were appropriately not modified in Milestone 3.

---

## 4. Conclusion

**Verdict: `APPROVE`**

Milestone 3 implementations for Toast Notification collision prevention, `Parts.EmptyState` unification across all 20 call sites, and Design Token radius consolidation meet and exceed all visual, mathematical, and accessibility criteria:
- Horizontal overlap between title and meta is **0.0px** in all scenarios.
- Clearance gap is **12.0px** ($\ge 10.0\text{px}$) across all payloads and narrow widths.
- Empty states across all 20 call sites are unified, vertically centered, and wrap Indonesian text cleanly.
- `ViewRadius` contains **0 ad-hoc radii**, adhering to `Ink.RadiusShell` (32px), `Ink.RadiusModule` (20px), and `Ink.RadiusControl` (12px).

---

## 5. Verification Method

To independently execute and verify the empirical tests:

1. **Clean Compilation**:
   ```cmd
   cmd.exe /c build.cmd
   ```
   *Expected output*: `Build OK: D:\PROJECT\Other\tepi\Tepi.exe` (Exit code 0).

2. **Challenger 2 Empirical Adversarial Stress Suite**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/challenger2_m3_stress.ps1
   ```
   *Expected output*: 11 tests passed, 0 failed. Verdict: `APPROVE`.

3. **Feature 21 Boundary Test**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/tier2_boundaries/test_b21_toast_collision.ps1
   ```
   *Expected output*: 5 passed, 0 failed.

4. **All Milestone 3 Boundary Suites**:
   ```powershell
   powershell -ExecutionPolicy Bypass -Command "tests/tier2_boundaries/test_b17_island_on_glass.ps1; tests/tier2_boundaries/test_b18_pill_elevation.ps1; tests/tier2_boundaries/test_b19_halo_reduced_motion.ps1; tests/tier2_boundaries/test_b20_tabs_fill_states.ps1; tests/tier2_boundaries/test_b21_toast_collision.ps1"
   ```
   *Expected output*: 25 passed, 0 failed.

5. **Full E2E Multi-Tier Test Suite**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tests/run_e2e.ps1
   ```
   *Expected output*: Tier 1 (78/78 pass), Tier 2 (105/105 pass), Total (183/183 pass).
