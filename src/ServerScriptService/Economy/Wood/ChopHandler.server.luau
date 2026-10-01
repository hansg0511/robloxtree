local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChopEvent = ReplicatedStorage.Chop.ChopEvent
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local economyManager = require(game.ServerScriptService.Economy.EconomyManager)
local plotManager = require(game.ServerStorage.PlotManager)
local treeObj = require(game.ServerScriptService.Trees.TreeObject)

local statsAggregator = require(game.ServerStorage.Items.StatsAggregator)
local damageService = require(game.ServerStorage.DamageService)


ChopEvent.OnServerEvent:Connect(function(player)
	local tree = treeObj.ActiveTreeByPlayer[player]
	local profile = profileCache.GetProfile(player)
	local weaponUID = profile.Data.Equipped
	local finalStats = profileCache.GetProfile(player).Data.Runtime.FinalStats
	if tree then
		local damage, context = damageService.Calculate(damageService:createDamageContext(player, tree, weaponUID, finalStats))
		--print(finalStats)
		--damage = 10
		tree:TakeDamage(context, player)
		--print("Tree took " .. damage .. " dmg, left with " .. tree.HP .. " HP")
	end
end)

