-- Server-owned prototype definitions. Categories describe behavior; balance and art
-- remain subject to iteration as the first world slice comes together.
local TreeDefinitions = {
	BasicGrove = {
		Category = "Grove",
		ModelName = "BrickPlaceholder",
		MaxHP = 100,
		SpeciesId = "Oak",
		-- Personal-grove trees do not yield cargo, but retain the same species
		-- identity as the starter forest for visuals.
		-- Legacy scaffold: it is retained for compatibility but cannot be chopped,
		-- reward logs, or respawn as a free base farm.
		YieldsLog = false,
		OwnerOnly = true,
		Choppable = false,
		ForestId = "Base",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 6,
	},
	PersistentGroveTree = {
		Category = "Grove",
		ModelName = "StarterForestTree",
		MaxHP = 60,
		SpeciesId = "Oak",
		YieldsLog = false,
		OwnerOnly = true,
		Choppable = true,
		ForestId = "Base",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 7,
	},
	StarterForestTree = {
		Category = "Grove",
		ModelName = "StarterForestTree",
		MaxHP = 60,
		SpeciesId = "Oak",
		YieldsLog = true,
		RespawnSeconds = 3,
		OwnerOnly = false,
		Choppable = true,
		ForestId = "Forest1",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 7,
	},
	Forest2Tree = {
		Category = "Grove",
		ModelName = "Forest2Tree",
		MaxHP = 180,
		SpeciesId = "Ironwood",
		YieldsLog = true,
		RespawnSeconds = 5,
		OwnerOnly = false,
		Choppable = true,
		ForestId = "Forest2",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 8,
	},
	BambooClump = {
		Category = "Grove",
		ModelName = "BambooClump",
		MaxHP = 18,
		SpeciesId = "Bamboo",
		LogYield = 5,
		FixedSizeScale = 1,
		YieldsLog = true,
		RespawnSeconds = 3,
		OwnerOnly = false,
		Choppable = true,
		ForestId = "Forest1",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 5,
	},
	BarrierTree = {
		Category = "Barrier",
		ModelName = "BarrierTree",
		MaxHP = 600,
		YieldsLog = false,
		RespawnSeconds = 20,
		OwnerOnly = false,
		Choppable = true,
		ForestId = "Forest1",
		-- The barrier is a current-run milestone: a crafted Copper Axe is required.
		RequiredStandardAxeTier = 1,
		-- Temporary server-side progression seam; the valid final hitter gets this unlock.
		UnlockForestId = "Forest2",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 10,
	},
}

-- Persistent Grove runtime prototypes reuse the species-specific world models,
-- HP and interaction radii without changing those world tree definitions.
TreeDefinitions.PersistentGroveSpecies = {
	Oak = { ModelName = "StarterForestTree", MaxHP = 60, ChopRadius = 7 },
	Bamboo = { ModelName = "BambooClump", MaxHP = 18, ChopRadius = 5 },
	Ironwood = { ModelName = "Forest2Tree", MaxHP = 180, ChopRadius = 8 },
}

TreeDefinitions.Categories = {
	Farm = true,
	Barrier = true,
	Boss = true,
	Grove = true,
}

return TreeDefinitions
