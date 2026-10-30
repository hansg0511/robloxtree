-- Source-owned coordinates for World 1's two hub-connected forest corridors.
-- ForestId values are consumed by existing tree interaction/progression services.
local function makeTreeRecords(definitionId, positions)
	local records = {}
	for _, position in ipairs(positions) do
		table.insert(records, {
			DefinitionId = definitionId,
			Position = position,
		})
	end
	return records
end

local starterForestTrees = makeTreeRecords("StarterForestTree", {
	-- Loose, alternating clusters leave a broad clear lane through Forest 1.
	Vector3.new(-112, -0.5, 160),
	Vector3.new(-93, -0.5, 174),
	Vector3.new(-116, -0.5, 201),
	Vector3.new(-94, -0.5, 213),
	Vector3.new(-113, -0.5, 237),
	Vector3.new(-92, -0.5, 239),
	Vector3.new(-42, -0.5, 164),
	Vector3.new(-23, -0.5, 182),
	Vector3.new(-44, -0.5, 206),
	Vector3.new(-22, -0.5, 223),
	Vector3.new(-40, -0.5, 239),
	Vector3.new(-25, -0.5, 199),
})
table.insert(starterForestTrees, {
	DefinitionId = "BambooClump",
	-- Retain the existing Forest 1 Bamboo gameplay tree beside the entrance.
	Position = Vector3.new(-17, -0.5, 157),
})

local forest2Trees = makeTreeRecords("Forest2Tree", {
	Vector3.new(-113, -0.5, 303),
	Vector3.new(-93, -0.5, 319),
	Vector3.new(-115, -0.5, 341),
	Vector3.new(-94, -0.5, 363),
	Vector3.new(-112, -0.5, 385),
	Vector3.new(-94, -0.5, 377),
	Vector3.new(-42, -0.5, 305),
	Vector3.new(-22, -0.5, 326),
	Vector3.new(-44, -0.5, 347),
	Vector3.new(-21, -0.5, 365),
	Vector3.new(-43, -0.5, 386),
	Vector3.new(-24, -0.5, 343),
})

local STATION_USE_DISTANCES = {
	AxeShopStation = 14,
	HomeEconomyStation = 14,
	ForgeStation = 14,
}

local WorldLayoutConfiguration = {
	-- Preserve the approved procedural Oak visual path for Forest 1.
	PROCEDURAL_STARTER_OAKS_ENABLED = true,

	ROOT_NAME = "SourceWorld",
	VERSION = 9,
	STATION_USE_DISTANCES = STATION_USE_DISTANCES,

	-- Surface steps stay small: support ground -0.56, forest/base -0.5,
	-- hub plaza -0.44, and readable paths -0.4.
	PATH_SURFACE_Y = -0.4,
	PATH_THICKNESS = 0.12,
	PATH_MATERIAL = Enum.Material.Slate,
	PATH_COLOR = Color3.fromRGB(157, 139, 108),
	PATH_SEGMENTS = {
		{
			Name = "PlotLane",
			Route = "GroveToHub",
			Width = 6,
			Start = Vector3.new(0, 0, -105),
			End = Vector3.new(0, 0, 119),
		},
		{
			Name = "HubApproach",
			Route = "HubToCorridorFork",
			Width = 18,
			Start = Vector3.new(0, 0, 119),
			End = Vector3.new(0, 0, 146),
		},
		{
			Name = "WestFork",
			Route = "HubToCorridorA",
			Width = 18,
			Start = Vector3.new(0, 0, 146),
			End = Vector3.new(-68, 0, 146),
		},
		{
			Name = "EastFork",
			Route = "HubToCorridorB",
			Width = 18,
			Start = Vector3.new(0, 0, 146),
			End = Vector3.new(68, 0, 146),
		},
		{
			Name = "CorridorA",
			Route = "Forests1To5",
			Width = 18,
			Start = Vector3.new(-68, 0, 146),
			End = Vector3.new(-68, 0, 824),
		},
		{
			Name = "CorridorB",
			Route = "Forests6To10",
			Width = 18,
			Start = Vector3.new(68, 0, 146),
			End = Vector3.new(68, 0, 824),
		},
	},

	GROUND_MATERIAL = Enum.Material.Grass,
	GROUND_COLOR = Color3.fromRGB(91, 132, 79),
	WORLD_GROUND = {
		-- This broad support slab sits 0.06 below the forest and BaseGround tops.
		Center = Vector3.new(0, -0.81, 483),
		Size = Vector3.new(280, 0.5, 742),
	},
	HUB_GROUND = {
		-- A shallow plaza rises 0.06 above BaseGround and stays below the path top.
		Center = Vector3.new(0, -0.69, 98),
		Size = Vector3.new(104, 0.5, 54),
		Color = Color3.fromRGB(132, 128, 113),
		Material = Enum.Material.Slate,
	},
	STYLE_SAMPLES = {
		Size = Vector3.new(22, 0.5, 18),
		Pads = {
			{ Name = "BrightSimulator", Style = "BrightSimulator", Center = Vector3.new(68, -0.75, 92) },
			{ Name = "ChunkyBrick", Style = "ChunkyBrick", Center = Vector3.new(94, -0.75, 92) },
			{ Name = "LightWhimsy", Style = "LightWhimsy", Center = Vector3.new(120, -0.75, 92) },
		},
	},

	-- Low timber rails frame the existing U of player plots and leave its front
	-- opening aligned with the original six-stud PlotLane.
	GROVE_FENCES = {
		SideX = 108,
		BackZ = -114,
		FrontZ = 82,
		StartZ = -114,
		EndZ = 82,
		FrontRuns = {
			{ StartX = -108, EndX = -28 },
			{ StartX = 28, EndX = 108 },
		},
	},

	-- Cliff runs frame two parallel dead-end corridors. The central ridge begins
	-- north of the shared hub fork and joins the north boundary, so Corridor B
	-- cannot be used to walk around the Forest 1 -> Forest 2 barrier.
	BOUNDARIES = {
		WestX = -140,
		EastX = 140,
		SpineX = 0,
		SideStartZ = 112,
		SideEndZ = 852,
		SpineStartZ = 160,
		SpineEndZ = 852,
		NorthZ = 852,
		WorldEdge = 140,
		WallHeight = 30,
		WallThickness = 12,
	},
	-- Existing BarrierTree stays the only progression gate. These flanks join its
	-- physical beam to both sides of Corridor A, so it cannot be walked around.
	BARRIER_FLANKS = {
		LeftStartX = -134,
		LeftEndX = -99,
		RightStartX = -37,
		RightEndX = -6,
		Depth = 8,
		Height = 30,
	},

	-- These remain the existing base stations and existing interaction distances.
	HOME_ECONOMY_STATION = {
		Position = Vector3.new(24, -0.4, 108),
	},
	AXE_SHOP_STATION = {
		Position = Vector3.new(-24, -0.4, 108),
	},
	FORGE_STATION = {
		Position = Vector3.new(40, -0.4, 108),
	},

	FORESTS = {
		{
			Name = "StarterForest",
			ForestId = "Forest1",
			Corridor = "A",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(-68, -0.75, 200),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(104, 151, 87),
			Sign = { Text = "FOREST 1", Position = Vector3.new(-95, 0, 184) },
			Trees = starterForestTrees,
		},
		{
			Name = "Forest2",
			ForestId = "Forest2",
			Corridor = "A",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(-68, -0.75, 340),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(91, 137, 82),
			Sign = { Text = "FOREST 2", Position = Vector3.new(-95, 0, 324) },
			Trees = forest2Trees,
		},
		{
			Name = "Forest3",
			ForestId = "Forest3",
			Status = "Blockout",
			Corridor = "A",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(-68, -0.75, 480),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(92, 134, 80),
			Sign = { Text = "FOREST 3 - BLOCKOUT", Position = Vector3.new(-95, 0, 464) },
			Trees = {},
		},
		{
			Name = "Forest4",
			ForestId = "Forest4",
			Status = "Blockout",
			Corridor = "A",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(-68, -0.75, 620),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(89, 131, 78),
			Sign = { Text = "FOREST 4 - BLOCKOUT", Position = Vector3.new(-95, 0, 604) },
			Trees = {},
		},
		{
			Name = "Forest5",
			ForestId = "Forest5",
			Status = "Blockout",
			Corridor = "A",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(-68, -0.75, 760),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(94, 136, 81),
			Sign = { Text = "FOREST 5 - BLOCKOUT", Position = Vector3.new(-95, 0, 744) },
			Trees = {},
		},
		{
			Name = "Forest6",
			ForestId = "Forest6",
			Status = "Blockout",
			Corridor = "B",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(68, -0.75, 200),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(91, 135, 81),
			Sign = { Text = "FOREST 6 - BLOCKOUT", Position = Vector3.new(95, 0, 184) },
			Trees = {},
		},
		{
			Name = "Forest7",
			ForestId = "Forest7",
			Status = "Blockout",
			Corridor = "B",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(68, -0.75, 340),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(90, 132, 78),
			Sign = { Text = "FOREST 7 - BLOCKOUT", Position = Vector3.new(95, 0, 324) },
			Trees = {},
		},
		{
			Name = "Forest8",
			ForestId = "Forest8",
			Status = "Blockout",
			Corridor = "B",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(68, -0.75, 480),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(92, 134, 79),
			Sign = { Text = "FOREST 8 - BLOCKOUT", Position = Vector3.new(95, 0, 464) },
			Trees = {},
		},
		{
			Name = "Forest9",
			ForestId = "Forest9",
			Status = "Blockout",
			Corridor = "B",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(68, -0.75, 620),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(89, 131, 77),
			Sign = { Text = "FOREST 9 - BLOCKOUT", Position = Vector3.new(95, 0, 604) },
			Trees = {},
		},
		{
			Name = "Forest10",
			ForestId = "Forest10",
			Status = "Blockout",
			Corridor = "B",
			ApproachFrom = "South",
			GroundCenter = Vector3.new(68, -0.75, 760),
			GroundSize = Vector3.new(110, 0.5, 104),
			GroundColor = Color3.fromRGB(94, 136, 81),
			Sign = { Text = "FOREST 10 - BLOCKOUT", Position = Vector3.new(95, 0, 744) },
			Trees = {},
		},
	},

	BARRIER = {
		DefinitionId = "BarrierTree",
		ForestId = "Forest1",
		Position = Vector3.new(-68, -0.4, 270),
	},
}

return WorldLayoutConfiguration
