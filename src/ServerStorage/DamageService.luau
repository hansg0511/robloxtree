local DamageService = {}

local RNG = require(game.ServerStorage.Items.RNGModule)

-- Ordered list of damage modifiers
DamageService.Modifiers = {}

function DamageService.RegisterModifier(modifier)
	table.insert(DamageService.Modifiers, modifier)
end


function DamageService.Calculate(ctx)
	-- 1. Initialize
	ctx.Damage = ctx.BaseDamage :: number

	-- 2. Roll crit (unless forced)
	if ctx.CritChance > 0 then
		ctx.IsCrit = math.random() < ctx.CritChance/100
	end

	-- 3. Apply crit
	if ctx.IsCrit then
		ctx.Damage *= ctx.CritMultiplier/100
	end

	-- 4. Apply registered modifiers
	for _, modifier in ipairs(DamageService.Modifiers) do
		modifier(ctx)
	end

	-- 5. Final clamp / rounding
	ctx.Damage = math.max(0, math.floor(ctx.Damage))

	return ctx.Damage, ctx
end

function DamageService:createDamageContext(player, tree, weaponUID, finalStats, weaponState)
	return {
		Player = player,
		Target = tree,
		Weapon = weaponUID,

		BaseDamage = finalStats.Attack,
		Damage = finalStats.Attack,

		CritChance = finalStats.CritChance,
		CritMultiplier = finalStats.CritDamage,
		IsCrit = false,

		Tags = {},
		Metadata = {
			WeaponState = weaponState, -- click counters etc
		},
	}
end

return DamageService
