# Grove Growth — Ironwood & Bamboo Fixes (Oak unchanged)

Base: `feature/grove-progressive-growth-forest-oak`
Branch: `feature/grove-ironwood-bamboo-growth-fix`

This is a scoped prototype correction following the 2026-11-18 Grove playtest. **Oak's accepted growth sequencing is intentionally unchanged**.

## What caused the problems

- **Ironwood:** The 3 trunk pieces were previously scheduled by position and a little deterministic jitter. Because the top and middle pieces overlap vertically, the third piece could appear first. Separate tiny `BarkStud` cylinders also appeared without the trunks supporting them, resembling floating brown particles.
- **Bamboo:** The full-height `BambooCore` and four `BambooStalk*` parts were unlocked independently. The result was one whole cane popping in, followed by the next—not a clump growing together. The generic Grove stump was one disproportionately thick square block.
- **Oak:** The approved Forest 1 procedural Oak path works and did not need redesign.

## Fix

**Ironwood**
- Explicit trunk build order: `Bark` lower at ~8% → `BarkBrick1` middle at ~21% → `BarkBrick2` upper at ~32%.
- Boughs follow at ~47% and ~57%, then the existing canopy reveal.
- Source-authored decorative `BarkStud` dots are hidden on **Grove Ironwood only** for this prototype, eliminating floating-looking dots. This does not modify wild Ironwood models or the core tree silhouette. The final bark-detail art remains on the polish backlog.

**Bamboo**
- Initial stump is **five small, slim cut culms** matching the positions and thicknesses of the final five mature canes.
- All five canes now progress upward through **six layers each** on the same timeline, from ~12% to ~56% of growth. Each cane shows layer one before layer two—there are no sequential full-height pops.
- At ~62%, the assembled layer visuals switch to the same full mature bamboo stalk parts, keeping the final model and its interactions identical. Nodes and foliage continue appearing in their own height/late-canopy phases.
- Temporary visible segments are cosmetic only, welded to the original model root. They don't collide, harvest or add materials, and are hidden once their mature stalks are visible.

**Oak bark timing follow-up:** The forest procedural Oak may have thin warm/recessed bark-accent parts assigned separately from the genuine Core section underneath. Those accents now wait until **all supporting core parts from the same authored harvest section are visible**, plus one growth step. This fixes early floating-looking wood strips without changing the approved Oak trunk-and-branch progression.

**Leaf growth follow-up:** Each existing cubic/cuboid foliage part now expands **in place** from a little block to its original mature size over ~17% of the growth cycle (~6–7 ticks). Individual starts are staggered, and they finish before maturity. This uses `BasePart.Size`, not extra leaf pieces; it does not alter leaf appearance when fully grown. At 45-second maturity and a 1-second server tick, the visible change is stepwise. Smooth easing remains a future polish item.

**Unchanged:** Grove genetics, per-cycle actual size, mutation inheritance, regrowth timers, E-harvest cinematic, owner-only checks, one protected log per harvest, Forge and processor logic.

## Switch to the new branch

```bash
git status
git fetch origin
git switch --track origin/feature/grove-ironwood-bamboo-growth-fix
rojo serve default.project.json
```

If the feature branch already exists locally: `git switch feature/grove-ironwood-bamboo-growth-fix` and `git pull --ff-only`.

## Studio playtest

1. **Oak regression:** Plant/regrow an Oak. Confirm the approved stump → trunk → branches → cubes/cuboid leaves progression looks the same.
2. **Ironwood:** Watch lower trunk, then middle, then upper. There should be no upper third log floating before the middle, and no tiny dotted bark "particles" around the growing tree.
3. **Bamboo:** Early growth shows five narrow culm stumps (not a fat square). Observe all **five canes** gaining height at each step together. At maturity the existing full Bamboo clump remains visible and E harvesting works.
4. After each mature harvest, confirm the original E cinematic runs and **exactly one** unique saved log is credited; regrowth repeats the same patterns.
5. Check multiplayer visibility, owner-only harvest access, and full saved-storage handling.
6. Watch Oak's thin warm bark accents: no orange texture strip should appear before the supporting trunk core.
7. Watch individual leaf cuboids grow gradually rather than materializing instantly at full size; they should finish at the normal mature shape.
8. Paste the contents of `tests/GroveIronwoodBambooGrowth.smoke.luau`, `tests/GroveStageVisuals.smoke.luau`, and `tests/GroveOakFoliageGrowth.smoke.luau` into Roblox Studio's **SERVER Command Bar**. They build read-only 0%–100% preview models and check the order, stump widths and synchronized segments.

## Caveats and polish

- This is stepwise visual growth, not continuously stretched stems. The segments are intentionally chunky for a first prototype. Their transitions can be smoothed later.
- The thin bamboo stumps reflect the actual next-cycle size.
- Hidden Ironwood bark studs are a visual workaround pending better authored bark details. Forest Ironwood's decorations are unaffected.
- Source code can be reviewed through GitHub, but **Roblox Studio execution cannot be performed here**. Keep the branch a draft until its playtest passes.
- See `docs/PROTOTYPE_POLISH_BACKLOG.md` for the other postponed polishing work.
