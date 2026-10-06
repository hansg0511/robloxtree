-- Renders server-confirmed ground-log pickups locally. This animation is
-- cosmetic; inventory ownership and pickup validation stay server-authoritative.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local economyFolder = ReplicatedStorage:WaitForChild("Economy")
local pickupFXRemote = economyFolder:WaitForChild("PickupLogFXRE")
local CarryLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarryLayout"))

local FX_FOLDER_NAME = "ClientPickupLogFX"
local SOUND_ID = "rbxassetid://140303363726378"
local SOUND_VOLUME = 0.85
local SOUND_REGION = NumberRange.new(0.22, 0.38)
local SOUND_POOL_SIZE = 16
local PICKUP_AUDIO_SPACING = 0.06
local PICKUP_COMBO_RESET_WINDOW = 1.5
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
-- LogService can accept a 24-log pickup batch; retain room for a short overlap
-- while the preceding batch is still homing/settling.
local MAX_CONCURRENT_FLIGHTS = 32

local CARRY_LOG_LENGTH = 2.15
local CARRY_LOG_DIAMETER = 0.48
local CARRY_CAP_THICKNESS = 0.07
local WORLD_LOG_DIAMETER = 0.48
local WORLD_CAP_DIAMETER_RATIO = 0.88
local CARRY_CAP_DIAMETER_RATIO = 0.88
local GROUND_TO_CARRY_SCALE = 4
local DEFAULT_POP_DURATION = 0.10
local DEFAULT_PICKUP_HOMING_SPEED = 24
local DEFAULT_PICKUP_ARRIVAL_RADIUS = 2.5
local LOCAL_PLAYER_HOLD_RADIUS = 1.5
local LOCAL_HOLD_OFFSET_RADIUS = 1.7
local DEFAULT_CARRY_SETTLE_DURATION = 0.16
local DEFAULT_OVERFLOW_SETTLE_DURATION = 0.28
local MAX_CLIENT_HOMING_LIFETIME = 45
local DEBUG_PICKUP_HOMING = false

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

local function debugHomingTransition(transition, flight)
	if not DEBUG_PICKUP_HOMING then return end
	local uid = flight and flight.UID or "?"
	local outcome = flight and flight.Outcome or "?"
	print(("[PickupHoming] %s uid=%s outcome=%s"):format(transition, tostring(uid), tostring(outcome)))
end

local function moveToward(currentPosition, targetPosition, maxDistance)
	local delta = targetPosition - currentPosition
	local distance = delta.Magnitude
	if distance <= maxDistance or distance <= 1e-5 then
		return targetPosition
	end
	return currentPosition + delta * (maxDistance / distance)
end

local function getFinalTargetOffset(value)
	if isFiniteVector3(value) then
		return value
	end
	if type(value) ~= "table"
		or not isFiniteNumber(value.X)
		or not isFiniteNumber(value.Y)
		or not isFiniteNumber(value.Z) then
		return nil
	end
	return Vector3.new(value.X, value.Y, value.Z)
end

local function getHoldOffset(root, currentPosition)
	local relative = root.CFrame:VectorToObjectSpace(currentPosition - root.Position)
	local horizontal = Vector3.new(relative.X, 0, relative.Z)
	if horizontal.Magnitude <= 1e-4 then
		horizontal = Vector3.new(0, 0, -1)
	else
		horizontal = horizontal.Unit
	end
	return horizontal * LOCAL_HOLD_OFFSET_RADIUS + Vector3.new(0, math.clamp(relative.Y, -0.25, 0.5), 0)
end

local function setHomingVisual(flight, position, rotation, visualScale)
	local diameter = WORLD_LOG_DIAMETER * visualScale
	setVisualTransform(
		flight,
		CFrame.new(position) * rotation,
		CARRY_LOG_LENGTH * visualScale,
		diameter,
		CARRY_CAP_THICKNESS * visualScale,
		diameter * WORLD_CAP_DIAMETER_RATIO
	)
end

local function getCarrySettleTarget(flight, torso)
	local offset = flight.Resolution and flight.Resolution.TargetOffset
	if not offset then return nil end
	local anchorRelativeTarget = CarryLayout.GetAnchorRelativeCFrame() * CFrame.new(offset)
	return torso.CFrame * anchorRelativeTarget
end

local function beginFinalSettle(flight)
	if flight.State == "CarrySettle" or flight.State == "OverflowSettle" then return end
	if not flight.LocalReached or not flight.Resolution then return end

	flight.SettleStartCFrame = CFrame.new(flight.CurrentPosition) * flight.Rotation
	flight.SettleElapsed = 0
	flight.State = flight.Resolution.Kind == "Carry" and "CarrySettle" or "OverflowSettle"
end

local function startHomingFlight(payload)
	if type(payload) ~= "table"
		or type(payload.OwnerUserId) ~= "number"
		or type(payload.UID) ~= "string"
		or #payload.UID == 0
		or #payload.UID > 80
		or not isFiniteCFrame(payload.SourceCFrame)
		or (payload.Outcome ~= "Carry" and payload.Outcome ~= "Overflow") then
		return
	end

	local owner = Players:GetPlayerByUserId(payload.OwnerUserId)
	if not owner then return end
	local localRoot = getPlayerRoot(localPlayer.Character)
	if owner ~= localPlayer and (not localRoot
		or (localRoot.Position - payload.SourceCFrame.Position).Magnitude > MAX_OBSERVER_DISTANCE) then
		return
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
	local sourceCFrame = payload.SourceCFrame
	local model, body, caps = createFlightVisual(sourceCFrame, barkColor, cutEndColor)
	local carryVisualScale = getPayloadNumber(payload, "CarryVisualScale", 1, 0.05, 4)
	local groundToCarryScale = getPayloadNumber(payload, "GroundToCarryScale", GROUND_TO_CARRY_SCALE, 1, 8)
	local expectedStartScale = carryVisualScale * groundToCarryScale
	local startVisualScale = getPayloadNumber(payload, "StartVisualScale", expectedStartScale, 0.05, 16)
	-- Keep the authored 4x ground-to-carry relationship even if an older or
	-- malformed payload sends one global start scale for every material.
	if math.abs(startVisualScale - expectedStartScale) > 1e-3 then
		startVisualScale = expectedStartScale
	end
	local flight = {
		Model = model,
		Body = body,
		Caps = caps,
		Owner = owner,
		OwnerUserId = payload.OwnerUserId,
		UID = payload.UID,
		Mode = "Homing",
		Outcome = payload.Outcome,
		CurrentPosition = sourceCFrame.Position,
		Rotation = sourceCFrame.Rotation,
		CarryVisualScale = carryVisualScale,
		StartVisualScale = startVisualScale,
		HomingSpeed = getPayloadNumber(payload, "HomingSpeed", DEFAULT_PICKUP_HOMING_SPEED, 1, 120),
		ArrivalRadius = getPayloadNumber(payload, "ArrivalRadius", DEFAULT_PICKUP_ARRIVAL_RADIUS, 0.5, 6),
		PopDuration = getPayloadNumber(payload, "PopDuration", DEFAULT_POP_DURATION, 0.04, 0.3),
		LaunchDelay = getPayloadNumber(payload, "LaunchDelay", 0, 0, 1),
		Elapsed = 0,
		Lifetime = 0,
		State = "Pop",
		LocalReached = false,
		Resolution = nil,
	}
	activeFlights[key] = flight
	activeFlightCount += 1
	setHomingVisual(flight, sourceCFrame.Position, flight.Rotation, flight.StartVisualScale)
	debugHomingTransition("START", flight)

	flight.Connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not flight.Model or not flight.Model.Parent or not owner:IsDescendantOf(Players) then
			cleanupFlight(key, flight)
			return
		end
		flight.Lifetime += deltaTime
		local overflowInHold = flight.Outcome == "Overflow" and flight.State == "Hold"
		if flight.Lifetime > MAX_CLIENT_HOMING_LIFETIME and not overflowInHold then
			debugHomingTransition("MISSING_RESOLUTION_TIMEOUT", flight)
			cleanupFlight(key, flight)
			return
		end

		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = getPlayerRoot(character)
		local torso = character and findTorso(character)
		if not character or not humanoid or humanoid.Health <= 0 or not root or not torso then
			cleanupFlight(key, flight)
			return
		end

		flight.Elapsed += deltaTime
		if flight.Elapsed < flight.LaunchDelay then return end
		local activeElapsed = flight.Elapsed - flight.LaunchDelay
		if activeElapsed < flight.PopDuration then
			local popT = activeElapsed / flight.PopDuration
			local popEase = 1 - (1 - popT) ^ 3
			local popPosition = sourceCFrame.Position + Vector3.new(0, 0.72 * popEase, 0)
			setHomingVisual(flight, popPosition, flight.Rotation, flight.StartVisualScale)
			return
		end

		if flight.State == "Pop" then
			flight.State = "Homing"
			flight.CurrentPosition = sourceCFrame.Position + Vector3.new(0, 0.72, 0)
		end

		if flight.State == "Homing" then
			local homingTarget = root.Position + Vector3.new(0, 0.35, 0)
			flight.CurrentPosition = moveToward(
				flight.CurrentPosition,
				homingTarget,
				flight.HomingSpeed * deltaTime
			)
			if (flight.CurrentPosition - homingTarget).Magnitude <= LOCAL_PLAYER_HOLD_RADIUS then
				flight.LocalReached = true
				flight.HoldOffset = getHoldOffset(root, flight.CurrentPosition)
				flight.State = "Hold"
				debugHomingTransition("LOCAL_REACHED_PLAYER", flight)
			end
		end

		if flight.State == "Hold" then
			local holdTarget = root.CFrame:PointToWorldSpace(flight.HoldOffset)
			flight.CurrentPosition = moveToward(
				flight.CurrentPosition,
				holdTarget,
				flight.HomingSpeed * deltaTime
			)
			if flight.Resolution then
				beginFinalSettle(flight)
			end
		end

		if flight.State == "CarrySettle" or flight.State == "OverflowSettle" then
			local resolution = flight.Resolution
			flight.SettleElapsed += deltaTime
			local settleT = math.clamp(flight.SettleElapsed / resolution.Duration, 0, 1)
			local easedT = smoothStep(settleT)
			local targetCFrame
			if flight.State == "CarrySettle" then
				targetCFrame = getCarrySettleTarget(flight, torso)
			else
				targetCFrame = resolution.PileTargetCFrame
			end
			if not targetCFrame then
				debugHomingTransition("MALFORMED_RESOLUTION", flight)
				cleanupFlight(key, flight)
				return
			end

			local startCFrame = flight.SettleStartCFrame
			local startPosition = startCFrame.Position
			local endPosition = targetCFrame.Position
			local control1 = startPosition + (endPosition - startPosition) * 0.28 + Vector3.new(0, 0.35, 0)
			local control2 = endPosition + Vector3.new(0, 0.35, 0)
			local position = bezier(startPosition, control1, control2, endPosition, easedT)
			local rotation = startCFrame.Rotation:Lerp(targetCFrame.Rotation, easedT)
			local visualScale = flight.StartVisualScale
			if flight.State == "CarrySettle" then
				visualScale += (flight.CarryVisualScale - flight.StartVisualScale) * easedT
			end
			setHomingVisual(flight, position, rotation, visualScale)

			if settleT >= 1 then
				setHomingVisual(
					flight,
					targetCFrame.Position,
					targetCFrame.Rotation,
					flight.State == "CarrySettle" and flight.CarryVisualScale or flight.StartVisualScale
				)
				debugHomingTransition("SETTLE_COMPLETE", flight)
				if flight.State == "CarrySettle" then
					queueArrivalSound()
				end
				cleanupFlight(key, flight)
				return
			end
		else
			setHomingVisual(flight, flight.CurrentPosition, flight.Rotation, flight.StartVisualScale)
		end
	end)
end

local function findHomingFlight(payload)
	if type(payload.OwnerUserId) == "number" then
		local key = tostring(payload.OwnerUserId) .. ":" .. payload.UID
		local flight = activeFlights[key]
		if flight and flight.Mode == "Homing" then
			return key, flight
		end
	end
	-- Older server builds may omit OwnerUserId on the resolution. UID values are
	-- generated per log; scan only the small bounded cosmetic flight registry.
	for key, flight in pairs(activeFlights) do
		if flight.Mode == "Homing" and flight.UID == payload.UID then
			return key, flight
		end
	end
	return nil, nil
end

local function resolveHomingFlight(payload)
	if type(payload) ~= "table" or type(payload.UID) ~= "string" or #payload.UID == 0 then
		return
	end
	local key, flight = findHomingFlight(payload)
	if not flight then
		if DEBUG_PICKUP_HOMING then
			warn(("[PickupHoming] LATE_OR_UNKNOWN_RESOLUTION uid=%s mode=%s"):format(payload.UID, tostring(payload.Mode)))
		end
		return
	end

	if payload.Mode == "Cancel" then
		debugHomingTransition("RESOLUTION_RECEIVED_CANCEL", flight)
		cleanupFlight(key, flight)
		return
	end
	if payload.Mode == "CarryResolve" and flight.Outcome == "Carry" then
		local targetOffset = getFinalTargetOffset(payload.FinalTargetOffset)
		if not targetOffset then
			debugHomingTransition("MALFORMED_RESOLUTION", flight)
			cleanupFlight(key, flight)
			return
		end
		flight.Resolution = {
			Kind = "Carry",
			TargetOffset = targetOffset,
			Duration = getPayloadNumber(payload, "FinalSettleDuration", DEFAULT_CARRY_SETTLE_DURATION, 0.05, 0.8),
		}
	elseif payload.Mode == "OverflowResolve" and flight.Outcome == "Overflow" then
		local targetCFrame = payload.PileTargetCFrame
		if not isFiniteCFrame(targetCFrame) then
			debugHomingTransition("MALFORMED_RESOLUTION", flight)
			cleanupFlight(key, flight)
			return
		end
		flight.Resolution = {
			Kind = "Overflow",
			PileTargetCFrame = targetCFrame,
			Duration = getPayloadNumber(payload, "FinalSettleDuration", DEFAULT_OVERFLOW_SETTLE_DURATION, 0.05, 1),
		}
	else
		debugHomingTransition("MALFORMED_RESOLUTION", flight)
		cleanupFlight(key, flight)
		return
	end

	debugHomingTransition("RESOLUTION_RECEIVED", flight)
	if flight.LocalReached then
		beginFinalSettle(flight)
	end
end

local function onPickupFX(payload)
	if type(payload) ~= "table" then return end
	if payload.Mode == "Homing" then
		startHomingFlight(payload)
	elseif payload.Mode == "CarryResolve" or payload.Mode == "OverflowResolve" or payload.Mode == "Cancel" then
		resolveHomingFlight(payload)
	else
		if DEBUG_PICKUP_HOMING then
			warn(("[PickupHoming] IGNORED_UNKNOWN_MODE mode=%s"):format(tostring(payload.Mode)))
		end
	end
end

pickupFXRemote.OnClientEvent:Connect(onPickupFX)
