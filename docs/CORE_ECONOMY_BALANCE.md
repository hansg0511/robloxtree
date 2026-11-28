# Core economy — first quantitative pass

## Grove parallel progression — source balance (2026-11-28)

Goal: Grove develops alongside equipment, breaks up farming, and supplies renewable exact-species/mutation logs at the cost of temporarily losing mature passives. No mandatory waiting or new currencies.

| Species | Initial growth | Regrowth | Passive scale |
|---|---:|---:|---:|
| Bamboo | 45s | 120s | 1 |
| Oak | 60s | 180s | 1.15 |
| Ironwood (legacy) | 120s | 300s | 1.15 |

Sapwood fallback 45/120s and multiplier 1 (not currently a wild sapling acquisition source). Species-specific durations apply to new planting/regrowth, independent of size. Existing persisted MaturesAt is never rewritten; offline wall-clock growth already supported, one mature harvest maximum per tree, no accumulation or automatic harvesting. Stump hold included. One protected log per harvest, rerolls actual size within 65–100% of genetic potential; no new Heartwood or additional yield. Mature-only passives unchanged. Size-dependent bonus is already a strong incentive to retain excellent specimens. Later species provisional multiplier anchors F4–10 1.25/1.35/1.45/1.55/1.65/1.75/1.85, regrowth 4/5/6/8/10/12/15m, not implemented and subject to joint boss balance; early shop Ironwood deliberately has no out-of-order passive advantage. Acquisition remains 10% ordinary drop, 6% mutated life, 20% mutated drop conditional on mutation; quality bands/genetics/shop stock remain unchanged. Exceptional size+mutation+desired genetic combinations already scarce. No new acquisition system.

Grove expansion costs 500/2500/10000/40000/120000 for 4/5/6/8/10 slots (total 173000, previously 62000); first upgrade unchanged, existing unlocked levels preserved. Latest 10h income budget must account for this, not old Grove cost. Harvesting should alternate with normal play; 3 Oak trees theoretically yield 60 logs/hour on immediate recurring harvest, 10 Oak trees 200/hour, before collection travel, passive opportunity costs and storage; rare-size/mutated material accumulation will need observation. Larger future species take longer to regrow. Do not add log harvest timers beyond the existing per-tree deadline or offline resource accumulation. Shop and quest intro unchanged; future species acquisition/access gates need proper content design. Grove manager displays countdown to maturity from persisted timestamp, presentation only.

Existing Grove growth smoke suite updated for species deadlines and old persisted deadlines; no new suite, no Studio test. Check growth visual stepping at longer durations, maturity/rejoin, current-size rolls, passive loss/restore, capacity purchases and UI countdown. Actual progress times and Grove farming profitability unknown. Next: progression objectives (no narrative) and future species/layout; joint 10h balancing continues.

---

## Weapon XP curve — current source balance (2026-11-28)

World 1 target remains ~10 active hours; player explicitly wants multiple meaningful goals, not ten hours of coins. Game is an incremental/tycoon, not a narrative RPG. Use progression objectives/tutorials/challenges rather than story-driven quests; optional event lore is fine. Existing technical Story quest category is retained for save/remote compatibility until a presentation rename is needed.

XP earning unchanged: floor(actual HP removed) + floor(0.25*maxHP) on a verified kill, weapon XP passives apply on the server, secondary hits count actual removed HP, no overkill or challenge farming XP. New required XP for transition from level L to L+1 = 100 + 25*L + 3*(L-1)^3, same for all rarities at the same level. Rarity already determines the maximum level and power multiplier. First threshold 125 unchanged. No additional rarity multiplier, so newly crafted higher-rarity weapons develop quickly initially and ascension preserves the same level curve. Current earned level, raw in-level XP, caps, 1% damage growth per level, 2% substat growth per level, XP gain and ascension costs unchanged. No retroactive level loss or reroll; raw partial XP is retained (percentage to next level may decrease). Capped XP remains zero. No XP transfer from old weapons, new currency, AFK XP or upgrade mechanics introduced.

| Rarity | Cap | Previous cumulative XP | Revised cumulative XP |
|---|---:|---:|---:|
| Common | 10 | 2,025 | 5,913 |
| Uncommon | 15 | 4,025 | 28,868 |
| Rare | 20 | 6,650 | 94,373 |
| Epic | 30 | 13,775 | 508,283 |
| Legendary | 45 | 29,150 | 2,713,898 |
| Mythical | 55 | 42,525 | 6,185,808 |
| Ultra | 65 | 58,400 | 12,251,168 |
| Divine | 80 | 86,900 | 28,564,583 |
| Celestial | 100 | 133,650 | 70,730,253 |
| Eternal | 125 | 206,150 | 174,673,778 |
| Primordial | 150 | 294,275 | 365,012,303 |
| Transcendent | 200 | 517,400 | 1,164,905,603 |

Illustrative single-player size-1 full-kill examples, no XP passive/overkill, assume constant tree throughput including movement/collection: Common cap 5913 XP / 87 XP per 70 HP Sapwood = 68 trees (~8.5m at 8 trees/min); Uncommon cap 28868 / 387 XP per planned 310 HP F4 tree = 75 trees (~12.5m at 6/min); Rare cap 94373 / 625 XP per planned 500 HP F6 tree = 151 trees (~25m at 6/min); Epic cap 508283 / 2375 XP per planned 1900 HP F10 tree = 215 trees (~43m at 5/min). Legendary cap 2713898 / 2375 = 1143 F10 size-1 trees (~3.8h at 5/min), optional mastery not world-clear requirement. These are examples from fixed assumed rates, not measured playtime. Earlier levels on each new weapon are quick; higher-HP later trees catch up low levels faster. Larger wild trees, effects, XP bonuses and actual travel/handling change throughput. Leveling overlaps farming/material hunting, not a separately additive time budget. Future-world levels 45–200 are provisional curve extrapolation only; revisit against future tree HP/damage/XP safety caps when worlds are designed. Don't interpret billion-XP endgame cap as final time target.

Existing XP smoke suite first-threshold 125, 1000-XP multiple levels, 100000-XP Common cap and HP-clamped reward invariants remain compatible by arithmetic. No new smoke suite and no Studio execution. Deferred check: real XP gain, UI progress, level-up/stat refresh, actual early/mid/late cap timing, saved level/partial XP, ascension and passive scaling, no challenge XP. Next balance Grove growth/sapling loops and non-narrative progression objectives, then revisit late Guardian thresholds and whole-world pacing.

---

## Current World 1 pacing target — 10 active hours (2026-11-28)

User revised the target from 12 to approximately 10 active hours for an average progressing player. Keep early onboarding, ten forests, optional gear mastery and freedom to progress faster with a strong build. Working pacing allocation (not timers or validated predictions):

| Forest | Residence minutes | Cumulative exit minutes |
|---:|---:|---:|
| 1 | 4 | 4 |
| 2 | 4 | 8 |
| 3 | 12 | 20 |
| 4 | 30 | 50 |
| 5 | 45 | 95 |
| 6 | 70 | 165 |
| 7 | 95 | 260 |
| 8 | 105 | 365 |
| 9 | 110 | 475 |
| 10 | 125 | 600 |

Steel unlock at F7 entry around 165 minutes (2h45m). Prior hypothetical income rates at 65% farming utilization imply 1,809,909 gross coins before sinks; this is scenario arithmetic only, not a calibrated economy. Rebalance later Forge progression, gear investment and Guardian thresholds jointly; no artificial time locks, mandatory rarity, premium spend or tedious ordinary tree HP inflation. Existing source configuration unchanged. No runtime validation.

---

## Prior World 1 duration target — 12 hours (superseded by 10 hours)

User superseded 3–6h with approximately 12 active hours for an average progressing player, to allow longer intervals between content updates. Keep the first craft 1–2m, Forest2/3 entry ~4/8m, first Iron 10–15m. Stretch mid/late progression rather than onboarding. Proposed pacing allocation (not timers, hard locks, or measured estimates):

| Forest | Previous minutes | New minutes | Cumulative exit minutes |
|---:|---:|---:|---:|
| 1 | 4 | 4 | 4 |
| 2 | 4 | 4 | 8 |
| 3 | 12 | 12 | 20 |
| 4 | 15 | 35 | 55 |
| 5 | 20 | 55 | 110 |
| 6 | 30 | 85 | 195 |
| 7 | 40 | 115 | 310 |
| 8 | 45 | 125 | 435 |
| 9 | 50 | 135 | 570 |
| 10 | 60 | 150 | 720 |

Steel becomes available upon F7 entry (~3h15m target); later Guardian/World Boss challenges remain stationary, personal and timed. No required rarity, Forge level, metal, premium currency or minimum elapsed time. Preserve ordinary hit-count/cadence targets; longer progression should come from more meaningful equipment/quality/level/Grove development, not 2.5x HP on routine trees or multi-minute repetitive boss attempts. Keep ten forests for now; no new world count or rebirth mechanic approved.

Important: the prior 280-minute affordability scenario is superseded as a duration target, NOT as source configuration. At the old hypothetical rates and 65% farming utilization, the new time allocation implies ~2,186,639 gross coins before sinks, so the previous Forge26/700-DPS boss budget cannot simply be relabeled a 12-hour progression curve. Actual players may clear much faster through quality, Bossbane and other bonuses. Re-budget late Forge targets/costs, income, repeated crafting incentives, accessible rarity and Guardian power thresholds jointly after choosing species/layout and measuring first-three-forest flow; higher levels may become plausible but Legendary should remain aspirational rather than compulsory. No promise of 12h completion without testing. Existing live costs, rarity probabilities, tree HP, material values and current two Guardian thresholds unchanged in this decision. Future material/Steel/Guardian numbers in the prior section are provisional starting points, not final 12h balance. No runtime tests performed.

---

## Prior World 1 integrated working balance — 2026-11-28 (280-minute scenario; superseded duration target)

User approved 3–6 active hours and delegated numeric balancing. Target scenario 280 minutes (4h40m), with F10 entry at 220m. These are design inputs and affordability arithmetic, NOT predicted median completion or a simulated optimal player. Guardians are the only progression power checks, not mandatory Forge/rarity/metal tiers; an exceptional build may clear much sooner. No rare roll, ascension or Gems required.

### Income and budget

Existing F1–3 material values remain active. F4–10 are numbered placeholders pending species/art/layout implementation; do not silently assign legacy Ironwood. Later proposed kg/log and size-1 sale prices are below. Fixed yield 2 for F1, 5 for F2, size-1 yield 2 for F3+ (future yield assumption). Keep size-squared sale, auto-keep and current 10/15/20/30/40 kg capacity ladder. Estimated round-trip/sale overhead includes travel/quick travel assumptions, NOT measured. Gross full-bag sale uses floor(bag/kg) logs, ceil(logs/yield) trees, four seconds handling per tree and (ceil(baseHP/representative Axe integer damage)-1)/1.3872 seconds from first to last hit; rate = 60*bagValue/(tree time+trip seconds). F1 rate is equipped farming, not fresh fist rate. Real rates depend on travel, actual yields/size/crit, pickup and storage, contention, tool class and passive bonuses. Budget assumes only 65% of active minutes earn the modeled size-1 gross rate, allowing other activity and log reserves; it is an explicit arbitrary utilization scenario, not an independently validated estimate. Bag upgrades are budgeted in the same forest as use; initial funds must be earned first. Forge target is on exit, not entry.

| Forest | Minutes | kg/log | Coins/log | Bag kg | Trip s | Gross coins/min while farming | Budgeted income | Exit Forge | Forge spend | Head spend | Bag spend | Grove spend | End balance |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 4 | 0.5 | 5 | 10 | 25 | 83 | 216 | 1 | 0 | 60 | 0 | 0 | 156 |
| 2 | 4 | 1 | 16 | 10 | 40 | 189 | 491 | 2 | 500 | 60 | 0 | 0 | 87 |
| 3 | 12 | 2 | 60 | 15 | 55 | 328 | 2558 | 3 | 800 | 750 | 250 | 0 | 845 |
| 4 | 15 | 2 | 100 | 15 | 60 | 514 | 5012 | 5 | 2950 | 1500 | 0 | 500 | 907 |
| 5 | 20 | 2.5 | 200 | 20 | 65 | 1071 | 13923 | 7 | 5700 | 2250 | 1000 | 0 | 5880 |
| 6 | 30 | 3 | 360 | 20 | 70 | 1465 | 28568 | 10 | 16700 | 3000 | 0 | 1500 | 13248 |
| 7 | 40 | 3 | 600 | 30 | 80 | 3249 | 84474 | 15 | 64450 | 12000 | 4000 | 5000 | 12272 |
| 8 | 45 | 4 | 1000 | 30 | 85 | 3830 | 112028 | 18 | 73250 | 18000 | 0 | 0 | 33050 |
| 9 | 50 | 4 | 1600 | 40 | 95 | 7418 | 241085 | 22 | 157750 | 24000 | 15000 | 15000 | 62385 |
| 10 | 60 | 5 | 2400 | 40 | 105 | 8692 | 338988 | 26 | 251750 | 36000 | 0 | 0 | 113623 |

Budgeted total 827343 coins, Forge 573850, heads 97620, bags 20250, Grove 22000, remaining 113623. Head assumptions: Copper 60 and Iron 750 unchanged, future Steel 6000 each (not implemented), 2/3/4/6 Steel crafts in F7/8/9/10; 1–4 Iron crafts in each F3–6. Grove upgrade budgets use existing costs through 8 plots, no assumption maxed Grove. Residual is not a compulsory sink: additional crafts/saplings, missed efficiency, and optional upgrades can absorb it. No reward for challenges, boss rewards, premium currency or optimized storage sales assumed. 50% utilization gives ~636k gross before sinks (Forge26 may be unaffordable); 80% ~1.02m. Re-evaluate targets/rates against actual clean play before changing gates.

### Forge cost and rarity — source-implemented

Early cost exponent 3.5 -> 3.1 through target level 30, first upgrade stays 500, scale 6, round 50. From 31 onward cost = new raw cost(30) + old raw cost(target) - old raw cost(30), preserving original late marginal increases without a discontinuous price jump. Late-world economy is still unknown. No retroactive refund or existing weapon changes. Cumulative cost to Forge 5 4250, 10 26650, 15 91100, 20 233300, 25 500450, 26 573850, 30 951600, 200 5232982750. Previously 25 862700, 30 1746050. Forge still caps at 200, not 30.

Per-rarity cumulative tail overrides give newly unlocked Uncommon 5%, Rare 2%, Epic 0.5%; Legendary and higher retain old 0.1% initial tail and default curve. Same unlocks and retirement floors, class probabilities and power multipliers. At +5 levels Uncommon tail 25%, Rare 12%, Epic 5%; at +15 65%,45%,25%. Actual exact rarity = tail minus next rarity tail (respect previous tail bound/rounding). Exact probabilities as percent:
| Forge | Common | Uncommon | Rare | Epic | Legendary |
|---:|---:|---:|---:|---:|---:|
| 3 | 95 | 5 | 0 | 0 | 0 |
| 5 | 87 | 13 | 0 | 0 | 0 |
| 7 | 79 | 19 | 2 | 0 | 0 |
| 10 | 67 | 25 | 8 | 0 | 0 |
| 15 | 47 | 31.1 | 21.4 | 0.5 | 0 |
| 18 | 35 | 33.2 | 28.6 | 3.2 | 0 |
| 22 | 30.4667 | 24.5333 | 36 | 9 | 0 |
| 25 | 27.0667 | 22.9333 | 35 | 14.9 | 0.1 |
| 26 | 25.9333 | 22.4 | 34.6667 | 16.42 | 0.58 |
| 30 | 21.4 | 20.2667 | 33.3333 | 22.5 | 2.5 |
At Forge26 Epic+ tail 17%, six independent crafts at that Forge level have ~67% chance of at least one Epic+; this is an illustrative probability, not a guarantee or assumption every craft is at the final level. Legendary at unlock stays aspirational, increases with Forge advancement. Early rarity unlocks should feel meaningful, while high quality/levels/Grove remain routes for common weapons. Verify client preview uses same config (no duplicate chances). Existing rarity smoke invariants independently translated to arithmetic and checked across 1–200; no Luau runtime executed.

### Guardian and World Boss targets (F3+ design only)

First two retain existing config. Later thresholds account for normal crit expectation (5% chance x2), local metal and wood, level caps, quality and Grove/substat bonuses. Compare common cap10 Axe five logs at 30% vs 50% quality, no passive/ability bonuses, continuous nominal DPS. Representative integer damage/real hit cadence may differ. Common weapons with sufficiently good logs and modest boss specialization should remain viable; not a rarity requirement. Thresholds deliberately not a hard playtime lock.

| Forest cleared | Base tree HP | Metal strength | Wood strength | Guardian HP | Seconds | Required DPS | Common cap 30% DPS | Common cap 50% DPS |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 70 | 25 | 20 | 2600 | 45 | 57.8 | 65 | 80 |
| 2 | 125 | 25 | 30 | 4000 | 60 | 66.7 | 72 | 92 |
| 3 | 210 | 55 | 45 | 6750 | 45 | 150.0 | 144 | 178 |
| 4 | 310 | 55 | 60 | 8750 | 50 | 175.0 | 154 | 196 |
| 5 | 400 | 55 | 80 | 11275 | 55 | 205.0 | 167 | 219 |
| 6 | 500 | 55 | 100 | 14700 | 60 | 245.0 | 180 | 243 |
| 7 | 760 | 125 | 120 | 23400 | 60 | 390.0 | 338 | 426 |
| 8 | 1050 | 125 | 150 | 28200 | 60 | 470.0 | 358 | 461 |
| 9 | 1450 | 125 | 185 | 33900 | 60 | 565.0 | 381 | 502 |
| 10 | 1900 | 125 | 230 | 126000 | 180 | 700.0 | 410 | 556 |
F10 encounter is World Boss (180s), not a tenth Guardian. 700 DPS is provisional; high-quality Common with +26% combined effective boost over 50% quality baseline can meet this, or Rare/Epic with levels and moderate passives. No attack/minions. No exact gate timings claimed until runtime and player testing. The modeled 280m includes repeat crafts, upgrades, Grove activity and challenge attempts, not forced elapsed time. Major limitation: players may rush with higher-quality wood and inexpensive Grove Bossbane/other passives, so actual playtest may show substantial skips. Do not add artificial rarity/Forge requirements to fix that; adjust gate/economy jointly after observing builds. Ordinary HP unchanged.

Next: choose future species and layout, implement Forests 4–10, Steel and actual Guardian/World Boss configurations in stages. Deferred Studio validation: actual early and late income, rarity rolls/previews, forge cost consistency and saved progression, class hit cadence and practical boss DPS, time-to-clear across ordinary/lucky builds. No new smoke suite; no runtime test.

---

## Prior balance addendum — 2026-11-28 (early forest values remain current; later Forge costs and odds superseded above)

Source changes: Bamboo 0.5 kg/5 coins -> 1 kg/16; Oak 4 kg/16 -> 2 kg/60. Sapwood 0.5 kg/5 unchanged. Ironwood 10 kg/144 remains legacy, not an active World 1 wild forest, and will need a new species/economy assignment later. All physical logs resolve weight and sale price through MaterialDefinitions, including older stored logs; no inventory record migration. Geometry, wood strength, log yield, capacity tiers, gold sinks, premium costs unchanged.

### Starter and first three forests

Current copper head 60; iron head 750 (requires Forest3 access). Bag 10 kg; upgrades 15/20/30/40 kg for 250/1000/4000/15000. RNG forge consumes head + at least one log; five logs at Forge1 produce 35% dagger/65% axe, not guaranteed axe. At size 1, 12 sold Sapwood logs fund Copper; reserve 5 more separately, requiring 17 logs total (9 two-log trees). Full 20-log bag minus 5 retained = 75 coins. 15-damage fists at 0.4s interval, 70 base HP, 5 noncrit punches at 1x (7 at 1.3x). Conservative example: 9 trees x (1.6s first-to-last swings + 4s movement/pickup) + 25s round-trip/sale/forge overhead = ~75s for a craft when all logs are usable and sale-eligible. This is a scenario, not a verified 1–2 minute completion promise; travel and inventory UX remain unmeasured. Default auto-keep preserves size >=1.5 or mutated logs, so protected cargo can be craft material but not immediate cash. Selling/storage routing matters; no compulsory full bag sale or premium payment.

| Forest | Base coins/kg | 10kg bag at size 1 | Trees per bag (ceil) | Assumed handling+combat per tree | Assumed round-trip/sale overhead | Gross coins/min |
|---|---:|---:|---:|---:|---:|---:|
| Sapwood | 10 | 100 | 10 | 6s | 25s | 71 |
| Bamboo | 16 | 160 | 2 | 6.4s | 40s | 182 |
| Oak | 30 | 300 | 3 | 6.4s | 55s | 243 |

Representative equipped farming example uses size-1 sale-eligible logs, fixed yields 2/5/2, 10kg capacity, rounded bag count; no claim of actual observed rates. Travel assumptions unmeasured, no skill/crit/cleave/buffs, no reserve/auto-keep deductions, no overflow sales. Oak yield rises to 3 for >=1.3. Exact size-sale factor is size squared: across the current unconditioned size bands E[size^2] ~=2.9904, but under 1.5 threshold only 61.5% of tree rolls qualify before mutations and conditional E[size^2] ~=1.1633. Do NOT use unconditional average as realized coin income; the larger logs are preferentially stored by default. Players can alter auto-keep or selectively sell storage. Size-1 example makes comparison transparent, not a simulation of auto-keep.

- First guardian 2600/45s =57.78 average DPS, second 4000/60s =66.67. Existing thresholds unchanged. A representative Copper Axe 41 damage x1.3872/s ~=56.87 noncrit nominal DPS (baseline crit and levels bring it above first threshold); early dagger or low quality may need a little leveling, another craft or passive. Second gate encourages stronger Bamboo Copper craft and leveling; no Iron needed before Forest3. Actual server cadence is unknown pending Studio, and no XP during attempts.
- Copper target 1–2m; Forest2 entry 3–5m; Forest3 entry 5–10m; first Iron 10–15m (cumulative targets). With the illustrative Bamboo rate, 750 coins = ~4.1m of gross farming from zero, or 3.1m of Oak gross rate after access. No guarantee since competing sinks and retained logs matter.
- Keep existing 250 coin first bag, 500 Forge2, 850 Forge3, 750 Iron prices for this pass. Iron should be reachable without buying Forge2/3 or a bag first; none of these are mandatory gate requirements. A 15kg Oak bag can carry seven logs (420 coins at size 1) vs five currently. Later re-evaluate if bag pressure dominates chopping.
- Current Forge cumulative costs: F2 500, F3 1350, F5 4750, F7 11900, F8 17550, F12 62600, F15 133400, F20 373650, F25 862700, F30 1746050. These still imply strong later income growth or a changed cost curve to meet world targets; do not blindly extrapolate current Oak income. Rarity odds remain unchanged for this pass. Revisit early rarity unlock odds and total Forge expenditure together with F4–10 income; don't require a rare craft or time-gated gems for ordinary progression.
- Deferred Studio validation: actual clean-start first craft time, collected vs protected log counts, sale-trip time, effective coins/min, first guardian across classes/quality, second guardian and Iron timing, bag upgrades and Forge spending tradeoffs. No new smoke runner. No runtime validation performed.

---

## Historical first quantitative pass (retained for context)

Source-derived arithmetic checked against the current Luau configuration (commit 0376e8b). This is not a Roblox playtest or complete player simulation. Assumptions: size-1 logs/trees unless stated, no travel, pickup, bag-sale time, crits, buffs or player skill; all four recurring quests claimed every week; no Gem payouts from leaderboards or purchases. Existing `tools/crafting_balance_sim.py` models an older prototype and must not be used as the authoritative current economy.

## Changes made
- Copper head 150 → 60 coins, allowing one ordinary 10 kg Sapwood bag to fund a head and retain three crafting logs (17 sold = 85 coins at size 1). Actual sales require locking the retained logs.
- Forge first upgrade 2,000 → 500 coins. Polynomial scale 10 → 6 preserves a steep later gold sink. Later forest income is not defined yet.
- Default ascension pity cap 30 attempts rather than unbounded ceil(1.5/chance). Keep per-rarity override. Crystals are consumed on all resolved attempts, so an uncapped 1% final tier previously risked 150 attempts / 2,400 Gems / 54.5 weeks of full quest income. It now has a maximum of 30 attempts.
- All numerical changes are provisional and in authoritative balance modules.

## Forge and rarity
All 200 Forge levels checked: weights are integer, positive for eligible rarities, zero outside the configured floor/ceiling, and sum to 1,000,000. A newly unlocked top rarity is intentionally rare.

| Forge | Min | Max | Top chance | Upgrade to level | Cumulative gold |
|---:|---|---|---:|---:|---:|
| 2 | Common | Common | 100.000% | 500 | 500 |
| 3 | Common | Uncommon | 0.100% | 850 | 1,350 |
| 7 | Common | Rare | 0.100% | 4,150 | 11,900 |
| 15 | Common | Epic | 0.100% | 28,250 | 133,400 |
| 25 | Common | Legendary | 0.100% | 124,100 | 862,700 |
| 60 | Rare | Ultra | 0.100% | 1,981,850 | 29,185,850 |
| 110 | Legendary | Celestial | 0.100% | 14,948,850 | 386,216,250 |
| 200 | Ultra | Transcendent | 0.100% | 114,589,850 | 5,252,198,750 |

At Forge 25, the first Legendary has 0.1% natural craft odds (1,000 crafts on average if level stays fixed); upgrading beyond the unlock changes the odds. At Forge 200 the newly unlocked Transcendent likewise remains at 0.1%, with no further Forge levels to improve it. This is an explicit endgame balancing decision to revisit, not a validated target. The last level costs 114,589,850 and the cumulative cost is 5,252,198,750. Only two current production forests exist, so this is NOT attainable on a reasonable playtime curve using present Ironwood alone. Add future forest income, then calibrate the Forge cost curve; don't pretend current two-forest throughput supports 200 levels.

## Time-gated economy
Full recurring task income: 44 Gems/week, 22 crystals/week if all Gems are exchanged. At-least-one-success expected attempts with hard pity N: (1-(1-p)^N)/p. Below, gold/logs/Gems consumed on failures and success; excludes XP and Forge gates.

| From → To | Chance | Pity | Crystals / attempt | Expected attempts | Expected Gems | Max Gems | Expected weeks |
|---|---:|---:|---:|---:|---:|---:|---:|
| Common → Uncommon | 85% | 2 | 1 | 1.15 | 2.3 | 4 | 0.05 |
| Uncommon → Rare | 70% | 3 | 1 | 1.39 | 2.8 | 6 | 0.06 |
| Rare → Epic | 50% | 3 | 1 | 1.75 | 3.5 | 6 | 0.08 |
| Epic → Legendary | 35% | 5 | 2 | 2.53 | 10.1 | 20 | 0.23 |
| Legendary → Mythical | 20% | 8 | 2 | 4.16 | 16.6 | 32 | 0.38 |
| Mythical → Ultra | 12% | 13 | 3 | 6.75 | 40.5 | 78 | 0.92 |
| Ultra → Divine | 8% | 19 | 3 | 9.94 | 59.6 | 114 | 1.35 |
| Divine → Celestial | 5% | 30 | 4 | 15.71 | 125.7 | 240 | 2.86 |
| Celestial → Eternal | 3% | 30 | 5 | 19.97 | 199.7 | 300 | 4.54 |
| Eternal → Primordial | 2% | 30 | 6 | 22.73 | 272.7 | 360 | 6.20 |
| Primordial → Transcendent | 1% | 30 | 8 | 26.03 | 416.5 | 480 | 9.47 |

Ascending through every tier instead of replacing a weapon via crafting costs ~1,150 Gems in expectation (26.1 weeks) and at most 1,640 Gems (37.3 weeks). Final step alone: ~416.5 Gems (9.5 weeks), maximum 480 Gems (10.9 weeks). Crafting can skip ascension expenses, intentionally. Awakening 30 Gems ≈ 4.8 days; replacement 100 Gems ≈ 2.27 weeks. Competing sinks lengthen progression. This is an initial time-gate, not a promise of final pacing.

## Forest/wood baseline
| Species | kg/log | size-1 coins/log | Full 10kg bag sale (size 1) |
|---|---:|---:|---:|
| Sapwood | 0.5 | 5 | 100 |
| Bamboo | 0.5 | 5 | 100 |
| Oak | 4 | 16 | 32 |
| Ironwood | 10 | 144 | 144 |
Sapwood/Bamboo base HP 40, Oak 175, Ironwood 180, Forest 2 barrier 600. Starter fists damage 5 = eight noncrit hits at size 1. Fixed copper with three normal Sapwood logs nominal power 14 = three hits on Sapwood, thirteen on Oak, forty-three on barrier. Fixed iron with Ironwood logs nominal power 26 = seven hits on Ironwood. Actual rarity, levels, size (HP scales as size^1.4), crits and buffs change this. No fixed tree-kill time claimed without measuring actual weapon cooldown in Studio.

Standard crafting consumes one head and 3 logs. Experimental RNG mode is still Studio-only; at size 1 quality factor is 0.6, Copper + Oak reference 35 yields approximate dagger 11.55 damage / 0.35 s, axe 26.25 / 0.60 s, hammer 75.6 / 1.10 s before +/-10% rolls and progression. Against 175 HP, ideal continuous swing time ~5.6 s, 4.2 s, 3.3 s respectively; hammer also hits up to 2 nearby targets with reduced damage. Class count and material consumption differ, so these are isolated combat comparisons. Measure travel and collection overhead before declaring an optimal class.

## Grove and mutations
- Wild eligible trees: ordinary sapling 9.4%, any mutated sapling 1.2% per tree, before Grove passives. Jackpot size band 0.3% conditional on sapling; a particular one of four equally weighted mutated families at jackpot size is ~1 in 111,111 eligible trees. Sapwood is excluded.
- Grove regrowth is 30 s with 65–100% size roll; 3 slots can produce at most 6 logs/min and 10 slots 20/min excluding chopping time. All Grove upgrades cost 62,000 gold. Grove output is protected storage, not automatic passive sale income; actual collection/sale flow and inventory pressure matter.
- Sell value scales as size squared, capacity is fixed by species. At 4.9× size a log is ~24× ordinary value, while HP is ~9.25× at the same species. Rare high-size trees can therefore substantially accelerate ordinary income. At 1×, 10 Golden Grove trees provide +50% sale bonus; if all have Prosperity genetics this becomes +100%, and scales linearly with actual size. Do not infer a stable late-game coin rate from maximum theoretical buffs.
- Golden Touch extra kill payout is 20% + 85% × potency of one species base log value (not total log yield); Golden Rush maximum stacks = 4 × (10% + 32% × potency); Golden Jackpot expectation = (10% + 15% × potency) × (4 + 4 × potency). At full potency, ~105%, 168%, 200% extra base-log value respectively before rounding/caps. Duplicate families blocked. AoE can trigger verified kills but not recursively chain effects. Measure clustered-forest throughput before changing these values.

## Studio validation required
Disable `StudioForgeSandbox.ENABLED` to observe resource spending (it refills coins, heads, logs, Gems and crystals). Existing tests updated, not executed in Roblox Studio. No new smoke runner. Check the first craft, actual Forge progression, second-slot-only Legendary, Awakening after slot 2, paid replacement with exact log UIDs, successful/failed crystal ascensions, daily/weekly repeat/rejoin protection and legacy weapon migration. Use real play-session telemetry for forest income, time-to-kill, bag trips, resource bottlenecks and QoL. Leaderboard event rewards, future premium perks/monetization, additional forests, acquired mutation/treasure systems remain deferred rather than pretending they are complete.

## Pending player playtest — saved 2026-11-25

User is away from their PC and has explicitly NOT completed the latest integration tests. Keep these pending for their next Studio session; design discussion can continue in the meantime. Do not mark these as passed or require new smoke suites.

### A. Integrated feature check (use developer fixtures for speed)

**Studio developer commands:** type `/dev help` in Roblox's in-game chat during Studio Play; feedback is in server Output. `/dev sandbox on` and `/dev refill` restore the existing developer supplies. To inspect real deductions, `/dev sandbox off`, then set exact test balances with `/dev coins 1000000`, `/dev gems 1000`, `/dev crystals 100`. `/dev forge 25` sets the Forge to Legendary's unlock level; `/dev maxweapon` caps the equipped real non-fixture weapon without modifying rarity or pity. These commands are Studio-only, target the caller's own profile, and the refill toggle is server-session-wide. A clean progression test still requires disabling grants before a fresh profile loads, not merely toggling refill off afterward. Runtime verification pending.

- [ ] Start a synced Studio Play session; confirm economy HUD loads without Luau active-local-limit errors. Check visible coins, bag, Gems and Ascension Crystal balances.
- [ ] Confirm Grove management/shop does not obstruct the screen by default; open at the west hub Grove Shop stall, close by leaving or closing it, and check planting at the personal plot still works.
- [ ] Check Grove shop stock/quality, capacity upgrade and mature-tree passive changes on harvest and regrowth.
- [ ] Check Story/Daily/Weekly quest progress and recurring Gem claims; confirm completed claims cannot be claimed twice.
- [ ] Check Forge upgrades and rarity floor/ceiling previews against current Forge level; test a forged weapon's rarity and XP.
- [ ] Temporarily disable StudioForgeSandbox auto-refill when verifying deductions (it otherwise replenishes balances); use existing fixtures or deliberate test resources rather than new test systems.
- [ ] Exchange Gems for Ascension Crystals; verify displayed balances update.
- [ ] Test successful and failed ascension attempts, including crystal/coin/log deductions, pity, destination Forge gate and retained level on success.
- [ ] Craft or ascend to Legendary+; confirm exactly one free second ability, independent of slot 1, no duplicate families and no reroll on further ascensions.
- [ ] Awaken an empty first slot, including when slot 2 is populated; replace slot 2 using selected mutated logs. Verify costs, family restrictions and original weapon stats/level/other slot preservation.

### B. Clean new-player pacing check (separate session)

- [ ] Disable StudioForgeSandbox and other development loadout/sapling/combat fixture grants for a dedicated fresh Mock profile; restore normal dev convenience afterward.
- [ ] Start unarmed; chop Sapwood/Bamboo, collect a stack, reserve crafting logs, sell, purchase a Copper head (current 60 coins), and craft/equip the first weapon. Test both quick-travel buttons during ordinary gameplay.
- [ ] Record time to first stack, sale, craft, Grove planting/first harvest, Forest 2 access and Forge Lv2/first Iron progression. Note any tedious steps or unclear objectives; compare first weapon to fists.
- [ ] Review early income, bag pressure and attack feel using actual gameplay, not theoretical travel/cooldown assumptions.

Production RNG forge rollout, true DataStore persistence and deferred two-player ownership verification are separate release work. No runtime validation has been performed by this assistant.

## RNG-only forge update — 2026-11-26

The user approved RNG-only forging. Fixed recipes are no longer craftable; fixed-recipe arithmetic above is historical, not a current player path. RNG recipes retain existing material/class/rarity rules and minimum one log, with server validation and existing head/metal/forest/Forge gates. Clean-profile pacing is still pending; no balance numbers changed. User reported the earlier integration playtest worked very well overall; individual checklist outcomes were not separately recorded. Preserve the prior checklist as a reference rather than requiring another identical round.
