local Players = game:GetService("Players")
local ChopEvent = game.ReplicatedStorage.Chop.ChopEvent
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local DamageService = require(game.ServerStorage.DamageService)

local MAX_CHOP_DISTANCE = 16
local MIN_CHOP_INTERVAL = 0.3
local lastChop = {}

local function hasEquippedAxe(player, profile)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or not tool:GetAttribute("EquippedAxe") then return false end
	local uid = profile.Data.Equipped.Weapon
	local weapon = uid and profile.Data.Runtime.Weapon[uid]
	return weapon ~= nil and weapon.ItemType == "Weapon" and tool.Name == weapon.InstanceName
end

ChopEvent.OnServerEvent:Connect(function(player, targetCandidate)
	local now = os.clock()
	if now - (lastChop[player] or -math.huge) < MIN_CHOP_INTERVAL then return end
	lastChop[player] = now

	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data.Runtime then return end
	if not hasEquippedAxe(player, profile) then return end

	-- The client only nominates an Instance it aimed at. Resolution and every
	-- meaningful validation remain server-owned.
	local tree = TreeObject.GetTreeFromTarget(targetCandidate)
	if not tree then return end
	if not tree:CanChop(player) then return end
	if not tree:IsPlayerWithinChopDistance(player, MAX_CHOP_DISTANCE) then return end
	if not WorldProgressService.CanInteractWithTree(player, tree) then return end

	local stats = profile.Data.Runtime.FinalStats
	local attack = stats and stats.Attack
	if type(attack) ~= "number" or attack ~= attack or attack <= 0 or attack == math.huge then return end
	local weaponUID = profile.Data.Equipped.Weapon
	local context = DamageService:createDamageContext(player, tree, weaponUID, stats)
	local _, calculated = DamageService.Calculate(context)
	tree:TakeDamage(calculated, player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastChop[player] = nil
end)
