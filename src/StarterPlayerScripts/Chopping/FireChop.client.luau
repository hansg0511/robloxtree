local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ChopEvent = ReplicatedStorage.Chop.ChopEvent
local ChopFX = ReplicatedStorage.Chop.ChopFX
local FXService = require(game.ReplicatedStorage.FXService)

	
local player = game.Players.LocalPlayer

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

FXHandlers.DropLeaves = function(ctx)
	FXService:DropLeaves(ctx.model, ctx.pool, ctx.leavesToDrop)
end

FXHandlers.TreeDies = function(ctx)
	player = game.Players:GetPlayerByUserId(ctx.playerID)
	FXService:TreeFall(ctx.model, player)
end

FXHandlers.TreeRespawn = function(ctx)
	FXService:FadeIn(ctx.model)
end

ChopFX.OnClientEvent:Connect(function(fxType, ctx)
	local handler = FXHandlers[fxType]
	if handler then
		handler(ctx)
	else
		warn("Unknown FXType: ", fxType)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if track then track:Play() end
		ChopEvent:FireServer()
	end	
end)





