-- Small, static foliage clusters that soften the hub and Forest 1 edges.
-- Every block is visual-only so foliage cannot affect movement or raycasts.
local World1Dressing = {}

local PALETTES = {
	Fern = {
		Base = Color3.fromRGB(62, 112, 61),
		Leaf = Color3.fromRGB(78, 139, 70),
		Light = Color3.fromRGB(113, 163, 81),
	},
	Moss = {
		Base = Color3.fromRGB(69, 117, 65),
		Leaf = Color3.fromRGB(92, 145, 76),
		Light = Color3.fromRGB(133, 171, 88),
	},
	Meadow = {
		Base = Color3.fromRGB(72, 119, 65),
		Leaf = Color3.fromRGB(100, 151, 76),
		Light = Color3.fromRGB(146, 180, 93),
	},
}

-- Offsets are relative to the ground top at each cluster's position. The
-- overlapping low cubes make distinct layered silhouettes without tall stems.
local SHAPES = {
	Broad = {
		{ Name = "LowBody", Size = Vector3.new(4.8, 1.3, 3.3), Offset = Vector3.new(0, 0.65, 0), Color = "Base" },
		{ Name = "WestLobe", Size = Vector3.new(2.8, 1.45, 2.5), Offset = Vector3.new(-1.05, 1.08, 0.18), Color = "Leaf" },
		{ Name = "EastLobe", Size = Vector3.new(2.5, 1.25, 2.25), Offset = Vector3.new(1.2, 0.95, -0.12), Color = "Leaf" },
		{ Name = "Crown", Size = Vector3.new(1.85, 0.78, 1.8), Offset = Vector3.new(-0.72, 1.85, -0.48), Color = "Light" },
	},
	Stepped = {
		{ Name = "LowBody", Size = Vector3.new(4.2, 1.2, 3.2), Offset = Vector3.new(0, 0.6, 0), Color = "Base" },
		{ Name = "MiddleTier", Size = Vector3.new(3.0, 1.2, 2.55), Offset = Vector3.new(-0.32, 1.32, 0.12), Color = "Leaf" },
		{ Name = "SideLobe", Size = Vector3.new(2.0, 1.05, 2.0), Offset = Vector3.new(1.32, 0.95, 0.34), Color = "Leaf" },
		{ Name = "TopBlock", Size = Vector3.new(1.75, 0.85, 1.7), Offset = Vector3.new(-0.82, 2.05, -0.42), Color = "Light" },
	},
	Twin = {
		{ Name = "LowBody", Size = Vector3.new(3.7, 1.15, 3.0), Offset = Vector3.new(0, 0.575, 0), Color = "Base" },
		{ Name = "WestLobe", Size = Vector3.new(2.35, 1.35, 2.2), Offset = Vector3.new(-1.12, 1.0, 0.18), Color = "Leaf" },
		{ Name = "EastLobe", Size = Vector3.new(2.45, 1.2, 2.25), Offset = Vector3.new(1.08, 0.92, -0.12), Color = "Leaf" },
		{ Name = "Crown", Size = Vector3.new(1.65, 0.72, 1.65), Offset = Vector3.new(0.08, 1.75, -0.42), Color = "Light" },
	},
}

-- Coordinates are deliberate gaps between existing gameplay objects. Forest1
-- stays clear of the x=-68 corridor, its entrance/sign, all tree chop areas,
-- and the Forest2 barrier. The hub placements follow the plaza margins and
-- leave the plot lane, fork, and station interaction volumes open.
local CLUSTERS = {
	Hub = {
		{ Name = "HubSouthwest", Position = Vector3.new(-46, -0.44, 75), Shape = "Broad", Palette = "Moss", Yaw = -12, Scale = 1.0 },
		{ Name = "HubWestMid", Position = Vector3.new(-49, -0.44, 99), Shape = "Stepped", Palette = "Fern", Yaw = 8, Scale = 0.92 },
		{ Name = "HubNorthwest", Position = Vector3.new(-48, -0.44, 119), Shape = "Twin", Palette = "Meadow", Yaw = -18, Scale = 0.9 },
		{ Name = "HubSoutheast", Position = Vector3.new(46, -0.44, 75), Shape = "Stepped", Palette = "Meadow", Yaw = 16, Scale = 1.08 },
		{ Name = "HubEastLow", Position = Vector3.new(48, -0.44, 88), Shape = "Broad", Palette = "Fern", Yaw = -9, Scale = 0.86 },
	},
	Forest1 = {
		{ Name = "Forest1Southwest", Position = Vector3.new(-82, -0.5, 190), Shape = "Broad", Palette = "Fern", Yaw = -14, Scale = 0.92 },
		{ Name = "Forest1Southeast", Position = Vector3.new(-53, -0.5, 190), Shape = "Stepped", Palette = "Moss", Yaw = 11, Scale = 0.96 },
		{ Name = "Forest1Midwest", Position = Vector3.new(-82, -0.5, 224), Shape = "Twin", Palette = "Meadow", Yaw = 18, Scale = 0.9 },
		{ Name = "Forest1Mideast", Position = Vector3.new(-53, -0.5, 222), Shape = "Broad", Palette = "Moss", Yaw = -7, Scale = 0.9 },
		{ Name = "Forest1Northwest", Position = Vector3.new(-81, -0.5, 249), Shape = "Stepped", Palette = "Fern", Yaw = -16, Scale = 0.9 },
		{ Name = "Forest1Northeast", Position = Vector3.new(-53, -0.5, 248), Shape = "Twin", Palette = "Meadow", Yaw = 13, Scale = 0.94 },
	},
}

local function createCluster(parent, configuration)
	local shape = SHAPES[configuration.Shape]
	local palette = PALETTES[configuration.Palette]
	if not shape or not palette then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = configuration.Name
	model:SetAttribute("WorldLayoutOwned", true)
	model:SetAttribute("WorldDecoration", "ShrubCluster")
	model.Parent = parent

	local clusterFrame = CFrame.new(configuration.Position)
		* CFrame.Angles(0, math.rad(configuration.Yaw or 0), 0)
	local scale = configuration.Scale or 1
	for _, blockConfiguration in ipairs(shape) do
		local block = Instance.new("Part")
		block.Name = blockConfiguration.Name
		block.Size = blockConfiguration.Size * scale
		block.CFrame = clusterFrame * CFrame.new(blockConfiguration.Offset * scale)
		block.Anchored = true
		block.CanCollide = false
		block.CanTouch = false
		block.CanQuery = false
		block.CastShadow = true
		block.Color = palette[blockConfiguration.Color]
		block.Material = Enum.Material.SmoothPlastic
		block.TopSurface = Enum.SurfaceType.Smooth
		block.BottomSurface = Enum.SurfaceType.Smooth
		block:SetAttribute("WorldLayoutOwned", true)
		block:SetAttribute("WorldDecoration", "ShrubBlock")
		block.Parent = model
	end

	return model
end

local function createGroup(parent, name, clusters)
	local group = Instance.new("Folder")
	group.Name = name
	group:SetAttribute("WorldLayoutOwned", true)
	group.Parent = parent

	for _, clusterConfiguration in ipairs(clusters) do
		createCluster(group, clusterConfiguration)
	end
end

function World1Dressing.Create(parent)
	if not parent then
		return nil
	end

	local dressing = Instance.new("Folder")
	dressing.Name = "World1Dressing"
	dressing:SetAttribute("WorldLayoutOwned", true)
	dressing.Parent = parent

	createGroup(dressing, "HubShrubs", CLUSTERS.Hub)
	createGroup(dressing, "Forest1Shrubs", CLUSTERS.Forest1)
	return dressing
end

return World1Dressing
