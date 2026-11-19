local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ChopEvent = game.ReplicatedStorage.Chop.ChopEvent
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local DamageService = require(game.ServerStorage.DamageService)
local WeaponEffects = require(game.ServerScriptService.WeaponEffects.Dispatcher)

local MIN_CHOP_INTERVAL = 0.3
local lastChop = {}

local function hasEquippedAxe(player, profile)
	local weapon, uid = WorldProgressService.GetEquippedRuntimeWeapon(player)
	local runtime = profile.Data.Runtime
	return weapon ~= nil
		and uid == runtime.EquippedWeaponUID
		and runtime.Weapon[uid] == weapon
end

ChopEvent.OnServerEvent:Connect(function(player)
	local profile = profileCache.GetProfile(player)
	if not profile or not profile.Data.Runtime then return end
	if not hasEquippedAxe(player, profile) then return end

	-- Experimental classes have separately rolled attack speeds. Enforce the
	-- real interval on the server; replicated Tool attributes are visual only.
	-- Existing axes retain the original 0.3-second minimum.
	local runtime = profile.Data.Runtime
	local equipped = runtime.Weapon[runtime.EquippedWeaponUID]
	local data = equipped and equipped.WeaponData
	local rate = type(data) == "table" and data.AttacksPerSecond
	local interval = MIN_CHOP_INTERVAL
	if type(rate) == "number" and rate == rate
		and rate > 0 and rate < math.huge
		and data.ExperimentalClass ~= nil then
		interval = math.max(MIN_CHOP_INTERVAL, 1 / math.clamp(rate, 0.1, 10))
	end
	local now = os.clock()
	if now - (lastChop[player] or -math.huge) < interval then return end
	lastChop[player] = now

	-- This request deliberately has no target payload. The server resolves the
	-- closest eligible registered tree from its own interaction geometry, so a
	-- client cannot nominate a model, HP, damage value, or reward target.
	local reach = if type(data) == "table" and data.ExperimentalClass ~= nil
		then data.Reach else nil
	if type(reach) ~= "number" or reach ~= reach
		or reach <= 0 or reach == math.huge then
		reach = 1
	end
	-- Relative to the already-authored per-tree interaction region; clamped
	-- in TreeObject, and still resolves exactly one server-selected target.
	local tree = TreeObject.GetBestChopTarget(player, function(candidate)
		return candidate:CanChop(player)
			and WorldProgressService.CanInteractWithTree(player, candidate)
	end, reach)
	if not tree then return end

	local stats = profile.Data.Runtime.FinalStats
	local attack = stats and stats.Attack
	if type(attack) ~= "number" or attack ~= attack or attack <= 0 or attack == math.huge then return end

	local weaponUID = profile.Data.Runtime.EquippedWeaponUID
	local lumberjackStrength = profile.Data.LumberjackStrength
	local context = DamageService:createDamageContext(player, tree, weaponUID, stats, nil, lumberjackStrength)
	local _, calculated = DamageService.Calculate(context)

	-- Class/mutation/skill origin is encoded in server-owned WeaponData.Effects.
	-- ChopHandler knows only the OnHit trigger, not individual effect types.
	-- Prepare before the primary strike because killing it may unregister it.
	local effectContext = {
		Player = player,
		PrimaryTree = tree,
		ActiveTrees = TreeObject.ActiveTrees,
		PrimaryDamage = calculated.Damage,
		EligibleSecondary = function(candidate)
			return candidate:CanChop(player)
				and WorldProgressService.CanInteractWithTree(player, candidate)
		end,
	}
	local preparedEffects = if RunService:IsStudio()
		then WeaponEffects.Prepare("OnHit", data, effectContext) else {}

	-- Normal attack remains single-target; only confirmed hits emit effects.
	if not tree:TakeDamage(calculated, player) then return end
	if RunService:IsStudio() then
		WeaponEffects.ApplyPrepared(preparedEffects, effectContext)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastChop[player] = nil
end)
