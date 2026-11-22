# Phase 3 — Configurable multi-resource upgrade cost architecture

**Status: source foundation committed; Awakening and Infusion actions are NOT yet wired to gameplay.** This checkpoint intentionally does not select the final materials, quantities or balance. The next implementation pass connects this shared cost engine to the two weapon-upgrade operations.

## Design constraint: Awakening uses other materials, not only mutated logs

A server-authored Awakening/Infusion recipe contains an **array of required ingredients**. The recipe can require all of the following at once:

- `Coins`: `{Kind="Coins", Amount=...}`
- `Logs`: `{Kind="Logs", Count=..., MutationFamily="$selected"}` — client can choose **owned exact UIDs**, but not change the authoritative required count or mutation family. All logs are verified via the existing `LogService.GetEligibleCraftLogs` and exact-UID `LogService.TakeCraftLogUIDs` APIs.
- `Material`: `{Kind="Material", Source="GroveMaterials", MaterialType="Heartwood", Count=...}` — unique-ID nonlog materials (e.g., Heartwood already exists in profile storage). Supports multiple different types via `MaterialUIDsByType`, with cross-resource duplicate UID rejection.
- `Stack`: `{Kind="Stack", Source="AxeHeads", Id="copper_head", Count=...}` — existing counted owned materials.
- `Stack`: `{Kind="Stack", Source="MaterialBalances", Id="future_catalyst", Count=...}` — a **new, empty, normalized profile field** for future recipe catalysts/essences. No such material is granted by this patch. Future acquisition systems set counts server-side. Missing balances fail closed.

**None of the example values or types above are locked recipe choices.** Heartwood is a concrete existing source, *not* a decision that all Awakening recipes must consume Heartwood.

## Implementation contracts

- `src/ServerScriptService/Economy/WeaponUpgradeCostRules.luau`: pure `Validate(costs)`, `Describe(costs)` and `Plan(costs, data, eligibleLogs, selections, family)`. Checks every requirement in a single quote, gives the UI all ingredients (including missing ones), rejects wrong mutation families, spoofed or reused UIDs, negative/malformed amounts, duplicate cost rows, unknown inventory-source types, and absent balances. Never mutates inventory.
- `src/ServerScriptService/Economy/WeaponUpgradeCostService.luau`: `Preview(player,...)` with authoritative profile/log snapshots; `Take(player,...)` checks all costs then consumes exact owned log UIDs through LogService and debits unique materials/stack balances/coins in one nonyielding transaction; `Rollback(receipt)` restores the precise consumed log records and source locations plus money/other materials on weapon-upgrade failure; `Finalize(receipt)` prevents replaying or double refunding the same receipt. Errors fail closed. A rollback failure quarantines the receipt with a warning rather than issuing a potentially duplicative refund.
- `src/ServerScriptService/PlayerProfile/ProfileInit/init.server.luau`, `DefaultPlayerData.luau`, and `ProfileDataCache.luau`: new `MaterialBalances` profile map, default empty, nonnegative integer normalization. Existing `GroveMaterials`/Heartwood schema and `AxeHeads` remain untouched.

## Next activation step

1. Define server-only **actual** recipes with both mutation logs **and** one or more additional ingredients. *Do not* add a "logs-only" fallback when those items are absent. A recipe cannot be considered eligible without all of them.
2. Integrate the `Take/Finalize/Rollback` adapter into the Awakening and Legendary Infusion server operations; debit materials only if weapon UID, rarity, ability slots, selected log family, forge location, and server recipe all validate.
3. Weapon mutations update **both persistent Inventory item WeaponData and current runtime weapon copies**, with one verified stat/effects refresh. Reject mutations if the full operation cannot complete; never silently lose material or reroll an existing ability.
4. Expose all ingredient requirements and their availability in Forge UI, without claiming an unavailable catalyst was paid.
5. Smoke-test real Studio Mock-owned material UIDs and coins with success/rollback/replay/spoofing cases before enabling user-facing operations; add a temporary fixture for missing material acquisition, never release free materials to production.

## Current automated test

`tests/WeaponUpgradeCostRules.smoke.luau` runs purely on synthetic cost snapshots and loads the server adapter without consuming any real inventory. It tests mixed resource kinds, display preview, separate unique material groups, exact log material family and UID validation, unavailable future balances, missing ingredients and safe failure.

This is **architecture scaffolding only**, not a report that Awakening/Infusion can already be used in Roblox. It should not change current forging, ascension, mutation ability use or resources.
