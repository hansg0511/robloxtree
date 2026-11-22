# Phase 1B — Weapon XP Studio verification

**Branch:** `dev/gameplay-prototype`  
**Status:** Phase 1B source implementation committed; **Roblox Studio execution and hands-on testing not yet verified.**  
**Scope:** XP from validated wild-tree damage and kill bonuses; progression on the exact equipped, persistent weapon; display Level/XP in **M → AXES**.

## Automated Studio server smoke tests

With the latest branch synced using Rojo, start **Play** and run the complete content of each test in the **Server Command Bar**:

1. `tests/WeaponProgressionRules.smoke.luau` — existing Phase 1A migration/stat test.
2. `tests/WeaponProgressionXP.smoke.luau` — new Phase 1B XP thresholds, cap behavior, overkill rejection, and actual Cleave secondary-hit reporting.
3. `tests/WeaponEffectsDispatcher.smoke.luau` — existing class/mutation effect compatibility and nonrecursive Cleave.
4. `tests/ExperimentalForgeRules.smoke.luau` — existing RNG forge regressions.

**Expected new test output:** `Weapon XP: thresholds, level caps, overkill, kill bonuses, and Cleave attribution passed`

If any test fails, collect the **first Studio Output error**, source file and line number; do not mark the stage validated.

## Hands-on regression and new feature checks

1. **Baseline:** Forge a fresh 1-log Dagger; open **M → AXES → INFO**. Expect `Common`, `Level 1 / 10`, `Weapon XP 0 / 125` (temporary tuning) and the old baseline power/damage. Repeat with the 20-log Battlehammer; its existing `WEAPON EFFECTS` list must still show Cleave.
2. **Primary hit:** Equip a normal owned weapon and chop a wild Oak. Reopen **M → AXES → INFO**. XP must increase; each strike credits only HP actually removed, never overkill. First level's temporary requirement is 125 XP, with a 25% max-HP bonus on killing the tree.
3. **Level-up:** Chop until the weapon reaches Level 2. Expect a level-up notification, increased Bag power, increased actual attack (from separately aggregated level bonus), and a new next-level XP requirement. Neither source log metadata nor existing Cleave radius/fraction should change.
4. **Cleave XP:** Equip a fresh Battlehammer and hit the **Studio-only Cleave Test Patch**. The secondary trees visibly take their usual damage. The Battlehammer should gain **additional** XP for those actual HP-clamped secondary hits; no bonus from missed/ineligible/protected targets.
5. **Weapon separation:** Equip another ordinary weapon. Its Level/XP should reflect **its own** progression, not the previously equipped weapon's XP. Switch back and verify the first weapon retained its progress.
6. **Grove protection:** Grove prompt harvesting is still separate from ordinary axe hits. Do not expect weapon XP from the Grove's E prompt; there must be no XP or effects from protected Grove trees.
7. **Debug isolation:** The ephemeral `Debug Pro Axe` (on the authorized test account) must not gain normal rarity/XP or persist as a regular weapon. No changes to legacy standard forge, shop purchases, logs, effects or equipment are intended.
8. **No errors:** Check the Studio Output for errors about `WeaponProgressionRules`, `WeaponProgressionService`, `TreeObject`, `ChopHandler`, `Cleave`, `StatsAggregator`, `ShopHandler` or `EconomyUI`.

## Implementation details and provisional values

- The server accepts only an authorized normal **ChopEvent** with a real equipped Tool, server-selected tree, bounded swing interval and server-determined damage.
- `TreeObject:TakeDamage` now returns `(success, appliedDamage, killed)`; the first return value remains compatible with older code.
- ChopHandler aggregates one primary hit and the validated secondary hits for that swing, using a callback in the existing effects dispatcher; then `WeaponProgressionService.AwardHits` updates the uniquely matched saved Inventory item and the runtime weapon copy.
- XP per hit = `floor(actual applied damage) + (killed ? floor(tree MaxHP * 0.25) : 0)`. XP to next level = `100 + 25 * current level`. **Provisional playtest values, not locked economy.** Normal Common cap is 10 for the prototype; excess XP at cap is not stored.
- Levels can advance by more than one if a real qualifying hit is unusually large; stat growth is recalculated once after the whole swing. No user-provided XP, client target, tree-health, or ability data enters the reward path.
- `M → AXES` reads the server-owned shop snapshot and receives lightweight XP updates. No new final-polish UI was designed.
- New rarity rolls, ascension/pity, Awakening, Infusion, activated skills and mutation powers are **not implemented** here.

## DataStore note

The current `ProfileInit` script calls `ProfileStore.Mock:LoadProfileAsync` in this prototype. A Stop/Play restart is **not proof of published DataStore persistence**. The saved Inventory item is updated in memory; persistence across real sessions needs separate verification when the deployment profile mode is ready.
