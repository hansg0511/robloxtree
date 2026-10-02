# First brick-world vertical slice

This source-controlled prototype deliberately contains only the route below:

```text
Base / player plots -> Starter Forest -> Barrier Tree -> Forest 2
```

`WorldLayoutConfiguration` owns the runtime layout data. The corridor follows
the central opening in the eight ground-level plots: it is six studs wide while
inside the base and sixteen studs wide after the plots. Starter Forest is
centered near Z=168, the barrier is at Z=245, and Forest 2 is centered near
Z=354. Each forest has twelve deterministic public tree placements.

## Prototype values, not final balance

| Tree | Forest | HP | Respawn | Interaction |
| --- | --- | ---: | ---: | --- |
| StarterForestTree | Forest1 | 60 | 3 s | trunk hitbox 10 x 22 x 10, radius 7 |
| Forest2Tree | Forest2 | 180 | 5 s | trunk hitbox 11 x 32 x 11, radius 8 |
| BarrierTree | Forest1 | 600 | 20 s | gate/trunk hitbox 76 x 68 x 30, radius 10 |

The barrier is shared physically. Its valid server-side final hitter receives a
session-only `Forest2` unlock through `WorldProgressService`. The barrier
returns after twenty seconds so other players can independently earn their own
unlock. Physical passage through or around the barrier never grants access:
Forest 2 trees still require the server-side per-player unlock.

No Forest 3, economy, selling, rebirth, tree growth, mutations, Bark,
Sharpness, or permanent progression is included in this prototype.
