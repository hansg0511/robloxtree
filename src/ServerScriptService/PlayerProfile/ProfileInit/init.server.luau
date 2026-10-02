local profileCache = require(script.Parent.ProfileService.ProfileDataCache)
local DevelopmentLoadouts = require(script.Parent.DevelopmentLoadouts)
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
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
		DevelopmentLoadouts.ApplyStudioPreset(player, profile.Data)
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
