-- Renders server-confirmed ground-log pickups locally. This animation is
-- cosmetic; inventory ownership and pickup validation stay server-authoritative.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local pickupFXRemote = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("PickupLogFXRE")
local CarryLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarryLayout"))

local FX_FOLDER_NAME = "ClientPickupLogFX"
local SOUND_ID = "rbxassetid://140303363726378"
local SOUND_VOLUME = 0.85
local SOUND_REGION = NumberRange.new(0, 0.45)
local SOUND_POOL_SIZE = 16
local MAX_OBSERVER_DISTANCE = 260
local MAX_CONCURRENT_FLIGHTS = 16

local CARRY_LOG_LENGTH = 2.15
local CARRY_LOG_DIAMETER = 0.48
local CARRY_CAP_THICKNESS = 0.07
local WORLD_LOG_DIAMETER = 0.48
local WORLD_CAP_DIAMETER_RATIO = 0.88
local CARRY_CAP_DIAMETER_RATIO = 0.88
local DEFAULT_START_SCALE = 2
local DEFAULT_POP_DURATION = 0.10
local DEFAULT_FLIGHT_DURATION = 0.37
local MAX_LAUNCH_OFFSET = 0.35

local activeFlights = {}
local soundPool = {}
local availableSounds = {}
local soundReady = false
local random = Random.new()
local activeFlightCount = 0

local function getFXFolder()
	local folder = Workspace:FindFirstChild(FX_FOLDER_NAME)
	if folder then return folder end

	folder = Instance.new("Folder")
	folder.Name = FX_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function releasePickupSound(slot)
	if not slot or not slot.Busy then return end
	slot.Busy = false
	slot.Sound.TimePosition = 0
	table.insert(availableSounds, slot)
end

local function createPickupSound()
	local sound = Instance.new("Sound")
	sound.Name = "LocalLogPickup"
	sound.SoundId = SOUND_ID
	sound.Volume = SOUND_VOLUME
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = SOUND_REGION
	sound.Parent = SoundService

	local slot = { Sound = sound, Busy = false }
	sound.Ended:Connect(function()
		releasePickupSound(slot)
	end)
	table.insert(soundPool, slot)
	table.insert(availableSounds, slot)
	return sound
end

for _ = 1, SOUND_POOL_SIZE do
	createPickupSound()
end

task.spawn(function()
	local preloadList = {}
	for _, slot in ipairs(soundPool) do
		table.insert(preloadList, slot.Sound)
	end
	local ok = pcall(function()
		ContentProvider:PreloadAsync(preloadList)
	end)
	soundReady = ok
end)

local function playArrivalSound()
	if not soundReady or #availableSounds == 0 then return end

	local slot = table.remove(availableSounds)
	if not slot or slot.Busy then return end
	slot.Busy = true
	local sound = slot.Sound
	sound.PlaybackSpeed = random:NextNumber(0.96, 1.04)
	sound.TimePosition = 0
	SoundService:PlayLocalSound(sound)

	-- Ended normally releases the slot. This fallback also recovers it if the
	-- asset fails to load or the playback region does not emit Ended.
	task.delay(1.5, function()
		if slot.Busy then
			sound:Stop()
			releasePickupSound(slot)
		end
	end)
end

local function findTorso(character)
	local torso = character:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then return torso end
	torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then return torso end
	return nil
end

local function getPlayerRoot(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

local function configurePart(part, name)
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function createFlightVisual(startCFrame, barkColor, cutEndColor)
	local model = Instance.new("Model")
	model.Name = "PickupLogFlight"

	local body = configurePart(Instance.new("Part"), "Body")
	body.Size = Vector3.new(CARRY_LOG_LENGTH, CARRY_LOG_DIAMETER, CARRY_LOG_DIAMETER)
	body.Color = barkColor
	body.TopSurface = Enum.SurfaceType.Studs
	body.BottomSurface = Enum.SurfaceType.Inlet
	body.FrontSurface = Enum.SurfaceType.Studs
	body.BackSurface = Enum.SurfaceType.Studs
	body.LeftSurface = Enum.SurfaceType.Studs
	body.RightSurface = Enum.SurfaceType.Studs
	body.Parent = model

	local caps = {}
	for index = 1, 2 do
		local cap = configurePart(Instance.new("Part"), "CutEnd" .. index)
		cap.Shape = Enum.PartType.Cylinder
		cap.Size = Vector3.new(CARRY_CAP_THICKNESS, CARRY_LOG_DIAMETER * CARRY_CAP_DIAMETER_RATIO, CARRY_LOG_DIAMETER * CARRY_CAP_DIAMETER_RATIO)
		cap.Color = cutEndColor
		cap.Parent = model
		caps[index] = cap
	end

	model.PrimaryPart = body
	model:PivotTo(startCFrame)
	model.Parent = getFXFolder()
	return model, body, caps
end

local function smoothStep(value)
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end

local function bezier(p0, p1, p2, p3, t)
	local inverse = 1 - t
	return p0 * inverse * inverse * inverse
		+ p1 * 3 * inverse * inverse * t
		+ p2 * 3 * inverse * t * t
		+ p3 * t * t * t
end

local function setVisualTransform(flight, cframe, bodyLength, bodyDiameter, capThickness, capDiameter)
	flight.Body.Size = Vector3.new(bodyLength, bodyDiameter, bodyDiameter)
	flight.Body.CFrame = cframe

	local capOffset = bodyLength * 0.5 - capThickness * 0.5
	for index, cap in ipairs(flight.Caps) do
		local direction = index == 1 and -1 or 1
		cap.Size = Vector3.new(capThickness, capDiameter, capDiameter)
		cap.CFrame = cframe * CFrame.new(direction * capOffset, 0, 0)
	end
end

local function cleanupFlight(key, flight)
	if flight.Connection then
		flight.Connection:Disconnect()
		flight.Connection = nil
	end
	if flight.Model then
		flight.Model:Destroy()
		flight.Model = nil
	end
	if activeFlights[key] == flight then
		activeFlights[key] = nil
		activeFlightCount = math.max(0, activeFlightCount - 1)
	end
end

local function evictObserverFlight()
	for key, flight in pairs(activeFlights) do
		if flight.Owner ~= localPlayer then
			cleanupFlight(key, flight)
			return true
		end
	end
	return false
end

local function getPayloadNumber(payload, key, fallback, minimum, maximum)
	local value = payload[key]
	if type(value) ~= "number" or value ~= value then return fallback end
	return math.clamp(value, minimum, maximum)
end

local function startFlight(payload)
	if type(payload) ~= "table"
		or type(payload.OwnerUserId) ~= "number"
		or type(payload.UID) ~= "string"
		or #payload.UID == 0
		or typeof(payload.StartCFrame) ~= "CFrame"
		or (payload.TargetStack ~= "Normal" and payload.TargetStack ~= "Rare")
		or type(payload.TargetIndex) ~= "number"
		or payload.TargetIndex < 1 then
		return
	end

	local owner = Players:GetPlayerByUserId(payload.OwnerUserId)
	if not owner then return end
	local localCharacter = localPlayer.Character
	local localRoot = getPlayerRoot(localCharacter)
	if owner ~= localPlayer then
		if not localRoot or (localRoot.Position - payload.StartCFrame.Position).Magnitude > MAX_OBSERVER_DISTANCE then
			return
		end
	end

	local key = tostring(payload.OwnerUserId) .. ":" .. payload.UID
	local previous = activeFlights[key]
	if previous then cleanupFlight(key, previous) end
	if activeFlightCount >= MAX_CONCURRENT_FLIGHTS then
		if owner ~= localPlayer or not evictObserverFlight() then
			return
		end
	end

	local barkColor = typeof(payload.BarkColor) == "Color3" and payload.BarkColor or Color3.fromRGB(115, 72, 42)
	local cutEndColor = typeof(payload.CutEndColor) == "Color3" and payload.CutEndColor or Color3.fromRGB(190, 153, 105)
	local model, body, caps = createFlightVisual(payload.StartCFrame, barkColor, cutEndColor)
	local flight = {
		Model = model,
		Body = body,
		Caps = caps,
		Owner = owner,
		TargetStack = payload.TargetStack,
		TargetIndex = math.floor(payload.TargetIndex),
		StartCFrame = payload.StartCFrame,
		StartPosition = payload.StartCFrame.Position,
		StartRotation = payload.StartCFrame.Rotation,
		-- Server payload scale matches the world-drop visual. Cap at the current
		-- 4x-carry contract so malformed payloads cannot create enormous FX.
		StartScale = getPayloadNumber(payload, "StartVisualScale", DEFAULT_START_SCALE, 1, 4),
		LaunchOffset = getPayloadNumber(payload, "LaunchOffset", 0, 0, MAX_LAUNCH_OFFSET),
		PopDuration = getPayloadNumber(payload, "PopDuration", DEFAULT_POP_DURATION, 0.04, 0.18),
		FlightDuration = getPayloadNumber(payload, "FlightDuration", DEFAULT_FLIGHT_DURATION, 0.22, 0.55),
		Elapsed = 0,
	}
	flight.StartLength = CARRY_LOG_LENGTH * flight.StartScale
	flight.StartDiameter = WORLD_LOG_DIAMETER * flight.StartScale
	flight.StartCapThickness = CARRY_CAP_THICKNESS * flight.StartScale
	flight.StartCapDiameter = flight.StartDiameter * WORLD_CAP_DIAMETER_RATIO
	activeFlights[key] = flight
	activeFlightCount += 1
	setVisualTransform(
		flight,
		flight.StartCFrame,
		flight.StartLength,
		flight.StartDiameter,
		flight.StartCapThickness,
		flight.StartCapDiameter
	)

	flight.Connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not flight.Model or not flight.Model.Parent or not owner:IsDescendantOf(Players) then
			cleanupFlight(key, flight)
			return
		end

		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local torso = character and findTorso(character)
		if not character or not humanoid or humanoid.Health <= 0 or not torso then
			cleanupFlight(key, flight)
			return
		end

		flight.Elapsed += deltaTime
		local localElapsed = flight.Elapsed - flight.LaunchOffset
		if localElapsed < 0 then return end

		if localElapsed < flight.PopDuration then
			local popT = localElapsed / flight.PopDuration
			local popEase = 1 - (1 - popT) ^ 3
			local popPosition = flight.StartPosition + Vector3.new(0, 0.72 * popEase, 0)
			local popRotation = flight.StartRotation * CFrame.Angles(0.05 * popT, 0.08 * math.sin(popT * math.pi), -0.06 * popT)
			setVisualTransform(
				flight,
				CFrame.new(popPosition) * popRotation,
				flight.StartLength,
				flight.StartDiameter,
				flight.StartCapThickness,
				flight.StartCapDiameter
			)
			return
		end

		local flightT = math.clamp((localElapsed - flight.PopDuration) / flight.FlightDuration, 0, 1)
		local targetOffset = CarryLayout.GetTorsoRelativeTargetCFrame(flight.TargetStack, flight.TargetIndex)
		if typeof(targetOffset) ~= "CFrame" then
			cleanupFlight(key, flight)
			return
		end
		local targetCFrame = torso.CFrame * targetOffset
		local endPosition = targetCFrame.Position
		local curveT = flightT ^ 2.1
		local popPosition = flight.StartPosition + Vector3.new(0, 0.72, 0)
		local control1 = popPosition + Vector3.new(0, 2.1, 0) + (endPosition - popPosition) * 0.10
		local control2 = endPosition + Vector3.new(0, 0.55, 0)
		local position = bezier(popPosition, control1, control2, endPosition, curveT)
		local orientT = smoothStep(flightT)
		local baseRotation = flight.StartRotation:Lerp(targetCFrame.Rotation, orientT)
		local spinEnvelope = 1 - orientT
		local spin = math.sin(flightT * math.pi * 2) * 0.16 * spinEnvelope
		local tilt = math.sin(flightT * math.pi) * 0.12 * spinEnvelope
		local yaw = 0.32 * spinEnvelope
		local visualCFrame = CFrame.new(position) * baseRotation * CFrame.Angles(tilt, yaw, spin)
		local shrinkT = smoothStep((flightT - 0.04) / 0.96)
		local remaining = 1 - shrinkT
		local bodyLength = CARRY_LOG_LENGTH + (flight.StartLength - CARRY_LOG_LENGTH) * remaining
		local bodyDiameter = CARRY_LOG_DIAMETER + (flight.StartDiameter - CARRY_LOG_DIAMETER) * remaining
		local capThickness = CARRY_CAP_THICKNESS + (flight.StartCapThickness - CARRY_CAP_THICKNESS) * remaining
		local capDiameter = CARRY_LOG_DIAMETER * CARRY_CAP_DIAMETER_RATIO
			+ (flight.StartCapDiameter - CARRY_LOG_DIAMETER * CARRY_CAP_DIAMETER_RATIO) * remaining
		setVisualTransform(flight, visualCFrame, bodyLength, bodyDiameter, capThickness, capDiameter)

		if flightT >= 1 then
			-- Put the last rendered frame directly on the shared carry slot, then
			-- play the cue locally on that same frame as the carried stack appears.
			setVisualTransform(
				flight,
				targetCFrame,
				CARRY_LOG_LENGTH,
				CARRY_LOG_DIAMETER,
				CARRY_CAP_THICKNESS,
				CARRY_LOG_DIAMETER * CARRY_CAP_DIAMETER_RATIO
			)
			playArrivalSound()
			cleanupFlight(key, flight)
		end
	end)
end

pickupFXRemote.OnClientEvent:Connect(startFlight)
