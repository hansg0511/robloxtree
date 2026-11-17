-- Additive Grove-growth visuals. This reveal layer is cosmetic only:
-- the server-owned Grove service retains genetics, UIDs, timers and harvests.
--
-- Oak retains its approved bottom-up procedural growth unchanged.
-- Ironwood uses explicit supporting-trunk order, not jittered piece positions.
-- Bamboo grows all five canes in synchronized vertical segments.
local SpeciesVisuals = require(game.ServerStorage.SpeciesVisuals)

local GrowthVisuals = {}
GrowthVisuals.STEPS = 40

local BAMBOO_LAYERS = 6
local BAMBOO_FIRST_LAYER_AT = 0.12
local BAMBOO_LAST_LAYER_AT = 0.56
local BAMBOO_FULL_STALKS_AT = 0.62

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

local IRONWOOD_WOOD_AT = {
	Bark = 0.08,       -- lower trunk
	BarkBrick1 = 0.21, -- middle trunk
	BarkBrick2 = 0.32, -- top trunk: must NEVER precede the middle
	BoughLeft = 0.47,
	BoughRight = 0.57,
}

local function timeForPart(part, model, height, speciesId)
	if part:GetAttribute("AlwaysInvisible") == true
		or part.Transparency >= 0.99 then return nil end
	local role = classify(part, model)
	local pivot = model:GetPivot()
	local localY = pivot:PointToObjectSpace(part.Position).Y
	local yFraction = math.clamp(localY / math.max(1, height), 0, 1)
	local jitter = stableHash(part)

	if speciesId == "Ironwood" then
		-- These are source-authored visible sections. Positional sorting
		-- can misorder overlapping logs, and decorative BarkStud cylinders
		-- can look like particles while their supporting trunks are hidden.
		local woodName = part:GetAttribute("GroveGrowthAttachment")
		if type(woodName) ~= "string" then woodName = part.Name end
		local exactAt = IRONWOOD_WOOD_AT[woodName]
		if exactAt then return exactAt end
	end

	if speciesId == "Bamboo" then
		local name = part.Name
		if name == "BambooCore" or string.match(name, "^BambooStalk%d+$") then
			-- Full-length native stalks replace their short segment proxies
			-- together only AFTER those proxies have fully grown.
			return BAMBOO_FULL_STALKS_AT
		elseif string.match(name, "^BambooNode%d+_%d+$") then
			-- All canes receive their matching nodes as the growing layer
			-- reaches the same fractional height.
			return math.clamp(0.15 + yFraction * 0.44, 0.15, 0.59)
		end
	end

	-- Existing Oak behavior remains unchanged.
	if role == "leaves" then
		return math.clamp(0.63 + 0.35 * (yFraction * 0.65 + jitter * 0.35), 0.63, 0.99)
	elseif role == "branches" then
		return 0.36 + 0.25 * (yFraction * 0.65 + jitter * 0.35)
	else
		if part.Name == "RootFoot" then return 0.04 end
		local sectionIndex = part:GetAttribute("CoreSectionIndex")
		if type(sectionIndex) == "number" and sectionIndex >= 1 then
			return math.min(0.31, 0.08 + 0.10 * (sectionIndex - 1))
		end
		return 0.06 + 0.27 * (yFraction * 0.75 + jitter * 0.25)
	end
end

local function attachVisualPart(part, model)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = model.PrimaryPart
	weld.Part1 = part
	weld.Parent = part
end

local function makeCutStumpParts(model, centerCFrame, width, height, palette, prefix)
	local body = Instance.new("Part")
	body.Name = prefix .. "Stump"
	body.Size = Vector3.new(width, height, width)
	body.CFrame = centerCFrame * CFrame.new(0, height * 0.5, 0)
	body.Color = palette.Bark
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	attachVisualPart(body, model)

	local cut = Instance.new("Part")
	cut.Name = prefix .. "CutEnd"
	cut.Size = Vector3.new(width * 0.92, math.max(0.055, width * 0.045), width * 0.92)
	cut.CFrame = centerCFrame * CFrame.new(0, height + cut.Size.Y * 0.5, 0)
	cut.Color = palette.CutEnd
	cut.Material = Enum.Material.SmoothPlastic
	attachVisualPart(cut, model)
	return body, cut
end

local function getBambooCanes(model)
	local canes = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and
			(part.Name == "BambooCore" or string.match(part.Name, "^BambooStalk%d+$")) then
			table.insert(canes, part)
		end
	end
	table.sort(canes, function(a, b) return a.Name < b.Name end)
	return canes
end

local function addStump(model, speciesId, bambooCanes)
	local root = model.PrimaryPart
	if not root or not root:IsA("BasePart") then return nil end
	local palette = SpeciesVisuals.GetPalette(speciesId)

	if speciesId == "Bamboo" and #bambooCanes > 0 then
		-- Bamboo is a CLUMP of slim culms, not a single fat trunk. Use the
		-- same original X/Z coordinates and cane diameters as its final form.
		local result = {}
		for index, cane in ipairs(bambooCanes) do
			local foot = cane.CFrame * CFrame.new(0, -cane.Size.Y * 0.5, 0)
			local width = math.max(0.16, cane.Size.X * 0.78)
			local stumpHeight = math.max(0.24, width * 1.25)
			local body, cut = makeCutStumpParts(model, foot, width, stumpHeight,
				palette, "GroveBambooCulm" .. index)
			table.insert(result, body)
			table.insert(result, cut)
		end
		return result
	end

	-- The Oak/ Ironwood trunk stump previews this specific cycle's ACTUAL
	-- (not genetic-maximum) future size. Leave this known-good Oak intact.
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
	local body, cut = makeCutStumpParts(model, model:GetPivot(), width, height,
		palette, "GroveGrowth")
	return { body, cut }
end

local function makeBambooGrowthSegments(model, canes)
	local root = model.PrimaryPart
	if not root then return {} end
	local segments = {}
	for _, cane in ipairs(canes) do
		-- Every cane gets the SAME step schedule. The stems grow UPWARD
		-- together, not one full-length bamboo popping in after another.
		for layer = 1, BAMBOO_LAYERS do
			local segment = Instance.new("Part")
			segment.Name = "GroveBambooGrowthSegment"
			segment.Size = Vector3.new(
				cane.Size.X, cane.Size.Y / BAMBOO_LAYERS + 0.005, cane.Size.Z)
			local offset = -cane.Size.Y * 0.5
				+ (layer - 0.5) * cane.Size.Y / BAMBOO_LAYERS
			segment.CFrame = cane.CFrame * CFrame.new(0, offset, 0)
			segment.Color = cane.Color
			segment.Material = cane.Material
			segment.TopSurface = cane.TopSurface
			segment.BottomSurface = cane.BottomSurface
			segment.LeftSurface = cane.LeftSurface
			segment.RightSurface = cane.RightSurface
			segment.FrontSurface = cane.FrontSurface
			segment.BackSurface = cane.BackSurface
			attachVisualPart(segment, model)
			table.insert(segments, {
				Part = segment,
				At = BAMBOO_FIRST_LAYER_AT
					+ (layer - 1) / (BAMBOO_LAYERS - 1)
					* (BAMBOO_LAST_LAYER_AT - BAMBOO_FIRST_LAYER_AT),
				HideAt = BAMBOO_FULL_STALKS_AT,
				Transparency = 0,
				CanCollide = false,
			})
		end
	end
	return segments
end

function GrowthVisuals.Prepare(model, speciesId)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return nil end
	local height = model:GetExtentsSize().Y
	local bambooCanes = if speciesId == "Bamboo" then getBambooCanes(model) else {}
	local records = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Ironwood's optional brick studs look like detached floating
			-- particles on a growing tree; omit these decorative details
			-- from the Grove prototype. Wild forest visuals are unaffected.
			if speciesId == "Ironwood" and part.Name == "BarkStud" then
				part.Transparency = 1
				part.CanCollide = false
			else
				local unlockAt = timeForPart(part, model, height, speciesId)
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
	end
	local stump = addStump(model, speciesId, bambooCanes)
	if speciesId == "Bamboo" then
		for _, segment in ipairs(makeBambooGrowthSegments(model, bambooCanes)) do
			table.insert(records, segment)
		end
	end
	return {
		Model = model,
		Records = records,
		Stump = stump,
		SpeciesId = speciesId,
		LastStep = -1,
	}
end

function GrowthVisuals.Apply(state, fraction, allowUnparented)
	if not state or not state.Model
		or (not allowUnparented and not state.Model.Parent) then return false end
	if type(fraction) ~= "number" or fraction ~= fraction then return false end
	fraction = math.clamp(fraction, 0, 1)
	local step = math.min(GrowthVisuals.STEPS,
		math.floor(fraction * GrowthVisuals.STEPS + 1e-6))
	if step == state.LastStep then return true end
	state.LastStep = step

	for _, record in ipairs(state.Records) do
		local part = record.Part
		if part.Parent then
			local unlockStep = math.ceil(record.At * GrowthVisuals.STEPS)
			local hiddenAgain = record.HideAt
				and step >= math.ceil(record.HideAt * GrowthVisuals.STEPS)
			local visible = step >= unlockStep and not hiddenAgain
			part.Transparency = if visible then record.Transparency else 1
			part.CanCollide = visible and record.CanCollide
		end
	end

	local stumpCutoff = if state.SpeciesId == "Bamboo" then 0.17 else 0.28
	local showStump = step < math.ceil(stumpCutoff * GrowthVisuals.STEPS)
	for _, stumpPart in ipairs(state.Stump or {}) do
		if stumpPart.Parent then
			stumpPart.Transparency = if showStump then 0 else 1
		end
	end
	state.Model:SetAttribute("GroveGrowthVisualStep", step)
	state.Model:SetAttribute("GroveGrowthProgress", step / GrowthVisuals.STEPS)
	return true
end

return GrowthVisuals
