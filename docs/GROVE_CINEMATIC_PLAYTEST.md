# Grove cinematic harvesting — prototype playtest

Feature branch: `feature/grove-cinematic-harvest-prototype`

Base: `feature/grove-regrowth-harvest-prototype`. This is a **draft playable prototype**, not animation polish or a launch-ready Grove economy.

## What changed

- **E to Harvest:** Each *mature* Grove tree has an owner-only ProximityPrompt anchored near the trunk base. There is no hold time; press E when nearby.
- **Wild forest chopping is unchanged.** Personal Grove trees are no longer eligible for the regular axe/ChopEvent path; the server validates proximity, living character, plot assignment, unique Grove ID, owner and maturity before harvesting.
- **Short skippable owner cutscene:** A local camera smoothly frames the planted tree, plays a wind-up from the existing leaf sound library, briefly shakes on impact, then releases to Roblox's normal camera controller after about three seconds. Click **SKIP** or press **Space**, **Escape**, or gamepad **B**. Death, character replacement and a safety timer restore the camera. No movement speed or control scripts are modified.
- **Tree fall and audio:** Reuses the existing FXService tree-fall animation with a brief charge-up. A server-owned slash sound reuses the chop asset already in FXService; the landing uses an existing leaf impact sound.
- **Physical-looking reward:** At the tree-fall reveal beat, a separately constructed model uses existing SpeciesVisuals log geometry, with its real recorded size and colored outlines for Golden/Crystal/Giant mutations. It falls, bounces, rests briefly and flies toward its owner. The model is server-replicated so nearby players can see it. It has no ProximityPrompt, collisions or authoritative reward behavior.
- **Reward banner:** Displays only **after** the visible log animation. The unique log was already credited server-side before the tree began falling; cinematic interruption cannot duplicate or erase the item.
- **Existing Grove persistence rules and growth timings stay the same.** The permanent tree retains genetics, rerolls actual size each harvest, and regrows from a stump. Legacy Heartwood is untouched. Full SAVED storage still rejects harvesting and leaves the mature tree available.

## Switch your workspace

With no uncommitted local changes:

```bash
git status
git fetch origin
git switch --track origin/feature/grove-cinematic-harvest-prototype
rojo serve default.project.json
```

Open `BrickWorldBase.rbxl`, connect the Rojo plugin, and Play in Studio.

If you already have this feature branch locally, use `git switch feature/grove-cinematic-harvest-prototype` then `git pull --ff-only`.

## Playtest walkthrough

1. Locate a *mature* tree in your Grove. Walk near its base and confirm a **Harvest — E** prompt appears.
2. Click your mouse/attack key near the tree: ordinary axe damage should not harvest it.
3. Press **E**. Camera should frame the tree (owner only); the wind-up and slash should play, the tree should **fall**, and a single large log should fall/bounce beside it and fly to you. A reward banner appears after the log fly-in.
4. Press **Space** or **SKIP** halfway through: your regular camera should return immediately. The server continues the fall and log visuals; the item should still appear in SAVED storage.
5. Harvest a tree, then reset/die during the camera sequence: normal Roblox camera controls should return. You should still own exactly one reward UID.
6. Open storage using **N**, confirm **one GROVE** item with source species, mutations and size. Forge from a saved log and confirm no duplicate material reward.
7. Wait for the stump and the next mature tree. Harvest again: two separate unique log UIDs, each keeping the same Grove origin, with potentially different size. Tree retains its Grove UID and genetics.
8. Try another player's Grove tree with a second client: you should not see or be able to use a valid harvest prompt. Their E interaction must never move your camera. You can still see their tree fall and flying reward model nearby.
9. Simulate full protected storage (Studio-only setup) and press E on your mature tree: no camera sequence, no tree removal and no loss of materials; storage-full notice should appear.
10. Rapidly press E on the same tree. Exactly **one** successful harvest should occur. Verify one log grant and one new Grove growth cycle.
11. Verify an immature tree has **no** harvest prompt, even if you attack it or press E nearby.
12. Paste `tests/GroveHarvestPrompt.smoke.luau` and `tests/GroveGrowthRules.smoke.luau` into the Studio **SERVER** Command Bar. Only the pure/static checks can be automated this way; the rest requires gameplay testing.

## Known limitations and next pass

- The cinematic, tree fall, sound balance, and log motion are provisional; the log is a **server-replicated cosmetic model**, not a second collectible item. The authoritative item is immediately saved before the FX begins.
- A camera skipped by the owner does not cancel the world visual for other players.
- **Growth silhouettes remain the original scaling/stump prototype**; this branch does not redesign the separate sapling/young/mature shapes. That is a different visual-development task.
- This branch doesn't add new sounds/assets, mutations, weapon quality systems, currencies or sapling shop changes.
- `ProfileStore.Mock` remains enabled; cross-session persistence and production-grade multiplayer stress have not been verified.
- GitHub source review is possible here; **ChatGPT has not executed Roblox Studio or Luau tests**. Treat the branch as unverified until you playtest.

## Relevant source

- `TreeObject/init.luau`: prompt placement, server input checks, harvest trigger, fall/reveal orchestration.
- `GroveService.luau`: successful reward grant, cooldown, start event, unchanged regrowth.
- `GroveHarvestVisualService.luau`: world log model, bounce/homing, world audio, post-reveal event.
- `GroveHarvestCinematic.client.luau`: camera, windup, skip/death cleanup and reward HUD.
- `Shared/GroveHarvestPresentation.luau`: central timing controls.
