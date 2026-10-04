-- Minimal, source-controlled world shell. Future corridor geometry belongs in a
-- dedicated world package; do not restore the archived low-poly environment.
local Workspace = game:GetService("Workspace")

local ground = Workspace:FindFirstChild("BaseGround")
if not ground then
	ground = Instance.new("Part")
	ground.Name = "BaseGround"
	ground.Parent = Workspace
end

ground.Size = Vector3.new(260, 1, 240)
ground.CFrame = CFrame.new(0, -1, -5)
ground.Anchored = true
ground.Material = Enum.Material.Plastic
ground.Color = Color3.fromRGB(85, 119, 73)
ground.TopSurface = Enum.SurfaceType.Studs

local spawn = Workspace:FindFirstChild("BaseSpawn")
if not spawn then
	spawn = Instance.new("SpawnLocation")
	spawn.Name = "BaseSpawn"
	spawn.Parent = Workspace
end

spawn.Size = Vector3.new(8, 1, 8)
-- Keep the playtest start at the clear path entrance to Starter Forest.
spawn.CFrame = CFrame.new(0, 0.1, 112)
spawn.Anchored = true
spawn.Neutral = true
spawn.Color = Color3.fromRGB(255, 214, 75)
spawn.Material = Enum.Material.Plastic
spawn.TopSurface = Enum.SurfaceType.Studs
