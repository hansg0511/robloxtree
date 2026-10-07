local PlotManager = {}

local Workspace = game:GetService("Workspace")
local PlotConfiguration = require(game.ServerStorage.PlotConfiguration)

local PLOT_COUNT = PlotConfiguration.MAX_PLOTS
local PLOT_SIZE = PlotConfiguration.PLOT_SIZE
local GROVE_MARGIN = PlotConfiguration.GROVE_MARGIN
local PLOT_COLOR = PlotConfiguration.PLOT_COLOR
local PLOT_CENTERS = PlotConfiguration.PLOT_CENTERS
local GROVE_OWNER_LABEL_ANCHOR_NAME = "GroveOwnerLabelAnchor"
local GROVE_OWNER_LABEL_GUI_NAME = "GroveOwnerLabel"
local GROVE_OWNER_LABEL_HEIGHT = 112

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

local function getOrCreateTextLabel(parent, name)
	local label = parent:FindFirstChild(name)
	if label and not label:IsA("TextLabel") then
		label:Destroy()
		label = nil
	end
	if not label then
		label = Instance.new("TextLabel")
		label.Name = name
		label.Parent = parent
	end
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 245, 216)
	label.TextStrokeColor3 = Color3.fromRGB(35, 48, 31)
	label.TextStrokeTransparency = 0.15
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	return label
end

local function updateGroveOwnerLabel(plot, player)
	if not plot or plot.OwnerID.Value ~= player.UserId then return end

	local model = plot:FindFirstChild("PlotModel")
	local groveArea = model and model:FindFirstChild("GroveArea")
	if not model or not groveArea or not groveArea:IsA("BasePart") then return end

	local anchor = model:FindFirstChild(GROVE_OWNER_LABEL_ANCHOR_NAME)
	if anchor and not anchor:IsA("BasePart") then
		anchor:Destroy()
		anchor = nil
	end
	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = GROVE_OWNER_LABEL_ANCHOR_NAME
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Transparency = 1
		anchor.Parent = model
	end
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.CFrame = groveArea.CFrame * CFrame.new(0, GROVE_OWNER_LABEL_HEIGHT, -groveArea.Size.Z * 0.35)

	local billboard = anchor:FindFirstChild(GROVE_OWNER_LABEL_GUI_NAME)
	if billboard and not billboard:IsA("BillboardGui") then
		billboard:Destroy()
		billboard = nil
	end
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = GROVE_OWNER_LABEL_GUI_NAME
		billboard.Parent = anchor
	end
	billboard.Adornee = anchor
	billboard.Enabled = true
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 300
	billboard.Size = UDim2.fromOffset(320, 76)

	local title = getOrCreateTextLabel(billboard, "OwnerTitle")
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.new(1, 0, 0, 50)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 30
	title.Text = player.DisplayName .. "'s Grove"
	title.Visible = true

	local handle = getOrCreateTextLabel(billboard, "OwnerHandle")
	handle.Position = UDim2.fromOffset(0, 50)
	handle.Size = UDim2.new(1, 0, 0, 22)
	handle.Font = Enum.Font.GothamMedium
	handle.TextSize = 16
	handle.Text = if player.DisplayName ~= player.Name then "@" .. player.Name else ""
	handle.Visible = player.DisplayName ~= player.Name
end

local function removeGroveOwnerLabel(plot)
	local model = plot and plot:FindFirstChild("PlotModel")
	local anchor = model and model:FindFirstChild(GROVE_OWNER_LABEL_ANCHOR_NAME)
	if anchor then
		anchor:Destroy()
	end
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
	local existingPlot = PlotManager.playerPlotMap[player]
	if existingPlot then
		updateGroveOwnerLabel(existingPlot, player)
		return existingPlot
	end
	local container = PlotManager.buildPlots()
	for plotId = 0, PLOT_COUNT - 1 do
		local plot = container:FindFirstChild("Plot" .. plotId)
		if plot and not plot.Occupancy.Value then
			plot.Occupancy.Value = true
			plot.OwnerID.Value = player.UserId
			PlotManager.playerPlotMap[player] = plot
			player:SetAttribute("PlotNumber", plotId)
			updateGroveOwnerLabel(plot, player)
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
			removeGroveOwnerLabel(plot)
			plot.Occupancy.Value = false
			plot.OwnerID.Value = 0
		end
		player:SetAttribute("PlotNumber", nil)
	end
	PlotManager.playerPlotMap[player] = nil
end

return PlotManager
