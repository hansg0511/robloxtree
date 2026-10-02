-- Minimal, source-controlled world shell. Future corridor geometry belongs in a
-- dedicated world package; do not restore the archived low-poly environment.
local Workspace = game:GetService("Workspace")

if not Workspace:FindFirstChild("BaseGround") then
	local ground = Instance.new("Part")
	ground.Name = "BaseGround"
	ground.Size = Vector3.new(250, 1, 100)
	ground.CFrame = CFrame.new(0, -1, 0)
	ground.Anchored = true
	ground.Material = Enum.Material.Plastic
	ground.Color = Color3.fromRGB(89, 192, 105)
	ground.TopSurface = Enum.SurfaceType.Studs
	ground.Parent = Workspace
end

if not Workspace:FindFirstChild("BaseSpawn") then
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BaseSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.1, -34)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(255, 214, 75)
	spawn.Material = Enum.Material.Plastic
	spawn.TopSurface = Enum.SurfaceType.Studs
	spawn.Parent = Workspace
end
