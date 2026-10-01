local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local IMC = require(script.Parent.Modules.IMC)
IMC.USING_IMS = true

local Remotes = RS.Inventory


local remoteCallbacks: IMC.RemoteCallbacks = {
	OnSwitch = function(slotIndex1, slotIndex2)
		Remotes.SwitchRE:FireServer(slotIndex1, slotIndex2)
	end,
	OnStack = function(targetSlotIndex, currSlotIndex)
		Remotes.StackRE:FireServer(targetSlotIndex, currSlotIndex)
	end,
	OnSplit = function(newSlotIndex, splitSlotIndex)
		Remotes.SplitRE:FireServer(newSlotIndex, splitSlotIndex)	
	end,
	OnEquip = function(slotIndex: number?)
		Remotes.EquipRE:FireServer(slotIndex)
	end,
	OnSort = function(sorterName, ...)
		Remotes.SortRE:FireServer(sorterName, ...)
	end,
}

IMC.IMS.DefineRemotesToServer(remoteCallbacks)

RS.Inventory.AddRE.OnClientEvent:Connect(function(newItem, stackOnAdd)
	IMC.AddItem(newItem, stackOnAdd)
end)



