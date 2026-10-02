local Players = game:GetService("Players")
local PlotManager = require(game.ServerStorage.PlotManager)
local profileLoaded = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent

PlotManager.buildPlots()

local function onProfileLoaded(player)
	if PlotManager.playerPlotMap[player] then return end
	local plot = PlotManager.assignPlot(player)
	if not plot then
		warn("No free plot for", player.Name)
		return
	end

	-- One temporary tree keeps the chop path testable. It deliberately uses a
	-- free position within the GroveArea instead of a fixed planting marker.
	local tree = PlotManager.CreateTree(player, PlotManager.GetPreviewTreeCFrame(player))
	if tree then tree:Spawn() end
end

profileLoaded.Event:Connect(onProfileLoaded)
Players.PlayerRemoving:Connect(PlotManager.CleanUp)

for _, player in ipairs(Players:GetPlayers()) do
	if player:GetAttribute("ProfileReady") then
		onProfileLoaded(player)
	end
end
