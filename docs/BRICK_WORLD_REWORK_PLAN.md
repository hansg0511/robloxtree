# Brick world rework plan

Checkpoint: `7b03f72` on `main` and `archive/pre-gameplay-rework`. Active development branch: `brick-world-rework`.

## Recovery boundary

The Git archive includes the 2026-10-01 full place (`archive/pre-gameplay-rework/Untitled Game - pre-rojo.rbxl`) and a fresh 2026-10-02 full place (`archive/pre-gameplay-rework/Untitled Game - studio-before-brick-rework.rbxl`). The latter was downloaded from the current Studio Edit session before world deletion; its size and SHA-256 are recorded in the archive README. Workspace is still outside Rojo.

## Keep unchanged or nearly unchanged

- ProfileService's session and reconciliation library and the profile cache interface.
- Server-owned item identity (`ItemID`, UID, rolled stats), item parsing, inventory container modules (`IMS` and `IMC`), and basic axe as the current test weapon.
- Client input → remote → server damage structure, DamageService's modifier pipeline, and reusable damage display/FX hooks.
- Semantic GUI structure and controllers until a separate visual redesign. No new aesthetic is built in this preparation task.

## Refactor

- Profile initialization: remove account-specific live wiping; make leave cleanup nil-safe; keep mock persistence explicitly documented for safe development.
- PlotManager: create required Workspace container itself, retain player ownership/release, expose an open Grove planting area, and remove hardcoded radial passive plot presentation.
- TreeObject: select definition/category from server data, allow trees under public or player containers, track many instances, and make HP, leaves, death and respawn independent of `PlotModel.Tree`.
- Chop handler: receive a client-nominated target candidate, resolve it through a server-owned model-to-`TreeObject` registry, validate player state, ownership, forest eligibility, equipped item and range, enforce a server cooldown, and calculate damage only on the server.
- Inventory remote handlers: validate current server inventory/tool state, guard uninitialized state, and rate-limit server mutations. Unsupported rearrange/sort remotes are removed rather than silently ignored.
- UI bootstrap: wait for replicated child hierarchy before accessing it.
- Documentation: update service ownership and describe current test limitations.

## Archive or remove from active source after recovery checks

- Dormant Goblin rig/spawner and vulnerable legacy Gun tool scripts.
- Old passive-plot/bush presentation, `Tree Minecraft`, and decorative platform assets.
- Studio-owned mountains, terrain layout, Forge, Anvil, crafting table and other old world decoration, once a fresh full-place snapshot exists.

The old `Basic` tree mesh was replaced by a source-built chunky brick placeholder and verified in Studio. It is only a smoke-test target, not final art. The cleaned `BrickWorldBase.rbxl` place is tracked as the active minimal Studio shell.

## Stable interfaces

- `ProfileLoadedEvent` and `ProfileLoadEvent` readiness signals.
- `ChopEvent` remains a client request: it may nominate an aimed model but cannot supply damage, HP, crits, rewards, RNG, or progression state.
- Inventory item UID records and the existing `EconomyUpdated(currency, amount)` outbound display contract.

`WorldProgressService` is the temporary server-only forest eligibility seam. Base and Forest 1 access are available for this scaffold; Forest 2 access is denied until server gameplay unlocks it. No barrier or Forest 2 content is implemented here.

Server-only tree definitions and registration may change internally. Public forest, barrier, boss, grove growing, selling, rebirth, Bark, Sharpness, and new reward formulas remain future work.

## Verification and rollback

Run a fresh Rojo build, inspect live Studio Output, join a player, confirm profile/plot/inventory startup, inspect remote initialization, and test a server-authorized tree hit and cleanup. Compare errors with the pre-rework baseline (missing sound `rbxassetid://90`, inventory `InventoryFrame` race, and mock profile wipe path). If live Studio changes fail, restore the full place snapshot and the archive branch; never force-push.

Studio smoke testing passed the new plot/tree/chop path. The old `rbxassetid://90` warning remains, but the inventory frame error did not recur. Do not mistake the remaining mock profile and old UI styling for production-ready systems.
