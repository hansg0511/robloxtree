local Tool = script.Parent
local Handle = Tool:WaitForChild("Handle")
local Player
local Character
local Humanoid
--local TEAM
local VisualizeBullet = script.Parent:WaitForChild("VisualizeBullet")
local Module = require(Tool:WaitForChild("Setting"))
local ChangeAmmoAndClip = script:WaitForChild("ChangeAmmoAndClip")
local InflictTarget = script:WaitForChild("InflictTarget")
local Grip2
local Handle2

if Module.DualEnabled then
	Handle2 = Tool:WaitForChild("Handle2",1)
	if Handle2 == nil and Module.DualEnabled then error("\"Dual\" setting is enabled but \"Handle2\" is missing!") end
end

local AmmoValue = script:FindFirstChild("Ammo") or Instance.new("NumberValue",script)
AmmoValue.Name = "Ammo"
AmmoValue.Value = Module.AmmoPerClip
local ClipsValue = script:FindFirstChild("Clips") or Instance.new("NumberValue",script)
ClipsValue.Name = "Clips"
ClipsValue.Value = Module.LimitedClipEnabled and Module.Clips or 0

if Module.IdleAnimationID ~= nil or Module.DualEnabled then
	local IdleAnim = Instance.new("Animation",Tool)
	IdleAnim.Name = "IdleAnim"
	IdleAnim.AnimationId = "rbxassetid://"..(Module.DualEnabled and 53610688 or Module.IdleAnimationID)
end
if Module.FireAnimationID ~= nil then
	local FireAnim = Instance.new("Animation",Tool)
	FireAnim.Name = "FireAnim"
	FireAnim.AnimationId = "rbxassetid://"..Module.FireAnimationID
end
if Module.ReloadAnimationID ~= nil then
	local ReloadAnim = Instance.new("Animation",Tool)
	ReloadAnim.Name = "ReloadAnim"
	ReloadAnim.AnimationId = "rbxassetid://"..Module.ReloadAnimationID
end
if Module.ShotgunClipinAnimationID ~= nil then
	local ShotgunClipinAnim = Instance.new("Animation",Tool)
	ShotgunClipinAnim.Name = "ShotgunClipinAnim"
	ShotgunClipinAnim.AnimationId = "rbxassetid://"..Module.ShotgunClipinAnimationID
end

ChangeAmmoAndClip.OnServerEvent:connect(function(Player,Ammo,Clips)
	AmmoValue.Value = Ammo
	ClipsValue.Value = Clips
end)
InflictTarget.OnServerEvent:connect(function(Player,TargetHumanoid,TargetTorso,Damage,Direction,Knockback,Lifesteal,FlamingBullet)
	if Player and TargetHumanoid and TargetHumanoid.Health ~= 0 and TargetTorso then
		while TargetHumanoid:FindFirstChild("creator") do
			TargetHumanoid.creator:Destroy()
		end
		local creator = Instance.new("ObjectValue",TargetHumanoid)
		creator.Name = "creator"
		creator.Value = Player
		game.Debris:AddItem(creator,5)
		TargetHumanoid:TakeDamage(Damage)
		if Knockback > 0 then
			TargetTorso.Velocity = Direction * Knockback
		end
		if Lifesteal > 0 and Humanoid and Humanoid.Health ~= 0 then
			Humanoid.Health = Humanoid.Health + (Damage*Lifesteal)
		end
		if FlamingBullet then
			local Debuff = TargetHumanoid.Parent:FindFirstChild("IgniteScript") or script.IgniteScript:Clone()
			Debuff.creator.Value = Player
			Debuff.Disabled = false
			Debuff.Parent = TargetHumanoid.Parent
		end
	end
end)

Tool.Equipped:connect(function()
	Player = game.Players:GetPlayerFromCharacter(Tool.Parent)
	Character = Tool.Parent
	Humanoid = Character:FindFirstChild("Humanoid")
	--TEAM = Character:FindFirstChild("TEAM")
	if Module.DualEnabled and Workspace.FilteringEnabled then
		Handle2.CanCollide = false
		local LeftArm = Tool.Parent:FindFirstChild("Left Arm")
		local RightArm = Tool.Parent:FindFirstChild("Right Arm")
		if RightArm then
			local Grip = RightArm:WaitForChild("RightGrip",0.01)
			if Grip then
				Grip2 = Grip:Clone()
				Grip2.Name = "LeftGrip"
				Grip2.Part0 = LeftArm
				Grip2.Part1 = Handle2
				--Grip2.C1 = Grip2.C1:inverse()
				Grip2.Parent = LeftArm
			end
		end
	end
end)

Tool.Unequipped:connect(function()
	if Module.DualEnabled and Workspace.FilteringEnabled then
		Handle2.CanCollide = true
		if Grip2 then Grip2:Destroy() end
	end
end)