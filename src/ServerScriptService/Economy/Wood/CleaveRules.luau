-- Compatibility shim for the initial Cleave prototype and older smoke tests.
-- New code should require ServerScriptService.WeaponEffects.Cleave instead.
-- Cleave behavior no longer knows the source of the effect.
return require(game.ServerScriptService.WeaponEffects.Cleave)
