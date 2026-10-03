local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")

local IMS = require(script.Parent.Module.IMS)
local IMRemotes = game.ReplicatedStorage:WaitForChild("Inventory")
local playerProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local profileBindableEvent = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent
local itemFolder = game.ServerStorage.Items
local itemDataBase = require(itemFolder.ItemDataBase)
local StatsAggregator = require(itemFolder.StatsAggregator)
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


local IMS_REMOTES_TO_CLIENT: IMS.RemoteCallbacks = {
	OnAdd = function(player: Player, newItem: IMS.ITEM_TYPE, stackOnAdd: boolean, ...: any)
		--INVENTORIES[player]:PrintContainers()
		IMRemotes.NewInventoryItemRE:FireClient(player, newItem, stackOnAdd)
	end,
	OnRemove = function(player: Player, slotIndex: number, ...: any)
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
	for i,v in profile.Data.Inventory do

		local info = itemDataBase.Info[v.ItemID]
		if not info then continue end

		local item = itemDataBase.ParseItem(v)::IMS.ITEM_TYPE
		profile.Data.Runtime[item.ItemType][item.ItemUID] = item
		table.insert(inventoryData, item)
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

local function EquipItem(player, item, clearHeldLogBeforeEquip)
	local inv = playerInventories[player]
	local playerProfile = playerProfileCache.GetProfile(player)
	if not inv or not playerProfile then return false end
	if not item then 
		item = inv:GetEquippedItem() 
	end
	if not item or item.ItemType ~= "Weapon" or typeof(item.ItemUID) ~= "string" then return false end
	if playerProfile.Data.Runtime.Weapon[item.ItemUID] ~= item then return false end
	local toolTemplate = SS.AxeParts:FindFirstChild(item.InstanceName)
	if not toolTemplate or not toolTemplate:IsA("Tool") then return false end
	local character = player.Character
	local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not playerHumanoid or playerHumanoid.Health <= 0 then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false end

	local tool = toolTemplate:Clone()
	if not prepareToolAssembly(tool) then
		tool:Destroy()
		return false
	end

	if clearHeldLogBeforeEquip then
		LogService.ClearHeldLog(player)
	end

	player:SetAttribute("EquipUID", item.ItemUID)
	playerProfile.Data.Equipped.Weapon = item.ItemUID
	for _, container in ipairs({backpack, character}) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("EquippedAxe") then child:Destroy() end
		end
	end
	tool:SetAttribute("EquippedAxe", true)
	tool:SetAttribute("AxeItemUID", item.ItemUID)
	tool.Parent = backpack
	playerHumanoid:EquipTool(tool)
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
			if not EquipItem(player, item, true) then return false end
			inv:SetEquippedItem(slotIndex)
			return true
		end
	end
	return false
end

addShopAxeItem.OnInvoke = function(player, itemRecord)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(itemRecord) ~= "table" then
		return false
	end
	local profile = playerProfileCache.GetProfile(player)
	local inv = playerInventories[player]
	if not profile or not profile.Data.Runtime or not inv then return false end
	if typeof(itemRecord.ItemID) ~= "number" or itemRecord.ItemID % 1 ~= 0 then return false end
	if typeof(itemRecord.UID) ~= "string" or #itemRecord.UID < 1 or #itemRecord.UID > 128 then return false end
	if type(itemRecord.Stats) ~= "table" or type(itemRecord.Substat) ~= "table" or typeof(itemRecord.Rarity) ~= "string" then return false end

	local info = itemDataBase.Info[itemRecord.ItemID]
	local template = itemDataBase.Instances[itemRecord.ItemID]
	if not info or info.Type ~= "Weapon" or not template or not template:IsA("Tool") then return false end
	for _, owned in ipairs(profile.Data.Inventory or {}) do
		if type(owned) == "table" and (owned.UID == itemRecord.UID or owned.ItemID == itemRecord.ItemID) then
			return false
		end
	end
	if profile.Data.Runtime.Weapon[itemRecord.UID] then return false end

	local persistedRecord = {
		ItemID = itemRecord.ItemID,
		UID = itemRecord.UID,
		Stats = table.clone(itemRecord.Stats),
		Substat = table.clone(itemRecord.Substat),
		Rarity = itemRecord.Rarity,
	}
	local runtimeItem = itemDataBase.ParseItem(persistedRecord)
	profile.Data.Runtime.Weapon[runtimeItem.ItemUID] = runtimeItem
	if not inv:AddItem(runtimeItem, false) then
		profile.Data.Runtime.Weapon[runtimeItem.ItemUID] = nil
		return false
	end
	table.insert(profile.Data.Inventory, persistedRecord)
	return true
end

profileBindableEvent.Event:Connect(function(player: Player)
	playerInventories[player] = createInventory(player)
	local playerProfile = playerProfileCache.GetProfile(player)
	player.CharacterAdded:Connect(function(char)
		(char::any).Humanoid.Died:Once(function()
			IMS.Reset(playerInventories[player])
		end)
		local itemUID = playerProfile.Data.Equipped.Weapon
		EquipItem(player, playerProfile.Data.Runtime.Weapon[itemUID])
		
	end)
	if player.Character then
		local itemUID = playerProfile.Data.Equipped.Weapon
		EquipItem(player, playerProfile.Data.Runtime.Weapon[itemUID])
	end
	
	
	--playerInventories[player]:AddItem(itemDataBase.ParseItem(itemGen.GenerateItem(101)))
end)


Players.PlayerRemoving:Connect(function(player: Player)
	destroyInventory(player)
	nextRemoteUse[player] = nil
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
