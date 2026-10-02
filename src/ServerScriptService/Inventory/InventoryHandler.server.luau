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
		local remote = IMRemotes:FindFirstChild("IncreaseCapRE")
		if remote then remote:FireClient(player, buildContainerIndex, amount) end
	end,
	OnDecreaseCap = function(player: Player, buildContainerIndex: number, amount: number)
		local remote = IMRemotes:FindFirstChild("DecreaseCapRE")
		if remote then remote:FireClient(player, buildContainerIndex, amount) end
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
	if playerProfile.Data.Runtime.Weapon[item.ItemUID] ~= item then return false end
	local toolTemplate = SS.AxeParts:FindFirstChild(item.InstanceName)
	if not toolTemplate or not toolTemplate:IsA("Tool") then return false end
	local character = player.Character
	local playerHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not playerHumanoid then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false end

	player:SetAttribute("EquipUID", item.ItemUID)
	playerProfile.Data.Equipped.Weapon = item.ItemUID
	for _, container in ipairs({backpack, character}) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("EquippedAxe") then child:Destroy() end
		end
	end
	local tool = toolTemplate:Clone()
	tool:SetAttribute("EquippedAxe", true)
	tool.Parent = backpack
	playerHumanoid:EquipTool(tool)
	StatsAggregator.Aggregate(player)
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
		print(playerProfile, "PROFILE")
		
	end)
	if player.Character then
		local itemUID = playerProfile.Data.Equipped.Weapon
		EquipItem(player, playerProfile.Data.Runtime.Weapon[itemUID])
		print(playerProfile, "PROFILE")
	end
	
	
	--playerInventories[player]:AddItem(itemDataBase.ParseItem(itemGen.GenerateItem(101)))
end)


Players.PlayerRemoving:Connect(function(player: Player)
	destroyInventory(player)
end)


IMRemotes.GetDataRF.OnServerInvoke = function(player)
	local inv = playerInventories[player]
	if not inv then return nil end
	return {data = inv:Items(), capacity = MAX_INVENTORY_CAPACITY}
end

IMRemotes.GetItemDataRF.OnServerInvoke = function(player, slotIndex)
	if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then return nil end
	local inv = playerInventories[player]
	if not inv then return end
	local item = inv:GetItem(slotIndex)
	if not item then return end
	return item
end



IMRemotes.SpawnEquippedItemRE.OnServerEvent:Connect(function(player)
	if EquipItem(player) then
		IMRemotes.SpawnEquippedItemRE:FireClient(player)
	end
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
	if not inv or typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then return end
	local item = inv:GetItem(slotIndex)
	if not item or item.ItemType ~= "Weapon" then return end

	inv:SetEquippedItem(slotIndex)
end)

IMRemotes.SortRE.OnServerEvent:Connect(function(player: Player, sorterName: string, ...: any)
	-- No server sorters are registered yet; ignore untrusted names instead of throwing.
end)
