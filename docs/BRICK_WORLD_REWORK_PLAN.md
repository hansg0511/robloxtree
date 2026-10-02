# Brick world rework plan

Checkpoint: `7b03f72` on `main` and `archive/pre-gameplay-rework`. Active development branch: `brick-world-rework`.

## Recovery boundary

The Git archive includes the 2026-10-01 full place (`archive/pre-gameplay-rework/Untitled Game - pre-rojo.rbxl`), which retains the pre-Rojo Studio world. The current Studio Workspace is still outside Rojo. Before deleting its mountain, terrain, Forge, Anvil, crafting table, or platform, save a fresh full-place copy from the current Studio session and verify the saved file. The older backup is a recovery baseline but may omit subsequent Studio edits.

## Keep unchanged or nearly unchanged

- ProfileService's session and reconciliation library and the profile cache interface.
- Server-owned item identity (`ItemID`, UID, rolled stats), item parsing, inventory container modules (`IMS` and `IMC`), and basic axe as the current test weapon.
- Client input → remote → server damage structure, DamageService's modifier pipeline, and reusable damage display/FX hooks.
- Semantic GUI structure and controllers until a separate visual redesign. No new aesthetic is built in this preparation task.

## Refactor

- Profile initialization: remove account-specific live wiping; make leave cleanup nil-safe; keep mock persistence explicitly documented for safe development.
- PlotManager: create required Workspace container itself, retain player ownership/release, expose stable Grove slot descriptors, and remove hardcoded radial passive plot presentation.
- TreeObject: select definition/category from server data, allow trees under public or player containers, track many instances, and make HP, leaves, death and respawn independent of `PlotModel.Tree`.
- Chop handler: choose a server-registered target, validate player state, equipped item and range, enforce a server cooldown, and calculate damage only on the server.
- Inventory remote handlers: align active names, validate item/slot/sort inputs, and guard uninitialized state. Preserve the current individualized item schema without inventing final stats.
- UI bootstrap: wait for replicated child hierarchy before accessing it.
- Documentation: update service ownership and describe current test limitations.

## Archive or remove from active source after recovery checks

- Dormant Goblin rig/spawner and vulnerable legacy Gun tool scripts.
- Old passive-plot/bush presentation, `Tree Minecraft`, and decorative platform assets.
- Studio-owned mountains, terrain layout, Forge, Anvil, crafting table and other old world decoration, once a fresh full-place snapshot exists.

Keep the current `Basic` tree model as a temporary chop smoke target until a replacement placeholder is verified in Studio; it is not the final brick-style art asset.

## Stable interfaces

- `ProfileLoadedEvent` and `ProfileLoadEvent` readiness signals.
- `ChopEvent` remains a client request with no client-supplied damage or reward.
- Inventory item UID records and the existing `EconomyUpdated(currency, amount)` outbound display contract.

Server-only tree definitions and registration may change internally. Public forest, barrier, boss, grove growing, selling, rebirth, Bark, Sharpness, and new reward formulas remain future work.

## Verification and rollback

Run a fresh Rojo build, inspect live Studio Output, join a player, confirm profile/plot/inventory startup, inspect remote initialization, and test a server-authorized tree hit and cleanup. Compare errors with the pre-rework baseline (missing sound `rbxassetid://90`, inventory `InventoryFrame` race, and mock profile wipe path). If live Studio changes fail, restore the full place snapshot and the archive branch; never force-push.
