-- Short, skippable camera sequence for the OWNER of a Grove harvest.
-- Never grants logs or changes growth. All physical world visuals are
-- server-replicated by GroveHarvestVisualService.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Grove"):WaitForChild("GroveHarvestFXRE")
local Config = require(ReplicatedStorage.Shared.GroveHarvestPresentation)

local screen = Instance.new("ScreenGui")
screen.Name = "GroveHarvestCinematic"
screen.DisplayOrder = 105
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.Parent = player:WaitForChild("PlayerGui")

local function style(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

local skipButton = Instance.new("TextButton")
skipButton.Name = "SkipCinematic"
skipButton.AnchorPoint = Vector2.new(1, 0)
skipButton.Position = UDim2.new(1, -30, 0, 40)
skipButton.Size = UDim2.fromOffset(132, 42)
skipButton.BackgroundColor3 = Color3.fromRGB(24, 33, 43)
skipButton.BackgroundTransparency = 0.15
skipButton.Text = "SKIP  [SPACE]"
skipButton.Font = Enum.Font.GothamBold
skipButton.TextColor3 = Color3.fromRGB(255, 237, 194)
skipButton.TextSize = 15
skipButton.Visible = false
skipButton.Parent = screen
style(skipButton, 10)

local reward = Instance.new("TextLabel")
reward.Name = "GroveReward"
reward.AnchorPoint = Vector2.new(0.5, 1)
reward.Position = UDim2.new(0.5, 0, 1, -85)
reward.Size = UDim2.new(0.82, 0, 0, 73)
reward.BackgroundColor3 = Color3.fromRGB(20, 35, 42)
reward.BackgroundTransparency = 0.1
reward.TextColor3 = Color3.fromRGB(255, 219, 121)
reward.TextStrokeTransparency = 0.7
reward.Font = Enum.Font.GothamBold
reward.TextSize = 21
reward.TextWrapped = true
reward.Visible = false
reward.Parent = screen
style(reward, 15)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(550, 80)
constraint.MinSize = Vector2.new(270, 63)
constraint.Parent = reward

local active
local notificationGeneration = 0
local seenRewardUids = {}
local recentRewardOrder = {}

local function playLocalWindup()
	local sounds = ReplicatedStorage:FindFirstChild("LeavesSound")
	local template = sounds and sounds:FindFirstChild("Rustling leaves")
	if not template or not template:IsA("Sound") then return end
	local sound = template:Clone()
	sound.Name = "GroveHarvestWindup"
	sound.Volume = 0.7
	sound.PlaybackSpeed = 0.78
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
	return sound
end

local function finishCamera(state)
	if not state or state.Closed then return end
	state.Closed = true
	if active == state then active = nil end
	skipButton.Visible = false
	if state.Tween then state.Tween:Cancel() end
	if state.Died then state.Died:Disconnect() end
	if state.WindupSound and state.WindupSound.Parent then
		state.WindupSound:Stop()
		state.WindupSound:Destroy()
	end
	local camera = Workspace.CurrentCamera
	if camera and camera == state.Camera and camera.CameraType == Enum.CameraType.Scriptable then
		-- Let Roblox's camera controller reacquire the current character;
		-- we do not manually guess a new player-follow position.
		local original = state.Original
		if original.Subject and original.Subject.Parent then
			camera.CameraSubject = original.Subject
		else
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then camera.CameraSubject = humanoid end
		end
		camera.FieldOfView = original.FieldOfView
		camera.CameraType = original.Type
	end
end

local function terminateCurrent()
	if active then finishCamera(active) end
end

local function showReward(payload)
	if type(payload.RewardUID) ~= "string" or seenRewardUids[payload.RewardUID] then return end
	seenRewardUids[payload.RewardUID] = true
	table.insert(recentRewardOrder, payload.RewardUID)
	if #recentRewardOrder > 128 then
		seenRewardUids[table.remove(recentRewardOrder, 1)] = nil
	end
	local names = {}
	if type(payload.Mutations) == "table" then
		for _, mutation in ipairs({ "Golden", "Giant", "Frenzied", "Shocked", "Crystal" }) do
			if payload.Mutations[mutation] == true then
				table.insert(names, mutation)
			end
		end
	end
	local name = table.concat(names, " ")
	if name ~= "" then name ..= " " end
	reward.Text = string.format("SAVED TO CRAFTING STORAGE!\n%s%s LOG  •  %.2fx",
		name, tostring(payload.SpeciesId or "Grove"),
		tonumber(payload.SizeScale) or 1)
	if payload.HeartwoodAwarded == true then
		reward.Text ..= "\n+1 HEARTWOOD • UPGRADE MATERIAL!"
	end
	notificationGeneration += 1
	local generation = notificationGeneration
	reward.Visible = true
	task.delay(2.6, function()
		if notificationGeneration == generation then reward.Visible = false end
	end)
end

local function beginCinematic(payload)
	if typeof(payload.WorldCFrame) ~= "CFrame" then return end
	terminateCurrent()
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not camera or not root or not humanoid or humanoid.Health <= 0 then return end

	local basePosition = payload.WorldCFrame.Position
	local diff = root.Position - basePosition
	local flat = Vector3.new(diff.X, 0, diff.Z)
	local toward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
	local side = Vector3.new(-toward.Z, 0, toward.X)
	local treeHeight = 14
	local model = payload.TreeModel
	if typeof(model) == "Instance" and model:IsA("Model") and model:IsDescendantOf(Workspace) then
		local ok, extent = pcall(function() return model:GetExtentsSize() end)
		if ok and typeof(extent) == "Vector3" then
			treeHeight = math.clamp(extent.Y, 5, 28)
		end
	end
	local focus = basePosition + Vector3.new(0, math.clamp(treeHeight * 0.38, 2.8, 10), 0)
	local target = CFrame.lookAt(
		basePosition + toward * (12 + treeHeight * 0.5) + side * (5 + treeHeight * 0.15)
			+ Vector3.new(0, 5 + treeHeight * 0.38, 0),
		focus
	)

	local state = {
		Camera = camera,
		Original = {
			Type = camera.CameraType,
			Subject = camera.CameraSubject,
			FieldOfView = camera.FieldOfView,
		},
		Closed = false,
	}
	active = state
	state.Died = humanoid.Died:Connect(function()
		finishCamera(state)
	end)
	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(camera, TweenInfo.new(
		Config.CameraBlendSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = target, FieldOfView = 60 })
	state.Tween = tween
	tween:Play()
	state.WindupSound = playLocalWindup()
	skipButton.Visible = true

	-- A tiny impact shake timed to the server's fall. It is cosmetic only.
	task.delay(Config.WindupSeconds + 1.0, function()
		if active ~= state or state.Closed or Workspace.CurrentCamera ~= camera then return end
		local base = camera.CFrame
		camera.CFrame = base * CFrame.new(0.12, -0.08, 0)
		task.delay(0.08, function()
			if active == state and not state.Closed and Workspace.CurrentCamera == camera then
				camera.CFrame = base
			end
		end)
	end)

	-- After the impact, reframe toward the actual log landing spot. This
	-- makes the reward reveal readable instead of keeping the canopy centered.
	task.delay(Config.WindupSeconds + 1.18, function()
		if active ~= state or state.Closed or Workspace.CurrentCamera ~= camera then return end
		local size = math.clamp(tonumber(payload.SizeScale) or 1, 0.2, 2)
		local landing = payload.WorldCFrame:PointToWorldSpace(Vector3.new(
			2.5 + size * 0.5, 0.75 + size * 0.18, 0))
		local rewardFocus = landing + Vector3.new(0, 1.35, 0)
		local newPosition = basePosition
			+ toward * (10.5 + treeHeight * 0.37)
			+ side * (5 + treeHeight * 0.13)
			+ Vector3.new(0, 5.4 + treeHeight * 0.18, 0)
		local panTween = TweenService:Create(camera, TweenInfo.new(
			0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = CFrame.lookAt(newPosition, rewardFocus) })
		state.Tween = panTween
		panTween:Play()
	end)

	task.delay(Config.CameraHoldSeconds, function()
		if active ~= state or state.Closed then return end
		-- A small, soft return toward the player's position before handing
		-- control back to the default Roblox camera controller.
		local currentCharacter = player.Character
		local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
		if not currentRoot or not currentRoot.Parent or Workspace.CurrentCamera ~= camera then
			finishCamera(state)
			return
		end
		local follow = currentRoot.CFrame * CFrame.new(0, 4.5, 10)
		local followGoal = CFrame.lookAt(follow.Position, currentRoot.Position + Vector3.new(0, 2, 0))
		local lastTween = TweenService:Create(camera, TweenInfo.new(
			Config.CameraReturnSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ CFrame = followGoal, FieldOfView = state.Original.FieldOfView })
		state.Tween = lastTween
		lastTween:Play()
		task.delay(Config.CameraReturnSeconds + 0.05, function()
			finishCamera(state)
		end)
	end)

	-- Hard safety timeout for interrupted tweens/animations.
	task.delay(Config.MaxVisualLifetimeSeconds, function()
		finishCamera(state)
	end)
end

skipButton.Activated:Connect(terminateCurrent)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not active then return end
	if input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.Escape
		or input.KeyCode == Enum.KeyCode.ButtonB then
		terminateCurrent()
	end
end)
player.CharacterAdded:Connect(terminateCurrent)

-- The prompt exists in replicated world models. Do not let non-owners see an
-- E interaction that the server (correctly) refuses.
local function hideForeignPrompt(instance)
	if not instance:IsA("ProximityPrompt") or instance.Name ~= "GroveHarvestPrompt" then return end
	local model = instance:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("PersistentGrove") == true
		and model:GetAttribute("OwnerUserId") ~= player.UserId then
		instance.Enabled = false
	end
end
Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("ProximityPrompt") and instance.Name == "GroveHarvestPrompt" then
		task.defer(hideForeignPrompt, instance)
		task.delay(0.25, hideForeignPrompt, instance)
	end
end)
ProximityPromptService.PromptShown:Connect(hideForeignPrompt)
for _, item in ipairs(Workspace:GetDescendants()) do
	hideForeignPrompt(item)
end

remote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Mode == "Start" then
		beginCinematic(payload)
	elseif payload.Mode == "Reward" then
		showReward(payload)
	end
end)
