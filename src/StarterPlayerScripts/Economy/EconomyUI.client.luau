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
local economyStateUpdated = economy:WaitForChild("EconomyStateUpdated")
local getShopData = economy:WaitForChild("GetShopDataRF")
local purchaseAxeHead = economy:WaitForChild("PurchaseAxeHeadRE")
local craftRecipe = economy:WaitForChild("CraftRecipeRE")
local purchaseCapacity = economy:WaitForChild("PurchaseCapacityRE")
local equipAxe = economy:WaitForChild("EquipAxeRE")

local COLORS = {
	Backdrop = Color3.fromRGB(7, 17, 23),
	Panel = Color3.fromRGB(47, 190, 103),
	Surface = Color3.fromRGB(18, 37, 43),
	SurfaceAlt = Color3.fromRGB(28, 54, 60),
	Ink = Color3.fromRGB(250, 249, 226),
	-- Text should stay readable over bright action surfaces. Dark is reserved for
	-- outlines; no interactive label relies on low-contrast black lettering.
	DarkInk = Color3.fromRGB(250, 249, 226),
	Muted = Color3.fromRGB(173, 204, 190),
	Green = Color3.fromRGB(129, 240, 82),
	GreenDark = Color3.fromRGB(90, 226, 98),
	Gold = Color3.fromRGB(255, 214, 57),
	Orange = Color3.fromRGB(255, 143, 48),
	Blue = Color3.fromRGB(67, 199, 245),
	Pink = Color3.fromRGB(255, 107, 158),
	Stroke = Color3.fromRGB(75, 133, 109),
	Disabled = Color3.fromRGB(105, 130, 121),
	BagBack = Color3.fromRGB(31, 38, 35),
	BagFrame = Color3.fromRGB(75, 91, 79),
	BagHeader = Color3.fromRGB(72, 213, 67),
	BagAction = Color3.fromRGB(105, 244, 54),
	BagClose = Color3.fromRGB(245, 48, 65),
	BagSlot = Color3.fromRGB(68, 79, 74),
	BagSelected = Color3.fromRGB(44, 112, 58),
	BagLine = Color3.fromRGB(7, 10, 8),
	BagText = Color3.fromRGB(255, 255, 255),
	BagMuted = Color3.fromRGB(226, 233, 226),
	BagPreview = Color3.fromRGB(44, 58, 50),
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
	item.TextColor3 = COLORS.Ink
	item.TextSize = 14
	item.TextWrapped = true
	item.Parent = parent
	round(item, 10)
	outline(item, Color3.fromRGB(255, 255, 255), 1)
	item.TextStrokeColor3 = COLORS.BagLine
	item.TextStrokeTransparency = 0
	return item
end

-- A small native UI log illustration keeps item cards readable on clients
-- where the wood emoji is rendered as a missing-glyph square.
local function makeLogIllustration(parent, name, zIndex)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.74, 0.44)
	holder.ZIndex = zIndex or 2
	holder.Parent = parent

	local body = Instance.new("Frame")
	body.Name = "Bark"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.54, 0.5)
	body.Size = UDim2.fromScale(0.82, 0.7)
	body.BackgroundColor3 = Color3.fromRGB(116, 73, 42)
	body.BorderSizePixel = 0
	body.ZIndex = holder.ZIndex + 1
	body.Parent = holder
	round(body, 8)
	outline(body, COLORS.BagLine, 2)

	local barkStripe = Instance.new("Frame")
	barkStripe.Name = "BarkStripe"
	barkStripe.AnchorPoint = Vector2.new(0.5, 0.5)
	barkStripe.Position = UDim2.fromScale(0.64, 0.5)
	barkStripe.Size = UDim2.fromScale(0.08, 0.56)
	barkStripe.BackgroundColor3 = Color3.fromRGB(75, 45, 28)
	barkStripe.BorderSizePixel = 0
	barkStripe.ZIndex = holder.ZIndex + 2
	barkStripe.Parent = holder
	round(barkStripe, 4)

	local cutEnd = Instance.new("Frame")
	cutEnd.Name = "CutEnd"
	cutEnd.AnchorPoint = Vector2.new(0.5, 0.5)
	cutEnd.Position = UDim2.fromScale(0.2, 0.5)
	cutEnd.Size = UDim2.fromScale(0.34, 0.88)
	cutEnd.BackgroundColor3 = Color3.fromRGB(223, 169, 93)
	cutEnd.BorderSizePixel = 0
	cutEnd.ZIndex = holder.ZIndex + 3
	cutEnd.Parent = holder
	round(cutEnd, 999)
	outline(cutEnd, COLORS.BagLine, 2)

	local grain = Instance.new("Frame")
	grain.Name = "Grain"
	grain.AnchorPoint = Vector2.new(0.5, 0.5)
	grain.Position = UDim2.fromScale(0.2, 0.5)
	grain.Size = UDim2.fromScale(0.15, 0.39)
	grain.BackgroundColor3 = Color3.fromRGB(184, 122, 67)
	grain.BorderSizePixel = 0
	grain.ZIndex = holder.ZIndex + 4
	grain.Parent = holder
	round(grain, 999)

	return holder
end

local function formatCoins(value)
	if typeof(value) ~= "number" or value ~= value then return "0" end
	if value >= 1000000 then return string.format("%.1fM", value / 1000000) end
	if value >= 1000 then return string.format("%.1fK", value / 1000) end
	return string.format("%.0f", value)
end

local function validNonNegativeNumber(value)
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return nil
	end
	return value
end

local validKg = validNonNegativeNumber

local function formatKgNumber(value)
	value = validKg(value)
	if value == nil then return nil end
	local rounded = math.floor(value * 10 + 0.5) / 10
	if rounded % 1 == 0 then return string.format("%.0f", rounded) end
	return string.format("%.1f", rounded)
end

local function formatKg(value)
	local amount = formatKgNumber(value)
	return if amount then amount .. " KG" else nil
end

local function getCapacitySnapshot(data, fallbackCarryCapacityKg)
	if type(data) ~= "table" then data = {} end
	local usedKg = validKg(data.UsedKg)
	local carryCapacityKg = validKg(data.CarryCapacityKg) or validKg(fallbackCarryCapacityKg)
	local remainingKg = validKg(data.RemainingKg)
	if typeof(data.RemainingKg) == "number" and data.RemainingKg == data.RemainingKg
		and data.RemainingKg ~= math.huge and data.RemainingKg ~= -math.huge then
		-- A slightly negative remainder can occur when the final item exactly
		-- fills the bag. Present it as zero for display and full-state checks.
		remainingKg = math.max(0, data.RemainingKg)
	end
	if usedKg == nil and carryCapacityKg ~= nil and remainingKg ~= nil then
		usedKg = math.max(0, carryCapacityKg - remainingKg)
	end
	if remainingKg == nil and carryCapacityKg ~= nil and usedKg ~= nil then
		remainingKg = math.max(0, carryCapacityKg - usedKg)
	end
	return usedKg, carryCapacityKg, remainingKg
end

local function formatCapacitySummary(usedKg, carryCapacityKg)
	local usedText = formatKgNumber(usedKg) or "—"
	local capacityText = formatKg(carryCapacityKg) or "— KG"
	return usedText .. " / " .. capacityText
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
	panel.Size = UDim2.new(0.94, 0, 0.9, 0)
	panel.BackgroundColor3 = COLORS.Panel
	panel.Parent = overlay
	round(panel, 22)
	outline(panel, COLORS.Gold, 3)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(300, 280)
	constraint.MaxSize = Vector2.new(1180, 820)
	constraint.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(20, 10)
	header.Size = UDim2.new(1, -40, 0, 62)
	header.Parent = panel
	local title = label(header, "Title", titleText, UDim2.new(1, -54, 0, 32), UDim2.new(0, 0, 0, 0), 26, COLORS.Ink, Enum.Font.GothamBlack)
	title.TextStrokeColor3 = COLORS.BagLine
	title.TextStrokeTransparency = 0
	local subtitle = label(header, "Subtitle", subtitleText, UDim2.new(1, -54, 0, 24), UDim2.new(0, 0, 0, 34), 12, COLORS.Ink, Enum.Font.GothamBold)
	subtitle.TextStrokeColor3 = COLORS.BagLine
	subtitle.TextStrokeTransparency = 0
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
local hudCoins = label(coinsPill, "Coins", "🪙  0", UDim2.new(1, -18, 1, 0), UDim2.new(0, 10, 0, 0), 17, COLORS.Ink, Enum.Font.GothamBlack)
hudCoins.TextStrokeColor3 = COLORS.BagLine
hudCoins.TextStrokeTransparency = 0

local logsPill = Instance.new("Frame")
logsPill.Name = "LogsPill"
logsPill.LayoutOrder = 2
logsPill.Size = UDim2.new(0.28, -4, 1, 0)
logsPill.BackgroundColor3 = COLORS.Surface
logsPill.Parent = hud
round(logsPill, 16)
outline(logsPill, COLORS.Blue, 2)
local hudLogs = label(logsPill, "LogCount", "🪵  BAG  — / — KG", UDim2.new(1, -14, 1, 0), UDim2.new(0, 8, 0, 0), 15, COLORS.Ink, Enum.Font.GothamBlack)

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

local bagOverlay, bagPanel = makeModal(screen, "LogBag", "LOG BAG", "Select a log to inspect it. Locked logs stay safe from SELL ALL.")
bagPanel.Size = UDim2.new(0.94, 0, 0.9, 0)
local bagSizeConstraint = bagPanel:FindFirstChildOfClass("UISizeConstraint")
if bagSizeConstraint then
	bagSizeConstraint.MinSize = Vector2.new(300, 280)
	bagSizeConstraint.MaxSize = Vector2.new(1180, 820)
end
bagPanel.BackgroundColor3 = COLORS.BagFrame
bagPanel.BackgroundTransparency = 0
for _, decoration in ipairs(bagPanel:GetChildren()) do
	if decoration:IsA("UICorner") then
		decoration.CornerRadius = UDim.new(0, 16)
	elseif decoration:IsA("UIStroke") then
		decoration.Color = COLORS.BagLine
		decoration.Thickness = 5
	end
end
bagPanel.Header.BackgroundColor3 = COLORS.BagHeader
bagPanel.Header.BackgroundTransparency = 0
bagPanel.Header.Position = UDim2.new(0, 9, 0, 8)
bagPanel.Header.Size = UDim2.new(1, -18, 0, 64)
round(bagPanel.Header, 12)
outline(bagPanel.Header, COLORS.BagLine, 3)
bagPanel.Header.Title.Text = "MY BAG"
bagPanel.Header.Title.AnchorPoint = Vector2.new(0.5, 0)
bagPanel.Header.Title.Position = UDim2.new(0.5, 0, 0, 0)
bagPanel.Header.Title.Size = UDim2.new(0, 300, 1, 0)
bagPanel.Header.Title.TextXAlignment = Enum.TextXAlignment.Center
bagPanel.Header.Title.TextSize = 36
bagPanel.Header.Title.Font = Enum.Font.GothamBlack
bagPanel.Header.Title.TextColor3 = COLORS.BagText
bagPanel.Header.Title.TextStrokeColor3 = COLORS.BagLine
bagPanel.Header.Title.TextStrokeTransparency = 0
bagPanel.Header.Subtitle.Text = "YOUR LOGS AND TOOLS"
bagPanel.Header.Subtitle.Visible = false
bagPanel.Header.CloseButton.AnchorPoint = Vector2.new(0, 0.5)
bagPanel.Header.CloseButton.Position = UDim2.new(1, -58, 0.5, 0)
bagPanel.Header.CloseButton.Size = UDim2.fromOffset(48, 48)
bagPanel.Header.CloseButton.BackgroundColor3 = COLORS.BagClose
bagPanel.Header.CloseButton.TextColor3 = COLORS.BagText
bagPanel.Header.CloseButton.TextSize = 22
bagPanel.Header.CloseButton.TextStrokeColor3 = COLORS.BagLine
bagPanel.Header.CloseButton.TextStrokeTransparency = 0
local closeStroke = bagPanel.Header.CloseButton:FindFirstChildOfClass("UIStroke")
if closeStroke then
	closeStroke.Color = COLORS.BagLine
	closeStroke.Thickness = 3
end
local bagToolbar = Instance.new("Frame")
bagToolbar.Name = "Toolbar"
bagToolbar.BackgroundColor3 = COLORS.BagBack
bagToolbar.Position = UDim2.new(0, 12, 0, 86)
bagToolbar.Size = UDim2.new(0, 150, 1, -98)
bagToolbar.Parent = bagPanel
round(bagToolbar, 12)
outline(bagToolbar, COLORS.BagLine, 3)
local sortModes = { "Species", "Value", "Newest" }
local sortIndex = 1
local logsTab = button(bagToolbar, "LogsTab", "LOGS", UDim2.new(1, -20, 0, 64), UDim2.new(0, 10, 0, 12), COLORS.BagHeader)
logsTab.TextColor3 = COLORS.BagBack
logsTab.TextSize = 20
local axesTab = button(bagToolbar, "AxesTab", "AXES", UDim2.new(1, -20, 0, 64), UDim2.new(0, 10, 0, 86), COLORS.BagSlot)
axesTab.TextColor3 = COLORS.BagText
axesTab.TextSize = 20
local sortButton = button(bagToolbar, "SortButton", "SORT: WT", UDim2.new(1, -20, 0, 54), UDim2.new(0, 10, 0, 164), COLORS.BagSlot)
sortButton.TextSize = 16
sortButton.TextColor3 = COLORS.BagText
sortButton.Parent = bagPanel.Header
local bagCountLabel = label(bagToolbar, "Capacity", "— / — KG", UDim2.new(1, -20, 0, 60), UDim2.new(0, 10, 0, 230), 16, COLORS.BagText, Enum.Font.GothamBlack)
bagCountLabel.TextXAlignment = Enum.TextXAlignment.Center
bagCountLabel.TextYAlignment = Enum.TextYAlignment.Center
local infoButton = button(bagToolbar, "InfoButton", "INFO", UDim2.new(1, -20, 0, 50), UDim2.new(0, 10, 0, 298), COLORS.BagAction)
infoButton.TextSize = 16
infoButton.Visible = false
for _, control in ipairs({ logsTab, axesTab, sortButton }) do
	local controlCorner = control:FindFirstChildOfClass("UICorner")
	if controlCorner then controlCorner.CornerRadius = UDim.new(0, 8) end
	local controlStroke = control:FindFirstChildOfClass("UIStroke")
	if controlStroke then
		controlStroke.Color = COLORS.BagLine
		controlStroke.Thickness = 2
	end
	control.TextStrokeColor3 = COLORS.BagLine
	control.TextStrokeTransparency = 0
end

local bagBody = Instance.new("Frame")
bagBody.Name = "BagBody"
bagBody.BackgroundTransparency = 1
bagBody.Position = UDim2.new(0, 174, 0, 86)
bagBody.Size = UDim2.new(1, -186, 1, -98)
bagBody.Parent = bagPanel

local logGrid = Instance.new("ScrollingFrame")
logGrid.Name = "ItemGrid"
logGrid.BackgroundColor3 = COLORS.BagBack
logGrid.BorderSizePixel = 0
logGrid.ScrollBarThickness = 8
logGrid.ScrollBarImageColor3 = COLORS.BagMuted
logGrid.CanvasSize = UDim2.new()
logGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
logGrid.Parent = bagBody
round(logGrid, 10)
outline(logGrid, COLORS.BagLine, 3)

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 10)
gridPadding.PaddingBottom = UDim.new(0, 10)
gridPadding.PaddingLeft = UDim.new(0, 10)
gridPadding.PaddingRight = UDim.new(0, 10)
gridPadding.Parent = logGrid

local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.CellSize = UDim2.fromOffset(132, 132)
gridLayout.FillDirectionMaxCells = 4
gridLayout.Parent = logGrid

local emptyState = label(bagBody, "EmptyState", "", UDim2.new(1, 0, 1, 0), UDim2.new(), 18, COLORS.BagMuted, Enum.Font.GothamBlack)
emptyState.TextXAlignment = Enum.TextXAlignment.Center
emptyState.TextYAlignment = Enum.TextYAlignment.Center
emptyState.ZIndex = 3
emptyState.Visible = false

local detailPanel = Instance.new("Frame")
detailPanel.Name = "ItemDetails"
detailPanel.BackgroundColor3 = COLORS.BagSlot
detailPanel.Parent = bagBody
detailPanel.ClipsDescendants = true
round(detailPanel, 10)
outline(detailPanel, COLORS.BagLine, 3)

local infoOverlay = Instance.new("Frame")
infoOverlay.Name = "ItemInfoOverlay"
infoOverlay.Size = UDim2.fromScale(1, 1)
infoOverlay.BackgroundColor3 = Color3.fromRGB(9, 15, 12)
infoOverlay.BackgroundTransparency = 0.24
infoOverlay.Visible = false
infoOverlay.ZIndex = 8
infoOverlay.Parent = bagPanel

local detailPreview = Instance.new("Frame")
detailPreview.Name = "ItemPreview"
detailPreview.BackgroundColor3 = COLORS.BagPreview
detailPreview.Visible = false
detailPreview.Parent = detailPanel
round(detailPreview, 12)
outline(detailPreview, COLORS.BagLine, 3)

local detailIcon = label(detailPanel, "ItemIcon", "🪵", UDim2.new(0, 32, 1, 0), UDim2.new(0, 6, 0, 0), 20, COLORS.BagText, Enum.Font.GothamBold)
detailIcon.TextXAlignment = Enum.TextXAlignment.Center
detailIcon.ZIndex = 10
local detailLogVisual = makeLogIllustration(detailPreview, "LogVisual", 12)
detailLogVisual.Size = UDim2.fromScale(0.82, 0.5)
detailLogVisual.Visible = false
local detailSpecies = label(detailPanel, "Species", "NO LOG SELECTED", UDim2.new(1, -36, 0, 30), UDim2.new(0, 18, 0, 12), 23, COLORS.BagText, Enum.Font.GothamBlack)
detailSpecies.TextTruncate = Enum.TextTruncate.AtEnd
detailSpecies.TextStrokeColor3 = COLORS.BagLine
detailSpecies.TextStrokeTransparency = 0
detailSpecies.TextStrokeColor3 = COLORS.BagLine
detailSpecies.TextStrokeTransparency = 0
local detailStatus = label(detailPanel, "Status", "CHOOSE A SLOT", UDim2.new(1, -36, 0, 26), UDim2.new(0, 18, 0, 46), 16, COLORS.BagMuted, Enum.Font.GothamBold)
local detailMetricLabel = label(detailPanel, "MetricLabel", "VALUE", UDim2.new(1, -36, 0, 24), UDim2.new(0, 18, 0, 0), 16, COLORS.BagMuted, Enum.Font.GothamBlack)
local detailMetricValue = label(detailPanel, "MetricValue", "", UDim2.new(1, -36, 0, 40), UDim2.new(0, 18, 0, 0), 30, COLORS.BagAction, Enum.Font.GothamBlack)
detailMetricValue.TextXAlignment = Enum.TextXAlignment.Center
local detailValue = label(detailPanel, "Value", "", UDim2.new(), UDim2.new(), 1, COLORS.BagMuted)
detailValue.Visible = false
local detailSize = label(detailPanel, "Size", "", UDim2.new(), UDim2.new(), 1, COLORS.BagMuted)
detailSize.Visible = false
local detailExtraLabel = label(detailPanel, "ExtraStatsLabel", "OTHER STATS", UDim2.new(1, -36, 0, 24), UDim2.new(0, 18, 0, 0), 16, COLORS.BagText, Enum.Font.GothamBlack)
local detailExtraValue = label(detailPanel, "ExtraStatsValue", "Not configured yet", UDim2.new(1, -36, 0, 28), UDim2.new(0, 18, 0, 0), 16, COLORS.BagMuted, Enum.Font.GothamBold)
detailExtraLabel.Visible = false
detailExtraValue.Visible = false
local favoriteButton = button(detailPanel, "FavoriteButton", "LOCK", UDim2.new(0, 82, 0, 32), UDim2.new(1, -88, 0.5, -16), COLORS.BagHeader)
favoriteButton.TextSize = 18
favoriteButton.TextColor3 = COLORS.BagText
favoriteButton.TextStrokeColor3 = COLORS.BagLine
favoriteButton.TextStrokeTransparency = 0
local favoriteStroke = favoriteButton:FindFirstChildOfClass("UIStroke")
if favoriteStroke then
	favoriteStroke.Color = COLORS.BagLine
	favoriteStroke.Thickness = 3
end
favoriteButton.Visible = false
favoriteButton.Size = UDim2.new(1, -36, 0, 52)
favoriteButton.Position = UDim2.new(0, 18, 1, -64)
local infoCloseButton = button(detailPanel, "InfoCloseButton", "CLOSE", UDim2.new(1, -36, 0, 48), UDim2.new(0, 18, 1, -60), COLORS.BagClose)
infoCloseButton.TextSize = 18
infoCloseButton.TextColor3 = COLORS.BagText
infoCloseButton.Visible = false
detailPanel.ZIndex = 10
for _, descendant in ipairs(detailPanel:GetDescendants()) do
	if descendant:IsA("GuiObject") then descendant.ZIndex = 11 end
end

local function styleStationModal(panel, titleText, subtitleText)
	panel.Size = UDim2.new(0.94, 0, 0.9, 0)
	panel.BackgroundColor3 = COLORS.BagFrame
	for _, decoration in ipairs(panel:GetChildren()) do
		if decoration:IsA("UICorner") then
			decoration.CornerRadius = UDim.new(0, 16)
		elseif decoration:IsA("UIStroke") then
			decoration.Color = COLORS.BagLine
			decoration.Thickness = 5
		end
	end

	local header = panel.Header
	header.BackgroundColor3 = COLORS.BagHeader
	header.BackgroundTransparency = 0
	header.Position = UDim2.new(0, 9, 0, 8)
	header.Size = UDim2.new(1, -18, 0, 70)
	round(header, 12)
	outline(header, COLORS.BagLine, 3)

	header.Title.Text = titleText
	header.Title.Position = UDim2.new(0, 18, 0, 2)
	header.Title.Size = UDim2.new(1, -92, 0, 38)
	header.Title.Font = Enum.Font.GothamBlack
	header.Title.TextSize = 32
	header.Title.TextColor3 = COLORS.BagText
	header.Title.TextStrokeColor3 = COLORS.BagLine
	header.Title.TextStrokeTransparency = 0

	header.Subtitle.Text = subtitleText
	header.Subtitle.Position = UDim2.new(0, 20, 0, 40)
	header.Subtitle.Size = UDim2.new(1, -96, 0, 22)
	header.Subtitle.Font = Enum.Font.GothamBold
	header.Subtitle.TextSize = 15
	header.Subtitle.TextColor3 = COLORS.Ink
	header.Subtitle.TextStrokeColor3 = COLORS.BagLine
	header.Subtitle.TextStrokeTransparency = 0

	header.CloseButton.Position = UDim2.new(1, -58, 0, 10)
	header.CloseButton.Size = UDim2.fromOffset(48, 48)
	header.CloseButton.BackgroundColor3 = COLORS.BagClose
	header.CloseButton.TextColor3 = COLORS.BagText
	header.CloseButton.TextSize = 28
	header.CloseButton.TextStrokeColor3 = COLORS.BagLine
	header.CloseButton.TextStrokeTransparency = 0
	local closeStroke = header.CloseButton:FindFirstChildOfClass("UIStroke")
	if closeStroke then
		closeStroke.Color = COLORS.BagLine
		closeStroke.Thickness = 3
	end
end

local shopOverlay, shopPanel = makeModal(screen, "AxeShop", "AXE SHOP", "Buy a head component, then forge the finished axe.")
styleStationModal(shopPanel, "AXE SHOP", "BUY AN AXE HEAD • FORGE YOUR AXE SEPARATELY")
local shopNotice = label(shopPanel, "ShopNotice", "AXE HEADS • CRAFTING COMPONENTS ONLY", UDim2.new(1, -42, 0, 30), UDim2.new(0, 21, 0, 88), 18, COLORS.BagText, Enum.Font.GothamBlack)
shopNotice.TextStrokeColor3 = COLORS.BagLine
shopNotice.TextStrokeTransparency = 0
local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Position = UDim2.new(0, 20, 0, 124)
shopList.Size = UDim2.new(1, -40, 1, -144)
shopList.BackgroundColor3 = COLORS.BagBack
shopList.BackgroundTransparency = 0
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 8
shopList.ScrollBarImageColor3 = COLORS.BagMuted
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.CanvasSize = UDim2.new()
shopList.Parent = shopPanel
round(shopList, 12)
outline(shopList, COLORS.BagLine, 3)
local shopPadding = Instance.new("UIPadding")
shopPadding.PaddingTop = UDim.new(0, 12)
shopPadding.PaddingBottom = UDim.new(0, 12)
shopPadding.PaddingLeft = UDim.new(0, 12)
shopPadding.PaddingRight = UDim.new(0, 12)
shopPadding.Parent = shopList
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 12)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

local forgeOverlay, forgePanel = makeModal(screen, "AxeForge", "AXE FORGE", "Combine an owned axe head with eligible logs.")
styleStationModal(forgePanel, "AXE FORGE", "STANDARD AXES USE AN AXE HEAD AND UNLOCKED LOGS")
forgePanel.Size = UDim2.new(0.86, 0, 0.82, 0)
local forgeSizeConstraint = forgePanel:FindFirstChildOfClass("UISizeConstraint")
if forgeSizeConstraint then
	forgeSizeConstraint.MaxSize = Vector2.new(980, 700)
end
local forgeList = Instance.new("ScrollingFrame")
forgeList.Name = "RecipeList"
forgeList.Position = UDim2.new(0, 20, 0, 124)
forgeList.Size = UDim2.new(1, -40, 1, -144)
forgeList.BackgroundColor3 = COLORS.BagBack
forgeList.BackgroundTransparency = 0
forgeList.BorderSizePixel = 0
forgeList.ScrollBarThickness = 8
forgeList.ScrollBarImageColor3 = COLORS.BagMuted
forgeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
forgeList.CanvasSize = UDim2.new()
forgeList.Parent = forgePanel
round(forgeList, 12)
outline(forgeList, COLORS.BagLine, 3)
local forgePadding = Instance.new("UIPadding")
forgePadding.PaddingTop = UDim.new(0, 12)
forgePadding.PaddingBottom = UDim.new(0, 12)
forgePadding.PaddingLeft = UDim.new(0, 12)
forgePadding.PaddingRight = UDim.new(0, 12)
forgePadding.Parent = forgeList
local forgeLayout = Instance.new("UIListLayout")
forgeLayout.Padding = UDim.new(0, 12)
forgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
forgeLayout.Parent = forgeList
local forgeEmptyState = label(forgePanel, "ForgeEmptyState", "LOADING RECIPES...", UDim2.new(1, -60, 0, 80), UDim2.new(0, 30, 0, 124), 20, COLORS.BagMuted, Enum.Font.GothamBlack)
forgeEmptyState.TextXAlignment = Enum.TextXAlignment.Center
forgeEmptyState.ZIndex = 3
forgeEmptyState.Visible = true

local sellOverlay, sellPanel = makeModal(screen, "SellLogs", "SELL LOGS", "Cash out your ready logs for Coins.")
styleStationModal(sellPanel, "LUMBER DEPOT", "TURN READY LOGS INTO COINS")
local sellCard = Instance.new("Frame")
sellCard.Name = "SaleSummary"
sellCard.AnchorPoint = Vector2.new(0.5, 0.5)
sellCard.Position = UDim2.fromScale(0.5, 0.58)
sellCard.Size = UDim2.new(0.84, 0, 0, 320)
sellCard.BackgroundColor3 = COLORS.BagBack
sellCard.Parent = sellPanel
round(sellCard, 16)
outline(sellCard, COLORS.BagLine, 4)
local sellCardConstraint = Instance.new("UISizeConstraint")
sellCardConstraint.MinSize = Vector2.new(280, 300)
sellCardConstraint.MaxSize = Vector2.new(700, 360)
sellCardConstraint.Parent = sellCard
local sellIcon = label(sellCard, "Icon", "READY LOGS", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 0, 16), 22, COLORS.BagAction, Enum.Font.GothamBlack)
sellIcon.TextXAlignment = Enum.TextXAlignment.Center
sellIcon.TextStrokeColor3 = COLORS.BagLine
sellIcon.TextStrokeTransparency = 0
local sellCount = label(sellCard, "EligibleCount", "0 LOGS READY TO SELL", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 0, 58), 23, COLORS.BagText, Enum.Font.GothamBlack)
sellCount.TextXAlignment = Enum.TextXAlignment.Center
sellCount.TextStrokeColor3 = COLORS.BagLine
sellCount.TextStrokeTransparency = 0
local sellValue = label(sellCard, "TotalValue", "0 COINS", UDim2.new(1, -32, 0, 52), UDim2.new(0, 16, 0, 96), 38, COLORS.BagAction, Enum.Font.GothamBlack)
sellValue.TextXAlignment = Enum.TextXAlignment.Center
sellValue.TextStrokeColor3 = COLORS.BagLine
sellValue.TextStrokeTransparency = 0
local sellHint = label(sellCard, "LockHint", "LOCKED LOGS STAY SAFE IN YOUR BAG.", UDim2.new(1, -32, 0, 26), UDim2.new(0, 16, 0, 154), 15, COLORS.BagMuted, Enum.Font.GothamBold)
sellHint.TextXAlignment = Enum.TextXAlignment.Center
local sellButton = button(sellCard, "SellUnlockedButton", "SELL ALL", UDim2.new(1, -36, 0, 70), UDim2.new(0, 18, 1, -86), COLORS.BagAction)
sellButton.TextSize = 26
	sellButton.TextColor3 = COLORS.Ink
	sellButton.TextStrokeColor3 = COLORS.BagLine
	sellButton.TextStrokeTransparency = 0
round(sellButton, 14)
local sellStroke = sellButton:FindFirstChildOfClass("UIStroke")
if sellStroke then
	sellStroke.Color = COLORS.BagLine
	sellStroke.Thickness = 4
end
local sellPending = false
local sellEligibleCount = 0

local latestLogsData
local latestShopData
local selectedLogUid
local selectedAxeUid
local activeBagTab = "Logs"
local showingBagInfo = false
local bagWideLayout = false
local refreshShop
local isRefreshingLogs = false
local refreshLogsQueued = false
local saleCoinsBefore
local feedbackSequence = 0

local function getBagUiCapacity()
	local logsData = if type(latestLogsData) == "table" then latestLogsData else {}
	local shopData = if type(latestShopData) == "table" then latestShopData else {}
	local usedKg = validKg(shopData.UsedKg) or validKg(logsData.UsedKg)
	local carryCapacityKg = validKg(shopData.CarryCapacityKg) or validKg(logsData.CarryCapacityKg)
	local remainingKg = validKg(logsData.RemainingKg)
	if typeof(logsData.RemainingKg) == "number" and logsData.RemainingKg == logsData.RemainingKg
		and logsData.RemainingKg ~= math.huge and logsData.RemainingKg ~= -math.huge then
		remainingKg = math.max(0, logsData.RemainingKg)
	end
	if usedKg == nil and carryCapacityKg ~= nil and remainingKg ~= nil then
		usedKg = math.max(0, carryCapacityKg - remainingKg)
	end
	return usedKg, carryCapacityKg
end

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
	forgeOverlay.Visible = false
	sellOverlay.Visible = false
	showingBagInfo = false
	infoOverlay.Visible = false
end

local function showPanel(target)
	closeAllPanels()
	target.Visible = true
end

local function setBagLayout()
	local panelWidth = bagPanel.AbsoluteSize.X
	local panelHeight = bagPanel.AbsoluteSize.Y
	local railWidth = if panelWidth < 520 then 94 elseif panelWidth < 780 then 120 else 154
	bagPanel.Header.Title.Size = UDim2.new(1, -112, 1, 0)
	bagPanel.Header.Title.TextSize = if panelWidth < 520 then 26 else 36
	bagToolbar.Position = UDim2.new(0, 12, 0, 86)
	bagToolbar.Size = UDim2.new(0, railWidth, 1, -98)
	logsTab.Position = UDim2.new(0, 10, 0, 12)
	logsTab.Size = UDim2.new(1, -20, 0, if railWidth < 110 then 54 else 64)
	logsTab.TextSize = if railWidth < 110 then 16 else if railWidth < 140 then 18 else 20
	axesTab.Position = UDim2.new(0, 10, 0, if railWidth < 110 then 76 else 86)
	axesTab.Size = UDim2.new(1, -20, 0, if railWidth < 110 then 54 else 64)
	axesTab.TextSize = logsTab.TextSize
	local sortTop = if railWidth < 110 then 142 else 164
	sortButton.Position = UDim2.new(1, -202, 0.5, 0)
	sortButton.AnchorPoint = Vector2.new(0, 0.5)
	sortButton.Size = UDim2.fromOffset(132, 44)
	sortButton.TextSize = 16
	bagCountLabel.Position = UDim2.new(0, 10, 0, sortTop)
	bagCountLabel.Size = UDim2.new(1, -20, 0, 56)
	bagCountLabel.TextSize = if railWidth < 110 then 14 else 16
	infoButton.Position = UDim2.new(0, 10, 0, sortTop + 66)
	infoButton.Size = UDim2.new(1, -20, 0, if railWidth < 110 then 44 else 50)
	infoButton.TextSize = if railWidth < 110 then 14 else 16
	bagBody.Position = UDim2.new(0, railWidth + 24, 0, 86)
	bagBody.Size = UDim2.new(1, -(railWidth + 36), 1, -98)
	local width = math.max(0, panelWidth - railWidth - 36)
	local height = math.max(0, panelHeight - 98)
	bagWideLayout = width >= 760 and height >= 470
	infoButton.Visible = not bagWideLayout
	local gridWidth = width
	if bagWideLayout then
		if detailPanel.Parent ~= bagBody then detailPanel.Parent = bagBody end
		infoOverlay.Visible = false
		detailPanel.Visible = true
		local detailWidth = math.clamp(math.floor(width * 0.32), 290, 350)
		local gap = 14
		gridWidth = width - detailWidth - gap
		logGrid.Position = UDim2.new(0, 0, 0, 0)
		logGrid.Size = UDim2.new(0, gridWidth, 1, 0)
		emptyState.Position = UDim2.new(0, 0, 0, 0)
		emptyState.Size = UDim2.new(0, gridWidth, 1, 0)
		detailPanel.AnchorPoint = Vector2.zero
		detailPanel.Position = UDim2.new(0, gridWidth + gap, 0, 0)
		detailPanel.Size = UDim2.new(0, detailWidth, 1, 0)
		infoCloseButton.Visible = false
		detailPreview.Visible = true
		local previewSide = math.clamp(math.floor(math.min(detailWidth - 48, height * 0.29)), 112, 164)
		local previewTop = 94
		detailPreview.Position = UDim2.new(0.5, -previewSide / 2, 0, previewTop)
		detailPreview.Size = UDim2.fromOffset(previewSide, previewSide)
		detailSpecies.Position = UDim2.new(0, 18, 0, 12)
		detailSpecies.Size = UDim2.new(1, -36, 0, 34)
		detailSpecies.TextSize = 25
		detailSpecies.TextXAlignment = Enum.TextXAlignment.Center
		detailStatus.Position = UDim2.new(0, 18, 0, 50)
		detailStatus.Size = UDim2.new(1, -36, 0, 30)
		detailStatus.TextSize = 16
		detailStatus.TextXAlignment = Enum.TextXAlignment.Center
		detailIcon.Position = UDim2.new(0.5, -previewSide / 2, 0, previewTop)
		detailIcon.Size = UDim2.fromOffset(previewSide, previewSide)
		detailIcon.TextSize = math.floor(previewSide * 0.48)
		detailMetricLabel.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 8)
		detailMetricLabel.Size = UDim2.new(1, -36, 0, 24)
		detailMetricLabel.TextXAlignment = Enum.TextXAlignment.Center
		detailMetricLabel.TextSize = 16
		detailMetricValue.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 30)
		detailMetricValue.Size = UDim2.new(1, -36, 0, 42)
		detailMetricValue.TextSize = 30
		detailMetricValue.TextXAlignment = Enum.TextXAlignment.Center
		detailExtraLabel.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 78)
		detailExtraLabel.Size = UDim2.new(1, -36, 0, 24)
		detailExtraLabel.TextXAlignment = Enum.TextXAlignment.Center
		detailExtraLabel.TextSize = 16
		detailExtraValue.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 104)
		detailExtraValue.Size = UDim2.new(1, -36, 0, 44)
		detailExtraValue.TextXAlignment = Enum.TextXAlignment.Center
		detailExtraValue.TextSize = 16
		favoriteButton.Position = UDim2.new(0, 18, 1, -64)
		favoriteButton.Size = UDim2.new(1, -36, 0, 52)
		favoriteButton.TextSize = 18
	else
		if detailPanel.Parent ~= infoOverlay then detailPanel.Parent = infoOverlay end
		infoOverlay.Visible = showingBagInfo
		detailPanel.Visible = showingBagInfo
		detailPanel.AnchorPoint = Vector2.new(0.5, 0.5)
		detailPanel.Position = UDim2.fromScale(0.5, 0.5)
		detailPanel.Size = UDim2.new(0.86, 0, 0.86, 0)
		infoCloseButton.Visible = true
		detailPreview.Visible = true
		logGrid.Position = UDim2.new(0, 0, 0, 0)
		logGrid.Size = UDim2.fromScale(1, 1)
		emptyState.Position = UDim2.new(0, 0, 0, 0)
		emptyState.Size = UDim2.fromScale(1, 1)
		local detailWidth = math.max(220, math.floor(width * 0.86))
		local detailHeight = math.max(220, math.floor(height * 0.86))
		local previewSide = math.clamp(math.floor(math.min(detailWidth - 48, (detailHeight - 220) * 0.48)), 64, 142)
		local previewTop = 82
		detailSpecies.Position = UDim2.new(0, 18, 0, 10)
		detailSpecies.Size = UDim2.new(1, -36, 0, 32)
		detailSpecies.TextSize = if detailWidth < 310 then 20 else 24
		detailSpecies.TextXAlignment = Enum.TextXAlignment.Center
		detailStatus.Position = UDim2.new(0, 18, 0, 44)
		detailStatus.Size = UDim2.new(1, -36, 0, 28)
		detailStatus.TextSize = 16
		detailStatus.TextXAlignment = Enum.TextXAlignment.Center
		detailPreview.Position = UDim2.new(0.5, -previewSide / 2, 0, previewTop)
		detailPreview.Size = UDim2.fromOffset(previewSide, previewSide)
		detailIcon.Position = UDim2.new(0.5, -previewSide / 2, 0, previewTop)
		detailIcon.Size = UDim2.fromOffset(previewSide, previewSide)
		detailIcon.TextSize = math.floor(previewSide * 0.48)
		detailMetricLabel.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 6)
		detailMetricLabel.Size = UDim2.new(1, -36, 0, 22)
		detailMetricLabel.TextSize = 14
		detailMetricLabel.TextXAlignment = Enum.TextXAlignment.Center
		detailMetricValue.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 26)
		detailMetricValue.Size = UDim2.new(1, -36, 0, 36)
		detailMetricValue.TextSize = 26
		detailMetricValue.TextXAlignment = Enum.TextXAlignment.Center
		detailExtraLabel.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 66)
		detailExtraLabel.Size = UDim2.new(1, -36, 0, 22)
		detailExtraLabel.TextSize = 14
		detailExtraLabel.TextXAlignment = Enum.TextXAlignment.Center
		detailExtraValue.Position = UDim2.new(0, 18, 0, previewTop + previewSide + 88)
		detailExtraValue.Size = UDim2.new(1, -36, 0, 24)
		detailExtraValue.TextSize = 14
		detailExtraValue.TextXAlignment = Enum.TextXAlignment.Center
		favoriteButton.Position = UDim2.new(0, 18, 1, -116)
		favoriteButton.Size = UDim2.new(1, -36, 0, 48)
		favoriteButton.TextSize = 16
		infoCloseButton.Position = UDim2.new(0, 18, 1, -58)
		infoCloseButton.Size = UDim2.new(1, -36, 0, 46)
		infoCloseButton.TextSize = 16
	end
	local availableWidth = math.max(0, gridWidth - 20)
	local columns = if availableWidth >= 560 then 4 elseif availableWidth >= 360 then 3 elseif availableWidth >= 180 then 2 else 1
	local cellSide = math.clamp(math.floor((availableWidth - 10 * (columns - 1)) / columns), 82, 156)
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
	emptyState.TextColor3 = COLORS.BagText
	emptyState.TextStrokeColor3 = COLORS.BagLine
	emptyState.TextStrokeTransparency = 0
	emptyState.TextSize = 18
	emptyState.Visible = true
end

local function getLogValue(record)
	if type(record) ~= "table" then return nil end
	local value = tonumber(record.LogValue)
	if value == nil then value = tonumber(record.Value) end
	if value == nil then value = tonumber(record.EstimatedSellValue) end
	if value == nil or value ~= value or value == math.huge or value == -math.huge then return nil end
	return math.max(0, math.floor(value + 0.5))
end

local function sortedLogs(data)
	local logs = type(data.Logs) == "table" and table.clone(data.Logs) or {}
	local mode = sortModes[sortIndex]
	table.sort(logs, function(a, b)
		if mode == "Value" then
			local valueA = getLogValue(a)
			local valueB = getLogValue(b)
			if valueA ~= valueB then
				if valueA == nil then return false end
				if valueB == nil then return true end
				return valueA > valueB
			end
		elseif mode == "Species" then
			if a.SpeciesId ~= b.SpeciesId then return tostring(a.SpeciesId or "") < tostring(b.SpeciesId or "") end
		elseif mode == "Newest" then
			if a.CreatedAt ~= b.CreatedAt then return (a.CreatedAt or 0) > (b.CreatedAt or 0) end
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

local function updateBagTabs(usedKg, carryCapacityKg, axeCount)
	local logsActive = activeBagTab == "Logs"
	logsTab.BackgroundColor3 = if logsActive then COLORS.BagAction else COLORS.BagSlot
	logsTab.TextColor3 = COLORS.BagText
	axesTab.BackgroundColor3 = if not logsActive then COLORS.BagAction else COLORS.BagSlot
	axesTab.TextColor3 = COLORS.BagText
	bagCountLabel.Visible = logsActive
	bagCountLabel.Text = formatCapacitySummary(usedKg, carryCapacityKg)
	bagCountLabel.TextColor3 = COLORS.BagMuted
	bagCountLabel.TextWrapped = false
	local sortLabels = { "A-Z", "VALUE", "NEWEST" }
	sortButton.Text = "SORT  " .. sortLabels[sortIndex]
	sortButton.Visible = logsActive and bagPanel.AbsoluteSize.X >= 680
end

local function renderLogDetail(record)
	local hasRecord = type(record) == "table"
	local value = if hasRecord then getLogValue(record) else nil
	local weightText = if hasRecord then formatKg(record.CapacityKg) else nil
	detailIcon.Visible = false
	detailLogVisual.Visible = hasRecord
	detailSpecies.Text = if hasRecord then tostring(record.SpeciesId or "Unknown") else "NO LOG SELECTED"
	detailMetricLabel.Text = "VALUE"
	detailMetricLabel.Visible = value ~= nil
	detailMetricValue.Text = if value ~= nil then formatCoins(value) .. " COINS" else ""
	detailMetricValue.Visible = value ~= nil
	detailMetricValue.TextColor3 = if value ~= nil then COLORS.BagAction else COLORS.BagMuted
	detailValue.Text = ""
	detailSize.Text = ""
	detailExtraLabel.Text = "WEIGHT"
	detailExtraValue.Text = weightText or ""
	detailExtraLabel.Visible = weightText ~= nil
	detailExtraValue.Visible = weightText ~= nil
	detailStatus.Text = if not hasRecord then "CHOOSE A LOG" elseif record.Locked == true then "LOCKED • SAFE FROM SELL ALL" else "SELECTED"
	detailStatus.TextColor3 = if hasRecord and record.Locked == true then COLORS.Gold else COLORS.BagMuted
	favoriteButton.Visible = hasRecord
	if not hasRecord then return end
	favoriteButton.Text = if record.Locked then "UNLOCK" else "LOCK"
	favoriteButton.BackgroundColor3 = COLORS.BagAction
	favoriteButton.TextColor3 = COLORS.Ink
	favoriteButton.TextStrokeColor3 = COLORS.BagLine
	favoriteButton.TextStrokeTransparency = 0
end

local function renderAxeDetail(axe)
	local hasAxe = type(axe) == "table"
	detailIcon.Visible = true
	detailLogVisual.Visible = false
	detailIcon.Text = "🪓"
	detailSpecies.Text = if hasAxe then tostring(axe.Name or "Axe") else "OWNED AXES"
	detailMetricLabel.Text = "POWER"
	detailMetricLabel.Visible = true
	detailMetricValue.Text = if hasAxe then tostring(axe.Power or 0) else "—"
	detailMetricValue.Visible = true
	detailMetricValue.TextColor3 = if hasAxe then COLORS.BagAction else COLORS.BagMuted
	detailStatus.Text = if not hasAxe then "NO OWNED AXES" elseif axe.Equipped then "EQUIPPED" else "TAP TO EQUIP"
	detailStatus.TextColor3 = if hasAxe and axe.Equipped then COLORS.BagAction else COLORS.BagMuted
	detailValue.Text = ""
	detailSize.Text = ""
	-- Keep the details panel deliberately spacious for real future axe stats;
	-- do not display invented or placeholder progression information.
	detailExtraLabel.Visible = false
	detailExtraValue.Visible = false
	favoriteButton.Visible = false
end

local function makeItemSlot(name, order, icon, title, metadata, isEquipped, isSelected, isLocked, onActivated)
	local slot = Instance.new("TextButton")
	slot.Name = name
	slot.LayoutOrder = order
	slot.BackgroundColor3 = if isEquipped then COLORS.BagAction elseif isSelected then COLORS.BagSelected else COLORS.BagSlot
	slot.Text = ""
	slot.AutoButtonColor = true
	slot.Parent = logGrid
	round(slot, 9)
	outline(slot, COLORS.BagLine, 3)
	local cellSide = gridLayout.CellSize.Y.Offset
	local iconHeight = math.clamp(math.floor(cellSide * 0.42), 30, 64)
	local nameY = iconHeight + 5
	local nameHeight = math.clamp(math.floor(cellSide * 0.2), 18, 28)
	if icon == "LOG" then
		local logVisual = makeLogIllustration(slot, "LogIcon", 2)
		logVisual.Position = UDim2.new(0.5, 0, 0, iconHeight * 0.5 + 3)
		logVisual.Size = UDim2.new(0.78, 0, 0, iconHeight)
	else
		local iconLabel = label(slot, "Icon", icon, UDim2.new(1, -8, 0, iconHeight), UDim2.new(0, 4, 0, 2), math.clamp(math.floor(iconHeight * 0.85), 24, 48), COLORS.BagText, Enum.Font.GothamBold)
		iconLabel.TextXAlignment = Enum.TextXAlignment.Center
		iconLabel.TextWrapped = false
		iconLabel.TextStrokeColor3 = COLORS.BagLine
		iconLabel.TextStrokeTransparency = 0
	end
	local nameLabel = label(slot, "Name", title, UDim2.new(1, -6, 0, nameHeight), UDim2.new(0, 3, 0, nameY), math.clamp(math.floor(cellSide * 0.13), 14, 19), COLORS.BagText, Enum.Font.GothamBlack)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextWrapped = false
	nameLabel.TextStrokeColor3 = COLORS.BagLine
	nameLabel.TextStrokeTransparency = 0
	local metadataLabel = label(slot, "Metadata", metadata, UDim2.new(1, -6, 0, 20), UDim2.new(0, 3, 1, -22), 14, COLORS.BagText, Enum.Font.GothamBold)
	metadataLabel.TextXAlignment = Enum.TextXAlignment.Center
	metadataLabel.TextTruncate = Enum.TextTruncate.AtEnd
	metadataLabel.TextWrapped = false
	metadataLabel.TextStrokeColor3 = COLORS.BagLine
	metadataLabel.TextStrokeTransparency = 0
	if isEquipped then
		local equippedMark = label(slot, "Equipped", "ON", UDim2.new(0, 36, 0, 18), UDim2.new(1, -38, 0, 2), 14, COLORS.BagAction, Enum.Font.GothamBlack)
		equippedMark.TextXAlignment = Enum.TextXAlignment.Right
		equippedMark.TextStrokeColor3 = COLORS.BagLine
		equippedMark.TextStrokeTransparency = 0
	elseif isLocked then
		local lockedMark = label(slot, "Locked", "LOCK", UDim2.new(0, 46, 0, 18), UDim2.new(0, 4, 0, 2), 14, COLORS.BagText, Enum.Font.GothamBlack)
		lockedMark.TextXAlignment = Enum.TextXAlignment.Left
		lockedMark.TextStrokeColor3 = COLORS.BagLine
		lockedMark.TextStrokeTransparency = 0
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
	local usedKg, carryCapacityKg = getBagUiCapacity()
	updateBagTabs(usedKg, carryCapacityKg, #axes)
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
	local usedKg, carryCapacityKg, remainingKg = getCapacitySnapshot(data, latestShopData and latestShopData.CarryCapacityKg)
	local coins = typeof(data.Coins) == "number" and data.Coins or 0
	hudCoins.Text = "🪙 " .. formatCoins(coins)
	hudLogs.Text = "🪵  BAG " .. formatCapacitySummary(usedKg, carryCapacityKg)
	local isFull = carryCapacityKg ~= nil and ((remainingKg ~= nil and remainingKg <= 0.0001)
		or (usedKg ~= nil and usedKg >= carryCapacityKg - 0.0001))
	local fullCapacityText = formatKg(carryCapacityKg)
	bagButton.Text = if isFull and fullCapacityText then "BAG FULL  •  " .. fullCapacityText else if isFull then "BAG FULL  •  M" else "OPEN BAG  •  M"
	bagButton.BackgroundColor3 = if isFull then COLORS.Orange else COLORS.Green
	if saleCoinsBefore then
		if coins > saleCoinsBefore then
			showFeedback("+" .. formatCoins(coins - saleCoinsBefore) .. " COINS!", COLORS.Gold)
		end
		saleCoinsBefore = nil
	end
	if not findSelectedLog(logs) then selectedLogUid = nil end
	updateBagTabs(usedKg, carryCapacityKg, #ownedAxes(latestShopData))
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
		local isSelected = record.UID == selectedLogUid
		local value = getLogValue(record)
		local valueText = if value ~= nil then formatCoins(value) .. " COINS" else ""
		makeItemSlot("LogSlot_" .. tostring(record.UID or index), index, "LOG", tostring(record.SpeciesId or "Log"), valueText, false, isSelected, record.Locked == true, function()
			if typeof(record.UID) ~= "string" then return end
			selectedLogUid = record.UID
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
		if child ~= shopLayout and child ~= shopPadding and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

local function renderShop(data)
	if type(data) ~= "table" then return end
	latestShopData = data
	local usedKg, carryCapacityKg = getBagUiCapacity()
	updateBagTabs(usedKg, carryCapacityKg, #ownedAxes(data))
	clearShopRows()
	hudCoins.Text = "🪙 " .. formatCoins(data.Coins or 0)
	local layoutOrder = 0
	local axeHeads = if type(data.AxeHeads) == "table" then data.AxeHeads else nil
	if not axeHeads or #axeHeads == 0 then
		layoutOrder += 1
		local emptyCard = Instance.new("Frame")
		emptyCard.Name = "AxeHeadUnavailable"
		emptyCard.LayoutOrder = layoutOrder
		emptyCard.Size = UDim2.new(1, -8, 0, 72)
		emptyCard.BackgroundColor3 = COLORS.BagSlot
		emptyCard.Parent = shopList
		round(emptyCard, 12)
		outline(emptyCard, COLORS.BagLine, 3)
		local emptyText = label(emptyCard, "Message", if axeHeads then "NO AXE HEADS AVAILABLE" else "AXE HEAD DATA UNAVAILABLE", UDim2.new(1, -24, 1, 0), UDim2.new(0, 12, 0, 0), 17, COLORS.BagMuted, Enum.Font.GothamBlack)
		emptyText.TextXAlignment = Enum.TextXAlignment.Center
	end
	for _, head in ipairs(axeHeads or {}) do
		if type(head) ~= "table" or typeof(head.Id) ~= "string" or #head.Id == 0 then
			continue
		end
		layoutOrder += 1
		local compactShopCards = shopList.AbsoluteSize.X < 620
		local card = Instance.new("Frame")
		card.Name = "AxeHeadCard_" .. head.Id
		card.LayoutOrder = layoutOrder
		card.Size = UDim2.new(1, -8, 0, compactShopCards and 166 or 118)
		card.BackgroundColor3 = layoutOrder % 2 == 0 and COLORS.BagPreview or COLORS.BagSlot
		card.Parent = shopList
		round(card, 12)
		outline(card, COLORS.BagLine, 3)
		local headIcon = Instance.new("Frame")
		headIcon.Name = "HeadIcon"
		headIcon.Position = if compactShopCards then UDim2.fromOffset(12, 10) else UDim2.new(0, 14, 0.5, -38)
		headIcon.Size = if compactShopCards then UDim2.fromOffset(64, 64) else UDim2.fromOffset(76, 76)
		headIcon.BackgroundColor3 = COLORS.BagHeader
		headIcon.Parent = card
		round(headIcon, 12)
		outline(headIcon, COLORS.BagLine, 3)
		local headIconText = label(headIcon, "ComponentLabel", "AXE\nHEAD", UDim2.fromScale(1, 1), UDim2.new(), 19, COLORS.BagText, Enum.Font.GothamBlack)
		headIconText.TextXAlignment = Enum.TextXAlignment.Center
		headIconText.TextStrokeColor3 = COLORS.BagLine
		headIconText.TextStrokeTransparency = 0
		local textLeft = if compactShopCards then 86 else 104
		local textWidth = if compactShopCards then UDim2.new(1, -textLeft - 12, 0, 32) else UDim2.new(0.54, -108, 0, 32)
		local name = label(card, "Name", tostring(head.Name or "Axe Head"), textWidth, UDim2.new(0, textLeft, 0, 8), 22, COLORS.BagText, Enum.Font.GothamBlack)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextStrokeColor3 = COLORS.BagLine
		name.TextStrokeTransparency = 0
		local countKnown = typeof(head.Count) == "number" and head.Count == head.Count
		local count = if countKnown then math.max(0, math.floor(head.Count)) else 0
		local componentNote = label(card, "ComponentNote", "COMPONENT ONLY • NO DAMAGE UNTIL FORGED", textWidth, UDim2.new(0, textLeft, 0, compactShopCards and 40 or 42), 13, COLORS.BagAction, Enum.Font.GothamBold)
		componentNote.TextTruncate = Enum.TextTruncate.AtEnd
		componentNote.TextWrapped = false
		local price = if typeof(head.Price) == "number" then head.Price else 0
		local priceLabel = label(card, "Price", "PRICE  " .. formatCoins(price) .. " COINS", textWidth, UDim2.new(0, textLeft, 0, compactShopCards and 60 or 64), 15, COLORS.BagText, Enum.Font.GothamBold)
		priceLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local owned = label(card, "OwnedCount", "OWNED  " .. tostring(count), textWidth, UDim2.new(0, textLeft, 0, compactShopCards and 80 or 84), 14, COLORS.BagMuted, Enum.Font.GothamBlack)
		owned.TextTruncate = Enum.TextTruncate.AtEnd
		local actionText
		local actionColor
		local canBuy = head.CanBuy == true and head.Available == true and countKnown and count == 0
		if count > 0 then
			actionText = "OWNED"
			actionColor = COLORS.Blue
		elseif head.Available ~= true then
			actionText = "LOCKED"
			actionColor = COLORS.Disabled
		else
			actionText = "BUY"
			actionColor = canBuy and COLORS.Gold or COLORS.Disabled
		end
		local actionSize = if compactShopCards then UDim2.new(1, -24, 0, 48) else UDim2.new(0.42, -16, 0, 66)
		local actionPosition = if compactShopCards then UDim2.new(0, 12, 1, -58) else UDim2.new(0.58, 0, 0.5, -33)
		local action = button(card, "BuyHead", actionText, actionSize, actionPosition, actionColor)
		action.TextSize = 17
		action.Active = canBuy
		action.AutoButtonColor = canBuy
		action.TextStrokeColor3 = COLORS.BagLine
		action.TextStrokeTransparency = 0
		round(action, 12)
		local actionStroke = action:FindFirstChildOfClass("UIStroke")
		if actionStroke then
			actionStroke.Color = COLORS.BagLine
			actionStroke.Thickness = 3
		end
		action.Activated:Connect(function()
			if not canBuy then return end
			purchaseAxeHead:FireServer(head.Id)
			task.delay(0.35, function()
				if shopOverlay.Visible then
					local ok, fresh = pcall(function() return getShopData:InvokeServer() end)
					if ok then renderShop(fresh) end
				end
			end)
		end)
	end

	layoutOrder += 1
	local heading = Instance.new("Frame")
	heading.Name = "CapacityHeading"
	heading.LayoutOrder = layoutOrder
	heading.Size = UDim2.new(1, -8, 0, 50)
	heading.BackgroundTransparency = 1
	heading.Parent = shopList
	local headingText = label(heading, "Text", "BAG CAPACITY  •  " .. (formatKg(carryCapacityKg) or "DATA UPDATING"), UDim2.new(1, 0, 1, 0), UDim2.new(), 20, COLORS.BagText, Enum.Font.GothamBlack)
	headingText.TextStrokeColor3 = COLORS.BagLine
	headingText.TextStrokeTransparency = 0

	local capacityUpgrades = if type(data.CapacityUpgrades) == "table" then data.CapacityUpgrades else {}
	local coins = validNonNegativeNumber(data.Coins) or 0
	for _, upgrade in ipairs(capacityUpgrades) do
		if type(upgrade) == "table" then
			local targetCapacityKg = validKg(upgrade.CapacityKg)
			if carryCapacityKg ~= nil and targetCapacityKg ~= nil and targetCapacityKg > carryCapacityKg then
				layoutOrder += 1
				local card = Instance.new("Frame")
				card.Name = "CapacityCard_" .. (formatKgNumber(targetCapacityKg) or "Unknown")
				card.LayoutOrder = layoutOrder
				card.Size = UDim2.new(1, -8, 0, 100)
				card.BackgroundColor3 = COLORS.BagSlot
				card.Parent = shopList
				round(card, 12)
				outline(card, COLORS.BagLine, 3)
				local upgradeText = label(card, "Upgrade", "CARRY " .. (formatKg(targetCapacityKg) or "— KG"), UDim2.new(0.52, -20, 1, 0), UDim2.new(0, 16, 0, 0), 20, COLORS.BagText, Enum.Font.GothamBlack)
				upgradeText.TextStrokeColor3 = COLORS.BagLine
				upgradeText.TextStrokeTransparency = 0
				local price = validNonNegativeNumber(upgrade.Price)
				local canPurchase = price ~= nil and coins >= price
				local action = button(card, "BuyCapacity", "UPGRADE  •  " .. formatCoins(price or 0), UDim2.new(0.45, -16, 0, 60), UDim2.new(0.55, 0, 0.5, -30), canPurchase and COLORS.BagAction or COLORS.Disabled)
				action.TextSize = 16
				action.Active = canPurchase
				action.AutoButtonColor = canPurchase
				action.TextStrokeColor3 = COLORS.BagLine
				action.TextStrokeTransparency = 0
				round(action, 12)
				local actionStroke = action:FindFirstChildOfClass("UIStroke")
				if actionStroke then
					actionStroke.Color = COLORS.BagLine
					actionStroke.Thickness = 3
				end
				action.Activated:Connect(function()
					if not canPurchase then return end
					purchaseCapacity:FireServer(targetCapacityKg)
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
	if bagOverlay.Visible and activeBagTab == "Axes" then renderAxes(data) end
end

local function clearForgeRows()
	for _, child in ipairs(forgeList:GetChildren()) do
		if child ~= forgeLayout and child ~= forgePadding and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

local function renderForge(data)
	clearForgeRows()
	if type(data) ~= "table" then
		forgeEmptyState.Text = "FORGE DATA UNAVAILABLE"
		forgeEmptyState.Visible = true
		return
	end

	if type(data.Recipes) ~= "table" then
		forgeEmptyState.Text = "RECIPE DATA UNAVAILABLE"
		forgeEmptyState.Visible = true
		return
	end
	local recipes = data.Recipes
	local renderedCount = 0
	for _, recipe in ipairs(recipes) do
		if type(recipe) ~= "table" or typeof(recipe.Id) ~= "string" or #recipe.Id == 0 then
			continue
		end
		renderedCount += 1
		local card = Instance.new("Frame")
		card.Name = "Recipe_" .. recipe.Id
		card.LayoutOrder = renderedCount
		card.Size = UDim2.new(1, -8, 0, 176)
		card.BackgroundColor3 = renderedCount % 2 == 0 and COLORS.BagPreview or COLORS.BagSlot
		card.Parent = forgeList
		round(card, 12)
		outline(card, COLORS.BagLine, 3)

		local axeName = label(card, "AxeName", tostring(recipe.Name or "Standard Axe"), UDim2.new(0.64, -16, 0, 34), UDim2.new(0, 16, 0, 10), 24, COLORS.BagText, Enum.Font.GothamBlack)
		axeName.TextTruncate = Enum.TextTruncate.AtEnd
		axeName.TextStrokeColor3 = COLORS.BagLine
		axeName.TextStrokeTransparency = 0

		local headOwned = if typeof(recipe.HeadOwned) == "number" then tostring(math.max(0, math.floor(recipe.HeadOwned))) else "?"
		local headRequired = if typeof(recipe.HeadRequired) == "number" then tostring(math.max(0, math.floor(recipe.HeadRequired))) else "?"
		local headLine = label(card, "HeadRequirement", "HEAD  " .. tostring(recipe.HeadName or recipe.HeadId or "Axe Head") .. "  •  " .. headOwned .. " / " .. headRequired, UDim2.new(0.64, -16, 0, 26), UDim2.new(0, 16, 0, 50), 17, COLORS.BagAction, Enum.Font.GothamBold)
		headLine.TextTruncate = Enum.TextTruncate.AtEnd
		headLine.TextWrapped = false
		headLine.TextStrokeColor3 = COLORS.BagLine
		headLine.TextStrokeTransparency = 0

		local woodOwned = if typeof(recipe.WoodOwned) == "number" then tostring(math.max(0, math.floor(recipe.WoodOwned))) else "?"
		local woodRequired = if typeof(recipe.WoodRequired) == "number" then tostring(math.max(0, math.floor(recipe.WoodRequired))) else "?"
		local woodLine = label(card, "WoodRequirement", "ELIGIBLE UNLOCKED LOGS  " .. tostring(recipe.WoodSpeciesId or "Wood") .. "  •  " .. woodOwned .. " / " .. woodRequired, UDim2.new(0.64, -16, 0, 26), UDim2.new(0, 16, 0, 80), 16, COLORS.BagText, Enum.Font.GothamBold)
		woodLine.TextTruncate = Enum.TextTruncate.AtEnd
		woodLine.TextWrapped = false
		woodLine.TextStrokeColor3 = COLORS.BagLine
		woodLine.TextStrokeTransparency = 0

		local hasMaterialSnapshot = typeof(recipe.Name) == "string"
			and #recipe.Name > 0
			and typeof(recipe.HeadId) == "string"
			and #recipe.HeadId > 0
			and typeof(recipe.HeadName) == "string"
			and #recipe.HeadName > 0
			and typeof(recipe.HeadOwned) == "number"
			and recipe.HeadOwned == recipe.HeadOwned
			and typeof(recipe.HeadRequired) == "number"
			and recipe.HeadRequired == recipe.HeadRequired
			and typeof(recipe.WoodSpeciesId) == "string"
			and #recipe.WoodSpeciesId > 0
			and typeof(recipe.WoodOwned) == "number"
			and recipe.WoodOwned == recipe.WoodOwned
			and typeof(recipe.WoodRequired) == "number"
			and recipe.WoodRequired == recipe.WoodRequired
		local canCraft = recipe.CanCraft == true
			and recipe.Unlocked == true
			and recipe.AtNextTier == true
			and recipe.AtForge == true
			and recipe.OutputOwned == false
			and hasMaterialSnapshot
		local statusText
		local statusColor
		if recipe.OutputOwned == true then
			statusText, statusColor = "ALREADY CRAFTED", COLORS.Blue
		elseif recipe.Unlocked == false then
			statusText, statusColor = "FOREST LOCKED", COLORS.Orange
		elseif recipe.AtNextTier == false then
			statusText, statusColor = "CRAFT THE PREVIOUS AXE FIRST", COLORS.Orange
		elseif recipe.AtForge == false then
			statusText, statusColor = "RETURN TO THE FORGE", COLORS.Orange
		elseif canCraft then
			statusText, statusColor = "READY TO CRAFT", COLORS.BagAction
		else
			statusText, statusColor = "MISSING REQUIRED HEAD OR ELIGIBLE LOGS", COLORS.BagMuted
		end
		local status = label(card, "Availability", statusText, UDim2.new(0.64, -16, 0, 30), UDim2.new(0, 16, 0, 112), 15, statusColor, Enum.Font.GothamBlack)
		status.TextTruncate = Enum.TextTruncate.AtEnd
		status.TextWrapped = false
		status.TextStrokeColor3 = COLORS.BagLine
		status.TextStrokeTransparency = 0

		local actionText = if canCraft then "CRAFT AXE" else if recipe.OutputOwned == true then "CRAFTED" else if recipe.Unlocked == false then "LOCKED" else "NOT READY"
		local action = button(card, "Craft", actionText, UDim2.new(0.32, -16, 0, 72), UDim2.new(0.68, 0, 0.5, -36), canCraft and COLORS.BagAction or COLORS.Disabled)
		action.TextSize = 18
		action.Active = canCraft
		action.AutoButtonColor = canCraft
		action.TextStrokeColor3 = COLORS.BagLine
		action.TextStrokeTransparency = 0
		local actionStroke = action:FindFirstChildOfClass("UIStroke")
		if actionStroke then
			actionStroke.Color = COLORS.BagLine
			actionStroke.Thickness = 3
		end
		action.Activated:Connect(function()
			if not canCraft then return end
			craftRecipe:FireServer(recipe.Id)
			action.Text = "CRAFTING..."
			action.Active = false
			action.AutoButtonColor = false
			task.delay(0.35, function()
				if forgeOverlay.Visible then refreshShop() end
			end)
		end)
	end
	forgeEmptyState.Text = if renderedCount > 0 then "" else "NO STANDARD RECIPES AVAILABLE"
	forgeEmptyState.Visible = renderedCount == 0
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
		if ok then
			renderShop(data)
			renderForge(data)
		elseif forgeOverlay.Visible then
			renderForge(nil)
		end
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
		sellButton.BackgroundColor3 = if count > 0 then COLORS.BagAction else COLORS.Disabled
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

local function openForge()
	showPanel(forgeOverlay)
	refreshShop()
end

local function openLumberDepot()
	showPanel(sellOverlay)
	refreshSellSummary()
end

bagButton.Activated:Connect(openBag)
logsTab.Activated:Connect(function()
	activeBagTab = "Logs"
	showingBagInfo = false
	infoOverlay.Visible = false
	if latestLogsData then renderLogs(latestLogsData) else refreshLogs() end
end)
axesTab.Activated:Connect(function()
	activeBagTab = "Axes"
	showingBagInfo = false
	infoOverlay.Visible = false
	if latestShopData then renderAxes(latestShopData) else renderAxes(nil) end
	if not latestShopData then refreshShop() end
end)
infoButton.Activated:Connect(function()
	if bagWideLayout or not bagOverlay.Visible then return end
	showingBagInfo = true
	setBagLayout()
	if activeBagTab == "Axes" then renderAxes(latestShopData) elseif latestLogsData then renderLogs(latestLogsData) end
end)
infoCloseButton.Activated:Connect(function()
	showingBagInfo = false
	infoOverlay.Visible = false
	detailPanel.Visible = false
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
	if forgeOverlay.Visible then refreshShop() end
	if bagOverlay.Visible and activeBagTab == "Axes" then refreshShop() end
end)

local legacyEconomyUpdated = economy:FindFirstChild("EconomyUpdated")
if legacyEconomyUpdated then
	legacyEconomyUpdated.OnClientEvent:Connect(function(currency)
		if currency == "Coins" or currency == "Progression" then
			refreshLogs()
			if shopOverlay.Visible or forgeOverlay.Visible or (bagOverlay.Visible and activeBagTab == "Axes") then refreshShop() end
			if sellOverlay.Visible then refreshSellSummary() end
		end
	end)
end

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
bindStationPrompt("ForgeStation", "ForgePrompt", openForge)
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
		elseif forgeOverlay.Visible and not isNearStation("ForgeStation") then
			forgeOverlay.Visible = false
			showFeedback("RETURN TO THE FORGE", COLORS.Orange)
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
	if forgeOverlay.Visible then refreshShop() end
	if bagOverlay.Visible then refreshShop() end
end)
if player:GetAttribute("ProfileReady") then refreshLogs() end
