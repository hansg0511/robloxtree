# Active world manifest

`Workspace` remains Studio-owned. The tracked clean Studio place is `BrickWorldBase.rbxl`; it contains a minimal `BaseGround` and `BaseSpawn`, with no old mountains, forest, terrain layout, Forge, Anvil, crafting table, or decorative platform. Terrain was cleared.

The equivalent minimal ground and spawn are created by `ServerScriptService.WorldBootstrap`, so a Rojo build has a playable shell. `ServerStorage.PlotConfiguration` defines eight larger, flush ground-level plots arranged in a U with the future route opening at the front; `PlotManager` creates `Workspace.PlayerPlots` at runtime. Each plot has a non-visible `GroveArea` bounds object, not fixed tree slots. Personal Grove trees restore from profile records at local GroveArea coordinates after plot assignment; there is no automatic preview-tree spawn. Plot positions, colors, and the source-built Grove visuals remain early art-direction scaffolding rather than the future corridor.

Do not use the archived old place as the active world. It is retained only for rollback and inspection at `archive/pre-gameplay-rework/`.
