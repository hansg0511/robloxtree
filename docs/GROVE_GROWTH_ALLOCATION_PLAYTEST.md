# Grove growth allocation — two-second fast playtest

Branch: `feature/grove-ironwood-bamboo-growth-fix` (existing draft PR #7).

## Current rules

- **Global visual cadence:** `GroveGrowthRules.SECONDS_PER_VISUAL_STEP = 2` for rapid Studio iteration. This is NOT intended to be the final economy pace.
- **Step count derived from actual rolled size:** `StepsForSize(size) = clamp(round(BASELINE_STEPS_AT_SIZE_ONE × size), MIN_VISUAL_STEPS, MAX_VISUAL_STEPS)`, with provisional baseline 6, minimum 3 and maximum 18.
- **Growth duration derived from steps:** `DurationForSize(size) = StepsForSize(size) × SECONDS_PER_VISUAL_STEP`. No independent maturity-time table or fixed 40-step denominator.
- Examples: 0.7× = 4 steps / 8 seconds; 1.0× = 6 steps / 12 seconds; 1.5× = 9 steps / 18 seconds; 2.0× = 12 steps / 24 seconds.
- **New planting:** starts in its initial stump visual state and reaches maturity after the size-derived duration.
- **After harvest:** the 2.6-second falling-tree cinematic is protected by a separate `STUMP_SECONDS = 4` hold. The new tree then starts the size-derived sequence. An ordinary 1.0× regrowth therefore takes about 16 seconds from harvest to maturity (4 + 12).
- The server checks maturity/harvest every second, while the visual geometry only changes at two-second milestones. All nearby players see the server-replicated growth.
- **Existing planted trees** retain their saved `PlantedAt` and `MaturesAt`. They are not restarted or retimed. Legacy deadlines that do not divide evenly into two seconds still mature at their originally recorded timestamp.
- `MaturesAt` remains the only server-authoritative maturity and harvesting gate.

## Growth allocation

- `Trees/GroveGrowthAllocation.luau` builds a normalized growth plan **once** from the mature model: trunk 0–50%; branches 50–80%; leaves 68–100%.
- A trunk with two unequal Pieces is allocated by real height. Huge Parts grow from the bottom; no requirement to manually create a Part per visual step.
- Branches grow sequentially from their base along local axes. Leaves expand in staggered clusters.
- The already-approved five-cane Bamboo clump remains synchronized as one visual bundle.
- Trunk and branch visual proxies do not move the real welded/harvest Parts. Proxies are destroyed when full native Parts are shown.
- For later irregular plants, authors can specify `GroveGrowthRole` (`trunk`,`branches`,`leaves`), `GroveGrowthOrder` (number), `GroveGrowthAxis` (`X`,`Y`,`Z`), `GroveGrowthDirection` (+1/-1), and optional `GroveGrowthStart`/`GroveGrowthFinish`. No procedural mesh cutting is implemented.

## Studio verification (before merge)

1. Pull the same branch and run `rojo serve default.project.json`.
2. Plant an ordinary-size Oak. It should finish in roughly 12 seconds with **six visible transitions**, around two seconds apart.
3. Plant smaller/larger Grove trees and inspect `GroveGrowthVisualTotalSteps` on the model. Their step counts should follow their **actual rolled size**, not always remain six.
4. Watch Ironwood bottom-to-top trunk growth and the Oak's slanted branches and leaf blocks. No whole huge log should suddenly appear; mature geometry should match the source forest tree.
5. Watch all five Bamboo stalks rise together from five thin stumps.
6. Harvest and regrow twice. Check the brief **four-second stump** remains during the falling cinematic, then growth resumes and produces exactly one protected unique log per harvest.
7. In a two-player Studio test, the observer should see the same visual growth; only the owner can harvest.
8. Run each regression in the **SERVER Command Bar**: `tests/GroveGrowthRules.smoke.luau`, `tests/GroveGrowthAllocation.smoke.luau`, `tests/GroveStageVisuals.smoke.luau`, `tests/GroveIronwoodBambooGrowth.smoke.luau`, `tests/GroveOakFoliageGrowth.smoke.luau`, and `tests/GroveLargeTrunkGrowth.smoke.luau`.

## Limitations

- Six discrete updates cannot display ten intermediate stages. They sample the same normalized growth plan with fewer transitions; tiny decorative parts may still pop in.
- The species-specific aesthetic and growth allocation windows remain prototype art decisions, not a final botanical model.
- To adjust testing speed, change `SECONDS_PER_VISUAL_STEP`. To change the number of visual transitions, tune `BASELINE_STEPS_AT_SIZE_ONE` and the min/max limits. No manual Part timing redistribution should be needed.
- This work has been checked through GitHub source review only. **Studio execution and multiplayer playtest are still required before merging PR #7.**
