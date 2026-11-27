local statDatabase = require(script.Parent.StatsDatabase)
local StatAggregator = {}
local playerProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local WeaponProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)
local Substats = require(game.ServerScriptService.WeaponSubstatRules)

local BASE_ATTACK = 5

function StatAggregator.CollectSources(player)
	local sources = {
		{
			SourceType = "Base",
			SourceId = "Base",
			Stats = {
				CritChance = 5,
				Attack = BASE_ATTACK,
				CritDamage = 200 
			}
		}
	}
	local playerProfile = playerProfileCache.GetProfile(player)
	-- Equipped weapon
	local runtime = playerProfile.Data.Runtime
	local weaponUID = runtime.EquippedWeaponUID or playerProfile.Data.Equipped.Weapon
	local weapon = weaponUID and playerProfile.Data.Runtime.Weapon[weaponUID]
	if weapon then
		table.insert(sources, {
			SourceType = "Weapon",
			SourceId = weaponUID,
			Stats = weapon.ItemStats or {}
		})
		table.insert(sources, {
			SourceType = "Weapon",
			SourceId = weaponUID .. "SubStats",
			Stats = weapon.ItemSubstat or {}
		})
		-- Add level/rarity growth as a separate derived stat source.
		-- The original forged ItemStats.Attack must never be rewritten here.
		local bonusAttack = WeaponProgressionRules.DerivedAttackBonus(weapon, BASE_ATTACK)
		if bonusAttack > 0 then
			table.insert(sources, {
				SourceType = "WeaponProgression",
				SourceId = weaponUID .. "Progression",
				Stats = { Attack = bonusAttack },
			})
		end
	end

	-- Active pets
	for _, petUID in ipairs(playerProfile.Data.ActivePets or {}) do
		table.insert(sources, {
			SourceType = "Pet",
			SourceId = petUID,
			Stats = playerProfile.Data.Runtime.Pet[petUID].ItemStats
		})
	end

	-- Buffs (runtime)
	for _, buff in ipairs(playerProfile.Data.ActiveBuffs or {}) do
		table.insert(sources, buff)
	end

	return sources
end

function StatAggregator.Aggregate(player)
	local final = {}
	local multipliers = {}
	local source = StatAggregator.CollectSources(player)
	for _, source in ipairs(source) do
		for stat, value in pairs(source.Stats) do
			local def = statDatabase[stat]
			if not def then continue end

			if def.StackType == "Add" then
				final[stat] = (final[stat] or 0) + value

			elseif def.StackType == "Mult" then
				multipliers[stat] = (multipliers[stat] or 1) * (1 + value)

			elseif def.StackType == "Special" then
				-- handled separately
			end
		end
	end

	-- Apply multipliers
	for stat, mult in pairs(multipliers) do
		final[stat] = (final[stat] or 0) * mult
	end
	local runtime=playerProfileCache.GetProfile(player).Data.Runtime
	local equipped=runtime.EquippedWeaponUID and runtime.Weapon[runtime.EquippedWeaponUID]
	player:SetAttribute("WeaponPassiveHaste", Substats.Totals(equipped).Haste or 0)
	runtime.FinalStats = final
	return final
end

return StatAggregator
