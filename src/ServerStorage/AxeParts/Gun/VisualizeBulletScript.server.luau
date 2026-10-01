local RE = script.Parent.VisualizeBullet
RE.OnServerEvent:connect(function(Player,Handle,MuzzleOffset,EndPos,MuzzleEffect,HitEffect,HitSound,ExplosiveData,BulletData,VisualizeExplosion,VisualizeEnabled)
	for _, TruePlayer in pairs(game.Players:GetPlayers()) do
		RE:FireClient(TruePlayer,Player,Handle,MuzzleOffset,EndPos,MuzzleEffect,HitEffect,HitSound,ExplosiveData,BulletData,VisualizeExplosion,VisualizeEnabled)
	end
end)