# RobloxTree review guide

This repository is a Rojo source mirror of the active Roblox Studio game. It is intended to give code reviewers and LLMs a useful, versioned view of the game without pretending every Studio artifact can be losslessly represented as text.

## Read order

1. `ROBLOX_GAME_CONTEXT.md` for the captured Studio hierarchy and architectural notes.
2. `docs/generated/REMOTE_CONTRACTS.md` and `docs/generated/WORLD_MANIFEST.md` for boundaries between systems.
3. `src/` for the executable Rojo source.
4. `docs/generated/ASSET_AND_BINARY_MANIFEST.md` for source artifacts that require Studio inspection.

## Source-of-truth boundaries

Rojo owns the mapped services in `default.project.json`: `ReplicatedStorage`, `ServerScriptService`, `ServerStorage`, `StarterGui`, and `StarterPlayerScripts`.

The live `Workspace` map, terrain, CSG/unions, placement, and other art-heavy world content remain Studio-owned for now. They are described in `docs/generated/WORLD_MANIFEST.md`; they are deliberately not synced from this filesystem.

Files under `archive/` are rollback artifacts only. They are not included in the Rojo project.

## Review expectations

Review Luau logic, remote contracts, module boundaries, runtime assumptions, and places where data validation is missing. Treat `.rbxm` files as real source artifacts that must be opened in Studio when their embedded hierarchy or UI/model data matters. The adjacent manifests call out the most important ones.

This snapshot was initially exported from `backups/Untitled Game - pre-rojo.rbxl` on 2026-10-01. Regenerate via Rojo syncback after intentional Studio-side changes to the mapped services.
