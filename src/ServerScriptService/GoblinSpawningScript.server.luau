local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage") -- optional
local Workspace = game:GetService("Workspace")

local goblinTemplate = ServerStorage:WaitForChild("Goblin") -- optional: Folder with parts to spawn near

local spawnInterval = 5 -- seconds

--while true do
--	wait(spawnInterval)

--	local goblin = goblinTemplate:Clone()

--	goblin.PrimaryPart.CFrame = CFrame.new(Vector3.new(0,10,0))
--	goblin.Parent = Workspace
--end

