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
local Rampage = require(game.ServerScriptService.WeaponEffects.Rampage)
local GoldenRush = require(game.ServerScriptService.WeaponEffects.GoldenRush)
local Bloodrush = require(game.ServerScriptService.WeaponEffects.Bloodrush)
local MaterialDefinitions = require(game.ServerScriptService.Economy.MaterialDefinitions)
local EconomyUpdated = game.ReplicatedStorage.Economy.EconomyUpdated

local TweenService = game:GetService("TweenService")
local MIN_CHOP_INTERVAL = 0.3
local Passives = require(game.ServerScriptService.PassiveStats)
local PUNCH_INTERVAL = 0.4
local PUNCH_DAMAGE = 15 -- Seven hits on a representative 1.3x Sapwood tree.
local PUNCH_REACH = 0.85

-- R6 procedural jab, using replicated Motor6D offsets rather than an
-- invented/unpublished animation asset. The original shoulder pose is
-- restored before another punch; combat authority is independent of FX.
local activePunch = setmetatable({}, { __mode = "k" })
local function playPunch(character)
	local torso = character:FindFirstChild("Torso")
	local shoulder = torso and torso:FindFirstChild("Right Shoulder")
	if not shoulder or not shoulder:IsA("Motor6D") then return end

	-- Preserve the actual rest offset even if a previous delayed tween has
	-- not completed. An old callback may not overwrite the newer pose.
	local previous = activePunch[shoulder]
	local original = previous and previous.Original or shoulder.C0
	if previous and previous.Tween then previous.Tween:Cancel() end
	shoulder.C0 = original
	local state = { Original = original }
	activePunch[shoulder] = state
	local jab = CFrame.new(original.Position) * CFrame.Angles(math.rad(95), 0, 0)
		* original.Rotation
	state.Tween = TweenService:Create(shoulder, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = jab })
	state.Tween:Play()
	task.delay(0.1, function()
		if activePunch[shoulder] ~= state or not shoulder:IsDescendantOf(character) then return end
		state.Tween = TweenService:Create(shoulder, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { C0 = original })
		state.Tween:Play()
		task.delay(0.18, function()
			if activePunch[shoulder] ~= state then return end
			if shoulder:IsDescendantOf(character) then shoulder.C0 = original end
			activePunch[shoulder] = nil
		end)
	end)
end
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
	local bonuses = Passives.ForPlayer(player, profile.Data, os.time())
	local hasteMultiplier = 1 + bonuses.Haste
	if not hasEquippedAxe(player, profile) then
		-- Fail closed when a weapon is recorded but its runtime Tool is absent.
		-- A missing/unequipped existing axe is not a way to bypass combat gates.
		local runtime = profile.Data.Runtime
		local savedEquipment = profile.Data.Equipped
		if runtime.EquippedWeaponUID ~= nil
			or (type(savedEquipment) == "table" and savedEquipment.Weapon ~= nil) then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart
			or not root or not character:IsDescendantOf(workspace)
			or character:FindFirstChildOfClass("Tool") then return end
		local now = os.clock()
		if now - (lastChop[player] or -math.huge) < math.max(MIN_FERVOR_CHOP_INTERVAL, PUNCH_INTERVAL / hasteMultiplier) then return end
		lastChop[player] = now

		-- Only the lightweight public starter resources are punchable.
		-- Use the existing range, first-hit claim and world-access rules.
		local tree = TreeObject.GetBestChopTarget(player, function(candidate)
			return candidate.ForestId == "Forest1"
				and (candidate.DefinitionId == "SapwoodTree" or candidate.DefinitionId == "BambooClump")
				and candidate:CanChop(player)
				and WorldProgressService.CanInteractWithTree(player, candidate)
		end, PUNCH_REACH)
		-- Presentation failure must never prevent a legitimate tree hit.
		pcall(playPunch, character)
		if tree then
			-- No weapon progression, crits, mutation/class effects or
			-- client-supplied damage. TreeObject owns kills and log rewards.
			tree:TakeDamage({ Damage = math.floor(PUNCH_DAMAGE * (1 + bonuses.Damage)), IsCrit = false }, player)
		end
		return
	end

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
	interval = math.max(MIN_FERVOR_CHOP_INTERVAL, interval / hasteMultiplier)
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
	context.BaseDamage *= 1 + bonuses.Damage
	context.CritChance = math.clamp(context.CritChance + bonuses.CritChance, 0, 100)
	context.CritMultiplier += bonuses.CritDamage
	local _, calculated = DamageService.Calculate(context)
	-- Damage boost from a PRIOR confirmed kill. This cannot boost the kill
	-- that first created Rampage, and duration/weapon ownership are checked
	-- server-side before modifying the single primary damage result.
	local rampageMultiplier = Rampage.Multiplier(player, weaponUID, now)
	if rampageMultiplier > 1 and type(calculated.Damage)=="number"
		and calculated.Damage > 0 and calculated.Damage < math.huge then
		calculated.Damage=math.clamp(math.floor(calculated.Damage*rampageMultiplier),1,1000000000)
	end

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
		OnMutationProc = function(id, details)
			if type(id)=="string" and type(details)=="table" then
				local payload={Id=id}
				for k,v in pairs(details) do
					if type(k)=="string" and (type(v)=="number" or type(v)=="string") then
						payload[k]=v
					end
				end
				EconomyUpdated:FireClient(player, "MutationProc", payload)
			end
		end,
		OnMutationTelemetry = if isMutationPracticeTree then function(effectId, state)
			if effectId == "Thunderstrike" and type(state) == "table" then
				print(string.format(
					"[MutationPractice] THUNDERSTRIKE %d/%d%s | weapon %s",
					state.Count, state.EveryHits,
					if state.Proc then " PROC!" else "",
					weaponUID))
			elseif effectId == "ThunderstrikeResult" and type(state) == "table" then
				print(string.format("[MutationPractice] THUNDERSTRIKE RESULT %s | damage=%s",
					tostring(state.Outcome), tostring(state.Damage or 0)))
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

	-- Thunderstrike's proc is a damage modifier on this SAME verified tree.
	-- Resolve BEFORE TakeDamage, not as a second hit afterwards: it works
	-- even when the combined strike kills the tree, and its actual HP removed
	-- will count ONCE for XP/rewards. Other effects retain base PrimaryDamage.
	local lightningBonus = 0
	for _, effect in ipairs(preparedEffects) do
		if effect.Id == "Thunderstrike" and type(effect.State) == "table"
			and effect.State.WillProc == true then
			local bonus = effect.State.BonusDamage
			if type(bonus) == "number" and bonus == bonus
				and bonus >= 1 and bonus <= 1000000000 then
				lightningBonus = bonus
			end
		end
	end
	if lightningBonus > 0 then
		calculated.Damage += lightningBonus
		calculated.EffectId = "Thunderstrike"
	end

	-- Normal attack remains single-target; only confirmed hits emit effects.
	local primaryMaxHP = tree.MaxHP
	local hit, actualDamage, killed = tree:TakeDamage(calculated, player)
	if not hit then return end
	recordHit(tree, actualDamage, killed, primaryMaxHP)
	effectContext.PrimarySucceeded = true
	effectContext.PrimaryAppliedDamage = actualDamage
	effectContext.PrimaryKilled = killed == true
	if fervorParams then
		local stacks = Fervor.RecordHit(player, weaponUID, tree, now, fervorParams)
		-- Replicate only server-confirmed combo state to the equipped Tool.
		-- The client uses it for animation/input pacing; server gating above
		-- remains authoritative regardless of local attribute tampering.
		local tool = runtime.EquippedWeaponTool
		if typeof(tool) == "Instance" and tool:IsA("Tool") then
			tool:SetAttribute("FervorStacks", stacks)
			tool:SetAttribute("FervorSpeedPerStack", fervorParams.SpeedPerStack)
			tool:SetAttribute("FervorExpiresAtServerTime",
				workspace:GetServerTimeNow() + fervorParams.WindowSeconds)
		end
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
	-- All OnKill effects share this verified, HP-clamped reward path:
	-- Golden Touch/Rush/Jackpot receive only species-based server payouts;
	-- Bloodrush/Rampage receive short, bounded buffs. No client kill claims.
	-- A tree can reward at most once per swing, including Chain Lightning
	-- and (Studio-only) Cleave secondary kills.
	local coinDelta=0
	local seenKills={}
	for _, record in ipairs(hitRecords) do
		local killedTree=record.Tree
		if record.Killed==true and type(killedTree)=="table"
			and not seenKills[killedTree] then
			seenKills[killedTree]=true
			local base=MaterialDefinitions.GetSellValue(killedTree.SpeciesId) or 0
			WeaponEffects.ApplyTrigger("OnKill",data,{
				Player=player,WeaponUID=weaponUID,Now=now,Killed=true,
				TreeCoinBase=base,
				AwardCoins=function(amount)
					if type(amount)=="number" and amount==amount
						and amount>=1 and amount<=50000 and amount%1==0 then
						coinDelta += amount
					end
				end,
				OnMutationProc=effectContext.OnMutationProc,
			})
		end
	end
	if coinDelta>0 then
		coinDelta=Passives.ScaleReward(coinDelta,bonuses.CoinGain)
		local coins=profile.Data.Coins
		if type(coins)=="number" and coins==coins and coins>=0
			and coins<1e12 then
			profile.Data.Coins=math.min(1e12,coins+coinDelta)
			EconomyUpdated:FireClient(player,"Coins",profile.Data.Coins)
		end
	end
	-- No client-reported hit/XP values. XP comes exclusively from trusted,
	-- HP-clamped TreeObject outcomes for the equipped weapon UID.
	WeaponProgressionService.AwardHits(player, weaponUID, hitRecords)
end)

local function clearTransientCombatState(player)
	lastChop[player] = nil
	Fervor.Clear(player)
	Thunderstrike.Clear(player)
	Rampage.Clear(player)
	GoldenRush.Clear(player)
	Bloodrush.Clear(player)
end
Players.PlayerRemoving:Connect(clearTransientCombatState)
local function watchCharacter(player)
	player.CharacterRemoving:Connect(function()
		clearTransientCombatState(player)
	end)
end
Players.PlayerAdded:Connect(watchCharacter)
for _, player in ipairs(Players:GetPlayers()) do
	watchCharacter(player)
end
