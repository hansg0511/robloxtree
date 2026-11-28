# Phase 2 Batch 2 — test plan (pending Roblox Studio verification)

This is a **source-code implementation**, not a claim that tests already ran.
Branch: `dev/gameplay-prototype`.

## Gameplay introduced

- Forge Level 1 retains each family's original guaranteed ability.
- Forge Level 2 rolls one ability based on **server-owned weighted odds**:
  - Golden: Golden Touch 50%; Golden Rush 30%; Golden Jackpot 20%.
  - Frenzied: Fervor 50%; Bloodrush 25%; Rampage 25%.
  - Shocked: Thunderstrike 65%; Chain Lightning 35%.
- The client shares the exact probability catalog for previews but cannot choose the roll. Weapon rarity and class remain independent. Potency per mutated log is unchanged (capped by workstation level).
- Golden Rush: verified kill streak, up to 4 stacks, 8-second renewal window. Each kill awards extra coins based on server-owned species sell value and stack count. Stacks reset after expiry or weapon switch.
- Golden Jackpot: verified kill only, server-owned random roll, 10%–20.5% chance depending on potency and 4–6.8× species base sell value, bounded award. (A separate Studio-only test weapon uses 50% chance for quick manual demonstration.)
- Bloodrush: verified kill gives +12% to +26% movement speed for 7 seconds, refresh rather than stack, max WalkSpeed 50, restores on expiry or weapon change without overwriting unrelated movement-controller changes.
- Rampage: verified kill gives +20% to +37.5% primary damage for 8 seconds, refresh rather than stack, effect begins on next hit, ends on expiry/weapon change/respawn.
- Chain Lightning: each confirmed primary strike has 25%–35.5% independent chance to leap to up to 3 separate eligible neighboring trees. Each hop starts at the last hit tree, must be within 20 studs, loses 30% damage per hop, and cannot repeat/recursively trigger. Actual HP removed is recorded for XP exactly once. Short neon connecting arcs are prototype VFX.
- Thunderstrike remains a SAME-TREE burst only; Battlehammer Cleave remains separate and Studio-only.

## Agent-automated tests

1. `tests/ForgeMutationsBatch2.smoke.luau` (new)
2. `tests/ForgeMutationsBatch1.smoke.luau`
3. `tests/WeaponEffectsDispatcher.smoke.luau`
4. `tests/ExperimentalForgeRules.smoke.luau`
5. `tests/WeaponProgressionXP.smoke.luau`
6. `tests/WeaponProgressionRules.smoke.luau`
7. `tests/WeaponRarityRoll.smoke.luau`
8. `tests/WeaponAscension.smoke.luau`

Use actual Roblox Studio SERVER execution or a temporary installed Studio-only runner. Run source/runtime load checks and report explicit PASS/FAIL/NOT RUN; never infer PASS from code inspection. Fix targeted errors, commit, rerun regression tests.

## Local Studio fixture installation

Agent installs these two tracked source fixtures as **untracked local copies** (via `.git/info/exclude`):

- `tests/DevMutationCombatFixture.server.luau` → `src/ServerScriptService/DevMutationCombatFixture.server.luau`. Spawns four labeled 50M-HP, server-registered practice Bamboo trees near the player.
- `tests/DevMutationAbilitiesFixture.server.luau` → `src/ServerScriptService/DevMutationAbilitiesFixture.server.luau`. In the game's existing Studio `ProfileStore.Mock` profile, uses the trusted inventory AddShopAxeItem bindable to add one copy of each of the **five new effect weapons**, without deleting/editing an existing axe. It logs `READY 5/5`. If inventory is full, report it rather than deleting any owned items. No real publishing/data writes.

**Important:** remove the old local `DevAscensionFixture.server.luau` runner. Preserve the new fixtures for the one manual pass, then remove the untracked local auto-runner copies.

## Manual verification in one Play session

1. Start Play. In Studio Output, verify `[MutationBatch2Fixture] READY 5/5` and `[MutationPractice] READY: Four 50M HP ...`. If missing, stop and ask agent to diagnose.
2. Forge → Lv2, select Gold ×10, Frenzy ×10 or Shock ×10, and verify exact *weighted ability percentages* are displayed for each family before crafting. No need to craft for each weighted outcome manually.
3. M → AXES → INFO, equip **Golden Rush** test weapon. Kill Bamboo/Oak quickly in Forest 1, aiming for 4 kills within 8 seconds; verify bonus coin feedback and streak progress, then stop for >8 seconds and verify next kill starts at stack 1.
4. Equip **Golden Jackpot** test weapon. Kill several small Bamboo trees. The Studio sample has 50% chance to trigger for demo only; production Forge chance is the displayed lower value. Verify a payout appears on a confirmed kill only.
5. Equip **Bloodrush** sample. Kill a Bamboo; movement becomes clearly faster for ~7 seconds and returns to baseline. Switching axe should also end it.
6. Equip **Rampage** sample. Kill a Bamboo, then immediately strike a nearby high-HP practice tree. Compare damage during 8-second buff vs after expiry. Killing the same Bamboo should not retroactively buff that killing hit. Switching weapons clears the buff.
7. Equip **Chain Lightning** sample. Repeatedly chop the blue practice tree with the two further practice trees nearby. Watch 1–3 blue arcs jump in sequence to different neighboring trees. New targets take actual damage and earn weapon XP. Unlike Thunderstrike, lightning should NOT simply add all bonus damage to the current tree.
8. Regression: equip existing Thunderstrike sample and ensure same-tree bonus still works, no neighbor damage; inspect a Battlehammer and ensure Cleave remains class-specific.

Optional deeper check: Forge random results match the advertised weights statistically over many server rolls, not by manually forging dozens of times.

**Exit:** The agent reports automated test PASS and one successful manual session confirms all five effects; only then mark Batch 2 complete and proceed to Phase 3.
