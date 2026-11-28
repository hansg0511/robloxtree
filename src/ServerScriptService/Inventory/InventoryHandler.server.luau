local Players = game:GetService("Players")

local IMS = require(script.Parent.Module.IMS)
local IMRemotes = game.ReplicatedStorage:WaitForChild("Inventory")
local playerProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local profileBindableEvent = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent
local itemFolder = game.ServerStorage.Items
local itemDataBase = require(itemFolder.ItemDataBase)
local StatsAggregator = require(itemFolder.StatsAggregator)
local WeaponProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)
local Fervor = require(game.ServerScriptService.WeaponEffects.Fervor)
local GoldenRush = require(game.ServerScriptService.WeaponEffects.GoldenRush)
local Bloodrush = require(game.ServerScriptService.WeaponEffects.Bloodrush)
local Rampage = require(game.ServerScriptService.WeaponEffects.Rampage)
local StatsDatabase = require(itemFolder.StatsDatabase)
local EquipAxeRE = game.ReplicatedStorage.Economy:WaitForChild("EquipAxeRE")
local LogService = require(game.ServerScriptService.Inventory.LogService)
local BaseStationAccess = require(game.ServerScriptService.WorldLayout.BaseStationAccess)
local addShopAxeItem = script.Parent:WaitForChild("AddShopAxeItem")
assert(addShopAxeItem:IsA("BindableFunction"), "AddShopAxeItem must be a BindableFunction")

local MAX_INVENTORY_CAPACITY = 30
local REMOTE_INTERVALS = {
	Equip = 0.15,
	SpawnEquippedItem = 0.75,
	EquipAxe = 0.5,
}

-- Use the real tier-two mutation definitions, selecting the midpoint of
-- every ability's probability bucket. Debug-only composition bypasses forge
-- slot selection, but all effects still pass the ordinary dispatcher rules.
local function debugMutationEffects()
	local effects = {}
	if not game:GetService("RunService"):IsStudio() then return effects end
	local rules = require(game.ReplicatedStorage.Shared.ForgeMutationRules)
	local tier = 2
	for _, family in ipairs(rules.FAMILIES) do
		local cumulative = 0
		for _, choice in ipairs(rules.AbilityOdds(family, tier)) do
			local draw = cumulative + choice.Chance * 0.5
			local result = rules.Roll({
				Family = family, Tier = tier, Potency = rules.TIERS[tier].PotencyCap,
			}, tier, {
				NextNumber = function() return draw end,
			})
			if result and result.Id == choice.Id then
				result.Effect.Source = "DebugProAxe"
				table.insert(effects, result.Effect)
			end
			cumulative += choice.Chance
		end
	end
	return effects
end

local DEBUG_PRO_PLAYER_NAME = "ForsakenDemonz"
local DEBUG_PRO_ALLOWED_USER_IDS = {}
local debugAllowlistState = "unresolved"
local debugAllowlistResolved = Instance.new("BindableEvent")

local function resolveDebugProAllowlist()
	if debugAllowlistState == "resolved" then return end
	if debugAllowlistState == "resolving" then
		debugAllowlistResolved.Event:Wait()
		return
	end

	debugAllowlistState = "resolving"
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(DEBUG_PRO_PLAYER_NAME)
	end)
	if ok and typeof(userId) == "number" and userId > 0 and userId % 1 == 0 then
		DEBUG_PRO_ALLOWED_USER_IDS[userId] = true
	end
	debugAllowlistState = "resolved"
	debugAllowlistResolved:Fire()
end

local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local suppressShopAxeInventoryCallbacks = {}
local deferredShopAxeAddedItems = {}

local IMS_REMOTES_TO_CLIENT: IMS.RemoteCallbacks = {
	OnAdd = function(player: Player, newItem: IMS.ITEM_TYPE, stackOnAdd: boolean, ...: any)
		if suppressShopAxeInventoryCallbacks[player] then
			local pendingAdds = deferredShopAxeAddedItems[player]
			if not pendingAdds then
				pendingAdds = {}
				deferredShopAxeAddedItems[player] = pendingAdds
			end
			table.insert(pendingAdds, { Item = newItem, StackOnAdd = stackOnAdd })
			return
		end
		--INVENTORIES[player]:PrintContainers()
		IMRemotes.NewInventoryItemRE:FireClient(player, newItem, stackOnAdd)
	end,
	OnRemove = function(player: Player, slotIndex: number, ...: any)
		if suppressShopAxeInventoryCallbacks[player] then return end
		IMRemotes.RemoveRE:FireClient(player, slotIndex, ...)
	end,
	OnIncreaseCap = function(player: Player, buildContainerIndex: number, amount: number)
		local remote = IMRemotes:FindFirstChild("IncreaseCapRE")
		if remote then remote:FireClient(player, buildContainerIndex, amount) end
	end,
	OnDecreaseCap = function(player: Player, buildContainerIndex: number, amount: number)
		local remote = IMRemotes:FindFirstChild("DecreaseCapRE")
		if remote then remote:FireClient(player, buildContainerIndex, amount) end
	end,
}


local playerInventories = {}
local nextRemoteUse = {}

local function consumeRemoteBudget(player, action)
	local interval = REMOTE_INTERVALS[action]
	local now = os.clock()
	local playerBudget = nextRemoteUse[player]
	if not playerBudget then
		playerBudget = {}
		nextRemoteUse[player] = playerBudget
	end
	if now < (playerBudget[action] or 0) then return false end
	playerBudget[action] = now + interval
	return true
end

-- Scale a fresh unparented Tool clone about its handle; never mutate the
-- template or resize an already-equipped tool. Preserve relative rotations.
local MaterialGeometry = require(game.ReplicatedStorage.Shared.MaterialGeometry)
local function scaleCraftedTool(tool, scale)
	if type(scale) ~= "number" or scale ~= scale or scale <= 0 or scale == math.huge then return end
	scale = math.clamp(scale, MaterialGeometry.WEAPON_MIN_SCALE, MaterialGeometry.WEAPON_MAX_SCALE)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return end
	local origin = handle.CFrame
	local descendants = tool:GetDescendants()
	-- Set joint offsets as well as part transforms, so authored rigid welds
	-- and attachments stay aligned with the scaled geometry.
	for _, part in ipairs(descendants) do
		if part:IsA("BasePart") then
			local relative = origin:ToObjectSpace(part.CFrame)
			part.Size *= scale
			part.CFrame = origin * CFrame.new(relative.Position * scale) * relative.Rotation
		elseif part:IsA("JointInstance") then
			part.C0 = CFrame.new(part.C0.Position * scale) * part.C0.Rotation
			part.C1 = CFrame.new(part.C1.Position * scale) * part.C1.Rotation
		elseif part:IsA("Attachment") then
			part.Position *= scale
		elseif part:IsA("SpecialMesh") then
			part.Offset *= scale
			if part.MeshType == Enum.MeshType.FileMesh then part.Scale *= scale end
		end
	end
	tool.Grip = CFrame.new(tool.Grip.Position * scale) * tool.Grip.Rotation
	tool:SetAttribute("CraftWeaponScale", scale)
end

local function prepareToolAssembly(tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return false end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			if descendant ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "ToolAssemblyWeld"
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	return true
end


local function initInventoryData(player: Player): { any }

	local inventoryData = {}
	local profile = playerProfileCache.GetProfile(player)
	if not profile or not profile.Data.Runtime then return inventoryData end
	for i,v in profile.Data.Inventory do

		local info = itemDataBase.Info[v.ItemID]
		if not info then continue end

		local item = itemDataBase.ParseItem(v)::IMS.ITEM_TYPE
		profile.Data.Runtime[item.ItemType][item.ItemUID] = item
		table.insert(inventoryData, item)
	end

	resolveDebugProAllowlist()
	if DEBUG_PRO_ALLOWED_USER_IDS[player.UserId] then
		local runtime = profile.Data.Runtime
		local function inventoryHasUID(uid)
			for _, item in ipairs(inventoryData) do
				if item and item.ItemUID == uid then return true end
			end
			return false
		end

		local debugUID = runtime.DebugProAxeUID
		local debugWeapon = debugUID and runtime.Weapon[debugUID]
		if not debugWeapon then
			local baseUID = "debug-pro-axe-" .. tostring(player.UserId)
			local candidateUID = baseUID
			local suffix = 1
			local function uidIsTaken(uid)
				if runtime.Weapon[uid] then return true end
				for _, owned in ipairs(profile.Data.Inventory or {}) do
					if type(owned) == "table" and owned.UID == uid then return true end
				end
				return false
			end
			while uidIsTaken(candidateUID) do
				suffix += 1
				candidateUID = baseUID .. "-" .. tostring(suffix)
			end

			local debugRecord = {
				ItemID = 9001,
				UID = candidateUID,
				Stats = { Attack = 9995 },
				Substat = {},
				Rarity = "Debug",
				WeaponData = {
					AxeTier = 999,
					HeadId = "debug_pro_head",
					CraftedPower = 10000,
					DebugOnly = true,
					Effects = debugMutationEffects(),
					Materials = {},
				},
			}
			debugWeapon = itemDataBase.ParseItem(debugRecord)
			if debugWeapon then
				debugUID = candidateUID
				runtime.Weapon[debugUID] = debugWeapon
				runtime.EphemeralWeaponUIDs[debugUID] = true
				runtime.DebugProAxeUID = debugUID
			end
		end

		if debugWeapon and debugUID and not inventoryHasUID(debugUID) then
			runtime.EphemeralWeaponUIDs[debugUID] = true
			table.insert(inventoryData, debugWeapon)
		end
	end

	return inventoryData
end

local function createInventory(player: Player): IMS.Inventory
	local inv

	inv = IMS.Inventory(30, initInventoryData(player))

	local backpack = IMS.Container("bp", 25, IMS.NO_AUTO_EQUIP)

	inv:SetPlayer(player)
	inv:DefineRemotesToClient(IMS_REMOTES_TO_CLIENT)
	inv:Build({ backpack })

	return inv
end


local function destroyInventory(player: Player)
	local inv: IMS.Inventory? = playerInventories[player]
	if inv then inv:Destroy() end
	playerInventories[player] = nil
end

local function EquipItem(player, item)
	local inv = playerInventories[player]
	local playerProfile = playerProfileCache.GetProfile(player)
	if not inv or not playerProfile then return false end
	if not item then 
		item = inv:GetEquippedItem() 
	end
	if not item or item.ItemType ~= "Weapon" or typeof(item.ItemUID) ~= "string" then return false end
	local runtime = playerProfile.Data.Runtime
	local previousWeaponUID = runtime.EquippedWeaponUID
	if runtime.Weapon[item.ItemUID] ~= item then return false end
	local toolTemplate = itemDataBase.Instances[item.ItemID]
	if not toolTemplate or not toolTemplate:IsA("Tool") or toolTemplate.Name ~= item.InstanceName then return false end
	local character = player.Character
	local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not playerHumanoid or playerHumanoid.Health <= 0 then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false end

	local tool = toolTemplate:Clone()
	if type(item.WeaponData) == "table" then
		scaleCraftedTool(tool, item.WeaponData.WeaponScale)
	end
	if not prepareToolAssembly(tool) then
		tool:Destroy()
		return false
	end

	tool:SetAttribute("EquippedAxe", true)
	tool:SetAttribute("AxeItemUID", item.ItemUID)
	-- Only server-forged experimental weapons carry individually rolled rates.
	-- Native Tools are temporary class models; attack rate is enforced by the
	-- server ChopHandler, not trusted from this replicated attribute.
	local weaponData = type(item.WeaponData) == "table" and item.WeaponData or nil
	local attackRate = weaponData and weaponData.AttacksPerSecond
	if type(attackRate) == "number" and attackRate == attackRate
		and attackRate >= 0.1 and attackRate <= 10 then
		tool:SetAttribute("CraftAttackRate", attackRate)
	end
	tool.Parent = backpack
	playerHumanoid:EquipTool(tool)
	for _, container in ipairs({backpack, character}) do
		for _, child in ipairs(container:GetChildren()) do
			if child ~= tool and child:IsA("Tool") and child:GetAttribute("EquippedAxe") then child:Destroy() end
		end
	end
	if tool.Parent ~= character then
		tool:Destroy()
		return false
	end

	player:SetAttribute("EquipUID", item.ItemUID)
	runtime.EquippedWeaponUID = item.ItemUID
	runtime.EquippedWeaponTool = tool
	if runtime.EphemeralWeaponUIDs[item.ItemUID] then
		-- Debug equipment is session-only; leave the profile's saved weapon untouched.
	else
		playerProfile.Data.Equipped.Weapon = item.ItemUID
		require(game.ServerScriptService.LifetimeStatsRules).RecordEquip(playerProfile.Data)
	end
	Fervor.OnWeaponEquipped(player, previousWeaponUID, item.ItemUID)
	GoldenRush.OnWeaponEquipped(player, previousWeaponUID, item.ItemUID)
	Bloodrush.OnWeaponEquipped(player, previousWeaponUID, item.ItemUID)
	Rampage.OnWeaponEquipped(player, previousWeaponUID, item.ItemUID)
	StatsAggregator.Aggregate(player)
	return true
end

local function EquipOwnedAxe(player, uid)
	if typeof(uid) ~= "string" or #uid < 1 or #uid > 128 then return false end
	local inv = playerInventories[player]
	local profile = playerProfileCache.GetProfile(player)
	if not inv or not profile or not profile.Data.Runtime then return false end
	local weapon = profile.Data.Runtime.Weapon[uid]
	if not weapon or weapon.ItemType ~= "Weapon" or weapon.ItemUID ~= uid then return false end

	for slotIndex, item in ipairs(inv:Items()) do
		if item and item.ItemUID == uid and item.ItemType == "Weapon" and item == weapon then
			if not EquipItem(player, item) then return false end
			inv:SetEquippedItem(slotIndex)
			return true
		end
	end
	return false
end

local function rollbackUncommittedShopAxe(player, profile, inv, runtimeItem, persistedRecord)
	suppressShopAxeInventoryCallbacks[player] = true
	for slotIndex, currentItem in ipairs(inv:Items()) do
		if currentItem == runtimeItem then
			local removed = pcall(function()
				inv:RemoveItem(slotIndex)
			end)
			if not removed then
				warn("Could not remove an uncommitted shop axe from the IMS inventory")
			end
			break
		end
	end
	suppressShopAxeInventoryCallbacks[player] = nil
	deferredShopAxeAddedItems[player] = nil
	profile.Data.Runtime.Weapon[runtimeItem.ItemUID] = nil
	-- table.insert is expected to be atomic, but remove the exact record by
	-- identity as well so a late persistence failure cannot leave a free axe.
	local profileInventory = profile.Data.Inventory
	if type(profileInventory) == "table" and persistedRecord then
		for index = #profileInventory, 1, -1 do
			if profileInventory[index] == persistedRecord then
				table.remove(profileInventory, index)
				break
			end
		end
	end
end

addShopAxeItem.OnInvoke = function(player, itemRecord)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(itemRecord) ~= "table" then
		return false
	end
	local profile = playerProfileCache.GetProfile(player)
	local inv = playerInventories[player]
	if not profile or not profile.Data.Runtime or not inv then return false end
	if type(profile.Data.Inventory) ~= "table" then return false end
	if typeof(itemRecord.ItemID) ~= "number" or itemRecord.ItemID % 1 ~= 0 then return false end
	if typeof(itemRecord.UID) ~= "string" or #itemRecord.UID < 1 or #itemRecord.UID > 128 then return false end
	if type(itemRecord.Stats) ~= "table" or type(itemRecord.Substat) ~= "table" or typeof(itemRecord.Rarity) ~= "string" then return false end

	local info = itemDataBase.Info[itemRecord.ItemID]
	local template = itemDataBase.Instances[itemRecord.ItemID]
	if not info or info.Type ~= "Weapon" or not template or not template:IsA("Tool") then return false end
	for _, owned in ipairs(profile.Data.Inventory or {}) do
		if type(owned) == "table" and owned.UID == itemRecord.UID then
			return false
		end
	end
	if profile.Data.Runtime.Weapon[itemRecord.UID] then return false end

	local persistedRecord = {
		ItemID = itemRecord.ItemID,
		UID = itemRecord.UID,
		Stats = deepCopy(itemRecord.Stats),
		Substat = deepCopy(itemRecord.Substat),
		Rarity = itemRecord.Rarity,
	}
	if itemRecord.WeaponData ~= nil then
		if type(itemRecord.WeaponData) ~= "table" then return false end
		persistedRecord.WeaponData = deepCopy(itemRecord.WeaponData)
	end
	-- The forged item's existing Rarity is authoritative; progression defaults
	-- are derived once on the server before creating runtime/IMS copies.
	if itemRecord.ItemID == 9001 or itemRecord.Rarity == "Debug"
		or not WeaponProgressionRules.NormalizeWeaponItem(persistedRecord) then
		return false
	end
	local runtimeItem = itemDataBase.ParseItem(persistedRecord)
	if not runtimeItem then return false end
	profile.Data.Runtime.Weapon[runtimeItem.ItemUID] = runtimeItem
	deferredShopAxeAddedItems[player] = nil
	suppressShopAxeInventoryCallbacks[player] = true
	local addOk, added = pcall(function()
		return inv:AddItem(runtimeItem, false)
	end)
	suppressShopAxeInventoryCallbacks[player] = nil
	if not addOk or added ~= true then
		-- A normal rejection is mutation-free. If an unexpected callback error
		-- happened after insertion, remove that exact runtime item silently.
		rollbackUncommittedShopAxe(player, profile, inv, runtimeItem, persistedRecord)
		return false
	end
	local profileInsertOk = pcall(function()
		table.insert(profile.Data.Inventory, persistedRecord)
	end)
	if not profileInsertOk then
		rollbackUncommittedShopAxe(player, profile, inv, runtimeItem, persistedRecord)
		return false
	end
	-- The first successfully crafted weapon should immediately replace
	-- bare hands. Do not auto-swap an established player's equipped weapon.
	local firstEquipment = profile.Data.Runtime.EquippedWeaponUID == nil
		and type(profile.Data.Equipped) == "table"
		and profile.Data.Equipped.Weapon == nil
	local pendingAdds = deferredShopAxeAddedItems[player]
	deferredShopAxeAddedItems[player] = nil
	if pendingAdds then
		for _, pendingAdd in ipairs(pendingAdds) do
			pcall(function()
				IMRemotes.NewInventoryItemRE:FireClient(player, pendingAdd.Item, pendingAdd.StackOnAdd)
			end)
		end
	end
	if firstEquipment then
		-- Inventory and recipe payment are already committed. An equip/character
		-- race must never roll the craft back or duplicate its materials.
		local equipOk, didEquip = pcall(EquipOwnedAxe, player, runtimeItem.ItemUID)
		if equipOk and didEquip then
			pcall(function() IMRemotes.SpawnEquippedItemRE:FireClient(player) end)
		else
			-- The player still owns the weapon and may equip it normally.
			warn("[Inventory] First forged weapon saved; automatic equip unavailable")
		end
	end
	return true
end

profileBindableEvent.Event:Connect(function(player: Player)
	playerInventories[player] = createInventory(player)
	local playerProfile = playerProfileCache.GetProfile(player)
	local function equipActiveWeapon()
		local runtime = playerProfile.Data.Runtime
		local itemUID = runtime.EquippedWeaponUID
		if typeof(itemUID) ~= "string" or not runtime.Weapon[itemUID] then
			itemUID = playerProfile.Data.Equipped.Weapon
		end
		local item = itemUID and runtime.Weapon[itemUID]
		if not item then
			-- Fresh profiles have no equipped weapon. Do not accidentally use
			-- an IMS selection (including a developer-only tool) as a fallback.
			StatsAggregator.Aggregate(player)
			return
		end
		if not EquipItem(player, item) then return end
		local inv = playerInventories[player]
		if not inv then return end
		for slotIndex, inventoryItem in ipairs(inv:Items()) do
			if inventoryItem == item then
				inv:SetEquippedItem(slotIndex)
				break
			end
		end
	end
	player.CharacterAdded:Connect(function(char)
		(char::any).Humanoid.Died:Once(function()
			IMS.Reset(playerInventories[player])
		end)
		equipActiveWeapon()
		
	end)
	if player.Character then
		equipActiveWeapon()
	end
	
	
	--playerInventories[player]:AddItem(itemDataBase.ParseItem(itemGen.GenerateItem(101)))
end)


Players.PlayerRemoving:Connect(function(player: Player)
	destroyInventory(player)
	nextRemoteUse[player] = nil
	suppressShopAxeInventoryCallbacks[player] = nil
	deferredShopAxeAddedItems[player] = nil
end)


IMRemotes.GetDataRF.OnServerInvoke = function(player)
	local inv = playerInventories[player]
	if not inv then return nil end
	return {data = inv:Items(), capacity = MAX_INVENTORY_CAPACITY}
end

IMRemotes.SpawnEquippedItemRE.OnServerEvent:Connect(function(player)
	if not consumeRemoteBudget(player, "SpawnEquippedItem") then return end
	if EquipItem(player) then
		IMRemotes.SpawnEquippedItemRE:FireClient(player)
	end
end)

IMRemotes.EquipRE.OnServerEvent:Connect(function(player, slotIndex)
	if not consumeRemoteBudget(player, "Equip") then return end
	local inv = playerInventories[player]
	if not inv or typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then return end
	local item = inv:GetItem(slotIndex)
	if not item or item.ItemType ~= "Weapon" then return end
	if not BaseStationAccess.CanUseAxeShop(player) then return end

	inv:SetEquippedItem(slotIndex)
end)

EquipAxeRE.OnServerEvent:Connect(function(player, uid, ...)
	if select("#", ...) ~= 0 then return end
	if not consumeRemoteBudget(player, "EquipAxe") then return end
	if EquipOwnedAxe(player, uid) then
		IMRemotes.SpawnEquippedItemRE:FireClient(player)
		LogService.NotifyState(player)
	end
end)
