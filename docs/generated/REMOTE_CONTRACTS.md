# Runtime remote contracts

These are inferred from current source and Studio smoke tests; there is no typed remote schema yet.

| Remote / bindable | Direction | Current contract |
| --- | --- | --- |
| `ReplicatedStorage.Chop.ChopEvent` | client → server | Intent only; no payload. The server selects the closest eligible registered `TreeObject` using each tree's explicit server-owned `ChopHitbox` bounds, then checks cooldown, alive/choppable state, owner, character/range, equipped axe, and `WorldProgressService` forest access. Damage, crit, HP, rewards, and RNG are server-calculated. |
| `ReplicatedStorage.Chop.ChopFX` | server → clients | Named visual effect plus model data. |
| `ReplicatedStorage.DamageEvent` | server → clients | `{ Target, Damage, IsCrit, HP, MaxHP }` for display only. |
| `ReplicatedStorage.Economy.EconomyUpdated` | server → client | `(currency, amount)`; existing economy UI selects the named frame. |
| `ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent` | server bindable | Profile readiness for plot/inventory initialization. |
| `ReplicatedStorage.Inventory.NewInventoryItemRE` | server → client | New item notification. |
| `ReplicatedStorage.Inventory.EquipRE` | client → server | A slot-index request only. The server validates the existing server inventory item and limits each player to one request per 0.15 seconds. |
| `ReplicatedStorage.Inventory.SpawnEquippedItemRE` | client → server | Requests spawning the currently server-selected weapon. The server validates the runtime item/template/character, replaces only server-marked tools, recalculates stats, and limits each player to one request per 0.75 seconds. |
| `ReplicatedStorage.Inventory.GetDataRF` | client → server | Read-only snapshot of the server inventory. |
| `ReplicatedStorage.Grove.GetGroveStateRF` | client → server | No arguments. Returns a fresh `{ Revision, HasAssignedGrove, Capacity, MinimumSpacing, PlacementMargin, Saplings, GroveTrees, GroveMaterials, ActiveGroveTreeUIDs }` snapshot with copied primitive fields and timestamp-derived tree `Stage`; `Revision` prevents an older startup response overwriting a newer pushed state, `ActiveGroveTreeUIDs` is always empty until active Grove features, and no profile table references are returned. |
| `ReplicatedStorage.Grove.PlantSaplingRE` | client → server | Exactly `(saplingUID: string, localX: number, localZ: number)`. The server validates the unique profile sapling, assigned GroveArea bounds, capacity, spacing, and cooldown, then derives species, mutations, size, UID, yaw, and timestamps. Extra arguments and malformed values are rejected. |
| `ReplicatedStorage.Grove.GroveStateUpdatedRE` | server → client | One sanitized Grove state snapshot after a successful plant, plot restoration, mature-tree-to-Heartwood harvest, or confirmed wild-tree sapling discovery. |
| `ReplicatedStorage.Grove.SaplingDiscoveredRE` | server → client | One server-confirmed `{ UID, SpeciesId, Mutations, SizePotential }` record for a newly discovered eligible wild-tree sapling. The client uses it only for temporary feedback, then reads the normal Grove snapshot; it cannot initiate a reward or influence RNG. |

The client is not authoritative for HP, damage, inventory, currency, or forest progression. Obsolete `AddRE`, slot mutation, sort, and per-item lookup remotes were removed rather than kept as inactive attack surface.
