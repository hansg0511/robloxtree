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
local CARRY_LOG_LENGTH = 2.15
local CARRY_LOG_DIAMETER = 0.48
local CARRY_CAP_THICKNESS = 0.07
local CARRY_CAP_DIAMETER_RATIO = 0.88

function SpeciesVisuals.GetPalette(speciesId)
	return PALETTES[speciesId] or PALETTES[FALLBACK_SPECIES]
end

local function hasNonemptyText(value)
	return type(value) == "string" and string.match(value, "%S") ~= nil
end

local function isValidMutationEntry(key, value)
	-- Mutation records are server-owned maps keyed by a nonempty mutation name.
	-- Empty strings, false flags, non-finite numbers, and malformed values are
	-- ignored so corrupt profile data cannot make an ordinary log look rare.
	if not hasNonemptyText(key) then
		return false
	end

	if type(value) == "string" then
		return hasNonemptyText(value)
	elseif type(value) == "number" then
		return value == value and value > -math.huge and value < math.huge
	elseif type(value) == "boolean" then
		return value
	end

	return false
end

function SpeciesVisuals.IsRareLog(logRecord)
	if type(logRecord) ~= "table" or type(logRecord.Mutations) ~= "table" then
		return false
	end

	for key, value in pairs(logRecord.Mutations) do
		if isValidMutationEntry(key, value) then
			return true
		end
	end

	return false
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

-- Creates a server-built wood assembly for an ordinary world drop. The optional
-- visualScale affects only this disposable model; inventory records deliberately
-- have no presentation-scale field.
-- Returns a direct-child Handle plus the direct-child decorative end caps.
function SpeciesVisuals.CreateLogParts(logRecord, handleName, visualScale)
	assert(type(logRecord) == "table", "A server-owned log record is required")
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	local geometryScale = if type(visualScale) == "number" and visualScale > 0 then visualScale else 1
	-- Ground drops use this same carry-log shape multiplied by the caller's
	-- visualScale. A scale of four therefore makes the true body and cap
	-- dimensions exactly four times the unchanged back-stack dimensions.
	local length = CARRY_LOG_LENGTH * geometryScale
	local diameter = CARRY_LOG_DIAMETER * geometryScale

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
	addBarkStrips(handle, length, diameter, geometryScale, palette)

	local caps = {}
	local capThickness = CARRY_CAP_THICKNESS * geometryScale
	for index, direction in ipairs({ -1, 1 }) do
		local cap = configurePart(Instance.new("Part"))
		cap.Name = "CutEnd" .. index
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(capThickness, diameter * CARRY_CAP_DIAMETER_RATIO, diameter * CARRY_CAP_DIAMETER_RATIO)
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

-- Small, standardized cosmetic log for the character's back cargo. It stays a
-- consistent size across species and has no inventory-driven presentation
-- scale. The caller positions and welds all three BaseParts to its character-
-- local cargo anchor.
function SpeciesVisuals.CreateCarryLogParts(logRecord)
	assert(type(logRecord) == "table", "A server-owned log record is required")
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	local length = CARRY_LOG_LENGTH
	local diameter = CARRY_LOG_DIAMETER
	local capThickness = CARRY_CAP_THICKNESS

	local body = configurePart(Instance.new("Part"))
	body.Name = "CarryLogBody"
	body.Size = Vector3.new(length, diameter, diameter)
	body.CFrame = CFrame.new()
	body.Color = palette.Bark
	body.Material = Enum.Material.Plastic
	body.TopSurface = Enum.SurfaceType.Studs
	body.BottomSurface = Enum.SurfaceType.Inlet
	body.FrontSurface = Enum.SurfaceType.Studs
	body.BackSurface = Enum.SurfaceType.Studs
	body.LeftSurface = Enum.SurfaceType.Studs
	body.RightSurface = Enum.SurfaceType.Studs
	body:SetAttribute("SpeciesId", logRecord.SpeciesId)
	body:SetAttribute("ItemType", "Log")

	local caps = {}
	for index, direction in ipairs({ -1, 1 }) do
		local cap = configurePart(Instance.new("Part"))
		cap.Name = "CarryLogCutEnd" .. index
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(capThickness, diameter * CARRY_CAP_DIAMETER_RATIO, diameter * CARRY_CAP_DIAMETER_RATIO)
		cap.CFrame = CFrame.new(direction * (length * 0.5 - capThickness * 0.5), 0, 0)
		cap.Color = palette.CutEnd
		cap.Material = Enum.Material.Plastic
		cap.TopSurface = Enum.SurfaceType.Smooth
		cap.BottomSurface = Enum.SurfaceType.Smooth
		cap:SetAttribute("SpeciesId", logRecord.SpeciesId)
		cap:SetAttribute("ItemType", "Log")
		table.insert(caps, cap)
	end

	return body, caps
end

return SpeciesVisuals
