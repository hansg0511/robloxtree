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
	LiftDuration = 0.16, CompressionDuration = 0.24, RevealDuration = 0.18,
	LiftHeight = 1.1, RotationTurns = 0.35, ChipCount = 8,
	HomingSpeed = 24, HomingAcceleration = 4, AccelerationDelay = 1,
	MaxHomingSpeed = 60, MaxHomingDuration = 8, OverflowHomingDuration = 60, ArrivalRadius = 2.5,
	CarrySettleDuration = 0.22, OverflowSettleDuration = 0.45, PileSpacing = 0.08,
}
local session, controls
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
local function extentAlong(frame, size, axis)
	return 0.5 * (math.abs(frame.RightVector:Dot(axis)) * size.X
		+ math.abs(frame.UpVector:Dot(axis)) * size.Y
		+ math.abs(frame.LookVector:Dot(axis)) * size.Z)
end
local function hide(tree)
	local saved = {}
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
	if controls and controls.folder.Parent then
		for mode, label in pairs(controls.labels) do
			label.Text = mode:upper() .. (selectedMode == mode and " [SELECTED]" or "")
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
local function reset()
	local s = session
	if not s then return end
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
local function runFall(s)
	local tree = s.tree
	local standing = tree:GetPivot()
	local baseRadius = s.sections[1].model.PrimaryPart.Size.X * 0.5
	assert(animate(s, CONFIG.Fall, function(progress)
		local angle = smooth(progress) * math.pi * 0.5
		tree:PivotTo(CFrame.new(0, baseRadius * math.sin(angle), 0) * standing * CFrame.Angles(0, 0, -angle))
	end), "fall cancelled")
	assert(animate(s, CONFIG.ImpactPause, function() end), "impact cancelled")
	detachJoints(tree, s.sections)
	local leaves, details = {}, {}
	local leafFolder = tree:FindFirstChild("Leaves")
	if leafFolder then
		for _, part in ipairs(leafFolder:GetDescendants()) do
			if part:IsA("BasePart") then table.insert(leaves, { part, part.Size, part.Transparency }) end
		end
	end
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
		details[index] = { Pivot = item.model:GetPivot(),
			Offset = Vector3.new(targetX - frame.Position.X, math.max(0, s.groundY + 0.04 - bottom), 0) }
		previousCenter, previousHalf = targetX, halfX
	end
	local duration = math.max(CONFIG.Foliage, CONFIG.Breakup + (#s.sections - 1) * CONFIG.BreakupStagger)
	assert(animate(s, duration, function(_, elapsed)
		local leafAlpha = smooth(elapsed / CONFIG.Foliage)
		for _, leaf in ipairs(leaves) do
			if leaf[1].Parent then
				leaf[1].Size = leaf[2] * math.max(0.03, 1 - leafAlpha)
				leaf[1].Transparency = leaf[3] + (1 - leaf[3]) * leafAlpha
			end
		end
		for index, item in ipairs(s.sections) do
			local p = math.clamp((elapsed - (index - 1) * CONFIG.BreakupStagger) / CONFIG.Breakup, 0, 1)
			local detail = details[index]
			local movement = detail.Offset * smooth(p) + Vector3.yAxis * (math.sin(math.pi * p) * CONFIG.BreakupPop)
			local spin = CFrame.fromAxisAngle(Vector3.yAxis, 2 * math.pi * CONFIG.BreakupTurns * p)
			item.model:PivotTo(CFrame.new(movement) * detail.Pivot * spin)
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
	local limit = if mode == "Overflow" then CONFIG.OverflowHomingDuration else CONFIG.MaxHomingDuration
	debugEvent("HOMING_STARTED", ("mode=%s limit=%.1fs"):format(mode, limit))
	while alive(s) and os.clock() - started < limit do
		local now = os.clock()
		local root = rootAndTorso()
		assert(root and root:IsA("BasePart"), "player character unavailable")
		local frame = model:GetPivot()
		local delta = root.Position - frame.Position
		if delta.Magnitude <= CONFIG.ArrivalRadius then
			debugEvent("HOMING_COMPLETE", ("mode=%s elapsed=%.2fs"):format(mode, now - started))
			return true
		end
		local acceleration = if mode == "Overflow"
			then CONFIG.HomingAcceleration * math.max(0, now - started - CONFIG.AccelerationDelay) else 0
		local speed = math.min(CONFIG.MaxHomingSpeed, CONFIG.HomingSpeed + acceleration)
		local position = frame.Position + delta.Unit * math.min(delta.Magnitude, speed * math.min(now - last, 0.1))
		-- Preserve the rotation handed off by the transform during the chase.
		model:PivotTo(CFrame.new(position) * frame.Rotation)
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
	local body = s.destination.PrimaryPart
	local stage = s.playground:FindFirstChild("ShowcaseStage")
	assert(body and stage and stage:IsA("BasePart"), "standard log body or gallery stage missing")
	local length, diameter = body.Size.X, body.Size.Y
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
	s.pickupStage = "transformation"
	debugEvent("PICKUP_STARTED", ("mode=%s section=%d"):format(mode, item.index))
	if mode == "Overflow" then status("Overflow pickup started") end
	local controller, message = FX.Play(item.model, s.destination, {
		LiftDuration = CONFIG.LiftDuration, CompressionDuration = CONFIG.CompressionDuration,
		RevealDuration = CONFIG.RevealDuration, FinishDuration = 3,
		LiftHeight = CONFIG.LiftHeight, RotationTurns = CONFIG.RotationTurns,
		ChipCount = CONFIG.ChipCount, HoverHeight = 0, HoldLift = true, AlignLongAxis = true,
	})
	assert(controller, "could not transform section: " .. tostring(message))
	s.controller = controller
	item.saved = hide(item.model)
	local deadline = os.clock() + CONFIG.LiftDuration + CONFIG.CompressionDuration + CONFIG.RevealDuration + 1
	while alive(s) and controller.Active and not controller.Ready and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	assert(alive(s) and controller.Ready, "transformation did not complete")
	debugEvent("TRANSFORMATION_COMPLETE", ("mode=%s section=%d"):format(mode, item.index))
	s.pickupStage = "handoff"
	local model = controller:TakeResult(s.folder)
	assert(model, "could not hand off transformed log")
	s.controller = nil
	s.activeModel = model
	debugEvent("HANDOFF_SUCCEEDED", ("mode=%s section=%d parent=%s position=%s"):format(
		mode, item.index, model.Parent:GetFullName(), tostring(model:GetPivot().Position)))
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
		s.pickupStage = "pile settlement"
		assert(settle(s, model, CONFIG.OverflowSettleDuration, function() return target end,
			model:GetScale()), "overflow settle cancelled")
		table.insert(s.pile, model)
		debugEvent("SETTLEMENT_COMPLETE", ("section=%d pileCount=%d position=%s"):format(
			item.index, #s.pile, tostring(model:GetPivot().Position)))
		status(("Overflow complete — pile: %d/3"):format(#s.pile))
	end
	item.state = "collected"
	item.prompt:Destroy()
	s.activeModel = nil
	s.pickupStage = nil
	s.phase = "ready"
	updateControls()
end
local function start(playground, fallPrompt)
	local source = playground:FindFirstChild("ShowcaseTree")
	local destination = playground:FindFirstChild("TransformationDestinationTemplate")
	local slot = playground:FindFirstChild("DemoSlot")
	assert(source and source:IsA("Model") and destination and destination:IsA("Model")
		and slot and slot:IsA("BasePart"), "showcase templates missing")
	local tree = source:Clone()
	assert(tree, "could not clone showcase tree")
	local sectionFolder, sections = tree:FindFirstChild("OakHarvestSections"), {}
	for index, name in ipairs({ "Base", "Middle", "Top" }) do
		local model = sectionFolder and sectionFolder:FindFirstChild(name)
		if not model or not model:IsA("Model") or not model.PrimaryPart then
			tree:Destroy()
			error("missing authored section " .. name)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DevCollectSection"
		prompt.ActionText = "Preview " .. selectedMode .. " Pickup"
		prompt.ObjectText = "Oak section " .. index
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 5
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("DevShowcaseSection", index)
		prompt.Parent = model.PrimaryPart
		table.insert(sections, { index = index, model = model, state = "available", prompt = prompt })
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClientFullHarvestShowcase"
	folder.Parent = Workspace
	for _, part in ipairs(tree:GetDescendants()) do
		if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
	end
	tree.Parent = folder
	local saved = hide(source)
	local groundY = slot:GetAttribute("GroundY")
	if typeof(groundY) ~= "number" then groundY = slot.Position.Y - 1.5 end
	local s = { playground = playground, folder = folder, tree = tree, destination = destination,
		sections = sections, saved = saved, fallPrompt = fallPrompt, groundY = groundY,
		phase = "falling", carries = {}, pile = {} }
	session = s
	fallPrompt.Enabled = false
	s.galleryConnection = playground.AncestryChanged:Connect(function()
		if not playground:IsDescendantOf(Workspace) and session == s then reset() end
	end)
	s.characterConnection = player.CharacterRemoving:Connect(function()
		if session == s then reset() end
	end)
	task.spawn(function()
		local ok, err = pcall(runFall, s)
		if not ok and session == s then
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
local function setupControls(gallery)
	local playground = gallery:WaitForChild("TransformationPlayground", 15)
	local slot = playground and playground:WaitForChild("DemoSlot", 15)
	if not gallery.Parent or not slot or not slot:IsA("BasePart") then return end
	if controls and controls.folder.Parent then controls.folder:Destroy() end
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
	controls = { folder = folder, labels = { Backpack = backpack, Overflow = overflow }, status = statusLabel }
	updateControls()
	status("Select a mode, then collect a section")
end
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "DevTreeGallery" then task.defer(setupControls, child) end
end)
local existing = Workspace:FindFirstChild("DevTreeGallery")
if existing then task.spawn(setupControls, existing) end

PromptService.PromptTriggered:Connect(function(prompt)
	if not prompt then return end
	local action = prompt:GetAttribute("DevShowcaseAction")
	if action and controls and prompt:IsDescendantOf(controls.folder) then
		if action == "Reset" then
			reset()
		elseif (action == "Backpack" or action == "Overflow") and (not session or session.phase == "ready") then
			selectedMode = action
			debugEvent("MODE_SELECTED", action)
			updateControls()
			status("Approach a section and press E")
		else
			debugEvent("MODE_SELECTION_IGNORED", ("action=%s phase=%s"):format(action, session and session.phase or "none"))
		end
		return
	end
	if prompt:GetAttribute("DevTreeGalleryTransformationPrompt") == true then
		local playground = prompt:FindFirstAncestor("TransformationPlayground")
		local gallery = Workspace:FindFirstChild("DevTreeGallery")
		if session or not playground or playground.Parent ~= gallery or not gallery then return end
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
	task.spawn(function()
		local ok, err = pcall(runPickup, s, item, mode)
		if not ok and session == s then
			local reason = ("%s: %s"):format(s.pickupStage or "unknown stage", tostring(err))
			debugEvent("PICKUP_FAILED", ("mode=%s section=%d reason=%s"):format(mode, index, reason))
			warn("[DevTreeGallery] " .. mode .. " pickup failed: " .. reason)
			if mode == "Overflow" then
				if s.controller then s.controller:Cancel(); s.controller = nil end
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
