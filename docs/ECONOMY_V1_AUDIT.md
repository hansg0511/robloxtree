# Economy v1 — code-grounded starting audit
_2026-11-24 · branch `dev/gameplay-prototype` · Phase 4E.1 in progress_

**Scope:** current *implemented* rules, not an approved final economy. This is an initial source audit and a list of decisions/measurements; it does not change gameplay values, invent a currency, or authorize prices. Older prototype docs describe rules that have since changed; trust the linked source modules for current behavior.

## Current player-facing resource map

| Resource / progression | How it currently enters the account | Where it is spent or limited | Status |
| --- | --- | --- | --- |
| Coins | Sell eligible *unlocked, carried* logs at the base; server-verified Golden mutation kill bonuses | Axe heads, Forge Lv2, carry upgrades, sapling shop, ascension attempts | Implemented, values provisional |
| Wild logs (Sapwood/Bamboo/Oak/Ironwood) | Server-verified wild tree death produces physical owner-reserved drops; ordinary size-based yields (1–3), **Sapwood 2**, Bamboo 5 | Standard/RNG forging (RNG Studio-only), ascension (eligible bag logs only), sales, carrying / pickup | Implemented; starter Sapwood update pending Studio playtest |
| Mutated wild logs | Mutation rolled per wild tree life (currently 6% chance), inherited by logs from that tree | Premium/mutation forging, Awakening/Infusion test costs, potentially sale (not currently a distinct priced material) | Implemented; rarity unbalanced |
| Grove harvested logs | Each mature owned tree grants one inherited-species/mutation log into protected storage, then regrows | Weapon crafting or upgrade inputs; protected storage cap; manual harvest time | Implemented; current full-capacity 25 trees, 30s growth cycle are provisional |
| Normal saplings | Wild sapling discovery, always-on rotating shop entries, introductory quests | Plant into Grove; uprooting planted tree destroys its sapling | Implemented |
| Rare/mutated saplings | Rare wild mutation discovery, rotating rare shop, initial story quest; later events proposed | Limited Grove plot slots and recurring manual harvest | Implemented paths; odds/prices provisional |
| Axe heads | Purchased at shop for coins | One head consumed by forge recipe | Implemented |
| Weapon XP and rarity | HP-clamped verified damage and kill XP, natural rarity on craft; ascension consumes currency/logs | Per-rarity level caps, ascension gating and repeated attempts | Implemented, XP/chances/costs provisional |
| Forge level | Bought for coins | Forge-tier recipe/ability eligibility | Level 1→2 implemented, 2,000 coin placeholder |
| Awakening / Infusion | Mutated logs provided through existing craft inventory | Studio-only test recipes: 2 / 3 matching mutated logs; live upgrades disabled by `ECONOMY_CONFIGURED=false` | Gameplay works; **production recipes missing** |
| Daily / weekly quests | Valid wild tree deaths and mature Grove harvests fill tasks | No recurring rewards or claim/premium currency yet | Progress implemented; payout economy missing |
| Leaderboards | Verified wild tree deaths | No reward or spending | Native server player list implemented; future in-world boards and weekly boss in backlog |

## Code anchors / parameters (not final prices)

- `Economy/MaterialDefinitions.luau`: **Sapwood 0.5kg / 5-coin base sale**, Bamboo 0.5kg / 5 coins, Oak 4kg / 16 coins, Ironwood 10kg / 144 coins. Sapwood's back-stack visual scale is 0.7 (prototype), and log kg does not depend on tree size.
- `Inventory/LogService.luau`: actual sale per log is `round(baseSellValue * SizeScale^2)` (minimum 1); bag kg cost is fixed per species, **not scaled by size**. Initial bag 10 kg. Unlocked carried logs sell at the base; protected stored logs are available for crafting, not included directly in the bag-sell request.
- `Trees/TreeDefinitions.luau`: **Sapwood 20 base HP / 3s respawn / 2 logs**, Oak 60 base HP / 3s, Ironwood 180 base HP / 5s, Bamboo 18 HP / five logs; first barrier 600 HP and Copper-tier prerequisite. Actual HP scales by `SizeScale^1.4`.
- `Inventory/LogService.luau`: ordinary wild logs per tree = 1 if scale <0.7, 2 if <1.3, else 3; explicit `LogYield` overrides this (**2 Sapwood; 5 Bamboo**). Ground pickup / overflow / protected auto-keep rules also constrain realized harvest.
- `Economy/AxeShopCatalog.luau`: Copper / Iron heads 150 / 750 coins; fixed recipes use one head plus three logs; Forge Lv2 costs 2,000 coins; bag capacity upgrades 10→15 (250), →20 (1,000), →30 (4,000), →40 (15,000) kg.
- `Economy/ShopHandler.server.luau`: **experimental RNG class forging is Studio-only** (`RunService:IsStudio()` guard in `craftExperimental`). Standard deterministic Copper/Iron craft paths remain. This is a **release-readiness decision** separate from balance: decide what the actual shipping forging path should be before making an economy model for production.
- `Grove/SaplingShopRules.luau`: common saplings cost 100/250/800 coins; rare example 3,000 or 5,500; shop restock every 600s, with 40% chance of one rare offer per restock. All provisional.
- `Grove/SaplingDiscoveryService.luau`: 6% wild mutation rate, 10% ordinary sapling discovery, 20% mutated-tree sapling discovery. Mutation appearance is per tree life; expected incidence of a mutated-tree sapling is about **1.2% of eligible wild tree deaths**, conditional on rates/eligibility (6%×20%).
- `Grove/GroveGrowthRules.luau` and `GroveService.luau`: maturation 30s per tree, maximum planted capacity currently 25, one harvested log/cycle; manual harvest and protected-storage availability can reduce real output. **Grove capacity upgrade is a planned sink, not implemented.**
- `WeaponProgressionRules.luau`: verified actual-damage XP at 1/HP plus a 25% max-HP kill bonus. Common cap 10, Rare 20, Epic 30, Legendary 45, Ultra 65; XP to next = 100+25×current level. All provisional.
- `WeaponAscensionRules.luau`: ascending Common→Rare 50%, 150 coins+1 log; Rare→Epic 25%, 600+2; Epic→Legendary 10%, 2,500+3; Legendary→Ultra 2%, 9,000+4; failures consume costs and pity is capped at `ceil(1.5/p)`. These costs and rates are placeholders.
- `Economy/WeaponUpgradeRules.luau`: only Studio testing permits Awakening/Infusion; **no agreed live costs**. Do not introduce Heartwood or unrelated items by assumption.
- `Quests/QuestRules.luau`: story grants saplings. Daily/Weekly objectives are implemented but have **zero payouts or claims**.

## First comparisons at size 1.0 (illustrations, not measured player time)

At normal size 1.0, Sapwood, Oak and Ironwood each yield 2 logs if both drops can be collected; **Forest 1 is now primarily Sapwood** (14 Sapwood, 4 Oaks and the existing Bamboo clump):
- **Sapwood: 2×5 = 10 coins** worth of logs; both weigh 1kg. Starter bag 10kg fits **20 Sapwood logs** (10 trees) if no other logs are being carried. This makes a tall backpack stack feasible even before bag upgrades, though actual stack height needs Studio confirmation.
- Oak: 2×16 = **32 coins** worth of eligible logs; both weigh 8 kg, fitting the initial 10 kg bag.
- Ironwood: 2×144 = **288 coins** worth, but each log weighs 10 kg, so the starting bag only holds **one at a time**. Other drops require overflow / later retrieval, so actual coin production per minute is *not* simply 288 per kill.
- Copper head alone = 150 coins = **15 normal-size Sapwood tree yields** or about five full Oak tree yields sold, *before* retaining three more logs for the fixed Copper craft. From Sapwood alone, the rough minimum is 17 tree deaths (15 to sell + 2 to obtain 3 craft logs) and **more than one sell trip** using the 10kg starter bag. That's a pacing warning, not an approved price target.
- Forge Lv2 2,000 coins is equivalent to **125 normal-size Oak logs** or **14 normal-size Ironwood logs** sold, ignoring Golden bonuses and size variation. Distance to the sell station, ground-drop retention and storage handling may dominate the time.
- Verified weapon XP at exact base HP across all hits plus death bonus: **75 XP** for a size-1 Oak, **225 XP** for a size-1 Ironwood, assuming the same eligible weapon received all damage. This is per-tree XP potential, not a measured clear-speed comparison.

These numbers already suggest **transport/carrying friction, ease of level-up, and renewable rare-wood supply** deserve attention before we re-price upgrades or duplicate forest tiers. **Do not confuse Studio-only forge/upgrade prototypes with a functioning published economy.**

**Sapwood scope note (2026-11-24):** Sapwood logs use the existing carrying, selling, crafting and mutation flow. The current Sapwood forest tree is not registered as a wild sapling-discovery source and no Sapwood Grove sapling is offered; the established Oak/Bamboo/Ironwood Grove sources are unchanged. Both the new forest visual and live reward integration are source-committed, **not yet Studio-validated**. No bag capacity, existing material weights or future upgrade prices were changed.

## Next measurements / decisions — Phase 4E.2

1. Define acceptable **player time**, not coin targets: e.g. first Copper craft, Forest 2 unlock, Forge Lv2 / first Iron craft, first meaningful mutation weapon, first ascension, and a viable Infusion. Keep desired durations as a playtest decision.
2. Build a small **current-system throughput model**: starter and Copper/Iron weapon attacks per second, HP and respawn cycles, average size/log value, bag weight, sales travel time, rare mutation sources, and Grove harvesting. Run baseline vs larger AoE weapon scenarios; distinguish per-tree rewards from per-minute earning rates.
3. Quantify how many **chops, logs, shop trips, and minutes** each representative upgrade needs under existing rules; find the worst bottlenecks. Include unbalanced probability/ascension pity and Golden ability payouts.
4. Only then decide which costs should be ordinary coins, common logs, mutated logs, scarce catalysts if genuinely justified, or task rewards. **Keep premium currency and its uses an open decision.**
5. Once v1 target pacing is agreed, implement *minimal* config changes and recurring reward payouts. Do not add new systems, forests or smoke suites to solve pricing problems prematurely.

## Deferred, not lost

- Live DataStore persistence and migration check before publishing; Studio currently boots using `ProfileStore.Mock`.
- Two-player first-hit ownership validation before multiplayer launch (single-client user device constraint).
- In-world leaderboard board, weekly tree/boss event, world/forest content beyond two playable forests, dense treasure maze (draft backlog), final UI polish.
