local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local damageTemplate = ReplicatedStorage.GuiTemplates:WaitForChild("DamageGui")
local healthBarTemplate = ReplicatedStorage.GuiTemplates:WaitForChild("HealthBarGui")

local RunService = game:GetService("RunService")
-- Listen to damage events from DamageService
local camera = workspace.CurrentCamera

local faceCameraParts = {} -- [Part] = true

RunService.RenderStepped:Connect(function()
	local camPos = workspace.CurrentCamera.CFrame.Position

	for part in pairs(faceCameraParts) do
		if part.Parent then
			part.CFrame = CFrame.new(
				part.Position,
				camPos
			)
		else
			faceCameraParts[part] = nil
		end
	end
end)

local function registerFaceCamera(part)
	faceCameraParts[part] = true
end

local function unregisterFaceCamera(part)
	faceCameraParts[part] = nil
end




local DamageEvent = ReplicatedStorage:WaitForChild("DamageEvent")
local Debris = game:GetService("Debris")


local function displayDamage(amount, target, isCrit)
	local damagePart = damageTemplate:Clone().RootPart

	damagePart.Position = target:GetPivot().Position
		+ Vector3.new(
			math.random(-15,15)/10,
			math.random(0,10)/10 + 5,
			math.random(-15,15)/10
		)

	if isCrit then
		damagePart.SurfaceGui.TextLabel.TextColor3 = Color3.fromRGB(170, 0, 0)
		damagePart.SurfaceGui.TextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		damagePart.SurfaceGui.TextLabel.TextSize = 150
	else
		damagePart.SurfaceGui.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		damagePart.SurfaceGui.TextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		damagePart.SurfaceGui.TextLabel.TextSize = 120
	end

	damagePart.Parent = workspace

	damagePart.SurfaceGui.TextLabel.Text = tostring(amount)

	registerFaceCamera(damagePart) -- 🔥 preferred
	-- faceCameraRenderStepped(damagePart) -- alt

	TweenService:Create(
		damagePart,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad),
		{ Position = damagePart.Position + Vector3.new(0,2,0) }
	):Play()

	local tween = TweenService:Create(
		damagePart.SurfaceGui.TextLabel,
		TweenInfo.new(0.8),
		{ TextTransparency = 1 }
	):Play()
	
	
	Debris:AddItem(damagePart, 1)
	
end

local bars = {}

local function GetOrCreateHealthBar(target, maxHP)
	if bars[target] then
		return bars[target]
	end

	local part = healthBarTemplate:Clone().RootPart


	local bar = {
		part = part,
		fill = part.SurfaceGui.Fill,
		fill2 = part.SurfaceGui.Fill2,
		target = target,
		lastSeen = os.clock(),
		label = part.SurfaceGui.HealthLabel,
		lastHP = maxHP
	}

	bars[target] = bar

	return bar
end

local function UpdateHealthBar(target, hp, maxHP)
	local bar = GetOrCreateHealthBar(target, maxHP)

	bar.lastSeen = os.clock()
	local newRatio = hp / maxHP
	local oldRatio = bar.lastHP / maxHP
	
	bar.lastHP = hp
	
	bar.fill.Size = UDim2.fromScale(newRatio, 1)

	-- Damage taken
	if newRatio < oldRatio then
		bar.fill2.Size = UDim2.fromScale(oldRatio, 1)

		TweenService:Create(
			bar.fill2,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad),
			{ Size = UDim2.fromScale(newRatio, 1) }
		):Play()
	end

	-- Position above tree
	bar.part.Position =
		target:GetPivot().Position + Vector3.new(0, 10, 0)
	
	bar.label.Text = hp .. "/" .. maxHP
	
	bar.lastHP = hp
	
	bar.part.Parent = workspace -- SHOW
	registerFaceCamera(bar.part)
	
	-- Auto-remove after 3 seconds
end

task.spawn(function()
	while true do
		local now = os.clock()

		for model, bar in pairs(bars) do
			if not model.Parent then
				bar.part:Destroy()
				bars[model] = nil
			elseif now - bar.lastSeen > 3 then
				bar.part.Parent = nil -- HIDE
			end
		end

		task.wait(0.5)
	end
end)

DamageEvent.OnClientEvent:Connect(function(damageContext)
	local amount = damageContext.Damage
	local target = damageContext.Target
	local isCrit = damageContext.IsCrit
	displayDamage(amount, target, isCrit)
	local hp = damageContext.HP
	local MaxHP = damageContext.MaxHP
	UpdateHealthBar(target, hp, MaxHP)
end)







