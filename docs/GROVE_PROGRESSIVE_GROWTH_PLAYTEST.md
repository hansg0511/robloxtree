# Grove — Progressive growth from the final forest tree

Branch: `feature/grove-progressive-growth-forest-oak`
Base: `feature/grove-distinct-growth-phases-prototype`

This is a **prototype** replacing the disliked fading model swaps. It preserves the server-side Grove, harvest cinematic and protected log inventory behavior.

## Why the Oak models differed

- The old Grove mature Oak used the simple `makeStarterForestTree()` model.
- The actual Forest 1 Oak uses `makeProceduralStarterOak()` when enabled in `WorldLayoutConfiguration`, otherwise `makeStarterForestHarvestOak()`.
- The Grove now calls that **same** production procedural function, with the same established fallback. Grove and forest Oaks share the final art/building system, with different seeds and size rolls.

## New growth presentation

One final full-species model is constructed per planted/regrowing tree and stays in place throughout that growth cycle. Its authoritative profile record, UID, mutations and actual size roll never depend on its visual display.

- **At first:** a visible cut stump sized from the ACTUAL next-cycle final tree trunk diameter.
- **Early growth:** the real tree's trunk/core and decorative bark parts appear bottom-up.
- **Mid growth:** branches appear in staggered order.
- **Late growth:** cubic/cuboid canopy leaf clusters appear gradually until the full species tree is present.
- **Maturity:** only when the stored `MaturesAt` time is reached does the owner get the familiar E Harvest prompt. The cinematic tree fall and one saved unique log behave as before.

No complete-model fade and no miniature mature-tree rescaling. Growth progress is split into **40 presentation steps**, advanced once per second by the existing Grove server clock. This is a prototype of additive growth, not a finished animation. Existing `stump/sapling/young/mature` status names are kept for UI and save compatibility, but visuals no longer swap those models.

The 45-second maturation and 5-second post-harvest stump hold are unchanged. `GroveGrowthRules.Progress` gives a 0–1 display fraction with the stump hold applied on regrowth. The stump's width is based on **CurrentSizeScale for this cycle**, not the sapling's max `SizePotential`—a huge stump really does predict a huge tree *this cycle*. Because the sapling's actual size rolls again after each harvest, future stumps can differ.

The growth model uses the shared production species tree for Oak, Bamboo and Ironwood. Oak's existing forest generator and cuboid leaf style remain the source of truth. Forest trees themselves are unchanged.

## Switch workspace and playtest

```bash
git status
git fetch origin
git switch --track origin/feature/grove-progressive-growth-forest-oak
rojo serve default.project.json
```

Open `BrickWorldBase.rbxl` and reconnect the Rojo Studio plugin.

1. Plant Oak and compare a mature Grove Oak directly to Forest 1. Their procedural art style and structural construction should now match, though procedural random seeds vary.
2. Watch one growth cycle: stump visible immediately; trunk appears from below; branches appear individually; many blocky leaves fill in gradually; no full-model fade.
3. Compare small and large Grove saplings/trees. The **width of the stump** must be visibly proportional to the particular tree's next growth roll. Harvest a mature tree and watch the *next* stump, which may be larger or smaller.
4. Confirm no E prompt and no axe chopping before maturity; when fully grown, E Harvest plays the **unchanged cinematic** and credits exactly **one** log.
5. Observe regrowth after harvesting. The Grove UID and genetic potential are unchanged; log origin, mutation and recorded size should still be preserved in protected storage and Forge.
6. Try a second player and confirm the growth additions are visible nearby but no foreign harvest prompt is usable.
7. Try a full protected-storage scenario: E must reject the harvest without a new growth cycle or missing log.
8. Run `tests/GroveStageVisuals.smoke.luau` from Studio SERVER Command Bar. It constructs source-owned visual previews at 0%, 22%, 50%, 80%, and 100% growth for Oak/Bamboo/Ironwood. Checks also verify larger final size means larger stump. Run `tests/GroveGrowthRules.smoke.luau` and `tests/GroveHarvestPrompt.smoke.luau`.

## Future polish (deferred)

- Smooth branch and leaf popping, trunk assembly transitions, growth sound, particle bursts and more sophisticated branch ordering
- Tree model and planting preview size hints, mutation-specific growth visuals, fully authored large-tree silhouette polish
- Camera cinematic, sound, log drop/homing, processing, forging and inventory UI polish (see `docs/PROTOTYPE_POLISH_BACKLOG.md`)

## Verification limits

- No Roblox Studio execution is possible via the GitHub connector. All code is committed and source-reviewed; **the smoke tests and visual playtest still need Studio**.
- The previous milestone still uses `ProfileStore.Mock`. Real persistence, storage-full policy and multiplayer race testing remain release blockers.
- This is additive visibility of real mature-tree parts; parts are not physically grown or minted as separate items. The stump is a welded cosmetic preview of the already-rolled next tree size.
