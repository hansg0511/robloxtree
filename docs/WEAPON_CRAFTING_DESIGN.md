# Brick World — crafting and progression design contract (v0.1)

> **Design update (November 2026):** The fixed-output, fixed-log-count rules below describe our *previous direction* and the existing standard-axe implementation. They are **not the current proposed premium crafting design**. We are now experimenting with a generic metal blank, log-count-based probabilities for Dagger/Axe/Battlehammer, globally normalized log quality, species-strength averages, independent per-stat forge rolls, and separately quality-weighted mutation effects. See **[CRAFTING_BALANCE_PROTOTYPE.md](CRAFTING_BALANCE_PROTOTYPE.md)** and `tools/crafting_balance_sim.py` for the active **offline balance experiment**, whose numbers are not approved. The standard Roblox forge still supports the earlier deterministic Copper/Iron 3-log recipes; a **Studio-only experimental RNG forge** is now available alongside them (see [EXPERIMENTAL_FORGE_PLAYTEST.md](EXPERIMENTAL_FORGE_PLAYTEST.md)). Neither the proposed economy nor the experimental weapon model art is final.


Status: **agreed direction / implementation starting point**, NOT final economy balance. Updated 2026-11-17.

This document records decisions from game-design discussions so future coding agents do not reinvent the crafting system. It distinguishes agreed gameplay rules from open balancing questions. Do not silently treat illustrative examples as final numbers.

## Core fantasy

Players actively chop increasingly outrageous trees and **forge collectible, show-off weapons**. Axes are iconic, but future **dual knives, katanas, swords, cleavers and absurd weapons** should fit the same crafting pipeline. Different specific weapons may have distinct swing speeds, reach, attack patterns and animations. **No compulsory elemental/class/archetype taxonomy.** Most trees share a common fall/break/log-drop sequence; per-weapon hits and optional spectacular finishers are presentation layers.

## Rules agreed for recipes and equipment

1. A selected **recipe fixes the output weapon identity** (e.g. Copper Axe or Dual Knives). Changing ingredient counts or types must never secretly turn that recipe into a different weapon. No percentage chance to craft one weapon versus another.
2. Recipes have **explicit, bounded quantities and eligible ingredients**; no unlimited ore/log dumping, undisclosed mixture formulas or trial-and-error consumption. The server verifies exact owned material UIDs and required progression at craft time.
3. A craft **succeeds when requirements are met**. RNG, where present, affects **quality/stat strength within a disclosed range**, not whether the weapon exists, its class, or whether an unrelated weapon drops.
4. Players pick a known recipe, see required inputs and intended output before crafting. For RNG quality, show the **possible range** before irreversible consumption; do not claim a precise rolled stat in advance. Server rolls and persists the actual result at a successful craft.
5. **Craft a new weapon**, do not upgrade a cheap wild-wood weapon into a premium Grove-wood one. Individual finished weapons are trophies with their own UID, materials, rolls and provenance.
6. **Wild logs are usable** to cheaply try standard weapons and progress. Grove-grown logs are a **premium investment** with the potential for exceptional size and material qualities, not a compulsory ingredient for every basic weapon.
7. **Bigger source wood means a bigger individual weapon**, not extra logs. Reach, area of effect or skill scaling may benefit, with server-side caps/diminishing returns to be designed; never map size directly to unconstrained hitboxes.
8. Axe heads / future equivalent weapon components and their coin costs can limit ordinary progression. The present **three-log Copper/Iron recipes are PROTOTYPES**, not universal material-count rules.
9. **Weapon levels** gained through use are an idea worth exploring, not yet approved as a power or XP formula. Skill effects for specific special weapons are future content, not mandatory for every recipe.
10. Gifting/trading of finished weapons is a future feature. **Ownership must not bypass account-bound forest progression**: server-side equip and damage eligibility must respect progression. Desired experience: some weapons can be wielded **~1–2 worlds before** their nominal challenge tier, subject to balance. No actual threshold is set yet.

## Sapling acquisition and Grove (agreed concept, not current runtime behavior)

- **Coins / restocking shop:** baseline, standardized common/uncommon saplings with modest size-potential RNG. Reliable basic access; higher-value genetics are mainly a wild discovery goal.
- **Wild forests:** rare saplings as an additional RNG drop from actively chopped trees. Only a **mutated wild tree** can potentially yield a sapling with that mutation. Matching species/traits matter; the drop is **not guaranteed**.
- **Quests:** can offer guaranteed introductory/progression saplings, with exceptional rewards exceptional and controlled.
- **Grove:** start with few planting spots, upgrade for more. A planted sapling becomes a persistent trophy/tree with fixed inherited species, mutations and genetic size potential.
- After a Grove harvest the **stump persists and regrows**. Current growth cycle rolls its actual capped size from its genetics; mature size controls its passive strength. While regrowing it **provides no passive**. Each mature harvest produces **one** individual log with that growth's size/material characteristics, not more logs for bigger size.
- The tree can gain a **root/growth level** through repeated harvest cycles; benefits and ceiling remain to be designed. Preserve identity/lineage when regrowing.
- Weather can add secondary temporary presentation/material modifiers to a current growth; **do not make AFK weather the principal route to high-power weapon skills**.
- A Golden inherited tree produces Golden wood when harvested, consistent with the player's mental model. Unlimited renewable production is a **known economic risk**; avoid solving it by adding arbitrary rare rune ingredients. Control value via tree/grove capacity, time, material size, quality and progression, then model supply before fixing rates.

## Economy and quality: deliberately NOT locked

Questions requiring playtime/economy modeling:
- How many weapon recipes/major upgrades in early worlds? Expected chopping, coin and head acquisition times?
- Which recipes accept mixed species, and how many bounded wood slots do they have?
- How does 1 vs. multiple special logs change the **announced quality band**? The proposed 1/2/3 Golden example with ~1–33%, ~34–66%, ~67–100% was illustrative, **not an agreed universal formula**.
- Does size determine purely visual scale or also capped reach/AoE/skill multipliers? What is max practical size?
- How rare are wild mutation spawns, sapling drops and exceptional genetics? How often can Grove trees be harvested? How many planting slots?
- How much of the RNG quality power is inherited from material traits versus the forge roll? What is the fair reroll/trade economy?
- Which weapon kinds ship first; what animation/attack pattern is distinctive and cheap enough to build?

**Do not implement fabricated final numbers** in the name of completing this contract.

## Actual repository state when this contract was written

- `AxeShopCatalog.luau` contains fixed `copper_axe` and `iron_axe` recipes with three log UIDs and purchased heads.
- `ShopHandler.server.luau` validates selected logs server-side, computes deterministic power from species bonuses, and inserts persistent unique inventory weapons. It does **not** implement special-quality rolls, weapon levels, recipe variants, non-axe models, or trading.
- `ItemDataBase.luau` already treats inventory weapons generically as `Type = "Weapon"`, even though the active shop/UI labels them as axes.
- `BRICK_WORLD_REWORK_PLAN.md` documents an older Grove model where harvesting **permanently consumes the tree and creates Heartwood**; it must be deliberately migrated before implementing regenerative Grove wood. Do not assume the new Grove design is already live.
- Profile initialization still uses `ProfileStore.Mock`; **real persistence is required before a public economy or trading release**.

## Implementation sequence

1. **Foundation (this PR):** preserve existing Copper/Iron crafting and equip behavior, centralize exact fixed-recipe input validation and record stable `RecipeId` + `WeaponKind` provenance on newly crafted items. No material or balance changes.
2. **First playable weapon slice:** add one deliberately differentiated weapon recipe/model/animation using the fixed-output path (e.g. dual knives), then verify common tree death/reward handling. Select the exact model and stats before implementation.
3. **Premium material slice:** support individual Grove wood provenance, capped size mapping, explicit quality bands and server quality RNG. Provide a preview of possible quality before crafting. Only after the actual recipe/economy parameters are specified.
4. **Grove/economy slice:** migrate old Heartwood harvesting to the stump/regrow/one-log plan; rework wild mutation discovery to correspond to visible wild traits; simulate production and demand.
5. **Progression/trade slice:** server-enforced equip/damage/world gates, safe persistent inventory, gifting/trading with anti-duplication checks; defer until persistence and transactional safety are validated.

## Acceptance checklist for first implementation

- Existing normal Copper/Iron recipes craft exactly the same item and power from identical ingredient selections; rejected selections remain rejected.
- Successful new crafts preserve their source materials and also record the recipe identity and weapon kind as inert metadata.
- No mutation to wild drops, forest access, Grove harvesting, UI, trading, or live player data.
- Roblox Studio Play test and inventory/equip regression checks required before merging; source review alone is not a Studio test.
