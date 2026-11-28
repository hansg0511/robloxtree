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

-- Server item updates may arrive before BackPackBuilder has populated IMC.
-- Keep them in order until the initial snapshot is available. That snapshot
-- can already contain an early update, so reconcile by UID before adding it.
local pendingAdds = {}
local flushing = false

local function flushPendingAdds()
	if flushing then return end
	flushing = true
	task.spawn(function()
		local warned = false
		while #pendingAdds > 0 do
			local ready, inventory = false, nil
			if IMC.ReadyForServerAdds == true then
				ready, inventory = pcall(IMC.Raw)
			end
			if not ready or type(inventory) ~= "table" then
				task.wait(0.1)
			else
				local entry = pendingAdds[1]
				local uid = type(entry.Item) == "table" and entry.Item.ItemUID
				local alreadyPresent = false
				if type(uid) == "string" then
					for _, item in pairs(inventory) do
						if type(item) == "table" and item.ItemUID == uid then
							alreadyPresent = true
							break
						end
					end
				end
				if alreadyPresent then
					table.remove(pendingAdds, 1)
				else
					local added, err = pcall(IMC.AddItem, entry.Item, entry.StackOnAdd)
					if added then
						table.remove(pendingAdds, 1)
					elseif not warned then
						warn("[Inventory] Waiting to apply an item update:", err)
						warned = true
					end
					if not added then task.wait(0.5) end
				end
			end
		end
		flushing = false
	end)
end

RS.Inventory.NewInventoryItemRE.OnClientEvent:Connect(function(newItem, stackOnAdd)
	-- Once initialized, preserve the normal immediate add/stack behavior.
	if IMC.ReadyForServerAdds == true and not flushing and #pendingAdds == 0 then
		local ready, inventory = pcall(IMC.Raw)
		if ready and type(inventory) == "table" then
			IMC.AddItem(newItem, stackOnAdd)
			return
		end
	end
	table.insert(pendingAdds, { Item = newItem, StackOnAdd = stackOnAdd })
	flushPendingAdds()
end)



