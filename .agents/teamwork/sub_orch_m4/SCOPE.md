# Scope: Milestone 4 — Dock & Mini Polish

## Mission
Perfect the visual interface, design token compliance, interactive feedback, and glanceability of the Dock and Mini edge indicator components (`src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, `src/Mini.cs`).

## Target Source Files (Exclusive Write Boundaries)
- `src/DockPaint.cs`: Dock surface rendering, rim lights, sheen, unread badge pills tokenization
- `src/DockCard.cs`: Dock preview flyouts, borders, close buttons, token alignment
- `src/DockSheet.cs`: Dock bottom sheet, flyout panel tokens and radius standardization
- `src/DockCal.cs`: Calendar flyout module, add pressed visual state handling to buttons
- `src/Mini.cs`: Minimal edge sliver, notification dot radius ($\ge 2.5$px) and status track thickening

## Feature Requirements & Acceptance Criteria
1. **Dock Hardcoded Colors Tokenization**:
   - In `src/DockPaint.cs` and `src/DockCard.cs`:
     - Tokenize `BadgeRed` and `BadgeRedSoft` to semantic theme tokens (`p.T.Negative`, `Ink.Base.Negative`, `p.T.Fill`).
     - Tokenize hardcoded white rim light (`Color.FromArgb(..., 255, 255, 255)`) to theme tokens: `p.T.Highlight` and `p.T.Text`.
     - Ensure unread badges maintain WCAG AA $\ge 4.5:1$ contrast in both light and dark themes.
2. **Dock Module Interactive Pressed States**:
   - In `src/DockCal.cs`:
     - Add visual feedback for mouse click down-state (`pressed` state) on interactive buttons (prev/next month, day buttons, etc.).
     - Provide tactile displacement (`r.Offset(0, 0.75f * s)`) or deeper background tint matching `KitButton` conventions.
3. **Mini Indicator Visual Salience**:
   - In `src/Mini.cs`:
     - Increase the notification indicator dot radius from legacy 1.7px to $\ge 2.5$px (area $\ge 19.6\text{ px}^2$) so it is clearly perceptible on high-DPI and standard displays.
     - Thicken the background status progress track for optimal visual glanceability.
     - Ensure idle and active indicator colors achieve $\ge 3:1$ contrast against host monitor border.

## Orchestration Procedure (Iteration Loop 2B)
1. **Survey / Explore**: Spawn 3 Explorers (`teamwork_explorer` / `teamwork_spec_miner`) to analyze target files, map line numbers, and recommend exact code replacements.
2. **Worker Implementation**: Spawn 1 `teamwork_worker` with mandatory integrity warning to implement changes, compile with `build.cmd`, and run test suites.
3. **Reviewers**: Spawn 2 `teamwork_reviewer` to review correctness, accessibility, and visual compliance.
4. **Challengers**: Spawn 2 `teamwork_challenger` to verify Dock badge contrast, rim lighting adaptation across themes, calendar button pressed states, and Mini dot/track geometry.
5. **Auditor**: Spawn 1 `teamwork_auditor` for binary forensic integrity verification.
6. **Gate Evaluation**: Evaluate `GATE_STATUS.md`. Gate passes ONLY if build succeeds, all reviewers approve, all challengers confirm, and auditor is CLEAN.
