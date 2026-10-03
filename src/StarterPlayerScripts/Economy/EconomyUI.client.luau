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
local bagToolbar = Instance.new("Frame")
bagToolbar.Name = "Toolbar"
bagToolbar.BackgroundTransparency = 1
bagToolbar.Position = UDim2.new(0, 18, 0, 78)
bagToolbar.Size = UDim2.new(1, -36, 0, 40)
bagToolbar.Parent = bagPanel
local sortModes = { "Weight", "Value", "Species", "Newest" }
local sortIndex = 1
local sortButton = button(bagToolbar, "SortButton", "SORT  •  WEIGHT", UDim2.new(0, 168, 1, 0), UDim2.new(), COLORS.Blue)
sortButton.TextSize = 12
local bagCountLabel = label(bagToolbar, "Capacity", "0 / 10 LOGS", UDim2.new(1, -182, 1, 0), UDim2.new(0, 182, 0, 0), 13, COLORS.Muted, Enum.Font.GothamBold)
bagCountLabel.TextXAlignment = Enum.TextXAlignment.Right

local bagBody = Instance.new("Frame")
bagBody.Name = "BagBody"
bagBody.BackgroundTransparency = 1
bagBody.Position = UDim2.new(0, 18, 0, 128)
bagBody.Size = UDim2.new(1, -36, 1, -146)
bagBody.Parent = bagPanel

local logGrid = Instance.new("ScrollingFrame")
logGrid.Name = "LogGrid"
logGrid.BackgroundColor3 = COLORS.Surface
logGrid.BorderSizePixel = 0
logGrid.ScrollBarThickness = 6
logGrid.ScrollBarImageColor3 = COLORS.GreenDark
logGrid.CanvasSize = UDim2.new()
logGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
logGrid.Parent = bagBody
round(logGrid, 16)
outline(logGrid, COLORS.Blue, 2)

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 8)
gridPadding.PaddingBottom = UDim.new(0, 8)
gridPadding.PaddingLeft = UDim.new(0, 8)
gridPadding.PaddingRight = UDim.new(0, 8)
gridPadding.Parent = logGrid

local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.CellSize = UDim2.new(0.5, -6, 0, 104)
gridLayout.FillDirectionMaxCells = 2
gridLayout.Parent = logGrid

local detailPanel = Instance.new("Frame")
detailPanel.Name = "CurrentLog"
detailPanel.BackgroundColor3 = COLORS.SurfaceAlt
detailPanel.Parent = bagBody
round(detailPanel, 16)
outline(detailPanel, COLORS.Gold, 2)

local detailIcon = label(detailPanel, "LogIcon", "🪵", UDim2.new(0, 48, 0, 42), UDim2.new(0, 14, 0, 12), 30, COLORS.Orange, Enum.Font.GothamBold)
detailIcon.TextXAlignment = Enum.TextXAlignment.Center
local detailSpecies = label(detailPanel, "Species", "NO LOG EQUIPPED", UDim2.new(1, -78, 0, 30), UDim2.new(0, 70, 0, 14), 18, COLORS.Ink, Enum.Font.GothamBlack)
local detailStatus = label(detailPanel, "Status", "TAP A CARD TO EQUIP", UDim2.new(1, -28, 0, 20), UDim2.new(0, 14, 0, 48), 11, COLORS.Blue, Enum.Font.GothamBlack)
local detailWeight = label(detailPanel, "Weight", "", UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 64), 14, COLORS.Muted)
local detailValue = label(detailPanel, "Value", "", UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 91), 14, COLORS.GreenDark, Enum.Font.GothamBold)
local detailSize = label(detailPanel, "Size", "", UDim2.new(1, -28, 0, 22), UDim2.new(0, 14, 0, 118), 12, COLORS.Muted)
local favoriteButton = button(detailPanel, "FavoriteButton", "♡  LOCK FROM SELLING", UDim2.new(1, -28, 0, 44), UDim2.new(0, 14, 1, -56), COLORS.Pink)
favoriteButton.TextSize = 12
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
local isRefreshingLogs = false
local refreshLogsQueued = false
local saleCoinsBefore
local feedbackSequence = 0
local compactBagLayout = false

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
	local height = bagBody.AbsoluteSize.Y
	local wide = width >= 690
	compactBagLayout = bagPanel.AbsoluteSize.Y < 400
	if compactBagLayout then
		-- On short landscape phones, keep the current-log details and lock control usable.
		bagPanel.Header.Size = UDim2.new(1, -40, 0, 48)
		bagToolbar.Position = UDim2.new(0, 18, 0, 62)
		bagToolbar.Size = UDim2.new(1, -36, 0, 32)
		bagBody.Position = UDim2.new(0, 18, 0, 102)
		bagBody.Size = UDim2.new(1, -36, 1, -112)
		logGrid.Position = UDim2.new(0, 0, 0, 0)
		logGrid.Size = UDim2.new(1, 0, 0, 70)
		detailPanel.Position = UDim2.new(0, 0, 0, 78)
		detailPanel.Size = UDim2.new(1, 0, 1, -78)
		gridLayout.FillDirectionMaxCells = 2
		gridLayout.CellSize = UDim2.new(0.5, -6, 0, 60)

		detailIcon.Position = UDim2.new(0, 10, 0, 6)
		detailIcon.Size = UDim2.new(0, 40, 0, 32)
		detailIcon.TextSize = 22
		detailSpecies.Position = UDim2.new(0, 56, 0, 7)
		detailSpecies.Size = UDim2.new(1, -68, 0, 24)
		detailSpecies.TextSize = 15
		detailStatus.Position = UDim2.new(0, 12, 0, 32)
		detailStatus.Size = UDim2.new(1, -24, 0, 18)
		detailStatus.TextSize = 10
		detailWeight.Visible = false
		detailValue.Visible = false
		detailSize.Visible = false
		favoriteButton.Position = UDim2.new(0, 12, 1, -40)
		favoriteButton.Size = UDim2.new(1, -24, 0, 32)
		favoriteButton.TextSize = 10
		return
	end

	bagPanel.Header.Size = UDim2.new(1, -40, 0, 62)
	bagToolbar.Position = UDim2.new(0, 18, 0, 78)
	bagToolbar.Size = UDim2.new(1, -36, 0, 40)
	bagBody.Position = UDim2.new(0, 18, 0, 128)
	bagBody.Size = UDim2.new(1, -36, 1, -146)
	detailIcon.Position = UDim2.new(0, 14, 0, 12)
	detailIcon.Size = UDim2.new(0, 48, 0, 42)
	detailIcon.TextSize = 30
	detailSpecies.Position = UDim2.new(0, 70, 0, 14)
	detailSpecies.Size = UDim2.new(1, -78, 0, 30)
	detailSpecies.TextSize = 18
	detailStatus.Position = UDim2.new(0, 14, 0, 48)
	detailStatus.Size = UDim2.new(1, -28, 0, 20)
	detailStatus.TextSize = 11
	detailWeight.Visible = true
	detailValue.Visible = true
	detailWeight.Position = UDim2.new(0, 14, 0, 74)
	detailWeight.Size = UDim2.new(1, -28, 0, 24)
	detailWeight.TextSize = 14
	detailValue.Position = UDim2.new(0, 14, 0, 100)
	detailValue.Size = UDim2.new(1, -28, 0, 24)
	detailValue.TextSize = 14
	detailSize.Visible = true
	detailSize.Position = UDim2.new(0, 14, 0, 126)
	detailSize.Size = UDim2.new(1, -28, 0, 22)
	favoriteButton.Position = UDim2.new(0, 14, 1, -54)
	favoriteButton.Size = UDim2.new(1, -28, 0, 42)
	favoriteButton.TextSize = 12
	if wide then
		logGrid.Position = UDim2.new(0, 0, 0, 0)
		logGrid.Size = UDim2.new(0.59, -7, 1, 0)
		detailPanel.Position = UDim2.new(0.61, 0, 0, 0)
		detailPanel.Size = UDim2.new(0.39, 0, 1, 0)
		gridLayout.FillDirectionMaxCells = 3
		gridLayout.CellSize = UDim2.new(0.333, -7, 0, 104)
	else
		local gridHeight = math.max(140, math.floor(height * 0.48))
		logGrid.Position = UDim2.new(0, 0, 0, 0)
		logGrid.Size = UDim2.new(1, 0, 0, gridHeight)
		detailPanel.Position = UDim2.new(0, 0, 0, gridHeight + 8)
		detailPanel.Size = UDim2.new(1, 0, 1, -gridHeight - 8)
		gridLayout.FillDirectionMaxCells = 2
		gridLayout.CellSize = UDim2.new(0.5, -6, 0, 104)
	end
end

local function clearGrid()
	for _, child in ipairs(logGrid:GetChildren()) do
		if child ~= gridLayout and not child:IsA("UIPadding") then child:Destroy() end
	end
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

local function renderLogDetail(record)
	local hasRecord = type(record) == "table"
	detailSpecies.Text = if hasRecord then tostring(record.SpeciesId or "Unknown") else "NO LOG EQUIPPED"
	detailWeight.Text = if hasRecord then string.format("WEIGHT   %.2f KG", tonumber(record.WeightKg) or 0) else ""
	detailValue.Text = if hasRecord then "VALUE   " .. formatCoins(record.EstimatedSellValue or 0) .. " COINS" else ""
	detailSize.Text = if hasRecord then string.format("Size   %.2f×", tonumber(record.SizeScale) or 1) else ""
	favoriteButton.Visible = hasRecord
	if not hasRecord then
		detailStatus.Text = "TAP A CARD TO EQUIP"
		detailStatus.TextColor3 = COLORS.Blue
		return
	end

	local isHeld = player:GetAttribute("HeldLogUID") == record.UID
	detailStatus.Text = if isHeld then "EQUIPPED  •  READY TO CHOP" else "EQUIPPING..."
	detailStatus.TextColor3 = if isHeld then COLORS.Green else COLORS.Blue
	favoriteButton.Text = if record.Locked then "♥  LOCKED • SAFE FROM SELLING" else "♡  LOCK FROM SELLING"
	favoriteButton.BackgroundColor3 = if record.Locked then COLORS.Pink else COLORS.Gold
end

local function renderLogs(data)
	if type(data) ~= "table" then return end
	latestLogsData = data
	local logs = sortedLogs(data)
	local capacity = typeof(data.Capacity) == "number" and data.Capacity or 10
	local coins = typeof(data.Coins) == "number" and data.Coins or 0
	hudCoins.Text = "🪙 " .. formatCoins(coins)
	hudLogs.Text = string.format("🪵  BAG  %d / %d", #logs, capacity)
	bagCountLabel.Text = string.format("%d / %d LOGS", #logs, capacity)
	local isFull = #logs >= capacity
	bagButton.Text = if isFull then "BAG FULL  •  M" else "OPEN BAG  •  M"
	bagButton.BackgroundColor3 = if isFull then COLORS.Orange else COLORS.Green
	if saleCoinsBefore then
		if coins > saleCoinsBefore then
			showFeedback("+" .. formatCoins(coins - saleCoinsBefore) .. " COINS!", COLORS.Gold)
		end
		saleCoinsBefore = nil
	end
	sortButton.Text = "SORT  •  " .. string.upper(sortModes[sortIndex])
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

	clearGrid()
	if #logs == 0 then
		local empty = label(logGrid, "EmptyBag", "NO LOGS YET  •  CHOP A TREE TO FILL YOUR BAG", UDim2.new(1, -24, 0, 54), UDim2.new(), 14, COLORS.Muted, Enum.Font.GothamBold)
		empty.LayoutOrder = 1
		empty.TextXAlignment = Enum.TextXAlignment.Center
		renderLogDetail(nil)
		return
	end

	for index, record in ipairs(logs) do
		local heldUid = player:GetAttribute("HeldLogUID")
		local isHeld = record.UID == heldUid
		local isSelected = record.UID == selectedLogUid
		local card = Instance.new("TextButton")
		card.Name = "LogCard_" .. tostring(record.UID or index)
		card.LayoutOrder = index
		card.BackgroundColor3 = if isHeld then Color3.fromRGB(62, 51, 31) elseif isSelected then Color3.fromRGB(31, 61, 67) else COLORS.SurfaceAlt
		card.Text = ""
		card.AutoButtonColor = true
		card.Parent = logGrid
		round(card, 16)
		outline(card, if isHeld then COLORS.Orange elseif isSelected then COLORS.Blue else COLORS.Stroke, if isHeld then 3 else 1.5)
		local woodColor = if record.SpeciesId == "Ironwood" then Color3.fromRGB(105, 66, 48) else Color3.fromRGB(174, 105, 55)
		local compactCard = compactBagLayout
		local iconBlock = Instance.new("Frame")
		iconBlock.Name = "LogPreview"
		iconBlock.Position = UDim2.new(0, 8, 0, if compactCard then 6 else 9)
		iconBlock.Size = UDim2.new(0, if compactCard then 30 else 34, 0, if compactCard then 30 else 34)
		iconBlock.BackgroundColor3 = Color3.fromRGB(77, 48, 36)
		iconBlock.Parent = card
		round(iconBlock, 17)
		local outerRing = Instance.new("Frame")
		outerRing.Name = "Bark"
		outerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		outerRing.Position = UDim2.fromScale(0.5, 0.5)
		outerRing.Size = UDim2.fromScale(0.78, 0.78)
		outerRing.BackgroundColor3 = woodColor
		outerRing.Parent = iconBlock
		round(outerRing, 17)
		local innerRing = Instance.new("Frame")
		innerRing.Name = "GrowthRing"
		innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		innerRing.Position = UDim2.fromScale(0.5, 0.5)
		innerRing.Size = UDim2.fromScale(0.46, 0.46)
		innerRing.BackgroundColor3 = if record.SpeciesId == "Ironwood" then Color3.fromRGB(174, 123, 78) else Color3.fromRGB(233, 174, 102)
		innerRing.Parent = iconBlock
		round(innerRing, 17)
		local textLeft = if compactCard then 44 else 48
		local species = label(card, "Species", tostring(record.SpeciesId or "Log"), UDim2.new(1, -66, 0, 20), UDim2.new(0, textLeft, 0, 6), 11, COLORS.Ink, Enum.Font.GothamBlack)
		species.TextTruncate = Enum.TextTruncate.AtEnd
		local weight = label(card, "Weight", string.format("%.2f KG", tonumber(record.WeightKg) or 0), UDim2.new(1, -58, 0, 17), UDim2.new(0, textLeft, 0, 27), 10, COLORS.Muted, Enum.Font.GothamBold)
		weight.TextTruncate = Enum.TextTruncate.AtEnd
		label(card, "Value", "🪙 " .. formatCoins(record.EstimatedSellValue or 0), UDim2.new(1, -40, 0, 18), UDim2.new(0, 9, 0, if compactCard then 39 else 69), 12, COLORS.Green, Enum.Font.GothamBlack)
		local stateMark = label(card, "State", if isHeld then "✓" elseif isSelected then "…" else "", UDim2.new(0, 20, 0, 20), UDim2.new(1, -25, 0, 6), 14, if isHeld then COLORS.Green else COLORS.Blue, Enum.Font.GothamBlack)
		stateMark.TextXAlignment = Enum.TextXAlignment.Center
		local lockMark = label(card, "Lock", if record.Locked then "♥" else "♡", UDim2.new(0, 20, 0, 20), UDim2.new(1, -26, 1, -25), 14, if record.Locked then COLORS.Pink else COLORS.Muted, Enum.Font.GothamBold)
		lockMark.TextXAlignment = Enum.TextXAlignment.Center
		card.Activated:Connect(function()
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

local function refreshShop()
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
sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #sortModes + 1
	if latestLogsData then renderLogs(latestLogsData) end
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
end)
if player:GetAttribute("ProfileReady") then refreshLogs() end
