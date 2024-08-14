
local RoundTypes = ACE.RoundTypes
local Round = table.Copy(RoundTypes.AP) -- inherit from AP

ACE.AmmoBlacklist.HP = ACE.AmmoBlacklist.AP

Round.type = "Ammo" --Tells the spawn menu what entity to spawn
Round.name = "[HP] - " .. ACFTranslation.HP[1] --Human readable name
Round.model = "models/munitions/round_100mm_shot.mdl" --Shell flight model
Round.desc = ACFTranslation.HP[2]
Round.netid = 3 --Unique ammotype ID for network transmission

Round.Type  = "HP"

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

	PlayerData, Data, ServerData, GUIData = ACE_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

	--Shell sturdiness calcs
	Data.ProjMass = math.max(GUIData.ProjVolume * 0.5, 0) * 7.9 / 1000 --(Volume of the projectile as a cylinder - Volume of the cavity) * density of steel
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local Energy = ACE_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)

	local MaxVol = ACE_RoundShellCapacity(Energy.Momentum, Data.FrArea, Data.Caliber, Data.ProjLength)
	GUIData.MinCavVol = 0
	GUIData.MaxCavVol = math.min(GUIData.ProjVolume, MaxVol)
	Data.CavVol = math.Clamp(PlayerData.Data5, GUIData.MinCavVol, GUIData.MaxCavVol)

	Data.ProjMass = ((Data.FrArea * Data.ProjLength) - Data.CavVol) * 7.9 / 1000 --Volume of the projectile as a cylinder * fraction missing due to hollow point (Data5) * density of steel
	Data.MuzzleVel = ACE_MuzzleVelocity(Data.PropMass, Data.ProjMass, Data.Caliber)
	local ExpRatio = Data.CavVol / GUIData.ProjVolume
	Data.ShovePower = 0.2 + ExpRatio / 2
	Data.ExpCaliber = Data.Caliber + ExpRatio * Data.ProjLength
	Data.PenArea = (3.1416 * Data.ExpCaliber / 2) ^ 2 ^ ACE.PenAreaMod
	Data.DragCoef = (Data.FrArea / 10000) / Data.ProjMass
	Data.LimitVel = 400 --Most efficient penetration speed in m/s
	Data.KETransfert = 0.1 --Kinetic energy transfert to the target for movement purposes
	Data.Ricochet = 72										--Base ricochet angle

	Data.BoomPower = Data.PropMass

	if SERVER then --Only the crates need this part
		ServerData.Id = PlayerData.Id
		ServerData.Type = PlayerData.Type
		return table.Merge(Data,ServerData)
	end

	if CLIENT then --Only tthe GUI needs this part
		GUIData = table.Merge(GUIData, Round.getDisplayData(Data))
		return table.Merge(Data,GUIData)
	end

end


function Round.getDisplayData(Data)
	local GUIData = {}
	local Energy = ACE_Kinetic(Data.MuzzleVel * 39.37, Data.ProjMass, Data.LimitVel)
	GUIData.MaxKETransfert = Energy.Kinetic * Data.ShovePower
	GUIData.MaxPen = (Energy.Penetration / Data.PenArea) * ACE.KEtoRHA

	return GUIData
end


function Round.network( Crate, BulletData )

	Crate:SetNWString( "AmmoType", "HP" )
	Crate:SetNWString( "AmmoID", BulletData.Id )
	Crate:SetNWFloat( "Caliber", BulletData.Caliber )
	Crate:SetNWFloat( "ProjMass", BulletData.ProjMass )
	Crate:SetNWFloat( "PropMass", BulletData.PropMass )
	Crate:SetNWFloat( "ExpCaliber", BulletData.ExpCaliber )
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
		"Max Penetration: ", math.floor(DData.MaxPen), " mm\n",
		"Expanded Caliber: ", math.floor(BulletData.ExpCaliber * 10), " mm\n",
		"Imparted Energy: ", math.floor(DData.MaxKETransfert), " KJ"
	}

	return table.concat(str)

end

function Round.guicreate( Panel, Table )

	acemenupanel:AmmoSelect( ACE.AmmoBlacklist.HP )

	ACE_UpperCommonDataDisplay()

	acemenupanel:AmmoSlider("PropLength",0,0,1000,3, "Propellant Length", "")	--Propellant Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",0,0,1000,3, "Projectile Length", "")	--Projectile Length Slider (Name, Value, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("CavVol",0,0,1000,2, "Hollow Point Length", "") --Hollow Point Cavity Slider (Name, Value, Min, Max, Decimals, Title, Desc)

	acemenupanel:AmmoCheckbox("Tracer", "Tracer", "")			--Tracer checkbox (Name, Title, Desc)
	acemenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", "" )

	acemenupanel:CPanelText("KEDisplay", "")			--Proj muzzle KE (Name, Desc)
	acemenupanel:CPanelText("RicoDisplay", "")	--estimated rico chance
	acemenupanel:CPanelText("PenetrationDisplay", "")	--Proj muzzle penetration (Name, Desc)

	Round.guiupdate( Panel, Table )

end

function Round.guiupdate( Panel )

	local PlayerData = {}
		PlayerData.Id = acemenupanel.AmmoData.Data.id			--AmmoSelect GUI
		PlayerData.Type = "HP"										--Hardcoded, match as Round.Type instead
		PlayerData.PropLength = acemenupanel.AmmoData.PropLength	--PropLength slider
		PlayerData.ProjLength = acemenupanel.AmmoData.ProjLength	--ProjLength slider
		PlayerData.Data5 = acemenupanel.AmmoData.CavVol
		PlayerData.Tracer	= acemenupanel.AmmoData.Tracer
		PlayerData.TwoPiece	= acemenupanel.AmmoData.TwoPiece

	local Data = Round.convert( Panel, PlayerData )

	RunConsoleCommand( "acemenu_data1", acemenupanel.AmmoData.Data.id )
	RunConsoleCommand( "acemenu_data2", PlayerData.Type )
	RunConsoleCommand( "acemenu_data3", Data.PropLength )		--For Gun ammo, Data3 should always be Propellant
	RunConsoleCommand( "acemenu_data4", Data.ProjLength )		--And Data4 total round mass
	RunConsoleCommand( "acemenu_data5", Data.CavVol )
	RunConsoleCommand( "acemenu_data10", Data.Tracer )
	RunConsoleCommand( "acemenu_data11", Data.TwoPiece )

	acemenupanel:AmmoSlider("PropLength",Data.PropLength,Data.MinPropLength,Data.MaxTotalLength,3, "Propellant Length", "Propellant Mass : " .. (math.floor(Data.PropMass * 1000)) .. " g" )	--Propellant Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("ProjLength",Data.ProjLength,Data.MinProjLength,Data.MaxTotalLength,3, "Projectile Length", "Projectile Mass : " .. (math.floor(Data.ProjMass * 1000)) .. " g")	--Projectile Length Slider (Name, Min, Max, Decimals, Title, Desc)
	acemenupanel:AmmoSlider("CavVol",Data.CavVol,Data.MinCavVol,Data.MaxCavVol,2, "Hollow Point Cavity Volume", "Expanded caliber : " .. (math.floor(Data.ExpCaliber * 10)) .. " mm") --Hollow Point Cavity Slider (Name, Min, Max, Decimals, Title, Desc)

	ACE_UpperCommonDataDisplay( Data, PlayerData )
	ACE_CommonDataDisplay( Data )
end

list.Set( "APRoundTypes", "HP", Round )
ACE.RoundTypes[Round.Type] = Round     --Set the round properties
ACE.IdRounds[Round.netid] = Round.Type --Index must equal the ID entry in the table above, Data must equal the index of the table above