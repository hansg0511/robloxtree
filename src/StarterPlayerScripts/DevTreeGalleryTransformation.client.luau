-- A local, Studio-only visual demonstration. No gameplay harvest is involved.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LogTransformationFX = require(script.Parent:WaitForChild("Inventory"):WaitForChild("Modules"):WaitForChild("LogTransformationFX"))

-- All showcase pacing is kept here for manual tuning.
local TIMING = {
	Fall = 1.35,
	ImpactPause = 0.12,
	Foliage = 0.48,
	Breakup = 0.52,
	BreakupStagger = 0.14,
	BreakupPop = 1.5,
	BreakupTurns = 1,
	BeforeTransform = 0.28,
	TransformStagger = 0.68,
	ViewResult = 2.0,
}
local TRANSFORM = {
	LiftDuration = 0.16,
	CompressionDuration = 0.24,
	RevealDuration = 0.18,
	FinishDuration = 10,
	LiftHeight = 1.1,
	RotationTurns = 0.35,
	SourceEndScale = 0.08,
	DestinationStartScale = 0.84,
	ChipCount = 8,
	ChipDuration = 0.28,
	ChipStrength = 1,
	HoverHeight = 0,
	SurfaceEpsilon = 0.04,
	AlignLongAxis = true,
}

local active = false

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function animate(duration, callback, isAlive)
	local start = os.clock()
	while isAlive() do
		local elapsed = os.clock() - start
		callback(math.clamp(elapsed / math.max(duration, 0.001), 0, 1), elapsed)
		if elapsed >= duration then return true end
		RunService.Heartbeat:Wait()
	end
	return false
end

local function waitFor(duration, isAlive)
	return animate(duration, function() end, isAlive)
end

local function extentAlong(frame, size, axis)
	return 0.5 * (
		math.abs(frame.RightVector:Dot(axis)) * size.X
		+ math.abs(frame.UpVector:Dot(axis)) * size.Y
		+ math.abs(frame.LookVector:Dot(axis)) * size.Z
	)
end

local function hideOriginal(tree)
	local saved = {}
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then
			saved[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	return saved
end

local function restoreOriginal(saved)
	for part, transparency in pairs(saved) do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
end

local function detachSectionJoints(tree, sections)
	local membership = {}
	for _, section in ipairs(sections) do
		for _, part in ipairs(section:GetDescendants()) do
			if part:IsA("BasePart") then membership[part] = section end
		end
	end
	for _, joint in ipairs(tree:GetDescendants()) do
		if joint:IsA("WeldConstraint") or joint:IsA("JointInstance") then
			local a, b = membership[joint.Part0], membership[joint.Part1]
			if a ~= b and (a or b) then joint:Destroy() end
		end
	end
end

local function getFoliage(tree)
	local records = {}
	local folder = tree:FindFirstChild("Leaves")
	if folder then
		for _, part in ipairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(records, {
					Part = part, Size = part.Size, CFrame = part.CFrame,
					Transparency = part.Transparency,
				})
			end
		end
	end
	return records
end

local function runShowcase(playground)
	local source = playground:FindFirstChild("ShowcaseTree")
	local destination = playground:FindFirstChild("TransformationDestinationTemplate")
	local slot = playground:FindFirstChild("DemoSlot")
	if not source or not source:IsA("Model") or not destination or not destination:IsA("Model")
		or not slot or not slot:IsA("BasePart") then
		warn("[DevTreeGallery] Full harvest showcase is missing a tree, log template, or demo slot")
		return
	end
	local groundY = slot:GetAttribute("GroundY")
	if typeof(groundY) ~= "number" then groundY = slot.Position.Y - 1.5 end
	local tree = source:Clone()
	if not tree then return end
	local sectionFolder = tree:FindFirstChild("OakHarvestSections")
	local sections = {}
	for _, name in ipairs({ "Base", "Middle", "Top" }) do
		local section = sectionFolder and sectionFolder:FindFirstChild(name)
		if not section or not section:IsA("Model") or not section.PrimaryPart then
			warn("[DevTreeGallery] Missing authored showcase section " .. name)
			tree:Destroy()
			return
		end
		table.insert(sections, section)
	end

	local localFolder = Instance.new("Folder")
	localFolder.Name = "ClientFullHarvestShowcase"
	localFolder.Parent = Workspace
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
	end
	tree.Parent = localFolder
	local saved = hideOriginal(source)
	local controllers = {}
	local function isAlive()
		return tree.Parent ~= nil and playground.Parent ~= nil and source.Parent ~= nil
	end

	local ok, err = pcall(function()
		local standingPivot = tree:GetPivot()
		local baseRadius = sections[1].PrimaryPart.Size.X * 0.5
		assert(animate(TIMING.Fall, function(progress)
			local angle = smooth(progress) * math.pi * 0.5
			local rise = baseRadius * math.sin(angle)
			tree:PivotTo(CFrame.new(0, rise, 0) * standingPivot * CFrame.Angles(0, 0, -angle))
		end, isAlive), "showcase removed during fall")
		assert(waitFor(TIMING.ImpactPause, isAlive), "showcase removed at impact")

		-- These are the exact sections that made up the visible fallen tree.
		detachSectionJoints(tree, sections)
		local leaves = getFoliage(tree)
		local details = {}
		local _, standardSize = destination:GetBoundingBox()
		local standardLength = math.max(standardSize.X, standardSize.Y, standardSize.Z)
		local previousCenter, previousHalf
		for index, section in ipairs(sections) do
			local frame, size = section:GetBoundingBox()
			local halfX = extentAlong(frame, size, Vector3.xAxis)
			local bottom = frame.Position.Y - extentAlong(frame, size, Vector3.yAxis)
			local targetX = frame.Position.X
			if previousCenter then
				targetX = math.max(targetX, previousCenter + math.max(previousHalf + halfX, standardLength) + 0.8)
			end
			details[index] = {
				Pivot = section:GetPivot(),
				Offset = Vector3.new(targetX - frame.Position.X, math.max(0, groundY + 0.04 - bottom), 0),
			}
			previousCenter, previousHalf = targetX, halfX
		end

		local waveDuration = math.max(TIMING.Foliage, TIMING.Breakup + (#sections - 1) * TIMING.BreakupStagger)
		assert(animate(waveDuration, function(_, elapsed)
			local leafAlpha = smooth(elapsed / TIMING.Foliage)
			for _, leaf in ipairs(leaves) do
				if leaf.Part.Parent then
					leaf.Part.Size = leaf.Size * math.max(0.03, 1 - leafAlpha)
					leaf.Part.Transparency = leaf.Transparency + (1 - leaf.Transparency) * leafAlpha
				end
			end
			for index, section in ipairs(sections) do
				local progress = math.clamp((elapsed - (index - 1) * TIMING.BreakupStagger) / TIMING.Breakup, 0, 1)
				local detail = details[index]
				local movement = detail.Offset * smooth(progress) + Vector3.yAxis * (math.sin(math.pi * progress) * TIMING.BreakupPop)
				local spin = CFrame.fromAxisAngle(Vector3.yAxis, 2 * math.pi * TIMING.BreakupTurns * progress)
				section:PivotTo(CFrame.new(movement) * detail.Pivot * spin)
			end
		end, isAlive), "showcase removed during breakup")
		assert(waitFor(TIMING.BeforeTransform, isAlive), "showcase removed before transformation")

		for index, section in ipairs(sections) do
			if index > 1 then assert(waitFor(TIMING.TransformStagger, isAlive), "showcase removed during transformation") end
			local options = table.clone(TRANSFORM)
			options.GroundY = groundY
			local controller, message = LogTransformationFX.Play(section, destination, options)
			assert(controller, "could not transform section: " .. tostring(message))
			table.insert(controllers, controller)
			-- Play has cloned the visible section at its exact current pose.
			for _, part in ipairs(section:GetDescendants()) do
				if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
			end
		end
		local transformationDuration = TRANSFORM.LiftDuration + TRANSFORM.CompressionDuration + TRANSFORM.RevealDuration
		assert(waitFor(transformationDuration + TIMING.ViewResult, isAlive), "showcase removed during result")
	end)

	for _, controller in ipairs(controllers) do controller:Cancel() end
	localFolder:Destroy()
	restoreOriginal(saved)
	if not ok then warn("[DevTreeGallery] Full harvest showcase stopped: " .. tostring(err)) end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if active or not prompt or prompt:GetAttribute("DevTreeGalleryTransformationPrompt") ~= true then return end
	local playground = prompt:FindFirstAncestor("TransformationPlayground")
	local gallery = Workspace:FindFirstChild("DevTreeGallery")
	if not playground or playground.Parent ~= gallery or not gallery then return end
	active = true
	local ok, err = pcall(runShowcase, playground)
	active = false
	if not ok then warn("[DevTreeGallery] Could not start full harvest showcase: " .. tostring(err)) end
end)
