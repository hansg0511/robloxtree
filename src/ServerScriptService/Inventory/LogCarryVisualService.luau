-- Server-replicated cosmetic back cargo for owned log inventory records.
-- Log ownership and inventory remain authoritative in the profile; this module
-- only projects a bounded list of those records onto the character.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))

local LogCarryVisualService = {}

local MAX_CARRIED_LOGS = 40
local MAX_RECORDS_SCANNED = 160
local COLUMNS_PER_STACK = 1
local LOG_LAYER_HEIGHT = 0.5
local NORMAL_STACK_CENTER_X = -1.15
local RARE_STACK_CENTER_X = 1.15
-- Leave a deliberate clear gap behind the body for the future bag model.
-- Cargo floats outside that future volume instead of clipping through a torso.
local CARGO_BACK_OFFSET = 1.75
local CARGO_BASE_HEIGHT = 0.68
local LOG_LENGTH = 2.15

local latestRecordsByPlayer = {}
local buildSerialByPlayer = {}
local modelByPlayer = {}
local playerConnections = {}
local deathConnectionByPlayer = {}

local function isPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function isNonemptyString(value, maxLength)
	return type(value) == "string"
		and #value > 0
		and #value <= maxLength
		and string.match(value, "%S") ~= nil
end

local function disconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

local function clearCharacterModel(player, character)
	local trackedModel = modelByPlayer[player]
	if trackedModel and trackedModel.Parent == character then
		trackedModel:Destroy()
		modelByPlayer[player] = nil
	end

	-- Also remove a prior instance if this module was reloaded and lost its
	-- in-memory model reference. The attribute keeps cleanup scoped to our own
	-- replicated cosmetic.
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model")
			and child.Name == "CarriedLogs"
			and child:GetAttribute("LogCarryVisuals") == true then
			child:Destroy()
		end
	end
end

local function invalidatePendingBuild(player)
	buildSerialByPlayer[player] = (buildSerialByPlayer[player] or 0) + 1
end

local function clearCurrentCharacter(player, character)
	invalidatePendingBuild(player)
	if character and character.Parent then
		clearCharacterModel(player, character)
	else
		local trackedModel = modelByPlayer[player]
		if trackedModel then
			trackedModel:Destroy()
			modelByPlayer[player] = nil
		end
	end
end

local function snapshotRecords(logRecords)
	local normalLogs = {}
	local rareLogs = {}
	local seenUids = {}
	local scanned = 0

	for _, logRecord in ipairs(logRecords) do
		scanned += 1
		if scanned > MAX_RECORDS_SCANNED or (#normalLogs + #rareLogs) >= MAX_CARRIED_LOGS then
			break
		end

		if type(logRecord) == "table"
			and logRecord.ItemType == "Log"
			and isNonemptyString(logRecord.UID, 80)
			and isNonemptyString(logRecord.SpeciesId, 64)
			and not seenUids[logRecord.UID] then
			local snapshot = {
				UID = logRecord.UID,
				ItemType = "Log",
				SpeciesId = logRecord.SpeciesId,
				IsRare = SpeciesVisuals.IsRareLog(logRecord),
			}
			seenUids[logRecord.UID] = true
			if snapshot.IsRare then
				table.insert(rareLogs, snapshot)
			else
				table.insert(normalLogs, snapshot)
			end
		end
	end

	return normalLogs, rareLogs
end

local function makeNonPhysicalPart(part)
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function addWeld(part0, part1, name)
	local weld = Instance.new("WeldConstraint")
	weld.Name = name
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

local function createCargoAnchor(torso, model)
	local anchor = Instance.new("Part")
	anchor.Name = "CargoAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CastShadow = false
	makeNonPhysicalPart(anchor)
	anchor.CFrame = torso.CFrame * CFrame.new(0, 0.42, CARGO_BACK_OFFSET)
	anchor.Parent = model
	addWeld(torso, anchor, "CargoAnchorWeld")
	return anchor
end

local function addLogVisual(model, anchor, logRecord, stackName, stackIndex)
	local stackCenterX = stackName == "Rare" and RARE_STACK_CENTER_X or NORMAL_STACK_CENTER_X
	local layerIndex = math.floor((stackIndex - 1) / COLUMNS_PER_STACK)
	local localPosition = Vector3.new(
		stackCenterX,
		CARGO_BASE_HEIGHT + layerIndex * LOG_LAYER_HEIGHT,
		0
	)
	-- Keep each log horizontally across the character's back rather than pointed
	-- into their body. The anchor already supplies the deliberate rear gap.
	local logCFrame = anchor.CFrame
		* CFrame.new(localPosition)

	local body, caps = SpeciesVisuals.CreateCarryLogParts(logRecord)
	body.CFrame = logCFrame
	body:SetAttribute("LogUID", logRecord.UID)
	body:SetAttribute("CarryStack", stackName)
	body:SetAttribute("IsRare", logRecord.IsRare == true)
	body.Parent = model
	addWeld(anchor, body, "CarriedLogWeld")

	local capOffset = LOG_LENGTH * 0.5 - 0.07 * 0.5
	for capIndex, cap in ipairs(caps) do
		local direction = capIndex == 1 and -1 or 1
		cap.CFrame = logCFrame * CFrame.new(direction * capOffset, 0, 0)
		cap:SetAttribute("LogUID", logRecord.UID)
		cap:SetAttribute("CarryStack", stackName)
		cap:SetAttribute("IsRare", logRecord.IsRare == true)
		cap.Parent = model
		addWeld(anchor, cap, "CarriedLogCapWeld")
	end
end

local function findTorso(character)
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso and upperTorso:IsA("BasePart") then
		return upperTorso
	end
	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return nil
end

local function buildForCharacter(player, character, categorizedRecords)
	if player.Character ~= character or not character:IsDescendantOf(workspace) then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = findTorso(character)
	if not humanoid or humanoid.Health <= 0 or not torso then
		return false
	end

	clearCharacterModel(player, character)

	local normalLogs = categorizedRecords.Normal
	local rareLogs = categorizedRecords.Rare
	if #normalLogs + #rareLogs == 0 then
		return true
	end

	local model = Instance.new("Model")
	model.Name = "CarriedLogs"
	model:SetAttribute("LogCarryVisuals", true)
	model:SetAttribute("NormalLogCount", #normalLogs)
	model:SetAttribute("RareLogCount", #rareLogs)
	model:SetAttribute("TotalLogCount", #normalLogs + #rareLogs)

	local anchor = createCargoAnchor(torso, model)
	model.PrimaryPart = anchor
	for index, logRecord in ipairs(normalLogs) do
		addLogVisual(model, anchor, logRecord, "Normal", index)
	end
	for index, logRecord in ipairs(rareLogs) do
		addLogVisual(model, anchor, logRecord, "Rare", index)
	end

	model.Parent = character
	modelByPlayer[player] = model
	return true
end

local function scheduleCharacterBuild(player, character)
	local serial = (buildSerialByPlayer[player] or 0) + 1
	buildSerialByPlayer[player] = serial

	task.defer(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local torso = findTorso(character)
		for _ = 1, 50 do
			if buildSerialByPlayer[player] ~= serial
				or player.Character ~= character
				or not player:IsDescendantOf(Players) then
				return
			end
			if humanoid and torso then
				break
			end
			task.wait(0.1)
			humanoid = character:FindFirstChildOfClass("Humanoid")
			torso = findTorso(character)
		end

		if not humanoid or not torso or humanoid.Health <= 0 then
			return
		end

		local categorizedRecords = latestRecordsByPlayer[player]
		if categorizedRecords then
			buildForCharacter(player, character, categorizedRecords)
		end

		disconnect(deathConnectionByPlayer[player])
		deathConnectionByPlayer[player] = humanoid.Died:Connect(function()
			if player.Character == character then
				clearCurrentCharacter(player, character)
			end
		end)
	end)
end

local function clearPlayerState(player)
	clearCurrentCharacter(player, player.Character)
	latestRecordsByPlayer[player] = nil
	disconnect(deathConnectionByPlayer[player])
	deathConnectionByPlayer[player] = nil

	local connections = playerConnections[player]
	if connections then
		disconnect(connections.CharacterAdded)
		disconnect(connections.CharacterRemoving)
		playerConnections[player] = nil
	end
	buildSerialByPlayer[player] = nil
end

local function bindPlayer(player)
	if playerConnections[player] then
		return
	end

	local connections = {}
	connections.CharacterAdded = player.CharacterAdded:Connect(function(character)
		scheduleCharacterBuild(player, character)
	end)
	connections.CharacterRemoving = player.CharacterRemoving:Connect(function(character)
		clearCurrentCharacter(player, character)
		disconnect(deathConnectionByPlayer[player])
		deathConnectionByPlayer[player] = nil
	end)
	playerConnections[player] = connections

	if player.Character then
		scheduleCharacterBuild(player, player.Character)
	end
end

function LogCarryVisualService.RebuildCarryVisuals(player, authoritativeLogRecords)
	if not isPlayer(player) then
		return false
	end

	bindPlayer(player)
	if authoritativeLogRecords ~= nil then
		if type(authoritativeLogRecords) ~= "table" then
			return false
		end
		local normalLogs, rareLogs = snapshotRecords(authoritativeLogRecords)
		latestRecordsByPlayer[player] = {
			Normal = normalLogs,
			Rare = rareLogs,
		}
	elseif latestRecordsByPlayer[player] == nil then
		return false
	end

	local character = player.Character
	if character then
		clearCurrentCharacter(player, character)
		scheduleCharacterBuild(player, character)
	end
	return true
end

function LogCarryVisualService.ClearCarryVisuals(player)
	if not isPlayer(player) then
		return false
	end

	latestRecordsByPlayer[player] = nil
	clearCurrentCharacter(player, player.Character)
	return true
end

function LogCarryVisualService.IsRareLog(logRecord)
	return SpeciesVisuals.IsRareLog(logRecord)
end

LogCarryVisualService.MAX_CARRIED_LOGS = MAX_CARRIED_LOGS

Players.PlayerAdded:Connect(bindPlayer)
Players.PlayerRemoving:Connect(clearPlayerState)
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

return LogCarryVisualService
