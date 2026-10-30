local FXService = {}
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HarvestVisualConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HarvestVisualConfig"))

local ContentProvider = game:GetService("ContentProvider")
local sounds = game.ReplicatedStorage.LeavesSound:GetChildren()

local soundIds = {
	"rbxassetid://159798370",
}

local chopSound = Instance.new("Sound")
chopSound.SoundId = soundIds[1]
chopSound.Volume = 3
chopSound.Parent = workspace -- must be parented
table.insert(sounds, chopSound)

ContentProvider:PreloadAsync(sounds)

local HIT_KICK_DURATION = 0.06
local HIT_REBOUND_DURATION = 0.13
local TREE_FALL_DURATION = HarvestVisualConfig.FallDuration
local POST_IMPACT_PAUSE = 0.15
local TREE_FADE_DURATION = 0.65
local DROP_REVEAL_FADE_OFFSET = 0.15
local IMPACT_LEAF_SHRINK_DURATION = HarvestVisualConfig.LeafShrinkDuration
local IMPACT_SMOKE_DURATION = HarvestVisualConfig.ImpactSmokeDuration
local activeHitByTree = setmetatable({}, { __mode = "k" })

local function cancelHitTween(tree, restoreCFrame)
	local state = activeHitByTree[tree]
	if not state then
		return
	end
	activeHitByTree[tree] = nil
	if state.Tween then
		state.Tween:Cancel()
	end
	if restoreCFrame and state.Primary and state.Primary.Parent then
		state.Primary.CFrame = state.BaseCFrame
	end
end

function FXService:playHit(tree)
	if not tree then return end
	local primary = tree.PrimaryPart or tree:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("Tree has no PrimaryPart or BasePart to shake")
		return
	end
	cancelHitTween(tree, true)
	local chopAudio = chopSound:Clone()
	chopAudio.Parent = primary
	chopAudio:Play()
	Debris:AddItem(chopAudio, 1)

	local baseCFrame = primary.CFrame
	local state = { Primary = primary, BaseCFrame = baseCFrame }
	activeHitByTree[tree] = state
	local kickCFrame = baseCFrame
		* CFrame.new(0, 0.035, 0)
		* CFrame.Angles(math.rad(-3.5), 0, math.rad(2.5))
	local kickTween = TweenService:Create(
		primary,
		TweenInfo.new(HIT_KICK_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = kickCFrame }
	)
	state.Tween = kickTween
	kickTween.Completed:Connect(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed
			or activeHitByTree[tree] ~= state
			or not primary.Parent then
			return
		end

		local reboundTween = TweenService:Create(
			primary,
			TweenInfo.new(HIT_REBOUND_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = baseCFrame }
		)
		state.Tween = reboundTween
		reboundTween.Completed:Connect(function(reboundState)
			if activeHitByTree[tree] ~= state then
				return
			end
			if reboundState == Enum.PlaybackState.Completed and primary.Parent then
				primary.CFrame = baseCFrame
			end
			activeHitByTree[tree] = nil
		end)
		reboundTween:Play()
	end)
	kickTween:Play()
end

function FXService.GetTreeFallRotation(model, player)
	if not model or not model.Parent then return CFrame.identity end
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not primary then return CFrame.identity end

	-- Compute the same server-observed fall direction used by TreeFall. Keeping
	-- the resulting rotation lets harvest visuals share the actual fall path.
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local offsetFromPlayer = root and (primary.Position - root.Position) or Vector3.new(1, 0, 0)
	local dir = offsetFromPlayer.Magnitude > 0 and -offsetFromPlayer.Unit or Vector3.new(1, 0, 0)
	local fallAxis = Vector3.new(-dir.Z, 0, dir.X)
	if fallAxis.Magnitude <= 1e-4 then
		local modelFrame = model:GetPivot()
		local fallback = Vector3.new(modelFrame.LookVector.X, 0, modelFrame.LookVector.Z)
		if fallback.Magnitude <= 1e-4 then
			fallback = Vector3.new(modelFrame.RightVector.X, 0, modelFrame.RightVector.Z)
		end
		if fallback.Magnitude <= 1e-4 then fallback = Vector3.xAxis end
		fallback = fallback.Unit
		fallAxis = Vector3.new(-fallback.Z, 0, fallback.X)
	end
	local fallAngle = if model:GetAttribute("ProceduralStarterOak") == true then math.rad(70) else math.rad(75)
	return CFrame.fromAxisAngle(fallAxis.Unit, fallAngle)
end

local function shrinkAttachedLeaves(treeModel, duration)
	local isProceduralOak = treeModel:GetAttribute("ProceduralStarterOak") == true
	local folderNames = { "Leaves" }
	if isProceduralOak then
		table.insert(folderNames, "FoliageDecorations")
		table.insert(folderNames, "DecorativeBranches")
		table.insert(folderNames, "DecorativeBark")
	end

	local tweens = {}
	local seenParts = {}
	for _, folderName in ipairs(folderNames) do
		local folder = treeModel:FindFirstChild(folderName)
		if folder then
			for _, descendant in ipairs(folder:GetDescendants()) do
				local isSurvivingBarkAccent = isProceduralOak
					and descendant:GetAttribute("HarvestableBarkAccent") == true
				if descendant:IsA("BasePart") and not isSurvivingBarkAccent and not seenParts[descendant] then
					seenParts[descendant] = true
					descendant.CanCollide = false
					local size = descendant.Size
					local tween = TweenService:Create(
						descendant,
						TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{
							Size = Vector3.new(
								math.max(size.X * 0.02, 0.001),
								math.max(size.Y * 0.02, 0.001),
								math.max(size.Z * 0.02, 0.001)
							),
							Transparency = 1,
						}
					)
					table.insert(tweens, tween)
					tween:Play()
				end
			end
		end
	end

	if #tweens > 0 then
		task.wait(duration)
		for _, tween in ipairs(tweens) do
			tween:Destroy()
		end
	end
end

local function playImpactSmoke(position, options)
	if options.SmokeEnabled == false then return end

	local duration = math.clamp(options.SmokeDuration or IMPACT_SMOKE_DURATION, 0.12, 1.5)
	local color = options.SmokeColor or Color3.fromRGB(142, 133, 121)
	local offsets = {
		Vector3.new(-0.45, 0, -0.25),
		Vector3.new(0.4, 0.05, -0.35),
		Vector3.new(-0.15, 0.1, 0.45),
		Vector3.new(0.45, -0.05, 0.35),
	}

	for index, offset in ipairs(offsets) do
		local puff = Instance.new("Part")
		puff.Name = "TreeImpactSmokePuff"
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = color
		puff.Transparency = 0.38
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanTouch = false
		puff.CanQuery = false
		puff.CastShadow = false
		puff.Size = Vector3.new(1.2, 0.9, 1.2)
		puff.CFrame = CFrame.new(position + offset)
		puff.Parent = workspace

		local spread = offset.Unit * 1.1
		local sizeScale = 1.8 + (index % 2) * 0.25
		local tween = TweenService:Create(
			puff,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = position + spread + Vector3.new(0, 0.8, 0),
				Size = Vector3.new(1.2, 0.9, 1.2) * sizeScale,
				Transparency = 1,
			}
		)
		local completedConnection
		completedConnection = tween.Completed:Connect(function()
			completedConnection:Disconnect()
			if puff.Parent then puff:Destroy() end
			tween:Destroy()
		end)
		tween:Play()
		Debris:AddItem(puff, duration + 0.25)
		Debris:AddItem(tween, duration + 0.25)
	end
end

local function getProceduralOakHingeLocal(treeModel, startPivot, fallRotation)
	local rootFolder = treeModel:FindFirstChild("DecorativeBark")
	local rootFoot = rootFolder and rootFolder:FindFirstChild("RootFoot")
	local supportParts = {}
	if rootFoot and rootFoot:IsA("BasePart") then
		table.insert(supportParts, rootFoot)
	end

	local trunkStructure = treeModel:FindFirstChild("TrunkStructure")
	local harvestableCore = trunkStructure and trunkStructure:FindFirstChild("HarvestableCore")
	local baseSection
	if harvestableCore then
		for _, child in ipairs(harvestableCore:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("AuthoredHarvestSection") == true
				and child:GetAttribute("HarvestSectionIndex") == 1 then
				baseSection = child
				break
			end
		end
	end
	if baseSection then
		for _, descendant in ipairs(baseSection:GetDescendants()) do
			if descendant:IsA("BasePart")
				and descendant:GetAttribute("HarvestableCore") == true
				and (descendant:GetAttribute("CoreBottomY") or 0) <= 1e-4 then
				table.insert(supportParts, descendant)
			end
		end
	end
	if #supportParts == 0 then return nil end

	local fallDirectionWorld = fallRotation:VectorToWorldSpace(Vector3.yAxis)
	local flatDirectionWorld = Vector3.new(fallDirectionWorld.X, 0, fallDirectionWorld.Z)
	if flatDirectionWorld.Magnitude <= 1e-4 then return nil end
	local fallDirectionLocal = startPivot:VectorToObjectSpace(flatDirectionWorld.Unit)
	fallDirectionLocal = Vector3.new(fallDirectionLocal.X, 0, fallDirectionLocal.Z)
	if fallDirectionLocal.Magnitude <= 1e-4 then return nil end
	fallDirectionLocal = fallDirectionLocal.Unit
	local acrossDirectionLocal = Vector3.new(-fallDirectionLocal.Z, 0, fallDirectionLocal.X)

	local corners = {}
	local lowestY = math.huge
	for _, part in ipairs(supportParts) do
		local relativeFrame = startPivot:ToObjectSpace(part.CFrame)
		local half = part.Size * 0.5
		for _, xSign in ipairs({ -1, 1 }) do
			for _, ySign in ipairs({ -1, 1 }) do
				for _, zSign in ipairs({ -1, 1 }) do
					local point = relativeFrame:PointToWorldSpace(Vector3.new(
						xSign * half.X,
						ySign * half.Y,
						zSign * half.Z
					))
					table.insert(corners, point)
					lowestY = math.min(lowestY, point.Y)
				end
			end
		end
	end

	local downhillProjection = -math.huge
	for _, point in ipairs(corners) do
		if point.Y <= lowestY + 0.01 then
			local projection = Vector3.new(point.X, 0, point.Z):Dot(fallDirectionLocal)
			downhillProjection = math.max(downhillProjection, projection)
		end
	end
	if downhillProjection == -math.huge then return nil end

	local acrossMinimum = math.huge
	local acrossMaximum = -math.huge
	for _, point in ipairs(corners) do
		if point.Y <= lowestY + 0.01 then
			local horizontalPoint = Vector3.new(point.X, 0, point.Z)
			local projection = horizontalPoint:Dot(fallDirectionLocal)
			if projection >= downhillProjection - 0.01 then
				local across = horizontalPoint:Dot(acrossDirectionLocal)
				acrossMinimum = math.min(acrossMinimum, across)
				acrossMaximum = math.max(acrossMaximum, across)
			end
		end
	end
	if acrossMinimum == math.huge then return nil end
	return fallDirectionLocal * downhillProjection
		+ acrossDirectionLocal * ((acrossMinimum + acrossMaximum) * 0.5)
		+ Vector3.new(0, lowestY, 0)
end

local function tweenGroundedStarterOakFall(treeModel, fallRotation)
	local progress
	local connection
	local completedConnection
	local tween
	local playbackState
	local pivotError
	local fallOk, landed, hingeWorld = pcall(function()
		local startPivot = treeModel:GetPivot()
		local hingeLocal = getProceduralOakHingeLocal(treeModel, startPivot, fallRotation)
		if not hingeLocal then
			error("Procedural Oak has no valid generated root hinge")
		end
		local hingeWorld = startPivot:PointToWorldSpace(hingeLocal)
		local axis, angle = fallRotation:ToAxisAngle()
		if axis.Magnitude <= 1e-4 or math.abs(angle) <= 1e-4 then
			error("Procedural Oak fall rotation is invalid")
		end

		progress = Instance.new("NumberValue")
		progress.Name = "StarterOakFallProgress"
		progress.Value = 0
		progress.Parent = treeModel
		local function updatePivot()
			if not treeModel.Parent then return end
			local rotation = CFrame.fromAxisAngle(axis, angle * progress.Value)
			local targetPivot = CFrame.new(hingeWorld) * rotation * CFrame.new(-hingeWorld) * startPivot
			local moved, err = pcall(function() treeModel:PivotTo(targetPivot) end)
			if not moved then pivotError = err end
		end
		connection = progress:GetPropertyChangedSignal("Value"):Connect(updatePivot)
		tween = TweenService:Create(
			progress,
			TweenInfo.new(TREE_FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Value = 1 }
		)
		completedConnection = tween.Completed:Connect(function(state)
			playbackState = state
		end)
		tween:Play()
		local deadline = os.clock() + TREE_FALL_DURATION + 0.5
		while playbackState == nil and os.clock() < deadline and treeModel.Parent and progress.Parent do
			task.wait(0.03)
		end
		if playbackState ~= Enum.PlaybackState.Completed and treeModel.Parent and progress.Parent then
			tween:Cancel()
			progress.Value = 1
		end
		if treeModel.Parent and not pivotError then updatePivot() end
		return treeModel.Parent ~= nil and pivotError == nil, hingeWorld
	end)

	if tween and playbackState ~= Enum.PlaybackState.Completed then
		pcall(function() tween:Cancel() end)
	end
	if connection then pcall(function() connection:Disconnect() end) end
	if completedConnection then pcall(function() completedConnection:Disconnect() end) end
	if tween then pcall(function() tween:Destroy() end) end
	if progress and progress.Parent then pcall(function() progress:Destroy() end) end
	if not fallOk then
		warn("Could not finish grounded procedural Oak fall", landed)
		return false, nil
	end
	return landed == true, hingeWorld
end

-- Plays the fall through impact and hands the still-existing tree to the caller.
-- By default, leaves shrink before OnImpact runs. Set ConcurrentLeafShrink to
-- true to start leaf shrinking asynchronously and invoke OnImpact at impact.
-- Options: LeafShrinkDuration, PostImpactPause, SmokeEnabled, SmokeDuration,
-- SmokeColor, OnImpact, ConcurrentLeafShrink.
-- OnImpact receives (treeModel, impactCFrame) and is invoked inline after the
-- shrink by default, or at impact in concurrent mode. If it yields, this
-- function yields until it returns. Callback errors are warned and still
-- produce a successful impact result. Concurrent leaf-shrink errors are also
-- warned; that path does not wait for the leaf effect to finish.
-- Trunk cleanup and presentation remain the caller's responsibility.
function FXService:TreeFallToImpact(model, player, fallRotation, options)
	if not model or not model.Parent then return false end
	options = type(options) == "table" and options or {}
	local treeModel = model
	local primary = treeModel.PrimaryPart or treeModel:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("Tree has no PrimaryPart or BasePart to fall")
		return false
	end

	local rotation = fallRotation or FXService.GetTreeFallRotation(treeModel, player)
	local isProceduralStarterOak = treeModel:GetAttribute("ProceduralStarterOak") == true
	local groundedHingeWorld
	if isProceduralStarterOak then
		local fallCompleted
		fallCompleted, groundedHingeWorld = tweenGroundedStarterOakFall(treeModel, rotation)
		if not fallCompleted then return false end
	else
		local pivotCF = treeModel:GetPivot().Position + Vector3.new(0, primary.Size.Y / 8, 0)
		local offset = primary.Position - pivotCF
		local rotatedOffset = rotation:VectorToWorldSpace(offset)
		local newPosition = pivotCF + rotatedOffset
		local relativeRotation = primary.CFrame - primary.Position
		local newCFrame = CFrame.new(newPosition) * (rotation * relativeRotation)
		local fallTween = TweenService:Create(
			primary,
			TweenInfo.new(TREE_FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = newCFrame }
		)
		fallTween:Play()
		fallTween.Completed:Wait()
		fallTween:Destroy()
	end
	if not treeModel.Parent then return false end

	for _, descendant in ipairs(treeModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	local postImpactPause = options.PostImpactPause
	if type(postImpactPause) ~= "number" or postImpactPause ~= postImpactPause or postImpactPause < 0 then
		postImpactPause = if isProceduralStarterOak then 0.05 else 0
	end
	if postImpactPause > 0 then task.wait(math.clamp(postImpactPause, 0, 1)) end
	if not treeModel.Parent then return false end
	local impactCFrame = if isProceduralStarterOak and groundedHingeWorld
		then CFrame.new(groundedHingeWorld)
		else primary.CFrame
	local leafDuration = math.clamp(
		options.LeafShrinkDuration or IMPACT_LEAF_SHRINK_DURATION,
		0.05,
		0.75
	)
	playImpactSmoke(impactCFrame.Position, options)
	if options.ConcurrentLeafShrink == true then
		task.spawn(function()
			local ok, err = pcall(shrinkAttachedLeaves, treeModel, leafDuration)
			if not ok then
				warn("Could not shrink fallen tree leaves", err)
			end
		end)
	else
		shrinkAttachedLeaves(treeModel, leafDuration)
	end
	if not treeModel.Parent then return false end

	if type(options.OnImpact) == "function" then
		local ok, err = pcall(options.OnImpact, treeModel, impactCFrame)
		if not ok then
			warn("Tree impact callback failed", err)
		end
	end
	return true, impactCFrame
end

function FXService:TreeFall(model, player, fallRotation, onDropReveal)
	if not model or not model.Parent then return end
	local treeModel = model
	local primary = treeModel.PrimaryPart or treeModel:FindFirstChildWhichIsA("BasePart")
	if not primary then treeModel:Destroy() return end
	local isProceduralStarterOak = treeModel:GetAttribute("ProceduralStarterOak") == true
	local rotation = fallRotation or FXService.GetTreeFallRotation(treeModel, player)
	if isProceduralStarterOak then
		local impactCompleted = FXService:TreeFallToImpact(treeModel, player, rotation, {
			ConcurrentLeafShrink = true,
			LeafShrinkDuration = IMPACT_LEAF_SHRINK_DURATION,
			SmokeDuration = IMPACT_SMOKE_DURATION,
		})
		if not impactCompleted then
			if type(onDropReveal) == "function" then pcall(onDropReveal) end
			if treeModel.Parent then treeModel:Destroy() end
			return
		end
	else
		local pivotCF = treeModel:GetPivot().Position + Vector3.new(0, primary.Size.Y / 8, 0)
		local offset = primary.Position - pivotCF
		local rotatedOffset = rotation:VectorToWorldSpace(offset)
		local newPosition = pivotCF + rotatedOffset
		local relativeRotation = primary.CFrame - primary.Position
		local newCFrame = CFrame.new(newPosition) * (rotation * relativeRotation)
		local fallTween = TweenService:Create(
			primary,
			TweenInfo.new(TREE_FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = newCFrame }
		)
		fallTween:Play()
		fallTween.Completed:Wait()
		if not treeModel.Parent then return end
		for _, descendant in ipairs(treeModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
			end
		end
		task.wait(POST_IMPACT_PAUSE)
		if not treeModel.Parent then return end
	end

	-- Fade the whole fallen tree and wait for that fade to finish before
	-- returning, so callers can safely reveal its ground drops afterward.
	local transparencyByPart = {}
	for _, descendant in ipairs(treeModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			transparencyByPart[descendant] = descendant.Transparency
		end
	end

	local fadeAlpha = Instance.new("NumberValue")
	fadeAlpha.Value = 0
	fadeAlpha.Parent = treeModel
	local function updateTransparency()
		local alpha = fadeAlpha.Value
		for part, startTransparency in pairs(transparencyByPart) do
			if part.Parent then
				part.Transparency = startTransparency + (1 - startTransparency) * alpha
			end
		end
	end
	local transparencyConnection = fadeAlpha:GetPropertyChangedSignal("Value"):Connect(updateTransparency)
	local fadeTween = TweenService:Create(
		fadeAlpha,
		TweenInfo.new(TREE_FADE_DURATION),
		{ Value = 1 }
	)
	fadeTween:Play()
	-- Drops are real server-owned pickup models. Let them begin revealing while
	-- the fallen tree is still fading, so the rewards emerge from beneath it.
	if type(onDropReveal) == "function" then
		task.wait(DROP_REVEAL_FADE_OFFSET)
		if treeModel.Parent then
			local ok, err = pcall(onDropReveal)
			if not ok then
				warn("Could not reveal fallen tree log rewards", err)
			end
		end
	end
	fadeTween.Completed:Wait()
	transparencyConnection:Disconnect()
	fadeAlpha:Destroy()
	Debris:AddItem(treeModel, 1)
end

local function PopRandomLeaf(pool)
	local n = #pool
	if n == 0 then return nil end

	local i = math.random(n)

	-- swap-remove (true O(1))
	pool[i], pool[n] = pool[n], pool[i]
	return table.remove(pool)
end



local function DetachLeafWelds(treeModel, leaf)
	for _, obj in ipairs(treeModel:GetDescendants()) do
		if obj:IsA("WeldConstraint") then
			if obj.Part0 == leaf or obj.Part1 == leaf then
				obj:Destroy()
			end
		end
	end
end

local function GetGroundY(origin, treeModel)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {treeModel}

	local result = workspace:Raycast(
		origin,
		Vector3.new(0, -200, 0),
		rayParams
	)

	if result then
		return result.Position.Y
	end

	-- fallback
	return origin.Y - 20
end

local function TweenDropLeaf(treeModel, leaf)
	--if not leaf or not leaf:IsA("BasePart") then return end
	--if leaf:GetAttribute("Detached") then return end

	--leaf:SetAttribute("Detached", true)

	-- Detach welds
	DetachLeafWelds(treeModel, leaf)

	-- Control motion manually
	leaf.Anchored = true
	leaf.CanCollide = false

	local startCF = leaf.CFrame
	local groundY = GetGroundY(startCF.Position, treeModel)

	local endPos = Vector3.new(
		startCF.Position.X + math.random(-2, 2),
		groundY + 0.2,
		startCF.Position.Z + math.random(-2, 2)
	)

	local fallTime = math.clamp(
		(startCF.Position.Y - groundY) / 15,
		0.6,
		1.2
	)

	local fallTween = TweenService:Create(
		leaf,
		TweenInfo.new(
			fallTime,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),
		{
			Position = endPos,
			Orientation = Vector3.new(
				math.random(-180, 180),
				math.random(-180, 180),
				math.random(-180, 180)
			)
		}
	)

	fallTween:Play()

	-- Fade AFTER landing
	task.delay(fallTime + 0.2, function()
		TweenService:Create(
			leaf,
			TweenInfo.new(0.4),
			{ Transparency = 1 }
		):Play()

		Debris:AddItem(leaf, 1)
	end)
end

local function PlayLeafSound(treeModel)
	local sounds = game.ReplicatedStorage.LeavesSound:GetChildren()
	local sound = sounds[math.random(1,3)]:Clone()
	sound.Parent = treeModel
	sound.Volume = 0.2
	sound:Play()
	game.Debris:AddItem(sound, 2)
end


function FXService:FadeIn(treeModel)
	local duration =  0.5

	local parts = {}
	for _, obj in ipairs(treeModel:GetDescendants()) do
		if obj:IsA("BasePart") then
			if obj:GetAttribute("AlwaysInvisible") then
				obj.Transparency = 1
			else
				table.insert(parts, obj)
				obj.Transparency = 1
			end
		end
	end

	local alpha = Instance.new("NumberValue")
	alpha.Value = 1
	alpha.Parent = treeModel

	alpha:GetPropertyChangedSignal("Value"):Connect(function()
		local v = alpha.Value
		for _, part in ipairs(parts) do
			part.Transparency = v
		end
	end)

	TweenService:Create(
		alpha,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = 0 }
	):Play()

	task.delay(duration, function()
		alpha:Destroy()
	end)
end
--local function PlayChopSound(position)
--	local sound = chopSound:Clone()
--	sound.Parent = workspace
--	sound.Position = position
--	sound:Play()
--	game.Debris:AddItem(sound, 2) -- cleanup
--end

function FXService:DropLeaves(treeModel, pool, count)
	for i = 1, count do
		local leaf = PopRandomLeaf(pool)
		if not leaf then break end
		PlayLeafSound(treeModel)
		TweenDropLeaf(treeModel, leaf)
		
		-- slight stagger so it looks organic
		task.wait(math.random() * 0.03)
	end
end



return FXService
