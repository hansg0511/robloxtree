# Core economy — first quantitative pass

## Current balance addendum — 2026-11-28 (supersedes obsolete fixed-recipe/HP/forest assumptions below)

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
