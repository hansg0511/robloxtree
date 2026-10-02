local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ChopEvent = ReplicatedStorage.Chop.ChopEvent
local ChopFX = ReplicatedStorage.Chop.ChopFX
local FXService = require(game.ReplicatedStorage.FXService)

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://125763233049501"

local track
local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	track = animator:LoadAnimation(animation)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then onCharacter(player.Character) end


local FXHandlers = {}

FXHandlers.playHit = function(ctx)
	FXService:playHit(ctx.model)
end

ChopFX.OnClientEvent:Connect(function(fxType, ctx)
	local handler = FXHandlers[fxType]
	if handler then
		handler(ctx)
	else
		warn("Unknown FXType: ", fxType)
	end
end)

local function getTargetCandidate()
	local target = mouse.Target
	local cursor = target
	while cursor do
		if cursor:IsA("Model") and cursor.Name == "Tree" then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local targetCandidate = getTargetCandidate()
		if not targetCandidate then return end
		if track then track:Play() end
		-- This is a request only. The server resolves the model against its
		-- registry and rejects anything invalid, out of range, or unauthorized.
		ChopEvent:FireServer(targetCandidate)
	end	
end)





