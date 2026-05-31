
ACE.AmmoBlacklist.HESH = { "MG", "HMG", "RAC", "SL" , "AC" , "SA" , "GL", "ECM", "ATR", "BOMB" , "GBU", "ASM", "AAM", "SAM", "UAR", "POD", "FFAR", "ATGM", "ARTY", "ECM", "FGL","SBC"}

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[HESH] - " .. ACFTranslation.ShellHESH[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACFTranslation.ShellHESH[2]
Round.netid = 12 --Unique ammotype ID for network transmission

Round.Type  = "HESH"

function Round.create( _, BulletData )
	ACE.CreateBullet( BulletData )
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

	PlayerData, Data, ServerData, GUIData = ACE.RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs
	Data.ProjMass = math.max(GUIData.ProjVolume - PlayerData.FillerVol, 0) * 7.9 / 1000 + math.min(PlayerData.FillerVol, GUIData.ProjVolume) * ACE.HEDensity / 1000 --Volume of the projectile as a cylinder - Volume of the filler * density of steel + Volume of the filler * density of TNT
	Data.MuzzleVel = ACE.MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local Energy = ACE.Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	local MaxVol = ACE.RoundShellCapacity(Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength)
	GUIData.MinFillerVol = 0
	GUIData.MaxFillerVol = math.min(GUIData.ProjVolume, MaxVol)
	GUIData.FillerVol = math.min(PlayerData.FillerVol, GUIData.MaxFillerVol)
	Data.FillerMass = GUIData.FillerVol * ACE.HEDensity / 1000

	Data.ProjMass = math.max(GUIData.ProjVolume - GUIData.FillerVol, 0) * 7.9 / 1000 + Data.FillerMass
	Data.MuzzleVel = ACE.MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)

	--Random bullshit left
	Data.ShovePower = 0.1
	Data.PenArea = Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 100 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 --Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 62 --Base ricochet angle
	Data.DetonatorAngle = 62

	Data.BoomPower = Data.PropMass + Data.FillerMass

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


function Round.getDisplayData(Data)
	local GUIData = {}
	GUIData.BlastRadius = (Data.FillerMass * 0.7) ^ 0.33 * 8
	local FragMass = Data.ProjMass - Data.FillerMass
	GUIData.Fragments = math.max(math.floor((Data.FillerMass / FragMass) * ACE.HEFrag), 2)
	GUIData.FragMass = FragMass / GUIData.Fragments
	GUIData.FragVel = (Data.FillerMass * ACE.HEPower * 1000 / GUIData.FragMass / GUIData.Fragments) ^ 0.5
	GUIData.MaxPen = Data.FillerMass / 1501 * 4 * ACE.HEPower

	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", Round.Type )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
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
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(BulletData.FillerMass * ACE.HEPower), " KJ\n",
		"Blast Penetration: ", math.floor(DData.MaxPen), " mm"
	}

	return table.concat(str)

end

function Round.propimpact( _, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE.Check( Target ) then

		local Speed = Bullet.Flight:Length() / ACE.VelScale
		local Energy = ACE.Kinetic(Speed / 4 + Bullet.FillerMass * 250, Bullet.ProjMass / 4 + Bullet.FillerMass * 5, Bullet.LimitVel)
		--local HitRes = ACE.RoundImpact(Bullet, Speed / 4 + Bullet.FillerMass * 250, Energy, Target, HitPos, HitNormal / 10, Bone)
	ACE.RoundImpact(Bullet, Speed / 4 + Bullet.FillerMass * 250, Energy, Target, HitPos, HitNormal / 10, Bone)

		table.insert( Bullet.Filter , Target )
	ACE.CreateSpallHESH( HitPos, Bullet.Flight, Bullet.Filter, Bullet.FillerMass * ACE.HEPower, Bullet.Caliber * 5, Target.ACE.Armour, Bullet.Owner, Target.ACE.Material) --Do some spalling

	else
		table.insert( Bullet.Filter , Target )
	return "Penetrated" end

end

function Round.worldimpact( )

	return false

end

function Round.endflight( Index, Bullet, HitPos, HitNormal )

ACE.HE( HitPos - Bullet.Flight:GetNormalized() * 3, HitNormal, Bullet.FillerMass * 0.4, Bullet.ProjMass - Bullet.FillerMass * 0.4, Bullet.Owner, nil, Bullet.Gun )
ACE.RemoveBullet( Index )

end

function Round.endeffect( _, Bullet )

	local Radius = Bullet.FillerMass ^ 0.33 * 8 * 39.37
	local Flash = EffectData()
		Flash:SetOrigin( Bullet.SimPos )
		Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
		Flash:SetRadius( math.max( Radius, 1 ) )
	util.Effect( "ace_explosion", Flash )

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
	util.Effect( "ace_impact", Spall )

end

function Round.ricocheteffect( _, Bullet )

	local Spall = EffectData()
		Spall:SetEntity( Bullet.Crate )
		Spall:SetOrigin( Bullet.SimPos )
		Spall:SetNormal( Bullet.SimFlight:GetNormalized() )
		Spall:SetScale( Bullet.SimFlight:Length() )
		Spall:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ace_ricochet", Spall )

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect(ACE.AmmoBlacklist.HESH)

	acemenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

	acemenupanel:CPanelText("BonusDisplay", "")

	acemenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acemenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acemenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "HE Filler", "")			--Slider (Name, Value, Min, Max, Decimals, Title, Desc)

ACE.Checkboxes()

	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "")	--HE Blast data (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "")	--HE Fragmentation data (Name, Desc)
	--acemenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.RoundGunClass    = acemenupanel.AmmoData.Data.id					-- AmmoSelect GUI
		PlayerData.RoundType        = Round.Type										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.FillerVol = acemenupanel.AmmoData.FillerVol
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	ACE.MenuSendTableValue("Data", "RoundData", "RoundGunClass", acemenupanel.AmmoData.Data.id)
	ACE.MenuSendTableValue("Data", "RoundData", "RoundType", Round.Type)
	ACE.MenuSendTableValue("Data", "RoundData", "PropLength", Data.PropLength)
	ACE.MenuSendTableValue("Data", "RoundData", "ProjLength", Data.ProjLength)
	ACE.MenuSendTableValue("Data", "RoundData", "FillerVol", Data.FillerVol)
	ACE.MenuSendTableValue("Data", "RoundData", "Tracer", Data.Tracer)
	ACE.MenuSendTableValue("Data", "RoundData", "TwoPiece", Data.TwoPiece)

	---------------------------Ammo Capacity-------------------------------------
	ACE.AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE.Checkboxes( Data )

	acemenupanel:CPanelText("Desc", ACE.RoundTypes[PlayerData.RoundType].desc) --Description (Name, Desc)
	acemenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + (math.floor(Data.Tracer * 5) / 10)) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm") --Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "Muzzle Velocity : " .. math.floor(Data.MuzzleVel * ACE.VelScale) .. " m/s") --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m" .. "\nBlast Max penetration: " .. math.floor(Data.MaxPen) .. " mm RHA") --Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s") --Proj muzzle penetration (Name, Desc)

	---------------------------Chance of Ricochet table----------------------------

	acemenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")

	-------------------------------------------------------------------------------
end

list.Set("HERoundTypes", "HESH", Round ) --Set the round on chemical folder
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above