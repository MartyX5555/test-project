local ACE = ACE or {}

--- Deprecated function names support.

-- These functions are kept for backwards compatibility with older addons, but they will be removed in the future. Please update your addons to use the new function names.
local ACF_OlddefineGunClass = ACF_OlddefineGunClass or ACF_defineGunClass
local ACF_OlddefineGun = ACF_OlddefineGun or ACF_defineGun
local ACF_OlddefineRack = ACF_OlddefineRack or ACF_DefineRack
local ACF_OlddefineRackClass = ACF_OlddefineRackClass or ACF_DefineRackClass
local ACF_OlddefineEngine = ACF_OlddefineEngine or ACF_DefineEngine
local ACF_OlddefineGearbox = ACF_OlddefineGearbox or ACF_DefineGearbox
local ACF_OlddefineFuelTank = ACF_OlddefineFuelTank or ACF_DefineFuelTank
local ACF_OlddefineFuelTankSize = ACF_OlddefineFuelTankSize or ACF_DefineFuelTankSize
local ACF_OlddefineRadarClass = ACF_OlddefineRadarClass or ACF_DefineRadarClass
local ACF_OlddefineRadar = ACF_OlddefineRadar or ACF_DefineRadar
local ACF_OlddefineTrackRadarClass = ACF_OlddefineTrackRadarClass or ACF_DefineTrackRadarClass
local ACF_OlddefineTrackRadar = ACF_OlddefineTrackRadar or ACF_DefineTrackRadar
local ACF_OlddefineIRSTClass = ACF_OlddefineIRSTClass or ACF_DefineIRSTClass
local ACF_OlddefineIRST = ACF_OlddefineIRST or ACF_DefineIRST

--Gun class definition
function ACF_defineGunClass( id, data )
    if ACF_OlddefineGunClass then
        ACF_OlddefineGunClass( id, data )
    end
    ACE.RegisterWeaponClass( id, data )
end

-- Gun definition
function ACF_defineGun( id, data )
    if ACF_OlddefineGun then
        ACF_OlddefineGun( id, data )
    end
    ACE.RegisterWeapon( id, data )
end

-- Rack definition
function ACF_DefineRack( id, data )
    if ACF_OlddefineRack then
        ACF_OlddefineRack( id, data )
    end
    ACE.RegisterRack( id, data )
end

-- Rack class definition
function ACF_DefineRackClass( id, data )
    if ACF_OlddefineRackClass then
        ACF_OlddefineRackClass( id, data )
    end
    ACE.RegisterRackClass( id, data )
end

--Engine definition
function ACF_DefineEngine( id, data )
    if ACF_OlddefineEngine then
        ACF_OlddefineEngine( id, data )
    end
    ACE.RegisterEngine( id, data )
end

-- Gearbox definition
function ACF_DefineGearbox( id, data )
    if ACF_OlddefineGearbox then
        ACF_OlddefineGearbox( id, data )
    end
    ACE.RegisterGearbox( id, data )
end

-- fueltank definition
function ACF_DefineFuelTank( id, data )
    if ACF_OlddefineFuelTank then
        ACF_OlddefineFuelTank( id, data )
    end
    ACE.RegisterFuelTank( id, data )
end

-- fueltank size definition
function ACF_DefineFuelTankSize( id, data )
    if ACF_OlddefineFuelTankSize then
        ACF_OlddefineFuelTankSize( id, data )
    end
    ACE.RegisterFuelTankSize( id, data )
end

-- Radar Class definition
function ACF_DefineRadarClass( id, data )
    if ACF_OlddefineRadarClass then
        ACF_OlddefineRadarClass( id, data )
    end
    ACE.RegisterRadarClass( id, data )
end

-- Radar definition
function ACF_DefineRadar( id, data )
    if ACF_OlddefineRadar then
        ACF_OlddefineRadar( id, data )
    end
    ACE.RegisterRadar( id, data )
end

-- Tracking Radar Class definition
function ACF_DefineTrackRadarClass( id, data )
    if ACF_OlddefineTrackRadarClass then
        ACF_OlddefineTrackRadarClass( id, data )
    end
    ACE.RegisterTrackRadarClass( id, data )
end

-- Tracking Radar definition
function ACF_DefineTrackRadar( id, data )
    if ACF_OlddefineTrackRadar then
        ACF_OlddefineTrackRadar( id, data )
    end
    ACE.RegisterTrackRadar( id, data )
end

-- Tracking Radar Class definition
function ACF_DefineIRSTClass( id, data )
    if ACF_OlddefineIRSTClass then
        ACF_OlddefineIRSTClass( id, data )
    end
    ACE.RegisterIRSTClass( id, data )
end

-- Tracking Radar definition
function ACF_DefineIRST( id, data )
    if ACF_OlddefineIRST then
        ACF_OlddefineIRST( id, data )
    end
    ACE.RegisterIRST( id, data )
end
