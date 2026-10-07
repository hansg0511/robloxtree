local profileCache = require(script.Parent.ProfileService.ProfileDataCache)
local DevelopmentLoadouts = require(script.Parent.DevelopmentLoadouts)
local AxeShopCatalog = require(game.ServerScriptService.Economy.AxeShopCatalog)
local bindableLoaded = script.ProfileLoadedEvent
local remoteLoaded = game.ReplicatedStorage.Profile.ProfileLoadEvent


local ProfileTemplate = {
	
	Inventory = {
		{
			ItemID = 101,
			UID = "starter-basic-axe",
			Stats = {
				["Attack"] = 5,
			},
			Substat = {},
			Rarity = "Common",
		},
	},
	-- One unique physical log per record; material kg cost is resolved server-side.
	Logs = {},
	-- Personal Grove ownership is stored as primitive profile records. Runtime
	-- TreeObjects and world transforms are rebuilt after the player's plot loads.
	Saplings = {},
	GroveTrees = {},
	ActiveGroveTreeUIDs = {},
	-- Axe heads are crafting materials, never equipable Tools.
	AxeHeads = {
		copper_head = 0,
		iron_head = 0,
	},
	-- Current-run progression is stored separately so Rebirth can reset it later
	-- without inferring it from permanently owned inventory records.
	RunProgress = {
		StandardAxeTier = 0,
		UnlockedForests = {
			Base = true,
			Forest1 = true,
			Forest2 = false,
		},
	},
	CarryCapacityKg = AxeShopCatalog.DEFAULT_CAPACITY_KG,
	-- Neutral server-owned seam for future character/prestige progression.
	-- It deliberately has no player-facing progression in this prototype.
	LumberjackStrength = 1,
	Coins = 0,
	Wood = 0,
	LogInTimes = 0,
	Equipped = {
		Weapon = "starter-basic-axe",
	},
	-- Retained because StatsAggregator supports legacy/current pet records. New
	-- profiles start empty; pets are not part of this rework's feature scope.
	ActivePets = {}
}

local ProfileService = require(game.ServerScriptService.PlayerProfile.ProfileService)
--------------------------------------------------------------------
local Players = game:GetService("Players")

local ProfileStore = ProfileService.GetProfileStore(
	"PlayerData",
	ProfileTemplate
)



--------------------------------------------------------------------
local function DoSomethingWithALoadedProfile(player, profile)
	profile.Data.LogInTimes = profile.Data.LogInTimes + 1
	print(player.Name .. " has logged in " .. tostring(profile.Data.LogInTimes)
		.. " time" .. ((profile.Data.LogInTimes > 1) and "s" or ""))
	print(player.Name .. " owns " .. tostring(profile.Data.Coins) .. " now!")
end


local function PlayerAdded(player)
	-- Rework testing intentionally uses the mock store. Never wipe live player data on join.
	local profile = ProfileStore.Mock:LoadProfileAsync("Player_" .. player.UserId)
	if profile ~= nil then
		print("New Player")
		profile:AddUserId(player.UserId) -- GDPR compliance
		-- Migrate the old count-named field before Reconcile injects the new
		-- default. Existing configured values (10/15/20/30/40) retain their number
		-- and become kilograms; malformed values fall back safely in the cache.
		profileCache.NormalizeCarryCapacity(profile.Data)
		local runProgressBeforeReconcile = profile.Data.RunProgress
		local priorTier = type(runProgressBeforeReconcile) == "table"
			and runProgressBeforeReconcile.StandardAxeTier
		local hadValidStandardAxeTier = type(priorTier) == "number"
			and priorTier == priorTier
			and math.abs(priorTier) < math.huge
			and priorTier >= 0
			and priorTier % 1 == 0
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
		profileCache.NormalizeGroveData(profile.Data)
		if not hadValidStandardAxeTier then
			-- One-time legacy migration: direct-purchased Copper/Iron weapons already
			-- owned before the schema existed count as reached tiers. Axe Heads alone
			-- never advance this current-run benchmark.
			local highestOwnedTier = 0
			for _, ownedItem in ipairs(type(profile.Data.Inventory) == "table" and profile.Data.Inventory or {}) do
				if type(ownedItem) == "table" then
					local recipe = AxeShopCatalog.FindRecipeForOutput(ownedItem.ItemID)
					if recipe and recipe.Tier > highestOwnedTier then
						highestOwnedTier = recipe.Tier
					end
				end
			end
			profile.Data.RunProgress.StandardAxeTier = highestOwnedTier
		end
		DevelopmentLoadouts.ApplyStudioPreset(player, profile.Data)
		DevelopmentLoadouts.ApplyGroveSaplings(player, profile.Data)
		profileCache.NormalizeGroveData(profile.Data)
		profile:ListenToRelease(function()
			profileCache.Remove(player)
			-- The profile could've been loaded on another Roblox server:
			player:Kick()
		end)
		if player:IsDescendantOf(Players) == true then
			profileCache.Set(player, profile)
			bindableLoaded:Fire(player)
			player:SetAttribute("ProfileReady", true)
			remoteLoaded:FireClient(player)
			
			
			-- A profile has been successfully loaded:
			
		else
			-- Player left before the profile loaded:
			profile:Release()
		end
	else
		-- The profile couldn't be loaded possibly due to other
		--   Roblox servers trying to load this profile at the same time:
		player:Kick() 
	end
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = profileCache.GetProfile(player)
	if profile ~= nil then
		profile.Data.Runtime = nil
		profile:Release()
		profileCache.Remove(player)
	end
end)
