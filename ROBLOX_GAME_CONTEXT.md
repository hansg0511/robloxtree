# Roblox Game Context Pack

> Snapshot date: 2026-10-01  
> Place: `Untitled Game` — PlaceId `121864357793790`  
> Capture mode: Studio Edit DataModel, read-only inspection

## Purpose

This is a compact handoff for a developer or an AI agent. It captures the current game architecture, relevant instance paths, system contracts, observed behavior, and known risks. It is deliberately smaller than a raw place dump so it can be attached to a new chat without overwhelming its context.

For a raw hierarchy and script-source export, use `roblox_context_exporter_improved.lua` in this same folder. That exporter writes Markdown in labelled console chunks; it does not edit the game or make HTTP requests.

## Game overview

The project is a lumber/plot-progression prototype. A player is assigned a plot, enters a zone around their active tree, uses an equipped axe to chop it, and should receive inventory/economy progression. The world also includes forge, anvil, and crafting-table props, plus a dormant goblin combat/spawning system.

Core loop, as currently implemented:

```text
Profile load
  -> plot assignment/build
  -> tree instance + zone binding
  -> client left-click while InZone
  -> ReplicatedStorage.Chop.ChopEvent
  -> server damage calculation / Tree:TakeDamage
  -> hit FX, leaf drops, tree fall, timed respawn
```

## Primary DataModel map

### Workspace

- `Workspace.PlayerPlots`: empty in Edit mode; runtime builds folders `0` through `5`.
  - Runtime tree seen at `Workspace.PlayerPlots.0.PlotModel.Tree`.
  - The runtime tree pivot was observed around `(0, 0, 125)`.
  - Plot zone template: `ServerStorage.PlotTemplate.PlotModel.Zone`.
- `Workspace.MountainBackground`: repeated `Mountain` models (23 observed).
- `Workspace.Forge`, `Workspace.Anvil`, `Workspace.Crafting Table`, `Workspace.Platform`: map props.
- Post-processing effects (`Bloom`, `Blur`, `ColorCorrection`, `SunRays`) currently sit under `Workspace`.

### ReplicatedStorage

- `Zone`: shared zone library.
- `FXService`: shared visual-effects module.
- `Inventory`: remote collection (11 remotes observed).
- `Profile.ProfileLoadEvent`.
- `Economy.EconomyUpdated`.
- `Chop.ChopEvent`, `Chop.ChopFX`.
- `Modules.NumberFormat` and GUI templates.

### ServerScriptService

- `GoblinSpawningScript`.
- `TreeService`: `Oak`, `HugeOak`, `VariableOak` modules.
- `Inventory`: `InventoryHandler`, `DataStoreLoader`, `IMS`.
- `PlayerProfile`: `ProfileService`, `ProfileInit`, profile-cache/default modules.
- `Economy`: `EconomyManager`, `Wood/ChopHandler`.
- `Trees`: `BuildTree/Plots`, `TreeObject`, `TreeDatabase`.

### ServerStorage

- `PlotManager`, `DamageService`.
- `Goblin` rig with `GoblinAI`.
- `TreeTypes.Basic` and a large `Tree Minecraft` model.
- `PlotTemplate` and passive plot template.
- Axe/tool assets and item database/generation/stat modules.

### Client

- `StarterPlayer.StarterPlayerScripts.Chopping.FireChop`.
- `StarterPlayer.StarterPlayerScripts.Inventory` and client modules.
- `StarterGui`: inventory and economy UI, including an economy updater LocalScript.

## Chopping contract

### Client guard

`StarterPlayer.StarterPlayerScripts.Chopping.FireChop`:

```lua
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        track:Play()
        if player:GetAttribute("InZone") then
            ChopEvent:FireServer()
        end
    end
end)
```

The tree is not mouse-targeted. The two required preconditions are an unprocessed `MouseButton1` input and `player:GetAttribute("InZone") == true`.

### Zone / active tree behavior

`ServerScriptService.Trees.TreeObject` constructs a zone from `PlotModel.Zone`. On enter it assigns `Tree.ActiveTreeByPlayer[player]` and sets `InZone = true`; on exit it clears both. The active tree spawns from `ServerStorage.TreeTypes`, is parented to the plot, and uses a three-second respawn delay.

### Server behavior

`Tree:TakeDamage` performs these effects:

- ignores hits after death;
- fires hit FX and damage UI data;
- subtracts server-calculated damage;
- drops leaves based on HP;
- falls at zero HP, then respawns after the delay.

## Test evidence and limitations

- A read-only Play session successfully initialized profile and inventory setup.
- The player character was moved near Plot 0's tree and synthetic clicks were sent.
- No chop/damage/fall logs appeared. This did **not** prove chopping is broken: the test did not independently verify `InZone`, and the input bridge may not have delivered a `UserInputType.MouseButton1` event to `UserInputService`.
- A proper regression test must first inspect `InZone = true`, then use a validated mouse input path and assert `ChopEvent` handling, damage, tree HP, FX, and respawn.

## Current high-priority risks

1. **Persistence:** `ProfileInit` loads through `ProfileStore.Mock`; durable saving is not established. A special-user branch wipes profiles on join.
2. **Profile removal safety:** player removal dereferences runtime profile data before checking whether a cache entry exists.
3. **Chop abuse:** sampled server handling has no cooldown/rate limit.
4. **Chop reward gap:** the inspected chop path imports economy support but does not visibly award wood.
5. **Inventory remotes:** server/client remote names are inconsistent; some handlers are commented out and some referenced remotes were absent in the inspected tree.
6. **Seed stat generation:** seed stats include `Health`, `Defense`, and `Regen`, while the inspected stat database includes only attack/critical-stat definitions; item generation can fail.
7. **Plot cleanup:** `PlotManager.CleanUp` references undefined `TreeCache`; player-removal cleanup was not found.
8. **Goblin system:** spawn loop is commented out; AI assumes a player and loaded character without nil checks.
9. **Audio:** Studio console reports `rbxassetid://90` cannot load.

## Recommended implementation order

1. Make profile loading use the intended production store and add safe nil handling on departure.
2. Define and test a server-authoritative chop reward/cooldown contract.
3. Repair inventory remote names and re-enable/implement required handlers.
4. Fix seed-stat definitions and add generator tests.
5. Implement plot/tree cleanup, then enable goblin spawning only after AI guards are in place.
6. Replace the missing sound asset and perform a real local play-test of the full progression loop.

## Context boundaries

- This pack is an architectural snapshot, not a `.rbxl` backup.
- Mesh/source binary data is not embedded; asset IDs and instance paths should be used to locate it in Studio.
- Studio was in Edit mode for the snapshot. Runtime-built plots, characters, and UI may differ after Play begins.
- Treat this document as a starting map; refresh it after significant changes.

