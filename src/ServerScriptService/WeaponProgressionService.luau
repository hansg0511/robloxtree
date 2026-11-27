-- Server-only award path for weapon XP. All inputs originate from the
-- validated ChopHandler / TreeObject hit path, never a client remote.
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local WorldProgressService = require(game.ServerScriptService.WorldProgressService)
local ProgressionRules = require(game.ServerScriptService.WeaponProgressionRules)
local StatsAggregator = require(game.ServerStorage.Items.StatsAggregator)
local Passives = require(game.ServerScriptService.PassiveStats)
local Substats = require(game.ServerScriptService.WeaponSubstatRules)

local EconomyUpdated = game.ReplicatedStorage.Economy:WaitForChild("EconomyUpdated")
local WeaponProgressionService = {}

local MAX_HITS_PER_ATTACK = 9 -- primary + bounded registered secondary effects

local function findUniquePersistentWeapon(data, uid, itemID)
	if type(data) ~= "table" or type(data.Inventory) ~= "table" then return nil end
	local match
	for _, item in ipairs(data.Inventory) do
		if type(item) == "table" and item.UID == uid then
			if match or item.ItemID ~= itemID then return nil end
			match = item
		end
	end
	return match
end

function WeaponProgressionService.AwardHits(player, weaponUID, hitRecords)
	if type(weaponUID) ~= "string" or type(hitRecords) ~= "table"
		or #hitRecords < 1 or #hitRecords > MAX_HITS_PER_ATTACK then return 0, 0 end

	-- A spawned Tool and its runtime UID must both pass the same server check
	-- used by ChopHandler. Ephemeral debug weapons are never progressed.
	local equipped, verifiedUID = WorldProgressService.GetEquippedRuntimeWeapon(player)
	if not equipped or verifiedUID ~= weaponUID or equipped.ItemID == 9001 then
		return 0, 0
	end
	local profile = ProfileCache.GetProfile(player)
	local data = profile and profile.Data
	local runtime = data and data.Runtime
	if not runtime or runtime.Weapon[weaponUID] ~= equipped
		or (runtime.EphemeralWeaponUIDs and runtime.EphemeralWeaponUIDs[weaponUID]) then
		return 0, 0
	end
	local saved = findUniquePersistentWeapon(data, weaponUID, equipped.ItemID)
	if not saved or not ProgressionRules.IsRarity(saved.Rarity)
		or type(saved.WeaponData) ~= "table" or type(equipped.WeaponData) ~= "table" then
		return 0, 0
	end

	-- Keep the Studio cadence comparison reproducible while normal weapons
	-- continue to gain XP. No gameplay effect outside Studio.
	if game:GetService("RunService"):IsStudio()
		and saved.WeaponData.DevCadenceFixture == true then return 0, 0 end

	local xpEarned = 0
	for _, hit in ipairs(hitRecords) do
		if type(hit) == "table" then
			xpEarned += ProgressionRules.XPForAppliedHit(
				hit.AppliedDamage, hit.TreeMaxHP, hit.Killed)
		end
	end
	xpEarned=Passives.ScaleReward(xpEarned,Passives.Totals(data,equipped,os.time()).WeaponXP)
	if xpEarned < 1 then return 0, 0 end

	local current = ProgressionRules.NormalizeProgression(
		saved.WeaponData.Progression, saved.Rarity)
	local nextProgress, levelsGained = ProgressionRules.ApplyXP(
		current, saved.Rarity, xpEarned)
	if current.Level == nextProgress.Level and current.XP == nextProgress.XP then
		return 0, 0 -- already at level cap
	end

	-- The saved Inventory item is authoritative. Runtime inventory / IMS
	-- records are distinct copies produced by ItemDataBase.ParseItem.
	saved.WeaponData.Progression = nextProgress
	equipped.WeaponData.Progression = table.clone(nextProgress)
	if type(equipped.ItemWeaponData) == "table" then
		equipped.ItemWeaponData.Progression = table.clone(nextProgress)
	end
	if levelsGained > 0 then
		-- Aggregate after all hits in the swing, so a level-up never changes
		-- damage within the same primary hit + Cleave chain.
		StatsAggregator.Aggregate(player)
	end
	local level = nextProgress.Level
	local cap = ProgressionRules.GetLevelCap(saved.Rarity)
	local baseAttack = type(saved.Stats) == "table" and saved.Stats.Attack or 0
	if type(baseAttack) ~= "number" or baseAttack ~= baseAttack
		or baseAttack < 0 or baseAttack == math.huge then
		baseAttack = 0
	end
	local bonus = ProgressionRules.DerivedAttackBonus(saved, 5)
	EconomyUpdated:FireClient(player, "WeaponProgression", {
		UID = weaponUID,
		Rarity = saved.Rarity,
		Level = level,
		LevelCap = cap,
		XP = nextProgress.XP,
		XPToNextLevel = ProgressionRules.XPToNextLevel(saved.Rarity, level),
		LevelsGained = levelsGained,
		Power = 5 + baseAttack + bonus,
		PassiveSubstats = Substats.Snapshot(saved),
	})
	return xpEarned, levelsGained
end

return WeaponProgressionService
