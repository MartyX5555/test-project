--- Library for interfacing with ACE entities
-- @name ace
-- @class library
-- @libtbl ace_library
-- @src https://github.com/RedDeadlyCreeper/ArmoredCombatExtended/tree/master/lua/starfall/lib_sv/ace.lua
SF.RegisterLibrary("ace")

local min, clamp, abs, round, floor = math.min, math.Clamp, math.abs, math.Round, math.floor
local rad, cos = math.rad, math.cos

local checkluatype = SF.CheckLuaType
local checkpermission = SF.Permissions.check
local registerprivilege = SF.Permissions.registerPrivilege

registerprivilege("ace.createMobility", "Create ace engine", "Allows the user to create ACE engines and gearboxes", { usergroups = { default = 3 } })
registerprivilege("ace.createFuelTank", "Create ace fuel tank", "Allows the user to create ACE fuel tanks", { usergroups = { default = 3 } })
registerprivilege("ace.createGun", "Create ace gun", "Allows the user to create ACE guns", { usergroups = { default = 3 } })
registerprivilege("ace.createAmmo", "Create ace ammo", "Allows the user to create ACE ammoboxes", { usergroups = { default = 3 } } )
registerprivilege("entities.ace", "ACE", "Allows the user to control ACE components", { entities = {} })

local function isEngine(ent)
	return ent:GetClass() == "ace_engine"
end

local function isGearbox(ent)
	return ent:GetClass() == "ace_gearbox"
end

local function isGun(ent)
	return ent:GetClass() == "ace_gun"
end

local function isAmmo(ent)
	return ent:GetClass() == "ace_ammo"
end

local function isFuel(ent)
	return ent:GetClass() == "ace_fueltank"
end

local radarTypes = {
	ace_radar = true,
	ace_irst = true,
	ace_trackingradar = true,
}

local function isRadar(ent)
	return radarTypes[ent:GetClass()] or false
end

-- link resources within each ent type. should point to an ent: true if adding link.Ent, false to add link itself
local linkTables = {
	ace_engine		= { GearLink = true, FuelLink = false },
	ace_gearbox		= { WheelLink = true, Master = false },
	ace_fueltank	= { Master = false },
	ace_gun			= { AmmoLink = false },
	ace_ammo		= { Master = false }
}

local function getLinks(ent, enttype)
	local ret = {}
	-- find the link resources available for this ent type
	for entry, mode in pairs(linkTables[enttype]) do
		if not ent[entry] then
			SF.Throw("[Internal ACE Error] Couldn't find link resource " .. entry .. " for entity " .. tostring(ent), 2)

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
	for _, box in ipairs(boxes) do
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


return function(instance)


local checktype = instance.CheckType
local ace_library = instance.Libraries.ace
local ents_methods = instance.Types.Entity.Methods
local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
local sanitize = instance.Sanitize
local getent = instance.Types.Entity.GetEntity

local function restrictInfo(ent)
	if GetConVar("ace_restrictinfo"):GetInt() ~= 0 then
		return ACE.GetEntityOwner(ent) ~= instance.player
	end

	return false
end

local idNameCache = {}
local function listIDFromName(list, name)
	idNameCache[list] = idNameCache[list] or {}

	if idNameCache[list][name] then return idNameCache[list][name] end

	for id, data in pairs(list) do
		if data.name == name then
			idNameCache[list][name] = id

			return id
		end
	end
end

instance:AddHook("deinitialize", function()
end)

-- Utility functions
do
	--- Returns current ACE drag divisor
	-- @server
	-- @return number The current drag divisor
	function ace_library.dragDivisor()
		return ACE.DragDiv
	end

	--- Returns true if functions returning sensitive info are restricted to owned props
	-- @server
	-- @return boolean True if restriced, False if not
	function ace_library.infoRestricted()
		return GetConVar("ace_restrictinfo"):GetInt() ~= 0
	end

	--- Returns latest version of ACE
	-- @server
	-- @return number Version number
	function ace_library.getVersion()
		return ACE.CurrentVersion
	end

	--- Returns server version of ace
	-- @server
	-- @return number Version number
	function ace_library.getCurrentVersion()
		return ACE.Version
	end

	--- Returns velocity loss for every meter traveled. 0.2x means HEAT loses 20% of its energy every 2m traveled. 1m is about typical for the sideskirt spaced armor of most tanks.
	-- @server
	-- @return number Air gap factor
	function ace_library.getHEATAirGapFactor()
		return ACE.HEATAirGapFactor
	end

	--- Returns ACE wind direction
	-- @server
	-- @return vector Wind direction
	function ace_library.getWindVector()
		return vwrap(ACE.Wind)
	end

	--- Returns true if this entity contains sensitive info and is not accessable to us
	-- @server
	-- @return boolean Is the info restricted?
	function ents_methods:aceIsInfoRestricted()
		return restrictInfo(getent(self))
	end

	--- Returns the short name of an ACE entity
	-- @server
	-- @return string The short name
	function ents_methods:aceNameShort()
		local this = getent(self)

		if isEngine(this) then return this.Id or "" end
		if isGearbox(this) then return this.Id or "" end
		if isGun(this) then return this.Id or "" end
		if isAmmo(this) then return this.RoundId or "" end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeId end

		return ""
	end

	--- Returns the maximum capacity of an ace ammo crate or fuel tank
	-- @server
	-- @return number The capacity
	function ents_methods:aceCapacity()
		local this = getent(self)

		if not (isAmmo(this) or isFuel(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Capacity or 1
	end

	--- Returns true if the ace engine, fuel tank, or ammo crate is active
	-- @server
	-- @return boolean Is the entity active?
	function ents_methods:aceGetActive()
		local this = getent(self)

		if not (isEngine(this) or isAmmo(this) or isFuel(this)) then return false end
		if restrictInfo(this) then return false end
		if not isAmmo(this) then
			if this.Active then return true end
		else
			if this.Load then return true end
		end

		return false
	end

	--- Turns an ACE engine, ammo crate, or fuel tank on or off
	-- @server
	-- @param boolean state The state to set the entity to
	function ents_methods:aceSetActive(on)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")

		if not (isEngine(this) or isAmmo(this) or isFuel(this)) then return end

		this:TriggerInput("Active", on and 1 or 0)
	end

	--- Returns true if hitpos is on a clipped part of prop
	-- @server
	-- @param Vector hitpos The hit position
	-- @return boolean Is the hit position on a clipped part of the prop?
	function ents_methods:aceHitClip(hitpos)
		checktype(hitpos, vec_meta)

		local this = getent(self)
		hitpos = vunwrap(hitpos)

		checkpermission(instance, this, "entities.ace")
		if ACE_CheckClips(nil, nil, this, hitpos) then
			return true
		else
			return false
		end
	end

	--- Returns the ACE links associated with the entity
	-- @server
	-- @return table The links
	function ents_methods:aceLinks()
		local this = getent(self)

		local enttype = this:GetClass()
		if not linkTables[enttype] then return sanitize(searchForGearboxLinks(this)) end

		return sanitize(getLinks(this, enttype))
	end

	--- Returns the full name of an ACE entity
	-- @server
	-- @return string The full name
	function ents_methods:aceName()
		local this = getent(self)

		if isAmmo(this) then return this.RoundId .. " " .. this.RoundType end
		if isFuel(this) then return this.FuelType .. " " .. this.SizeId end

		local acetype = ""

		if isEngine(this) then acetype = "Mobility" end
		if isGearbox(this) then acetype = "Mobility" end
		if isGun(this) then acetype = "Guns" end

		if acetype == "" then return "" end
		local List = ACE.Weapons

		return List[acetype][this.Id].name or ""
	end

	--- Returns the type of ACE entity
	-- @server
	-- @return string The type
	function ents_methods:aceType()
		local this = getent(self)

		if isEngine(this) or isGearbox(this) then
			return ACE.Weapons["Mobility"][this.Id].category or ""
		end

		if isGun(this) then
			return ACE.Classes["GunClass"][this.Class].name or ""
		end

		if isAmmo(this) then return this.RoundType or "" end
		if isFuel(this) then return this.FuelType or "" end

		return ""
	end

	--- Perform ACE links
	-- @server
	-- @param Entity target The entity to link to
	-- @param boolean notify Whether to notify the player of the link's creation
	-- @return boolean Whether the link was successful
	-- @return string Status message regarding the link's creation
	function ents_methods:aceLinkTo(target, notify)
		local this = getent(self)
		local tar = getent(target)

		checkpermission(instance, this, "entities.ace")
		checkpermission(instance, tar, "entities.ace")
		if not (isGun(this) or isEngine(this) or isGearbox(this)) then
			SF.Throw("Target must be a gun, engine, or gearbox", 2)
		end

		local success, msg = this:Link(tar)
		if notify then
			ACE_SendNotify(instance.player, success, msg)
		end

		return success, msg
	end

	--- Perform ACE unlinks
	-- @server
	-- @param Entity target The entity to unlink from
	-- @param boolean notify Whether to notify the player of the link's removal
	-- @return boolean Whether the unlink was successful
	-- @return string Status message regarding the link's removal
	function ents_methods:aceUnlinkFrom(target, notify)
		local this = getent(self)
		local tar = getent(target)

		checkpermission(instance, this, "entities.ace")
		checkpermission(instance, tar, "entities.ace")
		if not (isGun(this) or isEngine(this) or isGearbox(this)) then
			SF.Throw("Target must be a gun, engine, or gearbox", 2)
		end

		local success, msg = this:Unlink(tar)
		if notify then
			ACE_SendNotify(instance.player, success, msg)
		end

		return success, msg
	end

	--- Returns the heat of an ACE entity
	-- @server
	-- @return number The heat value of the entity
	function ents_methods:aceHeat()
		checktype(self, ents_metatable)
		local this = getent(self)

		if restrictInfo(this) then return 0 end

		local Heat
		if isGun(this) then
			Heat = ACE_HeatFromGun(this, this.Heat, this.DeltaTime)
		elseif isEngine(this) then
			Heat = ACE_HeatFromEngine(this)
		else
			Heat = ACE.AmbientTemp
		end

		return Heat
	end

	--- Returns all crewseats linked to an ace entity
	-- @server
	-- @return table crewseats entities
	function ents_methods:aceGetCrew()
		checktype(self, ents_metatable)
		local this = getent(self)

		if restrictInfo(this) then return {} end
		local Crew = {}
		for _, v in ipairs(this.CrewLink) do
			if IsValid(v) then
				Crew[#Crew + 1] = v
			end
		end

		return sanitize(Crew)
	end
end

-- Spawning functions
--do
--end

-- Armor functions
do
	--- Returns the effective armor given an armor value and hit angle
	-- @param number armor The nominal armor value
	-- @param number hit The hit angle
	-- @server
	-- @return number The effective armor
	function ace_library.effectiveArmor(armor, angle)
		checkluatype(armor, TYPE_NUMBER)
		checkluatype(angle, TYPE_NUMBER)

		return round(armor / abs(cos(rad(min(angle, 89.999)))), 1)
	end

	--- Returns the current health of an entity
	-- @server
	-- @return number The current health
	function ents_methods:acePropHealth()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACE_Check(this) then return 0 end

		return round(this.ACE.Health, 3)
	end

	--- Returns the current armor of an entity
	-- @server
	-- @return number The current armor
	function ents_methods:acePropArmor()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACE_Check(this) then return 0 end

		return round(this.ACE.Armour, 3)
	end

	--- Returns the max health of an entity
	-- @server
	-- @return number The max health
	function ents_methods:acePropHealthMax()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACE_Check(this) then return 0 end

		return round(this.ACE.MaxHealth, 3)
	end

	--- Returns the max armor of an entity
	-- @server
	-- @return number The max armor
	function ents_methods:acePropArmorMax()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACE_Check(this) then return 0 end

		return round(this.ACE.MaxArmour, 3)
	end

	--- Returns the ductility of an entity
	-- @server
	-- @return number The ductility
	function ents_methods:acePropDuctility()
		local this = getent(self)

		if not validPhysics(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not ACE_Check(this) then return 0 end

		return this.ACE.Ductility * 100
	end

	--- Returns the armor data of an entity
	-- @server
	-- @return table A table with keys: Curve, Effectiveness, HEATEffectiveness, Material
	function ents_methods:acePropArmorData()
		local this = getent(self)
		local empty = {}

		if not validPhysics(this) then return empty end
		if restrictInfo(this) then return empty end
		if not ACE_Check(this) then return empty end

		local mat = this.ACE.Material
		if not mat then return empty end

		local matData = ACE.ArmorMaterials[mat]
		if not matData then return empty end

		return {
			Curve = matData.curve,
			Effectiveness = matData.effectiveness,
			HEATEffectiveness = matData.HEATeffectiveness or matData.effectiveness,
			Material = mat
		}
	end
end

-- Weapon functions
do
	--- Returns the specs of a specified gun
	-- @param string id id or name of the gun
	-- @server
	-- @return table The specs table
	function ace_library.getGunSpecs(id)
		checkluatype(id, TYPE_STRING)

		local listEntries = ACE.Weapons.Guns

		-- Not a valid id, try name
		if not listEntries[id] then
			id = listIDFromName(listEntries, id)

			-- Name is also invalid, error
			if not id or not listEntries[id] then
				SF.Throw("Invalid id or name", 2)
			end
		end

		local specs = table.Copy(listEntries[id])
		specs.BaseClass = nil

		return sanitize(specs)
	end

	--- Returns a list of all guns
	-- @server
	-- @return table The guns list
	function ace_library.getAllGuns()
		local tbl = {}

		for id, _ in pairs(ACE.Weapons.Guns) do
			tbl[#tbl + 1] = id
		end

		return tbl
	end

	--- Returns true if the entity is an ACE gun
	-- @server
	-- @return boolean True if the entity is an ACE gun
	function ents_methods:aceIsGun()
		return isGun(getent(self))
	end

	--- Returns true if the ACE gun is ready to fire
	-- @server
	-- @return boolean True if the ACE gun is ready to fire
	function ents_methods:aceReady()
		local this = getent(self)

		if not isGun(this) then return false end
		if restrictInfo(this) then return false end

		return this.Ready
	end

	--- Returns the magazine size for an ACE gun
	-- @server
	-- @return number The magazine size
	function ents_methods:aceMagSize()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.MagSize
	end

	--- Returns the spread for an ACE gun or flechette ammo
	-- @server
	-- @return number The spread, in degrees
	function ents_methods:aceSpread()
		local this = getent(self)

		if not isGun(this) or isAmmo(this) then return 0 end
		local Spread = this.GetInaccuracy and this:GetInaccuracy() or this.Inaccuracy or 0
		if this.BulletData["Type"] == "FL" then
			if restrictInfo(this) then return Spread end

			return Spread + (this.BulletData["FlechetteSpread"] or 0)
		end

		return Spread
	end

	--- Returns true if an ACE gun is reloading
	-- @server
	-- @return boolean True if the ACE gun is reloading
	function ents_methods:aceIsReloading()
		local this = getent(self)

		if not isGun(this) then return false end
		if restrictInfo(this) then return false end

		return this.Reloading or false
	end

	--- Returns the rate of fire of an ace gun
	-- @server
	-- @return number The rate of fire
	function ents_methods:aceFireRate()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return math.Round(this.RateOfFire, 3)
	end

	--- Returns the number of rounds left in a magazine for an ACE gun
	-- @server
	-- @return number The number of rounds left in the magazine
	function ents_methods:aceMagRounds()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		if this.MagSize > 1 then return (this.MagSize - this.CurrentShot) or 1 end
		if this.Ready and this.BulletData.Type ~= "Empty" then return 1 end

		return 0
	end

	--- Sets the firing state of an ACE weapon
	-- @server
	-- @param number state 1 to fire, 0 to stop firing
	function ents_methods:aceFire(fire)
		checkluatype(fire, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGun(this) then return end

		this:TriggerInput("Fire", fire)
	end

	--- Sets the ROF limit of an ACE weapon
	-- @server
	-- @param number rate The rate of fire limit
	function ents_methods:aceSetROFLimit(rate)
		checkluatype(rate, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGun(this) then return end

		this:TriggerInput("ROFLimit", rate)
	end

	--- Causes an ACE weapon to unload
	-- @server
	function ents_methods:aceUnload()
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGun(this) then return end

		this:UnloadAmmo()
	end

	--- Causes an ACE weapon to reload
	-- @server
	function ents_methods:aceReload()
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGun(this) then return end
		local isEmpty = this.BulletData.Type == "Empty"

		if isEmpty and not this.Reloading then
			this:LoadAmmo(false, true)
			this.Reloading = true
		end
	end

	--- Returns the number of rounds in active ammo crates linked to an ACE weapon
	-- @server
	-- @return number The number of rounds in active ammo crates
	function ents_methods:aceAmmoCount()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		local Ammo = 0
		for _, AmmoEnt in pairs(this.AmmoLink) do
			if AmmoEnt and AmmoEnt:IsValid() and AmmoEnt["Load"] then
				Ammo = Ammo + (AmmoEnt.Ammo or 0)
			end
		end

		return Ammo
	end

	--- Returns the number of rounds in all ammo crates linked to an ACE weapon
	-- @server
	-- @return number The number of rounds in all ammo crates
	function ents_methods:aceTotalAmmoCount()
		local this = getent(self)

		if not isGun(this) then return 0 end
		if restrictInfo(this) then return 0 end

		local Ammo = 0
		for _, AmmoEnt in pairs(this.AmmoLink) do
			if AmmoEnt and AmmoEnt:IsValid() then
				Ammo = Ammo + (AmmoEnt.Ammo or 0)
			end
		end

		return Ammo
	end

	--- Returns time to next shot of an ACE weapon
	-- @server
	-- @return number The time to next shot
	function ents_methods:aceReloadTime()
		local this = getent(self)

		if restrictInfo(this) or not isGun(this) or not this.ReloadTime then return 0 end

		return this.ReloadTime
	end

	--- Returns number between 0 and 1 which represents reloading progress of an ACE weapon. Useful for progress bars
	-- @server
	-- @return number The reloading progress
	function ents_methods:aceReloadProgress()
		local this = getent(self)

		if restrictInfo(this) or not isGun(this) then return 1 end

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

	--- Returns time it takes for an ACE weapon to reload magazine
	-- @server
	-- @return number The time it takes to reload the magazine
	function ents_methods:aceMagReloadTime()
		local this = getent(self)

		if restrictInfo(this) or not isGun(this) or not this.MagReload then return 0 end

		return this.MagReload
	end

	--- Returns the state of an ACE weapon
	-- @server
	-- @return string The state of the weapon
	function ents_methods:aceState()
		local this = getent(self)

		if not isGun(this) then return "" end
		if restrictInfo(this) then return "" end

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
	--- Returns true if the entity is an ACE ammo crate
	-- @server
	-- @return boolean True if the entity is an ACE ammo crate
	function ents_methods:aceIsAmmo ()
		return isAmmo(getent(self))
	end

	--- Returns the rounds left in an ace ammo crate
	-- @server
	-- @return number The rounds left in the crate
	function ents_methods:aceRounds()
		local this = getent(self)

		if not isAmmo(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Ammo
	end

	--- Returns the type of weapon the ammo in an ACE ammo crate loads into
	-- @server
	-- @return string The type of weapon the ammo in the crate loads into
	function ents_methods:aceRoundType()
		local this = getent(self)
		if not isAmmo(this) then return "" end
		if restrictInfo(this) then return "" end
		--return this.RoundId or ""
		-- E2 uses this one now

		return this.RoundType or ""
	end

	--- Returns the type of ammo in a crate or gun
	-- @server
	-- @return string The type of ammo
	function ents_methods:aceAmmoType()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return "" end
		if restrictInfo(this) then return "" end

		return this.BulletData["Type"] or ""
	end

	--- Returns the caliber of an ammo or gun
	-- @server
	-- @return number The caliber
	function ents_methods:aceCaliber()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Caliber * 10
	end

	--- Returns the muzzle velocity of the ammo in a crate or gun
	-- @server
	-- @return number The muzzle velocity
	function ents_methods:aceMuzzleVel()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return round((this.BulletData["MuzzleVel"] or 0) * ACE.VelScale, 3)
	end

	--- Returns the mass of the projectile in a crate or gun
	-- @server
	-- @return number The mass of the projectile
	function ents_methods:aceProjectileMass()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.BulletData["ProjMass"] or 0, 3)
	end

	--- Returns the number of projectiles in a flechette round
	-- @server
	-- @return number The number of projectiles
	function ents_methods:aceFLSpikes()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if this.BulletData["Type"] ~= "FL" then return 0 end

		return this.BulletData["Flechettes"] or 0
	end

	--- Returns the mass of a single spike in a FL round in a crate or gun
	-- @server
	-- @return number The mass of a single spike
	function ents_methods:aceFLSpikeMass()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if this.BulletData["Type"] ~= "FL" then return 0 end

		return round(this.BulletData["FlechetteMass"] or 0, 3)
	end

	--- Returns the radius of the spikes in a flechette round in mm
	-- @server
	-- @return number The radius of the spikes in mm
	function ents_methods:aceFLSpikeRadius()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end
		if this.BulletData["Type"] ~= "FL" then return 0 end

		return round((this.BulletData["FlechetteRadius"] or 0) * 10, 3)
	end

	--- Returns the penetration of an AP, APHE, or HEAT round
	-- @server
	-- @return number The penetration of the round
	function ents_methods:acePenetration()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		local Type = this.BulletData["Type"] or ""
		local Energy

		if Type == "AP" or Type == "APHE" then
			Energy = ACE_Kinetic(this.BulletData["MuzzleVel"] * 39.37, this.BulletData["ProjMass"] - (this.BulletData["FillerMass"] or 0), this.BulletData["LimitVel"])

			return round((Energy.Penetration / this.BulletData["PenArea"]) * ACE.KEtoRHA, 3)
		elseif Type == "HEAT" then
			local Crushed, HEATFillerMass, _ = ACE.RoundTypes["HEAT"].CrushCalc(this.BulletData.MuzzleVel, this.BulletData.FillerMass)
			if Crushed == 1 then return 0 end -- no HEAT jet to fire off, it was all converted to HE
			Energy = ACE_Kinetic(ACE.RoundTypes["HEAT"].CalcSlugMV(this.BulletData, HEATFillerMass) * 39.37, this.BulletData["SlugMass"], 9999999)

			return round((Energy.Penetration / this.BulletData["SlugPenArea"]) * ACE.KEtoRHA, 3)
		elseif Type == "FL" then
			Energy = ACE_Kinetic(this.BulletData["MuzzleVel"] * 39.37, this.BulletData["FlechetteMass"], this.BulletData["LimitVel"])

			return round((Energy.Penetration / this.BulletData["FlechettePenArea"]) * ACE.KEtoRHA, 3)
		end

		return 0
	end

	--- Returns the blast radius of an HE, APHE, or HEAT round
	-- @server
	-- @return number The blast radius of the round
	function ents_methods:aceBlastRadius()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		local Type = this.BulletData["Type"] or ""

		if Type == "HE" or Type == "APHE" then
			return round(this.BulletData["FillerMass"] ^ 0.33 * 8, 3)
		elseif Type == "HEAT" then
			return round((this.BulletData["FillerMass"] / 3) ^ 0.33 * 8, 3)
		end

		return 0
	end

	--- Returns the drag coef of the ammo in a crate or gun
	-- @server
	-- @return number The drag coef of the ammo
	function ents_methods:aceDragCoef()
		local this = getent(self)
		if not (isAmmo(this) or isGun(this)) then return 0 end
		if restrictInfo(this) then return 0 end

		return (this.BulletData["DragCoef"] or 0) / ACE.DragDiv
	end
end

-- Mobility functions
do
	--- Returns the specs of an engine or gearbox
	-- @param string id ID or name of the engine or gearbox
	-- @server
	-- @return table The specs table
	function ace_library.getMobilitySpecs(id)
		checkluatype(id, TYPE_STRING)

		local listEntries = ACE.Weapons.Mobility

		-- Not a valid id, try name
		if not listEntries[id] then
			id = listIDFromName(listEntries, id)

			-- Name is also invalid, error
			if not id or not listEntries[id] then
				SF.Throw("Invalid ID or name", 2)
			end
		end

		local specs = table.Copy(listEntries[id])
		specs.BaseClass = nil

		return sanitize(specs)
	end

	--- Returns a list of all mobility components
	-- @server
	-- @return table The mobility component list
	function ace_library.getAllMobility()
		local tbl = {}

		for id, _ in pairs(ACE.Weapons.Mobility) do
			tbl[#tbl + 1] = id
		end

		return tbl
	end

	--- Returns a list of all engines
	-- @server
	-- @return table The engine list
	function ace_library.getAllEngines()
		local tbl = {}

		for id, d in pairs(ACE.Weapons.Mobility) do
			if d.ent == "ace_engine" then
				tbl[#tbl + 1] = id
			end
		end

		return tbl
	end

	--- Returns a list of all gearboxes
	-- @server
	-- @return table The gearbox list
	function ace_library.getAllGearboxes()
		local tbl = {}

		for id, d in pairs(ACE.Weapons.Mobility) do
			if d.ent == "ace_gearbox" then
				tbl[#tbl + 1] = id
			end
		end

		return tbl
	end

	--- Returns any wheels linked to this engine/gearbox or child gearboxes
	-- @server
	-- @return table The linked wheels
	function ents_methods:aceGetLinkedWheels()
		local this = getent(self)

		if not (isEngine(this) or isGearbox(this)) then
			SF.Throw("Target must be an engine or gearbox", 2)
		end

		local wheels = {}
		for _, ent in pairs(ACE_GetLinkedWheels(this)) do
			wheels[#wheels + 1] = ent
		end

		return sanitize(wheels)
	end

	--- Returns true if the entity is an ACE engine
	-- @server
	-- @return boolean Whether the entity is an ACE engine
	function ents_methods:aceIsEngine()
		return isEngine(getent(self))
	end

	--- Returns true if an ACE engine is electric
	-- @server
	-- @return boolean Whether the engine is electric
	function ents_methods:aceIsElectric()
		return getent(self).iselec == true
	end

	--- Returns the torque in N/m of an ACE engine
	-- @server
	-- @return number The torque in N/m
	function ents_methods:aceMaxTorque()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakTorque
	end

	--- Returns the torque in N/m of an ACE engine with fuel
	-- @server
	-- @return number The torque in N/m
	function ents_methods:aceMaxTorqueWithFuel()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakTorque * ACE.TorqueBoost
	end

	--- Returns the power in kW of an ACE engine
	-- @server
	-- @return number The power in kW
	function ents_methods:aceMaxPower()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.peakkw
	end

	--- Returns the power in kW of an ACE engine with fuel
	-- @server
	-- @return number The power in kW
	function ents_methods:aceMaxPowerWithFuel()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.peakkw * ACE.TorqueBoost
	end

	--- Returns the idle rpm of an ACE engine
	-- @server
	-- @return number The idle rpm
	function ents_methods:aceIdleRPM()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.IdleRPM
	end

	--- Returns the powerband min and max of an ACE Engine
	-- @server
	-- @return number The powerband min
	-- @return number The powerband max
	function ents_methods:acePowerband()
		local this = getent(self)

		if not isEngine(this) then return 0, 0 end

		return this.PeakMinRPM, this.PeakMaxRPM
	end

	--- Returns the powerband min of an ACE engine
	-- @server
	-- @return number The powerband min
	function ents_methods:acePowerbandMin()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakMinRPM
	end

	--- Returns the powerband max of an ACE engine
	-- @server
	-- @return number The powerband max
	function ents_methods:acePowerbandMax()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.PeakMaxRPM
	end

	--- Returns the redline max of an ACE engine
	-- @server
	-- @return number The redline
	function ents_methods:aceRedline()
		local this = getent(self)

		if not isEngine(this) then return 0 end

		return this.LimitRPM
	end

	--- Returns the current rpm of an ACE engine
	-- @server
	-- @return number The current rpm
	function ents_methods:aceRPM()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.FlyRPM)
	end

	--- Returns the current torque of an ACE engine
	-- @server
	-- @return number The current torque
	function ents_methods:aceTorque()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.Torque)
	end

	--- Returns the inertia of an ACE engine's flywheel
	-- @server
	-- @return number The inertia of the flywheel
	function ents_methods:aceFlyInertia()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Inertia
	end

	--- Returns the mass of an ACE engine's flywheel
	-- @server
	-- @return number The mass of the flywheel
	function ents_methods:aceFlyMass()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Inertia / 3.1416 ^ 2
	end


	--- Returns the current power of an ACE engine in kW
	-- @server
	-- @return number The current power in kW
	function ents_methods:acePower()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return round(this.Torque * this.FlyRPM / 9548.8)
	end

	--- Returns true if the RPM of an ACE engine is inside the powerband
	-- @server
	-- @return boolean True if the RPM is inside the powerband
	function ents_methods:aceInPowerband()
		local this = getent(self)

		if not isEngine(this) then return false end
		if restrictInfo(this) then return false end

		return this.FlyRPM > this.PeakMinRPM and this.FlyRPM < this.PeakMaxRPM
	end

	--- Returns the throttle value
	-- @server
	-- @return number The throttle value
	function ents_methods:aceGetThrottle()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Throttle * 100
	end

	--- Sets the throttle value for an ACE engine
	-- @server
	-- @param number throttle The throttle value
	function ents_methods:aceSetThrottle(throttle)
		checkluatype(throttle, TYPE_NUMBER)

		local this = getent(self)

		checkpermission(instance, this, "entities.ace")

		if not isEngine(this) then return end

		this:TriggerInput("Throttle", throttle)
	end

	--- Gets the fuel remaining for an ACE engine
	-- @server
	-- @return number The fuel remaining, in litres or kilowatt-hours
	function ents_methods:aceFuelRemaining()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.TotalFuel
	end

	--- Returns true if the entity is an ACE gearbox
	-- @server
	-- @return boolean True if the entity is an ACE gearbox
	function ents_methods:aceIsGearbox ()
		return isGearbox(getent(self))
	end

	--- Returns the current gear for an ACE gearbox
	-- @server
	-- @return number The current gear
	function ents_methods:aceGear()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Gear
	end

	--- Returns the number of gears for an ACE gearbox
	-- @server
	-- @return number The number of gears
	function ents_methods:aceNumGears()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.Gears
	end

	--- Returns the final drive ratio for an ACE gearbox
	-- @server
	-- @return number The final drive ratio
	function ents_methods:aceFinalRatio()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return tonumber(this.GearTable["Final"])
	end

	--- Returns the total ratio (current gear * final) for an ACE gearbox
	-- @server
	-- @return number The total ratio
	function ents_methods:aceTotalRatio()
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		return this.GearRatio
	end

	--- Returns the max torque for an ACE gearbox
	-- @server
	-- @return number The max torque
	function ents_methods:aceTorqueRating()
		local this = getent(self)

		if not isGearbox(this) then return 0 end

		return this.MaxTorque
	end

	--- Returns whether an ACE gearbox is dual clutch
	-- @server
	-- @return boolean True if the gearbox is dual clutch
	function ents_methods:aceIsDual()
		local this = getent(self)

		if not isGearbox(this) then return false end
		if restrictInfo(this) then return false end

		return this.Dual
	end

	--- Returns the time in ms an ACE gearbox takes to change gears
	-- @server
	-- @return number The time in ms
	function ents_methods:aceShiftTime()
		local this = getent(self)

		if not isGearbox(this) then return 0 end

		return this.SwitchTime * 1000
	end

	--- Returns true if an ACE gearbox is in gear
	-- @server
	-- @return boolean True if the gearbox is in gear
	function ents_methods:aceInGear()
		local this = getent(self)

		if not isGearbox(this) then return false end
		if restrictInfo(this) then return false end

		return this.InGear
	end

	--- Returns the ratio for a specified gear of an ACE gearbox
	-- @server
	-- @param number gear The gear to get the ratio for
	function ents_methods:aceGearRatio(gear)
		checkluatype(gear, TYPE_NUMBER)
		local this = getent(self)

		if not isGearbox(this) then return 0 end
		if restrictInfo(this) then return 0 end

		local g = clamp(floor(gear), 1, this.Gears)

		return tonumber(this.GearTable[g]) or 0
	end

	--- Returns the current torque output for an ACE gearbox
	-- @server
	-- @return number The current torque output
	function ents_methods:aceTorqueOut()
		local this = getent(self)

		if not isGearbox(this) then return 0 end

		return min(this.TotalReqTq, this.MaxTorque) / this.GearRatio
	end

	--- Sets the gear ratio of a CVT, set to 0 to use built-in algorithm
	-- @server
	-- @param number ratio The ratio to set
	function ents_methods:aceCVTRatio(ratio)
		checkluatype(ratio, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.CVT then return end

		this.CVTRatio = math.Clamp(ratio, 0, 1)
	end

	--- Sets the current gear for an ACE gearbox
	-- @server
	-- @param number gear The gear to switch to
	function ents_methods:aceShift(gear)
		checkluatype(gear, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Gear", gear)
	end

	--- Cause an ACE gearbox to shift up
	-- @server
	function ents_methods:aceShiftUp()
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Gear Up", 1)
	end

	--- Cause an ACE gearbox to shift down
	-- @server
	function ents_methods:aceShiftDown()
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Gear Down", 1)
	end

	--- Sets the brakes for an ACE gearbox
	-- @server
	-- @param number brake The brake value to apply
	function ents_methods:aceBrake(brake)
		checkluatype(brake, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Brake", brake)
	end

	--- Sets the left brakes for an ACE gearbox
	-- @server
	-- @param number brake The brake value to apply
	function ents_methods:aceBrakeLeft(brake)
		checkluatype(brake, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Left Brake", brake)
	end

	--- Sets the right brakes for an ACE gearbox
	-- @server
	-- @param number brake The brake value to apply
	function ents_methods:aceBrakeRight(brake)
		checkluatype(brake, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Right Brake", brake)
	end

	--- Sets the clutch for an ACE gearbox
	-- @server
	-- @param number clutch The clutch value to apply
	function ents_methods:aceClutch(clutch)
		checkluatype(clutch, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end

		this:TriggerInput("Clutch", clutch)
	end

	--- Sets the left clutch for an ACE gearbox
	-- @server
	-- @param number clutch The clutch value to apply
	function ents_methods:aceClutchLeft(clutch)
		checkluatype(clutch, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Left Clutch", clutch)
	end

	--- Sets the right clutch for an ACE gearbox
	-- @server
	-- @param number clutch The clutch value to apply
	function ents_methods:aceClutchRight(clutch)
		checkluatype(clutch, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Dual then return end

		this:TriggerInput("Right Clutch", clutch)
	end

	--- Sets the steer ratio for an ACE gearbox
	-- @server
	-- @param number ratio The steer ratio to apply
	function ents_methods:aceSteerRate(rate)
		checkluatype(rate, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.DoubleDiff then return end

		this:TriggerInput("Steer Rate", rate)
	end

	--- Applies gear hold for an automatic ACE gearbox
	-- @server
	-- @param number hold True to hold the current gear
	function ents_methods:aceHoldGear(hold)
		checkluatype(hold, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Auto then return end

		this:TriggerInput("Hold Gear", hold)
	end

	--- Sets the shift point scaling for an automatic ACE gearbox
	-- @server
	-- @param number scale The shift point scaling value
	function ents_methods:aceShiftPointScale(scale)
		checkluatype(scale, TYPE_NUMBER)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isGearbox(this) then return end
		if restrictInfo(this) then return end
		if not this.Auto then return end

		this:TriggerInput("Shift Speed Scale", scale)
	end
end

-- Fuel functions
do
	--- Returns true if the entity is an ACE fuel tank
	-- @server
	-- @return boolean True if the entity is an ACE fuel tank
	function ents_methods:aceIsFuel()
		return isFuel(getent(self))
	end

	--- Returns true if the current engine requires fuel to run
	-- @server
	-- @return boolean True if the current engine requires fuel to run
	function ents_methods:aceFuelRequired()
		local this = getent(self)

		if not isEngine(this) then return false end
		if restrictInfo(this) then return false end

		return (this.RequiresFuel and true) or false
	end

	--- Sets the ACE fuel tank refuel duty status, which supplies fuel to other fuel tanks
	-- @server
	-- @param[opt] boolean True to enable refuel duty, false to disable
	function ents_methods:aceRefuelDuty(on)
		checkluatype(on, TYPE_BOOL)
		local this = getent(self)

		checkpermission(instance, this, "entities.ace")
		if not isFuel(this) then return end

		this:TriggerInput("Refuel Duty", on and true or false)
	end

	--- Returns the remaining liters or kilowatt hours of fuel in an ACE fuel tank or engine
	-- @server
	-- @return number The remaining fuel
	function ents_methods:aceFuel()
		local this = getent(self)

		if restrictInfo(this) then return 0 end

		if isFuel(this) then
			return round(this.Fuel, 3)
		elseif isEngine(this) then
			if not #this.FuelLink then return 0 end --if no tanks, return 0

			local liters = 0
			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					liters = liters + tank.Fuel
				end
			end

			return round(liters, 3)
		end

		return 0
	end

	--- Returns the amount of fuel in an ACE fuel tank or linked to engine as a percentage of capacity
	-- @server
	-- @return number The fuel percentage
	function ents_methods:aceFuelLevel()
		local this = getent(self)

		if restrictInfo(this) then return 0 end

		if isFuel(this) then
			return round(this.Fuel / this.Capacity, 3)
		elseif isEngine(this) then
			if not #this.FuelLink then return 0 end --if no tanks, return 0

			local liters = 0
			local capacity = 0
			for _, tank in pairs(this.FuelLink) do
				if validPhysics(tank) and tank.Active then
					capacity = capacity + tank.Capacity
					liters = liters + tank.Fuel
				end
			end

			if capacity <= 0 then return 0 end

			return round(liters / capacity, 3)
		end

		return 0
	end

	--- Returns the current fuel consumption in liters or kilowatts per minute of an engine
	-- @server
	-- @return number The fuel consumption
	function ents_methods:aceFuelUse()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not #this.FuelLink then return 0 end --if no tanks, return 0

		local tank
		for _, fueltank in pairs(this.FuelLink) do
			if validPhysics(fueltank) and fueltank.Fuel > 0 and fueltank.Active then
				tank = fueltank
				break
			end
		end

		if not tank then return 0 end

		local Consumption
		if this.FuelType == "Electric" then
			Consumption = 60 * (this.Torque * this.FlyRPM / 9548.8) * this.FuelUse
		else
			local Load = 0.3 + this.Throttle * 0.7
			Consumption = 60 * Load * this.FuelUse * (this.FlyRPM / this.PeakKwRPM) / ACE.FuelDensity[tank.FuelType]
		end

		return round(Consumption, 3)
	end

	--- Returns the peak fuel consumption in liters per minute or kilowatts of an engine at powerband max, for the current fuel type the engine is using
	-- @server
	-- @return number The peak fuel consumption
	function ents_methods:acePeakFuelUse()
		local this = getent(self)

		if not isEngine(this) then return 0 end
		if restrictInfo(this) then return 0 end
		if not #this.FuelLink then return 0 end --if no tanks, return 0

		local fuel = "Petrol"
		local tank
		for _, fueltank in pairs(this.FuelLink) do
			if fueltank.Fuel > 0 and fueltank.Active then
				tank = fueltank
				break
			end
		end

		if tank then
			fuel = tank.Fuel
		end

		local Consumption
		if this.FuelType == "Electric" then
			Consumption = 60 * (this.PeakTorque * this.LimitRPM / (4 * 9548.8)) * this.FuelUse
		else
			Consumption = 60 * this.FuelUse / ACE.FuelDensity[fuel]
		end

		return round(Consumption, 3)
	end
end

-- Radar functions
do
	--- Returns a table containing the outputs you'd get from an ACE tracking radar, missile radar, or IRST
	-- @server
	-- @return table The radar data - check radar wire outputs for key names
	function ents_methods:aceRadarData()
		local this = getent(self)
		if not isRadar(this) then
			SF.Throw("Entity is not a radar", 2)
		end

		local data = {}
		local radarType = this:GetClass()

		if restrictInfo(this) then return data end

		data.Detected = this.OutputData.Detected
		data.Position = this.OutputData.Position

		if radarType == "ace_radar" then
			data.ClosestDistance = this.OutputData.ClosestDistance
			data.Entities = this.OutputData.Entities
			data.Velocity = this.OutputData.Velocity
		elseif radarType == "ace_trackingradar" or "ace_irst" then
			data.Owner = this.OutputData.Owner
			data.ClosestToBeam = this.OutputData.ClosestToBeam
			if radarType == "ace_trackingradar" then
				data.Velocity = this.OutputData.Velocity
				data.IsJammed = this.OutputData.IsJammed
			elseif radarType == "ace_irst" then
				data.Angle = this.OutputData.Angle
				data.EffHeat = this.OutputData.EffHeat
			end
		end

		return sanitize(data)
	end
end

end