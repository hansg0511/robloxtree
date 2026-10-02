local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local IMC = require(script.Parent.Modules.IMC)
IMC.USING_IMS = true

local Remotes = RS.Inventory


local remoteCallbacks: IMC.RemoteCallbacks = {
	OnEquip = function(slotIndex: number?)
		Remotes.EquipRE:FireServer(slotIndex)
	end,
}

IMC.IMS.DefineRemotesToServer(remoteCallbacks)

RS.Inventory.NewInventoryItemRE.OnClientEvent:Connect(function(newItem, stackOnAdd)
	IMC.AddItem(newItem, stackOnAdd)
end)



