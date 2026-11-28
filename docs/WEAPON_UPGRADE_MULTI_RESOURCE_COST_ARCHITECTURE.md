# Weapon upgrade material architecture — costs deliberately undecided

**Status (2026-11-23):** User-approved behaviors: Awakening grants the permanent first mutation; Legendary/Ultra Infusion adds or replaces **only the second mutation**. Awakening must eventually require additional materials beyond mutated logs. **No specific extra material, drop source, coin price, axe-head cost, or total ingredient quantity has been agreed.** Ultra Mastery is on hold.

## What was reverted

- The arbitrary Heartwood requirements for Awakening and Infusion are gone, along with the provisional coin/axe-head charges for these actions.
- The arbitrary one-Heartwood-every-third-Grove-harvest reward was removed, including HUD and reward notifications and Studio Heartwood auto-injection.
- The Grove continues to produce **one stored log per mature harvest**, inheriting the planted sapling's mutation. This is separate from future weapon-upgrade material sourcing.
- Existing `GroveMaterials` schema/old Heartwood records are **retained for backward compatibility**; existing records are not deleted and *no gameplay system generates new Heartwood*. No upgrade recipe refers to Heartwood.
- The generic multi-resource `WeaponUpgradeCostRules`, `WeaponUpgradeCostService`, and empty saved `MaterialBalances` map remain so future **approved** materials can be added without rewriting weapon mutation logic.

## Explicit Studio-only temporary upgrade test inputs

`src/ServerScriptService/Economy/WeaponUpgradeRules.luau` declares:

- `Rules.ECONOMY_CONFIGURED = false`
- `Rules.COST_POLICY = "STUDIO_TEST_ONLY"`
- Temporary Awakening test: **2 qualifying mutated logs**
- Temporary Infusion/slot-2 replacement test: **3 qualifying mutated logs**

These are **not** finalized prices or an approved logs-only upgrade design. The counts only provide reproducible inputs to the existing ability/potency mechanics. **No coins, Heartwood, axe heads or catalysts are deducted** by these Studio recipes.

`WeaponUpgradeService.Attempt` explicitly returns `UPGRADE_ECONOMY_PENDING` in **non-Studio** servers while `ECONOMY_CONFIGURED` is false. Its snapshot marks upgrade actions ineligible there. This prevents shipping the placeholder logs-only recipe as a permanent live economy by mistake. Normal forging, weapon leveling, rarity ascension, class abilities and Grove gameplay are not gated by this policy.

Once the actual economy is agreed, configure both final server-authored cost arrays and set `ECONOMY_CONFIGURED=true` in one intentional change. Do not silently promote test amounts to production.

## Retained general-purpose cost contract

Each future recipe can combine independent requirements, chosen from these existing validated ingredient kinds:

- `{Kind="Logs", Count=..., MutationFamily="$selected"}`: server-validated exact eligible owned log UIDs, including stored Grove logs
- `{Kind="Coins", Amount=...}`: existing coin balance
- `{Kind="Stack", Source="AxeHeads", Id="...", Count=...}`: existing item balances, **if** later approved
- `{Kind="Stack", Source="MaterialBalances", Id="some_future_id", Count=...}`: a future named stackable upgrade resource; currently no acquisition path is implied
- `{Kind="Material", Source="GroveMaterials", MaterialType="some_future_type", Count=...}`: a **schema example** for individually identified resources; requires a separately approved acquisition and profile-validation path if chosen

The pure planner previews all ingredients; the payment service checks every source, verifies exact UIDs, debits ingredients as one nonyielding operation and can restore the original records on a failed weapon update. All quantities, mutation-family checks and material types are server-owned. The client may request a mutation family and select UIDs, but cannot choose the price.

## Current testing and handoff

- Use the **existing** `tests/WeaponUpgradeCostRules.smoke.luau` to verify the reusable cost engine still accepts multi-resource synthetic test recipes and the actual Awakening/Infusion recipes are clearly Studio-only.
- Manual Axe INFO tests can still demonstrate Awakening and second-slot Infusion in Studio using mutated logs; they should **not** demand Heartwood or charge unrelated resources.
- Use `tests/GroveGrowthRules.smoke.luau` for Grove lifecycle, rare sapling shop/inheritance, old-profile compatibility and assurance that the unapproved extra-material drop rule has been removed.
- Do not create new upgrade materials, a Heartwood drop system, or Ultra Mastery until the user explicitly agrees to the corresponding design.
