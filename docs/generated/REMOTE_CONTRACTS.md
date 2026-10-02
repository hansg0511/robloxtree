# Runtime remote contracts

These are inferred from current source and Studio smoke tests; there is no typed remote schema yet.

| Remote / bindable | Direction | Current contract |
| --- | --- | --- |
| `ReplicatedStorage.Chop.ChopEvent` | client → server | No payload. Server checks cooldown, profile, equipped axe, character, ownership, and distance; resolves a registered target and computes damage. |
| `ReplicatedStorage.Chop.ChopFX` | server → clients | Named visual effect plus model data. |
| `ReplicatedStorage.DamageEvent` | server → clients | `{ Target, Damage, IsCrit, HP, MaxHP }` for display only. |
| `ReplicatedStorage.Economy.EconomyUpdated` | server → client | `(currency, amount)`; existing economy UI selects the named frame. |
| `ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent` | server bindable | Profile readiness for plot/inventory initialization. |
| `ReplicatedStorage.Inventory.NewInventoryItemRE` | server → client | New item notification; replaces the old mismatched `AddRE` client listener. |
| `ReplicatedStorage.Inventory/*` | mixed | Existing inventory actions/data; some unfinished capacity/sort/split flows remain disabled or guarded. Audit before enabling. |

The client is not authoritative for HP, damage, inventory, currency, or future progression. The inactive legacy Gun scripts were removed from the active source.
