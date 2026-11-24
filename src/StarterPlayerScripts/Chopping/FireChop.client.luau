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

local nextLocalSwingAt = 0
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if isChopInput(input) then
		local rate
		local hasAxe = false
		local fervorStacks, fervorPerStack, fervorExpiresAt
		local character = player.Character
		if character then
			for _, tool in ipairs(character:GetChildren()) do
				if tool:IsA("Tool") and tool:GetAttribute("EquippedAxe") == true then
					hasAxe = true
					rate = tool:GetAttribute("CraftAttackRate")
					fervorStacks = tool:GetAttribute("FervorStacks")
					fervorPerStack = tool:GetAttribute("FervorSpeedPerStack")
					fervorExpiresAt = tool:GetAttribute("FervorExpiresAtServerTime")
					break
				end
			end
		end
		if not hasAxe then
			-- The server selects and animates a valid R6 punch. Never play
			-- the axe animation on a character without an equipped axe.
			if character and not character:FindFirstChildOfClass("Tool") then
				local now = os.clock()
				if now >= nextLocalSwingAt then
					nextLocalSwingAt = now + 0.4
					ChopEvent:FireServer()
				end
			end
			return
		end
		local interval = 0.3
		local animationBaseRate = 1
		if type(rate) == "number" and rate == rate and rate >= 0.1 and rate <= 10 then
			interval = math.max(0.3, 1 / rate)
			animationBaseRate = math.clamp(rate, 0.5, 1 / 0.3)
		end
		local baseInterval = interval
		local speedMultiplier = 1
		-- Studio/live Fervor updates originate only from successful server
		-- chops. Use server time, not the client's local os.clock(), so the
		-- combo expires reliably across different client/server clocks.
		if type(fervorStacks) == "number" and fervorStacks >= 1
			and fervorStacks <= 8 and fervorStacks % 1 == 0
			and type(fervorPerStack) == "number" and fervorPerStack > 0
			and fervorPerStack <= 0.3
			and type(fervorExpiresAt) == "number"
			and workspace:GetServerTimeNow() <= fervorExpiresAt then
			speedMultiplier = 1 + fervorStacks * fervorPerStack
			interval = math.max(0.16, interval / speedMultiplier)
		end
		local now = os.clock()
		if now < nextLocalSwingAt then return end
		nextLocalSwingAt = now + interval
		if track then
			-- Follow the actual interval ratio, including the server-matched 0.16s floor.
			local animationRate = animationBaseRate * baseInterval / interval
			track:Play(0.05, 1, math.clamp(animationRate, 0.5, 1 / 0.16))
		end
		-- Intent only: the server validates hit rate and selects the target.
		ChopEvent:FireServer()
	end
end)





