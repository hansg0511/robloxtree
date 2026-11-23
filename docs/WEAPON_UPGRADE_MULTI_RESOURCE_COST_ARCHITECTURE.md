# Phase 3 — Configurable multi-resource upgrade cost architecture

**Status: Phase 3A Awakening and 3B Legendary Infusion gameplay actions now wired; Roblox Studio runtime verification pending.** Upgrade amounts below are temporary tuning values, not the final game economy.

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

## Implemented provisional gameplay recipes

- **Awakening:** Forge Lv2; one existing weapon with no mutation, two owned logs from one mutation family, **one Heartwood**, and **500 coins**. Rolls first mutation from the shared Level 2 ability pool, preserves rarity/XP and other weapon data.
- **Legendary/Ultra Infusion:** Forge Lv2, an already-mutated Legendary/Ultra weapon, three matching family logs, **two Heartwood**, **one copper axe head**, and **1,500 coins**. Adds/replaces only slot 2. The first family's mutation cannot be used again; the first effect, weapon class/Cleave, rarity, XP and forged stats are preserved.
- **UI:** `M → AXES → INFO` now displays the exact ingredients, auto-selects the largest eligible mutation logs, shows projected potency/ability odds, and asks for a second click to confirm. You must stand at the actual Forge.
- **Server:** `WeaponUpgradeRules.luau`, `WeaponUpgradeService.luau`, `ShopHandler.server.luau` and `UpgradeWeaponRE.model.json` coordinate real server-owned metadata updates, UUID verification, nonyielding resource consumption, rollback and runtime cache refresh. Existing one-ability metadata stays compatible.
- **Studio:** The pre-existing `StudioForgeSandbox.luau` supplies uniquely identified test Heartwood only when Studio sandbox is enabled. The already-existing mutation-abilities fixture now also adds a Rare unmutated `AWAKEN TEST` and a Legendary Fervor `INFUSE TEST` weapon (no new smoke runner).
- **Validation:** the existing `tests/WeaponUpgradeCostRules.smoke.luau` has been extended to exercise the slot rules and old-Cleave preservation. Run it together with the existing weapon regressions once. The user still needs one manual test of actual deductions, persistence during the Studio session and real combat.

## Next activation step

1. Ask the coding agent to pull and execute the extended existing cost smoke plus relevant prior effect, progression, ascension and forge tests in Roblox Studio. Do not create another independent smoke suite unless a new bug cannot be covered by the existing file.
2. Use the updated existing Studio fixture to test one Awakening, one Infusion, and one replacement; verify material deduction by comparing exact UID lists/coin balances at the transaction boundary, then check combat and the runtime weapon profile.
3. Keep ingredient requirements provisional until Grove economy sources and player pacing are designed; future catalyst materials should be added by recipe configuration and a genuine acquisition source, not by substituting logs.
4. Only after this single integrated pass, move on to Ultra mastery.

## Current automated test

`tests/WeaponUpgradeCostRules.smoke.luau` runs purely on synthetic cost snapshots and loads the server adapter without consuming any real inventory. It tests mixed resource kinds, display preview, separate unique material groups, exact log material family and UID validation, unavailable future balances, missing ingredients and safe failure.

This is **architecture scaffolding only**, not a report that Awakening/Infusion can already be used in Roblox. It should not change current forging, ascension, mutation ability use or resources.
