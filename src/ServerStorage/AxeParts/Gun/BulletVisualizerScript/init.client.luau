local BE = script:WaitForChild("Visualize")
local RE = script.Parent:WaitForChild("VisualizeBullet")

function VisualizeBullet(Player,Handle,MuzzleOffset,EndPos,MuzzleEffect,HitEffect,HitSound,ExplosiveData,BulletData,VisualizeExplosion,VisualizeEnabled)
	if Player ~= game.Players.LocalPlayer then
		if Handle then
			local MuzzlePos = (Handle.CFrame * CFrame.new(MuzzleOffset.X,MuzzleOffset.Y,MuzzleOffset.Z)).p
			local Distance = (MuzzlePos-EndPos).magnitude/2
		
			local Muzzle = Instance.new("Part")
			Muzzle.Name = "Bullet"
			Muzzle.Size = Vector3.new(0.01,0.01,0.01)
			Muzzle.Transparency = 1
			Muzzle.Anchored = false
			Muzzle.CanCollide = false
			Muzzle.TopSurface = Enum.SurfaceType.SmoothNoOutlines
			Muzzle.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
			local Particle = MuzzleEffect:Clone()
			Particle.Parent = Muzzle
			local Weld = Instance.new("Weld",Muzzle)
			Weld.Part0 = Handle
			Weld.Part1 = Muzzle
			Weld.C0 = CFrame.new(MuzzleOffset.X,MuzzleOffset.Y,MuzzleOffset.Z)
			Muzzle.Position = MuzzlePos
			Muzzle.Parent = Workspace.CurrentCamera
			Spawn(function() Particle:Emit(5) end)
			game.Debris:AddItem(Muzzle,10)	
		
			local HitPart = Instance.new("Part")
			HitPart.Name = "Bullet"
			HitPart.Size = Vector3.new(0.01,0.01,0.01)
			HitPart.Transparency = 1
			HitPart.Anchored = true
			HitPart.CanCollide = false
			HitPart.TopSurface = Enum.SurfaceType.SmoothNoOutlines
			HitPart.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
			local Particle = HitEffect:Clone()
			Particle.Parent = HitPart
			local Sound = Instance.new("Sound",HitPart)
			Sound.SoundId = "rbxassetid://"..HitSound
			Sound.Volume = 1
			HitPart.Position = EndPos
			HitPart.Parent = Workspace.CurrentCamera
			Spawn(function() Particle:Emit(2) Sound:Play() end)
			game.Debris:AddItem(HitPart,10)	
			
			if ExplosiveData[1] and VisualizeExplosion then
				local Explosion = Instance.new("Explosion")
				Explosion.BlastRadius = ExplosiveData[2]
				Explosion.BlastPressure = 0
				Explosion.Position = EndPos
				Explosion.Parent = Workspace.CurrentCamera
			end
			if VisualizeEnabled then
				local Bullet = Instance.new("Part")
				Bullet.Name = "Bullet"
				Bullet.Size = Vector3.new(0.2,0.2,0.2)
				Bullet.BrickColor = BulletData[3]
				Bullet.Transparency = BulletData[4]
				Bullet.Material = BulletData[5]
				Bullet.Anchored = true
				Bullet.CanCollide = false
				Bullet.TopSurface = Enum.SurfaceType.SmoothNoOutlines
				Bullet.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
				local Mesh = Instance.new("SpecialMesh",Bullet)
				Mesh.MeshType = Enum.MeshType.Brick
				Mesh.Scale = BulletData[2] * 5
				Mesh.Offset =  Vector3.new(0,0,-Mesh.Scale.Z/10)
				Bullet.CFrame = CFrame.new(MuzzlePos,EndPos)
				Bullet.Parent = Workspace.CurrentCamera
				game.Debris:AddItem(Bullet,10)
				if BulletData[1] ~= math.huge then
					for i = 0,Distance,BulletData[1] do
						if i ~= 0 then Bullet.CFrame = Bullet.CFrame * CFrame.new(0,0,-BulletData[1]) end
						if (Bullet.Position - EndPos).magnitude < BulletData[2].Z then
							Mesh.Scale = Vector3.new(BulletData[2].X,BulletData[2].Y,(Bullet.Position - EndPos).magnitude) * 5
							Mesh.Offset =  Vector3.new(0,0,-Mesh.Scale.Z/10)
						end
						game:GetService("RunService").Stepped:wait()
					end
				else
					Mesh.Scale = Vector3.new(BulletData[2].X,BulletData[2].Y,(Bullet.Position - EndPos).magnitude) * 5
					Mesh.Offset =  Vector3.new(0,0,-Mesh.Scale.Z/10)
					local Time = game:GetService("RunService").Heartbeat:wait()
					while Bullet.Transparency < 1 do
						Bullet.Transparency = Bullet.Transparency + (Time/BulletData[6])
						Time = game:GetService("RunService").Heartbeat:wait()
					end
				end
				if Bullet then Bullet:Destroy() end
			end
		end
	end
end

BE.Event:connect(VisualizeBullet)
RE.OnClientEvent:connect(VisualizeBullet)
--BE.Event:connect(function() print("Bindable Firing") end)
--RE.OnClientEvent:connect(function() print("Remote Firing") end)