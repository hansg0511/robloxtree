# Grove growth allocation — first implementation

Branch: `feature/grove-ironwood-bamboo-growth-fix`. Adds commits to **existing draft PR #7**, not a new branch/PR.

## Goal

A small plant finishes quickly; a bigger plant grows over more equally spaced updates. No fixed 40-step intermediate animation, no manually specified six-step vs. twenty-four-step geometry, no continuous per-frame server resizing.

**Authoritative timeline**
- `GroveGrowthRules.SECONDS_PER_VISUAL_STEP = 5` (global).
- `GroveGrowthRules.MATURITY_SECONDS = 30` is the **baseline at actual rolled scale 1.0**.
- New cycles compute `DurationForSize(CurrentSizeScale)`: baseline × actual size, rounded to the nearest 5 seconds, bounded to 15–90 seconds (temporary balance settings).
- This gives 0.7-size = 20 seconds / 4 updates; 1.0 = 30 seconds / 6 updates; 2.0 = 60 seconds / 12 updates.
- The server continues to poll every second for status/harvest eligibility, but `VisualProgress` only changes at five-second boundaries. Other players see the replicated geometry.
- **Existing planted trees:** their persisted `PlantedAt` and `MaturesAt` are honored. They are NOT restarted or retimed on load.
- At step zero, the stump is visible. At step one the stump hides and visible growth begins. After a harvest, that step-zero hold corresponds to the existing five-second stump period.
- `MaturesAt`, not appearance, remains the only server-authoritative maturity/harvest gate.

**Allocation once per growth cycle**
- `Trees/GroveGrowthAllocation.luau` allocates a generic normalized growth plan. Defaults: trunk 0–50%, branches 50–80%, foliage 68–100%.
- Structural trunk Parts are allocated according to their real height spans: a 30-stud trunk split as 10 + 20 studs will show the first 10 studs at the first of three trunk milestones and the next 10 at the second. The author does not need to split geometry into three Parts.
- Slanted branches extend along their local Y axis; Ironwood boughs along local X. Branches consume their group window in ascending attachment/height order.
- Leaf clusters start in staggered lower-to-upper order and expand toward their final sizes. The last leaf reaches full size at maturity.
- **Bamboo exception:** its five stalks remain one synchronized bundle so the previously approved clump doesn't become five sequential whole-cane pops.
- Visual wood uses temporary anchored, non-collidable Parts; originals retain their welds/collision. Temporary copies are destroyed when their full native Part becomes visible.
- Future plants can supply `GroveGrowthRole` (`trunk`, `branches`, `leaves`), `GroveGrowthOrder` (number), `GroveGrowthAxis` (`X`,`Y`,`Z`), `GroveGrowthDirection` (`-1`/`1`) and optional `GroveGrowthStart`/`GroveGrowthFinish` fractions. Simple parts use name/folder inference.
- An irregular MeshPart can be extended as one visual proxy; whether it looks good when squeezed is an art decision. No procedural mesh cutting or stage-swapping has been added.

## Studio test (required before merge)

1. Pull the **same** `feature/grove-ironwood-bamboo-growth-fix` branch, run `rojo serve default.project.json`.
2. Plant an Oak whose rolled actual size is close to 1.0. It should mature in ~30 seconds with six visible growth transitions five seconds apart, not 40 rapid visual jumps.
3. Check a smaller and a bigger tree's `GroveMaturesAt - GrovePlantedAt` and `GroveGrowthVisualTotalSteps` attributes: bigger should take longer and have more visual steps.
4. Inspect an Ironwood lower→middle→top: each should extend upward according to the vertical height it spans, not appear as full logs.
5. Inspect five Bamboo stalks: they should still grow together from their five slender stumps, then show their original adult models.
6. Inspect the Oak leaves, bark accents and slanted branches. Confirm no floating decorations, and mature appearance is unchanged.
7. Harvest and regrow at least twice. One protected UID log per harvest, owner-only E interaction, cinematic and regrowth should behave as before.
8. Start a two-player Studio test: the non-owner should see the same growth steps and **must not** gain owner-only harvest access.
9. In Studio SERVER Command Bar, execute these regression tests individually:
   - `tests/GroveGrowthRules.smoke.luau`
   - `tests/GroveGrowthAllocation.smoke.luau`
   - `tests/GroveStageVisuals.smoke.luau`
   - `tests/GroveIronwoodBambooGrowth.smoke.luau`
   - `tests/GroveOakFoliageGrowth.smoke.luau`
   - `tests/GroveLargeTrunkGrowth.smoke.luau`

## Deliberate limits

- Six discrete visual updates means there cannot be ten distinct observed size transitions. The allocator uses proportional growth windows to make those six transitions useful; tiny decorative parts may still reveal in one step.
- Server-side visuals replicate to all players; very high populations may later benefit from client-side interpolated presentation, but that is **not** part of this prototype.
- These are placeholder size/duration values, not finalized economy balance. If desired, change only the baseline/limits and `SECONDS_PER_VISUAL_STEP`, not individual part timelines.
- GitHub source review cannot run Roblox Studio. Keep draft PR #7 open until Studio playtests pass.
