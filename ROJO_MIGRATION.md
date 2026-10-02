# Rojo ownership and recovery

## Git-authoritative service roots

`default.project.json` explicitly sets `$ignoreUnknownInstances: false` on
every mapped gameplay/code root. Rojo owns their full contents:

- `ReplicatedStorage`
- `ServerScriptService`
- `ServerStorage`
- `StarterGui`
- `StarterPlayer`, including `StarterPlayerScripts`

Consequently, a script, ModuleScript, RemoteEvent, or GUI left only in Studio is
not part of the game contract and is removed by a full Rojo sync. This prevents
Studio from executing a stale object that Git and code review cannot see.

No mapped root deliberately retains unknown instances. `Workspace` is not
mapped: it remains Studio-owned for geometry, terrain, and later art placement.
That is not a gameplay-security boundary. Runtime code creates the minimal
`BaseGround`, `BaseSpawn`, and `PlayerPlots` shell, while server services decide
what a player may interact with.

The active clean place is `BrickWorldBase.rbxl`. Open it in Studio, run `rojo
serve default.project.json`, and connect the Rojo 7.7.0 plugin. Plot placement
is configured in `ServerStorage.PlotConfiguration`; `PlotManager` creates eight
ground-level U-shaped plots at runtime. Each plot exposes an invisible open
`GroveArea` rather than fixed tree markers.

## Structural syncs

Before syncing a project that removes source paths, save Studio work you intend
to keep. Rojo 7.7.0 previously crashed when a mapped directory was deleted
while it was serving; restart `rojo serve` and reconnect the plugin after a
structural deletion. A fresh `rojo build` is the reproducibility check and does
not use Studio-only leftovers.

Do not run `syncback` over this curated source tree. For Studio-only geometry,
save a new full-place copy and update the world manifest.

## Recovery

The full pre-rework Studio places are preserved under
`archive/pre-gameplay-rework/`. Their checksums are recorded in that archive's
README. They are rollback/inspection artifacts, not active Rojo source.
