local RS = game.ReplicatedStorage
local GetInvDataRF = RS.Inventory.GetDataRF
local profileLoadEvent = RS.Profile.ProfileLoadEvent

local IMC = require(script.Parent.Modules.IMC)
local UIS = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

local playerGui = player.PlayerGui
local screenGui = playerGui:WaitForChild("InventoryScreenGui")
local templates = playerGui:WaitForChild("TEMPLATES"):WaitForChild("Templates")

local bpFrame = screenGui:WaitForChild("InventoryFrame")
local emptySlotTemplate = templates.EmptySlot
local filledSlotTemplate = templates.FilledSlot

local itemDetailsFrame = bpFrame.ItemDetailsFrame
local ItemDetailsManager = require(itemDetailsFrame.ItemDetailsManager)
local EquipBtnColorChange = require(itemDetailsFrame.MainItemDetails.ItemStats.EquipBtn.EquipBtnColorChange)

IMC.Initialize(screenGui)


-- Inventory rearranging/sorting is not implemented server-side yet, so keep
-- this UI read-only apart from selecting an equipped item.
local backpack = IMC.Container("bp", 25, IMC.NO_AUTO_EQUIP + IMC.NO_DRAGGING + IMC.NO_SORTING)

-----------------------------------------------------------------

backpack:DefineLayout({
	ParentContainer = bpFrame.BackpackWrapper,
	--HorizontalAlignment = Enum.HorizontalAlignment.Center,
	--CellPadding = UDim2.new(0.02, 0, 0.05, 0),
	CellPadding= UDim2.new(0.04, 0, 0.04, 0),
	--CellPadding = UDim2.new(0, 20, 0, 20),
	--FillDirectionMaxCells = 8,
	--CellSize = UDim2.fromScale(.15,.25)
	CellSize= UDim2.fromScale(0.14, 0.12)
	--CellSize = UIS.TouchEnabled and UDim2.fromOffset(45, 45)
})

backpack:DefineEmptySlot({
	GuiTemplate = emptySlotTemplate,
})


backpack:DefineFilledSlot({
	GuiTemplate = filledSlotTemplate,
	RenderFunc = function(slotIndex, item, filledGui, containerIndex)
		filledGui.Size = UDim2.new(1, 0, 1, 0)
		filledGui.AnchorPoint = Vector2.new(.5, .5)
		filledGui.Position = UDim2.new(.5,0,.5,0)


		if item.ItemIcon then
			filledGui.ItemPreview.Image = item.ItemIcon
			--filledGui.ItemPreview.AnchorPoint = Vector2.new(.5, .5)
			--filledGui.ItemPreview.Position = UDim2.new(.5,0,.5,0)
			--filledGui.ItemPreview.Size = UDim2.fromScale(0.8,0.8)
			filledGui.TextLabel.Text = ""
			filledGui.ItemPreview.ZIndex = 10
			
		else
			filledGui.TextLabel.Text = item.ItemName
			filledGui.ItemPreview.Visible = false
		end
	end,
})

------- Filters -------------------------------------------------

IMC.DefineCustomFilters({
	axeView = function(slotIndex: number, item: IMC.ITEM_TYPE, containerIndex: number)
		return item.ItemType == "Weapon"
	end,
	seedView = function(slotIndex: number, item: IMC.ITEM_TYPE, containerIndex: number)
		return item.ItemType == "Seed"
	end,
})

local function showEquippedItem(filter) 
	-- Equipped item displayed by default
	local inventory = IMC.Raw()
	local EquippedUID = player:GetAttribute("EquipUID")
	local filterItemType = if filter == "axeView" then "Weapon" elseif filter == "seedView" then "Seed" else nil

	for i, item in inventory do
		if item and EquippedUID and item.ItemType == filterItemType and item.ItemUID == EquippedUID then
			IMC.SetEquippedItem(i)
			return
		end
	end
	for i, item in inventory do
		if item and item.ItemType == filterItemType then
			IMC.SetEquippedItem(i)
		end
	end
end

local categoryFrame = bpFrame.BackpackCategory
local axeViewBtn = categoryFrame.AxeBackpackButton
local seedViewBtn = categoryFrame.SeedBackpackButton
local axeViewBtnCon: RBXScriptConnection = nil
local seedViewBtnCon: RBXScriptConnection = nil
local lastFilter = nil 

local function filterToggleCallback(toggled: boolean)
	if toggled then 
		if lastFilter == "axeView" then
			IMC.Filter("axeView")
			showEquippedItem("axeView")
		elseif lastFilter == "seedView" then
			IMC.Filter("seedView")
			showEquippedItem("seedView")
		else
			IMC.Filter("axeView")
			showEquippedItem("axeView")
		end
	end

	if toggled then
		axeViewBtnCon = axeViewBtn.Activated:Connect(function()
			IMC.Filter("axeView")
			showEquippedItem("axeView")
			lastFilter = "axeView"
		end)
		seedViewBtnCon = seedViewBtn.Activated:Connect(function()
			IMC.Filter("seedView")
			showEquippedItem("seedView")
			lastFilter = "seedView"
		end)
	else
		(axeViewBtnCon::RBXScriptConnection):Disconnect();
		(seedViewBtnCon::RBXScriptConnection):Disconnect();
	end
end

----------------------------------------------------------------------

local function displayItemDetails(slotIndex)

	-- Retrieve data
	local itemInfo = IMC.GetItem(slotIndex)
	--print(itemInfo.ItemStats, "ItemStats")

	-- Change stats
	ItemDetailsManager.Init(itemInfo)
	
	-- Change equip button if item is equipped
	if player:GetAttribute("EquipUID") == itemInfo.ItemUID then
		EquipBtnColorChange.Unequip()
	else 
		EquipBtnColorChange.Equip()
	end

end

IMC.DefineRenderEquippedSlots({ backpack }, function(item: IMC.ITEM_TYPE, filledGui: GuiObject, emptyGui: GuiObject, info: IMC.ItemPositionInfo)
	-- Properties changed when slot is selected
	filledGui.Border.Enabled = true
	filledGui.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
	
	-- Display item details
	displayItemDetails(info.SlotIndex)

	return function(lastItem: IMC.ITEM_TYPE, lastFilledGui: GuiObject?, lastEmptyGui: GuiObject, lastInfo: IMC.ItemPositionInfo)
		-- Properties changed back when slot is deselected
		lastFilledGui.Border.Enabled = false
		filledGui.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		--warn("unrendered")
	end, nil
end)

-------- Equip Button Event Handlers
local spawnEquippedItemRE = RS.Inventory.SpawnEquippedItemRE
itemDetailsFrame.MainItemDetails.ItemStats.EquipBtn.Activated:Connect(function()
	spawnEquippedItemRE:FireServer()
end)

-- Equip Success Server Response
spawnEquippedItemRE.OnClientEvent:Connect(function()
	EquipBtnColorChange.Unequip()
end)
---------

--- Populate and build backpack on profile data load
local inventoryBuilt = false
local function buildInventory()
	if inventoryBuilt then return end
	IMC.Populate(function()
		local info = GetInvDataRF:InvokeServer()
		if not info then return {}, 30 end
		return info.data, info.capacity
	end)	
	IMC.Build({ backpack })
	inventoryBuilt = true
end

profileLoadEvent.OnClientEvent:Connect(buildInventory)
if player:GetAttribute("ProfileReady") then
	buildInventory()
end


IMC.DefineOnToggledCallback(function(toggled: boolean)
	bpFrame.Visible = toggled
	
	-- Apply appropriate filter, last viewed inventory is saved and loaded
	filterToggleCallback(toggled)
end)


---------------------------------------------
-----------[IMC configs and build]-----------
---------------------------------------------

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end

	if input.KeyCode == Enum.KeyCode.B then
		IMC.ToggleInventory()
	end
end)
