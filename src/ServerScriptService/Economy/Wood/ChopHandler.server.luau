local Players = game:GetService("Players")
local ChopEvent = game.ReplicatedStorage.Chop.ChopEvent
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local DamageService = require(game.ServerStorage.DamageService)

local DEBUG_PRO_AXE_DAMAGE = true
local DEBUG_PRO_AXE_ATTACK = 10000
local DEBUG_PRO_PLAYER_NAME = "ForsakenDemonz"

local MIN_CHOP_INTERVAL = 0.3
local lastChop = {}
local debugProUserIds = {}

if DEBUG_PRO_AXE_DAMAGE then
	task.spawn(function()
		local ok, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(DEBUG_PRO_PLAYER_NAME)
		end)

		if ok and type(userId) == "number" and userId > 0 and userId % 1 == 0 then
			debugProUserIds[userId] = true
		end
	end)
end

local function hasEquippedAxe(player, profile)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or not tool:GetAttribute("EquippedAxe") then return false end
	local uid = profile.Data.Equipped.Weapon
	local weapon = uid and profile.Data.Runtime.Weapon[uid]
	return weapon ~= nil and weapon.ItemType == "Weapon" and tool.Name == weapon.InstanceName
end

ChopEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastChop[player] or -math.huge) < MIN_CHOP_INTERVAL then return end
	lastChop[player] = now

	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data.Runtime then return end
	if not hasEquippedAxe(player, profile) then return end

	-- This request deliberately has no target payload. The server resolves the
	-- closest eligible registered tree from its own interaction geometry, so a
	-- client cannot nominate a model, HP, damage value, or reward target.
	local tree = TreeObject.GetBestChopTarget(player, function(candidate)
		return candidate:CanChop(player)
			and WorldProgressService.CanInteractWithTree(player, candidate)
	end)
	if not tree then return end

	local stats = profile.Data.Runtime.FinalStats
	local attack = stats and stats.Attack
	if type(attack) ~= "number" or attack ~= attack or attack <= 0 or attack == math.huge then return end

	local damageStats = stats
	if DEBUG_PRO_AXE_DAMAGE and debugProUserIds[player.UserId] then
		damageStats = table.clone(stats)
		damageStats.Attack = math.max(attack, DEBUG_PRO_AXE_ATTACK)
	end

	local weaponUID = profile.Data.Equipped.Weapon
	local lumberjackStrength = profile.Data.LumberjackStrength
	local context = DamageService:createDamageContext(player, tree, weaponUID, damageStats, nil, lumberjackStrength)
	local _, calculated = DamageService.Calculate(context)
	tree:TakeDamage(calculated, player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastChop[player] = nil
end)
