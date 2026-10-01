# Source inventory

Current Rojo-mapped snapshot:

| Artifact type | Count | Review use |
| --- | ---: | --- |
| `.luau` | 67 | Primary executable source; review these first. |
| `.json` | 64 | Rojo instance metadata, remotes, values, and properties. |
| `.rbxm` | 25 | Complex Studio models and GUIs; inspect in Studio when needed. |

Mapped services are `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, and `StarterPlayerScripts`.

Key entry points:

- `src/ServerScriptService/PlayerProfile/ProfileInit/init.server.luau` — profile initialization.
- `src/ServerScriptService/Trees/BuildTreePlots.server.luau` — plot assignment and initial tree spawning.
- `src/ServerScriptService/Economy/Wood/ChopHandler.server.luau` — chop event handling.
- `src/StarterPlayerScripts/Chopping/FireChop.client.luau` — client chop input.
- `src/ServerStorage/PlotManager.luau` — plot and tree construction.

The `Workspace` world is not in this inventory because it remains Studio-owned.
