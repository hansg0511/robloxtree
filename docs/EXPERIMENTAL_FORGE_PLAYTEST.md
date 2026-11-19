# Experimental RNG Forge — Roblox Studio playtest

**Branch:** `dev/gameplay-prototype` (existing draft PR #8).

**Mode:** Studio-only; live/public servers cannot access experimental recipes. This is an early integration of the independent Python balance sandbox, NOT finalized economy or art. The original fixed `copper_axe` / `iron_axe` recipes remain selectable and functional.

## Studio forge sandbox — no grinding required

This branch now has a **Studio-only automatic refill** implemented in `src/ServerScriptService/Economy/StudioForgeSandbox.luau`. It activates by default only under `RunService:IsStudio()`, and can be temporarily disabled by setting `Sandbox.ENABLED = false` for clean progression/economy tests.

Every Studio Play session automatically provides each test player with:
- **1,000,000,000 Coins**, topped back up on shop refresh / log inventory notifications.
- **1,000 Copper Axe Heads and 1,000 Iron Axe Heads**, topped back up the same way. They act as the experimental metal blanks, so you don't need to buy a head before every craft.
- **135 uniquely identified test logs in protected storage**, auto-replenished as they are consumed. The stock covers all 3 current species (Bamboo, Oak, Ironwood), size multipliers `0.5x, 1x, 2x, 3.5x, 5x`, and Normal, Golden, Crystal variants (3 of each combination).
- **Tier 2 and Forest2 access** to let you immediately test both metal tiers. These overrides exist *only in Studio* and do not apply to live players.
- Test logs are inserted into **StoredLogs**, not the carry bag. They do not eat carrying capacity or appear as physical ground drops, but are fully valid as owned forge inputs.

At the experimental forge, select a one-click preset: `BEST 1`, `BEST 5`, `BEST 10`, `BEST 20`, `GOLD 10`, `LOW 10`, or `BEST 96`. These select real owned log UIDs and update the quality/odds preview; forging still consumes exact server-validated records.

**Infinite here means sustainably replenished, not an unbounded number of records in memory.** The fixtures use 135 storage slots at full stock; the sandbox stops at 210 stored records to leave space for normal Grove logs. A consumed fixture receives a new UID, preserving prior craft provenance. No legitimate owned logs are deleted or overwritten. `BEST 96` is a transaction-limit stress test, not a recommended normal craft size.

The Studio-only smoke test `tests/StudioForgeSandbox.smoke.luau` uses synthetic player profile data, without modifying your actual inventory. Run it from the Studio **server** Command Bar during Play after a player has joined.

## What's actually playable

- In Studio, Copper/Iron heads are already stocked and Forest2 is unlocked by the sandbox. You can still test Axe Shop purchasing with `StudioForgeSandbox.ENABLED = false`.
- Open the **Forge**. In Studio there are now extra `COPPER BLANK • EXPERIMENTAL FORGE` and `IRON BLANK • EXPERIMENTAL FORGE` recipe cards.
- Select **1–96 individually owned logs** from bag or saved storage (or use the Studio **one-click presets**). The 96 limit is a defensive server transaction boundary, NOT intended as final game design. A 20+ log offering guarantees Battlehammer *in the current test distribution*; adding more doesn't increase the chance past 100% and may dilute average material quality.
- Each selected log displays its actual `SizeScale`, species and mutations. The preview shows **average absolute log quality** (size / global 5x maximum) and the weapon-class **probabilities**. There is no hidden extra reroll of overall material quality.
- Clicking `FORGE RNG` consumes **one owned metal head** plus exactly the offered UIDs, rolls a **Dagger, Axe, or Battlehammer** class and independently rolls damage, attacks/second and reach in their visible 90–110% ranges.
- The resulting unique weapon stores chosen log provenance, material quality, Golden quality and its per-stat rolls. The equipment list and inventory distinguish `Copper Dagger`, `Copper Axe`, etc.
- New weapon damage, attack interval and reach apply to ordinary **single-tree chopping**; other nearby trees are still unaffected. The server selects the tree, validates ownership/progression, and enforces hit cooldown and reach.
- Crafted **Dagger and Battlehammer currently borrow existing Tool models** (Starter Hatchet and Heavy Cleaver, respectively). These are placeholders, NOT their intended art or proportions. Equipping them does not resize the Tool model.
- **Golden mutation bonus** is calculated and recorded as metadata for later passive/ability implementation; it does NOT increase chopping damage yet. No Cleave, Chain Lightning, AoE, premium effects, skills or active abilities have been implemented.

## First playtest: look for these things

1. After pulling and syncing Rojo, enter **Studio Play**, visit the Axe Shop, purchase a head, and visit the Forge. Make sure both **standard** and **experimental** recipe cards appear.
2. Choose **one log**. The preview should display **100% Dagger** and a quality of `SizeScale/5 × 100%`. Clicking `FORGE RNG` should create one unique Dagger, remove one head and only that chosen log. If inventory is full or the request is invalid, it should NOT consume the head or logs.
3. Choose **5 logs**: the preview should show approximately **35% Dagger / 65% Axe**. At **10 logs**, it should show **2% Dagger / 38% Axe / 60% Battlehammer**. At **20+**, expect **100% Battlehammer**. A few attempts are not enough to verify probabilities statistically.
4. Put **one large high-quality log** alongside several smaller logs and verify the displayed quality **decreases** when the smaller logs are selected. Test Oak vs. Ironwood to observe different average material strength, though only quality and class odds are currently displayed.
5. Harvest a **Golden** mutated Grove tree; it should contribute to the Golden-quality calculation in the preview. The resulting Golden effect is **metadata only**. Do not mistake it for an implemented combat passive.
6. Equip newly crafted weapons, chop the same type of tree, and inspect **per-hit damage, swing interval and valid reach**. The attack interval is clamped to a minimum of 0.3s and reach to 0.5–2× server interaction range. Legacy standard axe cooldown remains unchanged. Actual hit feedback may differ from the independent DPS simulator until movement and animation tuning.
7. Test **Iron-tier progression**, and try an invalid/missing-head craft, duplicate UID selection, and a player who isn't near the Forge. No unauthorized craft should succeed.
8. Run `tests/ExperimentalForgeRules.smoke.luau` in **Studio SERVER Command Bar**, then check old standard crafting, equipping, Grove harvesting, bag/storage log protection and log sales for regressions.

## Temporary calculation

```text
LogQuality = clamp(ActualLogSize / 5, 0, 1)
Q = average(LogQuality of all selected logs)
MaterialFactor = 0.5 + 0.5 * Q
AverageWoodStrength = mean(6 Bamboo, 10 Oak, 16 Ironwood)

ReferenceDamage = (MetalBase + AverageWoodStrength) * ClassDamageMultiplier
Damage = ReferenceDamage * MaterialFactor * independent U(0.9, 1.1)
AttacksPerSecond = ClassBaseAttackRate * MaterialFactor * independent U(0.9, 1.1)
ReachMultiplier = ClassBaseReach * MaterialFactor * independent U(0.9, 1.1)
GoldenQuality = sum(Quality of selected Golden logs) / TotalLogCount
GoldenStrength = 0.30 * GoldenQuality * independent U(0.9, 1.1) [METADATA ONLY]
```

Class odds: `1 -> Dagger 100%`; `5 -> Dagger 35% / Axe 65%`; `10 -> Dagger 2% / Axe 38% / Battlehammer 60%`; `20+ -> Battlehammer 100%`. Linear interpolation between authored count anchors; all values are **experimental**.

## Current limitations

- The original Axe Shop and standard recipes still call the metal component an **Axe Head**. We intentionally kept those IDs to avoid an inventory migration.
- The 5x size denominator and species strength table match the sandbox but are future-game assumptions: current Grove genetic potential still caps at 2x, so current Grove log quality cannot exceed ~40%.
- The existing player data layer currently uses `ProfileStore.Mock`: do not interpret Studio persistence as production-ready storage.
- The simulated reference DPS excludes player travel, target acquisition, critical hits, HP variation, cooldown quantization and Roblox server latency. The playable hit cooldown is now applied, so real measurements are more useful than theoretical DPS alone.
- **No Roblox Studio or multiplayer test has been performed through the GitHub connection.** Do not merge PR #8 to `brick-world-rework` before Studio tests pass.

## Next work after this playtest

1. Fix any forage UI, transaction, equip, network or hit-rate bugs.
2. Tune class damage/speed/reach with measured tree-clear times.
3. Build distinct Dagger / Axe / Battlehammer models and size scaling, then connect Golden quality to a real passive and implement a first secondary effect (Cleave or Chain Lightning).
4. Only then replace the old Axe Head terminology with generic metal blanks across permanent inventory/economy flows, with a deliberate migration strategy.
