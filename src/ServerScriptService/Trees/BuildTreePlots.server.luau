local Players = game:GetService("Players")
local PlotManager = require(game.ServerStorage.PlotManager)
local GroveService = require(game.ServerScriptService.Grove.GroveService)
local profileLoaded = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent

PlotManager.buildPlots()

local function onProfileLoaded(player)
	if PlotManager.playerPlotMap[player] then return end
	local plot = PlotManager.assignPlot(player)
	if not plot then
		warn("No free plot for", player.Name)
		return
	end

	GroveService.RestorePlayer(player)
end

profileLoaded.Event:Connect(onProfileLoaded)
Players.PlayerRemoving:Connect(function(player)
	GroveService.CleanUp(player)
	PlotManager.CleanUp(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player:GetAttribute("ProfileReady") then
		onProfileLoaded(player)
	end
end
