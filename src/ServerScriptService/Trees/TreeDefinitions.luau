-- Server-owned definitions. Categories describe behavior; final stats and art are undecided.
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
}

TreeDefinitions.Categories = {
	Farm = true,
	Barrier = true,
	Boss = true,
	Grove = true,
}

return TreeDefinitions
