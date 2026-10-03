-- Client presentation for the Log Bag, Axe Shop, and Lumber Depot.
-- Every button sends intent only; the server owns inventory, prices, and sales.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local economy = ReplicatedStorage:WaitForChild("Economy")

local getLogsData = economy:WaitForChild("GetLogsDataRF")
local sellUnlockedLogs = economy:WaitForChild("SellUnlockedLogsRE")
local getSellSummary = economy:WaitForChild("GetSellSummaryRF")
local setLogLocked = economy:WaitForChild("SetLogLockedRE")
local setHeldLog = economy:WaitForChild("SetHeldLogRE")
local economyStateUpdated = economy:WaitForChild("EconomyStateUpdated")
local getShopData = economy:WaitForChild("GetShopDataRF")
local purchaseAxe = economy:WaitForChild("PurchaseAxeRE")
local purchaseCapacity = economy:WaitForChild("PurchaseCapacityRE")
local equipAxe = economy:WaitForChild("EquipAxeRE")

local COLORS = {
	Backdrop = Color3.fromRGB(7, 17, 23),
	Panel = Color3.fromRGB(47, 190, 103),
	Surface = Color3.fromRGB(18, 37, 43),
	SurfaceAlt = Color3.fromRGB(28, 54, 60),
	Ink = Color3.fromRGB(250, 249, 226),
	DarkInk = Color3.fromRGB(13, 32, 31),
	Muted = Color3.fromRGB(173, 204, 190),
	Green = Color3.fromRGB(129, 240, 82),
	GreenDark = Color3.fromRGB(90, 226, 98),
	Gold = Color3.fromRGB(255, 214, 57),
	Orange = Color3.fromRGB(255, 143, 48),
	Blue = Color3.fromRGB(67, 199, 245),
	Pink = Color3.fromRGB(255, 107, 158),
	Stroke = Color3.fromRGB(75, 133, 109),
	Disabled = Color3.fromRGB(105, 130, 121),
	BagBack = Color3.fromRGB(24, 27, 31),
	BagHeader = Color3.fromRGB(220, 128, 38),
	BagSlot = Color3.fromRGB(43, 47, 53),
	BagSelected = Color3.fromRGB(62, 51, 32),
	BagLine = Color3.fromRGB(104, 112, 122),
	BagText = Color3.fromRGB(245, 246, 248),
	BagMuted = Color3.fromRGB(186, 194, 202),
}

local function round(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 12)
	corner.Parent = parent
	return corner
end

local function outline(parent, color, thickness)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color or COLORS.Stroke
	uiStroke.Thickness = thickness or 1.5
	uiStroke.Parent = parent
	return uiStroke
end

local function label(parent, name, text, size, position, fontSize, color, font)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Font = font or Enum.Font.GothamMedium
	item.Text = text
	item.TextColor3 = color or COLORS.Ink
	item.TextSize = fontSize or 16
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function button(parent, name, text, size, position, color)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color or COLORS.Green
	item.AutoButtonColor = true
	item.Font = Enum.Font.GothamBold
	item.Text = text
	item.TextColor3 = COLORS.DarkInk
	item.TextSize = 14
	item.TextWrapped = true
	item.Parent = parent
	round(item, 10)
	outline(item, Color3.fromRGB(255, 255, 255), 1)
	return item
end

local function formatCoins(value)
	if typeof(value) ~= "number" or value ~= value then return "0" end
	if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
	if value >= 1000 then return string.format("%.1fK", value / 1000) end
	return string.format("%.0f", value)
end

local function makeModal(screen, name, titleText, subtitleText)
	local overlay = Instance.new("Frame")
	overlay.Name = name .. "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = COLORS.Backdrop
	overlay.BackgroundTransparency = 0.38
	overlay.Visible = false
	overlay.Parent = screen

	local panel = Instance.new("Frame")
	panel.Name = name .. "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.94, 0, 0.88, 0)
	panel.BackgroundColor3 = COLORS.Panel
	panel.Parent = overlay
	round(panel, 22)
	outline(panel, COLORS.Gold, 3)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(280, 280)
	constraint.MaxSize = Vector2.new(1040, 740)
	constraint.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(20, 10)
	header.Size = UDim2.new(1, -40, 0, 62)
	header.Parent = panel
	label(header, "Title", titleText, UDim2.new(1, -54, 0, 32), UDim2.new(0, 0, 0, 0), 26, COLORS.DarkInk, Enum.Font.GothamBlack)
	label(header, "Subtitle", subtitleText, UDim2.new(1, -54, 0, 24), UDim2.new(0, 0, 0, 34), 12, COLORS.DarkInk, Enum.Font.GothamBold)
	local close = button(header, "CloseButton", "×", UDim2.fromOffset(40, 40), UDim2.new(1, -40, 0, 5), COLORS.Gold)
	close.TextSize = 25
	close.TextColor3 = COLORS.Ink
	close.Activated:Connect(function() overlay.Visible = false end)

	return overlay, panel
end

local screen = Instance.new("ScreenGui")
screen.Name = "EconomyScreenGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.DisplayOrder = 20
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- The compact HUD stays visible while players move around the world.
local hud = Instance.new("Frame")
hud.Name = "EconomyHud"
hud.Position = UDim2.new(0, 12, 0, 10)
hud.Size = UDim2.new(0.94, 0, 0, 54)
hud.BackgroundTransparency = 1
hud.Parent = screen
local hudConstraint = Instance.new("UISizeConstraint")
hudConstraint.MinSize = Vector2.new(280, 54)
hudConstraint.MaxSize = Vector2.new(520, 54)
hudConstraint.Parent = hud
local hudLayout = Instance.new("UIListLayout")
hudLayout.FillDirection = Enum.FillDirection.Horizontal
hudLayout.Padding = UDim.new(0, 6)
hudLayout.SortOrder = Enum.SortOrder.LayoutOrder
hudLayout.Parent = hud

local coinsPill = Instance.new("Frame")
coinsPill.Name = "CoinsPill"
coinsPill.LayoutOrder = 1
coinsPill.Size = UDim2.new(0.31, -4, 1, 0)
coinsPill.BackgroundColor3 = COLORS.Gold
coinsPill.Parent = hud
round(coinsPill, 16)
outline(coinsPill, Color3.fromRGB(255, 244, 190), 2)
local hudCoins = label(coinsPill, "Coins", "🪙  0", UDim2.new(1, -18, 1, 0), UDim2.new(0, 10, 0, 0), 17, COLORS.DarkInk, Enum.Font.GothamBlack)

local logsPill = Instance.new("Frame")
logsPill.Name = "LogsPill"
logsPill.LayoutOrder = 2
logsPill.Size = UDim2.new(0.28, -4, 1, 0)
logsPill.BackgroundColor3 = COLORS.Surface
logsPill.Parent = hud
round(logsPill, 16)
outline(logsPill, COLORS.Blue, 2)
local hudLogs = label(logsPill, "LogCount", "🪵  BAG  0 / 10", UDim2.new(1, -14, 1, 0), UDim2.new(0, 8, 0, 0), 13, COLORS.Ink, Enum.Font.GothamBlack)

local bagButton = button(hud, "OpenBagButton", "OPEN BAG  •  M", UDim2.new(0.39, -4, 1, 0), UDim2.new(), COLORS.Green)
bagButton.LayoutOrder = 3
bagButton.TextSize = 14
round(bagButton, 16)

local feedback = label(screen, "EconomyFeedback", "", UDim2.new(0.86, 0, 0, 40), UDim2.new(0.5, 0, 0, 74), 16, COLORS.Gold, Enum.Font.GothamBlack)
feedback.AnchorPoint = Vector2.new(0.5, 0)
feedback.BackgroundColor3 = COLORS.Surface
feedback.BackgroundTransparency = 0.14
feedback.TextXAlignment = Enum.TextXAlignment.Center
feedback.Visible = false
round(feedback, 14)
outline(feedback, COLORS.Gold, 2)

local bagOverlay, bagPanel = makeModal(screen, "LogBag", "LOG BAG", "Tap a log to equip it. Locked logs stay safe from SELL ALL.")
bagPanel.BackgroundColor3 = COLORS.BagBack
bagPanel.BackgroundTransparency = 0
for _, decoration in ipairs(bagPanel:GetChildren()) do
	if decoration:IsA("UICorner") then
		decoration.CornerRadius = UDim.new(0, 5)
	elseif decoration:IsA("UIStroke") then
		decoration.Color = COLORS.BagLine
		decoration.Thickness = 1
	end
end
bagPanel.Header.BackgroundColor3 = COLORS.BagHeader
bagPanel.Header.BackgroundTransparency = 0
bagPanel.Header.Position = UDim2.new(0, 0, 0, 0)
bagPanel.Header.Size = UDim2.new(1, 0, 0, 44)
bagPanel.Header.Title.Text = "BAG"
bagPanel.Header.Title.Position = UDim2.new(0, 12, 0, 0)
bagPanel.Header.Title.Size = UDim2.new(0, 66, 1, 0)
bagPanel.Header.Title.TextSize = 20
bagPanel.Header.Title.TextColor3 = COLORS.BagBack
bagPanel.Header.Subtitle.Text = "INVENTORY"
bagPanel.Header.Subtitle.Position = UDim2.new(0, 80, 0, 0)
bagPanel.Header.Subtitle.Size = UDim2.new(1, -132, 1, 0)
bagPanel.Header.Subtitle.TextSize = 11
bagPanel.Header.Subtitle.TextColor3 = COLORS.BagBack
bagPanel.Header.CloseButton.Position = UDim2.new(1, -38, 0, 4)
bagPanel.Header.CloseButton.Size = UDim2.fromOffset(34, 34)
bagPanel.Header.CloseButton.BackgroundColor3 = COLORS.BagBack
bagPanel.Header.CloseButton.TextColor3 = COLORS.BagText
bagPanel.Header.CloseButton.TextSize = 22
local bagToolbar = Instance.new("Frame")
bagToolbar.Name = "Toolbar"
bagToolbar.BackgroundTransparency = 1
bagToolbar.Position = UDim2.new(0, 12, 0, 52)
bagToolbar.Size = UDim2.new(1, -24, 0, 30)
bagToolbar.Parent = bagPanel
local sortModes = { "Weight", "Value", "Species", "Newest" }
local sortIndex = 1
local logsTab = button(bagToolbar, "LogsTab", "LOGS", UDim2.new(0, 56, 1, 0), UDim2.new(), COLORS.BagHeader)
logsTab.TextColor3 = COLORS.BagBack
logsTab.TextSize = 11
local axesTab = button(bagToolbar, "AxesTab", "AXES", UDim2.new(0, 56, 1, 0), UDim2.new(0, 60, 0, 0), COLORS.BagSlot)
axesTab.TextColor3 = COLORS.BagText
axesTab.TextSize = 11
local sortButton = button(bagToolbar, "SortButton", "SORT", UDim2.new(0, 54, 1, 0), UDim2.new(0, 120, 0, 0), COLORS.BagSlot)
sortButton.TextSize = 10
sortButton.TextColor3 = COLORS.BagText
local bagCountLabel = label(bagToolbar, "Capacity", "0/10", UDim2.new(1, -180, 1, 0), UDim2.new(0, 180, 0, 0), 11, COLORS.BagMuted, Enum.Font.GothamBold)
bagCountLabel.TextXAlignment = Enum.TextXAlignment.Right

local bagBody = Instance.new("Frame")
bagBody.Name = "BagBody"
bagBody.BackgroundTransparency = 1
bagBody.Position = UDim2.new(0, 12, 0, 90)
bagBody.Size = UDim2.new(1, -24, 1, -102)
bagBody.Parent = bagPanel

local logGrid = Instance.new("ScrollingFrame")
logGrid.Name = "ItemGrid"
logGrid.BackgroundColor3 = COLORS.BagBack
logGrid.BorderSizePixel = 0
logGrid.ScrollBarThickness = 6
logGrid.ScrollBarImageColor3 = COLORS.BagLine
logGrid.CanvasSize = UDim2.new()
logGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
logGrid.Parent = bagBody
round(logGrid, 4)
outline(logGrid, COLORS.BagLine, 1)

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 6)
gridPadding.PaddingBottom = UDim.new(0, 6)
gridPadding.PaddingLeft = UDim.new(0, 6)
gridPadding.PaddingRight = UDim.new(0, 6)
gridPadding.Parent = logGrid

local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.CellPadding = UDim2.fromOffset(5, 5)
gridLayout.CellSize = UDim2.fromOffset(72, 72)
gridLayout.FillDirectionMaxCells = 3
gridLayout.Parent = logGrid

local emptyState = label(bagBody, "EmptyState", "", UDim2.new(1, 0, 1, -50), UDim2.new(), 12, COLORS.BagMuted, Enum.Font.GothamBold)
emptyState.TextXAlignment = Enum.TextXAlignment.Center
emptyState.TextYAlignment = Enum.TextYAlignment.Center
emptyState.ZIndex = 3
emptyState.Visible = false

local detailPanel = Instance.new("Frame")
detailPanel.Name = "ItemFooter"
detailPanel.BackgroundColor3 = COLORS.BagSlot
detailPanel.Parent = bagBody
round(detailPanel, 4)
outline(detailPanel, COLORS.BagLine, 1)

local detailIcon = label(detailPanel, "ItemIcon", "🪵", UDim2.new(0, 32, 1, 0), UDim2.new(0, 6, 0, 0), 20, COLORS.BagText, Enum.Font.GothamBold)
detailIcon.TextXAlignment = Enum.TextXAlignment.Center
local detailSpecies = label(detailPanel, "Species", "NO LOG SELECTED", UDim2.new(0.42, -42, 0, 20), UDim2.new(0, 42, 0, 3), 12, COLORS.BagText, Enum.Font.GothamBold)
detailSpecies.TextTruncate = Enum.TextTruncate.AtEnd
local detailStatus = label(detailPanel, "Status", "CHOOSE A SLOT", UDim2.new(0.42, -42, 0, 16), UDim2.new(0, 42, 0, 22), 9, COLORS.BagMuted, Enum.Font.GothamBold)
local detailWeight = label(detailPanel, "Weight", "", UDim2.new(0.22, -8, 1, 0), UDim2.new(0.46, 0, 0, 0), 10, COLORS.BagMuted, Enum.Font.GothamBold)
detailWeight.TextXAlignment = Enum.TextXAlignment.Center
local detailValue = label(detailPanel, "Value", "", UDim2.new(), UDim2.new(), 1, COLORS.BagMuted)
detailValue.Visible = false
local detailSize = label(detailPanel, "Size", "", UDim2.new(), UDim2.new(), 1, COLORS.BagMuted)
detailSize.Visible = false
local favoriteButton = button(detailPanel, "FavoriteButton", "LOCK", UDim2.new(0, 82, 0, 32), UDim2.new(1, -88, 0.5, -16), COLORS.BagHeader)
favoriteButton.TextSize = 10
favoriteButton.TextColor3 = COLORS.BagBack
favoriteButton.Visible = false

local shopOverlay, shopPanel = makeModal(screen, "AxeShop", "AXE SHOP", "Pick up more power and chop tougher trees.")
local shopNotice = label(shopPanel, "ShopNotice", "CHOPPING TOOLS", UDim2.new(1, -36, 0, 26), UDim2.new(0, 18, 0, 76), 13, COLORS.DarkInk, Enum.Font.GothamBlack)
local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Position = UDim2.new(0, 18, 0, 108)
shopList.Size = UDim2.new(1, -36, 1, -126)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.ScrollBarImageColor3 = COLORS.GreenDark
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.CanvasSize = UDim2.new()
shopList.Parent = shopPanel
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

local sellOverlay, sellPanel = makeModal(screen, "SellLogs", "SELL LOGS", "Cash out your ready logs for Coins.")
local sellCard = Instance.new("Frame")
sellCard.Name = "SaleSummary"
sellCard.AnchorPoint = Vector2.new(0.5, 0.5)
sellCard.Position = UDim2.fromScale(0.5, 0.6)
sellCard.Size = UDim2.new(0.84, 0, 0, 224)
sellCard.BackgroundColor3 = COLORS.Surface
sellCard.Parent = sellPanel
round(sellCard, 20)
outline(sellCard, COLORS.Gold, 2)
local sellCardConstraint = Instance.new("UISizeConstraint")
sellCardConstraint.MinSize = Vector2.new(250, 224)
sellCardConstraint.MaxSize = Vector2.new(640, 224)
sellCardConstraint.Parent = sellCard
local sellIcon = label(sellCard, "Icon", "🪙", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 12), 34, COLORS.Gold, Enum.Font.GothamBold)
sellIcon.TextXAlignment = Enum.TextXAlignment.Center
local sellCount = label(sellCard, "EligibleCount", "0 LOGS READY TO SELL", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 58), 15, COLORS.Ink, Enum.Font.GothamBlack)
sellCount.TextXAlignment = Enum.TextXAlignment.Center
local sellValue = label(sellCard, "TotalValue", "0 COINS", UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 90), 26, COLORS.GreenDark, Enum.Font.GothamBlack)
sellValue.TextXAlignment = Enum.TextXAlignment.Center
local sellHint = label(sellCard, "LockHint", "Locked logs stay in your bag.", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 130), 11, COLORS.Muted, Enum.Font.GothamBold)
sellHint.TextXAlignment = Enum.TextXAlignment.Center
local sellButton = button(sellCard, "SellUnlockedButton", "SELL ALL", UDim2.new(1, -28, 0, 54), UDim2.new(0, 14, 1, -66), COLORS.Gold)
sellButton.TextSize = 20
round(sellButton, 16)
local sellPending = false
local sellEligibleCount = 0

local latestLogsData
local latestShopData
local selectedLogUid
local selectedAxeUid
local activeBagTab = "Logs"
local refreshShop
local isRefreshingLogs = false
local refreshLogsQueued = false
local saleCoinsBefore
local feedbackSequence = 0

local function showFeedback(message, color)
	feedbackSequence += 1
	local sequence = feedbackSequence
	feedback.Text = message
	feedback.TextColor3 = color or COLORS.Gold
	feedback.Visible = true
	task.delay(1.8, function()
		if feedbackSequence == sequence then feedback.Visible = false end
	end)
end

local function closeAllPanels()
	bagOverlay.Visible = false
	shopOverlay.Visible = false
	sellOverlay.Visible = false
end

local function showPanel(target)
	closeAllPanels()
	target.Visible = true
end

local function setBagLayout()
	local width = bagBody.AbsoluteSize.X
	bagToolbar.Position = UDim2.new(0, 12, 0, 52)
	bagToolbar.Size = UDim2.new(1, -24, 0, 30)
	bagBody.Position = UDim2.new(0, 12, 0, 90)
	bagBody.Size = UDim2.new(1, -24, 1, -102)
	logGrid.Position = UDim2.new(0, 0, 0, 0)
	logGrid.Size = UDim2.new(1, 0, 1, -50)
	emptyState.Position = UDim2.new(0, 0, 0, 0)
	emptyState.Size = UDim2.new(1, 0, 1, -50)
	detailPanel.Position = UDim2.new(0, 0, 1, -44)
	detailPanel.Size = UDim2.new(1, 0, 0, 44)
	local availableWidth = math.max(0, width - 12)
	local columns = math.clamp(math.floor((availableWidth + 5) / 77), 3, 10)
	local cellSide = math.clamp(math.floor((availableWidth - 5 * (columns - 1)) / columns), 56, 82)
	gridLayout.FillDirectionMaxCells = columns
	gridLayout.CellSize = UDim2.fromOffset(cellSide, cellSide)
end

local function clearGrid()
	for _, child in ipairs(logGrid:GetChildren()) do
		if child ~= gridLayout and not child:IsA("UIPadding") then child:Destroy() end
	end
end

local function showGrid()
	emptyState.Visible = false
	logGrid.Visible = true
end

local function showEmptyState(text)
	logGrid.Visible = false
	emptyState.Text = text
	emptyState.Visible = true
end

local function sortedLogs(data)
	local logs = type(data.Logs) == "table" and table.clone(data.Logs) or {}
	local mode = sortModes[sortIndex]
	table.sort(logs, function(a, b)
			if mode == "Value" then
				if a.EstimatedSellValue ~= b.EstimatedSellValue then return (a.EstimatedSellValue or 0) > (b.EstimatedSellValue or 0) end
			elseif mode == "Species" then
				if a.SpeciesId ~= b.SpeciesId then return tostring(a.SpeciesId or "") < tostring(b.SpeciesId or "") end
			elseif mode == "Newest" then
				if a.CreatedAt ~= b.CreatedAt then return (a.CreatedAt or 0) > (b.CreatedAt or 0) end
			else
				if a.WeightKg ~= b.WeightKg then return (a.WeightKg or 0) > (b.WeightKg or 0) end
			end
			return tostring(a.UID or "") < tostring(b.UID or "")
		end)
	return logs
end

local function findSelectedLog(logs)
	for _, record in ipairs(logs) do
		if record.UID == selectedLogUid then return record end
	end
	return nil
end

local function updateBagTabs(logCount, capacity, axeCount)
	logsTab.BackgroundColor3 = if activeBagTab == "Logs" then COLORS.BagHeader else COLORS.BagSlot
	logsTab.TextColor3 = if activeBagTab == "Logs" then COLORS.BagBack else COLORS.BagText
	axesTab.BackgroundColor3 = if activeBagTab == "Axes" then COLORS.BagHeader else COLORS.BagSlot
	axesTab.TextColor3 = if activeBagTab == "Axes" then COLORS.BagBack else COLORS.BagText
	bagCountLabel.Text = if activeBagTab == "Logs"
		then string.format("%d/%d LOGS", logCount or 0, capacity or 10)
		else string.format("%d OWNED", axeCount or 0)
	bagCountLabel.TextColor3 = COLORS.BagMuted
	bagCountLabel.TextWrapped = false
	local sortLabels = { "WT", "VALUE", "A-Z", "NEW" }
	sortButton.Text = "SORT " .. sortLabels[sortIndex]
	sortButton.Visible = activeBagTab == "Logs"
end

local function renderLogDetail(record)
	local hasRecord = type(record) == "table"
	detailIcon.Text = "🪵"
	detailSpecies.Text = if hasRecord then tostring(record.SpeciesId or "Unknown") else "NO LOG SELECTED"
	detailWeight.Text = if hasRecord then string.format("%.2f KG", tonumber(record.WeightKg) or 0) else ""
	detailValue.Text = ""
	detailSize.Text = ""
	detailStatus.Text = if not hasRecord then "CHOOSE A SLOT" elseif player:GetAttribute("HeldLogUID") == record.UID then "EQUIPPED" else "TAP TO EQUIP"
	detailStatus.TextColor3 = if hasRecord and player:GetAttribute("HeldLogUID") == record.UID then COLORS.Green else COLORS.BagMuted
	favoriteButton.Visible = hasRecord
	if not hasRecord then return end
	favoriteButton.Text = if record.Locked then "UNLOCK" else "LOCK"
	favoriteButton.BackgroundColor3 = if record.Locked then COLORS.BagHeader else COLORS.BagSlot
	favoriteButton.TextColor3 = if record.Locked then COLORS.BagBack else COLORS.BagText
end

local function renderAxeDetail(axe)
	local hasAxe = type(axe) == "table"
	detailIcon.Text = "🪓"
	detailSpecies.Text = if hasAxe then tostring(axe.Name or "Axe") else "OWNED AXES"
	detailWeight.Text = if hasAxe then "PWR " .. tostring(axe.Power or 0) else ""
	detailStatus.Text = if not hasAxe then "NO OWNED AXES" elseif axe.Equipped then "EQUIPPED" else "TAP TO EQUIP"
	detailStatus.TextColor3 = if hasAxe and axe.Equipped then COLORS.Green else COLORS.BagMuted
	detailValue.Text = ""
	detailSize.Text = ""
	favoriteButton.Visible = false
end

local function makeItemSlot(name, order, icon, title, metadata, isEquipped, isSelected, isLocked, onActivated)
	local slot = Instance.new("TextButton")
	slot.Name = name
	slot.LayoutOrder = order
	slot.BackgroundColor3 = if isSelected then COLORS.BagSelected else COLORS.BagSlot
	slot.Text = ""
	slot.AutoButtonColor = true
	slot.Parent = logGrid
	round(slot, 4)
	outline(slot, if isEquipped then COLORS.Green elseif isSelected then COLORS.Gold else COLORS.BagLine, if isEquipped or isSelected then 2 else 1)
	local iconLabel = label(slot, "Icon", icon, UDim2.new(1, -8, 0, 25), UDim2.new(0, 4, 0, 2), 19, COLORS.BagText, Enum.Font.GothamBold)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.TextWrapped = false
	local nameLabel = label(slot, "Name", title, UDim2.new(1, -6, 0, 16), UDim2.new(0, 3, 0, 28), 9, COLORS.BagText, Enum.Font.GothamBold)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextWrapped = false
	local metadataLabel = label(slot, "Metadata", metadata, UDim2.new(1, -6, 0, 14), UDim2.new(0, 3, 1, -17), 8, COLORS.BagMuted, Enum.Font.GothamMedium)
	metadataLabel.TextXAlignment = Enum.TextXAlignment.Center
	metadataLabel.TextTruncate = Enum.TextTruncate.AtEnd
	metadataLabel.TextWrapped = false
	if isEquipped then
		local equippedMark = label(slot, "Equipped", "ON", UDim2.new(0, 24, 0, 12), UDim2.new(1, -26, 0, 2), 8, COLORS.Green, Enum.Font.GothamBlack)
		equippedMark.TextXAlignment = Enum.TextXAlignment.Right
	elseif isLocked then
		local lockedMark = label(slot, "Locked", "L", UDim2.new(0, 12, 0, 12), UDim2.new(0, 3, 0, 2), 8, COLORS.BagHeader, Enum.Font.GothamBlack)
		lockedMark.TextXAlignment = Enum.TextXAlignment.Left
	end
	slot.Activated:Connect(onActivated)
	return slot
end

local function ownedAxes(data)
	local result = {}
	for _, axe in ipairs(type(data) == "table" and data.Axes or {}) do
		if axe.Owned == true and typeof(axe.UID) == "string" then
			table.insert(result, axe)
		end
	end
	return result
end

local function renderAxes(data)
	local axes = ownedAxes(data)
	if not selectedAxeUid then
		for _, axe in ipairs(axes) do
			if axe.Equipped then
				selectedAxeUid = axe.UID
				break
			end
		end
	end
	local selectedAxe
	local selectedStillOwned = false
	for _, axe in ipairs(axes) do
		if axe.UID == selectedAxeUid then
			selectedAxe = axe
			selectedStillOwned = true
		end
	end
	if not selectedStillOwned then
		selectedAxeUid = nil
		selectedAxe = nil
		for _, axe in ipairs(axes) do
			if axe.Equipped then
				selectedAxeUid = axe.UID
				selectedAxe = axe
				break
			end
		end
	end
	updateBagTabs(latestLogsData and #(latestLogsData.Logs or {}) or 0, latestLogsData and latestLogsData.Capacity or 10, #axes)
	clearGrid()
	showGrid()
	if not data then
		showEmptyState("LOADING AXES...")
		renderAxeDetail(nil)
		return
	end
	if #axes == 0 then
		showEmptyState("NO OWNED AXES YET")
		renderAxeDetail(nil)
		return
	end
	for index, axe in ipairs(axes) do
		local isEquipped = axe.Equipped == true
		local isSelected = axe.UID == selectedAxeUid
		makeItemSlot("AxeSlot_" .. tostring(axe.Id or index), index, "🪓", tostring(axe.Name or "Axe"), "PWR " .. tostring(axe.Power or 0), isEquipped, isSelected, false, function()
			if typeof(axe.UID) ~= "string" then return end
			selectedAxeUid = axe.UID
			equipAxe:FireServer(axe.UID)
			renderAxes(latestShopData)
			task.delay(0.35, function()
				if bagOverlay.Visible and activeBagTab == "Axes" then refreshShop() end
			end)
		end)
	end
	renderAxeDetail(selectedAxe)
end

local function renderLogs(data)
	if type(data) ~= "table" then return end
	latestLogsData = data
	local logs = sortedLogs(data)
	local capacity = typeof(data.Capacity) == "number" and data.Capacity or 10
	local coins = typeof(data.Coins) == "number" and data.Coins or 0
	hudCoins.Text = "🪙 " .. formatCoins(coins)
	hudLogs.Text = string.format("🪵  BAG  %d / %d", #logs, capacity)
	local isFull = #logs >= capacity
	bagButton.Text = if isFull then "BAG FULL  •  M" else "OPEN BAG  •  M"
	bagButton.BackgroundColor3 = if isFull then COLORS.Orange else COLORS.Green
	if saleCoinsBefore then
		if coins > saleCoinsBefore then
			showFeedback("+" .. formatCoins(coins - saleCoinsBefore) .. " COINS!", COLORS.Gold)
		end
		saleCoinsBefore = nil
	end
	if not findSelectedLog(logs) then
		selectedLogUid = nil
		local heldUid = player:GetAttribute("HeldLogUID")
		for _, record in ipairs(logs) do
			if record.UID == heldUid then
				selectedLogUid = heldUid
				break
			end
		end
	end
	updateBagTabs(#logs, capacity, #ownedAxes(latestShopData))
	if activeBagTab == "Axes" then
		renderAxes(latestShopData)
		return
	end
	clearGrid()
	showGrid()
	if #logs == 0 then
		showEmptyState("NO LOGS YET • CHOP A TREE TO FILL YOUR BAG")
		renderLogDetail(nil)
		return
	end
	for index, record in ipairs(logs) do
		local isHeld = record.UID == player:GetAttribute("HeldLogUID")
		local isSelected = record.UID == selectedLogUid
		makeItemSlot("LogSlot_" .. tostring(record.UID or index), index, "🪵", tostring(record.SpeciesId or "Log"), string.format("%.2f KG", tonumber(record.WeightKg) or 0), isHeld, isSelected, record.Locked == true, function()
			if typeof(record.UID) ~= "string" then return end
			if player:GetAttribute("HeldLogUID") == record.UID then
				selectedLogUid = nil
				setHeldLog:FireServer("")
			else
				selectedLogUid = record.UID
				setHeldLog:FireServer(record.UID)
			end
			if latestLogsData then renderLogs(latestLogsData) end
		end)
	end
	renderLogDetail(findSelectedLog(logs))
end

bagPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if not bagOverlay.Visible then return end
	setBagLayout()
	if latestLogsData then renderLogs(latestLogsData) end
end)

local function clearShopRows()
	for _, child in ipairs(shopList:GetChildren()) do
		if child ~= shopLayout then child:Destroy() end
	end
end

local function renderShop(data)
	if type(data) ~= "table" then return end
	latestShopData = data
	updateBagTabs(latestLogsData and #(latestLogsData.Logs or {}) or 0, latestLogsData and latestLogsData.Capacity or 10, #ownedAxes(data))
	clearShopRows()
	hudCoins.Text = "🪙 " .. formatCoins(data.Coins or 0)
	local layoutOrder = 0
	for _, axe in ipairs(data.Axes or {}) do
		layoutOrder += 1
		local card = Instance.new("Frame")
		card.Name = "AxeCard_" .. tostring(axe.Id)
		card.LayoutOrder = layoutOrder
		card.Size = UDim2.new(1, -8, 0, 86)
		card.BackgroundColor3 = layoutOrder % 2 == 0 and COLORS.SurfaceAlt or COLORS.Surface
		card.Parent = shopList
		round(card, 16)
		outline(card, COLORS.Blue, 1.5)
		local axeIcon = Instance.new("Frame")
		axeIcon.Name = "AxeIcon"
		axeIcon.Position = UDim2.new(0, 9, 0.5, -20)
		axeIcon.Size = UDim2.fromOffset(40, 40)
		axeIcon.BackgroundColor3 = COLORS.Orange
		axeIcon.Parent = card
		round(axeIcon, 13)
		local axeEmoji = label(axeIcon, "Emoji", "🪓", UDim2.fromScale(1, 1), UDim2.new(), 23, COLORS.DarkInk, Enum.Font.GothamBlack)
		axeEmoji.TextXAlignment = Enum.TextXAlignment.Center
		local name = label(card, "Name", tostring(axe.Name), UDim2.new(0.50, -58, 0, 28), UDim2.new(0, 56, 0, 10), 16, COLORS.Ink, Enum.Font.GothamBlack)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local power = label(card, "Power", "POWER  " .. tostring(axe.Power), UDim2.new(0.50, -58, 0, 24), UDim2.new(0, 56, 0, 47), 12, COLORS.Blue, Enum.Font.GothamBold)
		power.TextTruncate = Enum.TextTruncate.AtEnd
		local actionText
		local actionColor
		if axe.Owned then
			actionText = axe.Equipped and "EQUIPPED" or "EQUIP"
			actionColor = axe.Equipped and COLORS.Blue or COLORS.Green
		else
			actionText = "BUY  •  " .. formatCoins(axe.Price)
			actionColor = (data.Coins or 0) >= axe.Price and COLORS.Gold or COLORS.Disabled
		end
		local action = button(card, "Action", actionText, UDim2.new(0.43, -8, 0, 52), UDim2.new(0.55, 0, 0.5, -26), actionColor)
		action.TextSize = 14
		round(action, 14)
		action.Activated:Connect(function()
			if axe.Owned then
				if not axe.Equipped and typeof(axe.UID) == "string" then equipAxe:FireServer(axe.UID) end
			else
				purchaseAxe:FireServer(axe.Id)
			end
			task.delay(0.35, function()
				if shopOverlay.Visible then
					local ok, fresh = pcall(function() return getShopData:InvokeServer() end)
					if ok then renderShop(fresh) end
				end
			end)
		end)
	end

	layoutOrder += 1
	local capacity = typeof(data.Capacity) == "number" and data.Capacity or 10
	local heading = Instance.new("Frame")
	heading.Name = "CapacityHeading"
	heading.LayoutOrder = layoutOrder
	heading.Size = UDim2.new(1, -8, 0, 40)
	heading.BackgroundTransparency = 1
	heading.Parent = shopList
	label(heading, "Text", "BAG POWER  •  CURRENT CAPACITY " .. tostring(capacity), UDim2.new(1, 0, 1, 0), UDim2.new(), 13, COLORS.DarkInk, Enum.Font.GothamBlack)

	for _, upgrade in ipairs(data.CapacityUpgrades or {}) do
		if upgrade.Capacity > capacity then
			layoutOrder += 1
			local card = Instance.new("Frame")
			card.Name = "CapacityCard_" .. tostring(upgrade.Capacity)
			card.LayoutOrder = layoutOrder
			card.Size = UDim2.new(1, -8, 0, 76)
			card.BackgroundColor3 = COLORS.Surface
			card.Parent = shopList
			round(card, 16)
			outline(card, COLORS.Blue, 1.5)
			label(card, "Upgrade", "CARRY " .. tostring(upgrade.Capacity) .. " LOGS", UDim2.new(0.50, -12, 1, 0), UDim2.new(0, 14, 0, 0), 14, COLORS.Ink, Enum.Font.GothamBlack)
			local action = button(card, "BuyCapacity", "UPGRADE  •  " .. formatCoins(upgrade.Price), UDim2.new(0.44, -10, 0, 48), UDim2.new(0.56, 0, 0.5, -24), (data.Coins or 0) >= upgrade.Price and COLORS.Gold or COLORS.Disabled)
			action.TextSize = 12
			round(action, 14)
			action.Activated:Connect(function()
				purchaseCapacity:FireServer(upgrade.Capacity)
				task.delay(0.35, function()
					if shopOverlay.Visible then
						local ok, fresh = pcall(function() return getShopData:InvokeServer() end)
						if ok then renderShop(fresh) end
					end
				end)
			end)
		end
	end
	if bagOverlay.Visible and activeBagTab == "Axes" then renderAxes(data) end
end

local function refreshLogs()
	if isRefreshingLogs then
		refreshLogsQueued = true
		return
	end
	isRefreshingLogs = true
	task.spawn(function()
		local ok, data = pcall(function() return getLogsData:InvokeServer() end)
		if ok then renderLogs(data) end
		isRefreshingLogs = false
		if refreshLogsQueued then
			refreshLogsQueued = false
			refreshLogs()
		end
	end)
end

refreshShop = function()
	task.spawn(function()
		local ok, data = pcall(function() return getShopData:InvokeServer() end)
		if ok then renderShop(data) end
	end)
end

local function refreshSellSummary()
	task.spawn(function()
		local ok, summary = pcall(function() return getSellSummary:InvokeServer() end)
		if not ok or type(summary) ~= "table" then return end
		local count = tonumber(summary.EligibleCount) or 0
		local value = tonumber(summary.TotalValue) or 0
		sellEligibleCount = count
		sellCount.Text = string.format("%d LOG%s READY TO SELL", count, if count == 1 then "" else "S")
		sellValue.Text = formatCoins(value) .. " COINS"
		sellButton.Text = if count > 0 then "SELL ALL" else "NOTHING TO SELL"
		sellButton.BackgroundColor3 = if count > 0 then COLORS.Gold else COLORS.Disabled
		hudCoins.Text = "🪙 " .. formatCoins(summary.Coins or 0)
	end)
end

local function openBag()
	showPanel(bagOverlay)
	setBagLayout()
	refreshLogs()
	refreshShop()
end

local function openAxeShop()
	showPanel(shopOverlay)
	refreshShop()
end

local function openLumberDepot()
	showPanel(sellOverlay)
	refreshSellSummary()
end

bagButton.Activated:Connect(openBag)
logsTab.Activated:Connect(function()
	activeBagTab = "Logs"
	if latestLogsData then renderLogs(latestLogsData) else refreshLogs() end
end)
axesTab.Activated:Connect(function()
	activeBagTab = "Axes"
	if latestShopData then renderAxes(latestShopData) else renderAxes(nil) end
	if not latestShopData then refreshShop() end
end)
sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #sortModes + 1
	if latestLogsData and activeBagTab == "Logs" then renderLogs(latestLogsData) end
end)

favoriteButton.Activated:Connect(function()
	if typeof(selectedLogUid) ~= "string" or not latestLogsData then return end
	local record = findSelectedLog(sortedLogs(latestLogsData))
	if record then setLogLocked:FireServer(record.UID, not record.Locked) end
end)

sellButton.Activated:Connect(function()
	if sellPending then return end
	if sellEligibleCount <= 0 then return end
	sellPending = true
	sellButton.Text = "SELLING..."
	local saleBaseline = latestLogsData and latestLogsData.Coins
	saleCoinsBefore = typeof(saleBaseline) == "number" and saleBaseline or nil
	sellUnlockedLogs:FireServer()
	task.delay(0.6, function()
		sellPending = false
		if sellOverlay.Visible then refreshSellSummary() end
	end)
	task.delay(1.5, function()
		if saleCoinsBefore == saleBaseline then saleCoinsBefore = nil end
	end)
end)

economyStateUpdated.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" then renderLogs(snapshot) else refreshLogs() end
	if sellOverlay.Visible then refreshSellSummary() end
	if shopOverlay.Visible then refreshShop() end
	if bagOverlay.Visible and activeBagTab == "Axes" then refreshShop() end
end)

local legacyEconomyUpdated = economy:FindFirstChild("EconomyUpdated")
if legacyEconomyUpdated then
	legacyEconomyUpdated.OnClientEvent:Connect(function(currency)
		if currency == "Coins" then
			refreshLogs()
			if shopOverlay.Visible then refreshShop() end
			if sellOverlay.Visible then refreshSellSummary() end
		end
	end)
end

player:GetAttributeChangedSignal("HeldLogUID"):Connect(function()
	if latestLogsData then renderLogs(latestLogsData) end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.M then
		if bagOverlay.Visible then closeAllPanels() else openBag() end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		closeAllPanels()
	end
end)

local stationInteractions = {}

local function bindStationPrompt(stationName, promptName, callback)
	task.spawn(function()
		local sourceWorld = workspace:WaitForChild("SourceWorld", 120)
		if not sourceWorld then return end
		local station = sourceWorld:WaitForChild(stationName, 60)
		if not station then return end
		local interaction = station:WaitForChild("Interaction", 30)
		if not interaction then return end
		local prompt = interaction:WaitForChild(promptName, 30)
		if prompt and prompt:IsA("ProximityPrompt") then
			-- The prompt range is source-built server configuration replicated by
			-- Roblox. Prefer the explicit Interaction attribute when present, but
			-- retain this prompt value during a live world rebuild.
			stationInteractions[stationName] = {
				Interaction = interaction,
				UseDistance = prompt.MaxActivationDistance,
			}
			prompt.Triggered:Connect(callback)
		end
	end)
end

bindStationPrompt("AxeShopStation", "AxeShopPrompt", openAxeShop)
bindStationPrompt("HomeEconomyStation", "EconomyPrompt", openLumberDepot)

local function isNearStation(stationName)
	local binding = stationInteractions[stationName]
	local interaction = binding and binding.Interaction
	if not interaction or not interaction:IsDescendantOf(workspace) then return true end
	local useDistance = interaction:GetAttribute("UseDistance")
	if type(useDistance) ~= "number" or useDistance ~= useDistance or useDistance <= 0 then
		useDistance = binding.UseDistance
	end
	if type(useDistance) ~= "number" or useDistance ~= useDistance or useDistance <= 0 then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return true end
	local localPosition = interaction.CFrame:PointToObjectSpace(root.Position)
	local halfSize = interaction.Size * 0.5
	local nearestPoint = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	return (root.Position - interaction.CFrame:PointToWorldSpace(nearestPoint)).Magnitude <= useDistance
end

-- The server independently validates all station mutations. Closing a station
-- panel after the player walks away keeps the normal experience just as clear.
task.spawn(function()
	while screen.Parent do
		task.wait(0.35)
		if shopOverlay.Visible and not isNearStation("AxeShopStation") then
			shopOverlay.Visible = false
			showFeedback("RETURN TO THE AXE SHOP", COLORS.Orange)
		elseif sellOverlay.Visible and not isNearStation("HomeEconomyStation") then
			sellOverlay.Visible = false
			showFeedback("RETURN TO THE SELL STATION", COLORS.Orange)
		end
	end
end)

local profileLoadEvent = ReplicatedStorage:WaitForChild("Profile"):WaitForChild("ProfileLoadEvent")
profileLoadEvent.OnClientEvent:Connect(function()
	refreshLogs()
	if sellOverlay.Visible then refreshSellSummary() end
	if shopOverlay.Visible then refreshShop() end
	if bagOverlay.Visible then refreshShop() end
end)
if player:GetAttribute("ProfileReady") then refreshLogs() end
