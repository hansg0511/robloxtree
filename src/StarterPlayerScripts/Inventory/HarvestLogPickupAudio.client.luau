-- Plays a local pickup cue when a server-created harvest log begins flying
-- toward this player's carried stack. This is cosmetic only; inventory and
-- rewards remain server-authoritative.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local HARVEST_FOLDER_NAME = "HarvestLogVisuals"
local HARVEST_MODEL_NAME = "HarvestLog"
local PICKUP_SOUND_ID = "rbxassetid://9114576220"
local PICKUP_VOLUME = 0.85
local SOUND_FALLBACK_LIFETIME = 4

local watchedModels = setmetatable({}, { __mode = "k" })
local boundFolders = setmetatable({}, { __mode = "k" })

local function playPickupSound()
	local sound = Instance.new("Sound")
	sound.Name = "HarvestLogPickupSound"
	sound.SoundId = PICKUP_SOUND_ID
	sound.Volume = PICKUP_VOLUME
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	SoundService:PlayLocalSound(sound)
	task.delay(SOUND_FALLBACK_LIFETIME, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function watchHarvestModel(instance)
	if not instance:IsA("Model") or instance.Name ~= HARVEST_MODEL_NAME or watchedModels[instance] then
		return
	end

	local played = false
	local function tryPlay()
		if played
			or instance:GetAttribute("OwnerUserId") ~= localPlayer.UserId
			or instance:GetAttribute("PickupFlightStarted") ~= true then
			return
		end

		played = true
		playPickupSound()
	end

	watchedModels[instance] = true
	instance:GetAttributeChangedSignal("OwnerUserId"):Connect(tryPlay)
	instance:GetAttributeChangedSignal("PickupFlightStarted"):Connect(tryPlay)
	tryPlay()
end

local function bindHarvestFolder(folder)
	if not folder:IsA("Folder") or boundFolders[folder] then
		return
	end

	boundFolders[folder] = true
	for _, child in ipairs(folder:GetChildren()) do
		watchHarvestModel(child)
	end
	folder.ChildAdded:Connect(watchHarvestModel)
end

local existingFolder = Workspace:FindFirstChild(HARVEST_FOLDER_NAME)
if existingFolder then
	bindHarvestFolder(existingFolder)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == HARVEST_FOLDER_NAME then
		bindHarvestFolder(child)
	end
end)
