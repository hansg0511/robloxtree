# Studio development gallery

The gallery is a Studio-only workspace for tree, terrain, reference-asset, and future lab previews. Change the switchboard at `ServerScriptService.DevGallery.Config`, then sync and restart the Studio server.

| Setting | Current default | What it controls |
| --- | --- | --- |
| `Enabled` | `true` | Master switch; false clears the coordinator-owned gallery shell and registry in Studio. |
| `Origin` | `Vector3.new(6000, 120, 6000)` | Shared world origin for the gallery shell and lab layout. |
| `Labs.Tree` | `true` | Builds the current tree lab. |
| `Labs.Terrain` | `true` | Builds the Mesa and boundary studies; also gates the reference-asset island. |
| `Labs.Forest` | `true` | Builds the Studio-only World 1 Forest Design Lab, its A/B scenes, four existing controlled contrast tests, four cartoon simulator comparisons, and the optional asset catalog navigation entry. |
| `Labs.Archive` | `true` | Shows the archive landing section. |
| `Archive.TreeStudies` | `false` | Optionally builds the archived tree comparisons under the Archive section. |

`Archive.TreeStudies` requires `Enabled` and `Labs.Archive`; it does not require `Labs.Tree`. To see only the archived comparisons, set `Labs.Tree = false`, leave `Labs.Archive = true`, and set `Archive.TreeStudies = true`.

## Current contents

The active `TreeLab` contains the Starter Oak Structural Study, 12 procedural comparison trees (seeds 20261030–20261041, four per row; samples 4, 8, and 12 are marked extreme), and the Starter Oak, full Wild Oak, and procedural harvest showcases. The four procedural harvest categories are Short, Normal, Tall, and Extreme/Asymmetrical; each uses a bounded search of up to 512 deterministic seed candidates. The showcase keeps the local fall and Backpack/Overflow pickup preview. It does not award gameplay rewards. Five A–E alternative Starter Oak layout definitions remain in the server source, but the current active assembly uses the Structural Study layout.

When enabled, `ArchiveLab.TreeStudiesArchive` contains the older Grove mutation comparisons (Oak, Bamboo, Ironwood), growth-stage comparisons, and Wild Oak versus Grove Oak builder comparison. These rows are retained in source and are not built by default.

The Terrain lab adds a Mesa overview and Terrain, Faceted, and Mixed boundary studies west of the shared gallery floor. The reference island clones the tracked `TerrainReference.rbxm` and `BorderReference.rbxm` backups from `ServerStorage.DevAssetReferences`; the reference builder does not edit those source files. See [REFERENCE_ASSETS.md](REFERENCE_ASSETS.md) for source IDs and caveats. In particular, the tracked TerrainReference backup is present, but restoration into the intended Studio hierarchy through Rojo has not been proven.

The Forest Design Lab builds two independently reachable interpretations of one bright, toy-like World 1 woodland clearing: **Forest A · Softer Storybook** emphasizes warmth and gentler silhouettes; **Forest B · Chunkier Storybook** uses stronger sculpted shapes. Unified navigation includes the **FOREST ASSET CATALOG**, four existing controlled contrast destinations, and four cartoon simulator comparisons. The A/B scenes, catalog, and tests remain under `Workspace.DevTreeGallery.ForestLab.ForestDesignLab`; if the controlled comparison build fails, A/B and the catalog remain available. Turn the lab off with `Labs.Forest = false`.

## Controlled Forest contrasts

With `Labs.Forest = true`, sync the updated Forest module, coordinator, and navigation script, then start a **fresh Studio Play/Start Server session**. The coordinator preserves an already-built schema-2 ForestDesignLab to keep A/B and the catalog intact, so newly built comparison targets appear after a fresh Play. Open **DEV GALLERY** and select the labeled entry; use **RETURN TO WORLD** when finished.

| Entry | Controlled change |
| --- | --- |
| **TEST 1 · RICH OAK** | Shared bright Cartoony grass with richer, deeper role-mapped oak foliage: Leaf 58,145,47, highlight 105,190,60, and shadow 28,95,30. |
| **TEST 2 · MINT GRASS** | Mint grass only: +56 blue channel with red and green unchanged; oak foliage and shadows stay unchanged. |
| **TEST 3 · ORIGINAL + SHADOWS** | Original bright grass and oak colors with five pairs of soft green ground shadows. Each pair uses a 13×9 outer ellipse at 0.82 transparency and a 10×7 inner ellipse at 0.52 transparency. |
| **TEST 4 · MINT + SHADOWS** | The same +56 mint shift as Test2 plus the same five paired ground shadows as Test3. |

All four use five Chunkier-scene Oaks with seeds `418031, 418047, 418063, 418079, 418097`, cloned with the same scales, props, paths, and local shadow positions. Their ground treatment uses an optional temporary sample at `MaterialService.TemporaryForestGrassComparisonArchive_20261114.GrassFloorPreview_Temporary.GrassSample_07` (AssetId `7213563087`; top texture `rbxassetid://7209230195`). The sample may be absent after Studio closes and reopens. When it is available, its base color is `RGB 77, 173, 76`; Test2 and Test4 shift it to `RGB 77, 173, 132`. If the sample or texture cannot be used, the tests still build: all ground surfaces use `SmoothPlastic`, the main floor uses visible green `RGB 121, 199, 93`, and the five facets keep their varied green shades. Test2 and Test4 apply the same +56 blue shift to those fallback surfaces (main floor `RGB 121, 199, 149`), and their scene plaques show **SMOOTH PLASTIC APPROX**. Each shadow layer is non-collidable and does not cast shadows; its role and transparency are recorded on the part.

### Cartoon simulator comparisons

After syncing the Forest module, coordinator, and navigation script, start a fresh Studio Play/Start Server session. Select the exact labels below from **DEV GALLERY**. `CartoonTest1`–`CartoonTest4` add to Forest A/B and the existing Test1-Test4 contrast entries.

| Entry | Treatment |
| --- | --- |
| **TEST 1 · SOFT CARTOON GRASS** | SmoothPlastic base `RGB(77, 173, 76)` with 20 overlapping flat ellipsoid lobes in `RGB(89, 185, 82)` and `RGB(68, 158, 67)`, at 0.82 scale. Existing oak leaves stay unchanged. |
| **TEST 2 · BOLD SIMULATOR GRASS** | Same base with 20 larger, bolder lobes in `RGB(107, 202, 83)` and `RGB(55, 145, 63)`, at 1.15 scale. Existing oak leaves stay unchanged. |
| **TEST 3 · BOLD GRASS + RICHER LEAVES** | Same ground as Test 2. Oak palette: leaf `RGB(48, 145, 48)`, highlight `RGB(171, 229, 70)`, shadow `RGB(35, 109, 58)`; per-part brightness multiplier is clamped to ±2% of its source value. |
| **TEST 4 · FULL CARTOON SIMULATOR** | Same ground and leaves as Test 3, plus 10 non-collidable flattened-cylinder shadows in `RGB(35, 105, 48)`: five pairs sized 15x10 outer and 11x7 inner (studs), with transparencies 0.90 and 0.76, respectively. |

All four reuse five Starter Oaks with seeds `418031, 418047, 418063, 418079, 418097` and matched tree sizes, positions, paths, and supporting scenery. The grass is a procedural bright-green approximation made from SmoothPlastic and scene geometry; it loads no external texture and does not reproduce the temporary GrassSample_07 exactly. Lighting is shared across all four comparisons.

The catalog reads source-controlled model templates, preferring `ServerStorage.DevToolboxAssets.ForestToolboxAssets` and falling back to `ServerStorage.DevToolboxAssets`. The tracked source model is `src/ServerStorage/DevToolboxAssets/ForestToolboxAssets.rbxm`. The comparison compositions also use `src/ServerStorage/DevToolboxAssets/ApprovedMesaReference.rbxm`, an approved World 1 mixed mesa junction reference with 49 visual BaseParts and no scripts or invisible collision pieces. Its preview is scaled down and made non-collidable. It does not load Creator Store IDs at runtime; missing templates are labeled unavailable. The module and its coordinator/navigation entry are guarded by `RunService:IsStudio()`. To inspect it, sync with Rojo, start a Studio Play/Start Server session, open **DEV GALLERY**, then select **FOREST ASSET CATALOG**. Stop the session before editing the .rbxm; save the template and restart the Studio server to rebuild the previews. MeshId, TextureID, and SurfaceAppearance dependencies inside a template may still require separate asset permission and availability in Studio.

## Shared ownership and navigation

The coordinator owns `Workspace.DevTreeGallery`, tagged `DevGalleryOwner = "Coordinator"`, including its direct `GalleryFloor` and `GallerySpawn`. Lab builders should wait for that ready shell, create or replace only their own named child, and never replace the shared root or another builder's content. Publish a lab's ready flag and teleport CFrame only after its complete target is attached. TreeLab uses `DevGalleryOwner = "TreeLab"`; archived studies use `DevGalleryOwner = "TreeStudiesArchive"` under `ArchiveLab`. Terrain publishes its own Mesa version and teleport attributes on the shared root.

`DevGalleryNavigation.client.luau` is the unified navigation UI. It reads the coordinator's registry, streams toward a selected ready target, and provides **Return to World** using the saved pre-gallery position or a non-gallery SpawnLocation/BaseGround fallback. The former standalone teleport LocalScripts have been removed. These are source contracts; navigation has not been verified in a Studio session for this guide, and no Studio playtest is claimed.

For a new lab, add its `Labs` switch, Studio/config gate, uniquely owned subtree, and post-build readiness/destination attributes; then teach the coordinator registry which target and destination to expose. For archived tree studies, keep the archive under `ArchiveLab` and gate it with both `Labs.Archive` and `Archive.TreeStudies`. Forest A/B destinations publish after both variation models are attached. The catalog publishes its own destination only after its Atomic target, walkable floor, and metadata are ready. The unified UI streams to the selected landing and focus point.
