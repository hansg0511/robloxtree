# Weapon effects architecture — prototype contract

**Status:** Implemented as a small **Studio-only** server-side effects framework on `dev/gameplay-prototype`. This is intentionally **not** an all-purpose ability system or a final design decision about how effects are obtained.

## Why this exists

The old Cleave implementation inspected `ExperimentalClass == "Battlehammer"` inside Cleave's damage/targeting logic. That confounded **who grants an effect** with **what an effect does**.

Now they are separate:

- **Grant policy** (for the current prototype): `ExperimentalForgeRules.Roll` and `ShopHandler.server.luau`. The Forge currently grants Cleave only to newly crafted Battlehammers. This is **temporary**, not a permanent rarity/mutation rule.
- **Weapon storage:** `WeaponData.Effects` is an array of named effect descriptors and independently rolled parameter values. These are server-generated, persisted in the unique weapon record and projected through a server-validated equipment snapshot.
- **Event dispatch:** `ServerScriptService/WeaponEffects/Dispatcher.luau` maintains the allowlisted registry, validates effect IDs, trigger, and parameters, and dispatches **OnHit** after a successful primary hit.
- **Behavior:** `ServerScriptService/WeaponEffects/Cleave.luau` handles the bounding, secondary-target selection and secondary damage. It has **no dependency on weapon class or mutation source**.
- **Primary attack:** `ChopHandler.server.luau` still resolves exactly one primary target using server-owned reach and damage. It prepares effects before that hit and applies them only if the primary hit succeeds. Secondary effects never call the dispatcher again.

## Example new weapon record

```lua
WeaponData = {
    ExperimentalClass = "Battlehammer",  -- class still defines base stats
    AttacksPerSecond = 0.8,              -- independent roll
    Reach = 1.3,                         -- independent roll

    Effects = {
        {
            Id = "Cleave",
            Trigger = "OnHit",
            Source = "WeaponClass",      -- origin metadata, NOT a permission
            Params = {
                Radius = 12.6,          -- independent forge roll
                DamageFraction = 0.36,  -- independent forge roll
            },
        },
    },
}
```

Nothing in `Cleave.Resolve`, `Cleave.Prepare`, or `Cleave.Apply` checks `ExperimentalClass` or `Source`. A **future mutation** could grant the same effect by changing `Source = "Mutation"`, without rewriting the attack system. This is verified with synthetic dispatcher tests, **not available as a real mutation recipe yet**.

## OnHit lifecycle

```text
Client ChopEvent (no target or ability arguments)
    -> server verifies equipped weapon, swing rate, forest progression
    -> server selects one primary wild tree and calculates normal hit
    -> Dispatcher.Prepare("OnHit", server-owned weapon data, context)
         -> validates each registered effect and prepares secondary targets
    -> apply normal primary tree:TakeDamage()
    -> if primary hit succeeded: Dispatcher.ApplyPrepared()
         -> effect validates that each target still exists and is eligible
         -> applies secondary damage through the existing Tree:TakeDamage()
         -> NO recursive effect dispatch
```

Preparing before the hit handles cases where the tree dies and leaves the active registry during its normal death process.

## How to add another effect

1. Add `ServerScriptService/WeaponEffects/NewEffect.luau` implementing `Id`, `Trigger`, `Resolve(params)`, `Prepare(params, context)`, and `Apply(prepared, context)`.
2. Register the module in the private `handlers` table in `Dispatcher.luau`. There is **no arbitrary executable module name from weapon records**.
3. Have a **server-owned grant policy** (forge, upgrade, mutation, etc.) add a descriptor to `WeaponData.Effects`. Only known, bounded parameters are accepted when executing and displaying effects.
4. Add tests for source independence, eligibility, lifecycle, thresholds and reasonable caps. The inventory already renders registered effects generically, including source, trigger and numeric parameters.

This doesn't dictate how players obtain an effect. As of now, **Cleave remains granted by Battlehammer class for playtesting only**. Nothing yet grants Cleave from Golden/Crystal mutations or skills.

## Compatibility and safety

- **Existing saved Battlehammers** with old `CleaveRadius` and `CleaveDamageFraction` but no `Effects` array still work through a read-only compatibility adapter, which is class-restricted so arbitrary old data doesn't grant Cleave. A new empty `Effects = {}` intentionally disables fallback.
- Only registered effect IDs and matching triggers are accepted. Invalid numbers are rejected, radius/damage are capped, duplicates are ignored for now, and at most eight effects are inspected. **Stacking rules are not designed yet.**
- All effect sources and params are taken from server-owned weapon records, not from user-supplied remote arguments. All secondary targets must pass tree ownership/forest/normal chop eligibility; Grove trees are excluded.
- The normal attack and published servers still function without the experimental effect path. Both preparation and execution are behind `RunService:IsStudio()`; this framework is not yet approved for production.
- The existing `Economy/Wood/CleaveRules.luau` path remains as a compatibility shim for older tests. New modules should use `WeaponEffects/Cleave.luau`.

## Validation

- Run `tests/ExperimentalCleaveRules.smoke.luau` to check pure Cleave geometry, damage and forge rolling.
- Run `tests/WeaponEffectsDispatcher.smoke.luau` to check dispatch, trigger filtering, mutation-vs-class origin independence, caps, duplicate protection, old-weapon compatibility and no-chain behavior.
- In Studio, craft a **new 20-log Battlehammer**. Its weapon inventory **WEAPON EFFECTS** section should show Cleave's `Source = WeaponClass`, `Trigger = OnHit`, radius and damage. Chop a nearby tree group. Ordinary axes and Daggers remain single-target.
- **GitHub source inspection is not a Roblox Studio runtime test.** UI rendering, persistence and multiplayer behavior must be validated in Play mode before any merge to production.
