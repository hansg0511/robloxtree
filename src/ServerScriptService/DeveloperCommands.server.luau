-- Local playtest utilities. Never register commands on a published server.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileCache = require(ServerScriptService.PlayerProfile.ProfileService.ProfileDataCache)
local Sandbox = require(ServerScriptService.Economy.StudioForgeSandbox)
local Config = require(ReplicatedStorage.Shared.ProgressionConfig)
local Premium = require(ReplicatedStorage.Shared.PremiumEconomyConfig)
local Progression = require(ServerScriptService.WeaponProgressionRules)
local WorldProgress = require(ServerScriptService.WorldProgressService)
local Stats = require(game.ServerStorage.Items.StatsAggregator)
local EconomyUpdated = ReplicatedStorage.Economy:WaitForChild("EconomyUpdated")

local MAX_BALANCE = 1e12
local HELP = "/dev help | /dev coins <amount> | /dev gems <amount> | /dev crystals <amount> | /dev forge <level> | /dev maxweapon | /dev refill | /dev sandbox on/off"
local function report(player, message)
	print("[StudioDev] " .. player.Name .. ": " .. message)
end

local function integer(text, low, high)
	local n = tonumber(text)
	if not n or n ~= n or n < low or n > high or n % 1 ~= 0 then return nil end
	return n
end

-- Refresh the existing HUD and shop projections; never expose a new admin remote.
-- The usual snapshot reads honor the current sandbox setting.
local function refresh(player)
	EconomyUpdated:FireClient(player, "Coins")
	EconomyUpdated:FireClient(player, "PremiumBalances")
	EconomyUpdated:FireClient(player, "Progression")
end

local function maxWeapon(player, data)
	local equipped, uid = WorldProgress.GetEquippedRuntimeWeapon(player)
	local runtime = data.Runtime
	if not equipped or type(uid) ~= "string" or equipped.ItemID == 9001
		or type(runtime.Weapon) ~= "table" or runtime.Weapon[uid] ~= equipped
		or (runtime.EphemeralWeaponUIDs and runtime.EphemeralWeaponUIDs[uid]) then
		return false, "Equip a normal crafted weapon first."
	end
	local saved
	for _, item in ipairs(data.Inventory or {}) do
		if type(item) == "table" and item.UID == uid then
			if saved or item.ItemID ~= equipped.ItemID then
				return false, "Weapon identity is inconsistent."
			end
			saved = item
		end
	end
	if not saved or type(saved.WeaponData) ~= "table"
		or saved.WeaponData.DevCadenceFixture == true
		or type(equipped.WeaponData) ~= "table"
		or not Progression.IsRarity(saved.Rarity) then
		return false, "Equip a real, non-fixture crafted weapon first."
	end
	local progress = Progression.NormalizeProgression(saved.WeaponData.Progression, saved.Rarity)
	progress.Level = Progression.GetLevelCap(saved.Rarity)
	progress.XP = 0
	saved.WeaponData.Progression = progress
	equipped.WeaponData.Progression = table.clone(progress)
	if type(equipped.ItemWeaponData) == "table" then
		equipped.ItemWeaponData.Progression = table.clone(progress)
	end
	Stats.Aggregate(player)
	return true, saved.Rarity .. " weapon set to level " .. tostring(progress.Level) .. "; pity unchanged."
end

local function execute(player, words)
	local verb = string.lower(words[2] or "help")
	local arg = words[3]
	if verb == "help" then report(player, HELP); return end
	local data = ProfileCache.GetData(player)
	if player:GetAttribute("ProfileReady") ~= true or type(data) ~= "table"
		or type(data.Runtime) ~= "table" then
		report(player, "Profile not ready. Try again after loading.")
		return
	end

	if verb == "sandbox" then
		arg = string.lower(arg or "")
		if arg ~= "on" and arg ~= "off" then report(player, "Usage: /dev sandbox on/off"); return end
		-- Session-only, server-wide toggle; does not change the source default.
		Sandbox.ENABLED = arg == "on"
		if Sandbox.ENABLED then Sandbox.Refill(player, data) end
		report(player, "Automatic resource refill " .. arg .. " for this Studio server.")
	elseif verb == "refill" then
		if not Sandbox.IsEnabled() then
			report(player, "Refill disabled. Use /dev sandbox on first.")
			return
		end
		Sandbox.Refill(player, data)
		report(player, "Sandbox supplies restored.")
	elseif verb == "coins" or verb == "gems" or verb == "crystals" then
		local amount = integer(arg, 0, MAX_BALANCE)
		if not amount then report(player, "Use a whole number between 0 and 1000000000000."); return end
		local floor = if verb == "coins" then Sandbox.COIN_FLOOR
			elseif verb == "gems" then Premium.STUDIO_PREMIUM_FLOOR else Premium.STUDIO_CRYSTAL_FLOOR
		if Sandbox.IsEnabled() and amount < floor then
			report(player, "Auto-refill would overwrite that amount. Run /dev sandbox off first.")
			return
		end
		if verb == "coins" then
			data.Coins = amount
		else
			if type(data.MaterialBalances) ~= "table" then report(player, "Material balances not ready."); return end
			data.MaterialBalances[if verb == "gems" then Premium.PREMIUM else Premium.CRYSTAL] = amount
		end
		report(player, verb .. " set to " .. tostring(amount))
	elseif verb == "forge" then
		local level = integer(arg, 1, Config.MAX_FORGE_LEVEL)
		if not level or not Config.ValidForge(level) or type(data.RunProgress) ~= "table" then
			report(player, "Usage: /dev forge <1-" .. tostring(Config.MAX_FORGE_LEVEL) .. ">")
			return
		end
		data.RunProgress.ForgeLevel = level
		report(player, "Forge level set to " .. tostring(level) .. "; existing weapons unchanged.")
	elseif verb == "maxweapon" then
		local ok, message = maxWeapon(player, data)
		report(player, message)
		if not ok then return end
	else
		report(player, HELP)
		return
	end
	refresh(player)
end

local command = Instance.new("TextChatCommand")
command.Name = "StudioDeveloperCommand"
command.PrimaryAlias = "/dev"
command.Triggered:Connect(function(source, unfilteredText)
	if not RunService:IsStudio() or not source or type(unfilteredText) ~= "string" then return end
	-- The server-issued TextSource identifies the requester; only their own
	-- Mock-profile data is edited. No target-user argument or live access.
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player or not player:IsDescendantOf(Players) then return end
	local words = {}
	for word in string.gmatch(unfilteredText, "%S+") do words[#words + 1] = word end
	if string.lower(words[1] or "") ~= "/dev" or #words > 3 then
		report(player, HELP)
		return
	end
	local ok, err = pcall(execute, player, words)
	if not ok then warn("[StudioDev] Command failed:", err) end
end)
command.Parent = TextChatService
print("[StudioDev] Type /dev help in Studio chat. Results appear in server Output.")
