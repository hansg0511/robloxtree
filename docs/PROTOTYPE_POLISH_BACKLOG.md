# Brick World — Prototype polish backlog

**Purpose:** Keep the game moving forward. A working prototype is not a polished or release-ready feature. Defer non-blocking presentation work until the end-to-end progression loop is proven.

This is the canonical list for *polish*, separate from new mechanics. Update it after each playtest.

## Grove — Harvest cinematic

- [ ] Camera angles: tune framing for small/huge Oak, Bamboo and Ironwood and different plot positions.
- [ ] Camera beats: smooth motion, fall impact timing, reward close-up; ensure the player always knows what to watch.
- [ ] Audio: stronger wind-up, clean cut, satisfying tree impact, premium log reveal; test loudness, spatialization and repetition.
- [ ] Physical log reward: adjust size, landing bounce, pause, homing arc and shrink timing for large/mutated logs.
- [ ] Mutation-specific visuals and rare-harvest celebration; decide when to show fuller vs shorter cinematic.
- [ ] Reward UI: readable typography, size/mutation emphasis, console/mobile layout, repeated-harvest clutter.
- [ ] Skip/camera-reset behavior, high latency, deaths, rapid E presses, multiple players and owner-only UI regression.
- [ ] Prompt placement and interaction UX for all tree sizes (including giant Ironwood).

## Grove — Growth appearance

- [x] **Prototype additive growth**: size-predictive stump → original forest tree's real trunk → branches → foliage, incrementally revealed, without full-model fade or miniature mature-tree model swaps. All three current Grove species use final forest models.
- [ ] Final art for each species and stage, distinctive tree species silhouettes, rare genetics and mutations.
- [ ] Polish the additive growth: more granular trunk-building pieces, satisfying branch/leaf pop, growth sound and particles without long waiting animations.
- [x] Fix Ironwood's out-of-order three trunk pieces and hide loose-looking Grove bark studs during growth (wild forest unchanged).
- [x] Fix Bamboo's oversized single stump and sequential cane pops; now uses five thin culms growing upward in synchronized segments.
- [ ] Refine Ironwood bark accents and smooth Bamboo's segmented growth after the core loop works.
- [ ] Timing indicators / clear maturation and ready-to-harvest indicators; tune 45-second prototype maturity.
- [ ] Planting ghost/preview consistency with real species and stage models.
- [ ] Visual performance and streaming with many Grove trees and observers.

## Other existing prototype systems

- [ ] Chop / falling-wood / pickup smoothness, collision, latency and feedback across low-end devices.
- [ ] Physical processor: log unloading arc, sounds, coin feedback and nearby-player visibility.
- [ ] Carry bag: back-stack silhouettes, inventory fullness, batch pickup polish and log-size readability.
- [ ] Protected storage: filtering, manual transfers, auto-keep education and capacity feedback.
- [ ] Forge: material-selection UX, weapon reveal/crafting feedback, recipe discoverability and material provenance display.
- [ ] World 1 visuals: floor/leaf contrast, bright cartoony palette, lighting, environment consistency.

## Gameplay/design still to build (not polish)

- Sapling sources and economics: shop, wild tree mutations, inheritance and rare drop policy.
- Weapon quality and size effects driven by individual unique logs; expanded progression.
- Balancing: growth/harvest rates, prices, rarity, storage size, shop costs and pacing.
- Further worlds and skills/passives only after the first-world loop is engaging.

## Before any public release (correctness blockers)

- Replace `ProfileStore.Mock` and validate persistent profiles and migrations.
- Resolve full protected-storage + overflow behavior without silently losing valuable items.
- Studio multiplayer, exploit/remote validation, respawn/rejoin, rollback and failure-injection tests.
- Performance, device controls, audio asset rights/availability and accessibility checks.

**Policy:** Unless a blocker prevents meaningful playtesting, prefer a small targeted improvement and move on. Record the rough edges here instead of broad refactoring.
