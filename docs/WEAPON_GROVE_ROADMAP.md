# Weapon + Grove Progression — Implementation Roadmap
_Last updated: 2026-11-21. Design handoff for the Roblox axe/forest game._

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
- New mutation powers, weapon rarity/XP/ascension, awakening, infusion, and multi-tier forge rules described below are **design-only**, not yet coded.
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
- **Still unresolved:** wild discovery frequency and quest/shop cadence; regrowth time/size mechanics; whether premium sapling recovery exists and exact caps/costs; log yield and inventory limits; sapling/Grove visuals; how much of the system should be online/offline. Decide structurally before fully implementing Grove.

### G. Gold economy
- Gold sources include chopping tree rewards and Golden mutation abilities; rewards scale with tree value/kill, not exploitable hit or recursive AoE events.
- Major recurring sinks: metal weapon blanks/heads, forging costs, rarity ascension attempts, mutation awakening/infusion/rerolls, forge upgrades, and player/Grove infrastructure such as storage and carrying.
- Ordinary weapon blanks should be readily purchasable. Rare blanks and rare saplings could rotate / appear in wild or quests; details open.
- No rebirth as an artificial gold sink. Don't finalize prices without playable production/consumption data.

## Execution roadmap: build small, test, then expand

### Phase 0 — 1 short Grove design pass + architecture checkpoint
- [ ] Settle only required Grove contracts: ownership/persistence of sapling → stump → regrowth → harvested log; inherited mutation; size attributes; acquisition tiers and capacity limit.
- [ ] Inspect server-authoritative weapon inventory, chopping, forge preview/roll, save/persistence and effect dispatcher; record backward-compatibility and data migration needs.
- [ ] Agree on versioned weapon fields: class, forge tier, source materials/provenance, base stats, original ability+potency, rarity, level/XP, ascension pity, ability slots, awakened/infused abilities. Avoid duplicating combat source-of-truth.

**Exit:** Contracts and migration plan are clear. No detailed balance math required.

### Phase 1 — Weapon leveling and rarity vertical slice (implement first)
- [ ] Add server-owned weapon XP and levels; damage attribution and tree-kill XP; cap XP to actual damage.
- [ ] Add rarity grade, rarity-dependent cap/growth, server validation, persistence, and minimal useful inventory display.
- [ ] Add natural rarity roll at forging, including possibility of direct Ultra; no new weapon-silencing bugs in existing crafting.
- [ ] Add max-level ascension, chance display, material+gold cost, RNG, hard pity `ceil(1.5/p)`, successful Level-1 reset; preserve forged qualities and existing effects.
- [ ] Add Studio-only accelerated testing fixtures / admin resources without exposing cheats to production.
- [ ] Test save/load, repeated attempts, pity boundaries, high-rarity natural roll, ascension resetting only level-derived stats, and fast vs slow weapons earning reasonable XP.

**Exit:** A player can **forge → chop/earn XP → reach cap → attempt ascension → grow stronger again**, with reliable persistence.

### Phase 2 — Forge tiers and the mutation engine
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

### Phase 4 — Grove gameplay loop and economy plumbing
- [ ] Plant/own saplings, grow/chop/regrow, produce inherited mutated logs, manage slots, save state.
- [ ] Connect sapling shop / discovery sources; make rare logs scarce but reliable per mutated harvest.
- [ ] Connect logs from Grove to forging / awakening / infusion; build gold and material sinks.
- [ ] Add simple training rack (reduced AFK XP; optional capped offline XP later).

**Exit:** Renewable Grove inputs connect to persistent weapon progression and the player has reasons to actively chop.

### Phase 5 — Balance, presentation, progression pacing
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

## Immediate next action

**One concise Grove structural decision pass (Phase 0), then implement Phase 1 — weapon XP, rarity and ascension — on `dev/gameplay-prototype`.** Stop at each milestone for a Studio test and address correctness issues before adding new mechanics.

## Things that are examples, NOT locked numbers
Illustrations previously discussed (such as Common 10 / Rare 20 level caps, 5% upgrades, 15–25% AFK efficiency, five perfect logs producing full potency, 1–3 Golden logs, or a fixed number of forge tiers) **must not be treated as finalized economy values**. Only the **pity formula** and conceptual rules above are agreed.
