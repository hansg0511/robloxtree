--[[ Version v1.0.7
====================================================================================================
Weapons and Tools Pack 2016's Gun by SuperEvilAzmil

Features:
- FilteringEnabled support
- Easy to edit with a bunch of settings
- No delays between Mouse Click and Gun Fire
====================================================================================================
]]

local Module = {
--	====================
--	BASIC
--	A basic settings for the gun
--	====================

		Auto = false;
		MuzzleOffset = Vector3.new(0, 0.625, 1.25);
		BaseDamage = 26;
		FireRate = 0.10 ; --In second
		ReloadTime = 2; --In second
		AmmoPerClip = 30; --Put "math.huge" to make this gun has infinite ammo and never reload
		Spread = 1.25; --In degree
		HeadshotEnabled = true; --Enable the gun to do extra damage on headshot
		HeadshotDamageMultiplier = 4;
		MouseIconID = "316279304";
		HitSoundIDs = {186809061,186809249,186809250,186809252};
		IdleAnimationID = 94242777; --Set to "nil" if you don't want to animate
		IdleAnimationSpeed = 1;
		FireAnimationID = 94332152; --Set to "nil" if you don't want to animate
		FireAnimationSpeed = 6;
		ReloadAnimationID = 95384819; 
		ReloadAnimationSpeed = 3;
		
--	====================
--	LIMITED CLIP
--	Make a gun has a limit clip
--	====================

		LimitedClipEnabled = false;
		Clips = 10;
		MaxClip = 10; --Put "math.huge" to allow user to carry unlimited clip
		
--	====================
--	SHOTGUN
--	Enable the gun to fire multiple bullet in one shot
--	====================

		ShotgunEnabled = false;
		BulletPerShot = 8;
		
		ShotgunReload = false; --Make user reloading like Shotgun, which user clipin shell one by one
		ShotgunClipinAnimationID = nil; --Set to "nil" if you don't want to animate
		ShotgunClipinAnimationSpeed = 1;
		ShellClipinSpeed = 0.5; --In second
		
--		How "ShotgunEnabled" work [Example]:

--		Play "ShotgunClipinAnimation" + Play "ShotgunClipin" Audio
--		>>>
--		Wait "ShellClipinSpeed" second
--		>>>
--		Repeat "AmmoPerClip" - "Current Ammo" times
--		>>>
--		Play "ReloadAnimation" + Play "ReloadSound"
--		Wait "ReloadTime"
		
--	====================
--	BURST FIRE
--	Enable the gun to do burst firing like Assault Rifle
--	====================

		BurstFireEnabled = true;
		BulletPerBurst = 3;
		BurstRate = 0.075; --In second
		
--	====================
--	SNIPER
--	Enable user to use scope
--	====================

		SniperEnabled = false;
		FieldOfView = 12.5;
		MouseSensitive = 0.05; --In percent
		SpreadRedution = 1; --In percent.
		
--	====================
--	CAMERA SHAKING
--	Make user's camera shaking when shooting
--	====================

		CameraShakingEnabled = true;
		Intensity = 0.5; --In degree
		
--	====================
--	EXPLOSIVE
--	Make a bullet explosive so user can deal a damage to multiple enemy in single shot. NOTE: Explosion won't break joints
--	====================

		ExplosiveEnabled = false;
		Radius = 8;
		
--	====================
--	BULLET VISUALIZER
--	Enabled the gun to display a fake travelling bullet
--	====================

		VisualizerEnabled = true;
		BulletSpeed = 25;
		BulletSize = Vector3.new(0.25,0.25,100);
		BulletColor = BrickColor.new("Bright yellow");
		BulletTransparency = 0.25;
		BulletMaterial = Enum.Material.SmoothPlastic;
		FadeTime = 0.25; --Only work when bullet travel instantly. For this, you have to set BulletSpeed to "math.huge"
		
--	====================
--	CHARGED SHOT
--	Make a gun charging before firing. Useful for a gun like "Railgun" or "Laser Cannon"
--	====================
		
		ChargedShotEnabled = false;
		ChargingTime = 1;
		
--	====================
--	MINIGUN
--	Make a gun delay before/after firing
--	====================

		MinigunEnabled = false;
		DelayBeforeFiring = 1;
		DelayAfterFiring = 1;
		
--	====================
--	MISCELLANEOUS
--	Etc. settings for the gun
--	====================

		Knockback = 0; --Setting above 0 will enabling the gun to push enemy back. NOTE: If "ExplosiveEnabled" is enabled, this setting is not work
		Lifesteal = 0; --In percent - Setting above 0 will allow user to steal enemy's health by dealing a damage to them.
		FlamingBullet = false; --Enable the bullet to set enemy on fire. Its DPS and Duration can be edited inside "IgniteScript"
		DualEnabled = false; --Enable the user to hold two guns instead one. In order to make this setting work, you must clone its Handle and name it to "Handle2". Enabling this setting will override Idle Animation ID.
		Piercing = 0; --Setting above 0 will enabling the gun to penetrate up to XX victim(s). Cannot penetrate wall. NOTE: It doesn't work with "ExplosiveEnabled"
		
--	====================
--	END OF SETTING
--	====================
}

return Module
