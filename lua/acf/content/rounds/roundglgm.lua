
ACE.AmmoBlacklist.GLATGM = { "AC", "HMG", "MG", "RAC", "SA", "SAM", "AAM", "ASM", "BOMB", "FFAR", "UAR", "GBU", "GL", "SL", "FGL" , "ATR", "ECM", "ARTY", "ATGM"}

local Round = {}

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[GLATGM] - " .. ACFTranslation.ShellGLGM[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACFTranslation.ShellGLGM[2]
Round.netid = 9 --Unique ammotype ID for network transmission

Round.Type  = "GLATGM"

function Round.create( Gun, BulletData )
	if Gun:GetClass() == "acf_ammo" then
		ACE_CreateBullet( BulletData )
	else

		local glatgm = ents.Create("acf_glatgm")
		glatgm.DoNotDuplicate = true
		glatgm.Guidance = Gun

		glatgm:SetAngles(Gun:GetAngles())
		glatgm:SetPos(Gun:GetAttachment(1).Pos + Gun:GetForward() * 39.37)
		glatgm.BulletData = BulletData
		glatgm.Distance = BulletData.MuzzleVel * 4 * 39.37
		glatgm:Spawn()
	end
end
function Round.ConeCalc( ConeAngle, Radius )

	local ConeLength	= math.tan(math.rad(ConeAngle)) * Radius
	local ConeArea		= 3.1416 * Radius * (Radius ^ 2 + ConeLength ^ 2) ^ 0.5
	local ConeVol		= (3.1416 * Radius ^ 2 * ConeLength) / 3

	return ConeLength, ConeArea, ConeVol

end

-- Function to convert the player's slider data into the complete round data
function Round.convert( _, PlayerData )

	local Data = {}
	local ServerData = {}
	local GUIData = {}

	PlayerData.PropLength	=  PlayerData.PropLength	or 0
	PlayerData.ProjLength	=  PlayerData.ProjLength	or 0
	PlayerData.Tracer	=  PlayerData.Tracer		or 0
	PlayerData.TwoPiece	=  PlayerData.TwoPiece	or 0
	PlayerData.Data5 = math.max(PlayerData.Data5 or 0, 0)
	if not PlayerData.Data6 then PlayerData.Data6 = 0 end
	if not PlayerData.Data7 then PlayerData.Data7 = 0 end

	PlayerData, Data, ServerData, GUIData = ACE_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	local ConeThick				= Data.Caliber / 50
	--local ConeLength				= 0
	local ConeArea					= 0
	local AirVol					= 0
	ConeLength, ConeArea, AirVol = Round.ConeCalc( PlayerData.Data6, Data.Caliber / 2, PlayerData.ProjLength )

	Data.ProjMass					= math.max(GUIData.ProjVolume-PlayerData.Data5,0) * 7.9 / 1000 + math.min(PlayerData.Data5,GUIData.ProjVolume) * ACE.HEDensity / 1000 + ConeArea * ConeThick * 7.9 / 1000 --Volume of the projectile as a cylinder - Volume of the filler - Volume of the crush cone * density of steel + Volume of the filler * density of TNT + Area of the cone * thickness * density of steel
	Data.MuzzleVel					= ACE_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )

	local Energy					= ACE_Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )
	local MaxVol					= 0
	--local MaxLength				= 0
	--local MaxRadius				= 0
	MaxVol, MaxLength, MaxRadius = ACE_RoundShellCapacity( Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength )

	GUIData.MinConeAng				= 0
	GUIData.MaxConeAng				= math.deg( math.atan((Data.ProjLength - ConeThick ) / (Data.Caliber / 2)) )
	GUIData.ConeAng				= math.Clamp(PlayerData.Data6 * 1, GUIData.MinConeAng, GUIData.MaxConeAng)
	ConeLength, ConeArea, AirVol	= Round.ConeCalc( GUIData.ConeAng, Data.Caliber / 2, Data.ProjLength )

	local ConeVol					= ConeArea * ConeThick
	GUIData.MinFillerVol			= 0
	GUIData.MaxFillerVol			= math.max(MaxVol -  AirVol - ConeVol,GUIData.MinFillerVol)
	GUIData.FillerVol				= math.Clamp(PlayerData.Data5 * 1,GUIData.MinFillerVol,GUIData.MaxFillerVol)

	Data.FillerMass				= GUIData.FillerVol * ACE.HEDensity / 1450
	Data.BoomFillerMass			= Data.FillerMass / 3 --manually update function "pierceeffect" with the divisor
	Data.ProjMass					= math.max(GUIData.ProjVolume-GUIData.FillerVol- AirVol-ConeVol,0) * 7.9 / 1000 + Data.FillerMass + ConeVol * 7.9 / 1000
	Data.MuzzleVel					= ACE_MuzzleVelocity( Data.PropMass, Data.ProjMass, Data.Caliber )
	--local Energy					= ACE_Kinetic( Data.MuzzleVel * 39.37 , Data.ProjMass, Data.LimitVel )


	--Let's calculate the actual HEAT slug
	Data.SlugMass					= ConeVol * 7.9 / 1000
	local Rad						= math.rad(GUIData.ConeAng / 2)
	Data.SlugCaliber				=  Data.Caliber - Data.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
	Data.SlugMV					= ( Data.FillerMass / 2 * ACE.HEPower * math.sin(math.rad(10 + GUIData.ConeAng) / 2) / Data.SlugMass) ^ ACE.HEATMVScale --keep fillermass/2 so that penetrator stays the same
	Data.SlugMass					= Data.SlugMass * 4 ^ 2
	Data.SlugMV					= Data.SlugMV / 4

	local SlugFrArea				= 3.1416 * (Data.SlugCaliber / 2) ^ 2
	Data.SlugPenArea				= SlugFrArea ^ ACE.PenAreaMod
	Data.SlugDragCoef				= ((SlugFrArea / 10000) / Data.SlugMass)
	Data.SlugRicochet				=	500									--Base ricochet angle (The HEAT slug shouldn't ricochet at all)

	Data.CasingMass				= Data.ProjMass - Data.FillerMass - ConeVol * 7.9 / 1000

	--Random bullshit left
	Data.ShovePower				= 0.1
	Data.PenArea					= Data.FrArea ^ ACE.PenAreaMod
	Data.DragCoef					= ((Data.FrArea / 10000) / Data.ProjMass)
	Data.LimitVel					= 100										--Most efficient penetration speed in m/s
	Data.KETransfert				= 0.1									--Kinetic energy transfert to the target for movement purposes
	Data.Ricochet					= 70										--Base ricochet angle
	Data.DetonatorAngle			= 75

	Data.Detonated					= false
	Data.NotFirstPen				= false
	Data.BoomPower					= Data.PropMass + Data.FillerMass

	if SERVER then --Only the crates need this part
		ServerData.Id = PlayerData.Id
		ServerData.Type = PlayerData.Type
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only the GUI needs this part
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data, GUIData)
	end

end


function Round.getDisplayData(Data)
	local GUIData = {}

	local SlugEnergy = ACE_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999)
	GUIData.MaxPen = (SlugEnergy.Penetration / Data.SlugPenArea) * ACE.KEtoRHA
	--GUIData.BlastRadius = (Data.FillerMass/2) ^ 0.33 * 5*10
	GUIData.BlastRadius = Data.BoomFillerMass ^ 0.33 * 8 -- * 39.37
	GUIData.Fragments = math.max(math.floor((Data.BoomFillerMass / Data.CasingMass) * ACE.HEFrag), 2)
	GUIData.FragMass = Data.CasingMass / GUIData.Fragments
	GUIData.FragVel = (Data.BoomFillerMass * ACE.HEPower * 1000 / Data.CasingMass / GUIData.Fragments) ^ 0.5

	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "GLATGM" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "FillerMass", BulletData.FillerMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "DragCoef", BulletData.DragCoef )
	Crate:SetNWFloat( "SlugMass", BulletData.SlugMass )
	Crate:SetNWFloat( "SlugCaliber", BulletData.SlugCaliber )
	Crate:SetNWFloat( "SlugDragCoef", BulletData.SlugDragCoef )
	Crate:SetNWFloat( "MuzzleVel", BulletData.MuzzleVel )
	Crate:SetNWFloat( "Tracer", BulletData.Tracer )

end


--local fakeent = {ACF = {Armour = 0}}
--local fakepen = {Penetration = 999999999}
function Round.cratetxt( BulletData )

	local DData = Round.getDisplayData(BulletData)

	local str =
	{
		"Command Link: ", math.Round(BulletData.MuzzleVel * 4, 1), " m\n",
		"Max Penetration: ", math.floor(DData.MaxPen), " mm\n",
		"Blast Radius: ", math.Round(DData.BlastRadius, 1), " m\n",
		"Blast Energy: ", math.floor(BulletData.BoomFillerMass * ACE.HEPower), " KJ"
	}

	return table.concat(str)

end

function Round.detonate( _, Bullet, HitPos, HitNormal )

	ACE_HE( HitPos - Bullet.Flight:GetNormalized() * 3 , HitNormal , Bullet.BoomFillerMass , Bullet.CasingMass , Bullet.Owner )

	Bullet.Detonated = true
	Bullet.InitTime = SysTime()
	Bullet.FuseLength = 0.005 + 40 / ((Bullet.Flight + Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37):Length() * 0.0254)
	Bullet.Pos = HitPos
	Bullet.Flight = Bullet.Flight:GetNormalized() * Bullet.SlugMV * 39.37
	Bullet.DragCoef = Bullet.SlugDragCoef

	Bullet.ProjMass = Bullet.SlugMass
	Bullet.Caliber = Bullet.SlugCaliber
	Bullet.PenArea = Bullet.SlugPenArea
	Bullet.Ricochet = Bullet.SlugRicochet

	local DeltaTime = SysTime() - Bullet.LastThink
	Bullet.StartTrace = Bullet.Pos - Bullet.Flight:GetNormalized() * math.min(ACE.PhysMaxVel * DeltaTime,Bullet.FlightTime * Bullet.Flight:Length())
	Bullet.NextPos = Bullet.Pos + (Bullet.Flight * ACE.VelScale * DeltaTime)		--Calculates the next shell position

end

function Round.propimpact( Index, Bullet, Target, HitNormal, HitPos, Bone )

	if ACE_Check( Target ) then

		if Bullet.Detonated then
			Bullet.NotFirstPen = true

			local Speed = Bullet.Flight:Length() / ACE.VelScale
			local Energy = ACE_Kinetic( Speed , Bullet.ProjMass, 999999 )
			local HitRes = ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

			if HitRes.Overkill > 0 then
				table.insert( Bullet.Filter , Target )					--"Penetrate" (Ingoring the prop for the retry trace)
				ACE_Spall( HitPos , Bullet.Flight , Bullet.Filter , Energy.Kinetic * HitRes.Loss , Bullet.Caliber , Target.ACE.Armour , Bullet.Owner , Target.ACE.Material) --Do some spalling
				Bullet.Flight = Bullet.Flight:GetNormalized() * math.sqrt(Energy.Kinetic * (1 - HitRes.Loss) * ((Bullet.NotFirstPen and ACE.HEATPenLayerMul) or 1) * 2000 / Bullet.ProjMass) * 39.37

				return "Penetrated"
			else
				return false
			end

		else

			local Speed = Bullet.Flight:Length() / ACE.VelScale
			local Energy = ACE_Kinetic( Speed , Bullet.ProjMass - Bullet.FillerMass, Bullet.LimitVel )
			local HitRes = ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone )

			if HitRes.Ricochet then
				return "Ricochet"
			else
				Round.detonate( Index, Bullet, HitPos, HitNormal )
				return "Penetrated"
			end

		end
	else
		table.insert( Bullet.Filter , Target )
		return "Penetrated"
	end

	return false

end

function Round.worldimpact( Index, Bullet, HitPos, HitNormal )

	if not Bullet.Detonated then
		Round.detonate( Index, Bullet, HitPos, HitNormal )
		return "Penetrated"
	end

	local Energy = ACE_Kinetic( Bullet.Flight:Length() / ACE.VelScale, Bullet.ProjMass, 999999 )
	local HitRes = ACE_PenetrateGround( Bullet, Energy, HitPos, HitNormal )
	if HitRes.Penetrated then
		return "Penetrated"
	--elseif HitRes.Ricochet then  --penetrator won't ricochet
	--	return "Ricochet"
	else
		return false
	end

end

function Round.endflight( Index )

	ACE_RemoveBullet( Index )

end

function Round.endeffect( _, Bullet )

	local Impact = EffectData()
		Impact:SetEntity( Bullet.Crate )
		Impact:SetOrigin( Bullet.SimPos )
		Impact:SetNormal( (Bullet.SimFlight):GetNormalized() )
		Impact:SetScale( Bullet.SimFlight:Length() )
		Impact:SetMagnitude( Bullet.RoundMass )
	util.Effect( "ace_impact", Impact )

end

function Round.pierceeffect( Effect, Bullet )

	if Bullet.Detonated then

		local Spall = EffectData()
			Spall:SetEntity( Bullet.Crate )
			Spall:SetOrigin( Bullet.SimPos )
			Spall:SetNormal( (Bullet.SimFlight):GetNormalized() )
			Spall:SetScale( Bullet.SimFlight:Length() )
			Spall:SetMagnitude( Bullet.RoundMass )
		util.Effect( "ace_penetration", Spall )

	else

		local Radius = (Bullet.FillerMass / 3) ^ 0.33 * 8 * 39.37 --fillermass/3 has to be manually set, as this func uses networked data
		local Flash = EffectData()
			Flash:SetOrigin( Bullet.SimPos )
			Flash:SetNormal( Bullet.SimFlight:GetNormalized() )
			Flash:SetRadius( math.max( Radius, 1 ) )
		util.Effect( "ace_heat_jet", Flash )

		Bullet.Detonated = true
		Effect:SetModel("models/Gibs/wood_gib01e.mdl")

	end

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

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.GLATGM )

	acemenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")
	acemenupanel:CPanelText("BonusDisplay", "")

	acemenupanel:CPanelText("Desc", "")	--Description (Name, Desc)
	acemenupanel:CPanelText("BoldAmmoStats", "Round information:", "DermaDefaultBold")
	acemenupanel:CPanelText("LengthDisplay", "")	--Total round length (Name, Desc)

	--Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")
	acemenupanel:AmmoSlider("ConeAng",0,0,1000,3, "HEAT Cone Angle", "")
	acemenupanel:AmmoSlider("FillerVol",0,0,1000,3, "Total HEAT Warhead volume", "")

	ACE_Checkboxes()

	acemenupanel:CPanelText("VelocityDisplay", "")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "")	--HE Blast data (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "")	--HE Fragmentation data (Name, Desc)

	--acemenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acemenupanel:CPanelText("SlugDisplay", "")	--HEAT Slug data (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acemenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "GLATGM"										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acemenupanel.AmmoData.FillerVol
		PlayerData.Data6 = acemenupanel.AmmoData.ConeAng
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )		--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )
	RunConsoleCommand( "acemenu_data5", Data.FillerVol )
	RunConsoleCommand( "acemenu_data6", Data.ConeAng )
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	---------------------------Ammo Capacity-------------------------------------
	ACE_AmmoCapacityDisplay( Data )
	-------------------------------------------------------------------------------
	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ConeAng",Data.ConeAng,Data.MinConeAng,Data.MaxConeAng,0, "Crush Cone Angle", "")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("FillerVol",Data.FillerVol,Data.MinFillerVol,Data.MaxFillerVol,3, "HE Filler Volume", "HE Filler Mass : " .. (math.floor(Data.FillerMass * 1000)) .. " g")	--HE Filler Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_Checkboxes( Data )

	acemenupanel:CPanelText("Desc", ACE.RoundTypes[PlayerData.Type].desc)	--Description (Name, Desc)
	acemenupanel:CPanelText("LengthDisplay", "Round Length : " .. (math.floor((Data.PropLength + Data.ProjLength + Data.Tracer) * 100) / 100) .. "/" .. Data.MaxTotalLength .. " cm")	--Total round length (Name, Desc)
	acemenupanel:CPanelText("VelocityDisplay", "Command Link: " .. math.floor(Data.MuzzleVel * ACE.VelScale * 4) .. " m")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("BlastDisplay", "Blast Radius : " .. (math.floor(Data.BlastRadius * 100) / 100) .. " m")	--Proj muzzle velocity (Name, Desc)
	acemenupanel:CPanelText("FragDisplay", "Fragments : " .. Data.Fragments .. "\n Average Fragment Weight : " .. (math.floor(Data.FragMass * 10000) / 10) .. " g \n Average Fragment Velocity : " .. math.floor(Data.FragVel) .. " m/s")	--Proj muzzle penetration (Name, Desc)

	---------------------------Chance of Ricochet table----------------------------

	acemenupanel:CPanelText("RicoDisplay", "Max Detonation angle: " .. Data.DetonatorAngle .. "°")

	-------------------------------------------------------------------------------

	local R1V, R1P = ACE_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 100)
	R1P = (ACE_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACE.KEtoRHA
	local R2V, R2P = ACE_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 200)
	R2P = (ACE_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACE.KEtoRHA
	local R3V, R3P = ACE_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 400)
	R3P = (ACE_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACE.KEtoRHA
	local R4V, R4P = ACE_PenRanging(Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel, 800)
	R4P = (ACE_Kinetic(Data.SlugMV * 39.37, Data.SlugMass, 999999).Penetration / Data.SlugPenArea) * ACE.KEtoRHA

	acemenupanel:CPanelText("SlugDisplay", "Penetrator Mass : " .. (math.floor(Data.SlugMass * 10000) / 10) .. " g \nPenetrator Caliber : " .. (math.floor(Data.SlugCaliber * 100) / 10) .. " mm \nPenetrator Velocity : " .. math.floor(Data.MuzzleVel + Data.SlugMV) .. " m/s \nMax Penetration : " .. math.floor(Data.MaxPen) .. " mm RHA\n\n100m pen: " .. math.Round(R1P,0) .. "mm @ " .. math.Round(R1V,0) .. " m\\s\n200m pen: " .. math.Round(R2P,0) .. "mm @ " .. math.Round(R2V,0) .. " m\\s\n400m pen: " .. math.Round(R3P,0) .. "mm @ " .. math.Round(R3V,0) .. " m\\s\n800m pen: " .. math.Round(R4P,0) .. "mm @ " .. math.Round(R4V,0) .. " m\\s\n\nThe range data is an approximation and may not be entirely accurate.\n")	--Proj muzzle penetration (Name, Desc)

end

list.Set("HERoundTypes", "GLATGM", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above