local SoundMaker = script.parent

SoundMaker.Equipped:Connect(function()
    SoundMaker.Handle.EquipSound:Play()
end)