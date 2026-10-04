-- Server-replicated cosmetic back cargo for owned log inventory records.
-- Log ownership and inventory remain authoritative in the profile; this module
-- only projects a bounded list of those records onto the character.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CarryLayout = require(game.ReplicatedStorage.Shared.CarryLayout)

local SpeciesVisuals = require(ServerStorage:WaitForChild("SpeciesVisuals"))

local LogCarryVisualService = {}

local MAX_CARRIED_LOGS = CarryLayout.MAX_CARRIED_LOGS
local MAX_RECORDS_SCANNED = 160

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
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	weld.C1 = CFrame.identity
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
	local anchorOffset = CarryLayout.GetAnchorRelativeCFrame()
	anchor.CFrame = torso.CFrame * anchorOffset
	anchor.Parent = model
	local weld = addWeld(torso, anchor, "CargoAnchorWeld")
	weld.C0 = anchorOffset
	return anchor
end

local function addLogVisual(model, anchor, logRecord, stackName, stackIndex)
	local slotCFrame = CarryLayout.GetAnchorRelativeSlotCFrame(stackName, stackIndex)
	if not slotCFrame then
		return nil
	end
	local logCFrame = anchor.CFrame * slotCFrame
	local body, caps = SpeciesVisuals.CreateCarryLogParts(logRecord)
	body.CFrame = logCFrame
	body:SetAttribute("LogUID", logRecord.UID)
	body:SetAttribute("CarryStack", stackName)
	body:SetAttribute("CarryIndex", stackIndex)
	body:SetAttribute("IsRare", logRecord.IsRare == true)
	body.Parent = model
	local bodyWeld = addWeld(anchor, body, "CarriedLogWeld")
	bodyWeld.C0 = slotCFrame

	local capOffset = body.Size.X * 0.5 - caps[1].Size.X * 0.5
	local capWelds = {}
	for capIndex, cap in ipairs(caps) do
		local direction = capIndex == 1 and -1 or 1
		local capRelativeCFrame = slotCFrame * CFrame.new(direction * capOffset, 0, 0)
		cap.CFrame = anchor.CFrame * capRelativeCFrame
		cap:SetAttribute("LogUID", logRecord.UID)
		cap:SetAttribute("CarryStack", stackName)
		cap:SetAttribute("CarryIndex", stackIndex)
		cap:SetAttribute("IsRare", logRecord.IsRare == true)
		cap.Parent = model
		capWelds[capIndex] = addWeld(anchor, cap, "CarriedLogCapWeld")
		capWelds[capIndex].C0 = capRelativeCFrame
	end
	return {
		Body = body,
		Caps = caps,
		BodyWeld = bodyWeld,
		CapWelds = capWelds,
		SpeciesId = logRecord.SpeciesId,
	}
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

-- Returns the exact server-side cargo slot for an arriving UID using the same
-- bounded ordering and spacing as the persistent back-stack projection.
function LogCarryVisualService.GetArrivalCFrame(player, stagedRecords, targetUID)
	if not isPlayer(player)
		or type(stagedRecords) ~= "table"
		or not isNonemptyString(targetUID, 80) then
		return nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character and findTorso(character)
	if not humanoid or humanoid.Health <= 0 or not torso then
		return nil
	end

	local normalLogs, rareLogs = snapshotRecords(stagedRecords)
	local stackName
	local stackIndex
	for index, logRecord in ipairs(normalLogs) do
		if logRecord.UID == targetUID then
			stackName = "Normal"
			stackIndex = index
			break
		end
	end
	if not stackIndex then
		for index, logRecord in ipairs(rareLogs) do
			if logRecord.UID == targetUID then
				stackName = "Rare"
				stackIndex = index
				break
			end
		end
	end
	if not stackIndex then
		return nil
	end

	local torsoRelativeTarget = CarryLayout.GetTorsoRelativeTargetCFrame(stackName, stackIndex)
	return torsoRelativeTarget and (torso.CFrame * torsoRelativeTarget) or nil
end

local function collectCarryVisuals(model)
	local visualsByUid = {}
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local uid = child:GetAttribute("LogUID")
			if isNonemptyString(uid, 80) then
				local visual = visualsByUid[uid]
				if not visual then
					visual = { Caps = {} }
					visualsByUid[uid] = visual
				end
				if child.Name == "CarryLogBody" then
					visual.Body = child
				elseif child.Name == "CarryLogCutEnd1" then
					visual.Caps[1] = child
				elseif child.Name == "CarryLogCutEnd2" then
					visual.Caps[2] = child
				end
			end
		end
	end
	return visualsByUid
end

local function ensureWeld(anchor, part, weldName)
	local weld = part:FindFirstChild(weldName)
	if weld and weld:IsA("Weld") then
		weld.Part0 = anchor
		weld.Part1 = part
		return weld
	end

	local relativeCFrame = anchor.CFrame:ToObjectSpace(part.CFrame)
	if weld then
		weld:Destroy()
	end
	weld = addWeld(anchor, part, weldName)
	weld.C0 = relativeCFrame
	return weld
end

local function destroyCarryVisual(visual)
	if visual.Body then
		visual.Body:Destroy()
	end
	for _, cap in pairs(visual.Caps) do
		cap:Destroy()
	end
end

local function setCarryVisualSlot(visual, anchor, logRecord, stackName, stackIndex)
	local body = visual.Body
	local slotCFrame = CarryLayout.GetAnchorRelativeSlotCFrame(stackName, stackIndex)
	if not body or not slotCFrame then
		return false
	end

	local needsReposition = body:GetAttribute("CarryStack") ~= stackName
		or body:GetAttribute("CarryIndex") ~= stackIndex
	local bodyWeld = ensureWeld(anchor, body, "CarriedLogWeld")
	if needsReposition then
		bodyWeld.C0 = slotCFrame
	end
	body:SetAttribute("LogUID", logRecord.UID)
	body:SetAttribute("CarryStack", stackName)
	body:SetAttribute("CarryIndex", stackIndex)
	body:SetAttribute("IsRare", logRecord.IsRare == true)

	local capOffset = body.Size.X * 0.5 - visual.Caps[1].Size.X * 0.5
	for capIndex, cap in ipairs(visual.Caps) do
		local capDirection = capIndex == 1 and -1 or 1
		local capRelativeCFrame = slotCFrame * CFrame.new(capDirection * capOffset, 0, 0)
		local capWeld = ensureWeld(anchor, cap, "CarriedLogCapWeld")
		if needsReposition then
			capWeld.C0 = capRelativeCFrame
		end
		cap:SetAttribute("LogUID", logRecord.UID)
		cap:SetAttribute("CarryStack", stackName)
		cap:SetAttribute("CarryIndex", stackIndex)
		cap:SetAttribute("IsRare", logRecord.IsRare == true)
	end
	return true
end

local function findOrCreateCargoModel(player, character, torso)
	local model = modelByPlayer[player]
	if not model or model.Parent ~= character then
		model = nil
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Model")
				and child.Name == "CarriedLogs"
				and child:GetAttribute("LogCarryVisuals") == true then
				model = child
				break
			end
		end
	end

	if not model then
		model = Instance.new("Model")
		model.Name = "CarriedLogs"
		model:SetAttribute("LogCarryVisuals", true)
		local anchor = createCargoAnchor(torso, model)
		model.PrimaryPart = anchor
		model.Parent = character
	end

	local anchor = model.PrimaryPart
	if not anchor or not anchor:IsA("BasePart") then
		anchor = model:FindFirstChild("CargoAnchor")
		if not anchor or not anchor:IsA("BasePart") then
			anchor = createCargoAnchor(torso, model)
		end
		model.PrimaryPart = anchor
	end
	modelByPlayer[player] = model
	return model, anchor
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

	local normalLogs = categorizedRecords.Normal
	local rareLogs = categorizedRecords.Rare
	if #normalLogs + #rareLogs == 0 then
		clearCharacterModel(player, character)
		return true
	end

	local model, anchor = findOrCreateCargoModel(player, character, torso)
	local visualsByUid = collectCarryVisuals(model)
	local desiredByUid = {}
	for index, logRecord in ipairs(normalLogs) do
		desiredByUid[logRecord.UID] = { Record = logRecord, Stack = "Normal", Index = index }
	end
	for index, logRecord in ipairs(rareLogs) do
		desiredByUid[logRecord.UID] = { Record = logRecord, Stack = "Rare", Index = index }
	end

	-- Preserve parts for UIDs that remain in the inventory. Only remove visuals
	-- for removed, malformed, or species-changed records.
	for uid, visual in pairs(visualsByUid) do
		local desired = desiredByUid[uid]
		local complete = visual.Body and visual.Caps[1] and visual.Caps[2]
		if not desired or not complete
			or visual.Body:GetAttribute("SpeciesId") ~= desired.Record.SpeciesId then
			destroyCarryVisual(visual)
			visualsByUid[uid] = nil
		end
	end

	for uid, desired in pairs(desiredByUid) do
		local visual = visualsByUid[uid]
		if not visual then
			visual = addLogVisual(model, anchor, desired.Record, desired.Stack, desired.Index)
		else
			setCarryVisualSlot(visual, anchor, desired.Record, desired.Stack, desired.Index)
		end
	end

	model:SetAttribute("NormalLogCount", #normalLogs)
	model:SetAttribute("RareLogCount", #rareLogs)
	model:SetAttribute("TotalLogCount", #normalLogs + #rareLogs)
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
