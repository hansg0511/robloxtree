local SoundMaker = script.parent

SoundMaker.Unequipped:Connect(function()
    SoundMaker.Handle.EquipSound:Stop()
end)