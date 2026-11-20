--[[
	ACE Missile Rack Entity (Server)

	Migrated port-based rack architecture (MissilePorts) with:
	- Numeric mountpoints and per-port occupancy / IsDamaged readiness.
	- Manual reload toggle, per-rack Fire Delay minimum, Fire Mode (auto / semi-auto), and Rail Launch control.
	- On-demand Refill crate reload bonus via ACE.RefillCrates (O(1) when no Refill crates exist).

	Future ACE-Project-Team parity roadmap:
	- Rail-active seeker preview: "Activate Guidance" input + "AcquiredTarget", "TargetDirection",
		"Current Missile", "Missile Info", "CurMissile", and "PositionFiredMissile" Wire outputs.
	- Remote scuttle support: "Detonate Missile" input (ScuttleMissiles).
	- Per-port damage integration via ENT:SetPortDamaged(portId, damaged) from ACE_OnDamage / repair tools,
		and chain scuttle of mounted missiles when the rack itself is destroyed.
	- Points system event hooks (ACE.PointsInputChanged) and firepower overlay readouts.
	- Per-missile reload timing fields (firedelay, reloadspeed, reloaddelay) if adopting upstream ordnance economy.
]]--

--[[
	Port Values and how they are interpreted:

	Ports are stored inside of a table, number indexed with the slot number used on the rack/pod
	Inside, we have the following values:

	Missile (ENTITY): This is the Missile, being armed, still not launched by the rack. Once the missile is launched, this becomes NULL.
	OccupiedBy (ENTITY): Once you fire the missile, this one will be used to represent the missile while its still inside of the rack, only if you are using the rail.
	IsDamaged (bool): Determine if the port is good to work as intended. In a future, we can expand this.
	Pos: The Missile position, relative to the rack/pod
	ScaleDir:

		Missile		= NULL,
		OccupiedBy	= NULL,
		IsDamaged	= false,
		Pos			= pos + offset,
		ScaleDir	= portdata.scaledir and Vector(portdata.scaledir) or Vector(0, 0, 0)


]]--

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_base")

CreateConVar("sbox_max_ace_rack", 12) -- Racks limit

local GunClasses	= ACE.Classes.GunClass
local RackClasses	= ACE.Classes.Rack

local GunTable		= ACE.Weapons.Guns
local RackTable		= ACE.Weapons.Racks

local AmmoLinkDistBase = 512

local FireSound		= "ace_weapons/multi_sound/40mm_multi.mp3"
local ReadySound	= "acf_extra/airfx/weapon_select.mp3"
local ReloadSound	= "acf_extra/tankfx/resupply_single.mp3"
local EmptySound	= "weapons/pistol/pistol_empty.wav"

do
	local Inputs = {
		"Fire",
		"Reload (Arms this rack. Its mandatory to set this since racks don't reload automatically.)",
		"Target Pos (Defines the Target position for the ordnance in this rack. This only works for Wire and laser guidances.) [VECTOR]",
		"Fire Delay (Defines a sequence delay in seconds at which missiles will be fired, clamped to the rack minimum.)",
		"Track Delay (Sets a specific delay to guidance control over the default one in seconds.\n Note that you cannot override lower values than default.)",
		"Fire Mode (Defines how missiles will be fired: 0 = auto, 1 = semi-auto.)",
		"Rail Launch (Enables in-rack rail launch guidance when supported by the rack.)"
	}

	local Outputs = {
		"Ready (Returns if the rack is ready to fire.)",
		"Shots Left (Returns how many missiles are currently loaded on the rack.)",
		"AmmoCount (Returns total available rounds in linked active crates.)",
		"Entity (The rack itself) [ENTITY]",
		"Position [VECTOR]"
	}

	function ENT:Initialize()
		BaseClass.Initialize(self)

		self.Ready					= false
		self.AllowReload			= false
		self.Reloading				= false
		self.ReloadEndTime			= 0
		self.ReloadTime				= 1
		self.ReloadMultiplierBonus	= 0

		self.CurPort				= 1
		self.TotalPorts				= 0
		self.MissilePorts			= {}
		self.CurCrate				= 0
		self.LoadedAmmo				= 0
		self.AvailableAmmo			= 0
		self.AmmoLink				= {}

		self.TimeDelay				= CurTime()
		self.NextFire				= CurTime()
		self.WaitTime				= CurTime()

		self.NextLegalCheck			= ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max)
		self.Legal					= true
		self.LegalIssues			= ""

		self.TargetPos				= vector_origin
		self.TrackDelay				= 0

		self.MinFireDelay			= 0.05
		self.DefaultFireDelay		= 0.5
		self.FireDelay				= 0.5
		self.CustomFireDelay		= nil
		self.FireMode				= 0
		self.OnFireCycle			= false

		self.PodLength				= 0
		self.EnforceFlightInRack	= false
		self.RailLaunch				= false
		self.LaunchKick				= 0

		self.Inaccuracy				= 1
		self.IsMaster				= true
		self.WireDebugName			= "ACE Rack"

		self.Inputs					= self:SetWireInputs(Inputs)
		self.Outputs				= self:SetWireOutputs(Outputs)

		self:TriggerWireOutput("Entity", self)
		self:TriggerWireOutput("Ready", 0)
		self:TriggerWireOutput("Shots Left", 0)
		self:TriggerWireOutput("AmmoCount", 0)
		self:TriggerWireOutput("Position", vector_origin)
	end
end

local function SetReady(Rack, bool)
	Rack.Ready = bool
	Rack:TriggerWireOutput("Ready", bool and 1 or 0)
end

local function SetNextFire(Rack, delay)
	Rack.NextFire = CurTime() + delay
end

local function DistSqrBetween(enta, entb)
	if not (IsValid(enta) and IsValid(entb)) then return 0 end
	return enta:GetPos():DistToSqr(entb:GetPos())
end

local function CountLoadedMissiles(Rack)
	local count = 0
	for _, portdata in ipairs(Rack.MissilePorts) do
		if IsValid(portdata.Missile) then
			count = count + 1
		end
	end
	return count
end

local function HasAmmoOnRack(Rack)
	for _, portdata in ipairs(Rack.MissilePorts) do
		if IsValid(portdata.Missile) then
			return true
		end
	end
	return false
end

local function HasOccupiedPort(Rack)
	for _, portdata in ipairs(Rack.MissilePorts) do
		if IsValid(portdata.Missile) or portdata.IsDamaged then
			return true
		end
	end
	return false
end

-- Check if the provided port can potentially fire
local function CanFireInPort(portdata)
	if not portdata then return false end
	if not next(portdata) then return false end
	if portdata.IsDamaged then return false end

	return IsValid(portdata.Missile)
end

-- Check if the provided port can potentially reload
local function CanReloadInPort(portdata)
	if not portdata then return false end
	if not next(portdata) then return false end
	if portdata.IsDamaged then return false end
	if IsValid(portdata.Missile) then return false end
	if IsValid(portdata.OccupiedBy) then return false end

	return true
end

-- Finds the first available port for reloading
local function FindAvailablePort(Rack)
	for i, portdata in ipairs(Rack.MissilePorts) do
		if CanReloadInPort(portdata) then
			return i, portdata
		end
	end

	return nil
end

-- Finds the next non-empty port to attempt firing; skips empty ports, but treats damaged ports as loaded
local function FindFirePort(Rack)
	local total = Rack.TotalPorts
	if total <= 0 then return nil, nil end

	local idx = Rack.CurPort
	if idx < 1 or idx > total then
		idx = total
	end

	for _ = 1, total do
		local portdata = Rack.MissilePorts[idx]
		if portdata and (IsValid(portdata.Missile) or portdata.IsDamaged) then
			return idx, portdata
		end

		idx = idx - 1
		if idx < 1 then
			idx = total
		end
	end

	return nil, nil
end

local function AdvancePortIndex(Rack, currentIdx)
	local total = Rack.TotalPorts
	if total <= 0 then return 1 end

	local nextIdx = currentIdx - 1
	if nextIdx < 1 then
		nextIdx = total
	end
	Rack.CurPort = nextIdx
end

-- Builds/Rebuilds the numeric MissilePorts table from rack mountpoints
local function BuildMissilePorts(Rack)
	Rack.MissilePorts = {}

	for i, portdata in ipairs(Rack.mountpoints or {}) do
		local pos = portdata.pos or vector_origin
		local offset = portdata.offset or vector_origin

		Rack.MissilePorts[i] = {
			Missile		= NULL,
			OccupiedBy	= NULL,
			IsDamaged	= false,
			Pos			= pos + offset,
			ScaleDir	= portdata.scaledir and Vector(portdata.scaledir) or Vector(0, 0, 0)
		}
	end

	Rack.TotalPorts = #Rack.MissilePorts
	Rack.CurPort = math.max(Rack.TotalPorts, 1)
end

-- Calculates total linked ammo and unlinks crates beyond max distance
local function ValidateAmmoCount(Rack)
	local AvailableAmmo = 0
	local maxDistSqr = AmmoLinkDistBase ^ 2

	for i = #Rack.AmmoLink, 1, -1 do
		local Crate = Rack.AmmoLink[i]
		if not IsValid(Crate) then
			table.remove(Rack.AmmoLink, i)
		elseif DistSqrBetween(Rack, Crate) >= maxDistSqr then
			Rack:Unlink(Crate)
			Rack:EmitSound("physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav", 500, 100)
		elseif Crate.Load then
			AvailableAmmo = AvailableAmmo + (Crate.Ammo or 0)
		end
	end

	Rack.AvailableAmmo = AvailableAmmo
	Rack:TriggerWireOutput("AmmoCount", AvailableAmmo)
end

function ENT:SetPortDamaged(portId, damaged)
	local portdata = self.MissilePorts[portId]
	if not portdata then return false end

	portdata.IsDamaged = damaged

	--Updating the integrity of the rack
	local IsRackDamaged
	for _, portdata in ipairs(self.MissilePorts) do
		if portdata.IsDamaged then
			IsRackDamaged = true
			break
		end
	end
	self.IsRackDamaged = IsRackDamaged
end

function ENT:ClearPortOccupant(portId, missile)
	local portdata = self.MissilePorts[portId]
	if not portdata then return end

	if not missile or portdata.OccupiedBy == missile then
		portdata.OccupiedBy = NULL
	end
end

function ENT:SetLoadedWeight()
	local totalMass = self.Mass or 10

	for _, portdata in ipairs(self.MissilePorts) do
		if IsValid(portdata.Missile) then
			totalMass = totalMass + (portdata.Missile.RoundWeight or 10)
		end
	end

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(totalMass)
	end
end

function ENT:UpdateRefillBonus()
	local refillCrates = ACE.RefillCrates
	if not refillCrates or not next(refillCrates) then
		self.ReloadMultiplierBonus = 0
		return 0
	end

	local totalBonus = 0
	local RackPos = self:GetPos()
	local Efficiency = 0.11 * ACE.AmmoMod -- Copied from ace_ammo, keep in sync
	local minFullEfficiency = 50000 * Efficiency
	local maxDist = ACE.RefillDistance
	local maxDistSqr = maxDist ^ 2

	for crate, _ in pairs(refillCrates) do
		if IsValid(crate) and crate.Ammo > 0 and crate.Load then
			local distSqr = RackPos:DistToSqr(crate:GetPos())

			if distSqr < maxDistSqr then
				local dist = math.sqrt(distSqr)
				dist = math.max(0, dist * 2 - maxDist)

				local bonus = ((crate.Volume or 0.1) / minFullEfficiency) * (maxDist - dist) / maxDist
				totalBonus = totalBonus + bonus
			end
		end
	end

	self.ReloadMultiplierBonus = math.min(totalBonus, 1)
	return self.ReloadMultiplierBonus
end

function ENT:GetFireDelay(bdata)
	if not istable(bdata) then
		return math.max(self.DefaultFireDelay, self.MinFireDelay)
	end

	local gun = GunTable[bdata.Id]
	if not gun then
		return math.max(self.DefaultFireDelay, self.MinFireDelay)
	end

	local class = GunClasses[gun.gunclass]
	local classRof = class and class.rofmod or 1
	local interval = math.max(((bdata.RoundVolume / 500) ^ 0.60) * (gun.rofmod or 1) * classRof, 0.1)

	self.DefaultFireDelay = math.max(interval, self.MinFireDelay)

	if not self.CustomFireDelay then
		self.FireDelay = self.DefaultFireDelay
	end

	self:SetNWFloat("Interval", interval)
	return interval
end

function ENT:GetReloadTime(bdata)
	local Rack = RackTable[self.Id]
	local baseReloadMul = (Rack and Rack.reloadmul) or self.ReloadMultiplier or 1
	local reloadBonus = self:UpdateRefillBonus()
	local mag = math.max(self.MagSize or self.TotalPorts or 1, 1)

	local effectiveMul = (baseReloadMul - (baseReloadMul - 1) * reloadBonus) / (mag ^ 1.1)
	local ret = math.max(self:GetFireDelay(bdata) * effectiveMul, 0.5)

	self:SetNWFloat("Reload", ret)
	return ret
end

function ENT:GetInaccuracy()
	return (self.Inaccuracy or 0) * ACE.GunInaccuracyScale
end

function ENT:CanLoadCaliber(cal)
	return ACE.RackCanLoadCaliber(self.Id, cal)
end

function ENT:CanLinkCrate(crate)
	local bdata = crate.BulletData
	if not bdata then
		return false, "Crate has invalid bullet data!"
	end

	if bdata.RoundType == "Refill" or bdata.Type == "Refill" then
		return false, "Refill crates cannot be linked!"
	end

	local class = ACE.GetGunValue(bdata, "gunclass")
	local Blacklist = ACE.AmmoBlacklist[bdata.RoundType or bdata.Type] or {}

	if not class or table.HasValue(Blacklist, class) then
		return false, "That round type cannot be used with this rack!"
	end

	if DistSqrBetween(self, crate) >= AmmoLinkDistBase ^ 2 then
		return false, "That crate is too far to be connected with this rack!"
	end

	local ret, msg = ACE.CanLinkRack(self.Id, bdata.Id, bdata, self)
	if not ret then return ret, msg end

	for _, v in ipairs(self.AmmoLink) do
		if v == crate then
			return false, "That crate is already linked to this rack!"
		end
	end

	return true
end

function ENT:Link(Target)
	if not IsValid(Target) or Target:GetClass() ~= "ace_ammo" then
		return false, "Racks can only be linked to ammo crates!"
	end

	local Blacklist = ACE.AmmoBlacklist[Target.RoundType] or {}
	if table.HasValue(Blacklist, self.Class) then
		return false, "That round type cannot be used with this gun!"
	end

	local ret, msg = self:CanLinkCrate(Target)
	if not ret then
		return false, msg
	end

	table.insert(self.AmmoLink, Target)
	table.insert(Target.Master, self)

	ValidateAmmoCount(self)
	self:UpdateWireOverlay()

	return true, "Link successful!"
end

function ENT:Unlink(Target)
	local Success = false

	for i = #self.AmmoLink, 1, -1 do
		if self.AmmoLink[i] == Target then
			table.remove(self.AmmoLink, i)
			Success = true
		end
	end

	if Success then
		ValidateAmmoCount(self)
		self:UpdateWireOverlay()
		return true, "Unlink successful!"
	end

	return false, "That entity is not linked to this gun!"
end

function ENT:UnloadAmmo()
	-- Racks support mixed munitions
end

function ENT:FireMissile()
	local Time = CurTime()
	if self.Reloading or Time < self.NextFire then return end

	if not (ACE.GunfireEnabled and self.Legal) then
		SetReady(self, false)
		return
	end

	SetReady(self, false)

	if HasOccupiedPort(self) then
		local portIdx, portdata = FindFirePort(self)

		if portdata then
			if CanFireInPort(portdata) then
				local missile = portdata.Missile
				local CanDo = hook.Run("ACE_FireShell", self, missile.BulletData)

				if CanDo == false then
					SetNextFire(self, self.FireDelay)
					return
				end

				local MuzzleVec = self:GetAngles():Forward()
				local coneAng = self:GetInaccuracy()
				local ShootVec = ACE.GetCircularSpread(MuzzleVec, coneAng)

				local filter = { self, missile }
				for _, pdata in ipairs(self.MissilePorts) do
					if IsValid(pdata.Missile) and pdata.Missile ~= missile then
						filter[#filter + 1] = pdata.Missile
					end
				end
				missile.Filter = filter

				if self.Sound and self.Sound ~= "" then
					missile.BulletData.Sound = self.Sound
					missile.BulletData.Pitch = self.SoundPitch
				end

				local useRail = (self.PodLength > 0) and (self.EnforceFlightInRack or self.RailLaunch)

				portdata.Missile = NULL
				if useRail then
					portdata.OccupiedBy = missile
					missile.PortId = portIdx
				else
					missile.PortId = nil
				end

				missile:Launch(ShootVec, useRail, self.PodLength, self.LaunchKick)

				self:EmitSound(FireSound, 500, 100)
			else
				-- Damaged ports are perceived as loaded by the fire cycle and emit EmptySound when attempted
				self:EmitSound(EmptySound)
			end

			AdvancePortIndex(self, portIdx)
			SetNextFire(self, self.FireDelay)
			self.WaitTime = Time + math.max(self.FireDelay * 1.5, 2)

			self.LoadedAmmo = CountLoadedMissiles(self)
			self:TriggerWireOutput("Shots Left", self.LoadedAmmo)
			self:SetNWInt("Ammo", self.LoadedAmmo)
			self:SetLoadedWeight()
		end
	else
		if Time > self.WaitTime then
			self:EmitSound(EmptySound)
			self.WaitTime = Time + 0.5
		end
	end
end

function ENT:CanReload()
	if not self.AllowReload then return false end
	if self.WaitTime > CurTime() then return false end
	if self.AvailableAmmo <= 0 then return false end
	if not FindAvailablePort(self) then return false end

	return true
end

function ENT:FindNextCrate()
	local MaxAmmo = #self.AmmoLink
	if MaxAmmo <= 0 then return false end

	local i = 0
	while i < MaxAmmo do
		self.CurCrate = self.CurCrate + 1
		if self.CurCrate > MaxAmmo then
			self.CurCrate = 1
		end

		local AmmoEnt = self.AmmoLink[self.CurCrate]
		if IsValid(AmmoEnt) and AmmoEnt.Ammo > 0 and AmmoEnt.Load and AmmoEnt.Legal then
			return AmmoEnt
		end

		i = i + 1
	end

	return false
end

function ENT:LoadMissile()
	local Crate = self:FindNextCrate()
	if not IsValid(Crate) then
		self.Reloading = false
		return
	end

	local portId, portData = FindAvailablePort(self)
	if not portData then
		self.Reloading = false
		return
	end

	SetReady(self, false)

	local BulletData = table.Copy(Crate.BulletData)
	local MissileData = GunTable[BulletData.Id]
	if not MissileData then
		self.Reloading = false
		return
	end

	local offset = (MissileData.bodydiameter and MissileData.bodydiameter / 2)
		or (MissileData.modeldiameter and MissileData.modeldiameter / 2)
		or (MissileData.caliber / 2.54)

	local scaledir = (portData.ScaleDir or vector_origin):GetNormalized()
	local MissilePos = portData.Pos + scaledir * offset
	local ReloadTime = self:GetReloadTime(BulletData)

	local owner = ACE.GetEntityOwner(self)
	local Missile = ACE.CreateMissile(owner, self:LocalToWorld(MissilePos), self:GetAngles(), BulletData, Crate.RoundData, self)

	if IsValid(Missile) then
		local rackmodel = self.missileCover or ACE.GetGunValue(BulletData.Id, "rackmdl")
		if rackmodel and rackmodel ~= Missile:GetModel() then
			Missile:InitializePhysics(rackmodel)
			Missile.RackModelApplied = true
		end

		if self.HideMissile then Missile:SetNoDraw(true) end
		if self.ProtectMissile then Missile:SetNotSolid(true) end

		Missile:SetColor(Crate:GetColor())
		Missile:SetParent(self)
		Missile:SetParentPhysNum(0)
		Missile.PortId = portId

		portData.Missile = Missile
		Crate.Ammo = Crate.Ammo - 1

		self.LoadedAmmo = CountLoadedMissiles(self)
		self:TriggerWireOutput("Shots Left", self.LoadedAmmo)
		self:SetNWInt("Ammo", self.LoadedAmmo)
		self:SetLoadedWeight()
		self:EmitSound(ReloadSound)

		self.ReloadTime = ReloadTime
		self.ReloadEndTime = CurTime() + ReloadTime
		self.CurPort = portId
	else
		self.Reloading = false
	end
end

function ENT:TriggerInput(iname, value)
	if iname == "Fire" then
		if value ~= 0 then
			if self.FireMode == 0 then
				self.OnFireCycle = true
			elseif self.FireMode >= 1 then
				self:FireMissile()
			end
		else
			self.OnFireCycle = false
		end
	elseif iname == "Reload" then
		self.AllowReload = value ~= 0
	elseif iname == "Target Pos" then
		self.TargetPos = value
		self:TriggerWireOutput("Position", value)
	elseif iname == "Fire Delay" then
		if value <= 0 then
			self.CustomFireDelay = nil
			self.FireDelay = math.max(self.DefaultFireDelay, self.MinFireDelay)
		else
			self.CustomFireDelay = math.max(value, self.MinFireDelay)
			self.FireDelay = self.CustomFireDelay
		end
	elseif iname == "Track Delay" then
		self.TrackDelay = math.max(value, 0)

		for _, portdata in ipairs(self.MissilePorts) do
			if IsValid(portdata.Missile) then
				portdata.Missile.ForceTdelay = self.TrackDelay
			end
		end
	elseif iname == "Fire Mode" then
		self.FireMode = math.Clamp(value, 0, 1)
	elseif iname == "Rail Launch" then
		self.RailLaunch = value ~= 0
	end
end

function ENT:Think()
	local Time = CurTime()

	if ACE.CurTime > self.NextLegalCheck then
		self.Legal, self.LegalIssues = ACE.CheckLegal(self, nil, math.Round(self.Mass or 10, 2), self.ModelInertia, nil, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self, self.Legal)

		if not self.Legal and self.OnFireCycle then
			self.OnFireCycle = false
		end
	end

	-- Throttled ammo validation, refill bonus and overlay refresh
	if Time >= self.TimeDelay then
		ValidateAmmoCount(self)
		self:UpdateRefillBonus()
		self.LoadedAmmo = CountLoadedMissiles(self)
		self:TriggerWireOutput("Shots Left", self.LoadedAmmo)
		self:SetNWInt("Ammo", self.LoadedAmmo)
		self:UpdateWireOverlay()

		self.TimeDelay = Time + 0.5
	end

	-- Finish active reload cycle once timer expires
	if self.Reloading and Time >= self.ReloadEndTime then
		self.Reloading = false

		if not self:CanReload() and HasAmmoOnRack(self) then
			if Time >= self.NextFire then
				SetReady(self, true)
			end
			self:EmitSound(ReadySound)
			self.CurPort = math.max(self.TotalPorts, 1)
		end
	end

	-- Fire handling up to 66 ticks/sec
	if Time >= self.NextFire and not self.Reloading then
		if HasAmmoOnRack(self) and self.Legal then
			SetReady(self, true)
		else
			SetReady(self, false)
		end

		if self.OnFireCycle and self.FireMode == 0 then
			self:FireMissile()
		end
	end

	-- Start next port reload if allowed
	if self:CanReload() and not self.Reloading then
		ValidateAmmoCount(self)
		if self:CanReload() then
			self.Reloading = true
			self:LoadMissile()
		end
	end

	self:NextThink(Time)
	return true
end

function MakeACE_Rack(Owner, Pos, Angle, Id)
	if not Owner:CheckLimit("_ace_rack") then return false end

	local Rack = ents.Create("ace_rack")
	if not IsValid(Rack) then return false end

	Rack:SetAngles(Angle)
	Rack:SetPos(Pos)
	Rack:Spawn()

	Owner:AddCount("_ace_rack", Rack)
	Owner:AddCleanup("acemenu", Rack)

	if not ACE.CheckRack(Id) then
		Id = "1xRK"
	end

	local rackdef = RackTable[Id]
	local rackclass = RackClasses[rackdef.gunclass] or ErrorNoHalt("Couldn't find the " .. tostring(rackdef.gunclass) .. " rack-class!")

	ACE.SetEntityOwner(Rack, Owner)

	Rack.Id					= Id
	Rack.MinCaliber			= rackdef.mincaliber
	Rack.MaxCaliber			= rackdef.maxcaliber
	Rack.Caliber			= rackdef.caliber
	Rack.Model				= rackdef.model
	Rack.Mass				= rackdef.weight
	Rack.name				= rackdef.name
	Rack.Class				= rackdef.gunclass
	Rack.gunclass			= rackdef.gunclass
	Rack.missileCover		= rackdef.rackmdl
	Rack.mountpoints		= rackdef.mountpoints
	Rack.MagSize			= #rackdef.mountpoints > 0 and #rackdef.mountpoints or (rackdef.magsize or 1)
	Rack.MagReload			= rackdef.magreload or 0

	Rack.Muzzleflash		= rackdef.muzzleflash or (rackclass and rackclass.muzzleflash) or ""
	Rack.RoFmod				= (rackclass and rackclass.rofmod) or 1
	Rack.Sound				= rackdef.sound or (rackclass and rackclass.sound) or "acf_extra/airfx/rocket_fire2.mp3"
	Rack.DefaultSound		= Rack.Sound
	Rack.SoundPitch			= 100
	Rack.Inaccuracy			= rackdef.spread or (rackclass and rackclass.spread) or 1

	Rack.HideMissile		= ACE.GetRackValue(Id, "hidemissile") or false
	Rack.ProtectMissile		= rackdef.protectmissile or (rackclass and rackclass.protectmissile) or false
	Rack.CustomArmour		= rackdef.armour or (rackclass and rackclass.armour) or 1

	Rack.ReloadMultiplier	= ACE.GetRackValue(Id, "reloadmul") or 1
	Rack.WhitelistOnly		= ACE.GetRackValue(Id, "whitelistonly") or false

	Rack.PodLength			= ACE.GetRackValue(Id, "podlength") or 0
	Rack.EnforceFlightInRack = ACE.GetRackValue(Id, "enforceFlightInRack") or false
	Rack.LaunchKick			= ACE.GetRackValue(Id, "launchkick") or 0
	Rack.MinFireDelay		= math.max(ACE.GetRackValue(Id, "minfiredelay") or 0.05, 0.05)
	Rack.DefaultFireDelay	= Rack.MinFireDelay
	Rack.FireDelay			= Rack.MinFireDelay

	BuildMissilePorts(Rack)

	Rack:SetModel(Rack.Model)
	Rack:PhysicsInit(SOLID_VPHYSICS)
	Rack:SetMoveType(MOVETYPE_VPHYSICS)
	Rack:SetSolid(SOLID_VPHYSICS)

	local phys = Rack:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(Rack.Mass or 1)
	end

	Rack:SetNW2String("WireName", Rack.name)
	Rack:SetNWString("Class", Rack.Class)
	Rack:SetNWString("ID", Rack.Id)
	Rack:SetNWString("GunType", Rack.Id)
	Rack:SetNWString("Sound", Rack.Sound)
	Rack:SetNWInt("SoundPitch", Rack.SoundPitch)

	hook.Call("ACE_RackCreate", nil, Rack)

	return Rack
end
duplicator.RegisterEntityClass("ace_rack", MakeACE_Rack, "Pos", "Angle", "Id")

function ENT:PreEntityCopy()
	local info = {}
	local entids = {}

	for i = #self.AmmoLink, 1, -1 do
		local Value = self.AmmoLink[i]
		if not IsValid(Value) then
			table.remove(self.AmmoLink, i)
		else
			table.insert(entids, Value:EntIndex())
		end
	end

	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier(self, "ACFAmmoLink", info)
	end

	duplicator.StoreEntityModifier(self, "ACFRackInfo", { Id = self.Id })

	-- Wire dupe info
	BaseClass.PreEntityCopy(self)
end

function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	if Ent.EntityMods and Ent.EntityMods.ACFAmmoLink and Ent.EntityMods.ACFAmmoLink.entities then
		local AmmoLink = Ent.EntityMods.ACFAmmoLink
		if AmmoLink.entities and next(AmmoLink.entities) then
			for _, AmmoID in pairs(AmmoLink.entities) do
				local Ammo = CreatedEntities[AmmoID]
				if IsValid(Ammo) and Ammo:GetClass() == "ace_ammo" then
					self:Link(Ammo)
				end
			end
		end
		Ent.EntityMods.ACFAmmoLink = nil
	end

	-- Wire dupe info
	BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)
end

local function GetStatus(Rack)
	if Rack.Ready then
		return "Ready"
	end

	if Rack.Reloading then
		local remaining = math.max(math.Round(Rack.ReloadEndTime - CurTime(), 1), 0)
		return "Loading (" .. remaining .. "s)"
	end

	if Rack.WaitTime > CurTime() then
		return "Firing"
	end

	return "Empty"
end

function ENT:UpdateWireOverlay()
	local Ammo = self.LoadedAmmo or 0
	local FireRate = self.FireDelay or self.MinFireDelay or 0.5
	local Reload = self.ReloadTime or 1
	local ReloadBonus = self.ReloadMultiplierBonus or 0
	local Status = GetStatus(self)

	local txt = "-  " .. Status .. "  -"

	if Ammo > 0 then
		if Ammo == 1 then
			txt = txt .. "\n" .. Ammo .. " Launch left"
		else
			txt = txt .. "\n" .. Ammo .. " Launches left"
		end

		txt = txt .. "\n\nFire Rate: " .. math.Round(FireRate, 2) .. " secs"
		txt = txt .. "\nReload Time: " .. math.Round(Reload, 2) .. " secs"

		if ReloadBonus > 0 then
			txt = txt .. "\n" .. math.floor(ReloadBonus * 100) .. "% Reload Time Decreased"
		end
	else
		if #self.AmmoLink > 0 then
			txt = txt .. "\n\nProvided with ammo (" .. (self.AvailableAmmo or 0) .. ").\n"
		else
			txt = txt .. "\n\nAmmo not found!\n"
		end
	end

	if self.PodLength > 0 and self.RailLaunch then
		txt = txt .. "\nRail Launch: Enabled (" .. self.PodLength .. "\")"
	end

	if self.IsRackDamaged then
		txt = txt .. "\n\nWarning: Damaged!"
	end

	if not self.Legal then
		txt = txt .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetWireOverlayText(txt)
end
