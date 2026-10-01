local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ChopEvent = ReplicatedStorage.Chop.ChopEvent
local ChopFX = ReplicatedStorage.Chop.ChopFX
local FXService = require(game.ReplicatedStorage.FXService)

	
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")	

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://125763233049501"

local track = humanoid:LoadAnimation(animation)


local FXHandlers = {}

FXHandlers.playHit = function(ctx)
	FXService:playHit(ctx.model)
end

FXHandlers.DropLeaves = function(ctx)
	FXService:DropLeaves(ctx.model, ctx.pool, ctx.leavesToDrop)
end

FXHandlers.TreeDies = function(ctx)
	player = game.Players:GetPlayerByUserId(ctx.playerID)
	print(player,"Player", ctx.model)
	FXService:TreeFall(ctx.model, player)
end

FXHandlers.TreeRespawn = function(ctx)
	FXService:FadeIn(ctx.model)
end

ChopFX.OnClientEvent:Connect(function(fxType, ctx)
	print(fxType)
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
		track:Play()
		if player:GetAttribute("InZone") then
			ChopEvent:FireServer()
		end
	end	
end)





