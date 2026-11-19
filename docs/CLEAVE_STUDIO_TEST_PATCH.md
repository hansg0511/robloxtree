# Studio-only Cleave playtest patch

The test area is attached to `SourceWorld.Forests.CleaveTestPatch` **only in Roblox Studio Play** by `WorldLayoutService`. The public World 1 tree placement is unchanged.

## Location and behavior

- The initial patch was inadvertently placed *beyond the western world wall*. This is fixed: from the main Forest 1 corridor (X≈-112), head **east into Forest 1** near Z≈185 and look for **CLEAVE TEST - STUDIO ONLY**, around X=-93, Z=185. It is entirely within the playable forest.
- Four `StarterForestTree` wild Oaks stand in a 7.5 x 7.5 stud rectangle. They are **real server-registered TreeObjects**, tagged `CleaveTestTree` on their initial models, using existing Forest1 eligibility, server-authoritative hits, death, normal logs and respawn.
- The patch is owned by `SourceWorld` and participates in world-rebuild cleanup. No trees or pad are constructed in a published server.
- These trees can award normal wood and wild sapling discovery as usual; this is not a reward-free dummy test.

## Quick check

1. In a new Studio Play session, forge an experimental Copper or Iron **20 LOGS** Battlehammer (guaranteed class in the current placeholder odds). Equip it. The regular Heavy Cleaver does **not** have this effect.
2. Press **M**, choose **AXES**, select the new weapon, and use **INFO** when the panel is narrow. Scroll to **WEAPON EFFECTS** and confirm `Cleave / OnHit / WeaponClass` plus a radius in studs and secondary damage fraction. If no Cleave is recorded, forge a new experimental hammer.
3. Walk to the marked patch and hit one Oak. Up to two nearby Oaks should take secondary damage. The 7.5-stud spacing fits the current minimum possible experimental Cleave roll (7.92 studs).
4. Test the same patch with a newly crafted Dagger or normal Axe: only the primary Oak should be damaged.
5. Test opening and closing **Bag / Shop / Forge**: Grove HUD and Lighting Preview should hide while any panel is open and return on close. Lighting Preview is top-right during normal Play; its expanded/collapsed state should survive panel opening.

**In Studio, secondary hits now display a gold `CLEAVE <damage>` popup** rather than the ordinary white damage number. The server Output also prints a `[CleaveTest]` line for strikes against test-patch trees, including the equipped weapon's radius, eligible prepared targets and successful secondary hits. If it instead says the equipped weapon has no validated Cleave effect, use the Bag weapon-effects panel to check your actual equipped weapon. There is **still no final sweeping wave VFX**; this is temporary diagnostic hit feedback.

## Limitations

GitHub source edits cannot execute Roblox Studio or its command-bar smoke tests. Confirm in Studio Play and inspect Output for script errors before merging the draft PR. This small debug patch is not game balance or final world dressing.
