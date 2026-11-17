-- Additive Grove-growth visuals. This reveal layer is cosmetic only:
-- the server-owned Grove service retains genetics, UIDs, timers and harvests.
--
-- Oak retains its approved bottom-up procedural growth unchanged.
-- Ironwood uses explicit supporting-trunk order, not jittered piece positions.
-- Bamboo grows all five canes in synchronized vertical segments.
local SpeciesVisuals = require(game.ServerStorage.SpeciesVisuals)

local GrowthVisuals = {}
GrowthVisuals.STEPS = 40
-- A leaf cluster starts as a small cuboid and grows to its source size
-- over several updates. No leaf geometry needs to be sliced or replaced.
GrowthVisuals.LEAF_EXPAND_DURATION = 0.17
GrowthVisuals.LEAF_MIN_SIZE = 0.05

-- The native final bamboo canes replace five growing visual copies together.
local BAMBOO_FIRST_LAYER_AT = 0.12
local BAMBOO_FULL_STALKS_AT = 0.62
local WOOD_EXPAND_DURATION = 0.11
local BRANCH_EXPAND_DURATION = 0.09

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
			-- Five native canes become visible together after their own
			-- bottom-anchored visual copies finish extending upward.
			return BAMBOO_FULL_STALKS_AT
		elseif string.match(name, "^BambooNode%d+_%d+$") then
			-- Tie each decorative node to the height that the synchronized
			-- growing cane has already reached. No floating rings.
			local layerIndex = tonumber(string.match(name, "_(%d+)$")) or 1
			return BAMBOO_FIRST_LAYER_AT
				+ (BAMBOO_FULL_STALKS_AT - BAMBOO_FIRST_LAYER_AT)
				* (layerIndex * 0.25)
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

local function growingLeafSize(size, fraction)
	-- Prevent invalid extremely small block dimensions while retaining the
	-- exact authored leaf shape and aspect ratio by the final growth tick.
	local factor = math.clamp(fraction, 0.08, 1)
	return Vector3.new(
		math.min(size.X, math.max(GrowthVisuals.LEAF_MIN_SIZE, size.X * factor)),
		math.min(size.Y, math.max(GrowthVisuals.LEAF_MIN_SIZE, size.Y * factor)),
		math.min(size.Z, math.max(GrowthVisuals.LEAF_MIN_SIZE, size.Z * factor))
	)
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
	body.CastShadow = true -- Preserve the approved Oak stump's original shadow.

	local cut = Instance.new("Part")
	cut.Name = prefix .. "CutEnd"
	cut.Size = Vector3.new(width * 0.92, math.max(0.055, width * 0.045), width * 0.92)
	cut.CFrame = centerCFrame * CFrame.new(0, height + cut.Size.Y * 0.5, 0)
	cut.Color = palette.CutEnd
	cut.Material = Enum.Material.SmoothPlastic
	attachVisualPart(cut, model)
	cut.CastShadow = true
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

-- Only prominent, structural wood gets height/length animation.
-- Small decorative bark blocks keep their existing reveal timing so a
-- hundred tiny pieces don't each need a temporary visual part.
local function growthAxis(part, model, speciesId)
	if not part:IsA("Part") or part.Shape ~= Enum.PartType.Block then return nil end
	local name = part.Name
	if speciesId == "Bamboo" and (name == "BambooCore"
		or string.match(name, "^BambooStalk%d+$")) then
		return "Y"
	end
	if part:GetAttribute("HarvestableCore") == true then return "Y" end
	if speciesId == "Ironwood" then
		if name == "Bark" or string.match(name, "^BarkBrick%d+$") then return "Y" end
		if name == "BoughLeft" or name == "BoughRight" then return "X" end
	end
	if name == "Bark" or string.match(name, "^BarkBrick%d+$") then return "Y" end
	if classify(part, model) == "branches" then
		return "Y" -- procedural Oak branches use their LOCAL Y axis
	end
	return nil
end

local function newGrowthProxy(part)
	-- Don't Clone() the original: it may contain WeldConstraints that would
	-- move the actual tree assembly. Render one simple collisionless copy
	-- per major wood piece; no per-stud segmentation.
	local proxy = Instance.new("Part")
	proxy.Name = "GroveGrowthProxy"
	proxy.Shape = part.Shape
	proxy.Color = part.Color
	proxy.Material = part.Material
	proxy.Reflectance = part.Reflectance
	proxy.Transparency = 1
	proxy.Size = part.Size
	proxy.CFrame = part.CFrame
	proxy.CastShadow = part.CastShadow
	proxy.TopSurface = part.TopSurface
	proxy.BottomSurface = part.BottomSurface
	proxy.LeftSurface = part.LeftSurface
	proxy.RightSurface = part.RightSurface
	proxy.FrontSurface = part.FrontSurface
	proxy.BackSurface = part.BackSurface
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CanTouch = false
	proxy.CanQuery = false
	proxy:SetAttribute("GroveGrowthSource", part.Name)
	proxy:SetAttribute("GroveGrowthAxis", "Y")
	if part.Name == "BambooCore" or string.match(part.Name, "^BambooStalk%d+$") then
		proxy:SetAttribute("GroveGrowthCane", part.Name)
	end
	proxy.Parent = part:FindFirstAncestorOfClass("Model")
	return proxy
end

local function resizeWoodFromBase(record, alpha)
	local proxy = record.Proxy
	if not proxy or not proxy.Parent then return end
	local source = record.Part
	if not source or not source.Parent then return end
	local axis = record.Axis
	local originalSize = record.FullSize
	local factor = math.clamp(alpha, 0.025, 1)
	local newSize
	local offset
	if axis == "X" then
		newSize = Vector3.new(originalSize.X * factor, originalSize.Y, originalSize.Z)
		-- Left bough grows toward -X; right bough grows toward +X.
		local direction = if source.Name == "BoughLeft" then -1 else 1
		offset = Vector3.new(-direction * originalSize.X * (1 - factor) * 0.5, 0, 0)
	else
		newSize = Vector3.new(originalSize.X, originalSize.Y * factor, originalSize.Z)
		offset = Vector3.new(0, -originalSize.Y * (1 - factor) * 0.5, 0)
	end
	proxy.Size = newSize
	-- Position follows the ORIGINAL source CFrame, preserving its local
	-- orientation. A growing rotated branch still extends from its base.
	proxy.CFrame = source.CFrame * CFrame.new(offset)
end

function GrowthVisuals.Prepare(model, speciesId)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return nil end
	local height = model:GetExtentsSize().Y
	local bambooCanes = if speciesId == "Bamboo" then getBambooCanes(model) else {}
	local records = {}
	local latestTrunkFinish = 0

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if speciesId == "Ironwood" and part.Name == "BarkStud" then
				-- Decorative dots are deferred, not released as floating
				-- particles during the visible trunk growth sequence.
				part.Transparency = 1
				part.CanCollide = false
			else
				local unlockAt = timeForPart(part, model, height, speciesId)
				if unlockAt then
					local record = {
						Part = part,
						At = unlockAt,
						Transparency = part.Transparency,
						CanCollide = part.CanCollide,
					}
					local role = classify(part, model)
					if role == "leaves" then
						record.At = math.clamp(
							0.60 + (unlockAt - 0.63) * 0.58, 0.60, 0.81)
						record.GrowDuration = GrowthVisuals.LEAF_EXPAND_DURATION
						record.FullSize = part.Size
					else
						local axis = growthAxis(part, model, speciesId)
						if axis then
							local isBambooCane = speciesId == "Bamboo"
							local isBranch = role == "branches"
							local length = if axis == "X" then part.Size.X else part.Size.Y
							-- Small decorative or stubby authored parts can
							-- retain their plain reveal; enormous parts never
							-- pop in whole even if the tree has only 2 pieces.
							if isBambooCane or length >= 1.6 then
								record.Axis = axis
								record.FullSize = part.Size
								record.At = if isBambooCane then BAMBOO_FIRST_LAYER_AT
									else unlockAt
								record.GrowDuration = if isBambooCane
									then BAMBOO_FULL_STALKS_AT - BAMBOO_FIRST_LAYER_AT
									else if isBranch then BRANCH_EXPAND_DURATION
									else WOOD_EXPAND_DURATION
								record.NativeAt = record.At + record.GrowDuration
								record.Proxy = newGrowthProxy(part)
								record.Proxy:SetAttribute("GroveGrowthAxis", axis)
								if not isBranch and not isBambooCane then
									latestTrunkFinish = math.max(latestTrunkFinish, record.NativeAt)
								end
							end
						end
					end
					table.insert(records, record)
				end
			end
		end
	end

	-- Complete the trunk before branches extend. This preserves the Oak
	-- visual order the user liked while avoiding detached branch tips on
	-- a still-rising multi-section trunk.
	if latestTrunkFinish > 0 then
		for _, record in ipairs(records) do
			if record.Proxy and classify(record.Part, model) == "branches" then
				record.At = math.max(record.At, latestTrunkFinish + 0.01)
				record.NativeAt = math.min(1, record.At + record.GrowDuration)
			end
		end
	end

	if speciesId == "Oak" then
		local lastCoreVisibleAtBySection = {}
		for _, record in ipairs(records) do
			local part = record.Part
			local section = part:GetAttribute("HarvestSectionIndex")
			if part:GetAttribute("HarvestableCore") == true
				and type(section) == "number" then
				lastCoreVisibleAtBySection[section] = math.max(
					lastCoreVisibleAtBySection[section] or 0,
					record.NativeAt or record.At
				)
			end
		end
		for _, record in ipairs(records) do
			local part = record.Part
			if part:GetAttribute("HarvestableBarkAccent") == true then
				local section = part:GetAttribute("HarvestSectionIndex")
					or part:GetAttribute("CoreSectionIndex")
				local coreFinishedAt = lastCoreVisibleAtBySection[section]
				if coreFinishedAt then
					-- Wait for the CORE to finish extending, not merely
					-- when its initial sprout first becomes visible.
					record.At = math.max(record.At,
						coreFinishedAt + 1 / GrowthVisuals.STEPS)
				end
			end
		end
	end

	local stump = addStump(model, speciesId, bambooCanes)
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
	local current = step / GrowthVisuals.STEPS

	for _, record in ipairs(state.Records) do
		local part = record.Part
		if part.Parent then
			local unlockStep = math.ceil(record.At * GrowthVisuals.STEPS)
			local hideAgain = record.HideAt
				and step >= math.ceil(record.HideAt * GrowthVisuals.STEPS)
			if record.Proxy then
				-- The original part is welded/anchored to the genuine tree
				-- and remains untouched until its cosmetic copy has grown.
				-- These proxy Size and CFrame updates occur on the SERVER,
				-- therefore every nearby client sees the same growing wood.
				local endStep = math.ceil(record.NativeAt * GrowthVisuals.STEPS)
				local finished = step >= endStep
				part.Transparency = if finished then record.Transparency else 1
				part.CanCollide = finished and record.CanCollide
				local proxy = record.Proxy
				if proxy and proxy.Parent then
					if finished then
						-- The real full-size model is now visible. Release the
						-- temporary anchored copy, so mature Grove trees don't
						-- retain duplicate hidden trunk/branch instances.
						proxy:Destroy()
					else
						local growing = step >= unlockStep
						proxy.Transparency = if growing then record.Transparency else 1
						if growing then
							local alpha = math.clamp(
								(current - record.At) / record.GrowDuration, 0, 1)
							resizeWoodFromBase(record, alpha)
						end
					end
				end
			else
				local visible = step >= unlockStep and not hideAgain
				part.Transparency = if visible then record.Transparency else 1
				part.CanCollide = visible and record.CanCollide
				if record.FullSize and record.GrowDuration then
					-- Leaves retain the existing in-place cuboid expansion.
					local alpha = if visible then
						math.clamp((current - record.At) / record.GrowDuration, 0, 1)
						else 0
					part.Size = if alpha >= 1 then record.FullSize
						else growingLeafSize(record.FullSize, alpha)
				end
			end
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
	state.Model:SetAttribute("GroveGrowthProgress", current)
	return true
end

return GrowthVisuals
