local LogPickupBounds = {}

local SURVIVING_BARK_ATTRIBUTE = "HarvestableBarkAccent"

local function projectPartCorners(boundsFrame, part, bounds)
	local partFrame = part.CFrame
	local halfSize = part.Size * 0.5
	for xSign = -1, 1, 2 do
		for ySign = -1, 1, 2 do
			for zSign = -1, 1, 2 do
				local worldCorner = partFrame:PointToWorldSpace(Vector3.new(
					halfSize.X * xSign,
					halfSize.Y * ySign,
					halfSize.Z * zSign
				))
				local localCorner = boundsFrame:PointToObjectSpace(worldCorner)
				bounds.Minimum = Vector3.new(
					math.min(bounds.Minimum.X, localCorner.X),
					math.min(bounds.Minimum.Y, localCorner.Y),
					math.min(bounds.Minimum.Z, localCorner.Z)
				)
				bounds.Maximum = Vector3.new(
					math.max(bounds.Maximum.X, localCorner.X),
					math.max(bounds.Maximum.Y, localCorner.Y),
					math.max(bounds.Maximum.Z, localCorner.Z)
				)
			end
		end
	end
end

function LogPickupBounds.GetBoundingBox(model)
	local fullFrame, fullSize = model:GetBoundingBox()
	local ok, result = pcall(function()
		if model:GetAttribute("SpeciesId") ~= "Oak"
			or model:GetAttribute("AuthoredHarvestSection") ~= true
			or model:GetAttribute("HasHarvestableBarkAccents") ~= true then
			return nil
		end

		local descendants = model:GetDescendants()
		local hasTaggedBarkAccent = false
		for _, descendant in ipairs(descendants) do
			if descendant:IsA("BasePart")
				and descendant:GetAttribute(SURVIVING_BARK_ATTRIBUTE) == true then
				hasTaggedBarkAccent = true
				break
			end
		end
		if not hasTaggedBarkAccent then return nil end

		local bounds = {
			Minimum = Vector3.new(math.huge, math.huge, math.huge),
			Maximum = Vector3.new(-math.huge, -math.huge, -math.huge),
			PartCount = 0,
		}
		for _, descendant in ipairs(descendants) do
			if descendant:IsA("BasePart")
				and descendant:GetAttribute(SURVIVING_BARK_ATTRIBUTE) ~= true then
				bounds.PartCount += 1
				projectPartCorners(fullFrame, descendant, bounds)
			end
		end
		if bounds.PartCount == 0 then return nil end

		local size = bounds.Maximum - bounds.Minimum
		local center = (bounds.Minimum + bounds.Maximum) * 0.5
		return {
			Frame = fullFrame * CFrame.new(center),
			Size = size,
		}
	end)

	if not ok or not result then
		return fullFrame, fullSize
	end
	return result.Frame, result.Size
end

return LogPickupBounds
