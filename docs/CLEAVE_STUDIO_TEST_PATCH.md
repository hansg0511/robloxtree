# Studio-only Cleave playtest patch

The test area is attached to `SourceWorld.Forests.CleaveTestPatch` **only in Roblox Studio Play** by `WorldLayoutService`. The public World 1 tree placement is unchanged.

## Location and behavior

- Walk **west from Forest 1**, following the short access path at approximately Z=201 to a labeled green patch around X=-216.
- Four `StarterForestTree` wild Oaks stand in a 9 x 10 stud rectangle. They are **real server-registered TreeObjects**, tagged `CleaveTestTree` on their initial models, using existing Forest1 eligibility, server-authoritative hits, death, normal logs and respawn.
- The patch is owned by `SourceWorld` and participates in world-rebuild cleanup. No trees or pad are constructed in a published server.
- These trees can award normal wood and wild sapling discovery as usual; this is not a reward-free dummy test.

## Quick check

1. In a new Studio Play session, forge an experimental Copper or Iron **20 LOGS** Battlehammer (guaranteed class in the current placeholder odds). Equip it. The regular Heavy Cleaver does **not** have this effect.
2. Press **M**, choose **AXES**, select the new weapon, and use **INFO** when the panel is narrow. Scroll to **WEAPON EFFECTS** and confirm `Cleave / OnHit / WeaponClass` plus a radius in studs and secondary damage fraction. If no Cleave is recorded, forge a new experimental hammer.
3. Walk to the marked patch and hit one Oak. Up to two nearby Oaks should take secondary damage if their centers are within the *actual rolled* radius. A weak-quality hammer with radius below 9 studs may still miss; choose high-quality logs to test reliably.
4. Test the same patch with a newly crafted Dagger or normal Axe: only the primary Oak should be damaged.
5. Test opening and closing **Bag / Shop / Forge**: Grove HUD and Lighting Preview should hide while any panel is open and return on close. Lighting Preview is top-right during normal Play; its expanded/collapsed state should survive panel opening.

Only existing hit effects and damage numbers indicate a Cleave. There is **no unique wave VFX** yet.

## Limitations

GitHub source edits cannot execute Roblox Studio or its command-bar smoke tests. Confirm in Studio Play and inspect Output for script errors before merging the draft PR. This small debug patch is not game balance or final world dressing.
