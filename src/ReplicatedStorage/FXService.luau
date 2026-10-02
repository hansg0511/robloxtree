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

function FXService:playHit(tree, intensityDegrees, totalDuration, shakes)
	if not tree then return end
	local primary = tree.PrimaryPart or tree:FindFirstChildWhichIsA("BasePart")
	if not primary then
		warn("Tree has no PrimaryPart or BasePart to shake")
		return
	end
	local chopAudio = chopSound:Clone()
	chopAudio.Parent = primary
	chopAudio:Play()
	Debris:AddItem(chopAudio, 1)
	intensityDegrees = intensityDegrees or 6    -- max rotation degrees per axis
	totalDuration = totalDuration or 0.6        -- total shake duration
	shakes = shakes or 6                        -- number of shake pulses
	local originalCFrame = primary.CFrame
	local step = totalDuration / (shakes * 2)
	
	
	
	for i = 1, shakes do
		local rx = math.rad((math.random() * 2 - 1) * intensityDegrees)
		local ry = math.rad((math.random() * 2 - 1) * intensityDegrees)
		local rz = math.rad((math.random() * 2 - 1) * intensityDegrees)
		local offsetY = (math.random() * 2 - 1) * 0.03 -- tiny up/down jitter

		local target = originalCFrame * CFrame.Angles(rx, ry, rz) * CFrame.new(0, offsetY, 0)

		local t1 = TweenService:Create(primary, TweenInfo.new(step, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = target})
		t1:Play()
		t1.Completed:Wait()

		local t2 = TweenService:Create(primary, TweenInfo.new(step, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {CFrame = originalCFrame})
		t2:Play()
		--t2.Completed:Wait()
	end

	primary.CFrame = originalCFrame
end

function FXService:TreeFall(model, player)
	if not model or not model.Parent then return end
	local treeModel = model
	local primary = treeModel.PrimaryPart or treeModel:FindFirstChildWhichIsA("BasePart")
	if not primary then treeModel:Destroy() return end
	local pivotCF = treeModel:GetPivot().Position + Vector3.new(0,primary.Size.Y/8,0)



	---- Compute fall direction
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local offsetFromPlayer = root and (primary.Position - root.Position) or Vector3.new(1, 0, 0)
	local dir = offsetFromPlayer.Magnitude > 0 and -offsetFromPlayer.Unit or Vector3.new(1, 0, 0)
	local fallAxis = Vector3.new(-dir.Z, 0, dir.X).Unit
	local angle = math.rad(75) -- tree falls over
	local rotation = CFrame.fromAxisAngle(fallAxis, angle)
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
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = newCFrame }
	)
	fallTween:Play()
	fallTween.Completed:Wait()
	task.delay(0.5 + 0.2, function()
		TweenService:Create(
			primary,
			TweenInfo.new(0.8),
			{ Transparency = 1 }
		):Play()
	Debris:AddItem(treeModel, 1)
	end)
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
