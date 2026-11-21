# Weapon + Grove Progression — Implementation Roadmap
_Last reviewed: 2026-11-22. Design handoff and implementation checkpoint for the Roblox axe/forest game._

> **Status:** Design decisions recorded here are **not** a claim that the functionality is implemented. Keep this file updated as decisions or implementation status change.
>
> **Implementation branch:** `dev/gameplay-prototype`. Work on this existing branch; do not create a new branch for this roadmap. Preserve the production world and existing Forest A/B Design Lab scenes.

## Goal and guiding principles

Ship a fun playable **chop → collect logs → forge weapons → level weapons → ascend rarity → improve abilities → chop stronger forests** loop before attempting detailed economic balancing or final UI polish.

- Flashy, rewarding, active-first "brainrot" gameplay; simple enough to understand quickly.
- **No account rebirth** planned. Progress, precious weapons and Grove trees persist.
- AFK weapon training is allowed but much less efficient than active play; no AFK resource generation.
- RNG should create exciting *outcomes*, not destroy rare items or cause failed basic crafts.
- Keep exact rates, prices, level caps, log requirements and damage figures as **tuning data**, not prematurely fixed design.
- Cross-server announcements and premium visual polish can wait until the core loop works.

## Current code baseline (verified on dev/gameplay-prototype, 2026-11-21)

- Experimental Forge rules exist in `src/ReplicatedStorage/Shared/ExperimentalForgeRules.luau`; class odds currently depend on log **quantity**; existing counts/ranges are temporary prototypes.
- Classes: **Dagger**, **Axe**, **Battlehammer**. Battlehammer has a **Cleave** effect prototype in the generic effects dispatcher (`src/ServerScriptService/WeaponEffects/Dispatcher.luau`).
- Grove mutation definitions currently include **Golden**, **Giant**, **Crystal**; this **does not reflect the approved future roster**.
- New mutation powers, manually activated skills, weapon rarity/XP/ascension, awakening, infusion, Ultra mastery, and multi-tier forge rules described below are **design-only**, not yet coded.
- **Implementation status:** Basic chopping, log collection, experimental class-roll forging, basic weapon inventory, and one Cleave effect work as prototypes. **Not implemented:** rarity rolls; weapon XP/leveling; rarity ascension/pity; real forge tiers; mutation ability pools and potency; awakening/infusion; active skills; complete Grove sourcing/upgrades/economy. **Correction from code inspection (2026-11-22):** substantial Grove mechanics ALREADY exist—persistent planted saplings, size rolled at planting/regrowth, mature-only E-prompt harvest, one protected log per harvest, and fixed provisional 30-second growth. Do not reimplement the Grove from scratch. The new rarity/weapon progression loop does not yet exist.
- **Keep scope explicit:** We have thoroughly designed mutation **abilities** and progression, but **manual activation skills** (if any) have *not* been specified individually. Do not invent and implement an active-skill system merely because it appears in the effect taxonomy.
- Do not remove functioning experimental forging or Cleave before equivalent functionality is integrated and tested.

## Locked / agreed design

### A. Weapons, logs and forge
1. Classes have different base combat profiles. Weapon class is **RNG rolled from the number of logs offered**, not selected via a fixed mold. More logs bias toward heavier classes; per-tier curves may differ.
2. One **upgradeable forge** with access to previously unlocked lower tiers. No fixed total number of tiers yet. Forge tier:
   - sets base-stat and mutation-potency ceilings;
   - shifts **log quantity → class odds** so Daggers can be made with several logs at high tiers;
   - unlocks additional entries in each mutation's ability pool.
3. Ordinary species such as Bamboo, Oak and Ironwood initially differ primarily in material strength, not bespoke powers.
4. Log/tree size affects weapon size and related reach/AoE/quality. **Giant** mutation increases the tree's genetic size potential, producing bigger logs; do **not** add an unrelated second "Giant damage multiplier."
5. Logs containing the mutation count in **normal shared ingredient slots**; no separate mutation-only forging slot.
6. Mutation potency comes from **sum of individual qualifying mutated logs' size/quality-weighted contributions**, each with a per-log cap, constrained by the **forge tier's potency ceiling**. One huge log cannot immediately give maximum potency; normal logs do not arbitrarily dilute mutation potency.
7. First release: one ability-granting mutation type per craft. Mixed mutation types / multiple mutation origins can be a later unlock. Always show chance/range previews and warn before consuming logs wasted against a forge cap.
8. A forge craft should produce a weapon (no failed craft). RNG governs class, ability within available pool, rarity, and rolls within bounded stat/potency ranges.

### B0. Weapon bonus architecture: behaviors versus sources

**This distinction is agreed and should be preserved in the eventual data model.**

Four possible **behaviors**: (1) base stat adjustments, (2) always-on passives, (3) triggered effects such as Cleave on hit, (4) player-activated skills. An ability's behavior is separate from **where it came from**.

Five **sources**: (1) weapon class, (2) ordinary forging materials, (3) wood mutations, (4) Grove/tree passives, (5) player upgrades/progression. Grove passives and manual skills are conceptual expansion points, **not a finalized list of new mechanics to implement now**.

Weapon classes have a **hybrid identity**: base characteristics for all (Dagger fast/short reach; Axe balanced; Battlehammer slow/heavy); optional special innate effect on some classes (Battlehammer Cleave), rather than forcing a unique effect or activated skill on every class. Class innate effects do **not** consume mutation slots.

We have **not** chosen the exact player-activated skills, how they are equipped/cast, or which weapon classes may use them. Preserve extension points in the dispatcher, but **defer skill content design/implementation** until the core weapon loops work. Don't conflate the Golden/Frenzied/Shocked mutation abilities with an entirely new manual-skill subsystem.

### B. Mutation families and abilities
- **Golden**, focused **only on gold**: **Golden Touch** (reliable bonus gold on tree kill), **Golden Rush** (gold multiplier from quick kill streak), **Golden Jackpot** (rare big gold payout).
- **Frenzied**: **Fervor** (consecutive hits on the *same tree* boost attack speed), **Bloodrush** (tree kill boosts movement speed temporarily), **Rampage** (tree kills boost damage temporarily).
- **Shocked**: **Thunderstrike** (lightning after X successful hits), **Chain Lightning** (arcs to more distant nearby trees, unlike Cleave).
- **Giant**: genetic size potential, **no mutation ability roll**.
- **Crystal and Rainbow are not in the approved initial roster** (Crystal remains in prototype code and needs migration planning).

Unlock one ability in each relevant mutation pool at low forge tiers; higher tiers unlock other entries, *not* extra simultaneous abilities for free. Unlocked earlier abilities remain rollable at high tiers. A newly unlocked rare ability has **nonzero chance even with low mutation potency**; higher potency improves its odds and strength, while common abilities retain nonzero chance. No potency threshold to permit an unlocked ability.

- Keep **ability identity**, **ability potency**, and **weapon rarity** conceptually separate.
- Innate class effects such as Battlehammer Cleave do **not** occupy mutation ability slots.
- Avoid duplicating abilities on one weapon, infinite effect recursion, unlimited attack-speed/damage stacking, or secondary effects triggering themselves.
- Initially one primary mutation ability, with **at most one extra infused ability at Legendary/Ultra**. Third mutation slot is **not planned** for first release.

### C. Weapon rarity, leveling and ascension
- Standard ladder: **Common → Rare → Epic → Legendary → Ultra**.
- Rarity may be **rolled directly on original forging at any forge tier**, even by a beginner. Natural high-rarity craft starts at **Level 1 of the rolled rarity** with its higher level cap (skips prior ascensions).
- Players can also **ascend** a weapon one rarity at a time by reaching the current rarity's **level cap**, paying gold/materials, and attempting an RNG upgrade.
- Rarity grants better level growth and higher caps; sufficiently high rarities unlock additional ability capacity / mastery. Proposed table:
  - Common / Rare / Epic: **one mutation ability slot**, with ascending stat growth and caps.
  - Legendary: **second mutation ability slot** becomes available.
  - Ultra: **two slots**, improved growth and **mastery/enhancement of existing abilities**, **not a third slot**.
- Rarity may improve base weapon stats, but must **not** overwrite original forged material quality, mutation identity or mutation potency. Avoid an unexplained huge rarity multiplier.
- **Successful ascension resets level and earned level-based stats to Level 1.** A newly ascended Epic Lv1 **can and should be weaker** than the Rare weapon at its previous max level. Original forged stats, size, original abilities and individual potency rolls remain unchanged. New max level / higher growth eventually surpass prior peak.
- Failed ascension consumes resources but **does not destroy, downgrade, reset levels, or remove abilities**.
- **Hard pity:** with per-attempt success probability `p` (as a 0–1 fraction), guarantee by attempt `ceil(1.5 / p)`. E.g. 1% → 150 attempts. Display real chance, attempt count and remaining tries. Pity persists **per weapon, per current ascension step**; success clears it. Exact rates and costs are pending.
- **Secret** is separate from the grindable Ultra rarity ladder: a very rare natural discovery/variant, **not** something regular rarity ascension creates. Define Secret details later.
- Ultra should also be obtainable by ongoing grinding; eventual reward paths like weekly leaderboard **upgrade materials/assistance** are possible, but leaderboard exclusivity is discouraged.
- High-rarity forge results and successful high-rarity ascensions may trigger celebratory effects / local or global announcements; later add spam guards. Preserve naturally forged versus ascended provenance if useful, without intrinsic combat inequality.
- Rarity unlocks real improvements and cosmetics, not merely a label; exact mastery effects and rarity stat curves remain for later balancing.
- An early-game naturally forged Ultra can still be **weaker than** a much higher-forge-tier Epic, even after leveling; rarity is an within-tier growth/progression axis, not global power ranking.
- Rarity rolls and mutation-ability rolls are separate. An Ultra forged with ordinary logs has the rarity-based **capacity** but starts with **empty mutation slots**; ability acquisition requires Awakening/Infusion using new logs. Natural high-rarity does not conjure free mutation abilities.

### D. XP and training
- Weapon XP from a **hybrid** of (i) actual damage dealt, capped at remaining tree HP, and (ii) tree-kill bonus weighted by difficulty/value.
- Damage from registered secondary effects (Cleave, Chain Lightning) counts **only to the extent it actually damages trees**; handle attribution and avoid double counting.
- No overkill / invulnerable-target XP exploits. Avoid pure per-hit incentives that distort fast versus slow weapons.
- **AFK training** is allowed at a **substantially reduced** XP/hour compared with active chopping. It grants XP only, not gold/logs/saplings/ascension, and stops at level cap. Capped offline accrual is an optional future extension; exact implementation and rate not locked.

### E. Mutation Awakening / Infusion
- Rarity controls **slot capacity**, but mutation abilities only appear through actual mutated logs.
- Weapon forged without mutated wood can later gain its **first ability** through **Mutation Awakening**: separate forge progression unlock (does **not** require Legendary); costs fresh qualifying mutated logs, gold and possibly an awakening material. More costly than including mutated logs in the original craft.
- New logs determine the awakened ability choice and its own potency; awakening preserves class, rarity, size, level and existing base stats.
- Legendary/Ultra second slot can be filled via **Mutation Infusion**, using new mutated logs and gold. Infused ability potency is calculated **independently from those new logs** (not copied from original mutation).
- Early infusion uses same mutation family as primary where one exists; mixed families may unlock in late game. Duplicate abilities disallowed. Initial ability protected; infused secondary can eventually be rerolled/replaced by paying additional materials.
- Awakening and infusion do not "fail to produce an ability"; randomness picks ability and potency. Forge tier gates which abilities are eligible.
- Balance combination effects via central caps/diminishing returns and nonrecursive triggers. No automatic arbitrary penalty for all secondary abilities until tested.
- **Giant cannot be infused** as a combat ability; genetic size is established by the sapling/tree and resulting log.

### F. Grove/sapling economy — minimum structure
- Mutated sapling **consistently produces logs carrying its mutation every regrowth**. No extra per-harvest mutation RNG for an already mutated sapling.
- Rare saplings are scarce; normal saplings readily obtainable. Candidate sources: rotating shop stock, wild discoveries, quests/events. Do not make access to basic saplings depend on rare shop restock.
- Grove has limited slots/capacity and can be upgraded with gold. Saplings can become valuable persistent assets; tree stump regrows after chopping.
- Distinguish genetic maximum size potential (e.g. Giant mutation) from size actually reached per growth cycle. Bigger grown trees yield bigger logs / larger weapon potential, **not simply more logs**.
- Don't make unusual rare wood effectively unlimited without a supply limiter: acquisition rarity, growth time, and limited Grove capacity are primary levers.
- **Rare sapling acquisition — AGREED:** all three routes: (1) rare wild mutated trees have a chance to drop matching permanent saplings; (2) rotating sapling shop occasionally stocks rare saplings for gold, while ordinary saplings are always available; (3) quests/events can reward rare saplings. Exact odds and prices remain open. A rare sapling's inherited mutation is guaranteed on every subsequent regrowth; growth time and limited Grove slots control renewable material supply.
- **Grove removal policy — AGREED BASELINE:** uprooting/removing an already planted tree permanently destroys that sapling. This makes limited Grove slots a meaningful choice. Warn/confirm before destroying valuable saplings. Unplanted saplings can remain in normal inventory, distinct from *recovering* a planted sapling.
- **Potential premium feature, NOT yet locked for implementation:** very limited paid sapling preservation/storage may allow saving a planted tree instead of destroying it. If added, keep strict capacity limits and avoid unlimited cycling or undermining Grove slot upgrades. No commitment to premium storage in MVP.
- **Grove tree growth/harvesting — AGREED:** Saplings grow (including offline) into visually recognizable mature trees. **Only fully grown trees are chop-eligible**; no early harvesting or partial-growth log drops. **No percentage/progress bar or numerical growth % shown to players**, including at chopping. Simple visual growth stages are allowed. **The tree's target mature size is rolled at the START of each growth cycle**, bounded by the sapling's genetic potential, then the tree visually grows toward that predetermined size (option A). That target size is **not revealed numerically before harvest**. Mature trees wait for player harvest, then leave a stump and start a new cycle with a newly rolled target size. Show actual harvested log size/quality as loot feedback, not intermediate growth %. Exact timing and visual stage implementation remain open.
- **Initial harvesting assumption (PROVISIONAL, to playtest):** a fully grown Grove tree yields **one log per harvest**, independent of its size. Larger grown trees produce a *larger/better* log, not more logs. User agreed tentatively; do not treat as immutable. Revisit if rare-log supply or multi-log potency progression feels unreasonably slow.
- **Minimum Grove structure is now sufficient to begin the weapon progression coding slice**; defer detailed economy decisions instead of extending design indefinitely.
- **Still unresolved:** wild discovery frequency and quest/shop cadence; exact regrowth duration and size distribution; whether premium sapling recovery exists and exact caps/costs; inventory limits; sapling/Grove visuals; how much of the system should be online/offline beyond passive offline growth. Tune these once the gameplay loop is playable.

### G. Gold economy
- Gold sources include chopping tree rewards and Golden mutation abilities; rewards scale with tree value/kill, not exploitable hit or recursive AoE events.
- Major recurring sinks: metal weapon blanks/heads, forging costs, rarity ascension attempts, mutation awakening/infusion/rerolls, forge upgrades, and player/Grove infrastructure such as storage and carrying.
- Ordinary weapon blanks should be readily purchasable. Rare blanks and rare saplings could rotate / appear in wild or quests; details open.
- No rebirth as an artificial gold sink. Don't finalize prices without playable production/consumption data.

## Execution roadmap: build small, test, then expand

### Phase 0 — Grove minimum structure DONE; weapon architecture checkpoint NEXT

**Grove design checkpoint complete (2026-11-22).** Mutation inheritance, sapling sources, permanent planted-sapling removal baseline, mature-only harvesting, no growth %, size rolled at cycle start, and provisional one log per mature harvest are recorded in section F. **Do not schedule another design discussion before coding**, unless the actual code exposes a blocking ambiguity.

**Next work is engineering inspection, NOT implementing everything at once:**
- [x] Settle minimum Grove behavior and economy **structure** (section F); numeric tuning and the exact save contract remain for implementation.
- [ ] **Partially inspected 2026-11-22:** forge, persisted inventory shape, item parser, chopping, actual-damage application and dispatcher were reviewed. **Still inspect:** implementation of the `AddShopAxeItem` inventory Bindable, runtime weapon reconciliation/equip flow, and stat aggregation/recalculation before modifying live weapon records. Record backward-compatibility and data migration needs.
- [ ] Agree on versioned weapon fields: class, forge tier, source materials/provenance, base stats, original ability+potency, rarity, level/XP, ascension pity, ability slots, awakened/infused abilities. Avoid duplicating combat source-of-truth.

**Exit:** Contracts and migration plan are clear. No detailed balance math required.

### Phase 1 — Weapon leveling and rarity vertical slice (first playable feature)

**Build sequence:** (1A) persistent/versioned weapon data + derived stat calculation; (1B) chopping XP and leveling; (1C) natural rarity roll and rarity-based stat growth; (1D) ascension, Level-1 reset and hard pity. **Studio-test after each substage.** No mutation ability implementation or active skill system required for this vertical slice.

The data model should have stable fields for forge tier, original log provenance, forged base quality/size/stats, rarity, level/XP, ascension pity, primary mutation ability/potency and a future secondary ability/potency. Prototype weapons from older saves must remain usable.
- [ ] Add server-owned weapon XP and levels; damage attribution and tree-kill XP; cap XP to actual damage.
- [ ] Add rarity grade, rarity-dependent cap/growth, server validation, persistence, and minimal useful inventory display.
- [ ] Add natural rarity roll at forging, including possibility of direct Ultra; no new weapon-silencing bugs in existing crafting.
- [ ] Add max-level ascension, chance display, material+gold cost, RNG, hard pity `ceil(1.5/p)`, successful Level-1 reset; preserve forged qualities and existing effects.
- [ ] Add Studio-only accelerated testing fixtures / admin resources without exposing cheats to production.
- [ ] Test save/load, repeated attempts, pity boundaries, high-rarity natural roll, ascension resetting only level-derived stats, and fast vs slow weapons earning reasonable XP.

**Exit:** A player can **forge → chop/earn XP → reach cap → attempt ascension → grow stronger again**, with reliable persistence.

### Phase 2 — Forge tiers, potency, and mutation ability engine

**Build sequence:** (2A) tier-dependent quantity-to-class odds and potency roll with previews; (2B) registered mutation-family ability selection; (2C) implement and test each combat/economy ability in small batches. Do not implement every ability simultaneously. Treat mutation powers as triggered/passive effects; manually activated skills remain deferred.
- [ ] Generalize multi-tier forge config: per-tier class odds by log quantity, base stat/potency caps, eligible ability pools, and visible preview.
- [ ] Implement per-log independent potency contributions and cap warnings; size/material mechanics.
- [ ] Migrate prototype Crystal references safely; establish approved Golden/Frenzied/Shocked/Giant definitions while preserving old saves.
- [ ] Implement mutation ability rolls and initial effects in small tested batches; register with existing generic server effect dispatcher, not bespoke unbounded weapon paths.
- [ ] Start with one ability per pool; later unlock higher-tier entries and test nonzero rare ability odds.
- [ ] Ensure class innate Cleave stays independent of mutation slots, VFX are noticeable but not final-polish.

**Exit:** Forging decisions about log quantity, forge tier, mutations and potency visibly matter, with safe combat/economy effects.

### Phase 3 — Awakening, second slot, infusion and Ultra mastery
- [ ] Add forge-unlocked Awakening to ordinary weapons (fresh logs → first mutation + potency).
- [ ] Add Legendary second slot, fresh-log infusion and independent potency, duplicate checks, replacement route, preserving original ability.
- [ ] Add Ultra mastery as enhancement to existing abilities rather than third slot; scope mastery conservatively.
- [ ] Add caps to overlapping stat buffs, nonrecursive proc rules, atomic resource consumption and persistability tests.

**Exit:** Ordinary lucky Ultras remain investable, but players still benefit from starting with valuable mutated wood.

### Phase 4 — Grove gameplay integration and economy plumbing
- [x] Prototype implemented: planted/owned saplings, mature-only harvest by proximity prompt, timestamp-based growth/regrowth and size reroll, inherited mutations, persistent Grove records, one protected log per mature harvest and current capacity limit. **These are current-code observations, not final release status.**
- [ ] Audit existing Grove implementation against the latest design (e.g., premium removal, hiding growth percentages, genetic Giant changes), then adjust *only gaps* and test save/load.
- [ ] Connect rotating rare sapling shop / quests/events and revised wild mutation sourcing; rare-log scarcity and reliable mutated harvest rates should be tuned after integration.
- [ ] Connect logs from Grove to forging / awakening / infusion; build gold and material sinks.
- [ ] Add simple training rack (reduced AFK XP; optional capped offline XP later).

**Exit:** Renewable Grove inputs connect to persistent weapon progression and the player has reasons to actively chop.

### Phase 5 — Balance, presentation, progression pacing

**Later design checkpoint:** decide whether manually activated **skills** should exist at launch, how they are learned/assigned, and their cooldown/input design. Do not confuse this unresolved decision with the already agreed mutation ability pool or Battlehammer's passive triggered Cleave.
- [ ] Measure time to level cap, material production per active/AFK hour, rarity success distribution and pity cost, different weapon classes' XP rates, Golden gold generation, and stacking combo DPS.
- [ ] Tune rarity probabilities, forge-class curves, potency/size limits, level caps, ability effects, upgrade resources, rare-sapling sources and Grove capacity.
- [ ] Implement weapon rarity reveals and **rate-limited** announcements for noteworthy naturally forged/ascended/Secret results; avoid low-tier announcement spam.
- [ ] Add cosmetic rarity treatments and clear weapon UI; polish chopping/log pickups last, after the loop works.
- [ ] Consider weekly leaderboard rewards, Secret variations, mixed mutations, trade/social systems and further worlds only after core retention is proven.

## Non-goals for the immediate next coding pass
- Full Grove economy simulation or final numerical spreadsheet.
- All mutation effects at once; multi-mutation mixing or three slots.
- Final UI visual polish, cross-server broadcasts, leaderboard payouts, complicated AFK/offline systems.
- Refactoring functioning weapon code unrelated to the next phase.

## Architecture inspection (2026-11-22) — observations and implementation seams

**Confirmed source-of-truth and code touchpoints:**

- `src/ServerScriptService/PlayerProfile/ProfileService/DefaultPlayerData.luau`: persisted `InventoryItem` already has top-level `Rarity: string`, `Stats`, `UID` and optional `WeaponData`. **Reuse `item.Rarity`** rather than adding an independent rarity field; it is currently hardcoded to `"Common"` at both forge creation paths. Add a versioned leveling/progression payload to `WeaponData` (or another single clearly normalized persistent location) without duplicating base power or mutation effects.
- `src/ServerStorage/Items/ItemDataBase.luau`: `ParseItem` clones `WeaponData` and exposes `ItemRarity` / `ItemStats`; use this existing inventory pipeline. It currently creates display names from class/metal metadata.
- `src/ServerScriptService/Economy/ShopHandler.server.luau`: server-exclusive `craftExperimental` rolls material/class stats, builds `WeaponData`, sets `Rarity = "Common"`, and invokes `Inventory.AddShopAxeItem` Bindable; fixed-craft branch also sets Common. Both must eventually initialize rarity and progression through **one shared server function**. The current shop snapshot `buildOwnedAxes` omits rarity and XP/level; add display-safe projections for the Bag/Forge UI in a later substage.
- `src/ServerScriptService/Economy/AxeShopCatalog.luau`: currently stores metal/head tier and progression; **do not conflate `AxeTier` (metal/forest access) with forge upgrade tier or rarity**.
- `src/ServerScriptService/Economy/Wood/ChopHandler.server.luau`: checks the real equipped runtime weapon, applies hit rate, chooses target, calculates damage from `Runtime.FinalStats`, and calls `tree:TakeDamage`. This should drive server-only weapon XP attribution, not a client-provided damage/XP claim.
- `src/ServerScriptService/Trees/TreeObject/init.luau`: `Tree:TakeDamage` clamps applied damage to remaining HP, tracks **per-player**, not per-weapon damage, and returns only a success boolean. For precise XP, expose validated **applied damage and kill outcome** or emit a server-only applied-hit event with the **equipped weapon UID**. Keep first boolean return compatible with existing callers and count actual secondary-effect damage. Avoid double awarding on lethal hits or overkill.
- `src/ServerScriptService/WeaponEffects/Dispatcher.luau`: existing validated effects pipeline with Cleave; preserve class effects and no-recursive-proc rules. Later mutation abilities should reuse it.
- `src/ServerScriptService/PlayerProfile/ProfileService/ProfileDataCache.luau`: `Runtime.Weapon` and `Runtime.FinalStats` are rebuilt as ephemeral on login; **persistent weapon progress must live in `Inventory`**, then be projected/rebuilt into runtime equipment. Need trace actual equip/stat recalculation handlers before coding.
- Grove current implementation: `src/ServerScriptService/Grove/GroveGrowthRules.luau`, `GroveService.luau` and `SaplingDiscoveryService.luau` already implement timed mature-only Grove harvest, target size roll at cycle start, inherited mutation, one-log output and wild sapling acquisition (all provisional numbers/old mutation catalog). Beware that Grove harvesting uses a **prompt, not normal axe damage**, so it is not inherently weapon XP-bearing.

**Risks to avoid:** (1) double-counting `item.Stats.Attack` (currently bonus above the shared base attack) when adding level growth; calculate a **derived** damage value, never mutate original forged stats during leveling; (2) stale equipped runtime or UI after XP/ascension; (3) rewriting saved legacy weapons or old Cleave descriptors incorrectly; (4) granting XP by raw calculated hit rather than HP-clamped actual damage; (5) breaking studio-only gating of experimental forging and effects.

**Outstanding code audit before production edits:** locate/review the code bound to `Inventory.AddShopAxeItem`, equip/unequip and `FinalStats` aggregator; verify how `Profile.Data.Inventory` normalizes saved weapon records and how the client receives the weapon snapshot.

## Immediate next action (as of 2026-11-22)

1. **Finish the narrow inventory/equipment audit above** and write explicit source locations for weapon insertion, equip and final-stat recomputation. No more general Grove/crafting design sessions.
2. **Implement Phase 1A: additive weapon-progress schema and a pure progression/stat calculation module** on the existing `dev/gameplay-prototype` branch. Reuse `InventoryItem.Rarity`; default legacy weapons to Common, Level 1, XP 0; preserve existing `Stats.Attack`, `WeaponData.Effects`, materials, class and metal tier.
3. Add unit/smoke tests for old save migration, idempotent normalization, level/rarity stat calculation, and no effects/forge regressions. Hook progress only after server state and runtime recalculation are verified.
4. **Phase 1B: award XP for real applied damage and tree kills**, including verified Cleave contributions, refresh equipped stats, and show level/XP in Bag with minimal UI changes.
5. Only then implement **Phase 1C/1D** natural rarity rolls, max-level ascension, pity and level reset; run Studio Play tests before proceeding to forge tiers/mutations/infusion.

**Next assistant task:** complete the last inventory/equip-stat trace, then implement the smallest testable Phase 1A change; do not create a new branch or finalize economy numbers.

## Things that are examples, NOT locked numbers
Illustrations previously discussed (such as Common 10 / Rare 20 level caps, 5% upgrades, 15–25% AFK efficiency, five perfect logs producing full potency, 1–3 Golden logs, or a fixed number of forge tiers) **must not be treated as finalized economy values**. Only the **pity formula** and conceptual rules above are agreed.
