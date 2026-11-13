# Synthesis: Milestone 4 — Dock & Mini Polish

## Executive Summary
All three Explorers have concluded their technical investigations across the scope files (`src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, `src/Mini.cs`). The recommendations form a unified, coherent, and verified implementation plan that directly fulfills all requirements and acceptance criteria in `SCOPE.md` and `ORIGINAL_REQUEST.md`.

---

## 1. Task 1: Dock Hardcoded Colors Tokenization (`src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`)
### Source: Explorer 1 (`sub_orch_m4\explorer_1\handoff.md`)
1. **Unread Badge (`src/DockPaint.cs:648, 658-659`)**:
   - Eliminate hardcoded `BadgeRed` = `#D93025`.
   - Replace with `p.T.Negative`.
   - **WCAG AA Contrast Resolution**:
     - In Dark mode, `p.T.Negative` is `#F07878` ($L = 0.3331$). White text on `#F07878` yields only **2.74:1** (FAILS WCAG AA). Dark text (`p.T.Bg`) yields **7.66:1** (PASSES).
     - In Light mode, `p.T.Negative` is `#BE3232` ($L = 0.1346$). White text yields **5.69:1** (PASSES).
     - Adaptive text formula: `p.T.IsDark ? p.T.Bg : Color.White` guarantees $\ge 4.5:1$ across all themes.
     - Badge pill on Dock surface: Dark mode yields **7.66:1**, Light mode yields **5.22:1** (both $\ge 4.5:1$).
   - Halo ring `Ink.A(Ink.Base.Bg, 0.55f)` updated to `Ink.A(p.T.Bg, 0.55f)`.
2. **Close Button on Preview Card (`src/DockCard.cs:411-415, 434`)**:
   - Eliminate `BadgeRedSoft` definition.
   - Replace with `p.T.Negative`.
   - Close icon glyph (`\uE711`) tokenized to `hot == "x" + id ? (p.T.IsDark ? p.T.Bg : Color.White) : p.T.Sub`.
3. **White Rim Lights & Sheen Gradients**:
   - `src/DockPaint.cs`:
     - `RimLight`: `LinearGradientBrush` and color blend stops tokenized to `p.T.Highlight` (`Color.FromArgb(Ink.Light ? 170 : 120, p.T.Highlight)`, etc.).
     - `Sheen`: Gradient top stop `Color.FromArgb(Ink.Light ? 80 : 24, p.T.Highlight)`, bottom stop `Color.FromArgb(0, p.T.Highlight)`. Radial hover glow `Color.FromArgb((int)(hover.Value * (Ink.Light ? 80 : 40)), p.T.Highlight)`.
     - `Rim`: Linear gradient stops tokenized to `Color.FromArgb(..., p.T.Highlight)`.
   - `src/DockCard.cs`: Card sheen (line 369) and border path (line 372) tokenized to `p.T.Highlight`.
   - `src/DockSheet.cs`: Sheet sheen (line 267) and border path (line 275) tokenized to `p.T.Highlight`.

---

## 2. Task 2: Dock Module Interactive Pressed States (`src/DockCal.cs`, `src/DockSheet.cs`)
### Source: Explorer 2 (`sub_orch_m4\explorer_2\handoff.md`)
1. **Interactive Button Feedback in `src/DockSheet.cs`**:
   - Add mouse lifecycle cleanup in `OnMouseLeave` (`pressId = null;`) and `OnMouseMove` (`if (e.Button == MouseButtons.None) pressId = null;`).
   - Add tactile displacement to `GlassSheet.Button`: `if (down) r.Offset(0, 0.75f);`.
   - Add protected helper `Down(string id) { return pressId == id && hotId == id; }`.
2. **Interactive Elements in `src/DockCal.cs`**:
   - Add `pressedId` field and `DateTime? selectedDay` property.
   - Add `Down(string id)` and `Pressed(string id)` helpers, plus `OnMouseDown`, `OnMouseUp`, and `OnMouseLeave` overrides.
   - "Hapus semua" (`clear`) button: Add `Down("clear")` check, `b.Offset(0, 0.75f)` tactile displacement, `p.T.FillPressed`, and vertically centered text.
   - Notification item delete (`x{i}`) button: Add `Down(del)` check, `0.75f` Y-offset, `p.T.FillPressed`.
   - Month / "today" jump header: When `month != 0`, register hit target, render hover pill `p.T.FillHover` / pressed pill `p.T.FillPressed`, and tactile displacement.
   - Day cells: Make interactive by registering `Hit` with `did = "d" + (day.Year * 10000 + day.Month * 100 + day.Day)`. When hovered, show `p.T.FillHover`; when pressed, show `p.T.FillPressed` (or `Ink.Mix(Accent, OnAccent, 0.22f)` for today) and `0.75f` tactile displacement. In `Clicked()`, clicking updates `selectedDay` and jumps month if needed.
   - "Senyap" (`quiet`) toggle: When pressed, apply tactile offset `b.Offset(0, 0.75f)` and deep accent tint `Ink.Mix(p.T.Accent, p.T.OnAccent, 0.22f)` when on, or `p.T.FillPressed` when off.

---

## 3. Task 3: Mini Indicator Visual Salience (`src/Mini.cs`)
### Source: Explorer 3 (`sub_orch_m4\explorer_3\handoff.md`)
1. **Notification / Privacy Indicator Dot Radius**:
   - Define `const float MiniDotR = 2.5f;`.
   - Update `p.Circle(w - 9, h / 2, MiniDotR, ...)` across all 3 call sites (`MiniClockOn`, plain sliver, and `MiniFace`).
   - Area increases from legacy $9.08\text{ px}^2$ to **$19.635\text{ px}^2$** ($\ge 19.6\text{ px}^2$).
   - Respects `g.ScaleTransform(scale, scale)` already active on `g`, ensuring no double-scaling trap.
   - Adjust right margin in plain sliver: `right = dot ? w - 16 : w - 12;` to guarantee $4.5\text{ px}$ clearance.
2. **Status Progress Track Thickening**:
   - Define `const float MiniTrackThick = 4f;`.
   - Horizontal track: `MiniLine(new RectangleF(left, cy - MiniTrackThick / 2, right - left, MiniTrackThick), v, now)`.
   - Vertical track (`OnSide`): `RectangleF(cx - MiniTrackThick / 2, 8, MiniTrackThick, h - 16)`.
   - Capsule corner radius = $\text{Height} / 2 = 2.0\text{ px}$.
   - Exact $2.0\text{ px}$ top/bottom padding inside the 8px container bounds.
3. **Contrast Compliance ($\ge 3:1$)**:
   - Replace legacy `p.T.Quaternary` (18% alpha, failing with 1.51:1 contrast) with `p.T.Faint` (58% alpha), elevating contrast against black/charcoal monitor bezels to **6.39:1** (dark mode) and **5.19:1** (light mode).
   - In `Breath(...)`, adjust base alpha to `0.38f + 0.32f * k` so breathing animations never drop below $3.17:1$.
   - Active dot colors (`Negative` and `Accent`) achieve $3.52:1$ to $19.26:1$ contrast against host monitor border.

---

## 4. Implementation Directives for Worker
The Worker will apply all verified diffs across the target files:
- `src/DockPaint.cs`: Diffs DP-1, DP-2.
- `src/DockCard.cs`: Diffs DC-1, DC-2.
- `src/DockSheet.cs`: Diffs DS-1, DS-2.
- `src/DockCal.cs`: Diff DCAL-1.
- `src/Mini.cs`: Diff MINI-1.
Then compile with `build.cmd` and run the smoke test harness.
