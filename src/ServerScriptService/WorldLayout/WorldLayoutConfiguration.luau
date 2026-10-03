-- Source-owned coordinates for the first base-to-forest world corridor.
-- ForestId values are also used by the tree interaction/progression services.
local function makeTreeRecords(definitionId, rowZ)
	local records = {}
	for _, z in ipairs(rowZ) do
		for _, x in ipairs({ -48, -28, 28, 48 }) do
			table.insert(records, {
				DefinitionId = definitionId,
				Position = Vector3.new(x, -0.5, z),
			})
		end
	end
	return records
end

local STATION_USE_DISTANCES = {
	AxeShopStation = 14,
	HomeEconomyStation = 14,
}

local WorldLayoutConfiguration = {
	ROOT_NAME = "SourceWorld",
	VERSION = 4,
	STATION_USE_DISTANCES = STATION_USE_DISTANCES,

	-- The narrow section follows the six-stud opening between the two rear plots.
	-- It widens once it clears the plots and stays centered on the same route.
	PATH_SURFACE_Y = -0.4,
	PATH_THICKNESS = 0.12,
	PATH_MATERIAL = Enum.Material.Slate,
	PATH_COLOR = Color3.fromRGB(148, 132, 105),
	PATH_SEGMENTS = {
		{
			Name = "PlotLane",
			Width = 6,
			StartZ = -105,
			EndZ = 120,
		},
		{
			Name = "ForestTrail",
			Width = 16,
			StartZ = 119,
			EndZ = 410,
		},
	},

	GROUND_MATERIAL = Enum.Material.Grass,
	GROUND_COLOR = Color3.fromRGB(91, 132, 79),
	-- The economy service verifies player distance to this source-built station
	-- before executing a sale. It is intentionally part of the base rather than
	-- a generic UI action usable from a forest.
	HOME_ECONOMY_STATION = {
		Position = Vector3.new(24, -0.4, 108),
	},
	AXE_SHOP_STATION = {
		Position = Vector3.new(-24, -0.4, 108),
	},
	FORESTS = {
		{
			Name = "StarterForest",
			ForestId = "Forest1",
			GroundCenter = Vector3.new(0, -0.75, 168),
			GroundSize = Vector3.new(126, 0.5, 100),
			Sign = {
				Text = "STARTER FOREST",
				Position = Vector3.new(-13, 0, 126),
			},
			Trees = makeTreeRecords("StarterForestTree", { 136, 170, 204 }),
		},
		{
			Name = "Forest2",
			ForestId = "Forest2",
			GroundCenter = Vector3.new(0, -0.75, 354),
			GroundSize = Vector3.new(126, 0.5, 112),
			Sign = {
				Text = "FOREST 2",
				Position = Vector3.new(13, 0, 304),
			},
			Trees = makeTreeRecords("Forest2Tree", { 316, 354, 392 }),
		},
	},

	-- The transition clearing keeps the path supported between the two forest pads.
	CONNECTOR_GROUND = {
		Name = "BarrierClearingGround",
		Center = Vector3.new(0, -0.75, 258),
		Size = Vector3.new(24, 0.5, 80),
	},
	BARRIER = {
		DefinitionId = "BarrierTree",
		ForestId = "Forest1",
		Position = Vector3.new(0, -0.4, 245),
	},
}

return WorldLayoutConfiguration
