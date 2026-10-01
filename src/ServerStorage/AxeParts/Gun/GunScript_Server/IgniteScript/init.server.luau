local Humanoid = script.Parent:FindFirstChild("Humanoid")
local Torso = script.Parent:FindFirstChild("Torso")
local Fires = {}
local FireDamagePerSecond = 5

function wait(TimeToWait)
	if TimeToWait ~= nil then
		local TotalTime = 0
		TotalTime = TotalTime + game:GetService("RunService").Heartbeat:wait()
		while TotalTime < TimeToWait do
			TotalTime = TotalTime + game:GetService("RunService").Heartbeat:wait()
		end
	else
		game:GetService("RunService").Heartbeat:wait()
	end
end

if Humanoid and Torso then
	BurnSound = Instance.new("Sound")
	BurnSound.Name = "BurnSound"
	BurnSound.SoundId = "http://www.roblox.com/asset/?id=32791565"
	BurnSound.Parent = Torso
	BurnSound.Volume = 1
	game.Debris:AddItem(BurnSound,10)
	Delay(0,function()
		BurnSound:Play()
	end)
	for _,parts in pairs(script.Parent:GetChildren()) do
		if parts.className == "Part" or parts.className == "WedgePart" or parts.className == "CornerWedgePart" then
			local firer = Instance.new("Fire")
			table.insert(Fires,firer)
			firer.Size = 5 + (parts.Size.magnitude*1.5)
			firer.Parent = parts
		end
	end
	while script.Duration.Value > 0 do
		wait(0.1)
		script.Duration.Value = script.Duration.Value - 0.1
		while Humanoid:FindFirstChild("creator") do
			Humanoid.creator:Destroy()
		end
		local Tag = script.creator:clone()
		Tag.Parent = Humanoid
		game.Debris:AddItem(Tag,5)
		Humanoid:TakeDamage(FireDamagePerSecond*0.1)
	end
	for _, Fire in pairs(Fires) do
		Fire.Enabled = false
	end
	wait(5)
	for _, Fire in pairs(Fires) do
		Fire:Destroy()
	end
end
wait()
script:remove()
