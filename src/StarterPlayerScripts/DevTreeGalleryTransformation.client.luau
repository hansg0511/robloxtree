-- Studio-only cosmetic harvest and pickup showcase; no gameplay state is changed.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PromptService = game:GetService("ProximityPromptService")
local FX = require(script.Parent:WaitForChild("Inventory"):WaitForChild("Modules"):WaitForChild("LogTransformationFX"))
local CarryLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarryLayout"))
local player = Players.LocalPlayer
local DEBUG_OVERFLOW_SHOWCASE = false

-- Prototype-only tuning. These values do not change production.
local CONFIG = {
	Fall = 1.35, ImpactPause = 0.12, Foliage = 0.48,
	Breakup = 0.52, BreakupStagger = 0.14, BreakupPop = 1.5, BreakupTurns = 1,
	StreamingTimeout = 12,
	LiftDuration = 0.16, CompressionDuration = 0.24, RevealDuration = 0.18,
	StarterOakPickup = { LiftDuration = 0.22, CompressionDuration = 0.63, RotationTurns = 1 },
	LiftHeight = 1.1, RotationTurns = 0.35, ChipCount = 8,
	HomingSpeed = 24, HomingAcceleration = 4, AccelerationDelay = 1,
	MaxHomingSpeed = 60, MaxHomingDuration = 8, OverflowHomingDuration = 60,
	ArrivalRadius = 2.5, OverflowArrivalRadius = 0.5,
	CarrySettleDuration = 0.22, OverflowSettleDuration = 0.45, PileSpacing = 0.08,
}
local session, controls
local controlsByPlayground = setmetatable({}, { __mode = "k" })
local controlsSetup = setmetatable({}, { __mode = "k" })
local startingByPlayground = setmetatable({}, { __mode = "k" })
local galleryConnections = setmetatable({}, { __mode = "k" })
local selectedMode = "Backpack"

local function debugEvent(event, detail)
	if DEBUG_OVERFLOW_SHOWCASE then
		print(("[DevHarvestPickup] %s %s"):format(event, detail or ""))
	end
end

local function status(message)
	if controls and controls.status and controls.status.Parent then
		controls.status.Text = "MODE: " .. selectedMode:upper() .. "\n" .. message
	end
end

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function alive(s)
	return session == s and not s.cancelled and s.folder.Parent ~= nil and s.playground.Parent ~= nil
end
local function animate(s, duration, callback)
	local start = os.clock()
	while alive(s) do
		local elapsed = os.clock() - start
		callback(math.clamp(elapsed / math.max(duration, 0.001), 0, 1), elapsed)
		if elapsed >= duration then return true end
		RunService.Heartbeat:Wait()
	end
	return false
end
local function waitForChild(parent, name, timeout, token, className)
	local deadline = os.clock() + timeout
	repeat
		if token and token.cancelled then return nil, "cancelled while waiting for " .. name end
		if not parent or not parent.Parent then return nil, "parent streamed out while waiting for " .. name end
		local child = parent:FindFirstChild(name)
		if child and (not className or child:IsA(className)) then return child end
		if os.clock() >= deadline then break end
		RunService.Heartbeat:Wait()
	until false
	return nil, "timed out waiting for " .. name
end
local function waitForAttribute(instance, name, timeout, token)
	local deadline = os.clock() + timeout
	repeat
		if token and token.cancelled then return nil, "cancelled while waiting for " .. name end
		if not instance or not instance.Parent then return nil, "instance streamed out while waiting for " .. name end
		local value = instance:GetAttribute(name)
		if value ~= nil then return value end
		if os.clock() >= deadline then break end
		RunService.Heartbeat:Wait()
	until false
	return nil, "timed out waiting for attribute " .. name
end
local function countBaseParts(root)
	local count = 0
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("BasePart") then count += 1 end
	end
	return count
end
local function waitForTreeGeometry(tree, timeout, token)
	local expected = tree:GetAttribute("PartCount")
	if typeof(expected) ~= "number" or expected < 1 then return true end
	local deadline = os.clock() + timeout
	repeat
		if token and token.cancelled then return false, "cancelled while waiting for generated tree geometry" end
		if not tree.Parent then return false, "generated tree streamed out while waiting for geometry" end
		if countBaseParts(tree) >= expected then return true end
		if os.clock() >= deadline then break end
		RunService.Heartbeat:Wait()
	until false
	return false, ("generated tree geometry timed out (%d/%d parts)"):format(countBaseParts(tree), expected)
end
local function extentAlong(frame, size, axis)
	return 0.5 * (math.abs(frame.RightVector:Dot(axis)) * size.X
		+ math.abs(frame.UpVector:Dot(axis)) * size.Y
		+ math.abs(frame.LookVector:Dot(axis)) * size.Z)
end
local function getLongitudinalAxis(frame, size)
	if size.X >= size.Y and size.X >= size.Z then
		return frame.RightVector, 1
	elseif size.Y >= size.Z then
		return frame.UpVector, 2
	end
	return frame.LookVector, 3
end

local CANOPY_FALL = {
	MinimumAngle = math.rad(60), MaximumAngle = math.rad(82),
	GroundClearance = 0.025, BranchClearance = 0.08,
	SectionGap = 0.5, SectionSettlePop = 0.25, BreakupDuration = 0.75,
}
local FALLBACK_CONTACT = {
	MaximumAngle = math.pi * 0.5, SearchSamples = 90,
	StandingIntersectionTolerance = 0.01, MinimumVisibleFallAngle = math.rad(5),
}
local CORNER_SIGNS = { -1, 1 }
local function collectVisibleBounds(root, referencePivot)
	local bounds = {}
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 and part.LocalTransparencyModifier < 1 then
			local half = part.Size * 0.5
			local corners = {}
			for _, xSign in ipairs(CORNER_SIGNS) do
				for _, ySign in ipairs(CORNER_SIGNS) do
					for _, zSign in ipairs(CORNER_SIGNS) do
						table.insert(corners, Vector3.new(half.X * xSign, half.Y * ySign, half.Z * zSign))
					end
				end
			end
			table.insert(bounds, { Frame = referencePivot:ToObjectSpace(part.CFrame), Corners = corners })
		end
	end
	return bounds
end
local function appendBounds(target, source)
	for _, partBounds in ipairs(source) do table.insert(target, partBounds) end
end
local function boundsAt(bounds, pivot)
	if #bounds == 0 then return nil end
	local result = { MinX = math.huge, MaxX = -math.huge, MinY = math.huge }
	for _, partBounds in ipairs(bounds) do
		local frame = pivot * partBounds.Frame
		for _, corner in ipairs(partBounds.Corners) do
			local point = frame:PointToWorldSpace(corner)
			result.MinX = math.min(result.MinX, point.X)
			result.MaxX = math.max(result.MaxX, point.X)
			result.MinY = math.min(result.MinY, point.Y)
		end
	end
	return result
end
local function minimumYAt(bounds, pivot)
	local result = boundsAt(bounds, pivot)
	return result and result.MinY or math.huge
end
local function isProceduralStarterOak(playground, tree)
	if tree and tree:GetAttribute("GeneratedStarterOak") == true then return true end
	if playground:GetAttribute("SourceTreeName") == "ProceduralStarterOakHarvestTree" then return true end
	local sourceName = playground:GetAttribute("SourceTreeName")
	local source = if type(sourceName) == "string" then playground:FindFirstChild(sourceName) else nil
	return source ~= nil and source:GetAttribute("GeneratedStarterOak") == true
end
local function isStarterOakShowcase(playground, tree)
	return playground:GetAttribute("SourceTreeName") == "StarterOakHarvestTree"
		or isProceduralStarterOak(playground, tree)
end
local function solveCanopyLandingAngle(tree, sections, standing)
	local baseBounds = collectVisibleBounds(sections[1].model, standing)
	-- The widened Starter Oak sleeve and root foot are display-only, but they
	-- form the visible base of this layout. Include them with section one so the
	-- canopy contact and branch-clearance checks use the standing silhouette.
	local barkSupport = tree:FindFirstChild("DecorativeBark")
	if barkSupport then
		appendBounds(baseBounds, collectVisibleBounds(barkSupport, standing))
	end
	local foliageBounds = {}
	local branchBounds = {}
	for _, folderName in ipairs({ "FoliageDecorations", "DecorativeBranches", "Leaves" }) do
		local folder = tree:FindFirstChild(folderName)
		if folder then
			local folderBounds = collectVisibleBounds(folder, standing)
			if folderName == "FoliageDecorations" or folderName == "Leaves" then
				appendBounds(foliageBounds, folderBounds)
			elseif folderName == "DecorativeBranches" then
				appendBounds(branchBounds, folderBounds)
			end
		end
	end
	if #baseBounds == 0 then
		return nil, nil, nil, "no visible trunk or root-support bounds"
	end
	if #foliageBounds == 0 then
		return nil, nil, nil, "no visible foliage bounds"
	end
	local function contactGap(angle, bounds)
		local rotatedPivot = standing * CFrame.Angles(0, 0, -angle)
		return minimumYAt(bounds, rotatedPivot) - minimumYAt(baseBounds, rotatedPivot)
	end
	local function branchGap(angle)
		if #branchBounds == 0 then return math.huge end
		return contactGap(angle, branchBounds)
	end
	local low, high = CANOPY_FALL.MinimumAngle, CANOPY_FALL.MaximumAngle
	local previousAngle, previousGap = low, contactGap(low, foliageBounds)
	local validLandings = {}
	local function addLanding(angle)
		local foliageGap = contactGap(angle, foliageBounds)
		local clearance = branchGap(angle)
		if clearance >= CANOPY_FALL.BranchClearance then
			table.insert(validLandings, { Angle = angle, FoliageGap = foliageGap, BranchGap = clearance })
		end
	end
	for sample = 1, 88 do
		local angle = low + (high - low) * sample / 88
		local gap = contactGap(angle, foliageBounds)
		if previousGap == 0 then
			addLanding(previousAngle)
		elseif gap == 0 then
			addLanding(angle)
		elseif (previousGap < 0 and gap > 0) or (previousGap > 0 and gap < 0) then
			local left, right = previousAngle, angle
			local leftGap = previousGap
			for _ = 1, 32 do
				local middle = (left + right) * 0.5
				local middleGap = contactGap(middle, foliageBounds)
				if middleGap == 0 then
					left, right = middle, middle
					break
				elseif (leftGap < 0 and middleGap > 0) or (leftGap > 0 and middleGap < 0) then
					right = middle
				else
					left, leftGap = middle, middleGap
				end
			end
			addLanding((left + right) * 0.5)
		end
		previousAngle, previousGap = angle, gap
	end
	if #validLandings == 0 then
		return nil, nil, nil, "no foliage contact angle retained the required branch clearance"
	end
	-- Prefer a foliage contact angle with the greatest clearance over branches,
	-- so decorative wood cannot become the first visible support.
	table.sort(validLandings, function(a, b) return a.BranchGap > b.BranchGap end)
	local landing = validLandings[1]
	return landing.Angle, landing.FoliageGap, landing.BranchGap, "foliage contact with branch clearance"
end
local function solveFallbackContactAngle(tree, sections, standing)
	local supportBounds = collectVisibleBounds(sections[1].model, standing)
	local barkSupport = tree:FindFirstChild("DecorativeBark")
	if barkSupport then appendBounds(supportBounds, collectVisibleBounds(barkSupport, standing)) end
	if #supportBounds == 0 then
		return nil, nil, nil, "no visible trunk or root-support bounds for fallback contact"
	end
	local foliageBounds, branchBounds, decorationBounds = {}, {}, {}
	for _, folderName in ipairs({ "FoliageDecorations", "DecorativeBranches", "Leaves" }) do
		local folder = tree:FindFirstChild(folderName)
		if folder then
			local folderBounds = collectVisibleBounds(folder, standing)
			if folderName == "DecorativeBranches" then
				appendBounds(branchBounds, folderBounds)
			else
				appendBounds(foliageBounds, folderBounds)
			end
			appendBounds(decorationBounds, folderBounds)
		end
	end
	if #decorationBounds == 0 then
		return nil, nil, nil, "no visible foliage or branch bounds for fallback contact"
	end
	local function contactGapAt(angle)
		local rotatedPivot = standing * CFrame.Angles(0, 0, -angle)
		local supportY = minimumYAt(supportBounds, rotatedPivot)
		return minimumYAt(decorationBounds, rotatedPivot) - supportY
	end
	local function folderGapsAt(angle)
		local rotatedPivot = standing * CFrame.Angles(0, 0, -angle)
		local supportY = minimumYAt(supportBounds, rotatedPivot)
		local foliageGap = if #foliageBounds > 0
			then minimumYAt(foliageBounds, rotatedPivot) - supportY else nil
		local branchGap = if #branchBounds > 0
			then minimumYAt(branchBounds, rotatedPivot) - supportY else math.huge
		return foliageGap, branchGap
	end
	local standingGap = contactGapAt(0)
	if standingGap < -FALLBACK_CONTACT.StandingIntersectionTolerance then
		return nil, nil, nil, ("visible decorations intersect root support while standing (gap=%.3f)"):format(standingGap)
	end
	if math.abs(standingGap) <= FALLBACK_CONTACT.StandingIntersectionTolerance then
		local angle = FALLBACK_CONTACT.MinimumVisibleFallAngle
		local foliageGap, branchGap = folderGapsAt(angle)
		return angle, foliageGap, branchGap,
			("decorations already contact root support while standing; using %.2fdeg minimum fall with full-bounds clearance"):format(math.deg(angle))
	end
	local previousAngle, previousGap = 0, standingGap
	for sample = 1, FALLBACK_CONTACT.SearchSamples do
		local angle = FALLBACK_CONTACT.MaximumAngle * sample / FALLBACK_CONTACT.SearchSamples
		local gap = contactGapAt(angle)
		if previousGap > 0 and gap <= 0 then
			local left, right = previousAngle, angle
			for _ = 1, 32 do
				local middle = (left + right) * 0.5
				local middleGap = contactGapAt(middle)
				if middleGap == 0 then
					left, right = middle, middle
					break
				elseif middleGap > 0 then
					left = middle
				else
					right = middle
				end
			end
			local contactAngle = (left + right) * 0.5
			local foliageGap, branchGap = folderGapsAt(contactAngle)
			return contactAngle, foliageGap, branchGap,
				("first decoration/root-support contact at %.2fdeg"):format(math.deg(contactAngle))
		end
		previousAngle, previousGap = angle, gap
	end
	return nil, nil, nil, "no decoration/root-support contact found through 90deg"
end
local function hide(tree, saved)
	saved = saved or {}
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then
			saved[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	return saved
end
local function restore(saved)
	for part, transparency in pairs(saved) do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
end
local function updateControls()
	for _, candidate in pairs(controlsByPlayground) do
		if candidate.folder.Parent then
			for mode, label in pairs(candidate.labels) do
				label.Text = mode:upper() .. (selectedMode == mode and " [SELECTED]" or "")
			end
		end
	end
	if session then
		for _, item in ipairs(session.sections) do
			if item.prompt and item.prompt.Parent then
				item.prompt.ActionText = "Preview " .. selectedMode .. " Pickup"
				item.prompt.Enabled = session.phase == "ready" and item.state == "available"
			end
		end
	end
end
local function reset(targetControls)
	local s = session
	if not s then
		if targetControls then
			controls = targetControls
			local pending = startingByPlayground[targetControls.playground]
			if pending then pending.cancelled = true end
			for _, prompt in ipairs(targetControls.playground:GetDescendants()) do
				if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("DevTreeGalleryTransformationPrompt") == true then
					prompt.Enabled = true
				end
			end
		end
		updateControls()
		local invalidReason = targetControls and targetControls.playground:GetAttribute("HarvestSectionInvalidReason")
		if targetControls and targetControls.playground:GetAttribute("GeneratedStarterOak") == true
			and targetControls.playground:GetAttribute("HarvestSectionValid") == false then
			status("Harvest unavailable — " .. tostring(invalidReason or "generated trunk dimensions do not meet the harvest limits"))
		else
			status("Ready — press E at the tree")
		end
		return
	end
	controls = controlsByPlayground[s.playground] or controls
	local pending = startingByPlayground[s.playground]
	if pending then pending.cancelled = true end
	session = nil
	s.cancelled = true
	if s.controller then s.controller:Cancel() end
	if s.follow then s.follow:Disconnect() end
	if s.galleryConnection then s.galleryConnection:Disconnect() end
	if s.characterConnection then s.characterConnection:Disconnect() end
	if s.folder then s.folder:Destroy() end
	restore(s.saved)
	if s.fallPrompt.Parent then s.fallPrompt.Enabled = true end
	updateControls()
	status("Showcase reset — press E at the tree")
end
local function detachJoints(tree, sections)
	local membership = {}
	for _, item in ipairs(sections) do
		for _, part in ipairs(item.model:GetDescendants()) do
			if part:IsA("BasePart") then membership[part] = item.model end
		end
	end
	for _, joint in ipairs(tree:GetDescendants()) do
		if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
			local a, b = membership[joint.Part0], membership[joint.Part1]
			if a ~= b and (a or b) then joint:Destroy() end
		end
	end
end
local function snapshotVisibleDecorations(tree)
	local snapshot, foliageSnapshot, decorationCount, foliageCount = {}, {}, 0, 0
	for _, folderName in ipairs({ "Leaves", "FoliageDecorations", "DecorativeBranches", "DecorativeBark" }) do
		local folder = tree:FindFirstChild(folderName)
		if folder then
			for _, part in ipairs(folder:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency < 1 and part.LocalTransparencyModifier < 1 then
					local original = {
						Size = part.Size, Transparency = part.Transparency,
						LocalTransparencyModifier = part.LocalTransparencyModifier,
					}
					snapshot[part] = original
					decorationCount += 1
					if folderName == "Leaves" or folderName == "FoliageDecorations" then
						foliageSnapshot[part] = original
						foliageCount += 1
					end
				end
			end
		end
	end
	return snapshot, foliageSnapshot, decorationCount, foliageCount
end
local function decorationsIntactAtImpact(tree, snapshot)
	for part, original in pairs(snapshot) do
		if not part:IsDescendantOf(tree) or part.Size ~= original.Size
			or part.Transparency ~= original.Transparency
			or part.LocalTransparencyModifier ~= original.LocalTransparencyModifier then
			return false
		end
	end
	return true
end
local function runFall(s)
	local tree = s.tree
	local standing = tree:GetPivot()
	local proceduralStarterOak = isProceduralStarterOak(s.playground, tree)
	local starterOak = isStarterOakShowcase(s.playground, tree)
	local requestsCanopySupport = s.playground:GetAttribute("FallStyle") == "CanopySupported"
	local canopySupported = false
	local landingAngle, foliageGap, branchGap, landingReason
	if proceduralStarterOak then
		landingReason = if requestsCanopySupport then "canopy contact not yet solved" else "showcase did not request canopy support"
		local treeBounds = collectVisibleBounds(tree, standing)
		local supportBounds = collectVisibleBounds(s.sections[1].model, standing)
		local barkSupport = tree:FindFirstChild("DecorativeBark")
		if barkSupport then appendBounds(supportBounds, collectVisibleBounds(barkSupport, standing)) end
		if requestsCanopySupport then
			if #treeBounds == 0 then
				landingReason = "no visible bounds were available for the fall"
			else
				landingAngle, foliageGap, branchGap, landingReason = solveCanopyLandingAngle(tree, s.sections, standing)
				canopySupported = landingAngle ~= nil
			end
		end
		if not canopySupported and requestsCanopySupport then
			local canopyReason = landingReason or "generated canopy could not provide a stable landing"
			local fallbackAngle, fallbackFoliageGap, fallbackBranchGap, fallbackReason =
				solveFallbackContactAngle(tree, s.sections, standing)
			if fallbackAngle then
				landingAngle, foliageGap, branchGap = fallbackAngle, fallbackFoliageGap, fallbackBranchGap
				landingReason = ("canopy solver: %s; fallback: %s"):format(canopyReason, fallbackReason)
			else
				landingAngle = FALLBACK_CONTACT.MaximumAngle
				landingReason = ("canopy solver: %s; fallback: %s; using 90deg full-bounds clearance"):format(
					canopyReason, fallbackReason)
			end
		elseif not canopySupported then
			local fallbackAngle, fallbackFoliageGap, fallbackBranchGap, fallbackReason =
				solveFallbackContactAngle(tree, s.sections, standing)
			if fallbackAngle then
				landingAngle, foliageGap, branchGap = fallbackAngle, fallbackFoliageGap, fallbackBranchGap
				landingReason = ("showcase did not request canopy support; fallback: %s"):format(fallbackReason)
			else
				landingAngle = FALLBACK_CONTACT.MaximumAngle
				landingReason = ("showcase did not request canopy support; fallback: %s; using 90deg full-bounds clearance"):format(
					fallbackReason)
			end
		end
		if #treeBounds == 0 then
			local sectionBounds = {}
			for _, item in ipairs(s.sections) do appendBounds(sectionBounds, collectVisibleBounds(item.model, standing)) end
			treeBounds = sectionBounds
		end
		if #treeBounds == 0 then error("fall has no visible trunk bounds to keep above the ground") end
		local seed = tree:GetAttribute("SourceTreeSeed") or tree:GetAttribute("DevTreeGallerySeed") or tree:GetAttribute("Seed")
		local coreHeight = tree:GetAttribute("SourceCoreHeight") or tree:GetAttribute("CoreHeight") or 0
		local thickness = tree:GetAttribute("SourceBaseThickness") or tree:GetAttribute("TrunkThickness") or 0
		local canopyOffset = tree:GetAttribute("CanopyCentroidOffset") or 0
		local canopyAsymmetry = tree:GetAttribute("CanopyAsymmetryRatio") or 0
		local landingStyle = if canopySupported then "CanopySupported" else "TrunkSideFallback"
		local diagnostic = ("seed=%s style=%s reason=%s finalAngle=%.2fdeg foliageGap=%s branchGap=%s trunk=%.2fx%.2f canopyOffset=%.2f asymmetry=%.2f sections=%d"):format(
			tostring(seed or "n/a"), landingStyle, landingReason or "canopy contact",
			math.deg(landingAngle or FALLBACK_CONTACT.MaximumAngle),
			foliageGap and ("%.3f"):format(foliageGap) or "n/a",
			branchGap and ("%.3f"):format(branchGap) or "n/a", coreHeight, thickness,
			canopyOffset, canopyAsymmetry, #s.sections)
		local decorationSnapshot, foliageSnapshot, decorationCount, foliageCount = snapshotVisibleDecorations(tree)
		local fallAngle = landingAngle or FALLBACK_CONTACT.MaximumAngle
		assert(animate(s, CONFIG.Fall, function(progress)
			local angle = (if canopySupported then landingAngle else fallAngle) * smooth(progress)
			local rotatedPivot = standing * CFrame.Angles(0, 0, -angle)
			-- Keep every visible part above the floor through impact, including the
			-- intact fallback crown and any support parts outside the section model.
			local minimumY = math.min(minimumYAt(treeBounds, rotatedPivot), minimumYAt(supportBounds, rotatedPivot))
			local groundOffset = s.groundY + CANOPY_FALL.GroundClearance - minimumY
			tree:PivotTo(CFrame.new(0, groundOffset, 0) * rotatedPivot)
		end), "fall cancelled")
		local foliageIntact = decorationsIntactAtImpact(tree, foliageSnapshot)
		local decorationsIntact = decorationsIntactAtImpact(tree, decorationSnapshot)
		local foliageIntactText = if foliageCount > 0 then tostring(foliageIntact) else "n/a"
		local decorationsIntactText = if decorationCount > 0 then tostring(decorationsIntact) else "n/a"
		print(("[DevTreeGallery] LANDING_STYLE_SELECTED %s foliageIntactUntilImpact=%s decorationsIntactUntilImpact=%s visibleFoliageParts=%d visibleDecorationParts=%d"):format(
			diagnostic, foliageIntactText, decorationsIntactText, foliageCount, decorationCount))
		if canopySupported then s.standing = standing end
	else
		-- Keep the established Structural Study and full-tree fall exactly as the
		-- regression reference; procedural-only geometry uses the adapted path above.
		canopySupported = requestsCanopySupport
		local treeBounds = if canopySupported then collectVisibleBounds(tree, standing) else nil
		if canopySupported and #treeBounds == 0 then
			warn("[DevTreeGallery] CanopySupported fall has no visible bounds; using the legacy fall")
			canopySupported = false
		end
		if canopySupported then
			local reason
			landingAngle, foliageGap, branchGap, reason = solveCanopyLandingAngle(tree, s.sections, standing)
			if landingAngle then
				s.standing = standing
				debugEvent("CANOPY_LANDING_SOLVED", ("angle=%.2f foliageGap=%.3f branchGap=%.3f reason=%s"):format(
					math.deg(landingAngle), foliageGap or -1, branchGap or -1, reason or "canopy contact"))
				assert(animate(s, CONFIG.Fall, function(progress)
					local angle = landingAngle * smooth(progress)
					local rotatedPivot = standing * CFrame.Angles(0, 0, -angle)
					local minimumY = minimumYAt(treeBounds, rotatedPivot)
					local groundOffset = s.groundY + CANOPY_FALL.GroundClearance - minimumY
					tree:PivotTo(CFrame.new(0, groundOffset, 0) * rotatedPivot)
				end), "fall cancelled")
			else
				warn("[DevTreeGallery] CanopySupported fall has no reliable contact; using the legacy fall: " .. tostring(reason))
				canopySupported = false
			end
		end
		if not canopySupported then
			local baseRadius = s.sections[1].model.PrimaryPart.Size.X * 0.5
			assert(animate(s, CONFIG.Fall, function(progress)
				local angle = smooth(progress) * math.pi * 0.5
				tree:PivotTo(CFrame.new(0, baseRadius * math.sin(angle), 0) * standing * CFrame.Angles(0, 0, -angle))
			end), "fall cancelled")
		end
	end
	assert(animate(s, CONFIG.ImpactPause, function() end), "impact cancelled")
	detachJoints(tree, s.sections)
	local leaves, details = {}, {}
	-- Starter Oak branches are decorative, just like its foliage. Fade both
	-- before its bare trunk sections settle so no bough can look like a support.
	for _, folderName in ipairs({ "Leaves", "FoliageDecorations", "DecorativeBranches", "DecorativeBark" }) do
		local decorationFolder = tree:FindFirstChild(folderName)
		if decorationFolder then
			for _, part in ipairs(decorationFolder:GetDescendants()) do
				if part:IsA("BasePart") then table.insert(leaves, { part, part.Size, part.Transparency }) end
			end
		end
	end
	if canopySupported or proceduralStarterOak then
		local impactPivot = tree:GetPivot()
		local previousCenter, previousHalf
		for index, item in ipairs(s.sections) do
			local startPivot = item.model:GetPivot()
			local boundsFrame, boundsSize = item.model:GetBoundingBox()
			local boundsCenterLocal = startPivot:PointToObjectSpace(boundsFrame.Position)
			local sectionBounds = collectVisibleBounds(item.model, startPivot)
			local boundsFrameLocal = startPivot:ToObjectSpace(boundsFrame)
			local relativePivot = impactPivot:ToObjectSpace(startPivot)
			local targetPivot = standing * CFrame.Angles(0, 0, -math.pi * 0.5) * relativePivot
			local bounds = boundsAt(sectionBounds, targetPivot)
			if bounds then
				targetPivot = CFrame.new(0, s.groundY + CANOPY_FALL.GroundClearance - bounds.MinY, 0) * targetPivot
				bounds = boundsAt(sectionBounds, targetPivot)
				local halfX = (bounds.MaxX - bounds.MinX) * 0.5
				local targetCenter = (bounds.MinX + bounds.MaxX) * 0.5
				if previousCenter then
					targetCenter = math.max(targetCenter, previousCenter + previousHalf + halfX + CANOPY_FALL.SectionGap)
				end
				targetPivot = CFrame.new(targetCenter - (bounds.MinX + bounds.MaxX) * 0.5, 0, 0) * targetPivot
				previousCenter, previousHalf = targetCenter, halfX
			end
			details[index] = {
				Pivot = startPivot, Target = targetPivot, Bounds = sectionBounds,
				BoundsCenterLocal = boundsCenterLocal, BoundsFrameLocal = boundsFrameLocal,
				BoundsSize = boundsSize,
			}
		end
	else
		local _, standardSize = s.destination:GetBoundingBox()
		local standardLength = math.max(standardSize.X, standardSize.Y, standardSize.Z)
		local previousCenter, previousHalf
		for index, item in ipairs(s.sections) do
			local frame, size = item.model:GetBoundingBox()
			local halfX = extentAlong(frame, size, Vector3.xAxis)
			local bottom = frame.Position.Y - extentAlong(frame, size, Vector3.yAxis)
			local targetX = frame.Position.X
			if previousCenter then
				targetX = math.max(targetX, previousCenter + math.max(previousHalf + halfX, standardLength) + 0.8)
			end
			local pivot = item.model:GetPivot()
			local bounds = if starterOak then collectVisibleBounds(item.model, pivot) else nil
			details[index] = { Pivot = pivot,
				Offset = Vector3.new(targetX - frame.Position.X, math.max(0, s.groundY + 0.04 - bottom), 0),
				Bounds = bounds,
				BoundsFrameLocal = if starterOak then pivot:ToObjectSpace(frame) else nil,
				BoundsSize = if starterOak then size else nil }
			previousCenter, previousHalf = targetX, halfX
		end
	end
	local breakupDuration = if (canopySupported and starterOak) or proceduralStarterOak
		then math.max(CONFIG.Breakup, CANOPY_FALL.BreakupDuration) else CONFIG.Breakup
	local duration = math.max(CONFIG.Foliage, breakupDuration + (#s.sections - 1) * CONFIG.BreakupStagger)
	assert(animate(s, duration, function(_, elapsed)
		local leafAlpha = smooth(elapsed / CONFIG.Foliage)
		for _, leaf in ipairs(leaves) do
			if leaf[1].Parent then
				leaf[1].Size = leaf[2] * math.max(0.03, 1 - leafAlpha)
				leaf[1].Transparency = leaf[3] + (1 - leaf[3]) * leafAlpha
			end
		end
		for index, item in ipairs(s.sections) do
			local p = math.clamp((elapsed - (index - 1) * CONFIG.BreakupStagger) / breakupDuration, 0, 1)
			local detail = details[index]
			if canopySupported or proceduralStarterOak then
				local path = detail.Pivot:Lerp(detail.Target, smooth(p))
				local candidate = path
				if starterOak then
					local boundsFrame = path * detail.BoundsFrameLocal
					local longitudinalAxis = getLongitudinalAxis(boundsFrame, detail.BoundsSize)
					local center = boundsFrame.Position
					local spin = CFrame.fromAxisAngle(longitudinalAxis, 2 * math.pi * CONFIG.BreakupTurns * smooth(p))
					candidate = CFrame.new(center) * spin * CFrame.new(-center) * path
				end
				-- Apply floor clearance after the full-turn transform so every
				-- intermediate barrel-roll pose stays above the gallery floor.
				local floorCorrection = math.max(0,
					s.groundY + CANOPY_FALL.GroundClearance - minimumYAt(detail.Bounds, candidate))
				local settlePop = math.sin(math.pi * p) * CANOPY_FALL.SectionSettlePop
				item.model:PivotTo(CFrame.new(0, floorCorrection + settlePop, 0) * candidate)
			else
				local movement = detail.Offset * smooth(p) + Vector3.yAxis * (math.sin(math.pi * p) * CONFIG.BreakupPop)
				if starterOak then
					local path = CFrame.new(movement) * detail.Pivot
					local boundsFrame = path * detail.BoundsFrameLocal
					local longitudinalAxis = getLongitudinalAxis(boundsFrame, detail.BoundsSize)
					local center = boundsFrame.Position
					local spin = CFrame.fromAxisAngle(longitudinalAxis, 2 * math.pi * CONFIG.BreakupTurns * smooth(p))
					local candidate = CFrame.new(center) * spin * CFrame.new(-center) * path
					local floorCorrection = math.max(0,
						s.groundY + 0.04 - minimumYAt(detail.Bounds, candidate))
					item.model:PivotTo(CFrame.new(0, floorCorrection, 0) * candidate)
				else
					local spin = CFrame.fromAxisAngle(Vector3.yAxis, 2 * math.pi * CONFIG.BreakupTurns * p)
					item.model:PivotTo(CFrame.new(movement) * detail.Pivot * spin)
				end
			end
		end
	end), "breakup cancelled")
	s.phase = "ready"
	updateControls()
end
local function rootAndTorso()
	local character = player.Character
	if not character then return nil, nil end
	return character:FindFirstChild("HumanoidRootPart"),
		character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end
local function carryTarget(index)
	local _, torso = rootAndTorso()
	if not torso then return nil end
	local offset = CarryLayout.GetTorsoRelativeTargetCFrame("Normal", index, table.create(index, 1))
	return offset and torso.CFrame * offset or nil
end
local function followCarries(s)
	if s.follow then return end
	s.follow = RunService.RenderStepped:Connect(function()
		if not alive(s) then return end
		for index, model in ipairs(s.carries) do
			local target = carryTarget(index)
			if target and model.Parent then model:PivotTo(target) end
		end
	end)
end
local function home(s, model, mode)
	local started, last = os.clock(), os.clock()
	local firstUpdate = false
	local limit = if mode == "Overflow" then CONFIG.OverflowHomingDuration else CONFIG.MaxHomingDuration
	-- A nearby section can already be inside the production-style 2.5-stud
	-- arrival radius; the preview must visibly approach before it settles.
	local arrivalRadius = if mode == "Overflow" then CONFIG.OverflowArrivalRadius else CONFIG.ArrivalRadius
	debugEvent("HOMING_STARTED", ("mode=%s limit=%.1fs"):format(mode, limit))
	while alive(s) and os.clock() - started < limit do
		local now = os.clock()
		local root = rootAndTorso()
		assert(root and root:IsA("BasePart"), "player character unavailable")
		local frame = model:GetPivot()
		local delta = root.Position - frame.Position
		if delta.Magnitude <= arrivalRadius then
			debugEvent("HOMING_ARRIVAL", ("mode=%s elapsed=%.2fs distance=%.2f moved=%s"):format(
				mode, now - started, delta.Magnitude, tostring(firstUpdate)))
			return true
		end
		local acceleration = if mode == "Overflow"
			then CONFIG.HomingAcceleration * math.max(0, now - started - CONFIG.AccelerationDelay) else 0
		local speed = math.min(CONFIG.MaxHomingSpeed, CONFIG.HomingSpeed + acceleration)
		local position = frame.Position + delta.Unit * math.min(delta.Magnitude, speed * math.min(now - last, 0.1))
		-- Preserve the rotation handed off by the transform during the chase.
		model:PivotTo(CFrame.new(position) * frame.Rotation)
		if not firstUpdate and (position - frame.Position).Magnitude > 0 then
			firstUpdate = true
			debugEvent("HOMING_FIRST_UPDATE", ("mode=%s from=%s to=%s"):format(
				mode, tostring(frame.Position), tostring(position)))
		end
		last = now
		RunService.Heartbeat:Wait()
	end
	debugEvent(if alive(s) then "HOMING_TIMEOUT" else "HOMING_CANCELLED",
		("mode=%s elapsed=%.2fs"):format(mode, os.clock() - started))
	return false
end
local function settle(s, model, duration, targetProvider, finalScale)
	local start, scale = model:GetPivot(), model:GetScale()
	return animate(s, duration, function(progress)
		local target = targetProvider()
		assert(target, "pickup destination unavailable")
		local alpha = smooth(progress)
		local position = start.Position:Lerp(target.Position, alpha) + Vector3.yAxis * (math.sin(math.pi * alpha) * 0.45)
		model:ScaleTo(scale + (finalScale - scale) * alpha)
		model:PivotTo(CFrame.new(position) * start.Rotation:Lerp(target.Rotation, alpha))
	end)
end
-- Match LogService's slot layout using the actual SpeciesVisuals template body.
local function pileSlotOffset(index, length, diameter)
	local zero = index - 1
	local layer = math.floor(zero / 12)
	local within = zero % 12
	local row, column = math.floor(within / 3), within % 3
	local stagger = if (row + column) % 2 == 0 then 0.045 else -0.045
	local yaw = ((index * 37) % 7 - 3) * 0.025 / 3
	return CFrame.new((row - 1.5) * length * 0.48 + stagger,
		diameter * 0.5 + 0.08 + layer * diameter * 0.70,
		(column - 1) * (diameter * 1.08 + CONFIG.PileSpacing)) * CFrame.Angles(0, yaw, 0)
end

local function pileTarget(s, root, index)
	local body = s.destination:FindFirstChild("LogHandle")
	local stage = s.playground:FindFirstChild("ShowcaseStage")
	assert(body and body:IsA("BasePart") and stage and stage:IsA("BasePart"), "standard log body or gallery stage missing")
	local length, diameter = body.Size.X, body.Size.Y
	if s.playground:GetAttribute("FallStyle") == "CanopySupported" then
		local outerLength = s.destination:GetAttribute("NormalizedOuterLength")
		local outerDiameter = s.destination:GetAttribute("NormalizedOuterDiameter")
		if typeof(outerLength) == "number" and outerLength > 0 then length = outerLength end
		if typeof(outerDiameter) == "number" and outerDiameter > 0 then diameter = outerDiameter end
	end
	if not s.pileOrigin then
		local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
		right = if right.Magnitude > 1e-4 then right.Unit else Vector3.xAxis
		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		forward = if forward.Magnitude > 1e-4 then forward.Unit else Vector3.zAxis
		local rotation = CFrame.fromMatrix(Vector3.zero, right, Vector3.yAxis, right:Cross(Vector3.yAxis))
		-- Clamp the whole three-log footprint onto the actual stage, not a fixed
		-- height or a raycast (the gallery floor is intentionally non-queryable).
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for slot = 1, 3 do
			local frame = rotation * pileSlotOffset(slot, length, diameter)
			local center = stage.CFrame:VectorToObjectSpace(frame.Position)
			local xAxis = stage.CFrame:VectorToObjectSpace(frame.RightVector)
			local zAxis = stage.CFrame:VectorToObjectSpace(frame.LookVector)
			local xRadius = math.abs(xAxis.X) * length * 0.5 + math.abs(zAxis.X) * diameter * 0.5 + 0.3
			local zRadius = math.abs(xAxis.Z) * length * 0.5 + math.abs(zAxis.Z) * diameter * 0.5 + 0.3
			minX, maxX = math.min(minX, center.X - xRadius), math.max(maxX, center.X + xRadius)
			minZ, maxZ = math.min(minZ, center.Z - zRadius), math.max(maxZ, center.Z + zRadius)
		end
		local lowX, highX = -stage.Size.X * 0.5 - minX, stage.Size.X * 0.5 - maxX
		local lowZ, highZ = -stage.Size.Z * 0.5 - minZ, stage.Size.Z * 0.5 - maxZ
		assert(lowX <= highX and lowZ <= highZ, "gallery stage is too small for the pile footprint")
		local bestPosition, bestClearance, bestDistance = nil, -math.huge, math.huge
		for _, displacement in ipairs({
			-right * 2.2 - forward * 2, right * 12 - forward * 2,
			-right * 2.2 + forward * 10, -right * 2.2 - forward * 10,
			right * 18 + forward * 12, right * 18 - forward * 12,
			-right * 8 + forward * 16, -right * 8 - forward * 16,
		}) do
			local desired = stage.CFrame:PointToObjectSpace(root.Position + displacement)
			local position = stage.CFrame:PointToWorldSpace(Vector3.new(
				math.clamp(desired.X, lowX, highX), stage.Size.Y * 0.5, math.clamp(desired.Z, lowZ, highZ)))
			local origin = CFrame.new(position) * rotation
			local clearance = math.huge
			for slot = 1, 3 do
				local relative = (origin * pileSlotOffset(slot, length, diameter)):PointToObjectSpace(root.Position)
				local dx = math.max(0, math.abs(relative.X) - length * 0.5)
				local dz = math.max(0, math.abs(relative.Z) - diameter * 0.5)
				clearance = math.min(clearance, math.sqrt(dx * dx + dz * dz))
			end
			local distance = (position - root.Position).Magnitude
			if (clearance >= 2 and (bestClearance < 2 or distance < bestDistance))
				or (bestClearance < 2 and clearance > bestClearance) then
				bestPosition, bestClearance, bestDistance = position, clearance, distance
			end
		end
		s.pileOrigin = CFrame.new(bestPosition) * rotation
		debugEvent("PILE_ORIGIN", tostring(bestPosition) .. (" clearance=%.2f"):format(bestClearance))
	end
	local target = s.pileOrigin * pileSlotOffset(index, length, diameter)
	debugEvent("PILE_SLOT", ("slot=%d position=%s"):format(index, tostring(target.Position)))
	return target
end
local function runPickup(s, item, mode)
	s.pickupStage = "FX.Play"
	debugEvent("TRANSFORMATION_STARTING", ("mode=%s section=%d"):format(mode, item.index))
	if mode == "Overflow" then status("Overflow pickup started") end
	local destination = item.destination or s.destination
	assert(destination and destination:IsA("Model"), "normalized log template missing for section " .. item.index)
	-- The same normalized model becomes the homing and pile/carry visual. This
	-- is intentionally not a generic global Oak log substitution.
	s.destination = destination
	local starterOak = isStarterOakShowcase(s.playground)
	local liftDuration = if starterOak then CONFIG.StarterOakPickup.LiftDuration else CONFIG.LiftDuration
	local compressionDuration = if starterOak then CONFIG.StarterOakPickup.CompressionDuration else CONFIG.CompressionDuration
	local revealDuration = CONFIG.RevealDuration
	local transformOptions = {
		LiftDuration = liftDuration, CompressionDuration = compressionDuration,
		RevealDuration = revealDuration, FinishDuration = 3,
		LiftHeight = CONFIG.LiftHeight,
		RotationTurns = if starterOak then CONFIG.StarterOakPickup.RotationTurns else CONFIG.RotationTurns,
		ChipCount = CONFIG.ChipCount, HoverHeight = 0, HoldLift = true, AlignLongAxis = true,
	}
	if starterOak then
		-- Let LogTransformationFX derive the barrel-roll axis from the section's longest bounds axis.
		transformOptions.SourceEndScale = 0.35
	end
	local controller, message = FX.Play(item.model, destination, transformOptions)
	assert(controller, "could not transform section: " .. tostring(message))
	s.controller = controller
	s.pickupStage = "transformation"
	debugEvent("TRANSFORMATION_STARTED", ("mode=%s section=%d"):format(mode, item.index))
	item.saved = {}
	hide(item.model, item.saved)
	debugEvent("SOURCE_HIDDEN", ("section=%d parts=%d"):format(item.index, #item.model:GetDescendants()))
	local deadline = os.clock() + liftDuration + compressionDuration + revealDuration + 1
	while alive(s) and controller.Active and not controller.Ready and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	assert(alive(s) and controller.Ready, "transformation did not complete: "
		.. tostring(controller.Failure or ("deadline or cancellation at " .. tostring(controller.Phase))))
	debugEvent("TRANSFORMATION_READY", ("mode=%s section=%d"):format(mode, item.index))
	s.pickupStage = "handoff"
	local model = controller:TakeResult(s.folder)
	assert(model, "could not hand off transformed log")
	s.controller = nil
	s.activeModel = model
	local visibleParts = 0
	local partCount = 0
	local examplePart
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			partCount += 1
			examplePart = examplePart or descendant
			if descendant.Transparency < 1 and descendant.LocalTransparencyModifier < 1 then
				visibleParts += 1
			end
		end
	end
	assert(model.PrimaryPart, "handoff standardized model has no PrimaryPart")
	assert(model.Parent == s.folder, "handoff standardized model has unexpected parent: " .. tostring(model.Parent))
	assert(visibleParts > 0, ("handoff standardized model has no visible parts: count=%d example=%s transparency=%s localTransparency=%s originalTransparency=%s"):format(
		partCount, examplePart and examplePart.Name or "none",
		examplePart and tostring(examplePart.Transparency) or "n/a",
		examplePart and tostring(examplePart.LocalTransparencyModifier) or "n/a",
		examplePart and tostring(examplePart:GetAttribute("DevOriginalTransparency")) or "n/a"))
	local boundsFrame, boundsSize = model:GetBoundingBox()
	debugEvent("HANDOFF_SUCCEEDED", ("mode=%s section=%d parent=%s pivot=%s bounds=%s size=%s scale=%.3f visibleParts=%d"):format(
		mode, item.index, model.Parent:GetFullName(), tostring(model:GetPivot().Position),
		tostring(boundsFrame.Position), tostring(boundsSize), model:GetScale(), visibleParts))
	s.pickupStage = "homing"
	assert(home(s, model, mode), "pickup homing timed out or was cancelled")
	if mode == "Backpack" then
		local index = #s.carries + 1
		assert(settle(s, model, CONFIG.CarrySettleDuration, function() return carryTarget(index) end,
			model:GetScale() / 4), "carry settle cancelled")
		table.insert(s.carries, model)
		followCarries(s)
	else
		s.pickupStage = "pile allocation"
		local root = rootAndTorso()
		assert(root, "player character unavailable")
		local target = pileTarget(s, root, #s.pile + 1)
		debugEvent("PILE_TARGET_CREATED", ("section=%d position=%s"):format(item.index, tostring(target.Position)))
		s.pickupStage = "pile settlement"
		debugEvent("SETTLEMENT_STARTED", ("section=%d from=%s to=%s"):format(
			item.index, tostring(model:GetPivot().Position), tostring(target.Position)))
		assert(settle(s, model, CONFIG.OverflowSettleDuration, function() return target end,
			model:GetScale()), "overflow settle cancelled")
		table.insert(s.pile, model)
		debugEvent("SETTLEMENT_COMPLETE", ("section=%d pileCount=%d position=%s"):format(
			item.index, #s.pile, tostring(model:GetPivot().Position)))
		status(("Overflow complete — pile: %d/%d"):format(#s.pile, #s.sections))
	end
	item.state = "collected"
	item.prompt:Destroy()
	s.activeModel = nil
	s.pickupStage = nil
	s.phase = "ready"
	updateControls()
end
local function readAuthoredSections(tree, sectionFolderName)
	local sectionFolder = tree:FindFirstChild(sectionFolderName)
	local authoredSections = {}
	for _, model in ipairs(sectionFolder and sectionFolder:GetChildren() or {}) do
		if model:IsA("Model") then
			local index = model:GetAttribute("HarvestSectionIndex")
			if typeof(index) == "number" then
				table.insert(authoredSections, { index = index, model = model })
			end
		end
	end
	table.sort(authoredSections, function(a, b) return a.index < b.index end)
	return sectionFolder, authoredSections
end

local function waitForAuthoredSections(tree, sectionFolderName, expectedCount, token)
	local sectionFolder, folderError = waitForChild(tree, sectionFolderName, CONFIG.StreamingTimeout, token, "Folder")
	assert(sectionFolder, folderError)
	local deadline = os.clock() + CONFIG.StreamingTimeout
	repeat
		if token.cancelled then error("showcase load cancelled while waiting for authored sections") end
		local _, authoredSections = readAuthoredSections(tree, sectionFolderName)
		local countMatches = expectedCount == nil and #authoredSections > 0 or #authoredSections == expectedCount
		local sectionsReady = countMatches
		for _, authored in ipairs(authoredSections) do
			if not authored.model.PrimaryPart or countBaseParts(authored.model) == 0 then
				sectionsReady = false
				break
			end
		end
		if sectionsReady then return authoredSections end
		if os.clock() >= deadline then break end
		RunService.Heartbeat:Wait()
	until false
	local _, authoredSections = readAuthoredSections(tree, sectionFolderName)
	return nil, ("authored section models timed out (%d found; expected %s)"):format(
		#authoredSections, expectedCount and tostring(expectedCount) or "at least one")
end

local function validateProceduralSections(tree, authoredSections)
	if tree:GetAttribute("GeneratedStarterOak") ~= true then return end
	local valid = tree:GetAttribute("HarvestSectionValid")
	if valid ~= true then
		local reason = tree:GetAttribute("HarvestSectionInvalidReason") or "the generator marked the harvest geometry invalid"
		error("procedural harvest unavailable: " .. tostring(reason))
	end
	local declaredCount = tree:GetAttribute("HarvestSectionCount")
	assert(typeof(declaredCount) == "number" and declaredCount >= 1 and declaredCount <= 2,
		"procedural tree has no supported one- or two-section harvest count")
	assert(#authoredSections == declaredCount,
		("procedural section metadata mismatch (declared %d, found %d)"):format(declaredCount, #authoredSections))
	local minimumLength = tree:GetAttribute("HarvestMinimumSectionLength")
	local minimumRatio = tree:GetAttribute("HarvestMinimumLengthToThicknessRatio")
	assert(typeof(minimumLength) == "number" and minimumLength > 0,
		"procedural tree is missing its minimum harvest section length")
	assert(typeof(minimumRatio) == "number" and minimumRatio > 0,
		"procedural tree is missing its minimum length/thickness ratio")
	for visualIndex, authored in ipairs(authoredSections) do
		assert(authored.index == visualIndex and authored.model.Name == "Section" .. visualIndex,
			"procedural section order or name is inconsistent at section " .. visualIndex)
		local length = authored.model:GetAttribute("SourceSectionLength")
		local thickness = authored.model:GetAttribute("SourceSectionThickness")
		assert(typeof(length) == "number" and length > 0 and typeof(thickness) == "number" and thickness > 0,
			"procedural section is missing its source dimensions: " .. authored.model.Name)
		if length + 1e-3 < minimumLength then
			error(("procedural section %d is shorter than its configured minimum (%.2f < %.2f)"):format(
				visualIndex, length, minimumLength))
		end
		if length / thickness + 1e-3 < minimumRatio then
			error(("procedural section %d is below its configured length/thickness ratio (%.2f < %.2f)"):format(
				visualIndex, length / thickness, minimumRatio))
		end
	end
end

local function start(playground, fallPrompt)
	if session or startingByPlayground[playground] then return end
	for _, pending in pairs(startingByPlayground) do
		if pending then return end
	end
	local token = { cancelled = false, fallPrompt = fallPrompt }
	startingByPlayground[playground] = token
	controls = controlsByPlayground[playground] or controls
	if fallPrompt.Parent then fallPrompt.Enabled = false end
	status("Loading the generated tree and log templates…")
	local source, tree, folder, saved, s
	local ok, failure = xpcall(function()
		local sourceName = playground:GetAttribute("SourceTreeName") or "ShowcaseTree"
		local sectionFolderName = playground:GetAttribute("SectionFolderName") or "OakHarvestSections"
		local templateFolderName = playground:GetAttribute("NormalizationTemplateFolder")
		local sourceError
		source, sourceError = waitForChild(playground, sourceName, CONFIG.StreamingTimeout, token, "Model")
		assert(source, sourceError)
		local slot, slotError = waitForChild(playground, "DemoSlot", CONFIG.StreamingTimeout, token, "BasePart")
		assert(slot, slotError)
		local proceduralStarterOak = source:GetAttribute("GeneratedStarterOak") == true
		local expectedCount
		if proceduralStarterOak then
			local valid, attributeError = waitForAttribute(source, "HarvestSectionValid", CONFIG.StreamingTimeout, token)
			assert(valid ~= nil, attributeError)
			if valid ~= true then
				local reason = source:GetAttribute("HarvestSectionInvalidReason") or "the generator marked the harvest geometry invalid"
				error("procedural harvest unavailable: " .. tostring(reason))
			end
			expectedCount = source:GetAttribute("HarvestSectionCount")
			assert(typeof(expectedCount) == "number" and expectedCount >= 1 and expectedCount <= 2,
				"procedural tree has no supported one- or two-section harvest count")
			local complete, geometryError = waitForTreeGeometry(source, CONFIG.StreamingTimeout, token)
			assert(complete, geometryError)
		else
			local publishedCount = source:GetAttribute("ExpectedAuthoredSectionCount")
			if typeof(publishedCount) == "number" and publishedCount >= 1 and publishedCount % 1 == 0 then
				expectedCount = publishedCount
			end
		end
		local authoredSections, sectionError = waitForAuthoredSections(source, sectionFolderName, expectedCount, token)
		assert(authoredSections, sectionError)
		validateProceduralSections(source, authoredSections)
		local destination
		local templateFolder
		if type(templateFolderName) == "string" then
			templateFolder, sourceError = waitForChild(playground, templateFolderName, CONFIG.StreamingTimeout, token, "Folder")
			assert(templateFolder, sourceError)
		else
			destination, sourceError = waitForChild(playground, "TransformationDestinationTemplate", CONFIG.StreamingTimeout, token, "Model")
			assert(destination, sourceError)
		end
		if destination then
			local body, bodyError = waitForChild(destination, "LogHandle", CONFIG.StreamingTimeout, token, "BasePart")
			assert(body, bodyError)
		end
		for visualIndex = 1, #authoredSections do
			local sectionDestination = destination
			if templateFolder then
				sectionDestination, sourceError = waitForChild(templateFolder, "Section" .. visualIndex,
					CONFIG.StreamingTimeout, token, "Model")
				assert(sectionDestination, sourceError)
			end
			local body, bodyError = waitForChild(sectionDestination, "LogHandle", CONFIG.StreamingTimeout, token, "BasePart")
			assert(body, bodyError)
		end
		if token.cancelled then error("showcase load cancelled") end
		tree = source:Clone()
		assert(tree, "could not clone showcase tree")
		local clonedFolder, clonedAuthoredSections = readAuthoredSections(tree, sectionFolderName)
		assert(clonedFolder and #clonedAuthoredSections == #authoredSections,
			"cloned showcase is missing its authored sections")
		local sections = {}
		for visualIndex, authored in ipairs(clonedAuthoredSections) do
			local model = authored.model
			assert(authored.index == visualIndex, "authored harvest sections must be ordered by their section index")
			if proceduralStarterOak then
				assert(model.Name == "Section" .. visualIndex,
					"procedural sections must be named Section1, Section2")
			end
			assert(model.PrimaryPart and model.PrimaryPart:IsA("BasePart"),
				"authored section has no PrimaryPart: " .. model.Name)
			local sectionDestination = destination
			if templateFolder then sectionDestination = templateFolder:FindFirstChild("Section" .. visualIndex) end
			assert(sectionDestination and sectionDestination:IsA("Model"),
				"normalized template missing for section " .. visualIndex)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "DevCollectSection"
			prompt.ActionText = "Preview " .. selectedMode .. " Pickup"
			prompt.ObjectText = "Oak section " .. visualIndex
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.MaxActivationDistance = 5
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt:SetAttribute("DevShowcaseSection", visualIndex)
			prompt.Parent = model.PrimaryPart
			table.insert(sections, { index = visualIndex, model = model, state = "available", prompt = prompt, destination = sectionDestination })
		end
		folder = Instance.new("Folder")
		folder.Name = "ClientFullHarvestShowcase"
		folder.Parent = Workspace
		for _, part in ipairs(tree:GetDescendants()) do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
		end
		tree.Parent = folder
		saved = {}
		hide(source, saved)
		local groundY = slot:GetAttribute("GroundY")
		if typeof(groundY) ~= "number" then groundY = slot.Position.Y - 1.5 end
		local seed = source:GetAttribute("SourceTreeSeed") or source:GetAttribute("DevTreeGallerySeed") or source:GetAttribute("Seed")
		local coreHeight = source:GetAttribute("SourceCoreHeight") or source:GetAttribute("CoreHeight") or 0
		local thickness = source:GetAttribute("SourceBaseThickness") or source:GetAttribute("TrunkThickness") or 0
		if proceduralStarterOak then
			debugEvent("PROCEDURAL_TREE_READY", ("seed=%s trunk=%.2fx%.2f sections=%d parts=%d"):format(
				tostring(seed or "n/a"), coreHeight, thickness, #sections, countBaseParts(tree)))
		end
		local gallery = Workspace:FindFirstChild("DevTreeGallery")
		s = { playground = playground, folder = folder, tree = tree, destination = destination or sections[1].destination,
			sections = sections, saved = saved, fallPrompt = fallPrompt, groundY = groundY,
			phase = "falling", carries = {}, pile = {}, proceduralStarterOak = proceduralStarterOak, seed = seed,
			gallery = gallery }
		session = s
		s.galleryConnection = playground.AncestryChanged:Connect(function()
			if not playground:IsDescendantOf(Workspace) and session == s then reset() end
		end)
		s.characterConnection = player.CharacterRemoving:Connect(function()
			if session == s then reset() end
		end)
	end, debug.traceback)
	startingByPlayground[playground] = nil
	if not ok then
		if s and s.galleryConnection then s.galleryConnection:Disconnect() end
		if s and s.characterConnection then s.characterConnection:Disconnect() end
		if session == s then session = nil end
		if folder and folder.Parent then folder:Destroy() elseif tree then tree:Destroy() end
		if saved then restore(saved) end
		if fallPrompt.Parent then fallPrompt.Enabled = true end
		if token.cancelled then
			status("Showcase load cancelled — press E at the tree")
		else
			local conciseFailure = tostring(failure):match("^[^\n]+") or tostring(failure)
			status("Showcase could not load: " .. conciseFailure)
			warn("[DevTreeGallery] Could not start showcase: " .. tostring(failure))
		end
		return
	end
	task.spawn(function()
		local success, err = pcall(runFall, s)
		if not success and session == s then
			warn("[DevTreeGallery] Showcase reset after fall error: " .. tostring(err))
			reset()
		end
	end)
end
local function makeControl(folder, position, action, title)
	local anchor = Instance.new("Part")
	anchor.Name = "Dev" .. action
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Anchored, anchor.Transparency = true, 1
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = title, "Harvest showcase"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 4
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("DevShowcaseAction", action)
	prompt.Parent = anchor
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(155, 35)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance, billboard.AlwaysOnTop = 65, true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.BackgroundColor3 = 0.3, Color3.fromRGB(30, 42, 31)
	label.Size, label.Font = UDim2.fromScale(1, 1), Enum.Font.GothamBold
	label.TextColor3, label.TextScaled, label.Text = Color3.new(1, 1, 1), true, title:upper()
	label.Parent = billboard
	return label
end
local function setupControls(playground)
	if not playground or not playground.Parent or controlsSetup[playground] then return end
	local existingControls = controlsByPlayground[playground]
	if existingControls and existingControls.folder.Parent then return end
	controlsSetup[playground] = true
	local slot, slotError = waitForChild(playground, "DemoSlot", CONFIG.StreamingTimeout, nil, "BasePart")
	controlsSetup[playground] = nil
	if not playground.Parent or not slot then
		if playground.Parent and slotError then warn("[DevTreeGallery] Showcase controls unavailable: " .. slotError) end
		return
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "ClientShowcaseControls", playground
	-- Keep controls outside the fall prompt's radius and apart from each other.
	local pos = slot.Position + Vector3.new(0, 0, -20)
	local backpack = makeControl(folder, pos + Vector3.new(-12, 0, 0), "Backpack", "Select Backpack")
	local overflow = makeControl(folder, pos, "Overflow", "Select Overflow")
	makeControl(folder, pos + Vector3.new(12, 0, 0), "Reset", "Reset Showcase")
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Anchored, anchor.Transparency = "DevShowcaseStatus", true, 1
	anchor.Size, anchor.CFrame = Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, 5, 0))
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Parent = folder
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.MaxDistance, billboard.AlwaysOnTop = UDim2.fromOffset(250, 55), 100, true
	billboard.Parent = anchor
	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundColor3, statusLabel.BackgroundTransparency = Color3.fromRGB(30, 42, 31), 0.2
	statusLabel.Size, statusLabel.Font = UDim2.fromScale(1, 1), Enum.Font.GothamBold
	statusLabel.TextColor3, statusLabel.TextScaled = Color3.new(1, 1, 1), true
	statusLabel.Parent = billboard
	local playgroundControls = { playground = playground, folder = folder, labels = { Backpack = backpack, Overflow = overflow }, status = statusLabel }
	controlsByPlayground[playground] = playgroundControls
	if not controls then controls = playgroundControls end
	updateControls()
	if playground:GetAttribute("GeneratedStarterOak") == true
		and playground:GetAttribute("HarvestSectionValid") == false then
		local reason = playground:GetAttribute("HarvestSectionInvalidReason") or "generated trunk dimensions do not meet the harvest limits"
		statusLabel.Text = "MODE: " .. selectedMode:upper() .. "\nHarvest unavailable — " .. tostring(reason)
	elseif controls == playgroundControls then
		status("Select a mode, then collect a section")
	end
end

local function discardShowcaseControls(playground)
	controlsSetup[playground] = nil
	local candidate = controlsByPlayground[playground]
	if candidate then
		if controls == candidate then controls = nil end
		if candidate.folder and candidate.folder.Parent then candidate.folder:Destroy() end
		controlsByPlayground[playground] = nil
	end
	if not controls then
		for _, remaining in pairs(controlsByPlayground) do
			if remaining.folder and remaining.folder.Parent then controls = remaining; break end
		end
	end
end

local function setupGallery(gallery)
	if not gallery or galleryConnections[gallery] then return end
	local function consider(instance)
		if instance:GetAttribute("DevHarvestShowcase") == true then
			task.spawn(setupControls, instance)
		elseif instance.Name == "DemoSlot" and instance.Parent
			and instance.Parent:GetAttribute("DevHarvestShowcase") == true then
			task.spawn(setupControls, instance.Parent)
		end
	end
	local function remove(instance)
		if instance:GetAttribute("DevHarvestShowcase") == true then
			if session and session.playground == instance then reset() end
			discardShowcaseControls(instance)
		end
	end
	local added = gallery.DescendantAdded:Connect(consider)
	local removing = gallery.DescendantRemoving:Connect(remove)
	local ancestry = gallery.AncestryChanged:Connect(function()
		if gallery:IsDescendantOf(Workspace) then return end
		local connections = galleryConnections[gallery]
		if connections then
			connections.Added:Disconnect()
			connections.Removing:Disconnect()
			connections.Ancestry:Disconnect()
			galleryConnections[gallery] = nil
		end
		if session and session.gallery == gallery then reset() end
	end)
	galleryConnections[gallery] = { Added = added, Removing = removing, Ancestry = ancestry }
	for _, descendant in ipairs(gallery:GetDescendants()) do consider(descendant) end
end

local function controlsForPrompt(prompt)
	for _, candidate in pairs(controlsByPlayground) do
		if prompt:IsDescendantOf(candidate.folder) then return candidate end
	end
	return nil
end

local function findHarvestPlayground(instance)
	local current = instance
	while current and current ~= Workspace do
		if current:GetAttribute("DevHarvestShowcase") == true then return current end
		current = current.Parent
	end
	return nil
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "DevTreeGallery" then task.defer(setupGallery, child) end
end)
local existing = Workspace:FindFirstChild("DevTreeGallery")
if existing then task.spawn(setupGallery, existing) end

PromptService.PromptTriggered:Connect(function(prompt)
	if not prompt then return end
	local action = prompt:GetAttribute("DevShowcaseAction")
	local promptControls = controlsForPrompt(prompt)
	if action and promptControls then
		controls = promptControls
		if action == "Reset" then
			reset(promptControls)
		elseif (action == "Backpack" or action == "Overflow") and (not session or session.phase == "ready") then
			local wasSelected = selectedMode == action
			selectedMode = action
			debugEvent("MODE_SELECTED", action)
			updateControls()
		status(if wasSelected
			then action .. " is already selected — press E at the tree"
			else action .. " selected — press E at the tree")
		else
			debugEvent("MODE_SELECTION_IGNORED", ("action=%s phase=%s"):format(action, session and session.phase or "none"))
		end
		return
	end
	if prompt:GetAttribute("DevTreeGalleryTransformationPrompt") == true then
		local playground = findHarvestPlayground(prompt)
		local gallery = Workspace:FindFirstChild("DevTreeGallery")
		if session or not playground or not gallery or not playground:IsDescendantOf(gallery) then return end
		local ok, err = pcall(start, playground, prompt)
		if not ok then warn("[DevTreeGallery] Could not start showcase: " .. tostring(err)) end
		return
	end
	local index = prompt:GetAttribute("DevShowcaseSection")
	local s = session
	if typeof(index) ~= "number" then return end
	if not s or s.phase ~= "ready" then
		debugEvent("SECTION_SELECTION_IGNORED", ("index=%s phase=%s"):format(tostring(index), s and s.phase or "none"))
		return
	end
	local item = s.sections[index]
	if not item or item.prompt ~= prompt or item.state ~= "available" then
		debugEvent("SECTION_SELECTION_IGNORED", ("index=%s phase=%s"):format(tostring(index), s.phase))
		return
	end
	item.state, s.phase = "animating", "collecting"
	updateControls()
	local mode = selectedMode
	debugEvent("PROMPT_ACCEPTED", ("mode=%s section=%d"):format(mode, index))
	task.spawn(function()
		local ok, err = pcall(runPickup, s, item, mode)
		if not ok and session == s then
			local reason = ("%s: %s"):format(s.pickupStage or "unknown stage", tostring(err))
			debugEvent("PICKUP_FAILED", ("mode=%s section=%d reason=%s"):format(mode, index, reason))
			warn("[DevTreeGallery] " .. mode .. " pickup failed: " .. reason)
			if mode == "Overflow" then
				if s.controller then
					local result = s.controller.Result
					s.controller:Cancel()
					if result and result.Parent then result:Destroy() end
					s.controller = nil
				end
				if s.activeModel then
					for i = #s.pile, 1, -1 do
						if s.pile[i] == s.activeModel then table.remove(s.pile, i) end
					end
					s.activeModel:Destroy()
					s.activeModel = nil
				end
				if item.saved then restore(item.saved); item.saved = nil end
				if #s.pile == 0 then s.pileOrigin = nil end
				item.state, s.phase, s.pickupStage = "available", "ready", nil
				updateControls()
				status("Overflow failed — section restored, try again")
			else
				reset()
			end
		end
	end)
end)
