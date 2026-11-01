# Reference asset identifiers and access

The following IDs were read from the exported Studio models. They are source
identifiers only; current availability and permission to load them by ID have
not been verified. The gallery does not load assets by ID. It clones the exact
Rojo-tracked model files under `ServerStorage.DevAssetReferences`.

| Reference | Source identifier | Notes |
| --- | ---: | --- |
| `TerrainReference` Folder | `1915188299` | Contains 39 UnionOperations and a Baseplate; its thumbnail Camera is stripped from the display clone. |
| `BorderReference` Model | `13223165776` | Contains four MeshParts. |
| Border MeshPart 1 | `13223101408` | Source `MeshId`. |
| Border MeshPart 2 | `13223101277` | Source `MeshId`. |
| Border MeshPart 3 | `13223101687` | Source `MeshId`. |
| Border MeshPart 4 | `13223101551` | Source `MeshId`. |

The exact backups are tracked in `src/ServerStorage/DevAssetReferences/` as
`TerrainReference.rbxm` and `BorderReference.rbxm`. The gallery uses those
backups and is Studio-only; it never replaces the originals stored in Studio.

## Opening the gallery

`src/ServerScriptService/DevTreeGallery.server.luau` controls the Studio tree
gallery with its `ENABLED` setting. Leave it enabled and start or restart the
Studio server session. After `Workspace.DevTreeGallery` appears, the separate
reference gallery builder creates the isolated island and the client shows a
`REFERENCE ASSETS` button. Use that button to teleport the local Studio test
character to the displays. Setting the existing gallery's `ENABLED` setting
to `false` removes its generated model; the reference island cleans itself up
when that gate disappears.

## Original Studio instances

In the currently open Studio place, the original `Terrain` Folder and `Border`
Model were moved to `Lighting.StudioReferenceOriginals`, outside Workspace and
outside Rojo-managed services. Save the Studio place if that relocation should
persist in the place itself. The Rojo-tracked backups above do not depend on
those originals. Because Lighting is not Rojo-managed, it is not reconstructed
by Rojo; its contents also replicate if the place is saved and published.
