E2Lib.RegisterExtension("ace", true)

local isOwner, validPhysics = E2Lib.isOwner, E2Lib.validPhysics
local match = string.match
local abs, round, clamp, floor, min, max = math.abs, math.Round, math.Clamp, math.floor, math.min, math.max
local cos, rad, pi = math.cos, math.rad, math.pi
local tableCopy = table.Copy
local ACE = ACE

local function isACE(ent)
	if not validPhysics(ent) then return false end
	return match(ent:GetClass(), "^ace_") and true or false
end

local function isEngine(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "ace_engine"
end

local function isGearbox(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "ace_gearbox"
end

local function isGun(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "ace_gun"
end

local function isRack(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "ace_rack"
end

local function isAmmo(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "ace_ammo"
end

local function isFuel(ent)
	if not validPhysics(ent) then return false end
	return ent:GetClass() == "ace_fueltank"
end

local radarTypes = {
	ace_radar = true,
	ace_irst = true,
	ace_trackingradar = true,
}

local function isRadar(ent)
	if not validPhysics(ent) then return false end
	return radarTypes[ent:GetClass()]
end

local function restrictInfo(ply, ent)
	if not ACE.RestrictInfo then return false end

	return not ent:CPPICanTool(ply, "acemenu")
end

-- Link functions
do
	local function isLinkableACEEnt(ent)
		if not validPhysics(ent) then return false end
		local entClass = ent:GetClass()
	
		return ACE_E2_LinkTables[entClass] ~= nil
	end

	ACE_E2_LinkTables = ACE_E2_LinkTables or
	{ -- link resources within each ent type.  should point to an ent: true if adding link.Ent, false to add link itself
		ace_engine		= {GearLink = true, FuelLink = false},
		ace_gearbox		= {WheelLink = true, Master = false},
		ace_fueltank	= {Master = false},
		ace_gun			= {AmmoLink = false},
		ace_ammo		= {Master = false}
	}
	
	
	local function getLinks(ent, enttype)
		local ret = {}
		-- find the link resources available for this ent type
		for entry, mode in pairs(ACE_E2_LinkTables[enttype]) do
			if not ent[entry] then
				error("Couldn't find link resource " .. entry .. " for entity " .. tostring(ent))

				return
			end

			-- find all the links inside the resources
			for _, link in pairs(ent[entry]) do
				ret[#ret + 1] = mode and link.Ent or link
			end
		end

		return ret
	end
	
	
	local function searchForGearboxLinks(ent)
		local boxes = ents.FindByClass("ace_gearbox")
		local ret = {}

		for _, box in pairs(boxes) do
			if IsValid(box) then
				for _, link in pairs(box.WheelLink) do
					if link.Ent == ent then
						ret[#ret + 1] = box
						break
					end
				end
			end
		end

		return ret
	end

	__e2setcost(20)

	-- Returns an array of all entities linked to this entity through ACE
	e2function array entity:aceLinks()
		if not validPhysics(this) then return self:throw("Entity is not valid", {}) end

		local class = this:GetClass()

		if not ACE_E2_LinkTables[class] then
			return searchForGearboxLinks(this)
		end

		return getLinks(this, class)
	end

	-- Returns an array of all wheels linked to this engine/gearbox, and child gearboxes
	e2function array entity:aceGetLinkedWheels()
		if not (isEngine(this) or isGearbox(this)) then return self:throw("Entity is not a valid ACE engine or gearbox", {}) end

		local wheels = {}

		for _, ent in pairs(ACE_GetLinkedWheels(this)) do
			wheels[#wheels + 1] = ent
		end

		return wheels
	end
end

-- General Functions
do
	__e2setcost(1)

	[nodiscard]
	e2function number aceInfoRestricted()
		return ACE.RestrictInfo and 1 or 0
	end

	[nodiscard]
	e2function string entity:aceNameShort()
		if not isACE(this) then return self:throw("Entity is not a valid ACE component", "") end
		if restrictInfo(self.player, this) then return "" end

		if isAmmo(this) then return this.RoundId or "" end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeID end

		return this.Id or ""
	end

	-- Returns the capacity of an ace ammo crate or fuel tank
	[nodiscard]
	e2function number entity:aceCapacity()
		if not (isAmmo(this) or isFuel(this)) then return self:throw("Entity is not a valid ACE ammo crate or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Capacity or 0
	end

	-- Returns 1 if an ACE engine, ammo crate, or fuel tank is on
	[nodiscard]
	e2function number entity:aceActive()
		local isAmmoCrate = isAmmo(this)
		if not (isEngine(this) or isAmmoCrate or isFuel(this)) then return self:throw("Entity is not a valid ACE engine, ammo crate, or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if isAmmoCrate then
			return this.Load and 1 or 0
		else
			return this.Active and 1 or 0
		end
	end

	__e2setcost(5)

	-- Turns an ACE engine, ammo crate, or fuel tank on or off
	e2function void entity:aceActive(number on)
		if not (isEngine(this) or isAmmo(this) or isFuel(this)) then return self:throw("Entity is not a valid ACE engine, ammo crate, or fuel tank") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Active", on)
	end

	-- Returns 1 if the hitpos is on a clipped part of the entity
	[nodiscard]
	e2function number entity:aceHitClip(vector hitPos)
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot target this entity", 0) end
		return ACE_CheckClips(this, hitPos) and 1 or 0
	end

	__e2setcost(2)
	
	-- Returns the full name of an ACE entity
	[nodiscard]
	e2function string entity:aceName()
		if not isACE(this) then return self:throw("Entity is not a valid ACE component", "") end

		if isAmmo(this) then return this.RoundId .. " " .. this.RoundType end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeId end

		local acetype = ""

		if isGun(this) then 
			acetype = "Guns"
		elseif isEngine(this)  then 
			acetype = "Engines"
		elseif isGearbox(this)  then 
			acetype = "Gearboxes" 
		elseif isRack(this) then
			acetype = "Racks"
		elseif isRadar(this) then
			acetype = "Radars"
		end

		if acetype == "" then return "" end

		return ACE.Weapons[acetype][this.Id]["name"] or ""
	end

	-- Returns the type of ACE entity
	[nodiscard]
	e2function string entity:aceType()
		if not isACE(this) then return self:throw("Entity is not a valid ACE component", "") end

		if isEngine(this) then
			return ACE.Weapons["Engines"][this.Id]["category"] or ""
		elseif isGearbox(this) then
			return ACE.Weapons["Gearboxes"][this.Id]["category"] or ""
		elseif isGun(this) then
			return ACE.Classes["GunClass"][this.Class]["name"] or ""
		elseif isRack(this) then
			return ACE.Classes["Rack"][this.Class]["name"] or ""
		elseif isRadar(this) then
			return ACE.Classes["Radar"][this.Class]["name"] or ""
		end

		if isAmmo(this) then return this.RoundType or "" end
		if isFuel(this) then return this.FuelType or "" end

		return ""
	end

	__e2setcost(1)

	-- Return the current ACE drag divisor
	[nodiscard]
	e2function number aceDragDiv()
		return ACE.DragDiv
	end

	-- Returns the temperature of an ACE entity
	[nodiscard]
	e2function number entity:aceHeat()
		if not isACE(this) then return self:throw("Entity is not a valid ACE component", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Heat or 0
	end

	-- Returns the latest ACE version
	[nodiscard]
	e2function number aceVersion()
		return ACE.CurrentVersion
	end

	-- Returns the current ACE version
	[nodiscard]
	e2function number aceCurVersion()
		return ACE.Version
	end

	-- Returns the current air gap factor (air effectiveness against HEAT)
	[nodiscard]
	e2function number aceHEATAirGapFactor()
		return ACE.HeatAirGapFactor
	end

	-- Returns the current ACE wind direction
	[nodiscard]
	e2function vector aceWindVector()
		return ACE.Wind
	end

	-- Returns 1 if the entity is an ACE engine
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsEngine()
		return isEngine(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACE gearbox
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsGearbox()
		return isGearbox(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACE gun
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsGun()
		return isGun(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACE rack
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsRack()
		return isRack(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACE ammo crate
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsAmmo()
		return isAmmo(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACE fuel tank
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsFuel()
		return isFuel(this) and 1 or 0
	end

	-- Returns 1 if the entity is an ACE radar
	[nodiscard, deprecated = "Just check the entity class yourself"]
	e2function number entity:aceIsRadar()
		return isRadar(this) and 1 or 0
	end

	-- Links two ACE entities together
	e2function number entity:aceLinkTo(entity target, number notify)
		if not IsValid(this) then return self:throw("Invalid source entity", 0) end
		if not IsValid(target) then return self:throw("Invalid target entity", 0) end
		if this == target then return self:throw("Cannot link entity to itself", 0) end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You do not have permission to target the source entity", 0) end
		if not target:CPPICanTool(self.player, "acemenu") then return self:throw("You do not have permission to target the target entity", 0) end

		local success, msg

		if this.Link and target.Link then
			if target:GetClass() == "ace_engine" then
				success, msg = target:Link(this)
			else
				success, msg = this:Link(target)
			end
		elseif this.Link and not target.Link then
			success, msg = this:Link(target)
		elseif not this.Link and target.Link then
			success, msg = target:Link(this)
		else
			return self:throw("These entities cannot be linked to each other", 0)
		end

		if notify > 0 then
			ACE_SendNotify(self.player, success, msg)
		end

		return success and 1 or 0
	end

	-- Unlinks two ACE entities from each other
	e2function number entity:aceUnlinkFrom(entity target, number notify)
		if not IsValid(this) then return self:throw("Invalid source entity", 0) end
		if not IsValid(target) then return self:throw("Invalid target entity", 0) end
		if this == target then return self:throw("Cannot unlink entity from itself", 0) end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You do not have permission to target the source entity", 0) end
		if not target:CPPICanTool(self.player, "acemenu") then return self:throw("You do not have permission to target the target entity", 0) end

		local success, msg

		if this.Unlink and target.Unlink then
			if target:GetClass() == "ace_engine" then
				success, msg = target:Unlink(this)
			else
				success, msg = this:Unlink(target)
			end
		elseif this.Unlink and not target.Unlink then
			success, msg = this:Unlink(target)
		elseif not this.Unlink and target.Unlink then
			success, msg = target:Unlink(this)
		else
			return self:throw("These entities cannot be unlinked from each other", 0)
		end

		if notify > 0 then
			ACE_SendNotify(self.player, success, msg)
		end

		return success and 1 or 0
	end
end

-- Engine Functions
do
	__e2setcost(1)

	-- Returns 1 if the ACE engine is electric
	[nodiscard]
	e2function number entity:aceIsElectric()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return ACE.Weapons["Engines"][this.Id]["category"] == "Electric" and 1 or 0
	end

	-- Returns the peak torque in Nm of an ACE engine
	[nodiscard]
	e2function number entity:aceMaxTorque()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local torque = this.PeakTorque

		if this.RequiresFuel then
			torque = torque * ACE.TorqueBoost
		end

		return torque
	end

	-- Returns the peak power in kW of an ACE engine
	[nodiscard]
	e2function number entity:aceMaxPower()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local power = this.peakkw

		if this.RequiresFuel then
			power = power * ACE.TorqueBoost
		end

		return power
	end

	-- Returns the peak torque in Nm of an ACE engine when supplied with fuel
	[nodiscard]
	e2function number entity:aceMaxTorqueWithFuel()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.PeakTorque * ACE.TorqueBoost
	end

	-- Returns the peak power in kW of an ACE engine when supplied with fuel
	[nodiscard]
	e2function number entity:aceMaxPowerWithFuel()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.peakkw * ACE.TorqueBoost
	end

	-- Returns the idle RPM of an ACE engine
	[nodiscard]
	e2function number entity:aceIdleRPM()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.IdleRPM
	end

	-- Returns the lower powerband of an ACE engine
	[nodiscard]
	e2function number entity:acePowerbandMin()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.PeakMinRPM / 10) * 10
	end

	-- Returns the upper powerband of an ACE engine
	[nodiscard]
	e2function number entity:acePowerbandMax()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.PeakMaxRPM / 10) * 10
	end

	-- Returns the redline of an ACE engine
	[nodiscard]
	e2function number entity:aceRedline()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.LimitRPM
	end

	-- Returns the current RPM of an ACE engine
	[nodiscard]
	e2function number entity:aceRPM()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.FlyRPM)
	end

	-- Returns the torque output of an ACE engine, in Nm
	[nodiscard]
	e2function number entity:aceTorque()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.Torque or 0)
	end

	-- Returns the power output of an ACE engine, in kW
	[nodiscard]
	e2function number entity:acePower()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round((this.Torque or 0) * this.FlyRPM / 9548.8)
	end

	-- Returns the inertia of an ACE engine's flywheel
	[nodiscard]
	e2function number entity:aceFlyInertia()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Inertia
	end

	-- Returns the mass of an ACE engine's flywheel
	[nodiscard]
	e2function number entity:aceFlyMass()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Inertia / pi ^ 2
	end

	-- Returns 1 if the RPM of an ACE engine is within its powerband
	[nodiscard]
	e2function number entity:aceInPowerband()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local rpm = this.FlyRPM
		local pbMin, pbMax = this.PeakMinRPM, this.PeakMaxRPM

		return (rpm >= pbMin and rpm <= pbMax) and 1 or 0
	end

	-- Returns the throttle of an ACE engine
	[nodiscard]
	e2function number entity:aceThrottle()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Throttle
	end

	-- Sets the throttle of an ACE engine
	e2function void entity:aceThrottle(number throttle)
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Throttle", throttle)
	end

	-- Returns the total fuel remaining for an ACE engine, in liters
	[nodiscard]
	e2function number entity:aceFuelRemaining()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.TotalFuel
	end

	__e2setcost(5)

	-- Returns an array of all fuel tanks linked to an ACE engine
	[nodiscard]
	e2function array entity:aceGetFuelTanks()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", {}) end
		if restrictInfo(self.player, this) then return {} end
		if not next(this.FuelLink) then return {} end

		return tableCopy(this.FuelLink)
	end
end

-- Gearbox functions
do
	__e2setcost(1)

	-- Returns the current gear of an ACE gearbox
	[nodiscard]
	e2function number entity:aceGear()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Gear
	end

	-- Returns the number of gears in an ACE gearbox
	[nodiscard]
	e2function number entity:aceNumGears()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Gears
	end

	-- Returns the final drive of an ACE gearbox
	[nodiscard]
	e2function number entity:aceFinalRatio()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return tonumber(this.GearTable["Final"])
	end

	-- Returns the total gear ratio (current * final) of an ACE gearbox
	[nodiscard]
	e2function number entity:aceTotalRatio()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.GearRatio
	end

	-- Returns the torque rating of an ACE gearbox, in Nm
	[nodiscard]
	e2function number entity:aceTorqueRating()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.MaxTorque
	end

	-- Returns whether an ACE gearbox is dual clutch
	[nodiscard]
	e2function number entity:aceIsDual()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Dual and 1 or 0
	end

	-- Returns the time it takes an ACE gearbox to change gears, in ms
	[nodiscard]
	e2function number entity:aceShiftTime()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.SwitchTime * 1000
	end

	-- Returns 1 if an ACE gearbox is in gear
	[nodiscard]
	e2function number entity:aceInGear()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.InGear and 1 or 0
	end

	-- Returns the ratio for a specified gear of an ACE gearbox
	[nodiscard]
	e2function number entity:aceGearRatio(number gear)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local gear = clamp(floor(gear), 1, this.Gears)

		return tonumber(this.GearTable[gear])
	end

	-- Returns the current torque output of an ACE gearbox, in Nm
	[nodiscard]
	e2function number entity:aceTorqueOut()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return min(this.TotalReqTq, this.MaxTorque) / this.GearRatio
	end

	-- Sets the gear ratio of a CVT, set to 0 to use automatic calculation
	e2function void entity:aceCVTRatio(number ratio)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.CVT then return self:throw("This function can only be used on CVTs") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this.CVTRatio = clamp(ratio, 0, 1)
	end

	__e2setcost(5)

	-- Sets the current gear for an ACE gearbox
	e2function void entity:aceShift(number gear)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Gear", gear)
	end

	-- Causes an ACE gearbox to shift up
	e2function void entity:aceShiftUp()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Gear Up", 1)
	end

	-- Causes an ACE gearbox to shift down
	e2function void entity:aceShiftDown()
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Gear Down", 1)
	end

	-- Sets the brakes for an ACE gearbox
	e2function void entity:aceBrake(number brake)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Brake", brake)
	end
	
	-- Sets the left brakes for an ACE gearbox
	e2function void entity:aceBrakeLeft(number brake)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Left Brake", brake)
	end

	-- Sets the right brakes for an ACE gearbox
	e2function void entity:aceBrakeRight(number brake)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Right Brake", brake)
	end

	-- Sets the clutch for an ACE gearbox
	e2function void entity:aceClutch(number clutch)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Clutch", clutch)
	end

	-- Sets the left clutch for an ACE gearbox
	e2function void entity:aceClutchLeft(number clutch)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Left Clutch", clutch)
	end

	-- Sets the right clutch for an ACE gearbox
	e2function void entity:aceClutchRight(number clutch)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.Dual then return self:throw("This gearbox is not dual clutch") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Right Clutch", clutch)
	end

	-- Sets the steer ratio for an ACE double differential gearbox
	e2function void entity:aceSteerRate(number steerRate)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.DoubleDiff then return self:throw("This gearbox is not a double differential") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Steer Rate", steerRate)
	end

	-- Applies gear hold for an automatic ACE gearbox
	e2function void entity:aceHoldGear(number holdGear)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.Auto then return self:throw("This gearbox is not automatic") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Hold Gear", holdGear)
	end

	-- Sets the shift point scaling for an automatic ACE gearbox
	e2function void entity:aceShiftPointScale(number scale)
		if not isGearbox(this) then return self:throw("Entity is not a valid ACE gearbox") end
		if not this.Auto then return self:throw("This gearbox is not automatic") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Shift Speed Scale", scale)
	end
end

-- Gun functions
do
	__e2setcost(1)

	-- Returns 1 if the ACE gun or rack is ready to fire
	[nodiscard]
	e2function number entity:aceReady()
		if not (isGun(this) or isRack(this)) then return self:throw("Entity is not a valid ACE gun or rack", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Ready and 1 or 0
	end

	-- Returns the reload duration of an ACE weapon
	[nodiscard]
	e2function number entity:aceReloadTime()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.ReloadTime
	end

	__e2setcost(2)

	-- Returns a number from 0 to 1 representing the reload progress of an ACE weapon
	[nodiscard]
	e2function number entity:aceReloadProgress()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local reloadTime
		if this.MagSize == 1 then
			reloadTime = this.ReloadTime
		else
			if this.MagSize - this.CurrentShot > 0 then
				reloadTime = this.ReloadTime
			else
				reloadTime = this.MagReload + this.ReloadTime
			end
		end
	
		return clamp(1 - (this.NextFire - CurTime()) / reloadTime, 0, 1)
	end

	__e2setcost(1)

	-- Returns the time it takes for an ACE weapon to reload its magazine
	[nodiscard]
	e2function number entity:aceMagReloadTime()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.MagReload
	end

	-- Returns the magazine size of an ACE gun
	[nodiscard]
	e2function number entity:aceMagSize()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.MagSize
	end

	-- Returns the spread for an ACE gun or flechette ammo
	[nodiscard]
	e2function number entity:aceSpread()
		if not (isGun(this) or isAmmo(this)) then return self:throw("Entity is not a valid ACE gun or ammo crate", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local spread = this.GetInaccuracy and this:GetInaccuracy() or this.Inaccuracy or 0

		if this.BulletData["Type"] == "FL" then
			return spread + (this.BulletData["FlechetteSpread"] or 0)
		end

		return spread
	end

	-- Returns 1 if an ACE gun is reloading
	[nodiscard]
	e2function number entity:aceIsReloading()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if not this.Ready then
			if this.MagSize == 1 then
				return 1
			else
				return this.CurrentShot >= this.MagSize and 1 or 0
			end
		end

		return 0
	end

	-- Returns the fire rate of an ACE gun
	[nodiscard]
	e2function number entity:aceFireRate()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.RateOfFire, 3)
	end

	__e2setcost(2)

	-- Sets the rate of fire limit of an ACE gun
	e2function void entity:aceSetROFLimit(number rate)
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("ROFLimit", rate)
	end

	__e2setcost(1)

	-- Returns the number of rounds left in a magazine of an ACE gun
	[nodiscard]
	e2function number entity:aceMagRounds()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if this.MagSize > 1 then
			return this.MagSize - this.CurrentShot
		end

		if this.Ready and this.BulletData.Type ~= "Empty" then return 1 end

		return 0
	end

	__e2setcost(2)

	-- Sets the firing state of an ACE gun or rack
	e2function void entity:aceFire(number fire)
		if not (isGun(this) or isRack(this)) then return self:throw("Entity is not a valid ACE gun or rack") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Fire", fire)
	end

	-- Unloads an ACE gun
	e2function void entity:aceUnload()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:UnloadAmmo()
	end

	-- Reloads an ACE gun
	e2function void entity:aceReload()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		local isEmpty = this.BulletData.Type == "Empty"

		if isEmpty and not this.Reloading then
			this:LoadAmmo(false, true)
			this.Reloading = true
		end
	end

	__e2setcost(5)

	-- Returns an array of all crew seats linked to the ACE entity
	[nodiscard]
	e2function array entity:aceGetCrew()
		if not (isGun(this) or isEngine(this)) then return self:throw("Entity is not a valid ACE gun or engine", {}) end
		if restrictInfo(self.player, this) then return {} end
		if not next(this.CrewLink) then return {} end

		return tableCopy(this.CrewLink)
	end

	-- Returns an array of all ammo crates linked to the ACE entity
	[nodiscard]
	e2function array entity:aceGetAmmoCrates()
		if not (isGun(this) or isRack(this)) then return self:throw("Entity is not a valid ACE gun or rack", {}) end
		if restrictInfo(self.player, this) then return {} end
		if not next(this.AmmoLink) then return {} end

		return tableCopy(this.AmmoLink)
	end

	__e2setcost(10)

	-- Returns the number of rounds of an ACE Ammo Crate
	[nodiscard]
	e2function number entity:aceMunitions()
		if not isAmmo(this) then return self:throw("You can get the count from Ammo Crates only.", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Ammo
	end

	-- Returns the number of rounds in active ammo crates linked to an ACE gun or rack.
	[nodiscard]
	e2function number entity:aceAmmoCount()
		if not (isGun(this) or isRack(this)) then return self:throw("Only Guns, Racks and Ammo Crates are valid.", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local count = 0

		for _, v in pairs(this.AmmoLink) do
			if IsValid(v) and v.Load then
				count = count + v.Ammo
			end
		end

		return count
	end

	-- Returns the number of rounds in all ammo crates linked to an ACE gun or rack, regardless of whether they are active or not.
	[nodiscard]
	e2function number entity:aceTotalAmmoCount()
		if not (isGun(this) or isRack(this)) then return self:throw("Only Guns, Racks and Ammo Crates are valid.", 0) end
		if restrictInfo(self.player, this) then return 0 end

		local count = 0

		for _, v in pairs(this.AmmoLink) do
			if IsValid(v) then
				count = count + v.Ammo
			end
		end

		return count
	end

	__e2setcost(2)

	-- Returns a string representing the state of the ACE gun
	[nodiscard]
	e2function string entity:aceState()
		if not isGun(this) then return self:throw("Entity is not a valid ACE gun", "") end
		if restrictInfo(self.player, this) then return "" end

		local state = ""

		local isEmpty = this.BulletData.Type == "Empty"
		local isReloading = not isEmpty and CurTime() < this.NextFire and (this.MagSize == 1 or (this.LastLoadDuration > this.ReloadTime))

		if isEmpty then
			state = "Empty"
		elseif isReloading or not this.Ready then
			state = "Loading"
		else
			state = "Loaded"
		end

		return state
	end
end

-- Ammo functions
do
	__e2setcost(1)

	-- Returns the number of rounds left in an ACE ammo crate
	[nodiscard]
	e2function number entity:aceRounds()
		if not isAmmo(this) then return self:throw("Entity is not a valid ACE ammo crate", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Ammo
	end

	-- Returns the type of weapon the ammo in an ACE ammo crate loads into
	[nodiscard]
	e2function string entity:aceRoundType()
		if not isAmmo(this) then return self:throw("Entity is not a valid ACE ammo crate", "") end
		if restrictInfo(self.player, this) then return "" end

		return this.RoundType
	end

	-- Returns the type of ammo in a crate or gun
	[nodiscard]
	e2function string entity:aceAmmoType()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", "") end
		if restrictInfo(self.player, this) then return "" end

		return this.BulletData.Type
	end

	-- Returns the caliber of an ammo crate or gun
	[nodiscard]
	e2function number entity:aceCaliber()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.Caliber * 10
	end

	-- Returns the muzzle velocity of the ammo in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:aceMuzzleVel()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round((this.BulletData.MuzzleVel or 0) * ACE.VelScale, 3)
	end

	-- Returns the projectile mass of the ammo in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:aceProjectileMass()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.BulletData.ProjMass or 0, 3)
	end

	-- Returns the number of projectiles in a flechette round in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:aceFLSpikes()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.BulletData.Flechettes or 0
	end

	-- Returns the mass of a single spike in a flechette round in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:aceFLSpikeMass()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round(this.BulletData.FlechetteMass or 0, 3)
	end

	-- Returns the radius of the spikes in a flechette round, in mm
	[nodiscard]
	e2function number entity:aceFLSpikeRadius()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return round((this.BulletData.FlechetteRadius or 0) * 10, 3)
	end

	-- Returns the drag coefficient of ammo contained in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:aceDragCoef()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return (this.BulletData.DragCoef or 0) / ACE.DragDiv
	end

	__e2setcost(2)

	-- Returns the penetration of a round in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:acePenetration()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		return ACE.RoundTypes[this.BulletData.Type].getDisplayData(this.BulletData).MaxPen or 0
	end

	-- Returns the penetration of a round in an ACE ammo crate or gun, with an index to check penetration for THEAT (uses indexes 1 and 2)
	[nodiscard]
	e2function number entity:acePenetration(number index)
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		local displayData = ACE.RoundTypes[this.BulletData.Type].getDisplayData(this.BulletData)

		if index == 1 then
			return displayData.MaxPen or 0
		elseif index == 2 then
			return displayData.MaxPen2 or 0
		end

		return 0
	end

	-- Returns the blast radius of an HE, APHE, or HEAT round in an ACE ammo crate or gun
	[nodiscard]
	e2function number entity:aceBlastRadius()
		if not (isAmmo(this) or isGun(this)) then return self:throw("Entity is not a valid ACE ammo crate or gun", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not ACE_CheckRound(this.BulletData.Type) then return 0 end

		local type = this.BulletData.Type

		if type == "HE" or type == "APHE" then
			return round(this.BulletData.FillerMass ^ 0.33 * 8, 3)
		elseif type == "HEAT" then
			return round((this.BulletData.FillerMass / 3) ^ 0.33 * 8, 3)
		end

		return 0
	end
end

-- Armor functions
do
	__e2setcost(1)

	-- Returns the effective armor given an armor value and hit angle
	[nodiscard]
	e2function number aceEffectiveArmor(number armor, number angle)
		local eff = armor / abs(cos(rad(min(angle, 89.999))))

		return round(eff, 1)
	end

	__e2setcost(5)

	-- Returns the current health of an entity
	[nodiscard]
	e2function number entity:acePropHealth()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACE or not this.ACE.Health then
			local check = ACE_Check(this)

			if not check then return 0 end
		end

		return round(this.ACE.Health, 3)
	end

	-- Returns the current armor of an entity
	[nodiscard]
	e2function number entity:acePropArmor()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACE or not this.ACE.Armour then
			local check = ACE_Check(this)

			if not check then return 0 end
		end

		return round(this.ACE.Armour, 3)
	end

	-- Returns the max health of an entity
	[nodiscard]
	e2function number entity:acePropHealthMax()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACE or not this.ACE.MaxHealth then
			local check = ACE_Check(this)

			if not check then return 0 end
		end

		return round(this.ACE.MaxHealth, 3)
	end

	-- Returns the max armor of an entity
	[nodiscard]
	e2function number entity:acePropArmorMax()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACE or not this.ACE.MaxArmour then
			local check = ACE_Check(this)

			if not check then return 0 end
		end

		return round(this.ACE.MaxArmour, 3)
	end

	-- Returns the ductility of an entity
	[nodiscard]
	e2function number entity:acePropDuctility()
		if not validPhysics(this) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not this.ACE then
			local check = ACE_Check(this)

			if not check then return 0 end
		end

		return round(this.ACE.Ductility, 3)
	end

	-- Returns the effective armor from a trace hitting a prop
	[nodiscard]
	e2function number ranger:aceEffectiveArmor()
		local ent = this.Entity
		if not (this and validPhysics(ent)) then return self:throw("Entity is not valid", 0) end
		if restrictInfo(self.player, ent) then return 0 end
		if not ent.ACE then
			local check = ACE_Check(ent)

			if not check then return 0 end
		end

		local eff = ent.ACE.Armour / abs(cos(rad(ACE_GetHitAngle(this.HitNormal, this.HitPos - this.StartPos))))
		return round(eff, 1)
	end

	-- Returns the material of an entity
	[nodiscard]
	e2function string entity:acePropMaterial()
		if not validPhysics(this) then return self:throw("Entity is not valid", "") end
		if restrictInfo(self.player, this) then return "" end
		if not this.ACE then
			local check = ACE_Check(this)

			if not check then return "" end
		end

		return this.ACE.Material
	end

	__e2setcost(10)

	-- Returns a table containing the armor data of an entity
	[nodiscard]
	e2function table entity:acePropArmorData()
		local ret = E2Lib.newE2Table()
		
		if not validPhysics(this) then return self:throw("Entity is not valid", ret) end
		if restrictInfo(self.player, this) then return ret end
		if not this.ACE then
			local check = ACE_Check(this)

			if not check then return ret end
		end

		local mat = this.ACE.Material
		if not mat then return ret end

		local matData = ACE.ArmorMaterials[mat]
		if not matData then return ret end

		ret.size = 4

		ret.s.Curve = matData.curve
		ret.stypes.Curve = "n"

		ret.s.Effectiveness = matData.effectiveness
		ret.stypes.Effectiveness = "n"

		ret.s.HEATeffectiveness = matData.HEATeffectiveness or matData.effectiveness
		ret.stypes.HEATeffectiveness = "n"

		ret.s.Material = mat
		ret.stypes.Material = "s"

		return ret
	end
end

-- Fuel functions
do
	__e2setcost(1)

	-- Returns 1 if the ACE engine requires fuel to run
	[nodiscard]
	e2function number entity:aceFuelRequired()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end

		return this.RequiresFuel and 1 or 0
	end

	__e2setcost(2)

	-- Sets the ACE fuel tank "refuel duty" state, which allows it to refuel other fuel tanks
	e2function void entity:aceRefuelDuty(number state)
		if not isFuel(this) then return self:throw("Entity is not a valid ACE fuel tank") end
		if not this:CPPICanTool(self.player, "acemenu") then return self:throw("You cannot control this entity") end

		this:TriggerInput("Refuel Duty", state)
	end

	-- Returns the remaining fuel, in liters or kilowatt-hours, of an ACE engine or fuel tank
	[nodiscard]
	e2function number entity:aceFuel()
		if not (isEngine(this) or isFuel(this)) then return self:throw("Entity is not a valid ACE engine or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if this:GetClass() == "ace_fueltank" then
			return round(this.Fuel, 3)
		else
			if not next(this.FuelLink) then return 0 end

			local fuel = 0

			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					fuel = fuel + tank.Fuel
				end
			end

			return round(fuel, 3)
		end
	end

	-- Returns the remaining fuel in an ACE engine or fuel tank as a percentage of its total capacity
	[nodiscard]
	e2function number entity:aceFuelLevel()
		if not (isEngine(this) or isFuel(this)) then return self:throw("Entity is not a valid ACE engine or fuel tank", 0) end
		if restrictInfo(self.player, this) then return 0 end

		if this:GetClass() == "ace_fueltank" then
			return round(this.Fuel / this.Capacity, 3)
		else
			if not next(this.FuelLink) then return 0 end

			local fuel = 0
			local capacity = 0

			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					fuel = fuel + tank.Fuel
					capacity = capacity + tank.Capacity
				end
			end

			if capacity == 0 then return 0 end

			return round(fuel / capacity, 3)
		end
	end

	-- Returns the current fuel consumption in liters or kilowatts per minute of an ACE engine
	[nodiscard]
	e2function number entity:aceFuelUse()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not next(this.FuelLink) then return 0 end

		local tank
		for _, v in pairs(this.FuelLink) do
			if validPhysics(v) and v.Active and v.Fuel > 0 then
				tank = v
				break
			end
		end

		if not tank then return 0 end

		local consumption
		if this.FuelType == "Electric" then
			Consumption = 60 * (this.Torque * this.FlyRPM / 9548.8) * this.FuelUse
		else
			local Load = 0.3 + this.Throttle * 0.7
			Consumption = 60 * Load * this.FuelUse * (this.FlyRPM / this.PeakKwRPM) / ACE.FuelDensity[Tank.FuelType]
		end

		return round(Consumption, 3)
	end

	-- Returns the peak fuel consumption in liters or kilowatts per minute of an ACE engine at powerband max
	[nodiscard]
	e2function number entity:acePeakFuelUse()
		if not isEngine(this) then return self:throw("Entity is not a valid ACE engine", 0) end
		if restrictInfo(self.player, this) then return 0 end
		if not next(this.FuelLink) then return 0 end

		local fuel = "Petrol"
		local tank
		for _, v in pairs(this.FuelLink) do
			if validPhysics(v) and v.Active and v.Fuel > 0 then
				tank = v
				fuel = v.Fuel
				break
			end
		end

		local consumption
		if this.FuelType == "Electric" then
			consumption = 60 * (this.PeakTorque * this.LimitRPM / (4 * 9548.8)) * this.FuelUse
		else
			local Load = 0.3 + this.Throttle * 0.7
			Consumption = 60 * this.FuelUse / ACE.FuelDensity[fuel]
		end

		return round(consumption, 3)
	end
end

-- Radar functions
do
	__e2setcost(10)

	-- Returns a table containing all data from an ACE radar entity
	e2function table entity:aceRadarData()
		local ret = E2Lib.newE2Table()

		if not isRadar(this) then return self:throw("Entity is not a valid ACE radar", ret) end
		if restrictInfo(self, this) then return ret end
		local radarType = this:GetClass()

		ret.s.Detected = this.OutputData.Detected
		ret.stypes.Detected = "n"

		ret.s.Position = table.Copy(this.OutputData.Position)
		ret.stypes.Position = "r"

		if radarType == "ace_radar" then
			ret.s.ClosestDistance = this.OutputData.ClosestDistance
			ret.stypes.ClosestDistance = "n"

			ret.s.Entities = table.Copy(this.OutputData.Entities)
			ret.stypes.Entities = "r"

			ret.s.Velocity = table.Copy(this.OutputData.Velocity)
			ret.stypes.Velocity = "r"

			ret.size = 5
		elseif radarType == "ace_trackingradar" or "ace_irst" then
			ret.s.Owner = table.Copy(this.OutputData.Owner)
			ret.stypes.Owner = "r"

			ret.s.ClosestToBeam = this.OutputData.ClosestToBeam
			ret.stypes.ClosestToBeam = "n"

			if radarType == "ace_trackingradar" then
				ret.s.Velocity = table.Copy(this.OutputData.Velocity)
				ret.stypes.Velocity = "r"

				ret.s.IsJammed = this.OutputData.IsJammed
				ret.stypes.IsJammed = "n"
			elseif radarType == "ace_irst" then
				ret.s.Angle = table.Copy(this.OutputData.Angle)
				ret.stypes.Angle = "r"

				ret.s.EffHeat = table.Copy(this.OutputData.EffHeat)
				ret.stypes.EffHeat = "r"
			end

			ret.size = 6
		end

		return ret
	end
end