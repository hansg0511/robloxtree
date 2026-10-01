# Rojo migration status

## Safety posture

This project is initially **partially managed**. Only the code/UI service roots are mapped:

- `ReplicatedStorage`
- `ServerScriptService`
- `StarterGui`
- `StarterPlayer.StarterPlayerScripts`

Every mapped service has `$ignoreUnknownInstances: true`. Rojo will preserve Studio instances not represented in this filesystem. Terrain, Workspace map content, CSG/UnionOperations, Forge/Anvil assets, and ServerStorage assets remain Studio-owned until deliberately migrated.

## Next safe migration step

1. In Roblox Studio: **File → Save to File As…**
2. Save a local backup as `backups/Untitled Game - pre-rojo.rbxl`.
3. Run:

   ```powershell
   rojo syncback default.project.json --input "backups/Untitled Game - pre-rojo.rbxl"
   ```

4. Inspect the generated `src/` tree before starting `rojo serve`.
5. Commit the generated source before connecting the Rojo Studio plugin.

Do not connect a Rojo server to the live place before step 4. The source tree must first contain the migrated scripts/UI.
