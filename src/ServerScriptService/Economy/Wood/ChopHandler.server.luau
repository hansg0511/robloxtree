local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ChopEvent = game.ReplicatedStorage.Chop.ChopEvent
local profileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local TreeObject = require(game.ServerScriptService.Trees.TreeObject)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local DamageService = require(game.ServerStorage.DamageService)
local WeaponEffects = require(game.ServerScriptService.WeaponEffects.Dispatcher)
local WeaponProgressionService = require(game.ServerScriptService.WeaponProgressionService)
local Fervor = require(game.ServerScriptService.WeaponEffects.Fervor)
local Thunderstrike = require(game.ServerScriptService.WeaponEffects.Thunderstrike)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local EconomyUpdated = game.ReplicatedStorage.Economy.EconomyUpdated

local MIN_CHOP_INTERVAL = 0.3
-- A Fervor weapon can accelerate below the legacy base interval; other
-- weapons keep the unchanged 0.3-second minimum.
local MIN_FERVOR_CHOP_INTERVAL = 0.16
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
	local weaponUID = runtime.EquippedWeaponUID
	local now = os.clock()
	local fervorParams = WeaponEffects.GetParams(data, "Fervor")
	if fervorParams then
		interval = math.max(MIN_FERVOR_CHOP_INTERVAL,
			Fervor.Interval(player, weaponUID, tree, now, interval, fervorParams))
	end
	local previousChopAt = lastChop[player]
	if now - (previousChopAt or -math.huge) < interval then return end
	lastChop[player] = now
	local isMutationPracticeTree = RunService:IsStudio()
		and tree.model ~= nil and tree.model:GetAttribute("MutationCombatDummy") == true

	local stats = profile.Data.Runtime.FinalStats
	local attack = stats and stats.Attack
	if type(attack) ~= "number" or attack ~= attack or attack <= 0 or attack == math.huge then return end

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
			Tree = target,
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
		WeaponUID = weaponUID,
		PrimarySucceeded = false,
		OnMutationTelemetry = if isMutationPracticeTree then function(effectId, state)
			if effectId == "Thunderstrike" and type(state) == "table" then
				print(string.format(
					"[MutationPractice] THUNDERSTRIKE %d/%d%s | weapon %s",
					state.Count, state.EveryHits,
					if state.Proc then " PROC!" else "",
					weaponUID))
			end
		end else nil,
		EligibleSecondary = function(candidate)
			return candidate:CanChop(player)
				and WorldProgressService.CanInteractWithTree(player, candidate)
		end,
	}
	local preparedEffects = WeaponEffects.Prepare("OnHit", data, effectContext)
	-- Preserve the existing Studio-only Cleave experiment. All new mutation
	-- abilities are server-authoritative and may run in published gameplay.
	if not RunService:IsStudio() then
		for index = #preparedEffects, 1, -1 do
			if preparedEffects[index].Id == "Cleave" then
				table.remove(preparedEffects, index)
			end
		end
	end

	-- Normal attack remains single-target; only confirmed hits emit effects.
	local primaryMaxHP = tree.MaxHP
	local hit, actualDamage, killed = tree:TakeDamage(calculated, player)
	if not hit then return end
	recordHit(tree, actualDamage, killed, primaryMaxHP)
	effectContext.PrimarySucceeded = true
	if fervorParams then
		local stacks = Fervor.RecordHit(player, weaponUID, tree, now, fervorParams)
		if isMutationPracticeTree then
			print(string.format(
				"[MutationPractice] FERVOR stacks=%d/%d | allowed interval=%.3fs | actual gap=%s",
				stacks, fervorParams.MaxStacks, interval,
				if previousChopAt then string.format("%.3fs", now - previousChopAt) else "first hit"))
		end
	end
	local secondaryHits = WeaponEffects.ApplyPrepared(preparedEffects, effectContext)
	if RunService:IsStudio() then
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
	-- Golden Touch awards server-owned kill gold after actual primary and
	-- registered secondary damage. Each TreeObject can die only once.
	if WeaponEffects.GetParams(data, "GoldenTouch") then
		local coinsDelta = 0
		for _, record in ipairs(hitRecords) do
			if record.Killed == true and type(record.Tree) == "table" then
				local species = record.Tree.SpeciesId
				local base = MaterialDefinitions.GetSellValue(species)
				if type(base) == "number" and base > 0 then
					WeaponEffects.ApplyTrigger("OnKill", data, {
						Killed = true,
						TreeCoinBase = base,
						AwardCoins = function(amount)
							if type(amount) == "number" and amount >= 1
								and amount <= 50000 and amount % 1 == 0 then
								coinsDelta += amount
							end
						end,
					})
				end
			end
		end
		if coinsDelta > 0 then
			local coins = profile.Data.Coins
			if type(coins) == "number" and coins == coins
				and coins >= 0 and coins < 1e12 then
				profile.Data.Coins = math.min(1e12, coins + coinsDelta)
				EconomyUpdated:FireClient(player, "Coins", profile.Data.Coins)
				EconomyUpdated:FireClient(player, "MutationProc", {
					Id = "GoldenTouch", Amount = coinsDelta,
				})
			end
		end
	end
	-- No client-reported hit/XP values. XP comes exclusively from trusted,
	-- HP-clamped TreeObject outcomes for the equipped weapon UID.
	WeaponProgressionService.AwardHits(player, weaponUID, hitRecords)
end)

Players.PlayerRemoving:Connect(function(player)
	lastChop[player] = nil
	Fervor.Clear(player)
	Thunderstrike.Clear(player)
end)
