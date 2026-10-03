# Economy and combat design debt

## Prototype notice

**Every numerical value introduced for the first economy loop is a PROTOTYPE
PLACEHOLDER, NOT FINAL BALANCE.** This includes tree HP, size ranges and
probabilities, log weights, sale values, axe power, shop prices, and bag
capacity prices. The goal is to validate a readable chop → log → sell → upgrade
loop, not to lock the eventual economy or combat design.

## Current prototype contracts

- A normal farm tree creates one unique log record. One log uses one inventory
  slot regardless of kilograms.
- Forest 1 Oak and Forest 2 Ironwood carry prototype `BaseWeightKg` and
  `ValuePerKg` definition data. Sale value is currently `WeightKg * ValuePerKg`,
  rounded by the authoritative server.
- A spawned normal tree rolls an authoritative, lifetime-stable size. The chosen
  simple distribution is normally uniform in `0.70–1.30`, with a small chance
  for a uniform `0.45–1.70` extreme range. A respawn may roll a new size.
- Prototype formulas are `HP = BaseHP * SizeScale^1.4` and
  `WeightKg = BaseWeightKg * SizeScale^2`. Kilograms are intentionally readable
  game values, not real-world forestry physics.
- Current normal axes are single-target. A neutral server-side
  `LumberjackStrength = 1` seam keeps equipment power separate from a future
  character/prestige multiplier.
- Barrier trees remain progression-only and do not yield ordinary sellable logs.
- Current prototype shop values are: Starter Hatchet 10 power (free), Copper
  Axe 16 (150 Coins), Iron Axe 26 (750), Steel Axe 42 (3,000), and Heavy
  Cleaver 68 (12,000). Capacity steps are 10 starting slots, then 15 (250
  Coins), 20 (1,000), 30 (4,000), and 40 (15,000). These numbers are all
  prototype placeholders.

## Tree size scaling

Still to design: species-specific ranges, a better spawn distribution, frequency
of tiny/giant extremes, the final relationship of visual scale to weight and HP,
and whether mutations can alter size independently. The present visual, HP, and
weight rules are deliberately easy to replace.

## Bark hardness

Future trees may have Bark/hardness and axes may have Sharpness. They could
define minimum effective damage, damage reduction, effectiveness thresholds, or
forest progression. No formula has been selected and this prototype must not
bake one into the damage pipeline.

## Regeneration

Barrier and special-tree regeneration is unresolved: rate, post-hit delay,
whether ordinary trees regenerate, multiplayer behaviour, and whether a
regenerating high-HP barrier should create a DPS check. It is not implemented.

## Axe size and controlled multi-tree hits

The future fantasy may be a rare large log becoming a visually larger crafted
axe, possibly with deliberately controlled extra reach or multi-chop. That must
not translate a freak giant log directly into an unlimited hitbox. A later pass
must choose caps/diminishing returns, discrete tiers, target limits, arcs/cones,
and forest-density rules. Current shop axes stay single-target; visuals and AoE
must stay independently tunable.

## Lumberjack Strength and prestige

`Axe Power` is equipment progression; `Lumberjack Strength` is reserved for
future character/prestige progression. The multiplier seam defaults to one.
There is no Prestige system, rank UI, or final damage formula in this milestone.

## Species economy

Oak/Ironwood values, weights, XP/progression value, crafting relevance, old
species usefulness, and Grove relevance are all temporary. Future changes may
add quality, seed drops, mutation tables, Bark, regeneration, or crafting-drop
data to definitions without changing the unique-log identity model.

## Inventory economy

The selected rule is **one unique log equals one inventory slot**: a light and a
giant log both consume one slot. This preserves the excitement of large logs but
will need a later decision for storage, warehouses, Grove use, crafting,
auto-sell, favouriting, and collections. Stored logs are data records, never
Roblox Instances; physical models exist only while held or dropped.

## Multiplayer rewards and barriers

Shared normal-tree rewards use effective server-recorded contribution rather
than last-hit ownership; overkill cannot create extra credit. Because one tree
currently yields exactly one unique log, the full log goes to the highest
effective contributor; a UserId tie break makes the result deterministic. This
is an intentional minimal prototype policy that must be reviewed before a
public multiplayer economy test. Barrier materials/crafting drops remain a
future decision and are expressly outside normal log rewards.

## Explicitly deferred systems

Mutations, seeds, Personal Grove growth/buffs, processing, sawmills, crafting,
crafted axes, giant-axe AoE, Sharpness, Bark, regeneration, AFK farming,
Prestige, Lumberjack ranks, Forest 3, pets, rebirth currencies, and trading are
all out of scope for this prototype.
