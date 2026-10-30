-- Shared server-owned palette and chunky log geometry for species visuals.
-- This module contains presentation data only; item identity and size are
-- always supplied by server-owned tree/log records.
local SpeciesVisuals = {}
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local replicatedStorage = game:GetService("ReplicatedStorage")
local OakLogAppearance = require(replicatedStorage:WaitForChild("Shared"):WaitForChild("OakLogAppearance"))

local PALETTES = {
	Oak = OakLogAppearance.Palette,
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
	Bamboo = {
		Bark = Color3.fromRGB(127, 179, 80),
		BarkHighlight = Color3.fromRGB(170, 207, 105),
		BarkShadow = Color3.fromRGB(78, 132, 60),
		CutEnd = Color3.fromRGB(224, 219, 145),
		CutRing = Color3.fromRGB(153, 177, 91),
		CutRingShadow = Color3.fromRGB(97, 135, 61),
		Leaf = Color3.fromRGB(63, 151, 68),
		LeafHighlight = Color3.fromRGB(121, 194, 75),
		LeafShadow = Color3.fromRGB(42, 111, 60),
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

function SpeciesVisuals.GetCarryVisualScale(speciesId)
	local definition = MaterialDefinitions.Get(speciesId)
	local scale = definition and definition.CarryVisualScale
	if type(scale) ~= "number" or scale ~= scale or scale <= 0 or scale == math.huge then
		return 1
	end
	return math.clamp(scale, 0.05, 4)
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

local function addEndGrain(cap, direction, length, diameter, sizeScale, palette, isOak)
	local layers = OakLogAppearance.GetEndGrainLayerDefinitions(direction, length, diameter, sizeScale, palette, isOak)
	for _, layer in ipairs(layers) do
		local grain = configurePart(Instance.new("Part"))
		grain.Name = layer.Name
		grain.Shape = Enum.PartType.Cylinder
		grain.Size = layer.Size
		grain.CFrame = CFrame.new(layer.Position)
		grain.Color = layer.Color
		grain.Material = Enum.Material.Plastic
		grain.TopSurface = Enum.SurfaceType.Smooth
		grain.BottomSurface = Enum.SurfaceType.Smooth
		if isOak then
			OakLogAppearance.SetSmoothSurfaces(grain)
		end
		grain.Parent = cap

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogGrowthRingWeld"
		weld.Part0 = cap
		weld.Part1 = grain
		weld.Parent = grain
	end
end

local function addBarkStrips(handle, length, diameter, sizeScale, palette, isOak)
	local faces = OakLogAppearance.GetBarkStripDefinitions(length, diameter, sizeScale, palette, isOak)
	for _, definition in ipairs(faces) do
		local strip = configurePart(Instance.new("Part"))
		strip.Name = definition.Name
		strip.Size = definition.Size
		strip.CFrame = CFrame.new(definition.Position)
		strip.Color = definition.Color
		strip.Material = Enum.Material.Plastic
		strip.TopSurface = Enum.SurfaceType.Smooth
		strip.BottomSurface = Enum.SurfaceType.Smooth
		if isOak then
			OakLogAppearance.SetSmoothSurfaces(strip)
		end
		strip.Parent = handle

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogBarkWeld"
		weld.Part0 = handle
		weld.Part1 = strip
		weld.Parent = strip
	end
end

local function addOakPickupBoundsProxy(handle, length, diameter, sizeScale)
	-- Keep the pre-refinement ground model bounds used by pickup distance checks
	-- while the visible Oak details use fewer parts.
	local proxy = configurePart(Instance.new("Part"))
	proxy.Name = "OakLogBoundsProxy"
	proxy.Size = Vector3.new(
		length + 9 * 0.012 * sizeScale,
		diameter + 0.7 * 0.045 * sizeScale,
		diameter + 0.7 * 0.045 * sizeScale
	)
	proxy.CFrame = handle.CFrame
	proxy.Transparency = 1
	proxy.CastShadow = false
	OakLogAppearance.SetSmoothSurfaces(proxy)
	proxy.Parent = handle

	local weld = Instance.new("WeldConstraint")
	weld.Name = "OakLogBoundsProxyWeld"
	weld.Part0 = handle
	weld.Part1 = proxy
	weld.Parent = proxy
end

-- Creates a server-built wood assembly for an ordinary world drop. The optional
-- visualScale affects only this disposable model; inventory records deliberately
-- have no presentation-scale field.
-- Returns a direct-child Handle plus the direct-child decorative end caps.
function SpeciesVisuals.CreateLogParts(logRecord, handleName, visualScale)
	assert(type(logRecord) == "table", "A server-owned log record is required")
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	local modelMultiplier = if type(visualScale) == "number" and visualScale > 0 then visualScale else 1
	local geometryScale = SpeciesVisuals.GetCarryVisualScale(logRecord.SpeciesId) * modelMultiplier
	-- Ground drops use this same carry-log shape multiplied by the caller's
	-- visualScale. A scale of four therefore makes the true body and cap
	-- dimensions exactly four times the unchanged back-stack dimensions.
	local length = CARRY_LOG_LENGTH * geometryScale
	local diameter = CARRY_LOG_DIAMETER * geometryScale
	local isOak = logRecord.SpeciesId == "Oak"

	local handle = configurePart(Instance.new("Part"))
	handle.Name = handleName or "Handle"
	-- Oak uses the smooth layered treatment approved for standardized logs;
	-- existing non-Oak surface styles and the matching cut ends are preserved.
	handle.Size = Vector3.new(length, diameter, diameter)
	handle.CFrame = CFrame.new()
	handle.Color = palette.Bark
	handle.Material = Enum.Material.Plastic
	if isOak then
		OakLogAppearance.SetSmoothSurfaces(handle)
	else
		handle.TopSurface = Enum.SurfaceType.Studs
		handle.BottomSurface = Enum.SurfaceType.Inlet
		handle.FrontSurface = Enum.SurfaceType.Studs
		handle.BackSurface = Enum.SurfaceType.Studs
		handle.LeftSurface = Enum.SurfaceType.Studs
		handle.RightSurface = Enum.SurfaceType.Studs
	end
	handle:SetAttribute("ItemType", "Log")
	handle:SetAttribute("SpeciesId", logRecord.SpeciesId)
	addBarkStrips(handle, length, diameter, geometryScale, palette, isOak)
	if isOak then
		addOakPickupBoundsProxy(handle, length, diameter, geometryScale)
	end

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
		if isOak then
			OakLogAppearance.SetSmoothSurfaces(cap)
		end

		local weld = Instance.new("WeldConstraint")
		weld.Name = "LogCutWeld"
		weld.Part0 = handle
		weld.Part1 = cap
		weld.Parent = cap
		addEndGrain(cap, direction, length, diameter, geometryScale, palette, isOak)
		table.insert(caps, cap)
	end

	return handle, caps
end

-- Small, standardized cosmetic log for the character's back cargo. It stays a
-- consistent size across species and has no inventory-driven presentation
-- scale. The caller positions and welds the body and cut-end roots to its
-- character-local cargo anchor; Oak bark and grain parts follow those roots.
function SpeciesVisuals.CreateCarryLogParts(logRecord)
	assert(type(logRecord) == "table", "A server-owned log record is required")
	local palette = SpeciesVisuals.GetPalette(logRecord.SpeciesId)
	local carryScale = SpeciesVisuals.GetCarryVisualScale(logRecord.SpeciesId)
	local length = CARRY_LOG_LENGTH * carryScale
	local diameter = CARRY_LOG_DIAMETER * carryScale
	local capThickness = CARRY_CAP_THICKNESS * carryScale
	local isOak = logRecord.SpeciesId == "Oak"

	local body = configurePart(Instance.new("Part"))
	body.Name = "CarryLogBody"
	body.Size = Vector3.new(length, diameter, diameter)
	body.CFrame = CFrame.new()
	body.Color = palette.Bark
	body.Material = Enum.Material.Plastic
	if isOak then
		OakLogAppearance.SetSmoothSurfaces(body)
	else
		body.TopSurface = Enum.SurfaceType.Studs
		body.BottomSurface = Enum.SurfaceType.Inlet
		body.FrontSurface = Enum.SurfaceType.Studs
		body.BackSurface = Enum.SurfaceType.Studs
		body.LeftSurface = Enum.SurfaceType.Studs
		body.RightSurface = Enum.SurfaceType.Studs
	end
	body:SetAttribute("SpeciesId", logRecord.SpeciesId)
	body:SetAttribute("ItemType", "Log")
	body:SetAttribute("CarryVisualScale", carryScale)

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
		if isOak then
			OakLogAppearance.SetSmoothSurfaces(cap)
			addEndGrain(cap, direction, length, diameter, carryScale, palette, isOak)
		end
		cap:SetAttribute("SpeciesId", logRecord.SpeciesId)
		cap:SetAttribute("ItemType", "Log")
		table.insert(caps, cap)
	end
	if isOak then
		addBarkStrips(body, length, diameter, carryScale, palette, isOak)
	end

	return body, caps
end

return SpeciesVisuals
