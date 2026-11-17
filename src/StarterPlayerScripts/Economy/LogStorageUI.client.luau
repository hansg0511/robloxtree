-- Prototype management UI for two separate persistent unique-log inventories.
-- All transfers and auto-keep settings are revalidated by LogService server.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Economy")
local getLogs = remotes:WaitForChild("GetLogsDataRF")
local updated = remotes:WaitForChild("EconomyStateUpdated")
local transfer = remotes:WaitForChild("TransferLogRE")
local keepRules = remotes:WaitForChild("UpdateAutoKeepRE")
local processingFX = remotes:WaitForChild("LogProcessingFXRE")
local PAGE_SIZE = 24
local THRESHOLDS = { 1.2, 1.4, 1.5, 1.6, 1.8, 2.0, 2.5 }

local colors = {
	Back = Color3.fromRGB(17, 27, 35),
	Panel = Color3.fromRGB(28, 49, 60),
	Row = Color3.fromRGB(39, 68, 78),
	Line = Color3.fromRGB(99, 159, 166),
	Accent = Color3.fromRGB(104, 204, 136),
	Text = Color3.fromRGB(252, 248, 219),
	Gold = Color3.fromRGB(255, 204, 83),
}

local function rounded(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = frame
end

local function label(parent, text, position, size, fontSize, color)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text
	item.Font = Enum.Font.GothamBold
	item.TextSize = fontSize or 17
	item.TextColor3 = color or colors.Text
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Position = position
	item.Size = size
	item.Parent = parent
	return item
end

local function button(parent, text, position, size, accent)
	local item = Instance.new("TextButton")
	item.Text = text
	item.Font = Enum.Font.GothamBold
	item.TextSize = 16
	item.TextColor3 = colors.Text
	item.BackgroundColor3 = accent or colors.Row
	item.Position = position
	item.Size = size
	item.AutoButtonColor = true
	item.Parent = parent
	rounded(item, 9)
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "LogStorageUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = button(gui, "STORAGE  N", UDim2.new(1, -180, 0, 18), UDim2.fromOffset(158, 46), colors.Panel)
local noticeToast = label(gui, "", UDim2.new(0.5, -260, 0, 75), UDim2.fromOffset(520, 45), 17, colors.Gold)
noticeToast.Name = "StorageToast"
noticeToast.BackgroundTransparency = 0.1
noticeToast.BackgroundColor3 = colors.Back
noticeToast.TextXAlignment = Enum.TextXAlignment.Center
noticeToast.TextWrapped = true
noticeToast.Visible = false
rounded(noticeToast, 9)

local overlay = Instance.new("Frame")
overlay.Name = "StorageOverlay"
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.Size = UDim2.fromScale(1, 1)
overlay.Visible = false
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "StoragePanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.92, 0, 0.86, 0)
panel.BackgroundColor3 = colors.Back
panel.Parent = overlay
rounded(panel, 16)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(940, 720)
limit.MinSize = Vector2.new(380, 340)
limit.Parent = panel

local heading = label(panel, "CRAFTING LOG STORAGE", UDim2.fromOffset(22, 16), UDim2.new(1, -95, 0, 44), 26, colors.Gold)
local close = button(panel, "X", UDim2.new(1, -62, 0, 17), UDim2.fromOffset(42, 42), Color3.fromRGB(144, 62, 62))
local storedTab = button(panel, "SAVED LOGS", UDim2.fromOffset(22, 73), UDim2.fromOffset(150, 44))
local bagTab = button(panel, "CARRY BAG", UDim2.fromOffset(185, 73), UDim2.fromOffset(150, 44))
local countLabel = label(panel, "", UDim2.fromOffset(348, 76), UDim2.new(1, -368, 0, 39), 15)
countLabel.TextXAlignment = Enum.TextXAlignment.Right

local keepMutated = button(panel, "KEEP MUTATIONS", UDim2.fromOffset(22, 130), UDim2.new(0.31, -24, 0, 46))
local keepLarge = button(panel, "KEEP LARGE", UDim2.new(0.34, 2, 0, 130), UDim2.new(0.31, -24, 0, 46))
local minSize = button(panel, "MIN SIZE", UDim2.new(0.66, 2, 0, 130), UDim2.new(0.34, -24, 0, 46))
local rulesNote = label(panel, "Auto-keep applies to newly picked-up logs. Storage does not use bag capacity.",
	UDim2.fromOffset(22, 179), UDim2.new(1, -44, 0, 25), 13, colors.Line)
local search = Instance.new("TextBox")
search.Name = "LogSearch"
search.PlaceholderText = "Search species or mutation..."
search.Text = ""
search.Font = Enum.Font.Gotham
search.TextSize = 17
search.TextColor3 = colors.Text
search.PlaceholderColor3 = colors.Line
search.BackgroundColor3 = colors.Panel
search.Size = UDim2.new(1, -44, 0, 42)
search.Position = UDim2.fromOffset(22, 210)
search.ClearTextOnFocus = false
search.Parent = panel
rounded(search, 9)

local list = Instance.new("ScrollingFrame")
list.Name = "LogRows"
list.BackgroundColor3 = colors.Panel
list.BorderSizePixel = 0
list.ScrollBarThickness = 7
list.ScrollBarImageColor3 = colors.Line
list.Position = UDim2.fromOffset(22, 264)
list.Size = UDim2.new(1, -44, 1, -340)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
rounded(list, 10)

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = list
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local previous = button(panel, "PREV", UDim2.fromOffset(22, 0), UDim2.fromOffset(94, 40))
previous.AnchorPoint = Vector2.new(0, 1)
previous.Position = UDim2.new(0, 22, 1, -17)
local pageLabel = label(panel, "", UDim2.new(0.5, -90, 1, -55), UDim2.fromOffset(180, 34), 17)
pageLabel.TextXAlignment = Enum.TextXAlignment.Center
local nextPage = button(panel, "NEXT", UDim2.new(1, -116, 1, -57), UDim2.fromOffset(94, 40))

local state
local activeTab = "Storage"
local currentPage = 1
local refreshPending = false
local function mutationText(mutations)
	local result = {}
	if type(mutations) == "table" then
		for name, enabled in pairs(mutations) do
			if type(name) == "string" and enabled ~= false and enabled ~= 0 then
				table.insert(result, name)
			end
		end
	end
	table.sort(result)
	return if #result > 0 then table.concat(result, ", ") else "Normal"
end

local function render()
	if type(state) ~= "table" then return end
	local prefs = state.AutoKeep or {}
	keepMutated.Text = "MUTATED: " .. (if prefs.Mutations == true then "ON" else "OFF")
	keepLarge.Text = "LARGE: " .. (if prefs.Oversized == true then "ON" else "OFF")
	minSize.Text = string.format("SIZE >= %.1fx", tonumber(prefs.SizeThreshold) or 1.5)
	keepMutated.BackgroundColor3 = if prefs.Mutations == true then colors.Accent else colors.Row
	keepLarge.BackgroundColor3 = if prefs.Oversized == true then colors.Accent else colors.Row
	storedTab.BackgroundColor3 = if activeTab == "Storage" then colors.Accent else colors.Row
	bagTab.BackgroundColor3 = if activeTab == "Bag" then colors.Accent else colors.Row

	local source = if activeTab == "Storage" then state.StoredLogs else state.Logs
	local query = string.lower(search.Text)
	local results = {}
	if type(source) == "table" then
		for _, record in ipairs(source) do
			if type(record) == "table" and type(record.UID) == "string" then
				local keywords = string.lower(tostring(record.SpeciesId) .. " " .. mutationText(record.Mutations))
				if query == "" or string.find(keywords, query, 1, true) then
					table.insert(results, record)
				end
			end
		end
	end
	table.sort(results, function(a, b)
		if (a.SizeScale or 1) ~= (b.SizeScale or 1) then
			return (a.SizeScale or 1) > (b.SizeScale or 1)
		end
		return tostring(a.UID) < tostring(b.UID)
	end)

	local pages = math.max(1, math.ceil(#results / PAGE_SIZE))
	currentPage = math.clamp(currentPage, 1, pages)
	pageLabel.Text = string.format("%d / %d", currentPage, pages)
	countLabel.Text = if activeTab == "Storage"
		then string.format("%d / %d SAVED", tonumber(state.StorageCount) or 0, tonumber(state.StorageCapacity) or 240)
		else string.format("%.1f / %.1f KG CARRIED", tonumber(state.UsedKg) or 0, tonumber(state.CarryCapacityKg) or 10)

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local from = (currentPage - 1) * PAGE_SIZE + 1
	for index = from, math.min(#results, from + PAGE_SIZE - 1) do
		local record = results[index]
		local row = Instance.new("Frame")
		row.Name = "UID_" .. record.UID
		row.BackgroundColor3 = colors.Row
		row.Size = UDim2.new(1, -16, 0, 65)
		row.LayoutOrder = index
		row.Parent = list
		rounded(row, 7)

		local origin = if record.SourceType == "Grove" then "GROVE" else "WILD"
		local description = string.format("%s  |  SIZE %.2fx  |  %s  |  %s",
			tostring(record.SpeciesId), tonumber(record.SizeScale) or 1, mutationText(record.Mutations), origin)
		label(row, description, UDim2.fromOffset(12, 5), UDim2.new(1, -130, 0, 27), 16)
		local detail = string.format("UID %s   •   ~%d coins", string.sub(record.UID, 1, 8), tonumber(record.LogValue) or 0)
		label(row, detail, UDim2.fromOffset(12, 31), UDim2.new(1, -130, 0, 25), 12, colors.Line)
		local destination = if activeTab == "Storage" then "Bag" else "Storage"
		local action = button(row, if destination == "Bag" then "TO BAG" else "SAVE",
			UDim2.new(1, -112, 0, 12), UDim2.fromOffset(98, 40),
			if destination == "Storage" then colors.Accent else colors.Panel)
		action.Activated:Connect(function()
			action.Active = false
			action.Text = "MOVING..."
			transfer:FireServer(record.UID, destination)
			task.delay(0.45, function()
				if action.Parent then
					action.Active = true
					action.Text = if destination == "Bag" then "TO BAG" else "SAVE"
				end
			end)
		end)
	end
	if #results == 0 then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, -16, 0, 55)
		empty.Parent = list
		label(empty, "NO MATCHING LOGS", UDim2.fromOffset(15, 8), UDim2.new(1, -30, 0, 32), 17, colors.Line)
	end
end

local function refresh()
	if refreshPending then return end
	refreshPending = true
	task.spawn(function()
		local ok, snapshot = pcall(function() return getLogs:InvokeServer() end)
		refreshPending = false
		if ok and type(snapshot) == "table" then
			state = snapshot
			if overlay.Visible then render() end
		end
	end)
end

local function show()
	overlay.Visible = true
	currentPage = 1
	refresh()
	if state then render() end
end

openButton.Activated:Connect(function()
	if overlay.Visible then overlay.Visible = false else show() end
end)
close.Activated:Connect(function() overlay.Visible = false end)
storedTab.Activated:Connect(function()
	activeTab = "Storage"
	currentPage = 1
	render()
end)
bagTab.Activated:Connect(function()
	activeTab = "Bag"
	currentPage = 1
	render()
end)
search:GetPropertyChangedSignal("Text"):Connect(function()
	currentPage = 1
	if overlay.Visible then render() end
end)
previous.Activated:Connect(function()
	currentPage -= 1
	render()
end)
nextPage.Activated:Connect(function()
	currentPage += 1
	render()
end)

local function changePreference(field)
	if not state or type(state.AutoKeep) ~= "table" then return end
	local prefs = state.AutoKeep
	local mutated = prefs.Mutations == true
	local oversized = prefs.Oversized == true
	local threshold = tonumber(prefs.SizeThreshold) or 1.5
	if field == "Mutations" then mutated = not mutated end
	if field == "Oversized" then oversized = not oversized end
	if field == "Threshold" then
		local nextIndex = 1
		for index, value in ipairs(THRESHOLDS) do
			if math.abs(value - threshold) < 0.001 then
				nextIndex = index % #THRESHOLDS + 1
				break
			end
		end
		threshold = THRESHOLDS[nextIndex]
	end
	keepRules:FireServer(mutated, oversized, threshold)
end
keepMutated.Activated:Connect(function() changePreference("Mutations") end)
keepLarge.Activated:Connect(function() changePreference("Oversized") end)
minSize.Activated:Connect(function() changePreference("Threshold") end)

local noticeRevision = 0
processingFX.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or payload.Mode ~= "StorageNotice"
		or type(payload.Message) ~= "string" then return end
	noticeRevision += 1
	local currentRevision = noticeRevision
	rulesNote.TextColor3 = colors.Gold
	rulesNote.Text = payload.Message
	noticeToast.Text = payload.Message
	noticeToast.Visible = true
	task.delay(4, function()
		if noticeRevision ~= currentRevision then return end
		rulesNote.Text = "Auto-keep applies to new pickups. Saved logs never use bag capacity."
		rulesNote.TextColor3 = colors.Line
		noticeToast.Visible = false
	end)
end)

updated.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) ~= "table" then return end
	state = snapshot
	if overlay.Visible then render() end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.N then
		if overlay.Visible then overlay.Visible = false else show() end
	elseif input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
		overlay.Visible = false
	end
end)
local profileLoaded = ReplicatedStorage:WaitForChild("Profile"):WaitForChild("ProfileLoadEvent")
profileLoaded.OnClientEvent:Connect(refresh)
if player:GetAttribute("ProfileReady") then refresh() end
