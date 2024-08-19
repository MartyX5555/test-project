-- init.lua

AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )

include("shared.lua")

DEFINE_BASECLASS( "base_wire_entity" )

--local Classes = ACE.Classes
--local GunClasses	= Classes.GunClass
--local RackClasses	= Classes.Rack

local GunTable	= ACE.Weapons.Guns
local RackTable	= ACE.Weapons.Racks

local FireSound = "ace_weapons/multi_sound/40mm_multi.mp3" -- Not the Missile ignition sound but the tick the rack does to deploy the missile.
local ReadySound = "acf_extra/airfx/weapon_select.wav"
local ReloadSound = "acf_extra/tankfx/resupply_single.wav"
local EmptySound = "weapons/pistol/pistol_empty.wav"

--[[

	Expected behaviour - RACK

	1.- Spawn it as usual. The model and its data is according to how it was before. Updates as usual too.
	2.- The reload system is manual. This means, you must input the reload to keep it ready to fire. While the reload is ON, the rack must fill until all the rackpos are ready.
	3.- Must have a dual reference among both entities (launcher and missile). This, to allow communications from one point to the other.
	4.- Ability to define if you want to fire a missile PER click or fire them while holding the button under a defined ROF.
	5.- Ability to set the ROF CORRECTLY, meaning you can fire all the missiles at the rate that you want. Note that reload speed will be same.
	6.- The input 'Target Pos' and 'Track Delay' must persist as usual.

]]

do

	local Inputs = {
		"Fire",
		"Reload (Arms this rack. Its mandatory to set this since racks don't reload automatically)",
		"Target Pos (Defines the Target position for the ordnance in this rack. This only works for Wire and laser guidances.) [VECTOR]",
		"Fire Delay (Defines a sequence delay at which missiles will be fired.)",
		"Track Delay (Sets a specific delay to guidance control over the default one in seconds.\n Note that you cannot override lower values than default.)",
		"Fire Mode (Defines how missiles will be fired.)"
	}
	local Outputs = {
		"Ready (if its ready)",
		"AmmoCount",
	}

	function ENT:Initialize()

		self.BaseClass.Initialize(self)

		self.Ready              = false
		self.MissilePorts       = {}
		self.TimeDelay          = CurTime()
		self.NextFire           = CurTime()
		self.WaitTime           = CurTime()

		self.CurCrate           = 0
		self.CurAmmo            = 0

		self.TargetPos          = vector_origin

		self.DefaultFireDelay   = 1
		self.FireDelay          = 2
		self.FireMode           = 0
		self.OnFireCycle        = false -- Determine if the fire was set into AUTO or not

		self.IsMaster           = true --acf menu jank requirements
		self.Inputs             = WireLib.CreateInputs( self, Inputs )
		self.Outputs            = WireLib.CreateOutputs( self, Outputs )

		self.CurPort            = 1
		self.MissilePorts       = {}
		self.AvailableAmmo      = 0
		self.AmmoLink           = {}


	end

end

local function SetReady( Rack, bool )
	Rack.Ready = bool
	Wire_TriggerOutput(Rack, "Ready", bool and 1 or 0)
end

local function SqrtRetDist( enta, entb )
	if not (IsValid(enta) or IsValid(entb)) then return 0 end
	return (enta:GetPos() - entb:GetPos()):LengthSqr()
end

local function SetNextFire( Rack, delay )
	Rack.NextFire = CurTime() + delay
end

local function HasAmmoOnRack( Rack )
	return Rack.CurAmmo > 0
end

-- Calcs the total ammo as indicator and unlinks crates if they are distant
local function ValidateAmmoCount( Rack )

	local AvailableAmmo = 0
	for _, Crate in pairs(Rack.AmmoLink) do -- UnlinkDistance
		if IsValid( Crate ) and Crate.Load then
			if SqrtRetDist( Rack, Crate ) < 512 ^ 2 then
				AvailableAmmo = AvailableAmmo + (Crate.Ammo or 0)
			else
				Rack:Unlink( Crate )
				Rack:EmitSound("physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav",500,100)
			end
		end
	end

	Rack.AvailableAmmo = AvailableAmmo
	Wire_TriggerOutput(Rack, "AmmoCount", AvailableAmmo)

end

--Builds/Rebuilds the Missile Ports. Meant to be used only when the rack is created
local function BuildMissilePorts( Rack )

	for i, portdata in ipairs(Rack.mountpoints) do

		Rack.MissilePorts[i] = {
			Missile    = NULL,
			IsDamaged  = false,
			Pos        = portdata.pos + portdata.offset,
			ScaleDir   = portdata.scaledir
		}

	end

end

--Check to see if the rack is not damaged and, if its meant for loading purposes, empty.
local function CheckPortStatus(portdata, mode)

	if portdata.IsDamaged then return false end

	if mode == "load" and IsValid(portdata.Missile) then
		return false
	end
	return true
end

--Tries to find an available port in the rack. Returns nil if nothing was found
local function FindAvailablePort( Rack )

	local Id, Port

	for i, portdata in ipairs( Rack.MissilePorts ) do

		if CheckPortStatus(portdata, "load") then
			Port = portdata
			Id = i
			break
		end
	end

	return Port, Id
end

--Returns the current port according to the internal self.CurPort or via the given portId.
local function GetCurrentPort( Rack, PortId )
	return Rack.MissilePorts[ PortId or Rack.CurPort ] or {}
end

--Note: global function. Meant to be an independant function. So missiles can be created easily from anywhere (apart of being used in racks.)
local function CreateMissile( Rack, Pos, Ang, BulletData )

	local Missile = ents.Create("ace_missile")
	if IsValid(Missile) then

		local MissileData = GunTable[BulletData.Id]

		Missile:CPPISetOwner(Rack:CPPIGetOwner())
		Missile:SetPos(Pos)
		Missile:SetAngles(Ang)

		Missile:SetModel( MissileData.round.model or MissileData.model )
		Missile:PhysicsInit( SOLID_VPHYSICS )
		Missile:SetMoveType( MOVETYPE_VPHYSICS )
		Missile:SetSolid( SOLID_VPHYSICS )

		Missile.DoNotDuplicate  = true
		Missile.BulletData = BulletData
		Missile.Launcher = Rack

		Missile:Spawn()

		return Missile
	end
	return NULL
end

function ENT:Link( Target )

	-- Don't link if it's not an ammo crate
	if not IsValid( Target ) or Target:GetClass() ~= "acf_ammo" then
		return false, "Racks can only be linked to ammo crates!"
	end

	-- Don't link if it's a blacklisted round type for this gun
	local Blacklist = ACE.AmmoBlacklist[ Target.RoundType ] or {}

	if table.HasValue( Blacklist, self.gunclass ) then
		return false, "That round type cannot be used with this gun!"
	end

	local bdata = Target.BulletData

	-- Don't link if it's a refill crate
	if bdata["RoundType"] == "Refill" or bdata["Type"] == "Refill" then
		return false, "Refill crates cannot be linked!"
	end

	-- Don't link if it's a blacklisted round type for this rack
	local class = ACE_GetGunValue(bdata, "gunclass")
	local Blacklist = ACE.AmmoBlacklist[ bdata.RoundType or bdata.Type ] or {}

	if not class or table.HasValue( Blacklist, class ) then
		return false, "That round type cannot be used with this rack!"
	end

	-- Dont't link if it's too far from this rack
	if SqrtRetDist( self, Target ) >= 512 ^ 2 then
		return false, "That crate is too far to be connected with this rack!"
	end

	-- Don't link if it's not a missile.
	local ret, msg = ACE_CanLinkRack(self.Id, bdata.Id, bdata, self)
	if not ret then return ret, msg end


	-- Don't link if it's already linked
	for _, v in pairs( self.AmmoLink ) do
		if v == Target then
			return false, "That crate is already linked to this rack!"
		end
	end

	table.insert( self.AmmoLink, Target )
	table.insert( Target.Master, self )

	return true, "Link successful!"

end

function ENT:Unlink( Target )

	local Success = false
	for Key,Value in pairs(self.AmmoLink) do
		if Value == Target then
			table.remove(self.AmmoLink,Key)
			Success = true
		end
	end

	if Success then
		return true, "Unlink successful!"
	else
		return false, "That entity is not linked to this gun!"
	end

end

function ENT:FireMissile()

	if not self.Reloading then

		SetReady( self, false )

		if HasAmmoOnRack( self ) then

			local portdata = GetCurrentPort( self )
			if CheckPortStatus(portdata) then

				if IsValid(portdata.Missile) then
					portdata.Missile:Launch()
					portdata.Missile = NULL

					self:EmitSound( FireSound, 500, 100 )
				else
					self:EmitSound( EmptySound )
				end
			end

			self.CurAmmo = self.CurAmmo - 1
			self.CurPort = self.CurPort - 1
			self.WaitTime = CurTime() + self.FireDelay * 1.5

		else
			if CurTime() > self.WaitTime then
				self:EmitSound( EmptySound )
			end
		end
	end
end

function ENT:CanReload()

	--Must be allowed to do so.
	if not self.AllowReload then
		return false
	end

	--When the rack finishes firing, theres a time where the reload must wait before proceeding.
	if self.WaitTime > CurTime() then
		return false
	end

	--Do nothing if theres no ammo available in crates.
	if self.AvailableAmmo == 0 then
		return false
	end

	--Stop if the rack is already reloaded.
	if self.CurAmmo >= self.MaxAmmo then
		return false
	end

	return true
end

function ENT:FindNextCrate()

	local MaxAmmo = #self.AmmoLink
	local AmmoEnt = nil
	local i = 0

	while i <= MaxAmmo and not (IsValid(AmmoEnt) and AmmoEnt.Ammo > 0) do -- need to check ammoent here? returns if found

		self.CurCrate = self.CurCrate + 1
		if self.CurCrate > MaxAmmo then self.CurCrate = 1 end

		AmmoEnt = self.AmmoLink[self.CurCrate]
		if IsValid(AmmoEnt) and AmmoEnt.Ammo > 0 and AmmoEnt.Load and AmmoEnt.Legal then
			return AmmoEnt
		end
		AmmoEnt = nil

		i = i + 1
	end

	return false
end

function ENT:LoadMissile()

	local Crate = self:FindNextCrate()
	if IsValid(Crate) then

		SetReady( self, false )

		--CODE to create missile here
		local portData, Id = FindAvailablePort( self )
		if not portData then self.Reloading = false return end

		self.CurPort = Id

		local BulletData = table.Copy(Crate.BulletData)
		local MissileData = GunTable[BulletData.Id]

		local offset = (MissileData.modeldiameter or MissileData.caliber) / (2.54 * 2)
		local MissilePos = portData.Pos + portData.ScaleDir * offset

		local ReloadTime = 1-- math.max( (BulletData.RoundVolume / 500) ^ 0.60, 0.1)
		local Missile = CreateMissile( self, self:LocalToWorld(MissilePos), self:GetAngles(), BulletData )
		if IsValid(Missile) then

			if self.missileCover then
				Missile:SetModel( self.missileCover )
			end

			Missile:SetParent(self)
			portData.Missile = Missile

			timer.Simple(ReloadTime, function()
				if IsValid(self) then

					self.Reloading = false
					--Emits a sound if the reload cannot continue but the final load is ready
					if not self:CanReload() then
						SetReady( self, true )
						self:EmitSound( ReadySound )
					end
				end
			end)

			self.CurAmmo = self.CurAmmo + 1
			Crate.Ammo = Crate.Ammo - 1

			self:EmitSound( ReloadSound )
			print("Loading Round", self.CurAmmo, self.CurPort)

		else
			self.Reloading = false
		end
	else
		self.Reloading = false
	end

end

function ENT:TriggerInput( iname , value )

	if iname == "Fire" then

		if value ~= 0 then

			if self.FireMode == 0 then --auto fire
				self.OnFireCycle = true
			elseif self.FireMode >= 1 then --semi-auto fire
				self:FireMissile()
			end

		else
			self.OnFireCycle = false
		end

	elseif iname == "Reload" then
		self.AllowReload = value and true or false
	elseif iname == "Target Pos" then
		self.TargetPos = value
		Wire_TriggerOutput(self, "Position", value)
	elseif iname == "Fire Delay" then
		if value <= 0 then
			value = self.DefaultFireDelay
		end
		self.FireDelay = math.max(value, 0.05)
	elseif iname == "Track Delay" then
		self.TrackDelay = value
	elseif iname == "Fire Mode" then
		self.FireMode = math.Clamp(value,0,1)
	end
end

function ENT:Think()

	local Time = CurTime()

	-- Overlays, non insta refresh features should go here.
	if Time >= self.TimeDelay then

		ValidateAmmoCount( self )
		self:UpdateWireOverlay()

		self.TimeDelay = Time + 0.5
	end

	-- Cycling fire is at 66 ticks here. The max RPM possible: 6000 RPM
	if Time >= self.NextFire and not self.Reloading then

		if HasAmmoOnRack( self ) then
			SetReady( self, true )
		end

		if self.OnFireCycle and self.FireMode == 0 then -- This is like self.Firing, but meant for automatic mode only.
			self:FireMissile()
			SetNextFire( self, self.FireDelay)
		end

	end

	-- AllowReload is sent via input. It will be constant if no ammo is available.
	if self:CanReload() and not self.Reloading then
		self.Reloading = true
		self:LoadMissile()
	end

	self:NextThink(Time)
	return true

end

function MakeACE_Rack(Owner, Pos, Angle, Id )

	if not Owner:CheckLimit("_acf_rack") then return false end
	local Rack = ents.Create("acf_rack")
	if not IsValid(Rack) then return false end

	Rack:CPPISetOwner(Owner)
	Rack:SetAngles(Angle)
	Rack:SetPos(Pos)
	Rack:Spawn()

	if not ACE_CheckRack( Id ) then
		Id = "1xRK"
	end

	local rackdef = RackTable[Id]

	Rack.Id          = Id
	Rack.model       = rackdef.model
	Rack.gunclass    = rackdef.gunclass
	Rack.weight      = rackdef.weight
	Rack.missileCover = rackdef.rackmdl --could be invalid if this value doesnt exist
	Rack.mountpoints = rackdef.mountpoints
	Rack.MaxAmmo     = rackdef.magsize or 1

	BuildMissilePorts( Rack )

	Rack:SetModel( Rack.model )
	Rack:PhysicsInit( SOLID_VPHYSICS )
	Rack:SetMoveType( MOVETYPE_VPHYSICS )
	Rack:SetSolid( SOLID_VPHYSICS )

	local phys = Rack:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(Rack.weight)
	end

	Rack:SetNWString("WireName",Rack.name)

	hook.Call("ACF_RackCreate", nil, Rack)

	undo.Create( "acf_rack" )
		undo.AddEntity( Rack )
		undo.SetPlayer( Owner )
	undo.Finish()

	return Rack

end
list.Set( "ACFCvars", "acf_rack" , {"id"} )
duplicator.RegisterEntityClass("acf_rack", MakeACE_Rack, "Pos", "Angle", "Id")

function ENT:PreEntityCopy()

	local info = {}
	local entids = {}
	for _, Value in pairs(self.AmmoLink) do				--First clean the table of any invalid entities
		if not Value:IsValid() then
			table.remove(self.AmmoLink, Value)
		end
	end
	for _, Value in pairs(self.AmmoLink) do				--Then save it
		table.insert(entids, Value:EntIndex())
	end
	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier( self, "ACFAmmoLink", info )
	end

	duplicator.StoreEntityModifier( self, "ACFRackInfo", {Id = self.Id} )

	--Wire dupe info
	self.BaseClass.PreEntityCopy( self )

end

function ENT:PostEntityPaste( Player, Ent, CreatedEntities )

	self.Id = Ent.EntityMods.ACFRackInfo.Id

	--MakeACF_Rack(self:CPPIGetOwner(), self:GetPos(), self:GetAngles(), self.Id, self)

	if Ent.EntityMods and Ent.EntityMods.ACFAmmoLink and Ent.EntityMods.ACFAmmoLink.entities then
		local AmmoLink = Ent.EntityMods.ACFAmmoLink
		if AmmoLink.entities and next(AmmoLink.entities) then
			for _,AmmoID in pairs(AmmoLink.entities) do
				local Ammo = CreatedEntities[ AmmoID ]
				if Ammo and Ammo:IsValid() and Ammo:GetClass() == "acf_ammo" then
					self:Link( Ammo )
				end
			end
		end
		Ent.EntityMods.ACFAmmoLink = nil
	end

	--Wire dupe info
	self.BaseClass.PostEntityPaste( self, Player, Ent, CreatedEntities )

end

local function GetStatus( Rack )

	local Status = "Amongos"

	if Rack.Ready then
		Status = "Ready"
	else
		if Rack.Reloading and Rack.AvailableAmmo > 0 then
			Status = "Loading"
		else
			if Rack.WaitTime > CurTime() then
				Status = "Firing"
			else
				Status = "Empty"
			end
		end
	end

	return Status
end

--New Overlay text that is shown when you are looking at the rack.
function ENT:UpdateWireOverlay()

	local Ammo		= self.CurAmmo	-- Ammo count
	local FireRate	= self.FireDelay or 1	-- How many time take one lauch from another. in secs
	--local Reload		= self:GetNWFloat("Reload")		-- reload time. in secs
	--local ReloadBonus	= self.ReloadMultiplierBonus or 0  -- the word explains by itself
	local Status		= GetStatus( self )				-- this was used to show ilegality issues before. Now this shows about rack state (reloading?, ready?, empty and so on...)

	local txt = "-  " .. Status .. "  -"

	if Ammo > 0 then
		if Ammo == 1 then
			txt = txt .. "\n" .. Ammo .. " Launch left"
		else
			txt = txt .. "\n" .. Ammo .. " Launches left"
		end

		txt = txt .. "\n\nFire Rate: " .. math.Round(FireRate, 2) .. " secs"
		--txt = txt .. "\nReload Time: " .. math.Round(Reload, 2) .. " secs"

		--if ReloadBonus > 0 then
		--	txt = txt .. "\n" .. math.floor(ReloadBonus * 100) .. "% Reload Time Decreased"
		--end
	else
		if #self.AmmoLink ~= 0 then
			txt = txt .. "\n\nProvided with ammo.\n"
		else
			txt = txt .. "\n\nAmmo not found!\n"
		end
	end

	--if not self.Legal then
		--txt = txt .. "\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	--end

	self:SetOverlayText(txt)

end