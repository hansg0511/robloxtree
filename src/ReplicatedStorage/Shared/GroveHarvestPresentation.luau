-- Timing and safety constraints shared by server harvest presentation and
-- the local cinematic. Only cosmetics use these constants: GroveService owns
-- all item grants, storage limits and growth-cycle changes.
local Config = {
	PromptDistance = 12,
	InteractionDistance = 15,
	HarvestCooldownSeconds = 3.2,
	WindupSeconds = 0.32,
	CameraBlendSeconds = 0.28,
	CameraHoldSeconds = 2.85,
	CameraReturnSeconds = 0.32,
	FallSoundDelaySeconds = 0.23,
	DropSeconds = 0.31,
	BounceSeconds = 0.15,
	GroundPauseSeconds = 0.2,
	FlySeconds = 0.6,
	LogRevealFallbackSeconds = 2.15,
	MaxVisualLifetimeSeconds = 7,
	AudioMaxDistance = 95,
}
return table.freeze(Config)
