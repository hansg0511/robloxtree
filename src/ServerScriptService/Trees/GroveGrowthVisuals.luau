-- Additive Grove-growth presentation.
--
-- This uses the SAME final species tree model that the world uses. Instead
-- of swapping miniature sapling / juvenile tree replicas or fading models,
-- reveal its real trunk, then branches, then cube-leaf clusters over time.
-- Never changes the item, mutation, tree UID, or harvest rules.
local SpeciesVisuals = require(game.ServerStorage.SpeciesVisuals)

local GrowthVisuals = {}
GrowthVisuals.STEPS = 40

local function stableHash(part)
	local name = part.Name
	local p = part.Position
	local seed = string.format("%s:%.1f:%.1f:%.1f", name, p.X, p.Y, p.Z)
	local value = 13
	for i = 1, #seed do
		value = (value * 31 + string.byte(seed, i)) % 104729
	end
	return value / 104729
end

local function inNamedFolder(part, model, allowed)
	local parent = part.Parent
	while parent and parent ~= model do
		if allowed[parent.Name] then return true end
		parent = parent.Parent
	end
	return false
end

local function classify(part, model)
	local name = part.Name
	if inNamedFolder(part, model, { Leaves = true, FoliageDecorations = true })
		or string.find(name, "Leaf") or string.find(name, "Canopy") then
		return "leaves"
	end
	if inNamedFolder(part, model, { DecorativeBranches = true })
		or string.find(name, "Bough") or string.find(name, "Branch") then
		return "branches"
	end
	return "trunk"
end

local function timeForPart(part, model, height)
	if part:GetAttribute("AlwaysInvisible") == true
		or part.Transparency >= 0.99 then return nil end
	local role = classify(part, model)
	local pivot = model:GetPivot()
	local localY = pivot:PointToObjectSpace(part.Position).Y
	local yFraction = math.clamp(localY / math.max(1, height), 0, 1)
	local jitter = stableHash(part)
	if role == "leaves" then
		-- Leaf groups arrive after their branches, a few at a time. A high
		-- crown fills in later than a low one.
		return math.clamp(0.68 + 0.29 * (yFraction * 0.65 + jitter * 0.35), 0.68, 0.99)
	elseif role == "branches" then
		return 0.42 + 0.22 * (yFraction * 0.65 + jitter * 0.35)
	else
		if name == "RootFoot" then return 0.10 end
		local sectionIndex = part:GetAttribute("CoreSectionIndex")
		if type(sectionIndex) == "number" and sectionIndex >= 1 then
			return math.min(0.40, 0.16 + 0.09 * (sectionIndex - 1))
		end
		-- Bark blocks appear from bottom to top, before branches.
		return 0.14 + 0.24 * (yFraction * 0.75 + jitter * 0.25)
	end
end

local function addStump(model, speciesId)
	local root = model.PrimaryPart
	if not root or not root:IsA("BasePart") then return nil end
	local palette = SpeciesVisuals.GetPalette(speciesId)
	local scale = model:GetScale()
	local width
	if speciesId == "Oak" then
		local rawThickness = model:GetAttribute("TrunkThickness")
		width = (if type(rawThickness) == "number" then rawThickness else 2.4) * scale
	elseif speciesId == "Ironwood" then
		width = 3.5 * scale
	else
		width = 1.3 * scale
	end
	width = math.clamp(width, 0.22, 20)
	local height = math.clamp(width * 0.8, 0.32, 6.5)
	local pivot = model:GetPivot()
	local body = Instance.new("Part")
	body.Name = "GroveGrowthStump"
	body.Size = Vector3.new(width, height, width)
	body.CFrame = pivot * CFrame.new(0, height * 0.5, 0)
	body.Color = palette.Bark
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = false
	body.Massless = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body

	local cut = Instance.new("Part")
	cut.Name = "GroveGrowthCutEnd"
	cut.Size = Vector3.new(width * 0.92, math.max(0.055, width * 0.045), width * 0.92)
	cut.CFrame = pivot * CFrame.new(0, height + cut.Size.Y * 0.5, 0)
	cut.Color = palette.CutEnd
	cut.Material = Enum.Material.SmoothPlastic
	cut.Anchored = false
	cut.Massless = true
	cut.CanCollide = false
	cut.CanTouch = false
	cut.CanQuery = false
	cut.Parent = model
	local capWeld = Instance.new("WeldConstraint")
	capWeld.Part0 = root
	capWeld.Part1 = cut
	capWeld.Parent = cut
	return { body, cut }
end

function GrowthVisuals.Prepare(model, speciesId)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return nil end
	local height = model:GetExtentsSize().Y
	local records = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local unlockAt = timeForPart(part, model, height)
			if unlockAt then
				table.insert(records, {
					Part = part,
					At = unlockAt,
					Transparency = part.Transparency,
					CanCollide = part.CanCollide,
				})
			end
		end
	end
	local stump = addStump(model, speciesId)
	return { Model = model, Records = records, Stump = stump, LastStep = -1 }
end

function GrowthVisuals.Apply(state, fraction, allowUnparented)
	if not state or not state.Model or (not allowUnparented and not state.Model.Parent) then return false end
	if type(fraction) ~= "number" or fraction ~= fraction then return false end
	fraction = math.clamp(fraction, 0, 1)
	local step = math.min(GrowthVisuals.STEPS, math.floor(fraction * GrowthVisuals.STEPS + 1e-6))
	if step == state.LastStep then return true end
	state.LastStep = step

	-- No model fade. Newly unlocked parts become solid in place.
	for _, record in ipairs(state.Records) do
		local part = record.Part
		if part.Parent then
			local visible = step >= math.ceil(record.At * GrowthVisuals.STEPS)
			part.Transparency = if visible then record.Transparency else 1
			part.CanCollide = visible and record.CanCollide
		end
	end

	-- The stump's diameter already reflects the ACTUAL next tree size.
	-- It stays in place while the first trunk blocks appear.
	local showStump = step < math.ceil(0.30 * GrowthVisuals.STEPS)
	for _, stumpPart in ipairs(state.Stump or {}) do
		if stumpPart.Parent then stumpPart.Transparency = if showStump then 0 else 1 end
	end
	state.Model:SetAttribute("GroveGrowthVisualStep", step)
	state.Model:SetAttribute("GroveGrowthProgress", step / GrowthVisuals.STEPS)
	return true
end

return GrowthVisuals
