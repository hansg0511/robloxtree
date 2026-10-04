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
		LogValue = 16,
		-- This temporary plot smoke-test tree must never become a free base farm.
		YieldsLog = false,
		RespawnSeconds = 3,
		OwnerOnly = true,
		Choppable = true,
		ForestId = "Base",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 6,
	},
	StarterForestTree = {
		Category = "Grove",
		ModelName = "StarterForestTree",
		MaxHP = 60,
		SpeciesId = "Oak",
		LogValue = 16,
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
		LogValue = 144,
		YieldsLog = true,
		RespawnSeconds = 5,
		OwnerOnly = false,
		Choppable = true,
		ForestId = "Forest2",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 8,
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
		-- Temporary server-side progression seam; the valid final hitter gets this unlock.
		UnlockForestId = "Forest2",
		InteractionPartName = "ChopHitbox",
		ChopRadius = 10,
	},
}

TreeDefinitions.Categories = {
	Farm = true,
	Barrier = true,
	Boss = true,
	Grove = true,
}

return TreeDefinitions
