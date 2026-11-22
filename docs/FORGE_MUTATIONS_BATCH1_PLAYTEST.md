# Phase 2 Batch 1 — Forge tiers, mutation potency and first 3 abilities

**Status:** Source changes and deterministic smoke test committed to `dev/gameplay-prototype`. Roblox Studio runtime and full integration testing **not run by this assistant**.

## Implemented

- Persistent `RunProgress.ForgeLevel` with migration default 1. At the Forge, pay a provisional **2,000 coins** to upgrade to Level 2. Tier 2 permits Iron forge recipes; existing forest and axe-head progression checks remain. Forge tier 2 shifts the log-count-to-class probability curve (Daggers become possible with more logs), raises mutation potency cap from **35% → 70%**, and uses the existing stronger Iron recipe head stats.
- Studio RNG and standard recipes both evaluate the **same pure shared** `ReplicatedStorage.Shared.ForgeMutationRules`. Potency = sum of *each qualifying mutated log's* `clamp(size/5,0,1) * 0.22`, capped per forge tier. Ordinary wood does not dilute mutation potency. Overcap potential is displayed as a warning. The ability-bearing families are **Golden/Frenzied/Shocked**, one per craft. **Giant** still represents size genetics and gives no weapon skill. Mixed ability-bearing types fail safely (consumed logs restored, head not consumed). Current families each have **one** unlocked ability (100% chance within that family); higher-tier ability pools come in Batch 2.
- New wild mutation rolls include Frenzied and Shocked. **Legacy Crystal** remains recognized/copied in existing owned records but is no longer newly rolled; old Crystal wood gives no new ability. Studio forging sandbox adds real individual Frenzied/Shocked test logs to owned storage. Remove the old local `DevAscensionFixture.server.luau` runner before these tests; it would modify max-level weapons on every Play session.
- Successful forge persists `WeaponData.MutationAbility = { Family, Id, Potency, ForgeTier }` and a registered generic `WeaponData.Effects` entry with `Source="WoodMutation"`. Class Cleave remains separate. New mutation effects work in published server chopping; **Cleave still Studio-only**.
- `GoldenTouch` (OnKill): server-awarded extra coins based on trusted tree species sell value and potency, only after actual kills. Currency/UI updates use the existing EconomyUpdated event; kills from valid registered secondary hits count.
- `Fervor` (OnHit passive): per-player/per-equipped-weapon same-target hit streak boosts **server-enforced** chop rate, with max stacks and short inactivity expiry. Misses and switching targets/weapons do not grant new stacks.
- `Thunderstrike` (OnHit): after a bounded number of confirmed primary chops, an independent registered effect strikes one eligible nearby target, or the original tree if it survived. Damage is HP-clamped and reported as a registered secondary hit for XP. No recursive effect triggering. Blue target highlight is a brief cosmetic.
- Forge previews show mutation family, potency vs cap and identity. Quick test presets: GOLD ×10, FRENZY ×10, SHOCK ×10. Bag weapon details show original mutation ability and potency. Standard forging remains a fixed class; Studio RNG forging still rolls Dagger/Axe/Battlehammer.

## Automated Studio smoke tests

Execute in **Play → Server Command Bar**, or via an agent with an actual Roblox Studio server test harness:

1. **New:** `tests/ForgeMutationsBatch1.smoke.luau`
2. Existing `tests/ExperimentalForgeRules.smoke.luau`
3. Existing `tests/WeaponEffectsDispatcher.smoke.luau`
4. Existing `tests/WeaponProgressionRules.smoke.luau`
5. Existing `tests/WeaponProgressionXP.smoke.luau`
6. Existing `tests/WeaponRarityRoll.smoke.luau`
7. Existing `tests/WeaponAscension.smoke.luau`

Expected first test message: `ForgeMutations Batch 1: tier curves, potency caps, mutation independence, Golden Touch, Fervor and Thunderstrike passed`

**New pure smoke tests cover:** tier odds and caps, per-log contributions/non-dilution, mixed-family rejection, Giant and legacy Crystal exceptions, effects registry, Golden Touch kill-only payout, Fervor same-tree timing/cooldown reset and Thunderstrike proc boundaries/one-target damage/XP callback.

A passing pure test does **not** prove the real Forge purchase/UI and chop integration. Report those separately.

## One quick end-to-end Studio playtest

1. **Remove or disable any local auto-runner from Phase 1D:** `src/ServerScriptService/DevAscensionFixture.server.luau` (it was an uncommitted local copy). Sync Rojo; start **Play**.
2. Go to **THE FORGE**. It should say **FORGE LV 1** and offer the **2,000 coin Level 2 upgrade**. Click once. Verify it now says **FORGE LV 2**, and Copper/ Iron recipes can be accessed subject to existing forest/head requirements. Existing Studio resource auto-refill may obscure actual coin deduction. Disable `StudioForgeSandbox.ENABLED` for a separate economic-cost test; do not permanently change it for mutation crafting.
3. In **RNG FORGE → COPPER**, use preset **GOLD ×10**. Craft using real server-owned logs; check the Forge result includes **GOLDEN TOUCH** and **M → AXES → INFO** shows the mutation ability, its potency and the `WoodMutation` effect source. Equip that weapon, chop a normal wild tree to death, and confirm the **GOLDEN TOUCH +coins** feedback. The bonus should trigger only when a tree actually dies.
4. Use **FRENZY ×10** to forge a weapon with **Fervor**, equip it and hit the *same tougher tree* several times. Server attack intervals should shorten with accumulated hits, not when switching targets. Exact feel is provisional; no final animations required.
5. Use **SHOCK ×10** to forge **Thunderstrike**, equip it, then hit a tree several times near another eligible tree. Watch for the brief **blue lightning flash** and an actual secondary damage number after the configured hit count. XP should be based on actual damage removed, and secondary hits must not chain new effects.
6. Use a mixture of Golden+Frenzied selected logs. The Forge must show **DO NOT MIX** and disable the craft button. No materials/heads should be consumed. Then use only **normal** logs: no mutation ability should appear.
7. Optional: forge a 20-log Battlehammer in Studio and verify its Cleave remains independent of a Golden/Frenzied/Shocked mutation. For newly forged Battlehammers with one mutation, Bag should show **both** registered effects.

Report first **red Output error**, if any, with source/line. Do not grind for higher rarity; Phase 1C/1D has already been smoke-tested manually.

## Known boundaries, deferred to Batch 2

- Rare ability selection (higher-tier Golden Rush/Jackpot, Bloodrush/Rampage, Chain Lightning) is **not yet implemented**. First ability per family is deterministic; no additional probability roll when there's one choice.
- Forge has two provisional tiers only. Tier 3+ and final workstation art/economy are not defined.
- Crystal migration preserves existing records, but any broader rebalancing of legacy Crystal visuals/saplings is deferred.
- Currently the effect visual is deliberately minimal: Golden coin feedback, Fervor actual attack timing, Thunderstrike brief highlight, not final VFX/audio.
- Published DataStore persistence still needs separate testing because Studio profile boot can use `ProfileStore.Mock`.
- Studio sandbox automatically refills normal test resources and can mask displayed coin deductions; this does not imply free resources in published play.
