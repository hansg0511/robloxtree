# Active world manifest

`Workspace` remains Studio-owned. The tracked clean Studio place is `BrickWorldBase.rbxl`; it contains a minimal `BaseGround` and `BaseSpawn`, with no old mountains, forest, terrain layout, Forge, Anvil, crafting table, or decorative platform. Terrain was cleared.

The equivalent minimal ground and spawn are created by `ServerScriptService.WorldBootstrap` when absent, so a Rojo build has a playable shell. `ServerStorage.PlotManager` creates `Workspace.PlayerPlots` at runtime: six owned plots in a temporary row, each with five `GroveSlots` markers. One slot currently spawns a server-built chunky brick placeholder tree for chop smoke tests. Plot positions and colors are not final art or the future corridor.

Do not use the archived old place as the active world. It is retained only for rollback and inspection at `archive/pre-gameplay-rework/`.
