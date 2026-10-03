-- Shared server-owned palette and chunky log geometry for species visuals.
-- This module contains presentation data only; item identity and size are
-- always supplied by server-owned tree/log records.
local SpeciesVisuals = {}

local PALETTES = {
	Oak = {
		Bark = Color3.fromRGB(151, 82, 43),
		BarkHighlight = Color3.fromRGB(190, 116, 58),
		BarkShadow = Color3.fromRGB(112, 59, 34),
		CutEnd = Color3.fromRGB(244, 202, 133),
		CutRing = Color3.fromRGB(186, 132, 75),
		CutRingShadow = Color3.fromRGB(143, 92, 50),
		Leaf = Color3.fromRGB(105, 202, 67),
		LeafHighlight = Color3.fromRGB(156, 226, 77),
		LeafShadow = Color3.fromRGB(69, 160, 58),
	},
	Ironwood = {
		Bark = Color3.fromRGB(79, 50, 36),
		BarkHighlight = Color3.fromRGB(116, 76, 49),
		BarkShadow = Color3.fromRGB(52, 38, 31),
		CutEnd = Color3.fromRGB(185, 159, 126),
		CutRing = Color3.fromRGB(145, 116, 82),
		CutRingShadow = Color3.fromRGB(105, 82, 61),
		Leaf = Color3.fromRGB(30, 105, 76),
		LeafHighlight = Color3.fromRGB(48, 141, 91),
		LeafShadow = Color3.fromRGB(23, 77, 63),
	},
}

local FALLBACK_SPECIES = "Oak"

function SpeciesVisuals.GetPalette(speciesId)
	return PALETTES[speciesId] or PALETTES[FALLBACK_SPECIES]
end

local function getSizeScale(logRecord)
	local sizeScale = type(logRecord) == "table" and logRecord.SizeScale or nil
	if type(sizeScale) ~= "number" or sizeScale ~= sizeScale or sizeScale <= 0 or sizeScale == math.huge then
		return 1
	end
	return math.clamp(sizeScale, 0.45, 1.7)
end

local function configurePart(part)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	return part
end

local function addEndGrain(cap, direction, length, diameter, sizeScale, palette)
	local layers = {
		{ DiameterScale = 0.68, Color = palette.CutRingShadow },
		{ DiameterScale = 0.48, Color = palette.CutRing },
		{ DiameterScale = 0.25, Color = palette.CutRingShadow },
		{ DiameterScale = 0.12, Color = palette.CutEnd },
	}
	for index, layer in ipairs(layers) do
		local grain = configurePart(Instance.new("Part"))
		grain.Name = "GrowthRing" .. index
		grain.Shape = Enum.PartType.Cylinder
		local thickness = 0.012 * sizeScale
		local grainDiameter = diameter * layer.DiameterScale
		grain.Size = Vector3.new(thickness, grainDiameter, grainDiameter)
		grain.CFrame = CFrame.new(direction * (length * 0.5 + thickness * index), 0, 0)
		grain.Color = layer.Color
		grain.Material = Enum.Material.Plastic
		grain.TopSurface = Enum.SurfaceType.Smooth
		grain.BottomSurface = Enum.SurfaceType.Smooth
		grain.Parent = cap

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogGrowthRingWeld"
		weld.Part0 = cap
		weld.Part1 = grain
		weld.Parent = grain
	end
end

local function addBarkStrips(handle, length, diameter, sizeScale, palette)
	local stripThickness = 0.045 * sizeScale
	local stripWidth = diameter * 0.09
	local stripLength = length * 0.82
	local faces = {
		{ Position = Vector3.new(0, diameter * 0.5 - stripThickness * 0.15, 0), Size = Vector3.new(stripLength, stripThickness, stripWidth), Color = palette.BarkHighlight },
		{ Position = Vector3.new(0, -diameter * 0.5 + stripThickness * 0.15, 0), Size = Vector3.new(stripLength, stripThickness, stripWidth), Color = palette.BarkShadow },
		{ Position = Vector3.new(0, 0, diameter * 0.5 - stripThickness * 0.15), Size = Vector3.new(stripLength, stripWidth, stripThickness), Color = palette.BarkHighlight },
		{ Position = Vector3.new(0, 0, -diameter * 0.5 + stripThickness * 0.15), Size = Vector3.new(stripLength, stripWidth, stripThickness), Color = palette.BarkShadow },
	}
	for index, definition in ipairs(faces) do
		local strip = configurePart(Instance.new("Part"))
		strip.Name = "BarkGrain" .. index
		strip.Size = definition.Size
		strip.CFrame = CFrame.new(definition.Position)
		strip.Color = definition.Color
		strip.Material = Enum.Material.Plastic
		strip.TopSurface = Enum.SurfaceType.Smooth
		strip.BottomSurface = Enum.SurfaceType.Smooth
		strip.Parent = handle

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogBarkWeld"
		weld.Part0 = handle
		weld.Part1 = strip
		weld.Parent = strip
	end
end

-- Creates the same server-built wood assembly for held tools and world pickups.
-- visualMultiplier changes presentation size only and defaults to 1.
-- Returns a direct-child Handle plus the direct-child decorative end caps.
function SpeciesVisuals.CreateLogParts(logRecord, handleName, visualMultiplier)
	assert(type(logRecord) == "table", "A server-owned log record is required")
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	local sizeScale = getSizeScale(logRecord)
	local geometryScale = sizeScale
	if type(visualMultiplier) == "number" and visualMultiplier == visualMultiplier and visualMultiplier ~= math.huge then
		geometryScale *= math.clamp(visualMultiplier, 1, 1.6)
	end
	local length = 2.15 * geometryScale
	local diameter = 0.7 * geometryScale

	local handle = configurePart(Instance.new("Part"))
	handle.Name = handleName or "Handle"
	-- A square, studded body reads like a toy-brick log while the round end
	-- plates make it unmistakably a cut section of the matching tree species.
	handle.Size = Vector3.new(length, diameter, diameter)
	handle.CFrame = CFrame.new()
	handle.Color = palette.Bark
	handle.Material = Enum.Material.Plastic
	handle.TopSurface = Enum.SurfaceType.Studs
	handle.BottomSurface = Enum.SurfaceType.Inlet
	handle.FrontSurface = Enum.SurfaceType.Studs
	handle.BackSurface = Enum.SurfaceType.Studs
	handle.LeftSurface = Enum.SurfaceType.Studs
	handle.RightSurface = Enum.SurfaceType.Studs
	handle:SetAttribute("ItemType", "Log")
	handle:SetAttribute("SpeciesId", logRecord.SpeciesId)
	handle:SetAttribute("SizeScale", sizeScale)
	addBarkStrips(handle, length, diameter, geometryScale, palette)

	local caps = {}
	local capThickness = 0.07 * geometryScale
	for index, direction in ipairs({ -1, 1 }) do
		local cap = configurePart(Instance.new("Part"))
		cap.Name = "CutEnd" .. index
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(capThickness, diameter * 0.84, diameter * 0.84)
		cap.CFrame = CFrame.new(direction * (length * 0.5 - capThickness * 0.5), 0, 0)
		cap.Color = palette.CutEnd
		cap.Material = Enum.Material.Plastic
		cap.TopSurface = Enum.SurfaceType.Smooth
		cap.BottomSurface = Enum.SurfaceType.Smooth

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogCutWeld"
		weld.Part0 = handle
		weld.Part1 = cap
		weld.Parent = cap
		addEndGrain(cap, direction, length, diameter, geometryScale, palette)
		table.insert(caps, cap)
	end

	return handle, caps
end

return SpeciesVisuals
