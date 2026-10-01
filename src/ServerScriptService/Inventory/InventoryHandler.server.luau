local Players = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local IMS = require(script.Parent.Module.IMS)
local IMRemotes = game.ReplicatedStorage:WaitForChild("Inventory")
local playerProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local profileBindableEvent = game.ServerScriptService.PlayerProfile.ProfileInit.ProfileLoadedEvent
local itemFolder = game.ServerStorage.Items
local itemDataBase = require(itemFolder.ItemDataBase)
local StatsAggregator = require(itemFolder.StatsAggregator)
local StatsDatabase = require(itemFolder.StatsDatabase)

local itemGen = require(itemFolder.ItemGeneratorModule)

local MAX_INVENTORY_CAPACITY = 30


local IMS_REMOTES_TO_CLIENT: IMS.RemoteCallbacks = {
	OnAdd = function(player: Player, newItem: IMS.ITEM_TYPE, stackOnAdd: boolean, ...: any)
		--INVENTORIES[player]:PrintContainers()
		IMRemotes.NewInventoryItemRE:FireClient(player, newItem, stackOnAdd)
	end,
	OnRemove = function(player: Player, slotIndex: number, ...: any)
		IMRemotes.RemoveRE:FireClient(player, slotIndex, ...)
	end,
	OnIncreaseCap = function(player: Player, buildContainerIndex: number, amount: number)
		--INVENTORIES[player]:PrintContainers()
		IMRemotes.IncreaseCapRE:FireClient(player, buildContainerIndex, amount)
	end,
	OnDecreaseCap = function(player: Player, buildContainerIndex: number, amount: number)
		--INVENTORIES[player]:PrintContainers()
		IMRemotes.DecreaseCapRE:FireClient(player, buildContainerIndex, amount)
	end,
}


local playerInventories = {}


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
end

local function EquipItem(player, item)
	local inv = playerInventories[player]
	local playerProfile = playerProfileCache.GetProfile(player)
	if not inv then return end
	if not item then 
		item = inv:GetEquippedItem() 
	end
	
	player:SetAttribute("EquipUID", item.ItemUID)
	playerProfile.Data.Equipped.Weapon = nil
	playerProfile.Data.Equipped.Weapon = item.ItemUID
	local playerHumanoid = player.Character.Humanoid
	player.Backpack:ClearAllChildren()
	local tool = SS.AxeParts:FindFirstChild(item.InstanceName):Clone()
	tool.Parent = player.Backpack
	playerHumanoid:EquipTool(tool)
	StatsAggregator.Aggregate(player)
end

profileBindableEvent.Event:Connect(function(player: Player)
	playerInventories[player] = createInventory(player)
	local playerProfile = playerProfileCache.GetProfile(player)
	local itemUID = playerProfile.Data.Equipped.Weapon
	
	player.CharacterAdded:Connect(function(char)
		(char::any).Humanoid.Died:Once(function()
			IMS.Reset(playerInventories[player])
		end)
		EquipItem(player, playerProfile.Data.Runtime.Weapon[itemUID])
		print(playerProfile, "PROFILE")
		
	end)
	if player.Character then
		EquipItem(player, playerProfile.Data.Runtime.Weapon[itemUID])
		print(playerProfile, "PROFILE")
	end
	
	
	--playerInventories[player]:AddItem(itemDataBase.ParseItem(itemGen.GenerateItem(101)))
end)


Players.PlayerRemoving:Connect(function(player: Player)
	destroyInventory(player)
end)


IMRemotes.GetDataRF.OnServerInvoke = function(player)
	local z
	return {data = playerInventories[player]:Items(), capacity = MAX_INVENTORY_CAPACITY}
end

IMRemotes.GetItemDataRF.OnServerInvoke = function(player, slotIndex)
	local inv = playerInventories[player]
	if not inv then return end
	local item = inv:GetItem(slotIndex)
	if not item then return end
	return item
end



IMRemotes.SpawnEquippedItemRE.OnServerEvent:Connect(function(player)
	EquipItem(player)
	IMRemotes.SpawnEquippedItemRE:FireClient(player)
end)



--IMRemotes.SwitchRE.OnServerEvent:Connect(function(player, slotIndex1, slotIndex2)
--    local inv = playerInventories[player]
--    if not inv then return end

--	inv:Switch(slotIndex1, slotIndex2)
--end)

--IMRemotes.StackRE.OnServerEvent:Connect(function(player, targetSlotIndex, currSlotIndex)
--    local inv = playerInventories[player]
--    if not inv then return end

--    inv:Stack(targetSlotIndex, currSlotIndex)
--end)

--IMRemotes.SplitRE.OnServerEvent:Connect(function(player, newSlotIndex, splitSlotIndex)
--    local inv = playerInventories[player]
--    if not inv then return end

--    inv:Split(newSlotIndex, splitSlotIndex)
--end)

IMRemotes.EquipRE.OnServerEvent:Connect(function(player, slotIndex)
	local inv = playerInventories[player]
	if not inv then 
		print(inv)
		print("NOT")return end

	inv:SetEquippedItem(slotIndex)
end)

IMRemotes.SortRE.OnServerEvent:Connect(function(player: Player, sorterName: string, ...: any)
	local inv = playerInventories[player]
	if not inv then return end

	inv:Sort(sorterName, ...)
end)