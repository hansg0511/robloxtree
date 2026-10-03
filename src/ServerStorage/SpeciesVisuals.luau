-- Shared server-owned palette and chunky log geometry for species visuals.
-- This module contains presentation data only; item identity and size are
-- always supplied by server-owned tree/log records.
local SpeciesVisuals = {}

local PALETTES = {
	Oak = {
		Bark = Color3.fromRGB(142, 84, 48),
		BarkHighlight = Color3.fromRGB(164, 101, 57),
		BarkShadow = Color3.fromRGB(127, 72, 42),
		CutEnd = Color3.fromRGB(210, 163, 101),
	},
	Ironwood = {
		Bark = Color3.fromRGB(91, 65, 49),
		BarkHighlight = Color3.fromRGB(111, 76, 52),
		BarkShadow = Color3.fromRGB(72, 53, 43),
		CutEnd = Color3.fromRGB(165, 139, 111),
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

-- Creates the exact same server-built wood assembly for inventory tools and
-- world pickups. The caller chooses the parent and whether it is anchored.
-- Returns a direct-child Handle plus the direct-child decorative end caps.
function SpeciesVisuals.CreateLogParts(logRecord, handleName)
	assert(type(logRecord) == "table", "A server-owned log record is required")
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	local sizeScale = getSizeScale(logRecord)
	local length = 2.15 * sizeScale
	local diameter = 0.7 * sizeScale

	local handle = configurePart(Instance.new("Part"))
	handle.Name = handleName or "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(length, diameter, diameter)
	handle.CFrame = CFrame.new()
	handle.Color = palette.Bark
	handle.Material = Enum.Material.Plastic
	handle:SetAttribute("ItemType", "Log")
	handle:SetAttribute("SpeciesId", logRecord.SpeciesId)
	handle:SetAttribute("SizeScale", sizeScale)

	local caps = {}
	for index, direction in ipairs({ -1, 1 }) do
		local cap = configurePart(Instance.new("Part"))
		cap.Name = "CutEnd" .. index
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(0.06 * sizeScale, diameter * 0.94, diameter * 0.94)
		cap.CFrame = CFrame.new(direction * (length * 0.5 - cap.Size.X * 0.5), 0, 0)
		cap.Color = palette.CutEnd
		cap.Material = Enum.Material.Plastic

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogCutWeld"
		weld.Part0 = handle
		weld.Part1 = cap
		weld.Parent = cap
		table.insert(caps, cap)
	end

	return handle, caps
end

return SpeciesVisuals
