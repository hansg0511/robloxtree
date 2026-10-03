-- Server-side distance checks for interactions that must happen at a specific
-- base station. A client-side prompt only opens the matching interface; remotes
-- still call these checks before making a state change.
local Workspace = game:GetService("Workspace")

local BaseStationAccess = {}

local MAX_DISTANCE = 14

local function getStationInteraction(stationName)
	local sourceWorld = Workspace:FindFirstChild("SourceWorld")
	local station = sourceWorld and sourceWorld:FindFirstChild(stationName)
	if not station or station:GetAttribute("WorldLayoutOwned") ~= true then return nil end

	local interaction = station:FindFirstChild("Interaction")
	if not interaction or not interaction:IsA("BasePart")
		or interaction:GetAttribute("WorldLayoutOwned") ~= true then
		return nil
	end
	-- The default is deliberately server-side. Individual source-built stations
	-- may tighten or widen it through their configuration without trusting a
	-- client prompt's activation distance.
	local useDistance = station:GetAttribute("UseDistance") or station:GetAttribute("SellDistance") or MAX_DISTANCE
	if type(useDistance) ~= "number" or useDistance ~= useDistance or useDistance <= 0 then
		useDistance = MAX_DISTANCE
	end
	return interaction, math.min(useDistance, MAX_DISTANCE)
end

local function canUseStation(player, stationName)
	if not player or not player:IsDescendantOf(game:GetService("Players")) then return false end
	local interaction, useDistance = getStationInteraction(stationName)
	if not interaction then return false end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return false end

	local localPosition = interaction.CFrame:PointToObjectSpace(root.Position)
	local halfSize = interaction.Size * 0.5
	local nearestPoint = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	return (root.Position - interaction.CFrame:PointToWorldSpace(nearestPoint)).Magnitude <= useDistance
end

function BaseStationAccess.CanUseAxeShop(player)
	return canUseStation(player, "AxeShopStation")
end

function BaseStationAccess.CanUseLumberDepot(player)
	return canUseStation(player, "HomeEconomyStation")
end

return BaseStationAccess
