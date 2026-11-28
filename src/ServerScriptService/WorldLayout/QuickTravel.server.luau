-- Free convenience travel within the current server. Requests contain only
-- a destination ID; never accept a client-supplied CFrame or target player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Configuration = require(script.Parent.WorldLayoutConfiguration)
local Profiles = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local WorldProgress = require(game.ServerScriptService.WorldProgressService)
local remote = ReplicatedStorage:WaitForChild("Economy"):WaitForChild("QuickTravelRE")

local COOLDOWN = 2
local lastRequest = {}

local function resolveDestination(id)
	local world = Workspace:FindFirstChild(Configuration.ROOT_NAME)
	if not world or world:GetAttribute("WorldLayoutOwned") ~= true then return nil end
	if id == "Sell" then
		local station = world:FindFirstChild("HomeEconomyStation")
		if not station or station:GetAttribute("WorldLayoutOwned") ~= true then return nil end
		-- Front of the existing processor, inside its normal use distance.
		local position = Configuration.HOME_ECONOMY_STATION.Position + Vector3.new(0, 4, -9)
		return CFrame.lookAt(position, position + Vector3.zAxis)
	elseif id == "ForestStart" then
		local forests = world:FindFirstChild("Forests")
		if not forests or not forests:FindFirstChild("StarterForest") then return nil end
		for _, forest in ipairs(Configuration.FORESTS) do
			if forest.ForestId == "Forest1" then
				local center = forest.GroundCenter
				local direction = if forest.ApproachFrom == "North" then -1 else 1
				-- Middle of the unobstructed approach lane, just before the
				-- first entrance frame. Never jump over a progression gate.
				local position = Vector3.new(center.X, Configuration.PATH_SURFACE_Y + 4,
					center.Z - direction * (forest.GroundSize.Z * 0.5 - 3))
				return CFrame.lookAt(position, position + Vector3.new(0, 0, direction))
			end
		end
	end
	return nil
end

remote.OnServerEvent:Connect(function(player, id, ...)
	if select("#", ...) ~= 0 or (id ~= "Sell" and id ~= "ForestStart") then return end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < COOLDOWN then return end
	lastRequest[player] = now
	if player.Parent ~= Players or not Profiles.GetProfile(player) then return end
	if id == "ForestStart" and not WorldProgress.CanAccessForest(player, "Forest1") then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart
		or not root or not root:IsA("BasePart") or not character:IsDescendantOf(Workspace) then return end
	local target = resolveDestination(id)
	if not target then return end

	-- Preserve root-to-model pivot offset for both avatar layouts. Existing
	-- carried records and pending pickups are left to their normal lifecycle.
	local rootToPivot = root.CFrame:ToObjectSpace(character:GetPivot())
	character:PivotTo(target * rootToPivot)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)
