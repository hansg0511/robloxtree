-- Studio-only development gallery configuration.
-- The coordinator enforces RunService:IsStudio() before reading this module.
return {
	Enabled = true,
	Origin = Vector3.new(6000, 120, 6000),
	Labs = {
		Tree = true,
		Terrain = true,
		Forest = true,
		Archive = true,
	},
	Archive = {
		TreeStudies = false,
	},
}
