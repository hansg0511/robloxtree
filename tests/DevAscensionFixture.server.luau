-- TEMPORARY Studio-only auto-runner. Intentionally stored in tests/,
-- NOT under src/: install locally with the coding agent to run via Rojo.
-- Prepares one normal owned weapon for a guaranteed ascension attempt,
-- then audits real server resource and weapon deltas after the player clicks.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Remote = game.ReplicatedStorage:WaitForChild("Economy"):WaitForChild("AscendWeaponRE")
local ProfileCache = require(game.ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Progression = require(game.ServerScriptService.WeaponProgressionRules)
local Ascension = require(game.ServerScriptService.WeaponAscensionRules)
local Service = require(game.ServerScriptService.WeaponAscensionService)
local Logs = require(game.ServerScriptService.Inventory.LogService)
local Stats = require(game.ServerStorage.Items.StatsAggregator)
local Sandbox = require(game.ServerScriptService.Economy.StudioForgeSandbox)

local GUARANTEE_NEXT_ATTEMPT = true
local COINS_FOR_TEST = 20000
local WAIT_FOR_PLAYER_SECONDS = 90

-- Important: old forging fixture silently refills currency on shop refresh.
-- Disable this in THIS Studio Play session so deductions are observable.
Sandbox.ENABLED = false

local function normalWeapon(data)
	local runtime = data.Runtime
	local function eligible(item)
		return type(item) == "table" and item.ItemID ~= 9001
			and type(item.UID) == "string" and Ascension.STEPS[item.Rarity] ~= nil
			and type(runtime.Weapon[item.UID]) == "table"
			and runtime.Weapon[item.UID].ItemUID == item.UID
	end
	for _, item in ipairs(data.Inventory) do
		if eligible(item) and item.UID == runtime.EquippedWeaponUID then
			return item
		end
	end
	for _, item in ipairs(data.Inventory) do
		if eligible(item) then return item end
	end
	return nil
end

local function prepare(player, data, item)
	assert(Progression.NormalizeWeaponItem(item), "Weapon normalization failed")
	local live = data.Runtime.Weapon[item.UID]
	assert(type(live.WeaponData) == "table", "Runtime weapon not ready")
	local progress = item.WeaponData.Progression
	progress.Level = Progression.GetLevelCap(item.Rarity)
	progress.XP = 0
	progress.AscensionFailures = if GUARANTEE_NEXT_ATTEMPT
		then Ascension.PityLimit(item.Rarity) - 1 else 0

	live.ItemRarity = item.Rarity
	live.WeaponData.Progression = table.clone(progress)
	if type(live.ItemWeaponData) == "table" then
		live.ItemWeaponData.Progression = table.clone(progress)
	end
	if data.Runtime.EquippedWeaponUID == item.UID then
		Stats.Aggregate(player)
	end

	local step = Ascension.STEPS[item.Rarity]
	local shortage = math.max(0, step.Logs - #Service.EligibleLogs(player))
	for _ = 1, shortage do
		table.insert(data.Logs, {
			UID = "devasc-" .. HttpService:GenerateGUID(false),
			ItemType = "Log", SpeciesId = "Bamboo", Mutations = {},
			Locked = false, CreatedAt = os.time(), SizeScale = 0.5,
		})
	end
	data.RunProgress.ForgeLevel=math.max(data.RunProgress.ForgeLevel or 1,step.RequiredForge)
	data.Coins = math.max(COINS_FOR_TEST,step.Coins)
	data.MaterialBalances.AscensionCrystal=step.Crystals
	Logs.NotifyState(player)

	-- Snapshot *after* preparation, before any ascension request. Works even
	-- with hundreds of logs from an earlier Studio forging fixture.
	local beforeCoins = data.Coins
	local beforeCrystals=data.MaterialBalances.AscensionCrystal
	local beforeBag = #data.Logs
	local beforeEligible = Service.EligibleLogs(player)
	local fromRarity, beforeLevel = item.Rarity, progress.Level
	local toRarity = step.To
	local oldAttack = item.Stats and item.Stats.Attack
	local oldMaterials = item.WeaponData.Materials
	local oldEffects = item.WeaponData.Effects
	local consumedUIDs = {}
	for i = 1, step.Logs do
		assert(beforeEligible[i] and beforeEligible[i].UID, "Not enough ordinary test logs")
		consumedUIDs[i] = beforeEligible[i].UID
	end

	print(string.format(
		"[DevAscensionFixture] READY | UID %s | %s Lv%d | %d coins | %d bag logs | %d eligible normal logs",
		item.UID, fromRarity, beforeLevel, beforeCoins, beforeBag, #beforeEligible
	))
	print(string.format(
		"[DevAscensionFixture] EXPECT | %s Lv%d | spend %d coins and %d ordinary bag log(s)",
		toRarity, beforeLevel, step.Coins, step.Logs
	))
	print("[DevAscensionFixture] Go near FORGE; open M > AXES > INFO; select this weapon; click ASCEND twice.")
	print("[DevAscensionFixture] No chopping, selling, or other crafting until the audit completes.")

	local audited = false
	local conn
	conn = Remote.OnServerEvent:Connect(function(requester, requestedUID)
		if audited or requester ~= player or requestedUID ~= item.UID then return end
		audited = true
		conn:Disconnect()

		-- Listen for the actual remote instead of assuming UI button state.
		-- Other server listeners may execute in either order; inspect after.
		task.delay(0.7, function()
			local afterCoins = data.Coins
			local afterBag = #data.Logs
			local afterEligible = Service.EligibleLogs(player)
			local stillOwned = {}
			for _, container in ipairs({data.Logs, data.StoredLogs}) do
				for _, record in ipairs(container) do
					if type(record) == "table" then stillOwned[record.UID] = true end
				end
			end
			local removedAllUIDs = true
			for _, uid in ipairs(consumedUIDs) do
				if stillOwned[uid] then removedAllUIDs = false end
			end
			local coinsSpent = beforeCoins - afterCoins
			local logsSpent = beforeBag - afterBag
			local moneyOK = coinsSpent == step.Coins and beforeCrystals-data.MaterialBalances.AscensionCrystal==step.Crystals
			local logsOK = logsSpent == step.Logs
				and #beforeEligible - #afterEligible == step.Logs
				and removedAllUIDs
			local afterProgress = item.WeaponData.Progression
			local currentLive = data.Runtime.Weapon[item.UID]
			local rarityOK = item.Rarity == toRarity
				and afterProgress.Level == beforeLevel and afterProgress.XP == 0
				and afterProgress.AscensionFailures == 0
				and currentLive and currentLive.ItemRarity == toRarity
			local preservedOK = item.Stats and item.Stats.Attack == oldAttack
				and #item.WeaponData.Materials==#(oldMaterials or {})
				and #(item.WeaponData.Effects or {})>=#(oldEffects or {})

			print("[DevAscensionFixture] ===== ASCENSION AUDIT =====")
			print(string.format("[DevAscensionFixture] Coins %d -> %d (spent %d / expected %d) %s",
				beforeCoins, afterCoins, coinsSpent, step.Coins,
				if moneyOK then "PASS" else "FAIL"))
			print(string.format("[DevAscensionFixture] Bag logs %d -> %d (spent %d / expected %d) %s",
				beforeBag, afterBag, logsSpent, step.Logs,
				if logsOK then "PASS" else "FAIL"))
			print("[DevAscensionFixture] Exact spent log UIDs removed: "
				.. (if removedAllUIDs then "YES" else "NO"))
			print(string.format("[DevAscensionFixture] Weapon %s Lv%d -> %s Lv%d %s",
				fromRarity, beforeLevel, item.Rarity, afterProgress.Level,
				if rarityOK then "PASS" else "FAIL"))
			print("[DevAscensionFixture] Original attack, materials, effects unchanged: "
				.. (if preservedOK then "PASS" else "FAIL"))
			if moneyOK and logsOK and rarityOK and preservedOK then
				print("[DevAscensionFixture] ASCENSION AUDIT PASS")
			else
				warn("[DevAscensionFixture] ASCENSION AUDIT FAIL -- check Forge proximity, Output errors and result message")
			end
		end)
	end)
end

task.spawn(function()
	local start = os.clock()
	while os.clock() - start < WAIT_FOR_PLAYER_SECONDS do
		local players = Players:GetPlayers()
		if #players == 1 then
			local player = players[1]
			local profile = ProfileCache.GetProfile(player)
			local data = profile and profile.Data
			if type(data) == "table"
				and type(data.Runtime) == "table"
				and type(data.Runtime.Weapon) == "table"
				and type(data.Inventory) == "table"
				and type(data.Logs) == "table"
				and type(data.StoredLogs) == "table" then
				local item = normalWeapon(data)
				if item then
					local ok, err = pcall(prepare, player, data, item)
					if not ok then warn("[DevAscensionFixture] Preparation failed:", err) end
					return
				end
			end
		end
		task.wait(0.4)
	end
	warn("[DevAscensionFixture] No saved, non-debug eligible weapon found. Forge one and restart Studio Play.")
end)
