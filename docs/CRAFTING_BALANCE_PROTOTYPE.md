# Crafting balance sandbox — first mathematical experiment

> **New Studio integration:** The formulas in this offline sandbox now have an **opt-in Roblox Studio-only experimental forge implementation** in `src/ReplicatedStorage/Shared/ExperimentalForgeRules.luau`, `ShopHandler.server.luau`, and the existing forge UI. See **[EXPERIMENTAL_FORGE_PLAYTEST.md](EXPERIMENTAL_FORGE_PLAYTEST.md)** for exactly what is playable and what remains placeholder. The current fixed Copper/Iron forge is still available; this Python simulation remains useful for bulk balance experiments.

**Status:** OFFLINE DESIGN PROTOTYPE. No live Roblox forge, equipment, damage, UI, inventories, or save files have been changed. All numerical balance values are placeholders, not agreed final economy values.

Run from the repository root (standard Python 3.10+, no third-party packages):

```bash
python tools/crafting_balance_sim.py --samples 20000 --seed 42
python -m unittest discover -s tests -p 'test_crafting_balance_sim.py' -v
```

The script is deterministic for a given seed. Outputs are Monte Carlo estimates; the probability anchors are exact, authored inputs.

## Design rules currently being investigated

1. A purchased/earned **metal blank** supplies the progression tier (Copper/Bronze/Iron). This is a possible replacement for axe-only heads later, not an actual shop feature yet.
2. Forge accepts a **chosen number of individual logs**; that count determines *probabilities* for Dagger / Axe / Battlehammer. This experiment places no practical maximum on selected materials, but a real server implementation will need bounded transactions/deposits.
3. Every log's **absolute material quality** is `clamp(actual_size / GLOBAL_MAX_SIZE, 0, 1)`; the example global maximum is **5x**, including future worlds. It is NOT normalized by that individual tree's genetic potential. Current Grove genetic potential is limited to 2x, so existing Grove logs cannot exceed ~40% quality in this sandbox.
4. The forged weapon's **average quality** `Q` is the simple arithmetic mean of all logs' absolute quality. Their species material-strength scores are also averaged.
5. Metal tier + mean species strength define a reference strength, modified by weapon-class multipliers. Each eligible stat (damage, **attacks per second**, reach) is independently rolled in **[0.9, 1.1]**. Quality influences **every** stat, with a low-quality floor so common materials remain playable.
6. A **Golden mutation strength** is computed separately as `sum(log_quality where log has Golden) / total_log_count`; its effect receives one independent [0.9,1.1] roll. The material-quality factor is not additionally applied to the mutation, avoiding double-counting.
7. No failure lottery: if an attempted craft is valid, it yields one weapon. Weapon *class* is RNG, along with individual stat rolls. There is no additional global quality roll.

### Prototype calculations

```text
LogQuality_i        = clamp(LogSize_i / 5.0, 0, 1)
WeaponMaterialQ     = average(LogQuality_i)
AverageWoodStrength = average(WoodStrength_i)
QualityFactor       = 0.5 + 0.5 * WeaponMaterialQ
ReferenceStrength   = MetalBaseStrength + AverageWoodStrength

Damage     = ReferenceStrength * ClassDamageMultiplier * QualityFactor * U(0.9, 1.1)
Attacks/S  = ClassAttackRate         * QualityFactor * U(0.9, 1.1)
Reach      = ClassReach              * QualityFactor * U(0.9, 1.1)

GoldenQ        = sum(LogQuality_i for Golden logs) / TotalLogs
GoldenBonus    = 0.30 * GoldenQ * U(0.9,1.1) [if any Golden logs]
Modelled DPS   = Damage * Attacks/S * (1 + GoldenBonus)
```

Quality is **how close to reference potential the materials are**, not a guarantee of perfect stat rolls. At 100% material quality, a 1.1 stat roll can exceed the nominal reference. The *hard maximum* would include that roll.

### Placeholders to tune

- Base strength: Copper 25, Bronze 40, Iron 55
- Wood strength: Bamboo 6, Oak 10, Ironwood 16
- Class multipliers (damage, attacks/sec, reach): Dagger (0.55, 2.20, 0.75), Axe (1.25, 1.20, 1.00), Battlehammer (3.60, 0.70, 1.40)
- Minimum reference stat fraction: 50%; random stat factors: 90–110%
- Golden effect example: max +30% damage. **This is only a placeholder to test dilution**, not a designed Golden passive or approved ability.
- Weapon class probabilities, interpolated between log-count anchors:

| Logs | Dagger | Axe | Battlehammer |
|---:|---:|---:|---:|
| 1 | 100% | 0% | 0% |
| 3 | 80% | 20% | 0% |
| 5 | 35% | 65% | 0% |
| 8 | 10% | 70% | 20% |
| 10 | 2% | 38% | 60% |
| 15 | 0% | 15% | 85% |
| 20 or more | 0% | 0% | 100% |

The last anchor is just a probability ceiling, not a requested cap on the number of logs. Adding ordinary logs **after** reaching the category ceiling cannot increase class or stat potential merely by increasing count; their quality and species still affect the averages, possibly **lowering** them.

## Actual simulation findings (20,000 rolls per case; seed 42)

Controlled comparison: one metal (Copper), all Ironwood logs of the same quality, and each listed weapon class held fixed **to isolate class balance**, regardless of its probability at that offering count.

| Class | Logs | Material quality | Average DPS | DPS/log | 20 HP chop sec | 100 HP chop sec | 400 HP chop sec |
|---|---:|---:|---:|---:|---:|---:|---:|
| Dagger | 1 | 20% | 17.9 | 17.9 | 1.52 | 6.00 | 22.93 |
| Axe | 5 | 20% | 22.1 | 4.4 | 1.39 | 5.46 | 18.91 |
| Battlehammer | 10 | 20% | 37.2 | 3.7 | 2.39 | 4.78 | 11.99 |
| Dagger | 1 | 80% | 40.2 | 40.2 | 0.72 | 2.75 | 10.28 |
| Axe | 5 | 80% | 49.8 | 10.0 | 0.93 | 2.71 | 8.58 |
| Battlehammer | 10 | 80% | 83.7 | 8.4 | 1.59 | 1.59 | 5.60 |

Chop times assume the first hit lands after one swing interval; no target switching, client/server latency, movement, recovery, tree spawning, collisions or AoE mechanics.

With class chosen from count-based probabilities:

| Offering | Average quality | Mean DPS |
|---|---:|---:|
| 1 elite Ironwood log at 4x (guaranteed Dagger) | 80% | 40.2 |
| 10 ordinary Oak logs at 1x (60% chance hammer) | 20% | 26.6 |
| 10 elite Ironwood logs at 4x (60% chance hammer) | 80% | 70.0 |
| 20 ordinary Oak logs at 1x (guaranteed hammer) | 20% | 31.8 |

**Important balance finding:** cheap daggers have dramatically better DPS per *log* even with these heavy-weapon advantages. More expensive classes are better in absolute DPS at equal quality, but stronger class multipliers alone cannot equalize output per log without creating absurdly strong heavy weapons. We should **not** try to force equal DPS/log across classes. Instead test progression gates, one-shot behavior, reach, time to move between trees, and secondary-area effects after gameplay is implemented. Exceptional-quality daggers may beat low-quality heavy weapons, which is acceptable if rare materials have meaningful value.

Mutation dilution example: in a 10-log 4x Ironwood craft (80% material quality), **2 Golden logs** contribute `2 * 0.8 / 10 = 16%` Golden quality, yielding ~**4.8%** bonus against the placeholder 30%-maximum trait. Ten Golden logs yield ~24%. Other mutation types are not yet modeled.

## Limits and next milestone

- This is **pure Python** and does not interact with the live forge. The current Lua forge still uses Copper/Iron Axe Heads, exactly three logs, fixed-output weapon identity and deterministic power; existing weapon behavior is unchanged.
- Existing wild/Grove log `SizeScale`, `SpeciesId`, `Mutations` and UID provenance are already available as ingredients for a future server-authoritative implementation, but the current forge does not roll these stats.
- Weapon meshes, animations, active abilities, multi-tree effects, rarities and selling/recycling are **not** simulated.
- Suggested next step: agree on the first three class profiles and rough class odds; then port the validated calculation to a small server-only Lua rules module, implement weapon-class output and stat provenance, and expose a pre-craft probability/stat-range preview with transaction tests. Do **not** merge into live crafting until the test and presentation rules are reviewed.
