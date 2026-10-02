-- Wait for the existing base shell, then add the source-controlled forest corridor.
local Workspace = game:GetService("Workspace")
local WorldLayoutService = require(script.Parent.WorldLayoutService)

Workspace:WaitForChild("BaseGround")
WorldLayoutService.Build()
