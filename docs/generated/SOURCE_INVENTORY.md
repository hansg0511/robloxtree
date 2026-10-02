# Active source inventory

`default.project.json` maps `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, and `StarterPlayerScripts`. `Workspace` remains outside Rojo; `BrickWorldBase.rbxl` is the cleaned full-place snapshot.

Review these entry points first:

- `src/ServerScriptService/PlayerProfile/ProfileInit/init.server.luau` — mock-backed profile startup and readiness signal.
- `src/ServerScriptService/WorldBootstrap.server.luau` — minimal base ground and spawn.
- `src/ServerStorage/PlotManager.luau` — plot ownership and five Grove slot markers.
- `src/ServerScriptService/Trees/TreeDefinitions.luau` and `Trees/TreeObject/init.luau` — server-only tree category definitions and lifecycle/registry.
- `src/ServerScriptService/Trees/BuildTreePlots.server.luau` — initial plot/tree assignment.
- `src/ServerScriptService/Economy/Wood/ChopHandler.server.luau` — server validation and damage path.
- `src/StarterPlayerScripts/Chopping/FireChop.client.luau` — client request input only.

`ROBLOX_GAME_CONTEXT.md` is a historical pre-rework snapshot, not the active world description. The archived `.rbxl` files preserve that former state.
