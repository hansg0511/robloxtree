# Grove Growth — Ironwood & Bamboo Fixes (Oak unchanged)

> **Historical playtest guide.** Timing, animation phases, and the smoke-test expectations described below have been superseded by [`GROVE_GROWTH_ALLOCATION_PLAYTEST.md`](GROVE_GROWTH_ALLOCATION_PLAYTEST.md). Use the new guide for current behavior: five-second milestones, size-dependent durations, sequential allocation and Bamboo's five-cane bundle.

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
- All five canes now grow upward through **bottom-anchored height resizing** of one temporary visual Part per cane, from ~12% to ~62% of growth. They move together; no sequential full-height pops and no 30 temporary segments.
- At ~62%, the expanding visual copies are replaced by the exact original mature bamboo stalk parts. Nodes and foliage still appear progressively.
- Temporary copies are anchored, collisionless, and **not welded to the original model**; they never generate actual materials or affect harvest behavior.

**Oak bark timing follow-up:** The forest procedural Oak may have thin warm/recessed bark-accent parts assigned separately from the genuine Core section underneath. Those accents now wait until **all supporting core parts from the same authored harvest section are visible**, plus one growth step. This fixes early floating-looking wood strips without changing the approved Oak trunk-and-branch progression.

**Leaf growth follow-up:** Each existing cubic/cuboid foliage part now expands **in place** from a little block to its original mature size over ~17% of the growth cycle (~6–7 ticks). Individual starts are staggered, and they finish before maturity. This uses `BasePart.Size`, not extra leaf pieces; it does not alter leaf appearance when fully grown. At 45-second maturity and a 1-second server tick, the visible change is stepwise. Smooth easing remains a future polish item.

**Structural growth follow-up:** Large Oak/Ironwood trunk sections and major branches now extend from their local bases using a temporary, collisionless visual copy of the original Part. The copy grows by changing its `Size` and `CFrame`, leaving the original welded/anchored model geometry intact. When it reaches its full length, the original Part becomes visible and the copy is hidden. This works even for a giant trunk made from just two enormous pieces. Procedural Oak branches (local Y) and Ironwood horizontal boughs (local X) grow along their correct orientations. Oak bark accents are delayed until their *full* supporting trunk section finishes expanding.

**Multiplayer:** The growth presentation is updated by the **server** (existing ~1-second Grove tick) inside replicated Workspace models. All nearby players see the same bottom-anchored growth; nothing is exclusive to the tree owner. Interpolation for truly fluid per-frame animation remains a future polish task, without making harvest or growth client-authoritative.

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
8. With a second Studio client standing nearby, watch a Grove tree grow and confirm both players see the same increasing trunk, branches and leaves.
9. Paste `tests/GroveIronwoodBambooGrowth.smoke.luau`, `tests/GroveStageVisuals.smoke.luau`, `tests/GroveOakFoliageGrowth.smoke.luau` and the stress case `tests/GroveLargeTrunkGrowth.smoke.luau` into the Studio **SERVER Command Bar**. The last test simulates a 120-stud tree with only two huge wood Parts and checks their bottom positions stay fixed.

## Caveats and polish

- This is **bottom-anchored growth in server-replicated steps** (roughly one update per second), not smooth per-frame animation. Optional client-side interpolation for all observers can be added later. No huge number of extra segments are created.
- The thin bamboo stumps reflect the actual next-cycle size.
- Hidden Ironwood bark studs are a visual workaround pending better authored bark details. Forest Ironwood's decorations are unaffected.
- Source code can be reviewed through GitHub, but **Roblox Studio execution cannot be performed here**. Keep the branch a draft until its playtest passes.
- See `docs/PROTOTYPE_POLISH_BACKLOG.md` for the other postponed polishing work.
