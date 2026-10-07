local PlotManager = {}

local Workspace = game:GetService("Workspace")
local PlotConfiguration = require(game.ServerStorage.PlotConfiguration)

local PLOT_COUNT = PlotConfiguration.MAX_PLOTS
local PLOT_SIZE = PlotConfiguration.PLOT_SIZE
local GROVE_MARGIN = PlotConfiguration.GROVE_MARGIN
local PLOT_COLOR = PlotConfiguration.PLOT_COLOR
local PLOT_CENTERS = PlotConfiguration.PLOT_CENTERS

PlotManager.playerPlotMap = {}
PlotManager.MAX_PLOTS = PLOT_COUNT

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

function PlotManager.CleanUp(player)
	local plot = PlotManager.playerPlotMap[player]
	if plot then
		-- Never clear a plot that was reassigned after this player's old state.
		if plot.OwnerID.Value == player.UserId then
			plot.Occupancy.Value = false
			plot.OwnerID.Value = 0
		end
		player:SetAttribute("PlotNumber", nil)
	end
	PlotManager.playerPlotMap[player] = nil
end

return PlotManager
