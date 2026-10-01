local economyManager = {}
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local economyUpdated = game.ReplicatedStorage.Economy.EconomyUpdated

function economyManager.Add(player: Player, currency: string, amount: number)
	-- add currency to player
	local playerData = profileCache.GetData(player)
	playerData[currency] = playerData[currency] + amount
	economyUpdated:FireClient(player, currency, playerData[currency])
end

return economyManager 

