# Phase 1C — Natural weapon rarity test plan

**Branch:** `dev/gameplay-prototype`  
**Status:** Implementation committed; Studio tests and live forge/regression checks still pending.

## Implemented behavior

- Every **new successfully forged weapon** receives one independent, server-owned natural rarity roll through `ServerScriptService/WeaponRarityRoll.luau`. Both **Studio RNG forge** and **fixed-output standard recipes** use the same function; class, quality, size, metal/head tier and mutation effects still come from their existing code paths.
- Result rarity is saved in the existing **`InventoryItem.Rarity`** field, parsed by `ItemDataBase`, and used by the pre-existing rarity-specific level caps and derived power.
- Existing saved weapons **are not rerolled**. A naturally rolled Ultra with normal wood has **no free mutation abilities**. Secret is excluded from natural rolls.
- On successful forging, a compact color-coded feedback toast shows the actual server-rolled rarity and resulting power. In **M → AXES**, each item slot has a rarity label; **INFO → PROGRESSION** displays the rarity, level, XP and cap. We kept existing level/power slot metadata.
- If rarity RNG fails to produce a recognized tier, the forge aborts and restores consumed logs without reducing the head count.
- This stage does not add ascension, pity, player-selected rarity, forge-tier rarity odds, mutation powers, final polish, or player-facing odds preview.

### Provisional odds (not locked balancing)

| Natural rarity | Chance |
| --- | ---: |
| Common | 78.00% |
| Rare | 18.50% |
| Epic | 3.00% |
| Legendary | 0.45% |
| Ultra | 0.05% |

All odds use a single integer draw per crafted weapon over 1,000,000 possibilities. They do **not** depend on log species, mutation, quantity, class or tier in this initial slice.

## Automated smoke tests

In Studio **Play → Server Command Bar**, execute the contents of:

1. `tests/WeaponRarityRoll.smoke.luau` (**new**, rarity boundaries, deterministic seeded distribution, persistence/parse, no free effects).
2. `tests/WeaponProgressionRules.smoke.luau` (Phase 1A migration and rarity power growth).
3. `tests/WeaponProgressionXP.smoke.luau` (Phase 1B chopping XP and Cleave attribution).
4. `tests/WeaponEffectsDispatcher.smoke.luau` (class Cleave and effect safety).
5. `tests/ExperimentalForgeRules.smoke.luau` (existing class odds and quality).

**Expected new message:** `WeaponRarityRoll: boundaries, real RNG distribution, persistence, and class/effects independence passed`

Do not claim a full forge transaction was tested merely because the pure roller test passed.

## Minimal hands-on Studio verification

1. Sync the branch and start Play. Forge several **standard Copper Axes** (3 logs) and several **Studio RNG Copper weapons** (e.g. 1-log Dagger). For each successful craft, verify the forged result toast displays a real rarity and the item appears exactly once in Bag. Common is the most likely; Rare should show sometimes. **Do not farm until Legendary/Ultra appears:** the deterministic smoke test covers those thresholds.
2. Confirm the **server rarity saved** on each item matches **M → AXES** slot rarity and **INFO → PROGRESSION**. Inspect the rarity-dependent level cap (Common 10, Rare 20, Epic 30, Legendary 45, Ultra 65, temporarily).
3. Equip a higher-rarity weapon (if one naturally appears); check that initial derived power and chopping damage are consistent with the rarity bonus. Chop until XP increments normally; weapon-specific XP remains independent.
4. Forge a 20-log **Battlehammer** in RNG mode. It must still roll a Battlehammer due to the **original class odds**, not the rarity roll. Verify Cleave effect remains, and verified secondary damage still earns XP.
5. Reopen Bag and inspect **older pre-1C weapons**: their rarity must not have been rerolled, Cleave and original materials must remain intact. Check that `Rarity` labels don't overlap the equipped `ON` tag or become unreadably small.
6. Check Studio Output for first red error; if any error occurs, record exact source and line.

**Persistence caution:** current `ProfileInit` uses `ProfileStore.Mock` in Studio. The new rarity is in the persisted Inventory record at runtime, but a Stop/Play cycle is **not** proof of live DataStore durability.

## Phase 1C acceptance

Proceed to Phase 1D only after the new RNG test and the previous four smoke tests pass, and a couple of successful crafts through **both paths** show the rarity, correct class, inventory, combat and no resource loss/duplication.
