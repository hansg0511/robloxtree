--None of this is mine...
script.Parent.Equipped:Connect(function()
	script.Parent.WAP.act:FireServer()
end)

script.Parent.Unequipped:Connect(function()
	script.Parent.WAP.dct:FireServer()
end)

