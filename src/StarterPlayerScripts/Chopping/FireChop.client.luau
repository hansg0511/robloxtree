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

ChopFX.OnClientEvent:Connect(function(fxType, ctx)
	local handler = FXHandlers[fxType]
	if handler then
		handler(ctx)
	else
		warn("Unknown FXType: ", fxType)
	end
end)

local function isChopInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonR2)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if isChopInput(input) then
		if track then track:Play() end
		-- Intent only: the server finds the closest eligible tree itself.
		ChopEvent:FireServer()
	end
end)





