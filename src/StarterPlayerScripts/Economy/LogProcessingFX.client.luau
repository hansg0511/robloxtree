-- Cosmetic only. Server commits stored ownership/coin payouts first.
-- Visuals use a bounded number of locally spawned parts; never send inputs back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("LogProcessingFXRE")
local MAX_VISIBLE_PER_SALE = 20
local activeParts = 0
local MAX_ACTIVE = 36

local COLORS = {
	Oak = Color3.fromRGB(171, 114, 61),
	Bamboo = Color3.fromRGB(115, 166, 80),
	Ironwood = Color3.fromRGB(105, 119, 134),
}

local function createLog(source, speciesId)
	if activeParts >= MAX_ACTIVE or typeof(source) ~= "CFrame" then return nil end
	local log = Instance.new("Part")
	log.Name = "CosmeticFlyingLog"
	log.Size = Vector3.new(0.7, 0.7, 1.6)
	log.Material = Enum.Material.Wood
	log.Color = COLORS[speciesId] or COLORS.Oak
	log.Anchored = true
	log.CanCollide = false
	log.CanTouch = false
	log.CanQuery = false
	log.CastShadow = false
	log.CFrame = source
	log.Parent = workspace
	activeParts += 1
	Debris:AddItem(log, 4)
	return log
end

local function fly(log, midpoint, destination, pause)
	if not log then return end
	task.spawn(function()
		if pause and pause > 0 then task.wait(pause) end
		if not log.Parent then return end
		local first = TweenService:Create(log, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = midpoint,
		})
		first:Play()
		first.Completed:Wait()
		if log.Parent then
			local finish = TweenService:Create(log, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = destination,
				Transparency = 1,
				Size = Vector3.new(0.15, 0.15, 0.3),
			})
			finish:Play()
			finish.Completed:Wait()
		end
		if log.Parent then log:Destroy() end
		activeParts = math.max(0, activeParts - 1)
	end)
end

local function processorIntake()
	local sourceWorld = workspace:FindFirstChild("SourceWorld")
	local station = sourceWorld and sourceWorld:FindFirstChild("HomeEconomyStation")
	local intake = station and station:FindFirstChild("ProcessorIntake")
	return if intake and intake:IsA("BasePart") then intake else nil
end

local function showSale(payload)
	if type(payload.Sold) ~= "table" then return end
	local intake = processorIntake()
	local owner = Players:GetPlayerByUserId(payload.OwnerUserId)
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not intake or not root then return end
	if player ~= owner then
		local localCharacter = player.Character
		local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
		if not localRoot or (localRoot.Position - root.Position).Magnitude > 130 then return end
	end

	local total = math.min(#payload.Sold, 96)
	if total < 1 then return end
	local visible = math.min(total, MAX_VISIBLE_PER_SALE)
	for i = 1, visible do
		local record = payload.Sold[i]
		if type(record) == "table" then
			-- Cargo remains authoritative; these are temporary replicas flying
			-- out of the player's back and into the processor's dark intake.
			local x = ((i - 1) % 4 - 1.5) * 0.5
			local y = math.floor((i - 1) / 4) * 0.33
			local source = root.CFrame * CFrame.new(x, 1.2 + y, 1.3)
			local destination = intake.CFrame * CFrame.new(0, 0, -0.05)
			local midpoint = CFrame.new((source.Position + destination.Position) / 2 + Vector3.new(0, 3.5, 0))
			local log = createLog(source, record.SpeciesId)
			fly(log, midpoint, destination, (i - 1) * 0.045)
		end
	end
end

local function showStoredPickup(payload)
	if typeof(payload.SourceCFrame) ~= "CFrame" then return end
	local owner = Players:GetPlayerByUserId(payload.OwnerUserId)
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		and (player.Character.HumanoidRootPart.Position - root.Position).Magnitude > 130 then return end

	local source = payload.SourceCFrame
	local destination = root.CFrame * CFrame.new(0, 2.5, 0)
	local midpoint = CFrame.new((source.Position + destination.Position) / 2 + Vector3.new(0, 2.2, 0))
	fly(createLog(source, payload.SpeciesId), midpoint, destination, 0)
end

remote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.Mode == "ProcessSale" then
		showSale(payload)
	elseif payload.Mode == "StoragePickup" then
		showStoredPickup(payload)
	end
end)
