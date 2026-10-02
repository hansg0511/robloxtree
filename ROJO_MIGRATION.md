# Rojo ownership and recovery

`default.project.json` maps `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, and `StarterPlayer.StarterPlayerScripts`. Each mapped root uses `$ignoreUnknownInstances: true`; a removed filesystem asset may remain as an unknown Studio instance until explicitly deleted. `Workspace` is intentionally not mapped.

The active clean place is `BrickWorldBase.rbxl`. Open it in Studio, run `rojo serve default.project.json`, and connect the Rojo 7.7.0 plugin. The source-built `WorldBootstrap` script makes a plain base ground/spawn in a Rojo-built place; `PlotManager` creates six runtime plots and five Grove slot markers per plot. World geometry for the future corridor is not implemented.

The full pre-rework Studio place is preserved in `archive/pre-gameplay-rework/Untitled Game - studio-before-brick-rework.rbxl`. The earlier pre-Rojo place is there too. See that archive's README for checksums. Do not assume a Git source checkout alone reconstructs the archived world.

Do not re-run `syncback` over this curated source tree. To change Studio-only geometry, save a new full-place copy and update the world manifest. Rojo 7.7.0 crashed when a mapped directory was deleted while serving; restart `rojo serve` and reconnect if that occurs.
