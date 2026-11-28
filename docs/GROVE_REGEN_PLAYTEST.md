# Grove regeneration + one-log harvesting — playtest contract

Base branch: `feature/log-storage-processor-prototype`
Feature branch: `feature/grove-regrowth-harvest-prototype`

Status: **PLAYABLE PROTOTYPE, UNVERIFIED IN ROBLOX STUDIO.** Growth duration, art, economy and feedback are not polished or approved launch balance.

## Behavior implemented

- Existing Grove sapling planting and stable **GroveTreeUID / SourceSaplingUID** lineage remain in place. The permanent planted tree is **not consumed when chopped**.
- A sapling has fixed `SizePotential` genetics. The first growing tree and **every regrowth** roll their actual `CurrentSizeScale` independently within **65%–100%** of their genetic maximum. The actual size governs the visible tree and the unique harvested log. Legacy planted records without this field migrate to their existing `SizePotential` on load to avoid changing a mature tree's initial appearance unexpectedly.
- A mature Grove tree chopped by its **owner** yields **exactly ONE unique log** directly to their protected **SAVED** log inventory (not the Carry Bag). It keeps `SpeciesId`, allowlisted inherited `Mutations`, `SizeScale`, `SourceType=Grove`, `SourceGroveTreeUID` and `SourceSaplingUID`. The Forge can use it from protected storage and retains source metadata on the finished weapon's materials.
- Only after the log has been credited is the planted tree's growth cycle advanced: **falling tree → visible stump → sapling → young → mature**. A first-time planting has no stump. Growth timing prototype: 45 seconds from harvest/plant to maturity, with a 5-second stump phase after harvest (tree fall occupies part of that phase).
- Logs already in protected storage and old **Heartwood** records stay owned; **new harvests no longer mint Heartwood**, and old Heartwood is not automatically converted into logs.
- If SAVED storage (currently 240 unique logs) is full, the harvest is **rejected**. No tree/growth reset, no arbitrary sale or lost unique log. A notification appears in the new storage toast.
- The PlantingController shows planted/mature/regrowing counts from server Grove state. New regrowth stages are broadcast as they change.
- **NOT implemented:** Grove levels, passives, weather modifiers, shop saplings, mutated wild-tree spawn/drop consistency, personalized animation polish, exceptional crafting quality or final size-based axe geometry. Existing `SaplingDiscoveryService` still uses prototype mutation rolls.

## Reproducing locally

If currently on `feature/log-storage-processor-prototype` with no uncommitted work:

```bash
git status
git fetch origin
git switch --track origin/feature/grove-regrowth-harvest-prototype
rojo serve default.project.json
```

Connect Rojo in `BrickWorldBase.rbxl`. No merge into the base branch is necessary to playtest.

## Manual Roblox Studio walkthrough

1. **N storage UI:** confirm existing bag and SAVED inventory still work.
2. Chop ordinary wild trees until a sapling drops (existing prototype acquisition; if RNG is slow, use a temporary Studio-only test profile/development loadout rather than changing live rates).
3. Enter Grove planting mode with **G**, plant the sapling on your own plot. Confirm the sapling disappears from sapling inventory and a persistent Grove tree with a stable `GroveTreeUID` appears. The **Grove** HUD now shows planted/growing counts.
4. Wait **45 seconds** (prototype growth duration) and confirm it becomes mature. Early chops should fail; owner chops of mature tree should work. Another player's tree cannot be harvested by you.
5. Chop the mature tree. Verify the usual fall plays, **one** new unique `Grove` log appears directly in SAVED storage, and **nothing new** is added to the carry bag or old Heartwood. Its size matches the previous tree's `GroveCurrentSize`; its mutation matches the inherited tree.
6. The original tree's **UID remains unchanged** in the server Grove state; it becomes a visible stump, then a sapling, young, mature again in roughly **45 seconds** from the chop. The second mature tree has a new size roll but the same genetic SizePotential and lineage.
7. Harvest a second time. Two different saved log UIDs should exist with the **same** source Grove UID; their sizes may differ. Craft a Copper Axe from three eligible bag/SAVED logs and confirm only the selected log UIDs are consumed.
8. Fill SAVED storage (or lower its limit for a Studio-only stress test), attempt a mature Grove harvest: **no log is lost and the mature tree remains available to retry** once storage space is freed. Turn capacity back afterward.
9. Leave/rejoin (while `ProfileStore.Mock` remains enabled, persistence across sessions is not guaranteed). At minimum confirm during the live session that the stump and lineage survive multiple chops without duplication and that plot reset handling remains safe.
10. Paste `tests/GroveGrowthRules.smoke.luau` into **SERVER** Command Bar; expected output: `GroveGrowthRules smoke checks passed`. The earlier `LogStorageRules.smoke.luau` and `WeaponRecipeRules.smoke.luau` should still pass.

## Engineering warnings

- **Not Studio-tested by ChatGPT**: The GitHub integration can edit/review source but cannot operate the user's Roblox Studio or execute its Luau scripts.
- `ProfileStore.Mock` remains active. Real economy persistence, trade safety, atomic claim/sell, and heavy multiplayer stress testing remain release blockers.
- Unique material arrays are bounded; current capacity is a prototype; this design deliberately rejects a premium harvest if no storage remains.
- Existing Heartwood materials are left intact to avoid destroying older prototype achievements. Their future conversion/use needs a separate, explicit migration design.
- New Grove tree size is **within genetics**, and can now be shown in material inventory. **No change to weapon gameplay power based on log size** in this milestone.
- Existing wild sapling drop rules are NOT yet aligned with the later design decision that mutated wild trees exclusively produce the matching mutated saplings. That belongs to a separate acquisition milestone.

## Code ownership

- `GroveGrowthRules`: pure growth/stage/genetics rules.
- `GroveService`: server owner/plot/UID validation, one-log harvest transaction, next-cycle persistence, regrowth scheduling.
- `TreeObject`: stump visuals, actual-size model scaling, maturity-gated chopping.
- `LogService`: server grant into protected storage, exact lineage preservation.
- `ShopHandler`: retain source lineage after forging.
- `PlantingController` / `LogStorageUI`: prototype status and harvest messages.
