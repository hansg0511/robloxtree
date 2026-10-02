# RobloxTree review guide

This repository contains Rojo-mapped source plus a cleaned full Studio place. It is prepared for the brick-world redesign; it is not a finished new game.

## Read order

1. `docs/BRICK_WORLD_REWORK_PLAN.md` and `docs/generated/WORLD_MANIFEST.md` for the current architecture and scope.
2. `docs/generated/REMOTE_CONTRACTS.md` for trust boundaries.
3. `src/` for active source.
4. `docs/generated/ASSET_AND_BINARY_MANIFEST.md` for opaque assets.
5. `ROBLOX_GAME_CONTEXT.md` only as historical pre-rework context.

## Source-of-truth boundaries

Rojo maps five service roots in `default.project.json`; `Workspace` is Studio-owned. `BrickWorldBase.rbxl` is the active minimal place snapshot. Files under `archive/` are rollback-only and not Rojo-mapped.

For gameplay changes, edit source in `src/`. For Studio-only geometry, save a fresh full place copy and update the world manifest. Do not run blanket `syncback` over the curated rework source. Review `.rbxm` assets in Studio when visual hierarchy or nested properties matter.
