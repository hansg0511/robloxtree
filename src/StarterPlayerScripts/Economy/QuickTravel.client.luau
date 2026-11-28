-- Two compact shortcuts below the economy HUD. All movement is performed by
-- the server; neither control modifies coins, inventory or forest access.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("QuickTravelRE")

local screen = Instance.new("ScreenGui")
screen.Name = "QuickTravelGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
-- Keep below modal economy/planting/storage interfaces.
screen.DisplayOrder = 18
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local row = Instance.new("Frame")
row.Name = "TravelButtons"
row.Position = UDim2.fromOffset(12, 70)
row.Size = UDim2.new(0.94, 0, 0, 42)
row.BackgroundTransparency = 1
row.Parent = screen

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(340, 42)
sizeLimit.Parent = row
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = row

local lastRequest = -math.huge
local function makeButton(id, text, color, order)
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.new(0.5, -3, 1, 0)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeColor3 = Color3.fromRGB(7, 10, 8)
	button.TextStrokeTransparency = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextWrapped = true
	button.Text = text
	button.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Parent = button
	button.Activated:Connect(function()
		local now = os.clock()
		if now - lastRequest < 2 then return end
		lastRequest = now
		remote:FireServer(id)
	end)
end

makeButton("Sell", "TELEPORT TO SELL", Color3.fromRGB(223, 164, 43), 1)
makeButton("ForestStart", "FOREST START", Color3.fromRGB(65, 172, 86), 2)
