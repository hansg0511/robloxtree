local profileCache = require(script.Parent.ProfileService.ProfileDataCache)
local bindableLoaded = script.ProfileLoadedEvent
local remoteLoaded = game.ReplicatedStorage.Profile.ProfileLoadEvent


local ProfileTemplate = {
	
	Inventory = {
		{
			ItemID = 101,
			UID = "1232",
			Stats = {
				["Attack"] = 5000000,
				["AttackSpeed"] = 3
			},
			Substat = {
				["CritChance"] = 5,
				["CritDamage"] = 10000000,
			},
			Rarity = "Common",
		},
		
		{
			ItemID = 101,
			UID = "1233",
			Stats = {
				["Attack"] = 1,
				["CritChance"] = 5
			},
			Substat = {
				["AttackSpeed"] = 3,
				["CritChance"] = 10
			},
			Rarity = "Common",
		},
		
		{
			ItemID = 201,
			UID = "1234",
			Stats = {
				["Attack"] = 10,
				["CritChance"] = 5
			},
			Substat = {
				["AttackSpeed"] = 3,
				["CritChance"] = 10
			},
			Rarity = "Common",
		}
	,

		
	},
	Coins = 0,
	TreeLevel = 1,
	Wood = 0,
	LogInTimes = 0,
	Equipped = {
		Weapon = "1232",
	},
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
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
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
