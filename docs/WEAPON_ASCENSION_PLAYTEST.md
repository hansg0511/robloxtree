# Phase 1D — Ascension / hard pity validation

Branch: `dev/gameplay-prototype`  
Implementation status: **committed; Roblox Studio and integration tests not yet executed by this assistant**.

## New behavior

A saved Common/Rare/Epic/Legendary weapon may attempt **one** rarity upgrade after reaching its current rarity level cap. Ultra is terminal on the standard ladder.

The user opens **M → AXES → INFO** while standing at **THE FORGE**. At max level the existing scrollable weapon detail displays:
- the next rarity, coin and **ordinary unlocked BAG log** costs;
- the current success chance, guaranteed-pity attempt counter;
- a warning that failed attempts still consume coins/logs;
- a two-click **ASCEND → CONFIRM** action.

The client sends only the owned weapon UID via `AscendWeaponRE`. The server checks unique ownership, persistent/runtime identity, actual rarity and max level, forge proximity, coins and log eligibility. It chooses the weakest/smallest ordinary unlocked logs from the **carry bag** and **never** automatically consumes mutated logs, locked logs or stored logs. The server resolves its own RNG and deducts materials and coins exactly once for either outcome.

On success: exactly one rarity upgrade; Level=1, XP=0 and per-step failures=0. All forged original Attack, class, material provenance, size, Cleave effects and potency metadata remain intact. For an equipped weapon, derived stats are recomputed immediately. **A newly ascended Level-1 weapon can be temporarily weaker than a prior max-level weapon**; this is expected.

On failure: rarity, Level, XP and original effects/stats remain unchanged; gold and logs are charged, `AscensionFailures` increments for the *same saved weapon only*. Hard pity forces success at `ceil(1.5 / p)` attempts, using p as the base chance fraction. Per-step pity resets upon success.

No special Secret path, no free mutation skills, no active skills, no account rebirth.

## Provisional config (not final economy)

| Step | Chance | Hard pity attempt | Coins | Normal bag logs |
| --- | ---: | ---: | ---: | ---: |
| Common → Rare | 50% | 3 | 150 | 1 |
| Rare → Epic | 25% | 6 | 600 | 2 |
| Epic → Legendary | 10% | 15 | 2,500 | 3 |
| Legendary → Ultra | 2% | 75 | 9,000 | 4 |

These numbers are deliberately easy-to-configure prototype placeholders. Do not infer they have been playtested or balanced.

## Agent / Studio automated tests

Run the contents of these files in Roblox Studio **Play → SERVER Command Bar**, or a configured Roblox-compatible test harness:

1. **NEW:** `tests/WeaponAscension.smoke.luau` — pure cost, upgrade eligibility, invalid draws, pity boundaries and reset, separate weapon counters, and no mutated/protected/stored log auto-consumption.
2. `tests/WeaponRarityRoll.smoke.luau` — Phase 1C rarity odds and persistence.
3. `tests/WeaponProgressionRules.smoke.luau` — Phase 1A progression migration.
4. `tests/WeaponProgressionXP.smoke.luau` — Phase 1B XP/levels.
5. `tests/WeaponEffectsDispatcher.smoke.luau` — Cleave/effect safety.
6. `tests/ExperimentalForgeRules.smoke.luau` — forge/class rolls.

New success output: `WeaponAscension: rarity ladder, cost previews, non-destructive failure, exact hard pity, resets and preservation passed`

**Important:** pure math smoke tests do NOT prove that the real server transaction, client result messages, bag proximity check or level reset after inventory refresh work end-to-end.

## One quick manual integration check (no grind required)

1. Start single-player Studio Play with Rojo synced. Forge a **normal persisted weapon**, not the Debug Pro Axe.
2. In Studio's **SERVER Command Bar**, run the optional **`tests/WeaponAscensionStudioFixture.smoke.luau`**. It is not shipped in the game. It:
   - caps the currently equipped non-debug weapon (or first available eligible saved weapon);
   - ensures sufficient coins and the minimum ordinary Bamboo logs in the carry bag;
   - sets the pity counter to guarantee success **on the next attempt** (set `FORCE_GUARANTEED_NEXT_ATTEMPT = false` to exercise normal RNG/failure);
   - temporarily disables the StudioForgeSandbox's automatic coin/log refill, to make cost deductions observable.
   - mutates **only the current Studio test session**; restart Play to clear those fixture changes.
3. Stand within the normal interaction range of **THE FORGE**. Press **M → AXES → INFO** and select the fixture weapon. Check the `ASCENSION` section's price, `GUARANTEED` label, attempt/pity counter, and action button.
4. Click the ASCEND button once to arm confirmation, then click again within 6 seconds. Verify the actual **weapon UID is unchanged**, rarity increases by exactly one, Level returns to 1, XP 0, pity resets, base forged stats and class effects are unchanged, and both log count and coins decrease by the displayed amounts.
5. Recheck current damage if equipped (level-derived power should reflect the **new rarity at Level 1**), switch to another weapon and back, and check Studio Output for errors.
6. For a failure attempt, rerun the fixture with `FORCE_GUARANTEED_NEXT_ATTEMPT = false`, and make an attempt when the random draw fails. Confirm the weapon is preserved while costs and pity counter advance. This is optional if server integration is exercised by the test agent.

**Known limitation:** Studio's current profile boot uses `ProfileStore.Mock`; Stop/Play is NOT a real published cross-session DataStore durability test. Do not claim that full persistence has been validated.

## Regression / acceptance

- No duplicate free attempts, no costs on rejection, no client-controlled roll/price, no wrong-player weapon changes.
- Class roll, forge, rarity, XP, Cleave and inventory equip continue working.
- No mutated/stored/locked logs silently consumed; no unchanged original weapon state mutated on failures.
- Agent tests plus one verified Studio ascend success are sufficient to proceed to Phase 2. Repeated pity boundary testing is covered in the deterministic tests and does not need 75 manual attempts.
