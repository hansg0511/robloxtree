-- Shared tunable material geometry and wild size rolls. No inventory weight,
-- mutation potency, or Grove genetics policy belongs here.
local Geometry = {}
Geometry.MAX_LOG_SIZE = 5
Geometry.BASE_DIMENSIONS = {
	Sapwood = { Length = 2.5, Width = 0.65, Height = 0.65 },
	Bamboo = { Length = 4, Width = 0.45, Height = 0.45 },
	Oak = { Length = 4, Width = 1.4, Height = 1.4 },
	Ironwood = { Length = 5, Width = 1.8, Height = 1.8 },
}
-- Weights sum to 1; exact maximum is a separate rare outcome, so 100%
-- quality is actually obtainable rather than a continuous RNG endpoint.
Geometry.WILD_SIZE_BANDS = {
	{ Weight = 0.81, Min = 0.7, Max = 1.3 },
	{ Weight = 0.09, Min = 0.45, Max = 0.7 },
	{ Weight = 0.09, Min = 1.3, Max = 1.7 },
	{ Weight = 0.009, Min = 1.7, Max = 3 },
	{ Weight = 0.0009, Min = 3, Max = 4.99 },
	{ Weight = 0.0001, Min = 5, Max = 5 },
}
Geometry.WEAPON_REFERENCE_LINEAR_SIZE = 1
Geometry.WEAPON_SCALE_EXPONENT = 0.6
Geometry.WEAPON_MIN_SCALE = 0.75
Geometry.WEAPON_MAX_SCALE = 2.5
Geometry.REACH_MIN = 0.9
Geometry.REACH_MAX = 1.15

function Geometry.RollWildSize(rng)
	local draw = rng:NextNumber()
	local cumulative = 0
	for index, band in ipairs(Geometry.WILD_SIZE_BANDS) do
		cumulative += band.Weight
		if draw < cumulative or index == #Geometry.WILD_SIZE_BANDS then
			return math.min(Geometry.MAX_LOG_SIZE,
				if band.Min == band.Max then band.Min else rng:NextNumber(band.Min, band.Max))
		end
	end
	return 1
end

function Geometry.Dimensions(speciesId, size)
	local base = Geometry.BASE_DIMENSIONS[speciesId]
	if not base or type(size) ~= "number" or size ~= size or size <= 0
		or size == math.huge then return nil end
	size = math.min(size, Geometry.MAX_LOG_SIZE)
	return base.Length * size, base.Width * size, base.Height * size
end

function Geometry.Volume(speciesId, size)
	local length, width, height = Geometry.Dimensions(speciesId, size)
	if not length then return nil end
	return length * width * height
end

function Geometry.WeaponScale(averageVolume)
	local linearSize = averageVolume ^ (1 / 3)
	return math.clamp((linearSize / Geometry.WEAPON_REFERENCE_LINEAR_SIZE)
		^ Geometry.WEAPON_SCALE_EXPONENT, Geometry.WEAPON_MIN_SCALE, Geometry.WEAPON_MAX_SCALE)
end

function Geometry.Reach(weaponScale)
	local t = math.clamp((weaponScale - Geometry.WEAPON_MIN_SCALE)
		/ (Geometry.WEAPON_MAX_SCALE - Geometry.WEAPON_MIN_SCALE), 0, 1)
	return Geometry.REACH_MIN + (Geometry.REACH_MAX - Geometry.REACH_MIN) * t
end

return Geometry
