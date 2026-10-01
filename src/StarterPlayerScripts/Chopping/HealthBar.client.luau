local healthBar = workspace.HealthBarGui.RootPart.SurfaceGui.Fill

local highlight = Instance.new("Frame")
highlight.Size = UDim2.fromScale(1, 0.15)
highlight.BackgroundColor3 = Color3.fromRGB(255,255,255)
highlight.BackgroundTransparency = 0.85
highlight.Parent = healthBar
highlight.ZIndex = healthBar.ZIndex + 2

local shadow = Instance.new("Frame")
shadow.Size = UDim2.fromScale(1, 0.25)
shadow.Position = UDim2.fromScale(0, 0.75)
shadow.BackgroundColor3 = Color3.fromRGB(0,0,0)
shadow.BackgroundTransparency = 0.8
shadow.Parent = healthBar
shadow.ZIndex = healthBar.ZIndex + 1

