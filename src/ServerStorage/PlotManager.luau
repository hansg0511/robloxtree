local PlotManager = {}

local Workspace = game:GetService("Workspace")
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)

local PLOT_COUNT = 6
local SLOT_COUNT = 5
local PLOT_SPACING = 36

PlotManager.playerPlotMap = {}
PlotManager.playerTrees = {}

local function getPlotContainer()
	local container = Workspace:FindFirstChild("PlayerPlots")
	if not container then
		container = Instance.new("Folder")
		container.Name = "PlayerPlots"
		container.Parent = Workspace
	end
	return container
end

local function makeValue(className, name, value, parent)
	local object = Instance.new(className)
	object.Name = name
	object.Value = value
	object.Parent = parent
	return object
end

local function makePart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makePlot(plotId)
	local plot = Instance.new("Folder")
	plot.Name = "Plot" .. plotId
	makeValue("IntValue", "PlotID", plotId, plot)
	makeValue("IntValue", "OwnerID", 0, plot)
	makeValue("BoolValue", "Occupancy", false, plot)

	local model = Instance.new("Model")
	model.Name = "PlotModel"
	model.Parent = plot

	local center = Vector3.new((plotId - (PLOT_COUNT - 1) / 2) * PLOT_SPACING, 0, 0)
	local base = makePart("Base", Vector3.new(30, 1, 30), CFrame.new(center), Color3.fromRGB(81, 192, 241), model)
	model.PrimaryPart = base

	local slots = Instance.new("Folder")
	slots.Name = "GroveSlots"
	slots.Parent = model
	for slotId = 1, SLOT_COUNT do
		local angle = (slotId - 1) * (2 * math.pi / SLOT_COUNT)
		local position = center + Vector3.new(math.cos(angle) * 9, 0.7, math.sin(angle) * 9)
		local slot = makePart("Slot" .. slotId, Vector3.new(5, 0.25, 5), CFrame.new(position), Color3.fromRGB(255, 208, 87), slots)
		slot:SetAttribute("SlotId", slotId)
	end

	return plot
end

function PlotManager.buildPlots()
	local container = getPlotContainer()
	for plotId = 0, PLOT_COUNT - 1 do
		local name = "Plot" .. plotId
		if not container:FindFirstChild(name) then
			local plot = makePlot(plotId)
			plot.Parent = container
		end
	end
	return container
end

function PlotManager.assignPlot(player)
	if PlotManager.playerPlotMap[player] then return PlotManager.playerPlotMap[player] end
	local container = PlotManager.buildPlots()
	for plotId = 0, PLOT_COUNT - 1 do
		local plot = container:FindFirstChild("Plot" .. plotId)
		if plot and not plot.Occupancy.Value then
			plot.Occupancy.Value = true
			plot.OwnerID.Value = player.UserId
			PlotManager.playerPlotMap[player] = plot
			player:SetAttribute("PlotNumber", plotId)
			return plot
		end
	end
	return nil
end

function PlotManager.GetGroveSlots(player)
	local plot = PlotManager.playerPlotMap[player]
	if not plot then return nil end
	return plot.PlotModel.GroveSlots
end

function PlotManager.CreateTree(player, slotId)
	local plot = PlotManager.playerPlotMap[player]
	if not plot then return nil end
	local slot = plot.PlotModel.GroveSlots:FindFirstChild("Slot" .. tostring(slotId))
	if not slot then return nil end

	local tree = TreeObject.new({
		DefinitionId = "BasicGrove",
		Parent = plot.PlotModel,
		CFrame = slot.CFrame * CFrame.new(0, 0.15, 0),
		OwnerUserId = player.UserId,
	})
	PlotManager.playerTrees[player] = PlotManager.playerTrees[player] or {}
	PlotManager.playerTrees[player][slotId] = tree
	return tree
end

function PlotManager.CleanUp(player)
	for _, tree in pairs(PlotManager.playerTrees[player] or {}) do
		tree:Destroy()
	end
	PlotManager.playerTrees[player] = nil

	local plot = PlotManager.playerPlotMap[player]
	if plot then
		plot.Occupancy.Value = false
		plot.OwnerID.Value = 0
		player:SetAttribute("PlotNumber", nil)
	end
	PlotManager.playerPlotMap[player] = nil
end

return PlotManager
