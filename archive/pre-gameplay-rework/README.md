# Prototype recovery snapshot

`Untitled Game - pre-rojo.rbxl` is a full Roblox place saved from Studio on 2026-10-01 before the initial Rojo migration. It contains the Studio-owned Workspace world, terrain, map geometry, and other instances that `default.project.json` does not map.

SHA-256: `83FAA5D9BEB00913CB808CB0B0E1C4056A0755F0961470C31653ECEBA4E28982`

The backup predates the Rojo source conversion. To recover the pre-rework prototype, open this place in Studio and sync the `archive/pre-gameplay-rework` Git branch's Rojo source, or use the place alone to inspect the earlier pre-Rojo state. The original local copy remains under `backups/` and is ignored by Git.

Do not remove this Git-tracked place snapshot until another complete and verified recovery path exists.

`Untitled Game - studio-before-brick-rework.rbxl` is a fresh full-place copy downloaded from the current Studio Edit session on 2026-10-02, before deleting any legacy world content. It is 370,825 bytes and has SHA-256 `4EE593B17484BC452B8C22034CBCFB8920CD92C4CD1565D8A48C33830305AF1E`. This is the preferred recovery point for the exact pre-rework Studio world and Rojo-synced source.
