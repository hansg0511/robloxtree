local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local economy = ReplicatedStorage:WaitForChild("Economy")

local getLogsData = economy:WaitForChild("GetLogsDataRF")
local sellUnlockedLogs = economy:WaitForChild("SellUnlockedLogsRE")
local setLogLocked = economy:WaitForChild("SetLogLockedRE")
local setHeldLog = economy:WaitForChild("SetHeldLogRE")
local economyStateUpdated = economy:WaitForChild("EconomyStateUpdated")
local getShopData = economy:WaitForChild("GetShopDataRF")
local purchaseAxe = economy:WaitForChild("PurchaseAxeRE")
local purchaseCapacity = economy:WaitForChild("PurchaseCapacityRE")
local equipAxe = economy:WaitForChild("EquipAxeRE")

local COLORS = {
	Panel = Color3.fromRGB(31, 38, 43),
	Surface = Color3.fromRGB(43, 51, 56),
	SurfaceAlt = Color3.fromRGB(50, 59, 63),
	Text = Color3.fromRGB(240, 238, 226),
	Muted = Color3.fromRGB(178, 184, 177),
	Accent = Color3.fromRGB(201, 143, 75),
	Green = Color3.fromRGB(93, 161, 112),
	Disabled = Color3.fromRGB(79, 83, 82),
	Stroke = Color3.fromRGB(87, 98, 95),
}

local function round(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function stroke(parent, color, thickness)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color or COLORS.Stroke
	uiStroke.Thickness = thickness or 1
	uiStroke.Parent = parent
	return uiStroke
end

local function label(parent, name, text, size, position, fontSize, color, font)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Font = font or Enum.Font.Gotham
	item.Text = text
	item.TextColor3 = color or COLORS.Text
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
	item.BackgroundColor3 = color or COLORS.SurfaceAlt
	item.AutoButtonColor = true
	item.Font = Enum.Font.GothamSemibold
	item.Text = text
	item.TextColor3 = COLORS.Text
	item.TextSize = 14
	item.TextWrapped = true
	item.Parent = parent
	round(item, 7)
	return item
end

local function makeScroll(parent, name, position, size)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = COLORS.Accent
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

local function formatCoins(value)
	if typeof(value) ~= "number" or value ~= value then return "0" end
	if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
	if value >= 1000 then return string.format("%.1fK", value / 1000) end
	return string.format("%.0f", value)
end

local screen = Instance.new("ScreenGui")
screen.Name = "EconomyScreenGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.DisplayOrder = 20
screen.Parent = playerGui

local openButton = button(screen, "OpenEconomyButton", "GROVE ECONOMY  •  M", UDim2.fromOffset(220, 42), UDim2.new(1, -18, 1, -106), COLORS.Panel)
openButton.AnchorPoint = Vector2.new(1, 1)
openButton.TextSize = 13
stroke(openButton)

local panel = Instance.new("Frame")
panel.Name = "EconomyPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.88, 0, 0.78, 0)
panel.BackgroundColor3 = COLORS.Panel
panel.Visible = false
panel.Parent = screen
round(panel, 12)
stroke(panel, COLORS.Stroke, 1.5)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(350, 360)
sizeConstraint.MaxSize = Vector2.new(860, 650)
sizeConstraint.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 78)
header.BackgroundTransparency = 1
header.Parent = panel

label(header, "Title", "GROVE EXCHANGE", UDim2.new(0.56, 0, 0, 30), UDim2.new(0, 22, 0, 11), 20, COLORS.Text, Enum.Font.GothamBold)
label(header, "Subtitle", "Trade the wood you bring home. Upgrade your tools.", UDim2.new(0.65, 0, 0, 22), UDim2.new(0, 22, 0, 42), 12, COLORS.Muted)
local coinsLabel = label(header, "Coins", "COINS  0", UDim2.new(0, 150, 0, 28), UDim2.new(1, -205, 0, 22), 16, COLORS.Accent, Enum.Font.GothamBold)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
local closeButton = button(header, "CloseButton", "×", UDim2.fromOffset(36, 36), UDim2.new(1, -49, 0, 15), COLORS.SurfaceAlt)
closeButton.TextSize = 24

local tabBar = Instance.new("Frame")
tabBar.Name = "Tabs"
tabBar.Position = UDim2.new(0, 18, 0, 82)
tabBar.Size = UDim2.new(1, -36, 0, 42)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel

local logsTab = button(tabBar, "LogsTab", "LOGS", UDim2.new(0.5, -5, 1, 0), UDim2.new(0, 0, 0, 0), COLORS.Accent)
local shopTab = button(tabBar, "ShopTab", "SHOP", UDim2.new(0.5, -5, 1, 0), UDim2.new(0.5, 5, 0, 0), COLORS.SurfaceAlt)

local logsPanel = Instance.new("Frame")
logsPanel.Name = "LogsPanel"
logsPanel.Position = UDim2.new(0, 18, 0, 137)
logsPanel.Size = UDim2.new(1, -36, 1, -155)
logsPanel.BackgroundTransparency = 1
logsPanel.Parent = panel

local logSummary = label(logsPanel, "LogSummary", "0 / 10 logs", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), 14, COLORS.Muted)
local sortButton = button(logsPanel, "SortButton", "SORT: WEIGHT", UDim2.new(0.48, -4, 0, 34), UDim2.new(0, 0, 0, 31), COLORS.SurfaceAlt)
local sellButton = button(logsPanel, "SellUnlockedButton", "SELL UNLOCKED", UDim2.new(0.48, -4, 0, 34), UDim2.new(0.52, 4, 0, 31), COLORS.Green)

local logList = makeScroll(logsPanel, "LogList", UDim2.new(0, 0, 0, 76), UDim2.new(1, 0, 1, -82))

local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Position = logsPanel.Position
shopPanel.Size = logsPanel.Size
shopPanel.BackgroundTransparency = 1
shopPanel.Visible = false
shopPanel.Parent = panel

label(shopPanel, "ShopIntro", "Fixed prototype tools and log capacity upgrades", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 13, COLORS.Muted)
local shopList = makeScroll(shopPanel, "ShopList", UDim2.new(0, 0, 0, 36), UDim2.new(1, 0, 1, -36))

local currentPage = "Logs"
local sortModes = { "Weight", "Value", "Species", "Newest" }
local sortIndex = 1
local latestLogs = nil
local latestShop = nil
local isRefreshing = false
local refreshQueued = false
local sellPending = false

local function setPage(page)
	currentPage = page
	local showLogs = page == "Logs"
	logsPanel.Visible = showLogs
	shopPanel.Visible = not showLogs
	logsTab.BackgroundColor3 = if showLogs then COLORS.Accent else COLORS.SurfaceAlt
	shopTab.BackgroundColor3 = if showLogs then COLORS.SurfaceAlt else COLORS.Accent
end

local function clearRows(scroller)
	for _, child in ipairs(scroller:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
end

local function renderLogs(data)
	latestLogs = data
	local logs = type(data.Logs) == "table" and table.clone(data.Logs) or {}
	local capacity = typeof(data.Capacity) == "number" and data.Capacity or 10
	logSummary.Text = string.format("%d / %d logs", #logs, capacity)
	coinsLabel.Text = "COINS  " .. formatCoins(data.Coins)
	sortButton.Text = "SORT: " .. string.upper(sortModes[sortIndex])

	local sortMode = sortModes[sortIndex]
	table.sort(logs, function(a, b)
		if sortMode == "Weight" then
			return (a.WeightKg or 0) > (b.WeightKg or 0)
		elseif sortMode == "Value" then
			return (a.EstimatedSellValue or 0) > (b.EstimatedSellValue or 0)
		elseif sortMode == "Species" then
			return tostring(a.SpeciesId or "") < tostring(b.SpeciesId or "")
		else
			return (a.CreatedAt or 0) > (b.CreatedAt or 0)
		end
	end)

	clearRows(logList)
	if #logs == 0 then
		local empty = label(logList, "EmptyLogs", "No logs yet. Chop a tree, then bring your logs back here to sell them.", UDim2.new(1, -8, 0, 72), UDim2.new(), 15, COLORS.Muted)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end

	for index, record in ipairs(logs) do
		local row = Instance.new("Frame")
		row.Name = "LogRow_" .. tostring(record.UID or index)
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 72)
		row.BackgroundColor3 = index % 2 == 0 and COLORS.Surface or COLORS.SurfaceAlt
		row.Parent = logList
		round(row, 8)

		local species = tostring(record.SpeciesId or "Unknown")
		local weight = typeof(record.WeightKg) == "number" and record.WeightKg or 0
		local value = typeof(record.EstimatedSellValue) == "number" and record.EstimatedSellValue or 0
		label(row, "Species", species, UDim2.new(0.34, -4, 0, 25), UDim2.new(0, 14, 0, 9), 14, COLORS.Text, Enum.Font.GothamSemibold)
		label(row, "Details", string.format("%.2f kg  •  %s coins", weight, formatCoins(value)), UDim2.new(0.34, -8, 0, 22), UDim2.new(0, 14, 0, 39), 11, COLORS.Muted)

		local keepButton = button(row, "FavoriteButton", record.Locked and "♥ SAVED" or "♡ SAVE", UDim2.new(0, 82, 0, 38), UDim2.new(1, -178, 0.5, -19), record.Locked and COLORS.Accent or COLORS.Panel)
		keepButton.TextSize = 12
		keepButton.Activated:Connect(function()
			if typeof(record.UID) ~= "string" then return end
			setLogLocked:FireServer(record.UID, not record.Locked)
		end)

		local isHeld = player:GetAttribute("HeldLogUID") == record.UID
		local holdButton = button(row, "HoldButton", isHeld and "DROP" or "HOLD", UDim2.new(0, 70, 0, 38), UDim2.new(1, -86, 0.5, -19), isHeld and COLORS.Accent or COLORS.Green)
		holdButton.TextSize = 12
		holdButton.Activated:Connect(function()
			if typeof(record.UID) ~= "string" then return end
			setHeldLog:FireServer(if isHeld then "" else record.UID)
		end)
	end
end

local function renderShop(data)
	latestShop = data
	clearRows(shopList)
	coinsLabel.Text = "COINS  " .. formatCoins(data.Coins)

	local layoutOrder = 0
	for _, axe in ipairs(data.Axes or {}) do
		layoutOrder += 1
		local card = Instance.new("Frame")
		card.Name = "Axe_" .. tostring(axe.Id)
		card.LayoutOrder = layoutOrder
		card.Size = UDim2.new(1, -8, 0, 72)
		card.BackgroundColor3 = layoutOrder % 2 == 0 and COLORS.Surface or COLORS.SurfaceAlt
		card.Parent = shopList
		round(card, 8)

		label(card, "Name", tostring(axe.Name), UDim2.new(0.48, -8, 0, 26), UDim2.new(0, 14, 0, 8), 15, COLORS.Text, Enum.Font.GothamSemibold)
		label(card, "Power", string.format("POWER  %s", tostring(axe.Power)), UDim2.new(0.48, -8, 0, 22), UDim2.new(0, 14, 0, 39), 12, COLORS.Muted)

		local actionText
		local actionColor
		if axe.Owned then
			actionText = axe.Equipped and "EQUIPPED" or "EQUIP"
			actionColor = axe.Equipped and COLORS.Disabled or COLORS.Green
		else
			actionText = "BUY  •  " .. formatCoins(axe.Price)
			actionColor = data.Coins >= axe.Price and COLORS.Accent or COLORS.Disabled
		end
		local action = button(card, "Action", actionText, UDim2.new(0.43, -4, 0, 42), UDim2.new(0.57, 0, 0.5, -21), actionColor)
		action.Activated:Connect(function()
			if axe.Owned then
			if not axe.Equipped and typeof(axe.UID) == "string" then equipAxe:FireServer(axe.UID) end
			else
				purchaseAxe:FireServer(axe.Id)
			end
		end)
	end

	layoutOrder += 1
	local capacity = typeof(data.Capacity) == "number" and data.Capacity or 10
	local section = Instance.new("Frame")
	section.Name = "CapacitySection"
	section.LayoutOrder = layoutOrder
	section.Size = UDim2.new(1, -8, 0, 46)
	section.BackgroundTransparency = 1
	section.Parent = shopList
	label(section, "Heading", "LOG CAPACITY  •  CURRENT " .. tostring(capacity), UDim2.new(1, 0, 1, 0), UDim2.new(), 13, COLORS.Accent, Enum.Font.GothamBold)

	for _, upgrade in ipairs(data.CapacityUpgrades or {}) do
		if upgrade.Capacity > capacity then
			layoutOrder += 1
			local card = Instance.new("Frame")
			card.Name = "Capacity_" .. tostring(upgrade.Capacity)
			card.LayoutOrder = layoutOrder
			card.Size = UDim2.new(1, -8, 0, 64)
			card.BackgroundColor3 = COLORS.Surface
			card.Parent = shopList
			round(card, 8)
			label(card, "Upgrade", string.format("Increase capacity to %d logs", upgrade.Capacity), UDim2.new(0.48, -8, 1, 0), UDim2.new(0, 14, 0, 0), 13, COLORS.Text)
			local action = button(card, "BuyCapacity", "UPGRADE  •  " .. formatCoins(upgrade.Price), UDim2.new(0.45, -4, 0, 40), UDim2.new(0.55, 0, 0.5, -20), data.Coins >= upgrade.Price and COLORS.Accent or COLORS.Disabled)
			action.Activated:Connect(function()
				purchaseCapacity:FireServer(upgrade.Capacity)
			end)
		end
	end
end

local function refreshAll()
	if isRefreshing then
		refreshQueued = true
		return
	end
	isRefreshing = true
	task.spawn(function()
		local logOk, logsData = pcall(function() return getLogsData:InvokeServer() end)
		if logOk and type(logsData) == "table" then renderLogs(logsData) end
		local shopOk, shopData = pcall(function() return getShopData:InvokeServer() end)
		if shopOk and type(shopData) == "table" then renderShop(shopData) end
		isRefreshing = false
		if refreshQueued then
			refreshQueued = false
			refreshAll()
		end
	end)
end

local function openPanel()
	panel.Visible = true
	setPage("Logs")
	refreshAll()
end

local function togglePanel()
	if panel.Visible then
		panel.Visible = false
	else
		openPanel()
	end
end

openButton.Activated:Connect(togglePanel)
closeButton.Activated:Connect(function() panel.Visible = false end)
logsTab.Activated:Connect(function() setPage("Logs") end)
shopTab.Activated:Connect(function()
	setPage("Shop")
	refreshAll()
end)

sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #sortModes + 1
	if latestLogs then renderLogs(latestLogs) end
end)

sellButton.Activated:Connect(function()
	if sellPending then return end
	sellPending = true
	sellButton.Text = "SELLING..."
	sellUnlockedLogs:FireServer()
	task.delay(0.6, function()
		sellPending = false
		sellButton.Text = "SELL UNLOCKED"
		refreshAll()
	end)
end)

economyStateUpdated.OnClientEvent:Connect(refreshAll)
player:GetAttributeChangedSignal("HeldLogUID"):Connect(function()
	if latestLogs then renderLogs(latestLogs) end
end)
local legacyEconomyUpdated = economy:FindFirstChild("EconomyUpdated")
if legacyEconomyUpdated then
	legacyEconomyUpdated.OnClientEvent:Connect(function(currency)
		if currency == "Coins" then refreshAll() end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.M then
		togglePanel()
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		panel.Visible = false
	end
end)

task.spawn(function()
	local sourceWorld = workspace:WaitForChild("SourceWorld", 60)
	if not sourceWorld then return end
	local homeStation = sourceWorld:WaitForChild("HomeEconomyStation", 60)
	if not homeStation then return end
	local interaction = homeStation:WaitForChild("Interaction", 30)
	if not interaction then return end
	local prompt = interaction:WaitForChild("EconomyPrompt", 30)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(openPanel)
	end
end)

local profileLoadEvent = ReplicatedStorage:WaitForChild("Profile"):WaitForChild("ProfileLoadEvent")
profileLoadEvent.OnClientEvent:Connect(refreshAll)
if player:GetAttribute("ProfileReady") then refreshAll() end
