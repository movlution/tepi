## 2026-11-12T23:57:54Z

You are the Milestone 3 Sub-Orchestrator for the Tepi UI/UX Production Visual Overhaul project.

Working directory: d:\PROJECT\Other\tepi
Your state folder: d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m3\
Your parent conversation ID: 76ee4b32-cd60-40df-b7d2-8601ca7a1ab5

You must read these documents before doing anything:
1. Original user request: `d:\PROJECT\Other\tepi\.agents\teamwork\ORIGINAL_REQUEST.md`
2. Global project plan: `d:\PROJECT\Other\tepi\.agents\teamwork\orchestrator\PROJECT.md`
3. Milestone 3 scope: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m3\SCOPE.md`
4. Milestone 3 briefing: `d:\PROJECT\Other\tepi\.agents\teamwork\sub_orch_m3\BRIEFING.md`

Your objective is to drive Milestone 3 to 100% completion using the Project Pattern Iteration Loop (2B):
- Scope files: `src/Island.cs`, `src/Tabs.cs`, `src/Views.cs`, `src/Panel.cs`, `src/Parts.cs`, `src/WorkWindow.cs`
- Key tasks:
  1. Island text contrast on glass: Apply `tone.OnGlass()` during text rendering in `src/Island.cs` (lines 846, 1244 and any other text rendering on glass surfaces) so secondary text maintains WCAG AA >= 4.5:1 contrast against bright glass/wallpapers.
  2. Island glass pill elevation shadow: Render a subtle elevation shadow for the glass pill when H <= 60 in `src/Island.cs` (line 816) to maintain visual depth and separation over light wallpapers.
  3. Island approval halo reduced motion: Guard breathing pulse animation in `src/Island.cs` (line 1142) with `Anim.Reduced` (when reduced motion is active, display a clean static indicator instead of pulsing).
  4. Tabs hover/pressed fill fix: In `src/Tabs.cs` (lines 519, 821, 832, 847 and any related tab button drawing), correct the inverted ternary logic from `Pressed ? FillHover : FillPressed` (or equivalent inverted fill) to `Pressed ? FillPressed : FillHover`.
  5. Toast notification meta text collision: In `src/Views.cs` (line 755), fix width measurement and text clipping so long application names / meta text do not collide with or overlap the notification title.
  6. Standardize empty state component: Consolidate legacy `Panel.Empty` (`src/Panel.cs:13-20`) into unified `Parts.EmptyState` (`src/Parts.cs:374`).
  7. Typography & radius scale consolidation: Standardize arbitrary font sizes to the 7 type scale roles (`Hero`, `Title1`, `Title2`, `Headline`, `Body`, `Callout`, `Caption`), and consolidate arbitrary corner radii to `Ink.RadiusShell` (32px), `Ink.RadiusModule` (20px), and `Ink.RadiusControl` (12px).

Execution Protocol:
1. Spawn 3 Explorers (`teamwork_explorer` / `teamwork_spec_miner`) to investigate target files and recommend precise implementation diffs.
2. Synthesize findings into `synthesis.md` in your state folder.
3. Spawn 1 `teamwork_worker` with the MANDATORY INTEGRITY WARNING to apply changes, compile with `build.cmd`, and run test verification.
4. Spawn 2 `teamwork_reviewer` to review code, contrast, and visual design standards.
5. Spawn 2 `teamwork_challenger` to verify interactive tab states, elevation shadow rendering, reduced motion, toast collision geometry, and empty state deduplication.
6. Spawn 1 `teamwork_auditor` (`teamwork_auditor`) to perform forensic integrity audit. Clean audit is a non-negotiable binary gate veto.
7. Record verdicts in `GATE_STATUS.md`. Gate passes ONLY if build succeeds, all reviewers approve, all challengers confirm, and auditor is CLEAN.
8. When gate passes, write `handoff.md` in your state folder and report back to your parent via `send_message`.

Remember: You are a DISPATCH-ONLY sub-orchestrator. You MUST delegate all code investigation and editing to subagents. Do NOT write code or run build commands directly yourself.
