local FXService = {}
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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
local TREE_FALL_DURATION = 1.0
local POST_IMPACT_PAUSE = 0.15
local TREE_FADE_DURATION = 0.65
local DROP_REVEAL_FADE_OFFSET = 0.15
local IMPACT_LEAF_SHRINK_DURATION = 0.18
local IMPACT_SMOKE_DURATION = 0.42
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
	return CFrame.fromAxisAngle(fallAxis.Unit, math.rad(75))
end

local function shrinkAttachedLeaves(treeModel, duration)
	local leavesFolder = treeModel:FindFirstChild("Leaves")
	if not leavesFolder then return end

	local tweens = {}
	for _, descendant in ipairs(leavesFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
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

-- Plays the fall through its impact and hands the still-existing tree to the
-- caller. Leaves remain attached until impact, then shrink before OnImpact runs.
-- Options: LeafShrinkDuration, SmokeEnabled, SmokeDuration, SmokeColor, OnImpact.
-- OnImpact receives (treeModel, impactCFrame); trunk cleanup belongs to caller.
function FXService:TreeFallToImpact(model, player, fallRotation, options)
	if not model or not model.Parent then return false end
	options = type(options) == "table" and options or {}
	local treeModel = model
	local primary = treeModel.PrimaryPart or treeModel:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("Tree has no PrimaryPart or BasePart to fall")
		return false
	end

	local pivotCF = treeModel:GetPivot().Position + Vector3.new(0, primary.Size.Y / 8, 0)
	local rotation = fallRotation or FXService.GetTreeFallRotation(treeModel, player)
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
	if not treeModel.Parent then return false end

	for _, descendant in ipairs(treeModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	local impactCFrame = primary.CFrame
	local leafDuration = math.clamp(
		options.LeafShrinkDuration or IMPACT_LEAF_SHRINK_DURATION,
		0.05,
		0.75
	)
	playImpactSmoke(impactCFrame.Position, options)
	shrinkAttachedLeaves(treeModel, leafDuration)
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
	local pivotCF = treeModel:GetPivot().Position + Vector3.new(0,primary.Size.Y/8,0)
	local rotation = fallRotation or FXService.GetTreeFallRotation(treeModel, player)
	--local offset = rotatedPivot:ToObjectSpace(pivotCF)
	local offset = primary.Position - pivotCF

	-- 2️⃣ Rotate the vector
	local rotatedOffset = rotation:VectorToWorldSpace(offset)

	-- 3️⃣ New position
	local newPosition = pivotCF + rotatedOffset

	-- 4️⃣ Rotate the part’s orientation
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
