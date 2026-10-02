local Players = game:GetService("Players")
local PlotManager = require(game.ServerStorage.PlotManager)
local profileLoaded = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent

PlotManager.buildPlots()

local function onProfileLoaded(player)
	local plot = PlotManager.assignPlot(player)
	if not plot then
		warn("No free plot for", player.Name)
		return
	end

	-- One temporary Grove tree keeps the existing chop path testable.
	-- The remaining slots are stable placeholders for future growing rules.
	local tree = PlotManager.CreateTree(player, 1)
	if tree then tree:Spawn() end
end

profileLoaded.Event:Connect(onProfileLoaded)
Players.PlayerRemoving:Connect(PlotManager.CleanUp)

for _, player in ipairs(Players:GetPlayers()) do
	if player:GetAttribute("ProfileReady") then
		onProfileLoaded(player)
	end
end
