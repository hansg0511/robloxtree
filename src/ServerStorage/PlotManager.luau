local PlotManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local plotTemplate = ServerStorage.PlotTemplate
local TreeObj = require(game.ServerScriptService.Trees.TreeObject)

local function getPrimaryPart(model)
	if not model then return nil end
	if model.PrimaryPart then return model.PrimaryPart end
	for _, child in pairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

PlotManager.playerPlotMap = {} ---- DEPRECATED -------

--function PlotManager.spawnPassivePlots(player, passivePlotNumber)
--		if not passivePlotNumber then
--			warn("PlotManager.updatePassivePlots requires a passivePlotNumber")
--			return end
		
--		local mainPlot = PlotManager.playerPlotMap[player]
--		local mainPivot = mainPlot.PlotModel:GetPivot()	
--		local passiveTemplate = ServerStorage.PassivePlots[1]
--		local clone = passiveTemplate:Clone()
		
--		local mainPos = mainPivot.Position
--		local mainRot = mainPlot.Name * -60
--		local x = mainPos.x - 50 * math.sin(math.rad(passivePlotNumber * 45 -(90-mainRot)))
--		local z = mainPos.z + 50 * math.cos(math.rad(passivePlotNumber * 45 -(90-mainRot)))
		
--		local rotation = passivePlotNumber * 45
			
--		clone:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad((2 - passivePlotNumber) * 45), 0) * passiveTemplate:GetPivot().Rotation )
--		clone.Parent = mainPlot.PlotModel
--		clone.Name = passivePlotNumber
--		return clone
--end



function PlotManager.spawnPassivePlotsCFrame(CFramee)
	local passiveTemplate = ServerStorage.PassivePlotTemplate[1]
	local clone = passiveTemplate:Clone()
	local plotFolder = PlotManager.playerPlotMap
	clone:PivotTo(CFramee)
	clone.Parent = workspace
	clone.Name = "clone"
	return clone
end

function PlotManager.savePassivePlots()
	local passivePositions = {}
	for _, plotFolder in ipairs(workspace.PlayerPlots:GetChildren()) do
		passivePositions[plotFolder.Name] = {}
		for i = 0, 4 do
			local plot = plotFolder.PlotModel
			local mainPivot = plot:GetPivot()	


			local mainPos = mainPivot.Position
			local mainRot = plotFolder.Name * -60
			local x = mainPos.x - 40 * math.sin(math.rad(i * 45 -(90-mainRot)))
			local z = mainPos.z + 40 * math.cos(math.rad(i * 45 -(90-mainRot)))

			local LatestCFrame = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad((2 - i) * 45 - mainRot), 0) * CFrame.fromEulerAnglesXYZ(0, math.rad(22.402), math.rad(90))
			passivePositions[plotFolder.Name][i] = LatestCFrame
		end
	end
	return passivePositions
end

local passivePositions = PlotManager.savePassivePlots()

function PlotManager.spawnPassivePlots(player, passivePlotNumber)
	local plotFolder = PlotManager.playerPlotMap[player]
	local mainPlot = plotFolder.PlotModel
	passivePositions = PlotManager.savePassivePlots()
	local CFramee = passivePositions[plotFolder.Name][passivePlotNumber]
	local clone = PlotManager.spawnPassivePlotsCFrame(CFramee)
	clone.Parent = mainPlot
	clone.Name = passivePlotNumber
end


function PlotManager.surroundPlotWithBushes(plotModel, bushTemplates, count, radius)
	if not plotModel or not radius then
		warn("surroundPlotWithBushes requires plotModel, radius and count")
		return
	end

	local centerPart = getPrimaryPart(plotModel)
	if not centerPart then
		warn("plotModel has no PrimaryPart or BasePart to use as center")
		return
	end

	-- create container for the ring
	local ringModel = Instance.new("Model")
	ringModel.Name = "BushRing"

	local startAngleDeg = -60

	for i = 1, count do
		-- base angle around circle for this index (radians)
		local angle = math.rad(startAngleDeg) + (7/4 * math.pi) * ((i - 1) / count)
		-- per-bush angular displacement in degrees (cycles if fewer provided)


		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local worldPos = centerPart.Position + Vector3.new(x, 2.4, z)
		local worldPosCFrame = CFrame.new(worldPos)

		-- optionally raycast down to ground to find Y
		local finalPos = worldPosCFrame

		-- choose template and clone
		local templates = bushTemplates:GetChildren()
		local template = templates[math.random(1,3)]

		local clone = template:Clone()
		clone.Parent = ringModel
		local cf = template:GetPivot()

		-- find a primary part for the clone
		local clonePrimary = getPrimaryPart(clone)
		clonePrimary.Anchored = true
		clonePrimary.CanCollide = false
		if clonePrimary then
			clone:SetPrimaryPartCFrame(finalPos * cf.Rotation)
			if template.Name == "Model" then
				clone:SetPrimaryPartCFrame(finalPos * cf.Rotation * CFrame.Angles(0, math.rad(80-math.deg(angle)), 0))
			end
		end
		ringModel.Parent = plotModel.Parent
	end
	
	local ringPos = ringModel:GetPivot()
	local finalRot = ringPos * CFrame.Angles(0, math.rad((2 - plotModel.Name) * 45), 0)
	ringModel:PivotTo(finalRot)
	
	return ringModel
end

function PlotManager.buildPlots()
	local radius = 125
	for i = 0,5 do
		local plot = plotTemplate:Clone()
		plot.Name = i
		plot.PlotModel.OwnerDisplay.TextLabel.Text = "Plot" .. i --For development purposes
		plot.PlotID.Value = i
		local x = radius * math.sin(i * math.pi/3)
		local z = radius * math.cos(i * math.pi/3)
		local position = CFrame.new(x,0,z)
		local rotation = CFrame.Angles(0, math.rad(90) + i * math.rad(60), math.rad(90))
		plot.PlotModel:PivotTo(position * rotation)
		plot.Parent = workspace.PlayerPlots
	end
end



function PlotManager.assignPlot(player)
	local Plots = workspace.PlayerPlots
	for i, plot in ipairs(Plots:GetChildren()) do
		if plot.Occupancy.Value == true then 
			continue
		else 
			plot.Occupancy.Value = true
			plot.PlotModel.OwnerDisplay.TextLabel.Text = player.Name .. "'s Plot"
			plot.OwnerID.Value = player.UserId
			PlotManager.playerPlotMap[player] = plot
			player:SetAttribute("PlotNumber", plot.Name)
			return
		end
	end
end

function PlotManager.CreateTree(player, passivePlotNumber)
	local plotFolder = PlotManager.playerPlotMap[player]
	local tree = TreeObj.new(player, plotFolder, "Basic", passivePlotNumber)
	--local position
	--local plotModel
	--if not passivePlotNumber then
	--	plotModel = workspace.PlayerPlots[plotNumber].PlotModel
	--	position = plotModel:GetPivot()
	--else 
	--	plotModel = workspace.PlayerPlots[plotNumber].PlotModel[passivePlotNumber]
	--	position = plotModel:GetPivot()
	--end
	
	
	--local treePart = ServerStorage.TreeTypes:FindFirstChild(treeType):Clone()
	--local primary = treePart.PrimaryPart
	--if not primary then return end

	--treePart:PivotTo(CFrame.new(position.Position) * (CFrame.Angles(math.rad(0), plotNumber * math.rad(45), math.rad(0))))
	--treePart.Parent = plotModel
	--treePart.Name = "Tree"
	return tree
end

function PlotManager.CleanUp(player)
	TreeCache[player] = nil
	PlotManager.playerPlotMap[player] = nil
end



return PlotManager
