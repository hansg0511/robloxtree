-- Server-owned prototype definitions. Categories describe behavior; balance and art
-- remain subject to iteration as the first world slice comes together.
local TreeDefinitions = {
	BasicGrove = {
		Category = "Grove",
		ModelName = "BrickPlaceholder",
		MaxHP = 100,
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
