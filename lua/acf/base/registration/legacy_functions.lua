local ACE = ACE or {}

--- Deprecated function names support.

--Gun class definition
function ACF_defineGunClass( id, data )
    ACE.RegisterWeaponClass( id, data )
end

-- Gun definition
function ACF_defineGun( id, data )
    ACE.RegisterWeapon( id, data )
end

-- Rack definition
function ACF_DefineRack( id, data )
    ACE.RegisterRack( id, data )
end

-- Rack class definition
function ACF_DefineRackClass( id, data )
    ACE.RegisterRackClass( id, data )
end

--Engine definition
function ACF_DefineEngine( id, data )
    ACE.RegisterEngine( id, data )
end

-- Gearbox definition
function ACF_DefineGearbox( id, data )
    ACE.RegisterGearbox( id, data )
end

-- fueltank definition
function ACF_DefineFuelTank( id, data )
    ACE.RegisterFuelTank( id, data )
end

-- fueltank size definition
function ACF_DefineFuelTankSize( id, data )
    ACE.RegisterFuelTankSize( id, data )
end

-- Radar Class definition
function ACF_DefineRadarClass( id, data )
    ACE.RegisterRadarClass( id, data )
end

-- Radar definition
function ACF_DefineRadar( id, data )
    ACE.RegisterRadar( id, data )
end

-- Tracking Radar Class definition
function ACF_DefineTrackRadarClass( id, data )
    ACE_RegisterTrackRadarClass( id, data )
end

-- Tracking Radar definition
function ACF_DefineTrackRadar( id, data )
    ACE.RegisterTrackRadar( id, data )
end

-- Tracking Radar Class definition
function ACF_DefineIRSTClass( id, data )
    ACE.RegisterIRSTClass( id, data )
end

-- Tracking Radar definition
function ACF_DefineIRST( id, data )
    ACE.RegisterIRST( id, data )
end
