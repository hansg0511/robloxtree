local DataStoreService = game:GetService("DataStoreService")
local playerDataStore = DataStoreService:GetDataStore("PlayerData")
local bindableEvent = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent

local itemGen = require(game.ServerStorage.Items.ItemGeneratorModule)

PlotManager = require(game.ServerStorage.PlotManager)

PlotManager.buildPlots()

--local TreeService = require(script.Parent:WaitForChild("TreeService"))
--TreeService:GenerateTree("Oak", CFrame.new(75,1,0))
----TreeService:GenerateTree("HugeOak", CFrame.new(0,1,0))

---- Might need to tweak the ratio here, it LGTM now but up to you
--TreeService:GenerateTree("VariableOak", CFrame.new(-75,1,0), {
--	Height = 2.5,
--	BranchDensity = 2.2,
--	BranchThickness = 1.3
--})

bindableEvent.Event:Connect(function(player)

	PlotManager.assignPlot(player)
	PlotManager.spawnPassivePlots(player,0)
	PlotManager.spawnPassivePlots(player,1)
	PlotManager.spawnPassivePlots(player,2)
	PlotManager.spawnPassivePlots(player,3)
	PlotManager.spawnPassivePlots(player,4)
	local tree = PlotManager.CreateTree(player)
	tree:Spawn()
	local passiveTree = PlotManager.CreateTree(player, 0)
	passiveTree:Spawn()
	--PlotManager.surroundPlotWithBushes(plot, game.ServerStorage.Bushes, 20, 20)
	print(itemGen.GenerateItem(101),"This the item")

end)
