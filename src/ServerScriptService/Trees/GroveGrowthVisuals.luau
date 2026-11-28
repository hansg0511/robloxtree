-- Server-replicated Grove presentation: render the SAME mature model through
-- a reusable allocation plan sampled at five-second visual milestones.
-- Original welded/harvest geometry remains intact; visual copies are temporary.
local SpeciesVisuals = require(game.ServerStorage.SpeciesVisuals)
local GroveGrowthRules = require(game.ServerScriptService.Grove.GroveGrowthRules)
local Allocation = require(script.Parent.GroveGrowthAllocation)

local GrowthVisuals = {}
GrowthVisuals.LEAF_MIN_SIZE = 0.05

local function inNamedFolder(part, model, allowed)
	local parent = part.Parent
	while parent and parent ~= model do
		if allowed[parent.Name] then return true end
		parent = parent.Parent
	end
	return false
end

local function classify(part, model)
	local configured = part:GetAttribute("GroveGrowthRole")
	if configured == "trunk" or configured == "branches"
		or configured == "leaves" then return configured end
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
	if not part:IsA("Part") and not part:IsA("MeshPart") then return nil end
	if part:IsA("Part") and part.Shape ~= Enum.PartType.Block then return nil end
	local explicitAxis = part:GetAttribute("GroveGrowthAxis")
	if explicitAxis == "X" or explicitAxis == "Y"
		or explicitAxis == "Z" then return explicitAxis end
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

local function newGrowthProxy(part, axis)
	-- No clones of live WeldConstraints or scripts are parented. A MeshPart
	-- may be visually distorted while extended, which is acceptable for
	-- intentionally cartoony growth; complex assets can later use segments.
	local proxy
	if part:IsA("MeshPart") then
		proxy = part:Clone()
		for _, child in ipairs(proxy:GetChildren()) do child:Destroy() end
	else
		proxy = Instance.new("Part")
		proxy.Shape = part.Shape
	end
	proxy.Name = "GroveGrowthProxy"
	proxy.Color = part.Color
	proxy.Material = part.Material
	proxy.Reflectance = part.Reflectance
	proxy.Transparency = 1
	proxy.Size = part.Size
	proxy.CFrame = part.CFrame
	proxy.CastShadow = part.CastShadow
	if proxy:IsA("Part") then
		proxy.TopSurface = part.TopSurface
		proxy.BottomSurface = part.BottomSurface
		proxy.LeftSurface = part.LeftSurface
		proxy.RightSurface = part.RightSurface
		proxy.FrontSurface = part.FrontSurface
		proxy.BackSurface = part.BackSurface
	end
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CanTouch = false
	proxy.CanQuery = false
	proxy:SetAttribute("GroveGrowthSource", part.Name)
	proxy:SetAttribute("GroveGrowthAxis", axis)
	if part.Name == "BambooCore" or string.match(part.Name, "^BambooStalk%d+$") then
		proxy:SetAttribute("GroveGrowthCane", part.Name)
	end
	proxy.Parent = part:FindFirstAncestorOfClass("Model")
	return proxy
end

local function resizeWoodFromBase(record, alpha)
	local proxy = record.Proxy
	local source = record.Part
	if not proxy or not proxy.Parent or not source or not source.Parent then return end
	local originalSize = record.FullSize
	local factor = math.clamp(alpha, 0.025, 1)
	local axis = record.Axis
	local sign = record.Part:GetAttribute("GroveGrowthDirection")
	if sign ~= -1 and sign ~= 1 then
		sign = if source.Name == "BoughLeft" then -1 else 1
	end
	local newSize
	local offset
	if axis == "X" then
		newSize = Vector3.new(originalSize.X * factor, originalSize.Y, originalSize.Z)
		offset = Vector3.new(-sign * originalSize.X * (1 - factor) * 0.5, 0, 0)
	elseif axis == "Z" then
		newSize = Vector3.new(originalSize.X, originalSize.Y, originalSize.Z * factor)
		offset = Vector3.new(0, 0, -sign * originalSize.Z * (1 - factor) * 0.5)
	else
		newSize = Vector3.new(originalSize.X, originalSize.Y * factor, originalSize.Z)
		offset = Vector3.new(0, -sign * originalSize.Y * (1 - factor) * 0.5, 0)
	end
	proxy.Size = newSize
	proxy.CFrame = source.CFrame * CFrame.new(offset)
end

function GrowthVisuals.Prepare(model, speciesId, totalSteps)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return nil end
	if type(totalSteps) ~= "number" or totalSteps < 1 or totalSteps % 1 ~= 0 then
		totalSteps = GroveGrowthRules.MATURITY_SECONDS
			/ GroveGrowthRules.SECONDS_PER_VISUAL_STEP
	end
	local bambooCanes = if speciesId == "Bamboo" then getBambooCanes(model) else {}
	local records = {}

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("AlwaysInvisible") ~= true
			and part.Transparency < 0.99 then
			if speciesId == "Ironwood" and part.Name == "BarkStud" then
				part.Transparency = 1
				part.CanCollide = false
			else
				local role = classify(part, model)
				local axis = if role == "leaves" then nil
					else growthAxis(part, model, speciesId)
				local record = {
					Part = part,
					Role = role,
					Axis = axis,
					Transparency = part.Transparency,
					CanCollide = part.CanCollide,
				}
				if speciesId == "Bamboo" and (part.Name == "BambooCore"
					or string.match(part.Name, "^BambooStalk%d+$")) then
					record.Bundle = "BambooCulms"
				end
				table.insert(records, record)
			end
		end
	end

	-- Build each growth window ONCE per model using original mature geometry.
	-- Individual parts can override the default role, order, local axis,
	-- direction, or window through explicit authored attributes.
	Allocation.Assign(records, model)
	for _, record in ipairs(records) do
		if record.Axis then
			record.FullSize = record.Part.Size
			record.Proxy = newGrowthProxy(record.Part, record.Axis)
		elseif record.Role == "leaves" then
			record.FullSize = record.Part.Size
		end
	end
	local stump = addStump(model, speciesId, bambooCanes)
	return {
		Model = model,
		Records = records,
		Stump = stump,
		SpeciesId = speciesId,
		TotalSteps = totalSteps,
		LastStep = -1,
	}
end

function GrowthVisuals.Apply(state, fraction, allowUnparented)
	if not state or not state.Model
		or (not allowUnparented and not state.Model.Parent) then return false end
	if type(fraction) ~= "number" or fraction ~= fraction then return false end
	local total = state.TotalSteps
	local step = math.clamp(math.floor(math.clamp(fraction, 0, 1) * total + 1e-6), 0, total)
	if step == state.LastStep then return true end
	state.LastStep = step
	local current = step / total

	for _, record in ipairs(state.Records) do
		local part = record.Part
		if part.Parent then
			local startStep = math.ceil(record.At * total - 1e-6)
			local endStep = math.ceil(record.NativeAt * total - 1e-6)
			if record.Proxy then
				local finished = step >= endStep
				part.Transparency = if finished then record.Transparency else 1
				part.CanCollide = finished and record.CanCollide
				local proxy = record.Proxy
				if proxy and proxy.Parent then
					if finished then
						-- Free temporary copies; no duplicates remain on
						-- mature trees and the welded originals never moved.
						proxy:Destroy()
					else
						local growing = step > 0 and step >= startStep
						proxy.Transparency = if growing then record.Transparency else 1
						if growing then
							local alpha = math.clamp((current - record.At)
								/ record.GrowDuration, 0, 1)
							resizeWoodFromBase(record, alpha)
						end
					end
				end
			else
				local visible = step > 0 and step >= startStep
				part.Transparency = if visible then record.Transparency else 1
				part.CanCollide = visible and record.CanCollide
				if record.FullSize then
					local alpha = if visible then
						math.clamp((current - record.At) / record.GrowDuration, 0, 1)
						else 0
					part.Size = if alpha >= 1 then record.FullSize
						else growingLeafSize(record.FullSize, alpha)
				end
			end
		end
	end

	-- Stump is the only visible structure at step zero. At first growth
	-- milestone, its permanent trunk starts extending from the ground.
	local showStump = step == 0
	for _, part in ipairs(state.Stump or {}) do
		if part.Parent then part.Transparency = if showStump then 0 else 1 end
	end
	state.Model:SetAttribute("GroveGrowthVisualStep", step)
	state.Model:SetAttribute("GroveGrowthVisualTotalSteps", total)
	state.Model:SetAttribute("GroveGrowthProgress", current)
	return true
end

return GrowthVisuals
