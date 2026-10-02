-- Temporary server-owned traversal baseline for evaluating the first corridor.
-- This is not a movement upgrade system or a persistent player stat.
local Players = game:GetService("Players")

local PLAYTEST_WALK_SPEED = 28

local function configureCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = PLAYTEST_WALK_SPEED
end

local function configurePlayer(player)
	player.CharacterAdded:Connect(configureCharacter)
	if player.Character then
		configureCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(configurePlayer)
for _, player in ipairs(Players:GetPlayers()) do
	configurePlayer(player)
end
