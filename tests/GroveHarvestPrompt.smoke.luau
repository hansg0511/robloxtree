-- Run in Roblox Studio's SERVER Command Bar with a running player.
-- Source-only guard checks. In-world E input and camera FX still need manual play.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tree = require(game.ServerScriptService.Trees.TreeObject)
local Presentation = require(ReplicatedStorage.Shared.GroveHarvestPresentation)

local function check(name, condition)
	assert(condition, name .. " failed")
end

local remote = ReplicatedStorage.Grove:FindFirstChild("GroveHarvestFXRE")
check("harvest remote exists", remote and remote:IsA("RemoteEvent"))
check("short camera sequence", Presentation.CameraHoldSeconds >= 2
	and Presentation.CameraHoldSeconds <= 4)
check("prompt radius safe", Presentation.PromptDistance < Presentation.InteractionDistance)
check("wind-up before fall", Presentation.WindupSeconds > 0
	and Presentation.WindupSeconds < 0.6)
check("bounded visual lifetime", Presentation.MaxVisualLifetimeSeconds <= 10)
local count = 0
for tree in pairs(Tree.ActiveTrees) do
	if tree.IsPersistentGrove then
		count += 1
		local owner = Players:GetPlayerByUserId(tree.OwnerUserId)
		if owner then
			check("Grove cannot be struck with an axe", tree:CanChop(owner) == false)
		end
		check("Grove model exists", tree.model ~= nil and tree.model.Parent ~= nil)
		local anchor = tree.model:FindFirstChild("GroveHarvestPromptAnchor")
		if tree.GroveStage == "mature" then
			check("mature tree has E anchor", anchor ~= nil)
			local prompt = anchor and anchor:FindFirstChild("GroveHarvestPrompt")
			check("mature tree E prompt", prompt and prompt:IsA("ProximityPrompt"))
			check("E shortcut", prompt.KeyboardKeyCode == Enum.KeyCode.E)
		else
			check("immature tree has no harvest prompt", anchor == nil)
		end
	end
end
print(string.format("Grove prompt smoke checks passed (%d grove trees inspected)", count))
return true
