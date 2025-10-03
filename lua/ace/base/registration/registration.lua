
-- Register all the entities that were registered with the functions provided below.
-- Once you edit this file. Force an addon reload from globals to repopulate.

local ACE = ACE or {}
local Weapons = ACE.Weapons
local Classes = ACE.Classes
local MuzzlesFlashes = ACE.MuzzleFlashes

Classes.GunClass        = {}
Classes.Rack            = {}
Classes.Radar           = {}

Weapons.Ammo            = {} --end ammo containers listing
Weapons.LegacyAmmo      = {}

Weapons.Guns            = {}
Weapons.Racks           = {}
Weapons.Engines         = {}
Weapons.Gearboxes       = {}
Weapons.FuelTanks       = {}
Weapons.FuelTanksSize   = {}
Weapons.Radars          = {}

--Small reminder of Mobility table. Still being used in stuff like starfall/e2. This can change
Weapons.Mobility        = {}

ACE.Guidance = {}

ACE.GSounds.GunFire     = {}
ACE.ModelData           = {}
ACE.MineData            = {}

-- setup base classes
local gun_base = {
	ent    = "ace_gun",
	type   = "Guns"
}
local ammo_base = {
	ent    = "ace_ammo",
	type   = "Ammo"
}
local engine_base = {
	ent    = "ace_engine",
	type   = "Engines"
}
local gearbox_base = {
	ent    = "ace_gearbox",
	type   = "Gearboxes",
	sound  = "vehicles/junker/jnk_fourth_cruise_loop2.wav"
}
local fueltank_base = {
	ent    = "ace_fueltank",
	type   = "FuelTanks"
}
local rack_base = {
	ent    = "ace_rack",
	type   = "Racks"
}
local radar_base = {
	ent    = "ace_radar",
	type   = "Radars"
}
local trackradar_base = {
	ent    = "ace_trackingradar",
	type   = "Radars"
}
local irst_base = {
	ent    = "ace_irst",
	type   = "Radars"
}

-- add gui stuff to base classes if this is client
if CLIENT then
	gun_base.guicreate           = function( _, Table ) ACFGunGUICreate( Table )		end or nil
	gun_base.guiupdate           = function() return end

	engine_base.guicreate        = function( _, tbl ) ACE_EngineGUI_Update( tbl )		end or nil

	gearbox_base.guicreate       = function( _, tbl ) ACFGearboxGUICreate( tbl )		end or nil
	gearbox_base.guiupdate       = function() return end

	fueltank_base.guicreate      = function( _, tbl ) ACFFuelTankGUICreate( tbl )		end or nil
	fueltank_base.guiupdate      = function( _, tbl ) ACFFuelTankGUIUpdate( tbl )		end or nil

	radar_base.guicreate         = function( _, Table ) ACFRadarGUICreate( Table )	end
	radar_base.guiupdate         = function() return end

	trackradar_base.guicreate    = function( _, Table ) ACFTrackRadarGUICreate( Table )  end or nil
	trackradar_base.guiupdate    = function() return end

	irst_base.guicreate          = function( _, Table ) ACFIRSTGUICreate( Table )		end or nil
	irst_base.guiupdate          = function() return end
end

-- some factory functions for defining ents

--Gun class definition
function ACE.RegisterWeaponClass( id, data )
	data.id = id
	Classes.GunClass[id] = data
end

-- Gun definition
function ACE.RegisterWeapon( id, data )
	data.id = id
	data.round.id = id
	table.Inherit( data, gun_base )
	Weapons.Guns[id] = data
end

-- Muzzleflash definition. The definitions are likely to be placed at the same location as the gun itself
function ACE_DefineMuzzleFlash(id, data)
	data.id = id
	MuzzlesFlashes[id] = data
end

function ACE_DefineAmmoCrate( id, data )
	data.id = id
	table.Inherit( data, ammo_base )
	Weapons.Ammo[id] = data
end

function ACE_DefineLegacyAmmoCrate( id, data )
	data.id = id
	Weapons.LegacyAmmo[id] = data
end

-- Rack definition
function ACE.RegisterRack( id, data )
	data.id = id
	table.Inherit( data, rack_base )
	Weapons.Racks[id] = data
end

-- Rack class definition
function ACE.RegisterRackClass( id, data )
	data.id = id
	Classes.Rack[id] = data
end

--Engine definition
function ACE.RegisterEngine( id, data )
	if (data.year or 0) < ACE.Year then
		local engineData = ACE_CalcEnginePerformanceData(data.torquecurve or ACE.GenericTorqueCurves[data.enginetype], data.torque, data.idlerpm, data.limitrpm)

		data.peaktqrpm    = engineData.peakTqRPM
		data.peakpower    = engineData.peakPower
		data.peakpowerrpm = engineData.peakPowerRPM
		data.peakminrpm   = engineData.powerbandMinRPM
		data.peakmaxrpm   = engineData.powerbandMaxRPM
		data.curvefactor  = (data.limitrpm - data.idlerpm) / data.limitrpm

		data.id = id
		table.Inherit( data, engine_base )
		Weapons.Engines[id] = data
		Weapons.Mobility[id] = data
	end
end

-- Gearbox definition
function ACE.RegisterGearbox( id, data )
	data.id = id
	table.Inherit( data, gearbox_base )
	Weapons.Gearboxes[id] = data
	Weapons.Mobility[id] = data
end

-- fueltank definition
function ACE.RegisterFuelTank( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	Weapons.FuelTanks[id] = data
	Weapons.Mobility[id] = data
end

-- fueltank size definition
function ACE.RegisterFuelTankSize( id, data )
	data.id = id
	table.Inherit( data, fueltank_base )
	Weapons.FuelTanksSize[id] = data
end

-- Radar Class definition
function ACE.RegisterRadarClass( id, data )
	data.id = id
	Classes.Radar[id] = data
end

-- Radar definition
function ACE.RegisterRadar( id, data )
	data.id = id
	table.Inherit( data, radar_base )
	Weapons.Radars[id] = data
end

-- Tracking Radar Class definition
function ACE_RegisterTrackRadarClass( id, data )
	data.id = id
	Classes.Radar[id] = data
end

-- Tracking Radar definition
function ACE.RegisterTrackRadar( id, data )
	data.id = id
	table.Inherit( data, trackradar_base )
	Weapons.Radars[id] = data
end

-- Tracking Radar Class definition
function ACE.RegisterIRSTClass( id, data )
	data.id = id
	Classes.Radar[id] = data
end

-- Tracking Radar definition
function ACE.RegisterIRST( id, data )
	data.id = id
	table.Inherit( data, irst_base )
	Weapons.Radars[id] = data
end

--Step 2: gather specialized sounds. Normally sounds that have associated sounds into it. Literally using the string path as id.
function ACE.RegisterWeaponFireSound( id, data )
	data.id = id
	ACE.GSounds.GunFire[id] = data
end


function ACE.RegisterGuidance( id, data )
	data.id = id
	ACE.Guidance[id] = data
end

function ACE_DefineModelData( id, data )
	data.id = id
	ACE.ModelData[id] = data
	ACE.ModelData[data.Model] = data -- I will allow both model or fast name as id.
end

function ACE_DefineMine(id, data)
	data.id = id
	ACE.MineData[id] = data
end

