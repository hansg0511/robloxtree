local PlotManager = {}

local Workspace = game:GetService("Workspace")
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)

local PLOT_COUNT = 6
local PLOT_SIZE = Vector3.new(42, 0.05, 42)
local GROVE_MARGIN = 6
local PLOT_COLOR = Color3.fromRGB(118, 160, 98)

-- A U-shaped village leaves the front open for the future base-to-forest route.
-- These are plot boundaries only; trees are not tied to markers inside them.
local PLOT_CENTERS = {
	Vector3.new(-70, 0, -50),
	Vector3.new(-70, 0, 0),
	Vector3.new(-24, 0, 48),
	Vector3.new(24, 0, 48),
	Vector3.new(70, 0, 0),
	Vector3.new(70, 0, -50),
}

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
	part.Material = Enum.Material.Plastic
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

	local center = PLOT_CENTERS[plotId + 1]
	-- This paper-thin colored surface sits flush with BaseGround; it is deliberately
	-- not a raised platform.
	local base = makePart("Base", PLOT_SIZE, CFrame.new(center.X, -0.475, center.Z), PLOT_COLOR, model)
	base.CanCollide = false
	model.PrimaryPart = base

	local groveArea = makePart(
		"GroveArea",
		Vector3.new(PLOT_SIZE.X - GROVE_MARGIN * 2, 1, PLOT_SIZE.Z - GROVE_MARGIN * 2),
		CFrame.new(center),
		Color3.new(),
		model
	)
	groveArea.Transparency = 1
	groveArea.CanCollide = false
	groveArea.CanTouch = false
	groveArea.CanQuery = false
	groveArea:SetAttribute("Purpose", "Open planting bounds; future trees choose their own positions")

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

function PlotManager.GetGroveArea(player)
	local plot = PlotManager.playerPlotMap[player]
	if not plot then return nil end
	return plot.PlotModel.GroveArea
end

local function containsPosition(area, position)
	local localPosition = area.CFrame:PointToObjectSpace(position)
	local halfSize = area.Size * 0.5
	return math.abs(localPosition.X) <= halfSize.X and math.abs(localPosition.Z) <= halfSize.Z
end

function PlotManager.GetPreviewTreeCFrame(player)
	local area = PlotManager.GetGroveArea(player)
	if not area then return nil end
	-- A temporary smoke-test tree gets a fresh open-area position. Real planting
	-- will supply a stored world position rather than inheriting a fixed slot.
	local random = Random.new()
	local halfSize = area.Size * 0.5
	return area.CFrame * CFrame.new(
		random:NextNumber(-halfSize.X + 7, halfSize.X - 7),
		0,
		random:NextNumber(-halfSize.Z + 7, halfSize.Z - 7)
	)
end

function PlotManager.CreateTree(player, treeCFrame)
	local plot = PlotManager.playerPlotMap[player]
	if not plot then return nil end
	local area = plot.PlotModel:FindFirstChild("GroveArea")
	if not area then return nil end
	if typeof(treeCFrame) == "Vector3" then treeCFrame = CFrame.new(treeCFrame) end
	if typeof(treeCFrame) ~= "CFrame" or not containsPosition(area, treeCFrame.Position) then return nil end

	local tree = TreeObject.new({
		DefinitionId = "BasicGrove",
		Parent = plot.PlotModel,
		CFrame = treeCFrame,
		OwnerUserId = player.UserId,
	})
	PlotManager.playerTrees[player] = PlotManager.playerTrees[player] or {}
	table.insert(PlotManager.playerTrees[player], tree)
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
