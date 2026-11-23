-- Server-owned visual replica of a Grove log reward. The real UID has
-- already been placed in protected storage before this runs; this model is
-- never a pickup, a tool, or a second inventory item.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SpeciesVisuals = require(game.ServerStorage:WaitForChild("SpeciesVisuals"))
local Config = require(ReplicatedStorage.Shared.GroveHarvestPresentation)
local fxRemote = ReplicatedStorage.Grove:WaitForChild("GroveHarvestFXRE")

local VisualService = {}

local function copyMutations(value)
	local result = {}
	if type(value) == "table" then
		for _, key in ipairs({ "Golden", "Giant", "Crystal" }) do
			if value[key] == true then result[key] = true end
		end
	end
	return result
end

local function playWorldSound(parent, name, speed, volume)
	if not parent or not parent.Parent then return end
	local folder = ReplicatedStorage:FindFirstChild("LeavesSound")
	local template = folder and folder:FindFirstChild(name)
	if not template or not template:IsA("Sound") then return end
	local sound = template:Clone()
	sound.Name = "GroveHarvest_" .. name
	sound.PlaybackSpeed = speed or 1
	sound.Volume = volume or 0.9
	sound.RollOffMaxDistance = Config.AudioMaxDistance
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5)
end

function VisualService.PlaySlash(treeModel)
	local root = treeModel and treeModel.PrimaryPart
	if not root or not root.Parent then return end
	-- Reuse the existing chop impact asset from FXService rather than add a
	-- new, unverified catalog sound.
	local sound = Instance.new("Sound")
	sound.Name = "GroveHarvestSlash"
	sound.SoundId = "rbxassetid://159798370"
	sound.Volume = 1.2
	sound.PlaybackSpeed = 0.85
	sound.RollOffMaxDistance = Config.AudioMaxDistance
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 4)
end

local function makeVisual(reward)
	local size = math.clamp(reward.SizeScale or 1, 0.2, 2)
	local record = { SpeciesId = reward.SpeciesId, Mutations = reward.Mutations }
	local ok, handle, caps = pcall(SpeciesVisuals.CreateLogParts, record, "Handle", 0.8 * size)
	if not ok or not handle or type(caps) ~= "table" then
		warn("[Grove] Could not make reward log visual", handle)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "GroveHarvestRewardVisual"
	model:SetAttribute("GroveHarvestCosmetic", true)
	model:SetAttribute("SpeciesId", reward.SpeciesId)
	model:SetAttribute("SizeScale", size)
	handle.Parent = model
	for _, cap in ipairs(caps) do cap.Parent = model end
	model.PrimaryPart = handle
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
	-- Only the root is anchored: the existing decorative end caps/bark parts
	-- stay welded in their original orientation.
	handle.Anchored = true

	local color
	local mutations = copyMutations(reward.Mutations)
	if mutations.Golden then
		color = Color3.fromRGB(255, 200, 53)
	elseif mutations.Crystal then
		color = Color3.fromRGB(104, 229, 255)
	elseif mutations.Giant then
		color = Color3.fromRGB(205, 134, 255)
	end
	if color then
		local shine = Instance.new("Highlight")
		shine.Name = "MutatedGlow"
		shine.FillColor = color
		shine.OutlineColor = color
		shine.FillTransparency = 0.78
		shine.OutlineTransparency = 0.15
		shine.DepthMode = Enum.HighlightDepthMode.Occluded
		shine.Parent = model
	end
	return model
end

local function animateModel(model, from, to, duration, easing, direction)
	if not model or not model.Parent then return false end
	local value = Instance.new("CFrameValue")
	value.Value = from
	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		if model.Parent then model:PivotTo(value.Value) end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration,
		easing or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out), { Value = to })
	tween:Play()
	local state = tween.Completed:Wait()
	connection:Disconnect()
	tween:Destroy()
	value:Destroy()
	if model.Parent then model:PivotTo(to) end
	return state == Enum.PlaybackState.Completed and model.Parent ~= nil
end

local function notifyOwner(player, reward)
	if not player or not player:IsDescendantOf(Players) then return end
	fxRemote:FireClient(player, {
		Mode = "Reward",
		RewardUID = reward.RewardUID,
		SpeciesId = reward.SpeciesId,
		Mutations = copyMutations(reward.Mutations),
		SizeScale = reward.SizeScale,
	})
end

function VisualService.Reveal(player, reward)
	if not player or not player:IsDescendantOf(Players)
		or type(reward) ~= "table" or typeof(reward.WorldCFrame) ~= "CFrame" then return end
	local model = makeVisual(reward)
	if not model then notifyOwner(player, reward) return end
	local size = math.clamp(reward.SizeScale or 1, 0.2, 2)
	local landing = reward.WorldCFrame:PointToWorldSpace(Vector3.new(2.5 + size * 0.5, 0.75 + size * 0.18, 0))
	local final = CFrame.new(landing) * CFrame.Angles(0, math.rad(22), math.rad(-9))
	local starting = CFrame.new(landing + Vector3.new(0, 3.0 + size, 0))
		* CFrame.Angles(0, math.rad(-65), math.rad(50))
	model:PivotTo(starting)
	model.Parent = Workspace
	Debris:AddItem(model, Config.MaxVisualLifetimeSeconds)

	-- All movement is visual only and replicated to nearby players. No
	-- ProximityPrompts, tool pickup events or client-authored rewards.
	local ok, err = pcall(function()
		animateModel(model, starting, final, Config.DropSeconds,
			Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		playWorldSound(model.PrimaryPart, "Giant Leaves 8 (SFX)", 0.92, 1.0)
		local lifted = final * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.rad(9))
		animateModel(model, final, lifted, Config.BounceSeconds * 0.5)
		animateModel(model, lifted, final, Config.BounceSeconds * 0.5, Enum.EasingStyle.Bounce)
		task.wait(Config.GroundPauseSeconds)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Parent and model.Parent then
			local from = model:GetPivot()
			local target = root.CFrame * CFrame.new(0, 1.6, -1.1)
			-- A visible arc keeps the piece readable before it shrinks into
			-- the owner; the authoritative inventory was already committed.
			local middle = CFrame.new((from.Position + target.Position) * 0.5 + Vector3.new(0, 2.8, 0))
				* CFrame.Angles(0, math.rad(140), 0)
			animateModel(model, from, middle, Config.FlySeconds * 0.5)
			animateModel(model, middle, target, Config.FlySeconds * 0.5,
				Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		else
			task.wait(Config.FlySeconds)
		end
	end)
	if not ok then warn("[Grove] Cosmetic log reveal failed", err) end
	if model.Parent then model:Destroy() end
	notifyOwner(player, reward)
end

return VisualService
