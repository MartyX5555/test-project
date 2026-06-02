
ACE.AmmoBlacklist.APDS =  { "MG", "MO", "RM", "SL", "GL", "HW", "SC", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY", "ECM", "FGL","SBC"}

local Round = {}

Round.type  = "Ammo" --Tells the spawn menu what entity to spawn
Round.name  = "[APDS] - " .. ACETranslation.ShellAPDS[1] --Human readable name
Round.model = "models/munitions/dart_100mm.mdl" --Shell flight model
Round.desc  = ACETranslation.ShellAPDS[2]
Round.netid = 9 --Unique ammotype ID for network transmission

Round.Type  = "APDS"

function Round.create( _, BulletData )
	ACE.CreateBullet( BulletData )
end

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data		= {}
	local ServerData	= {}
	local GUIData	= {}

	PlayerData.PropLength	=  PlayerData.PropLength	or 0
	PlayerData.ProjLength	=  PlayerData.ProjLength	or 0
	PlayerData.Tracer	=  PlayerData.Tracer		or 0
	PlayerData.TwoPiece	=  PlayerData.TwoPiece	or 0
	PlayerData.SCalMult		= PlayerData.SCalMult	or 0.5  --caliber in mm count --Data5

	PlayerData, Data, ServerData, GUIData = ACE.RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	local GunClass = ACE.Weapons["Guns"][Data["RoundGunClass"] or PlayerData["RoundGunClass"]]["gunclass"]

	if GunClass == "AC" or GunClass == "HMG" then

		Data.MinCalMult	= 0.35
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 2 -- Autocannons are puny anyways
		Data.VelModifier	= 1.6
		Data.Ricochet	= 68
	elseif GunClass == "RAC" then

		Data.MinCalMult	= 0.5
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 1.8
		Data.VelModifier	= 1.7
		Data.Ricochet	= 68
	elseif GunClass == "HRAC" then

		Data.MinCalMult	= 0.5
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 1.9
		Data.VelModifier	= 1.7
		Data.Ricochet	= 68
	elseif GunClass == "MG" then

		Data.MinCalMult	= 0.45
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 1.7
		Data.VelModifier	= 1.8
		Data.Ricochet	= 68
	elseif GunClass == "SA" then

		Data.MinCalMult	= 0.3
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 2
		Data.VelModifier	= 1.6
		Data.Ricochet	= 68
	elseif GunClass == "C" then

		Data.MinCalMult	= 0.25
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 0.8
		Data.VelModifier	= 0.9
		Data.Ricochet	= 68
	elseif GunClass == "AL" then

		Data.MinCalMult	= 0.28
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 0.8
		Data.VelModifier	= 0.9
		Data.Ricochet = 68
	else

		Data.MinCalMult	= 0.25
		Data.MaxCalMult	= 1.0
		Data.PenModifier	= 1.35
		Data.VelModifier	= 1
		Data.Ricochet	= 68
	end

	--Used for adapting acf2 apds/apfsds to the new format
	PlayerData.SCalMult	= math.Clamp(PlayerData.SCalMult,Data.MinCalMult,Data.MaxCalMult)

	Data.SCalMult	= PlayerData.SCalMult
	Data.SubFrArea	= Data.FrArea * math.min(PlayerData.SCalMult,Data.MaxCalMult) ^ 2
	Data.ProjMass	= Data.SubFrArea * (Data.ProjLength * 7.9 / 1000) * 2.5 --Volume of the projectile as a cylinder * density of steel
	Data.ShovePower	= 0.2
	Data.PenArea		= (Data.PenModifier * Data.SubFrArea) ^ ACE.PenAreaMod

	Data.DragCoef	= ((Data.SubFrArea / 10000) / Data.ProjMass)
	Data.CaliberMod	= Data.Caliber * math.min(PlayerData.SCalMult,Data.MaxCalMult)
	Data.LimitVel	= 1000										--Most efficient penetration speed in m/s
	Data.KETransfert	= 0.2								--Kinetic energy transfert to the target for movement purposes
	Data.MuzzleVel	= ACE.MuzzleVelocity( Data.PropMass * 0.5 , Data.ProjMass * 2.5, Data.Caliber ) * Data.VelModifier
	Data.BoomPower	= Data.PropMass

	--Only the crates need this part
	if SERVER then
		ServerData.Id   = PlayerData.RoundGunClass
		ServerData.Type = PlayerData.RoundType
		return table.Merge(Data,ServerData)
	end

	--Only tthe GUI needs this part
	if CLIENT then
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data,GUIData)
	end

end


function Round.getDisplayData(Data)
	local GUIData = {}
	local Energy = ACE.Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )
	GUIData.MaxPen = (Energy.Penetration / Data.PenArea) * ACE.KEtoRHA
	return GUIData
end



function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", Round.Type )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

		--For propper bullet model
	Crate:SetNWFloat( "BulletModel", Round.model )

end

function Round.cratetxt( BulletData )

	local DData = Round.getDisplayData(BulletData)
	local str =
	{
		"Muzzle Velocity: ", math.Round(BulletData.MuzzleVel, 1), " m/s\n",
		"Max Penetration: ", math.floor(DData.MaxPen), " mm"
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE.Check( Target ) then

		local Speed	= Bullet.Flight:Length() / ACE.VelScale
		local Energy	= ACE.Kinetic( Speed , Bullet.ProjMass, Bullet.LimitVel )
		local HitRes	= ACE.RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

		if HitRes.Overkill > 0 then

			table.insert( Bullet.Filter , Target )				--"Penetrate" (Ingoring the prop for the retry trace)

		ACE.CreateSpall( HitPos , Bullet.Flight , Bullet.Filter , Energy.Kinetic * HitRes.Loss , Bullet.Caliber , Target.ACE.Armour , Bullet.Owner , Target.ACE.Material) --Do some spalling

			Bullet.Flight = Bullet.Flight:GetNormalized() * (Energy.Kinetic * (1-HitRes.Loss) * 2000 / Bullet.ProjMass) ^ 0.5 * 39.37

			return "Penetrated"
		elseif HitRes.Ricochet then

			return "Ricochet"
		else
			return false
		end

	else
		table.insert( Bullet.Filter , Target )
		return "Penetrated"
	end

end

function Round.worldimpact( _, Bullet, HitPos, HitNormal )

	local Energy = ACE.Kinetic( Bullet.Flight:Length() / ACE.VelScale, Bullet.ProjMass, Bullet.LimitVel )
	local HitRes = ACE.PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	elseif HitRes.Ricochet then
		return "Ricochet"
	else
		return false
	end

end

function Round.endflight( Index )

	ACE.RemoveBullet( Index )

end

-- Bullet stops here
function Round.endeffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ace_impact", Spall )

end

-- Bullet penetrated something
function Round.pierceeffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ace_penetration", Spall )

end

-- Bullet ricocheted off something
function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ace_ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.APDS )

ACE.UpperCommonDataDisplay()

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Propellant Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Projectile Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("SCalMult",0,0,1000,2, "Subcaliber Size Multiplier", "") --Subcaliber Slider (Name, Value, Min, Max, Decimals, Title, Desc)

ACE.CommonDataDisplay()

	Round.guiupdate( Panel, Table )
end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.RoundGunClass    = acemenupanel.AmmoData.Data.id		--AmmoSelect GUI
		PlayerData.RoundType        = Round.Type										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength       = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength       = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.SCalMult         = acemenupanel.AmmoData.SCalMult
		PlayerData.Tracer           = acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece         = acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	ACE.MenuSendTableValue("Data", "RoundData", "RoundGunClass", acemenupanel.AmmoData.Data.id)
	ACE.MenuSendTableValue("Data", "RoundData", "RoundType", Round.Type)
	ACE.MenuSendTableValue("Data", "RoundData", "PropLength", Data.PropLength)
	ACE.MenuSendTableValue("Data", "RoundData", "ProjLength", Data.ProjLength)
	ACE.MenuSendTableValue("Data", "RoundData", "SCalMult", Data.SCalMult)
	ACE.MenuSendTableValue("Data", "RoundData", "Tracer", Data.Tracer)
	ACE.MenuSendTableValue("Data", "RoundData", "TwoPiece", Data.TwoPiece)

	ACE.UpperCommonDataDisplay( Data, PlayerData )

	acemenupanel:AmmoSlider("PropLength", Data.PropLength, Data.MinPropLength, Data.MaxTotalLength, 3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.PropMass, 1)) .. " kg" )  --Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength", Data.ProjLength, Data.MinProjLength, Data.MaxTotalLength, 3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g" .. "/ " .. (math.Round(Data.ProjMass, 1)) .. " kg")  --Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("SCalMult",Data.SCalMult,Data.MinCalMult,Data.MaxCalMult,2, "Subcaliber Size Multiplier", "Caliber : " .. math.floor(Data.Caliber * math.min(PlayerData.SCalMult,Data.MaxCalMult) * 10) .. " mm") --Subcaliber round slider (Name, Min, Max, Decimals, Title, Desc)

	ACE.CommonDataDisplay( Data )

end

list.Set( "APRoundTypes", "APDS", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above