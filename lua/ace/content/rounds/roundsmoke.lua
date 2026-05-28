
ACE.AmmoBlacklist.SM = { "MG", "GL", "HMG", "AC", "RAC", "SA" , "GL", "ATR", "FGL", "ECM", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY" }

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[SM] - " .. ACFTranslation.ShellSm[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACFTranslation.ShellSm[2]
Round.netid = 6 --Unique ammotype ID for network transmission

Round.Type  = "SM"

function Round.create( _, BulletData )

	ACE_CreateBullet( BulletData )

end

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data = {}
	local ServerData = {}
	local GUIData = {}

	PlayerData.PropLength    = PlayerData.PropLength	or 0
	PlayerData.ProjLength    = PlayerData.ProjLength	or 0
	PlayerData.Tracer        = PlayerData.Tracer		or 0
	PlayerData.TwoPiece      = PlayerData.TwoPiece	or 0
	PlayerData.FillerVol     = math.max(PlayerData.FillerVol or 0, 0)
	PlayerData.WPVol         = math.max(PlayerData.WPVol or 0, 0)
	PlayerData.FuseDelay     = tonumber(PlayerData.FuseDelay) or 0  --catching some possible errors with string data in legacy dupes


	PlayerData, Data, ServerData, GUIData = ACE_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs
	Data.ProjMass = math.max(GUIData.ProjVolume - PlayerData.FillerVol, 0) * 7.9 / 1000 + math.min(PlayerData.FillerVol, GUIData.ProjVolume) * ACE.HEDensity / 2000 --Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local Energy = ACE_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	local MaxVol = ACE_RoundShellCapacity(Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength)
	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.min(GUIData.ProjVolume, MaxVol)

	GUIData.MaxSmokeVol = math.max(GUIData.MaxFillerVol - PlayerData.WPVol, GUIData.MinFillerVol)
	GUIData.MaxWPVol = math.max(GUIData.MaxFillerVol - PlayerData.FillerVol, GUIData.MinFillerVol)

	local Ratio = math.min(GUIData.MaxFillerVol / (PlayerData.FillerVol + PlayerData.WPVol), 1)
	GUIData.FillerVol = math.min(PlayerData.FillerVol * Ratio, GUIData.MaxSmokeVol)
	GUIData.WPVol = math.min(PlayerData.WPVol * Ratio, GUIData.MaxWPVol)

	Data.FillerMass = GUIData.FillerVol * ACE.HEDensity / 2000
	Data.WPMass = GUIData.WPVol * ACE.HEDensity / 2000

	Data.ProjMass = math.max(GUIData.ProjVolume - (GUIData.FillerVol + GUIData.WPVol), 0) * 7.9 / 1000 + Data.FillerMass + Data.WPMass
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 100 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 --Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 63 --Base ricochet angle
	Data.DetonatorAngle = 85

	if PlayerData.FuseDelay < 0.5 then
		PlayerData.FuseDelay = 0
		Data.FuseDelay = PlayerData.FuseDelay
	else
		PlayerData.FuseDelay = math.max(math.Round(PlayerData.FuseDelay,1),0.5)
		Data.FuseDelay = PlayerData.FuseDelay
	end

	Data.BoomPower = Data.PropMass + Data.FillerMass + Data.WPMass

	if SERVER then --Only the crates need this part
		ServerData.Id = PlayerData.RoundGunClass
		ServerData.Type = PlayerData.RoundType
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only tthe GUI needs this part
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data,GUIData)
	end

end

function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", Round.Type )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "WPMass", BulletData.WPMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

		--For propper bullet model
	Crate:SetNWFloat( "BulletModel", Round.model )

end

function Round.getDisplayData(Data)

	local GUIData = {}

	GUIData.SMFiller = math.min(math.log(1 + Data.FillerMass * 8 * 39.37) / 0.02303, 350) --smoke filler
	GUIData.SMLife = math.Round(20 + GUIData.SMFiller / 4, 1)
	GUIData.SMRadiusMin = math.Round(GUIData.SMFiller * 1.25 * 0.15 * 0.0254, 1)
	GUIData.SMRadiusMax = math.Round(GUIData.SMFiller * 1.25 * 2 * 0.0254, 1)

	GUIData.WPFiller = math.min(math.log(1 + Data.WPMass * 8 * 39.37) / 0.02303, 350) --wp filler
	GUIData.WPLife = math.Round(6 + GUIData.WPFiller / 10, 1)
	GUIData.WPRadiusMin = math.Round(GUIData.WPFiller * 1.25 * 0.0254, 1)
	GUIData.WPRadiusMax = math.Round(GUIData.WPFiller * 1.25 * 2 * 0.0254, 1)

	return GUIData

end

function Round.cratetxt( BulletData )

	local GUIData = Round.getDisplayData(BulletData)

	local str = {
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s"
	}

	if GUIData.WPFiller > 0 then
		local temp = {
			"\nWP Radius: ", GUIData.WPRadiusMin, " m to ", GUIData.WPRadiusMax, " m\n",
			"WP Lifetime: ", GUIData.WPLife, " s"
		}

		for i = 1,#temp do
			str[#str + 1] = temp[i]
		end
	end

	if GUIData.SMFiller > 0 then
		local temp = {
			"\nSM Radius: ", GUIData.SMRadiusMin, " m to ", GUIData.SMRadiusMax, " m\n",
			"SM Lifetime: ", GUIData.SMLife, " s"
		}

		for i = 1,#temp do
			str[#str + 1] = temp[i]
		end
	end

	if BulletData.FuseDelay > 0 then
		local temp = {
			"\nFuse time: ", BulletData.FuseDelay, " s"
		}

		for i = 1,#temp do
			str[#str + 1] = temp[i]
		end
	end

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE_Check( Target ) then
		local Speed = Bullet.Flight:Length() / ACE.VelScale
		local Energy = ACE_Kinetic( Speed , Bullet.ProjMass - (Bullet.FillerMass + Bullet.WPMass), Bullet.LimitVel )
		local HitRes = ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )
		if HitRes.Ricochet then
			return "Ricochet"
		end
	end
	return false

end

function Round.worldimpact()

	return false

end

function Round.endflight( Index )

	--ACE_HE( HitPos - Bullet.Flight:GetNormalized() * 3 , HitNormal, Bullet.FillerMass, Bullet.ProjMass - Bullet.FillerMass, Bullet.Owner )
	ACE_RemoveBullet( Index )

end

function Round.endeffect( _, Bullet )

	local Flash = EffectData()
		Flash:SetOrigin( Bullet.SimPos )
		Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
		Flash:SetRadius( math.max( Bullet.FillerMass * 8 * 39.37, 0 ) ) --(Bullet.FillerMass) ^ 0.33 * 8*39.37
		Flash:SetMagnitude( math.max( Bullet.WPMass * 8 * 39.37, 0 ) )

		local vec = Vector(255,255,255)
		if IsValid(Bullet.Crate) then vec = Bullet.Crate:GetNWVector( "TracerColour", Bullet.Crate:GetColor() ) end
		Flash:SetStart(vec)
	util.Effect( "ace_smoke", Flash )

end

function Round.pierceeffect( _, Bullet )

	local BulletEffect = {}
		BulletEffect.Num = 1
		BulletEffect.Src = Bullet.SimPos - Bullet.SimFlight:GetNormalized()
		BulletEffect.Dir = Bullet.SimFlight:GetNormalized()
		BulletEffect.Spread = Vector(0,0,0)
		BulletEffect.Tracer = 0
		BulletEffect.Force = 0
		BulletEffect.Damage = 0
	LocalPlayer():FireBullets(BulletEffect)

	util.Decal("ExplosiveGunshot", Bullet.SimPos + Bullet.SimFlight * 10, Bullet.SimPos - Bullet.SimFlight * 10)

	local Spall = EffectData()
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale(math.max(((Bullet.RoundMass * (Bullet.SimFlight:Length() / 39.37) ^ 2) / 2000) / 10000, 1))
	util.Effect( "AP_Hit", Spall )

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Gun )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ace_ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.SM )

	acemenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acemenupanel:CPanelText("BonusDisplay", "")

	acemenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acemenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acemenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Smoke Filler", "")			--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("WPVol",0,0,1000,3, "WP Filler", "")			--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FuseLength",0,0,1000,3, "Timed Fuse", "")

	ACE_Checkboxes()

	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "")	--HE Blast data (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "")	--HE Fragmentation data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.RoundGunClass    = acemenupanel.AmmoData.Data.id					-- AmmoSelect GUI
		PlayerData.RoundType        = Round.Type										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength       = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength       = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.FillerVol        = acemenupanel.AmmoData.FillerVol
		PlayerData.WPVol            = acemenupanel.AmmoData.WPVol
		PlayerData.FuseDelay        = acemenupanel.AmmoData.FuseDelay
		PlayerData.Tracer           = acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece         = acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	local Data = Round.convert( Panel, PlayerData )
	ACE.MenuSendTableValue("Data", "RoundData", "RoundGunClass", acemenupanel.AmmoData.Data.id)
	ACE.MenuSendTableValue("Data", "RoundData", "RoundType", Round.Type)
	ACE.MenuSendTableValue("Data", "RoundData", "PropLength", Data.PropLength)
	ACE.MenuSendTableValue("Data", "RoundData", "ProjLength", Data.ProjLength)
	ACE.MenuSendTableValue("Data", "RoundData", "FillerVol", Data.FillerVol)
	ACE.MenuSendTableValue("Data", "RoundData", "FuseDelay", Data.FuseDelay)
	ACE.MenuSendTableValue("Data", "RoundData", "Tracer", Data.Tracer)
	ACE.MenuSendTableValue("Data", "RoundData", "TwoPiece", Data.TwoPiece)

	---------------------------Ammo Capacity-------------------------------------
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "Smoke Filler Volume", "Smoke Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("WPVol",Data.WPVol,Data.MinFillerVol,Data.MaxFillerVol,3, "WP Filler Volume", "WP Filler Mass : " .. (math.floor(Data.WPMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FuseLength",Data.FuseDelay,0,10,1, "Fuse Time", Data.FuseDelay .. " s")

	ACE_Checkboxes( Data )

	acemenupanel:CPanelText("Desc", ACE.RoundTypes[PlayerData.RoundType].desc)	--Description (Name, Desc)
	acemenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm")	--Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACE.VelScale) .. " m/s")	--Proj muzzle velocity (Name, Desc)

end

list.Set( "SPECSRoundTypes", "SM", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above