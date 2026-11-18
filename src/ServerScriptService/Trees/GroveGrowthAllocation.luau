-- Reusable, deterministic geometry-to-timeline allocator for Grove plants.
-- A component is simply "trunk", "branches", or "leaves". A plant can
-- override individual parts using GroveGrowthRole, GroveGrowthOrder,
-- GroveGrowthStart and GroveGrowthFinish attributes. No fixed 40-step grid.
--
-- The renderer samples this normalized plan at the number of configured
-- milestones derived from each tree's actual, persisted maturity deadline.
local Allocation = {}

-- Deliberately simple overlapping windows. A six-step tree can devote
-- roughly three updates to wood, one/two to branches and two to foliage.
-- Branches may start as the top of the trunk finishes, foliage as branches
-- extend. Adjust ONE profile here, not the part timings in the renderer.
Allocation.DefaultWindows = {
	trunk = { Start = 0, Finish = 0.50 },
	branches = { Start = 0.50, Finish = 0.80 },
	leaves = { Start = 0.68, Finish = 1.00 },
}

local function finite(value)
	return type(value) == "number" and value == value
		and value > -math.huge and value < math.huge
end

local function windowFor(role)
	return Allocation.DefaultWindows[role] or Allocation.DefaultWindows.trunk
end

local function originalFootHeight(part, model)
	local foot = part.CFrame * CFrame.new(0, -part.Size.Y * 0.5, 0)
	return model:GetPivot():PointToObjectSpace(foot.Position).Y
end

local function originalTopHeight(part, model)
	local top = part.CFrame * CFrame.new(0, part.Size.Y * 0.5, 0)
	return model:GetPivot():PointToObjectSpace(top.Position).Y
end

local function localHeight(part, model)
	return model:GetPivot():PointToObjectSpace(part.Position).Y
end

local function compareParts(a, b)
	local left = a.Part:GetAttribute("GroveGrowthOrder")
	local right = b.Part:GetAttribute("GroveGrowthOrder")
	if finite(left) and finite(right) and left ~= right then return left < right end
	if finite(left) and not finite(right) then return true end
	if finite(right) and not finite(left) then return false end
	if a.OrderValue ~= b.OrderValue then return a.OrderValue < b.OrderValue end
	return a.Part.Name < b.Part.Name
end

local function setWindow(record, first, last)
	first = math.clamp(first, 0, 1)
	last = math.clamp(last, first, 1)
	record.At = first
	record.NativeAt = last
	record.GrowDuration = math.max(0.0001, last - first)
end

local function allocateTrunk(records, model)
	if #records == 0 then return nil end
	local low, high = math.huge, -math.huge
	for _, record in ipairs(records) do
		local bottom = originalFootHeight(record.Part, model)
		local top = originalTopHeight(record.Part, model)
		record.OrderValue = math.min(bottom, top)
		low = math.min(low, bottom, top)
		high = math.max(high, bottom, top)
	end
	table.sort(records, compareParts)
	local span = math.max(0.001, high - low)
	local window = Allocation.DefaultWindows.trunk
	local authoredOrder = false
	local totalLength = 0
	for _, record in ipairs(records) do
		if finite(record.Part:GetAttribute("GroveGrowthOrder")) then
			authoredOrder = true
		end
		totalLength += record.Part.Size.Y
	end
	local orderedLength = 0
	for _, record in ipairs(records) do
		if record.Bundle == "BambooCulms"
			or record.Part:GetAttribute("GroveGrowthBundle") == "BambooCulms" then
			-- Existing five-cane Bamboo visual is intentionally one bundle,
			-- not five separate trunks popping up in sequence.
			setWindow(record, window.Start + 0.06, window.Finish)
		elseif authoredOrder then
			-- For a strange curved/tapered structure, authors may supply a
			-- deliberate sequence. Each source consumes its proportional
			-- LENGTH of the trunk's total window; no geometry slicing.
			setWindow(record,
				window.Start + orderedLength / totalLength
					* (window.Finish - window.Start),
				window.Start + (orderedLength + record.Part.Size.Y) / totalLength
					* (window.Finish - window.Start))
		else
			local bottom = math.min(originalFootHeight(record.Part, model),
				originalTopHeight(record.Part, model))
			local top = math.max(originalFootHeight(record.Part, model),
				originalTopHeight(record.Part, model))
			setWindow(record,
				window.Start + (bottom - low) / span * (window.Finish - window.Start),
				window.Start + (top - low) / span * (window.Finish - window.Start))
		end
		orderedLength += record.Part.Size.Y
	end
	return { Low = low, High = high }
end

local function allocateBranches(records, model)
	if #records == 0 then return end
	for _, record in ipairs(records) do
		local attachment = record.Part:GetAttribute("TrunkAnchorLocal")
		record.OrderValue = if typeof(attachment) == "Vector3"
			then attachment.Y else localHeight(record.Part, model)
	end
	table.sort(records, compareParts)
	local totalLength = 0
	for _, record in ipairs(records) do
		totalLength += if record.Axis == "X" then record.Part.Size.X else record.Part.Size.Y
	end
	local window = Allocation.DefaultWindows.branches
	local distance = 0
	for _, record in ipairs(records) do
		local length = if record.Axis == "X" then record.Part.Size.X else record.Part.Size.Y
		setWindow(record,
			window.Start + distance / totalLength * (window.Finish - window.Start),
			window.Start + (distance + length) / totalLength * (window.Finish - window.Start))
		distance += length
	end
end

local function allocateLeaves(records, model)
	if #records == 0 then return end
	for _, record in ipairs(records) do
		record.OrderValue = localHeight(record.Part, model)
	end
	table.sort(records, compareParts)
	local window = Allocation.DefaultWindows.leaves
	local span = window.Finish - window.Start
	-- Stagger foliage starts from lower to higher clusters, allowing each
	-- leaf to expand for more than one tiny slice of a short growth cycle.
	-- Leaves overlap rather than consuming N separate milestone updates.
	for index, record in ipairs(records) do
		local rank = if #records == 1 then 0 else (index - 1) / (#records - 1)
		setWindow(record,
			window.Start + span * 0.38 * rank,
			window.Start + span * (0.62 + 0.38 * rank))
	end
end

function Allocation.Assign(records, model)
	local trunk = {}
	local branches = {}
	local leaves = {}
	local decorative = {}
	for _, record in ipairs(records) do
		if record.Role == "leaves" then
			table.insert(leaves, record)
		elseif record.Axis and record.Role == "branches" then
			table.insert(branches, record)
		elseif record.Axis then
			table.insert(trunk, record)
		else
			table.insert(decorative, record)
		end
	end

	local trunkBounds = allocateTrunk(trunk, model)
	allocateBranches(branches, model)
	allocateLeaves(leaves, model)

	local coreEndBySection = {}
	for _, record in ipairs(trunk) do
		if record.Part:GetAttribute("HarvestableCore") == true then
			local index = record.Part:GetAttribute("HarvestSectionIndex")
			if type(index) == "number" then
				coreEndBySection[index] = math.max(
					coreEndBySection[index] or 0, record.NativeAt)
			end
		end
	end

	for _, record in ipairs(decorative) do
		local role = record.Role
		local window = windowFor(role)
		local at
		if role == "trunk" and trunkBounds then
			local positionY = localHeight(record.Part, model)
			local fraction = math.clamp((positionY - trunkBounds.Low) /
				math.max(0.001, trunkBounds.High - trunkBounds.Low), 0, 1)
			at = window.Start + fraction * (window.Finish - window.Start)
		elseif role == "branches" then
			at = window.Start + (window.Finish - window.Start) * 0.6
		else
			at = window.Start
		end
		-- A decorative strip should never float ahead of its supporting
		-- procedural Oak core: release at or after the source core has risen.
		local part = record.Part
		local section = part:GetAttribute("HarvestSectionIndex")
			or part:GetAttribute("CoreSectionIndex")
		if (part:GetAttribute("HarvestableBarkAccent") == true
			or type(part:GetAttribute("CoreSectionIndex")) == "number")
			and type(section) == "number" and coreEndBySection[section] then
			at = math.max(at, coreEndBySection[section])
		end
		setWindow(record, at, at)
	end

	-- Per-Part overrides are optional for unusual shapes and future plants.
	-- The same generic renderer handles authored groupings and geometry.
	for _, record in ipairs(records) do
		local explicitStart = record.Part:GetAttribute("GroveGrowthStart")
		local explicitFinish = record.Part:GetAttribute("GroveGrowthFinish")
		if finite(explicitStart) and finite(explicitFinish)
			and explicitStart >= 0 and explicitFinish <= 1
			and explicitStart <= explicitFinish then
			setWindow(record, explicitStart, explicitFinish)
		end
	end
	return records
end

return Allocation
