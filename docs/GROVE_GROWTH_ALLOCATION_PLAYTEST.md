# Grove growth allocation — fixed 30-second testing cycles

Active branch: `dev/gameplay-prototype` — consolidated draft PR #8.

## Current prototype timing (temporary)

- **Every Grove tree matures in 30 seconds total**, regardless of its actual rolled size, genetic potential, or species. This applies to **new plantings and new regrowth cycles**.
- **2 seconds per time interval** (globally), so every cycle comprises **15 two-second intervals**.
- **First planting:** 15 growth intervals, from planting to maturity at +30 seconds.
- **Following harvest:** the **first 4 seconds / 2 intervals** are reserved for stump and the existing ~2.6-second harvest-fall cinematic. The remaining **26 seconds / 13 intervals** are for visible growth. The tree still matures **at +30 seconds from harvest**, not +34.
- The growing model initially shows a stump at visual step zero; trunks, branches and foliage are gradually revealed according to the normalized allocation timeline. No fixed internal 40-step denominator exists.
- The server checks maturation and harvest conditions each second, but replicates geometry changes at the two-second visual milestones, so **other players see the growth**.
- **Already-planted trees** keep the maturity timestamp stored in their existing records. Their current cycles are not retimed automatically by this code change; their next regrowth cycle will use the new 30-second duration.
- The authoritative server-owned `MaturesAt` deadline, not appearance, determines when the E-harvest prompt is enabled.

### Tuning location

`src/ServerScriptService/Grove/GroveGrowthRules.luau`:

```luau
Rules.SECONDS_PER_VISUAL_STEP = 2
Rules.MATURITY_SECONDS = 30
Rules.TOTAL_CYCLE_STEPS =
    Rules.MATURITY_SECONDS / Rules.SECONDS_PER_VISUAL_STEP
Rules.STUMP_SECONDS = Rules.SECONDS_PER_VISUAL_STEP * 2
```

`Rules.StepsForSize` and `Rules.DurationForSize` retain their existing API for the plant and regrowth code, but **deliberately return the same values for every valid size** during testing. Size still controls the mature model and harvested log, not growth time.

## How the generic allocator works

- `Trees/GroveGrowthAllocation.luau` maps a mature plant to normalized windows: trunk 0–50%, branches 50–80%, leaves 68–100%.
- Trunk sections extend according to **real relative height**, rather than being allocated one step per Part. Branches extend from their authored base along local X/Y/Z axes.
- Leaves grow as staggered expanding blocks. Bamboo's five culms remain synchronized as one visual group.
- Temporary collisionless wood copies are destroyed once their original complete Parts appear; the source welded/harvest model is not resized.
- For unusual future plants, authors can optionally use `GroveGrowthRole`, `GroveGrowthOrder`, `GroveGrowthAxis`, `GroveGrowthDirection`, `GroveGrowthStart`, and `GroveGrowthFinish`.

## Studio validation

1. Pull `dev/gameplay-prototype` and run `rojo serve default.project.json`.
2. Plant a small Oak and a huge Oak. **Both should mature in ~30 seconds**, showing growth every ~2 seconds. Their sizes and harvested-log characteristics should still differ.
3. Harvest a mature tree. Verify the fall + stump occupy the beginning of the new cycle, and that the next tree is mature **30 seconds after the harvest**, not 34.
4. Check Ironwood's trunk lower→middle→top, Oak's branches/bark/leaves and five synchronized Bamboo canes. Mature models should match forest versions.
5. Test an observer client nearby: growth is visible to both, and only the Grove owner can harvest.
6. Run `tests/GroveGrowthRules.smoke.luau`, `tests/GroveGrowthAllocation.smoke.luau`, `tests/GroveStageVisuals.smoke.luau`, `tests/GroveIronwoodBambooGrowth.smoke.luau`, `tests/GroveOakFoliageGrowth.smoke.luau`, and `tests/GroveLargeTrunkGrowth.smoke.luau` from the Studio **SERVER Command Bar**.

**Not yet Studio-executed through GitHub.** Leave PR #8 in draft until the in-game playtest and smoke tests pass. Size-based growth duration can be reintroduced at balance time without redesigning the generic allocation module.
