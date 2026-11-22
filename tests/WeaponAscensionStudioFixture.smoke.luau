-- OPTIONAL Phase 1D end-to-end fixture for Studio SERVER Command Bar.
-- Mutates ONLY the active Studio player's mock testing session.
-- DO NOT put this file in src/ or call it from production code.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Ascension fixture is Studio-only")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Rules = require(game.ServerScriptService.WeaponProgressionRules)
local Ascension = require(game.ServerScriptService.WeaponAscensionRules)
local AscensionService = require(game.ServerScriptService.WeaponAscensionService)
local LogService = require(game.ServerScriptService.Inventory.LogService)
local StatsAggregator = require(game.ServerStorage.Items.StatsAggregator)

local FORCE_GUARANTEED_NEXT_ATTEMPT = true -- set false to test ordinary RNG
local player = Players:GetPlayers()[1]
assert(player, "Start single-player Studio Play first")
local profile = ProfileCache.GetProfile(player)
assert(profile and profile.Data and profile.Data.Runtime,
	"Wait until the player profile and inventory are initialized")
local data = profile.Data
local uid = data.Runtime.EquippedWeaponUID
local chosen
for _, weapon in ipairs(data.Inventory or {}) do
	if type(weapon) == "table" and weapon.UID == uid and weapon.ItemID ~= 9001
		and Ascension.STEPS[weapon.Rarity] then
		chosen = weapon
		break
	end
end
if not chosen then
	for _, weapon in ipairs(data.Inventory or {}) do
		if type(weapon) == "table" and weapon.ItemID ~= 9001
			and Ascension.STEPS[weapon.Rarity]
			and data.Runtime.Weapon[weapon.UID] then
			chosen = weapon
			break
		end
	end
end
assert(chosen, "Forge a normal Common/Rare/Epic/Legendary weapon first; debug axes cannot ascend")
local live = data.Runtime.Weapon[chosen.UID]
assert(live and live.ItemUID == chosen.UID and type(live.WeaponData) == "table")
Rules.NormalizeWeaponItem(chosen)
local cap = Rules.GetLevelCap(chosen.Rarity)
local progress = chosen.WeaponData.Progression
progress.Level = cap
progress.XP = 0
progress.AscensionFailures = if FORCE_GUARANTEED_NEXT_ATTEMPT
	then Ascension.PityLimit(chosen.Rarity) - 1 else 0
live.ItemRarity = chosen.Rarity
live.WeaponData.Progression = table.clone(progress)
if type(live.ItemWeaponData) == "table" then
	live.ItemWeaponData.Progression = table.clone(progress)
end
if data.Runtime.EquippedWeaponUID == chosen.UID then
	StatsAggregator.Aggregate(player)
end

local needed = Ascension.STEPS[chosen.Rarity].Logs
local available = #AscensionService.EligibleLogs(player)
local extra = math.max(0, needed - available)
for _ = 1, extra do
	-- Cheap, ordinary, unlocked BAG logs only; will be consumed first.
	table.insert(data.Logs, {
		UID = "devasc-" .. HttpService:GenerateGUID(false),
		ItemType = "Log", SpeciesId = "Bamboo", Mutations = {},
		Locked = false, SizeScale = 0.5, CreatedAt = os.time(),
	})
end
data.Coins = math.max(type(data.Coins) == "number" and data.Coins or 0, 20000)
LogService.NotifyState(player)
print(string.format(
	"[AscensionFixture] Weapon: %s / %s  rarity=%s  level=%d  pity_failures=%d  ordinary_bag_logs=%d",
	chosen.UID, tostring(chosen.WeaponData.WeaponKind or chosen.ItemID),
	chosen.Rarity, progress.Level, progress.AscensionFailures,
	#AscensionService.EligibleLogs(player)))
print("[AscensionFixture] Stand near THE FORGE, open M → AXES → INFO, select this weapon and confirm ASCEND twice.")
return chosen.UID
