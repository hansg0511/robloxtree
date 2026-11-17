# Grove growth-stage silhouettes — prototype playtest

Stacked feature branch: `feature/grove-distinct-growth-phases-prototype`
Base branch: `feature/grove-cinematic-harvest-prototype`

**Status:** prototype visual models, not polished animation/art. Existing E-harvest cinematic and server-owned unique logs remain unchanged.

## What changed

Previously, the Grove simply scaled the full mature model down for "sapling" and "young" and up at maturity. That made growth look like a tree inflating.

Now each species has **four visually distinct growth silhouettes**:
- **Stump**: cut trunk/cut bamboo culms after harvesting; no foliage.
- **Sapling**: a single small shoot with just a few leaves (Oak foliage stays cubes/cuboids).
- **Young**: visibly taller trunk/branches and sparse leaf clusters; Bamboo grows a few stalks, Ironwood grows a more vertical crown.
- **Mature**: the existing full production model for that species, retaining its current size scale and E-to-harvest behavior.

Oak, Bamboo and Ironwood each have their own stage shape, not just a rescaled mature tree. Stage boundaries swap the model and briefly fade in the new one; **the tree does not continuously expand across the entire growth timer**. The existing planting preview also now uses a cuboid-leaf ghost with basic species-specific dimensions/colors.

### Unchanged rules

- Each Grove sapling permanently retains its UID, species, inherited mutations, genetic SizePotential and planted location.
- Each new growth cycle still chooses a fresh `CurrentSizeScale` bounded by its genetic size potential.
- Current prototype timing stays the same: **45 seconds from planting/harvest to maturity**, with a **5-second stump phase** after harvest. The young stage occupies the remainder after the ~25% sapling phase. A first-time planting starts as a sapling, not a stump.
- Only mature owner trees show the E Harvest prompt. The E cinematic, exact one-log grant, storage-full rejection, reward/provenance and subsequent regrowth are unchanged.
- Wild forest tree models/chopping remain unchanged.
- This deliberately does **not** add new effects, mutation-specific growth silhouettes, quality RNG, shop saplings or final art.

## Switch to the feature branch

```bash
git status
git fetch origin
git switch --track origin/feature/grove-distinct-growth-phases-prototype
rojo serve default.project.json
```

If a local tracking branch already exists:
```bash
git switch feature/grove-distinct-growth-phases-prototype
git pull --ff-only
```

In Studio, open `BrickWorldBase.rbxl` and connect Rojo to `default.project.json`.

## Studio playtest steps

1. Press **G** to plant a sapling. Check that the preview uses blocky leaves, and the **actual tree looks like a small seedling**, not a tiny mature oak.
2. Observe it advance to **young**: fewer leaves and smaller branches than the mature model, yet clearly bigger than the sapling. Note that the change is a new model fading in, not the old one stretching.
3. At ~45 seconds, confirm the **full species tree** replaces the young model and gets an E prompt. Oak foliage remains cube/cuboid only.
4. Press E and watch the existing cinematic fall/log reward. It should still generate exactly one unique log in protected storage.
5. After the fall, verify **stump → sapling → young → mature** at the same planting location and same Grove UID. A newly rolled size should affect the next cycle's appearance, not introduce a fake rescaling from a miniature mature tree.
6. Repeat for **Bamboo and Ironwood** as saplings become available. Check species identity: sprout vs small clump for Bamboo; slim juvenile vs tall mature Ironwood.
7. Confirm early growth stages have no E prompt and cannot be attacked. Test an observer: nearby players see changes, and an owner-only E prompt remains unavailable to others.
8. Verify **Grove state**, carry bag, processor and Forge still work. The new stage visuals should not modify physical log UIDs or harvest math.
9. Paste the full file `tests/GroveStageVisuals.smoke.luau` into Studio's **SERVER** Command Bar. It builds all 12 stage previews (4 × 3 species) without mutating player data, verifies relative heights, and checks stage metadata and cube foliage. Also run existing `tests/GroveGrowthRules.smoke.luau` and `tests/GroveHarvestPrompt.smoke.luau`.

## Polish to defer

See **`docs/PROTOTYPE_POLISH_BACKLOG.md`** for camera/audio/log-fly refinements, subtle growth transition VFX, silhouette art, mutation treatments, UI and controls. Keep these as follow-up polish, not blockers to progressing the first playable loop.

## Engineering and verification notes

- Stage display is **derived from already-persisted plant/growth timestamps**. No new persistent fields and no client-authoritative growth decisions are introduced.
- Stage transitions recreate their source-owned TreeObject model; the old model is only removed after a successful new spawn. Failed builds keep the previous appearance and retry on the next stage tick.
- Existing `Tree.BuildPreviewModel` now uses the same stage builders for Studio visual previews. Models are unregistered and do not modify `Tree.ActiveTrees`.
- No Roblox Studio execution was possible from the GitHub connector. These changes have been source-reviewed, but **must be verified in your running place before merging**.
- The prior branch still uses `ProfileStore.Mock`. Real persistence and full-storage handling remain release blockers.
