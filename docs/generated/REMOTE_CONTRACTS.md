# Runtime remote contracts

These are inferred from the current source; the repository does not yet enforce typed remote schemas.

| Remote / bindable | Direction | Payload / role | Evidence |
| --- | --- | --- | --- |
| `ReplicatedStorage.Chop.ChopEvent` | client → server | Fired by `FireChop` when the player has `InZone`; drives tree damage. | `StarterPlayerScripts/Chopping/FireChop.client.luau`, `ServerScriptService/Economy/Wood/ChopHandler.server.luau` |
| `ReplicatedStorage.Chop.ChopFX` | server → all clients | Named chop visual effect and effect data. | `TreeObject` |
| `ReplicatedStorage.DamageEvent` | server → all clients | `{ Target, Damage, IsCrit, HP, MaxHP }` for damage UI. | `TreeObject` |
| `ReplicatedStorage.Economy.EconomyUpdated` | server → client | `(currency, amount)`; UI selects `<currency>Frame`. | `EconomyManager`, embedded `EconomyGui` script |
| `ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent` | server bindable | Signals profile readiness; initializes a player plot and trees. | `Trees/BuildTreePlots.server.luau` |
| `ReplicatedStorage.Inventory/*` | mixed | Inventory commands and data functions; contracts need an explicit schema audit. | `ReplicatedStorage/Inventory` |

Review risk: remotes should validate rate, player state, and payloads on the server. The chop path was previously observed without an explicit rate limiter in the sampled handler.
