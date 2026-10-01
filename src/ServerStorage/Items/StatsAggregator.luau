local statDatabase = require(script.Parent.StatsDatabase)
local StatAggregator = {}
local playerProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)

function StatAggregator.CollectSources(player)
	local sources = {
		{
			SourceType = "Base",
			SourceId = "Base",
			Stats = {
				CritChance = 5,
				Attack = 5,
				CritDamage = 200 
			}
		}
	}
	local playerProfile = playerProfileCache.GetProfile(player)
	-- Equipped weapon
	local weaponUID = playerProfile.Data.Equipped.Weapon
	if weaponUID then
		table.insert(sources, {
			SourceType = "Weapon",
			SourceId = weaponUID,
			Stats = playerProfile.Data.Runtime.Weapon[weaponUID].ItemStats
		})
		table.insert(sources, {
			SourceType = "Weapon",
			SourceId = weaponUID .. "SubStats",
			Stats = playerProfile.Data.Runtime.Weapon[weaponUID].ItemSubstat
		})
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
	playerProfileCache.GetProfile(player).Data.Runtime.FinalStats = final
	return final
end

return StatAggregator
