-- Shared visual timing for production and the Studio harvest showcase.
-- Consumers keep their own geometry, easing, effects, and lifecycle adapters.
local HarvestVisualConfig = {
	FallDuration = 1.0,
	LeafShrinkDuration = 0.18,
	ImpactSmokeDuration = 0.42,
	SectionStagger = 0.12,
	SectionArcHeight = 1.4,
	SectionDuration = 0.45,
	RotationTurns = 1,
	RotationSpeedRadiansPerSecond = math.rad(800),
}

return table.freeze(HarvestVisualConfig)
