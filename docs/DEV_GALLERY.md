# Studio development gallery

The gallery is a Studio-only workspace for tree, terrain, reference-asset, and future lab previews. Change the switchboard at `ServerScriptService.DevGallery.Config`, then sync and restart the Studio server.

| Setting | Current default | What it controls |
| --- | --- | --- |
| `Enabled` | `true` | Master switch; false clears the coordinator-owned gallery shell and registry in Studio. |
| `Origin` | `Vector3.new(6000, 120, 6000)` | Shared world origin for the gallery shell and lab layout. |
| `Labs.Tree` | `true` | Builds the current tree lab. |
| `Labs.Terrain` | `true` | Builds the Mesa and boundary studies; also gates the reference-asset island. |
| `Labs.Forest` | `true` | Builds the Studio-only World 1 Forest Design Lab showcase and its two navigation entries. |
| `Labs.Archive` | `true` | Shows the archive landing section. |
| `Archive.TreeStudies` | `false` | Optionally builds the archived tree comparisons under the Archive section. |

`Archive.TreeStudies` requires `Enabled` and `Labs.Archive`; it does not require `Labs.Tree`. To see only the archived comparisons, set `Labs.Tree = false`, leave `Labs.Archive = true`, and set `Archive.TreeStudies = true`.

## Current contents

The active `TreeLab` contains the Starter Oak Structural Study, 12 procedural comparison trees (seeds 20261030–20261041, four per row; samples 4, 8, and 12 are marked extreme), and the Starter Oak, full Wild Oak, and procedural harvest showcases. The four procedural harvest categories are Short, Normal, Tall, and Extreme/Asymmetrical; each uses a bounded search of up to 512 deterministic seed candidates. The showcase keeps the local fall and Backpack/Overflow pickup preview. It does not award gameplay rewards. Five A–E alternative Starter Oak layout definitions remain in the server source, but the current active assembly uses the Structural Study layout.

When enabled, `ArchiveLab.TreeStudiesArchive` contains the older Grove mutation comparisons (Oak, Bamboo, Ironwood), growth-stage comparisons, and Wild Oak versus Grove Oak builder comparison. These rows are retained in source and are not built by default.

The Terrain lab adds a Mesa overview and Terrain, Faceted, and Mixed boundary studies west of the shared gallery floor. The reference island clones the tracked `TerrainReference.rbxm` and `BorderReference.rbxm` backups from `ServerStorage.DevAssetReferences`; the reference builder does not edit those source files. See [REFERENCE_ASSETS.md](REFERENCE_ASSETS.md) for source IDs and caveats. In particular, the tracked TerrainReference backup is present, but restoration into the intended Studio hierarchy through Rojo has not been proven.

The Forest Design Lab builds two independently reachable interpretations of one bright, toy-like World 1 woodland clearing: **Forest A · Softer Storybook** emphasizes warmth and gentler silhouettes; **Forest B · Chunkier Storybook** uses stronger sculpted shapes. Both remain Studio-only showcase content beneath `Workspace.DevTreeGallery.ForestLab`. Turn the lab off with `Labs.Forest = false`; a failed forest module build leaves Tree, Terrain, and other enabled labs available.

## Shared ownership and navigation

The coordinator owns `Workspace.DevTreeGallery`, tagged `DevGalleryOwner = "Coordinator"`, including its direct `GalleryFloor` and `GallerySpawn`. Lab builders should wait for that ready shell, create or replace only their own named child, and never replace the shared root or another builder's content. Publish a lab's ready flag and teleport CFrame only after its complete target is attached. TreeLab uses `DevGalleryOwner = "TreeLab"`; archived studies use `DevGalleryOwner = "TreeStudiesArchive"` under `ArchiveLab`. Terrain publishes its own Mesa version and teleport attributes on the shared root.

`DevGalleryNavigation.client.luau` is the unified navigation UI. It reads the coordinator's registry, streams toward a selected ready target, and provides **Return to World** using the saved pre-gallery position or a non-gallery SpawnLocation/BaseGround fallback. The former standalone teleport LocalScripts have been removed. These are source contracts; navigation has not been verified in a Studio session for this guide, and no Studio playtest is claimed.

For a new lab, add its `Labs` switch, Studio/config gate, uniquely owned subtree, and post-build readiness/destination attributes; then teach the coordinator registry which target and destination to expose. For archived tree studies, keep the archive under `ArchiveLab` and gate it with both `Labs.Archive` and `Archive.TreeStudies`. The Forest Design Lab publishes its A/B navigation destinations only after both variation models are attached and ready; the unified UI streams to each selected landing and focus point.
