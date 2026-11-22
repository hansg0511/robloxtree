local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ChopEvent = game.ReplicatedStorage.Chop.ChopEvent
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local DamageService = require(game.ServerStorage.DamageService)
local WeaponEffects = require(game.ServerScriptService.WeaponEffects.Dispatcher)
local WeaponProgressionService = require(game.ServerScriptService.WeaponProgressionService)

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

	-- Collect actual HP removed for this single verified swing. Commit XP
	-- only after the primary hit and all allowed secondary effects have run;
	-- that prevents level-up stat growth from affecting this same swing.
	local hitRecords = {}
	local function recordHit(target, applied, killed, maxHPBeforeHit)
		if #hitRecords >= 9 or type(target) ~= "table" then return end
		local maxHP = maxHPBeforeHit or target.MaxHP
		if type(maxHP) ~= "number" or maxHP ~= maxHP or maxHP <= 0
			or maxHP == math.huge or type(applied) ~= "number"
			or applied ~= applied or applied <= 0 or applied > maxHP then return end
		hitRecords[#hitRecords + 1] = {
			AppliedDamage = applied,
			TreeMaxHP = maxHP,
			Killed = killed == true,
		}
	end

	-- Class/mutation/skill origin is encoded in server-owned WeaponData.Effects.
	-- ChopHandler knows only the OnHit trigger, not individual effect types.
	-- Prepare before the primary strike because killing it may unregister it.
	local effectContext = {
		OnAppliedHit = recordHit,
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
	local primaryMaxHP = tree.MaxHP
	local hit, actualDamage, killed = tree:TakeDamage(calculated, player)
	if not hit then return end
	recordHit(tree, actualDamage, killed, primaryMaxHP)
	if RunService:IsStudio() then
		local secondaryHits = WeaponEffects.ApplyPrepared(preparedEffects, effectContext)
		-- Avoid noisy output in normal forests; this is a dedicated Studio
		-- test-zone trace for differentiating "no Cleave" vs "no neighbors".
		if tree.Parent and tree.Parent.Name == "CleaveTestPatch" then
			local cleaveState
			for _, effect in ipairs(preparedEffects) do
				if effect.Id == "Cleave" then
					cleaveState = effect.State
					break
				end
			end
			if cleaveState then
				print(string.format(
					"[CleaveTest] radius=%.2f studs, preparedTargets=%d, secondaryHits=%d, primaryDamage=%.0f",
					cleaveState.Profile.Radius, #(cleaveState.Targets or {}),
					secondaryHits, calculated.Damage
				))
			else
				print("[CleaveTest] Equipped weapon has no validated Cleave effect. Forge/equip a new experimental Battlehammer.")
			end
		end
	end
	-- No client-reported hit/XP values. XP comes exclusively from trusted,
	-- HP-clamped TreeObject outcomes for the equipped weapon UID.
	WeaponProgressionService.AwardHits(player, weaponUID, hitRecords)
end)

Players.PlayerRemoving:Connect(function(player)
	lastChop[player] = nil
end)
