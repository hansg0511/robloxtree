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
local SOUND_REGION = NumberRange.new(0.22, 0.38)
local SOUND_POOL_SIZE = 16
local PICKUP_AUDIO_SPACING = 0.06
local PICKUP_COMBO_RESET_WINDOW = 0.4
local MAX_QUEUED_PICKUP_CUES = 64
-- Fifteen-note major-scale ladder across two octaves, including both endpoints.
-- Semitone degrees: 0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24.
-- The 0.75x root starts lower; notes 1/8/15 are 0.75x/1.5x/3x.
-- Notes 1-15 ascend through the scale; later pickups stay at the 3x endpoint.
local PICKUP_COMBO_PITCHES = {
	0.750000,
	0.841847,
	0.944941,
	1.001130,
	1.123730,
	1.261345,
	1.415812,
	1.500000,
	1.683693,
	1.889882,
	2.002260,
	2.247461,
	2.522690,
	2.831623,
	3.000000,
}
local MAX_OBSERVER_DISTANCE = 260
local MAX_CONCURRENT_FLIGHTS = 16

local CARRY_LOG_LENGTH = 2.15
local CARRY_LOG_DIAMETER = 0.48
local CARRY_CAP_THICKNESS = 0.07
local WORLD_LOG_DIAMETER = 0.48
local WORLD_CAP_DIAMETER_RATIO = 0.88
local CARRY_CAP_DIAMETER_RATIO = 0.88
local GROUND_TO_CARRY_SCALE = 4
local DEFAULT_POP_DURATION = 0.10
local DEFAULT_FLIGHT_DURATION = 0.37
local DEFAULT_OVERFLOW_FLIGHT_DURATION = 0.52
local MAX_LAUNCH_OFFSET = 0.35
local OVERFLOW_PLAYER_APPROACH_FRACTION = 0.44

local activeFlights = {}
local soundPool = {}
local availableSounds = {}
local queuedPickupPitches = table.create(MAX_QUEUED_PICKUP_CUES)
local soundReady = false
local activeFlightCount = 0
local queuedCueHead = 1
local queuedCueTail = 0
local queuedCueCount = 0
local pickupAudioQueueRunning = false
local nextPickupSoundAt = 0
local lastPickupAudioArrivalAt = nil
local pickupAudioComboStep = 0

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

local function playArrivalSound(playbackSpeed)
	if not soundReady or #availableSounds == 0 then return end

	local slot = table.remove(availableSounds)
	if not slot or slot.Busy then return end
	slot.Busy = true
	local sound = slot.Sound
	sound.PlaybackSpeed = playbackSpeed
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

local function dequeuePickupPitch()
	if queuedCueCount <= 0 then return nil end
	local pitch = queuedPickupPitches[queuedCueHead]
	queuedPickupPitches[queuedCueHead] = nil
	queuedCueHead = queuedCueHead % MAX_QUEUED_PICKUP_CUES + 1
	queuedCueCount -= 1
	return pitch
end

local function runPickupAudioQueue()
	if pickupAudioQueueRunning or queuedCueCount == 0 then return end
	pickupAudioQueueRunning = true

	task.spawn(function()
		while queuedCueCount > 0 do
			local waitDuration = nextPickupSoundAt - os.clock()
			if waitDuration > 0 then
				task.wait(waitDuration)
			end

			local pitch = dequeuePickupPitch()
			if pitch then
				playArrivalSound(pitch)
				nextPickupSoundAt = os.clock() + PICKUP_AUDIO_SPACING
			end
		end

		pickupAudioQueueRunning = false
		-- No yield occurs between observing an empty queue and clearing the flag,
		-- but retain this guard so future queue changes cannot strand a cue.
		if queuedCueCount > 0 then
			runPickupAudioQueue()
		end
	end)
end

local function queueArrivalSound()
	if not soundReady or queuedCueCount >= MAX_QUEUED_PICKUP_CUES then return end

	local now = os.clock()
	if not lastPickupAudioArrivalAt or now - lastPickupAudioArrivalAt > PICKUP_COMBO_RESET_WINDOW then
		pickupAudioComboStep = 0
	end
	lastPickupAudioArrivalAt = now
	pickupAudioComboStep = math.min(pickupAudioComboStep + 1, #PICKUP_COMBO_PITCHES)

	queuedCueTail = queuedCueTail % MAX_QUEUED_PICKUP_CUES + 1
	queuedPickupPitches[queuedCueTail] = PICKUP_COMBO_PITCHES[pickupAudioComboStep]
	queuedCueCount += 1
	runPickupAudioQueue()
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

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function isFiniteCFrame(value)
	if typeof(value) ~= "CFrame" then return false end
	for _, component in ipairs({ value:GetComponents() }) do
		if not isFiniteNumber(component) then
			return false
		end
	end
	return true
end

local function getOverflowTargetCFrame(payload)
	local targetCFrame = payload.PileTargetCFrame
	if isFiniteCFrame(targetCFrame) then
		return targetCFrame
	end

	-- Position-only payloads are accepted as a defensive compatibility fallback.
	-- The server remains the only source of this target; a missing/invalid target
	-- causes the cosmetic flight to be skipped rather than guessed locally.
	local targetPosition = payload.PileTargetPosition
	if not isFiniteVector3(targetPosition) then
		return nil
	end

	local targetYaw = payload.PileTargetYaw
	if not isFiniteNumber(targetYaw) then
		targetYaw = 0
	end
	return CFrame.new(targetPosition) * CFrame.Angles(0, targetYaw, 0)
end

local function getFlatYaw(cframe)
	local _, yaw = cframe:ToOrientation()
	return yaw
end

local function shortestAngleDelta(fromAngle, toAngle)
	return math.atan2(math.sin(toAngle - fromAngle), math.cos(toAngle - fromAngle))
end

local function getTargetOffset(payload)
	local offset = payload.TargetOffset
	if type(offset) ~= "table" then return nil end
	for _, key in ipairs({ "X", "Y", "Z" }) do
		local value = offset[key]
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
	end
	if math.abs(offset.X) > 8 or offset.Y < 0 or offset.Y > 32 or math.abs(offset.Z) > 8 then
		return nil
	end
	return Vector3.new(offset.X, offset.Y, offset.Z)
end

local function startFlight(payload)
	if type(payload) ~= "table" then return end

	local isOverflowFlight = payload.Mode == "Overflow" or payload.Mode == "OverflowPile"
	if payload.Mode ~= nil and payload.Mode ~= "Normal" and not isOverflowFlight then
		return
	end
	local overflowTargetCFrame = isOverflowFlight and getOverflowTargetCFrame(payload) or nil
	if isOverflowFlight and not overflowTargetCFrame then
		return
	end

	if type(payload.OwnerUserId) ~= "number"
		or type(payload.UID) ~= "string"
		or #payload.UID == 0
		or typeof(payload.StartCFrame) ~= "CFrame"
		or (not isOverflowFlight and (payload.TargetStack ~= "Normal" and payload.TargetStack ~= "Rare"))
		or (not isOverflowFlight and type(payload.TargetIndex) ~= "number")
		or (not isOverflowFlight and payload.TargetIndex < 1) then
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
	local carryVisualScale = getPayloadNumber(payload, "CarryVisualScale", 1, 0.05, 4)
	local flightDuration = getPayloadNumber(payload, "FlightDuration", DEFAULT_FLIGHT_DURATION, 0.22, 0.55)
	if isOverflowFlight then
		flightDuration = getPayloadNumber(
			payload,
			"OverflowFlightDuration",
			getPayloadNumber(payload, "FlightDuration", DEFAULT_OVERFLOW_FLIGHT_DURATION, 0.22, 1.2),
			0.22,
			1.2
		)
	end
	local flight = {
		Model = model,
		Body = body,
		Caps = caps,
		Owner = owner,
		Mode = isOverflowFlight and "Overflow" or "Normal",
		TargetStack = not isOverflowFlight and payload.TargetStack or nil,
		TargetIndex = not isOverflowFlight and math.floor(payload.TargetIndex) or nil,
		StartCFrame = payload.StartCFrame,
		StartPosition = payload.StartCFrame.Position,
		StartRotation = payload.StartCFrame.Rotation,
		OverflowTargetCFrame = overflowTargetCFrame,
		StartYaw = isOverflowFlight and getFlatYaw(payload.StartCFrame) or nil,
		TargetYaw = overflowTargetCFrame and getFlatYaw(overflowTargetCFrame) or nil,
		-- The server authors the material-specific carry scale. The world drop is
		-- always exactly four times this scale.
		CarryVisualScale = carryVisualScale,
		StartScale = carryVisualScale * GROUND_TO_CARRY_SCALE,
		TargetOffset = getTargetOffset(payload),
		LaunchOffset = getPayloadNumber(payload, "LaunchOffset", 0, 0, MAX_LAUNCH_OFFSET),
		PopDuration = getPayloadNumber(payload, "PopDuration", DEFAULT_POP_DURATION, 0.04, 0.18),
		FlightDuration = flightDuration,
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

		if flight.Mode == "Overflow" then
			local targetCFrame = flight.OverflowTargetCFrame
			local playerRoot = getPlayerRoot(character)
			if not targetCFrame or not playerRoot then
				cleanupFlight(key, flight)
				return
			end

			local visualRotation
			if localElapsed < flight.PopDuration then
				local popT = localElapsed / flight.PopDuration
				local popEase = 1 - (1 - popT) ^ 3
				local popPosition = flight.StartPosition + Vector3.new(0, 0.72 * popEase, 0)
				visualRotation = CFrame.Angles(0, flight.StartYaw, 0)
				setVisualTransform(
					flight,
					CFrame.new(popPosition) * visualRotation,
					flight.StartLength,
					flight.StartDiameter,
					flight.StartCapThickness,
					flight.StartCapDiameter
				)
				return
			end

			local flightT = math.clamp((localElapsed - flight.PopDuration) / flight.FlightDuration, 0, 1)
			local popPosition = flight.StartPosition + Vector3.new(0, 0.72, 0)
			local approachPosition = torso.Position + Vector3.new(0, 0.45, 0)
			local targetPosition = targetCFrame.Position
			local position
			if flightT < OVERFLOW_PLAYER_APPROACH_FRACTION then
				local phaseT = smoothStep(flightT / OVERFLOW_PLAYER_APPROACH_FRACTION)
				local towardPlayer = approachPosition - popPosition
				position = bezier(
					popPosition,
					popPosition + towardPlayer * 0.24 + Vector3.new(0, 1.8, 0),
					popPosition + towardPlayer * 0.76 + Vector3.new(0, 1.6, 0),
					approachPosition,
					phaseT
				)
			else
				local phaseT = smoothStep(
					(flightT - OVERFLOW_PLAYER_APPROACH_FRACTION)
						/ (1 - OVERFLOW_PLAYER_APPROACH_FRACTION)
				)
				local towardPile = targetPosition - approachPosition
				position = bezier(
					approachPosition,
					approachPosition + towardPile * 0.30 + Vector3.new(0, 1.6, 0),
					targetPosition + Vector3.new(0, 1.0, 0),
					targetPosition,
					phaseT
				)
			end

			local yaw = flight.StartYaw
				+ shortestAngleDelta(flight.StartYaw, flight.TargetYaw) * smoothStep(flightT)
			visualRotation = CFrame.Angles(0, yaw, 0)
			setVisualTransform(
				flight,
				CFrame.new(position) * visualRotation,
				flight.StartLength,
				flight.StartDiameter,
				flight.StartCapThickness,
				flight.StartCapDiameter
			)

			if flightT >= 1 then
				-- The authoritative ground log takes over at the exact server-authored
				-- pile slot. Keep its full ground scale and omit normal pickup audio.
				setVisualTransform(
					flight,
					targetCFrame,
					flight.StartLength,
					flight.StartDiameter,
					flight.StartCapThickness,
					flight.StartCapDiameter
				)
				cleanupFlight(key, flight)
			end
			return
		end

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
		local anchorRelativeTarget
		if flight.TargetOffset then
			anchorRelativeTarget = CarryLayout.GetAnchorRelativeCFrame() * CFrame.new(flight.TargetOffset)
		else
			local fallbackScales = table.create(flight.TargetIndex, flight.CarryVisualScale)
			anchorRelativeTarget = CarryLayout.GetTorsoRelativeTargetCFrame(
				flight.TargetStack,
				flight.TargetIndex,
				fallbackScales
			)
		end
		if typeof(anchorRelativeTarget) ~= "CFrame" then
			cleanupFlight(key, flight)
			return
		end
		local targetCFrame = torso.CFrame * anchorRelativeTarget
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
		local carryLength = CARRY_LOG_LENGTH * flight.CarryVisualScale
		local carryDiameter = CARRY_LOG_DIAMETER * flight.CarryVisualScale
		local carryCapThickness = CARRY_CAP_THICKNESS * flight.CarryVisualScale
		local carryCapDiameter = carryDiameter * CARRY_CAP_DIAMETER_RATIO
		local bodyLength = carryLength + (flight.StartLength - carryLength) * remaining
		local bodyDiameter = carryDiameter + (flight.StartDiameter - carryDiameter) * remaining
		local capThickness = carryCapThickness + (flight.StartCapThickness - carryCapThickness) * remaining
		local capDiameter = carryCapDiameter + (flight.StartCapDiameter - carryCapDiameter) * remaining
		setVisualTransform(flight, visualCFrame, bodyLength, bodyDiameter, capThickness, capDiameter)

		if flightT >= 1 then
			-- Put the last rendered frame directly on the shared carry slot, then
			-- play the cue locally on that same frame as the carried stack appears.
			setVisualTransform(
				flight,
				targetCFrame,
				CARRY_LOG_LENGTH * flight.CarryVisualScale,
				CARRY_LOG_DIAMETER * flight.CarryVisualScale,
				CARRY_CAP_THICKNESS * flight.CarryVisualScale,
				CARRY_LOG_DIAMETER * flight.CarryVisualScale * CARRY_CAP_DIAMETER_RATIO
			)
			queueArrivalSound()
			cleanupFlight(key, flight)
		end
	end)
end

pickupFXRemote.OnClientEvent:Connect(startFlight)
