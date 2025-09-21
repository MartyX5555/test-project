local ACE = ACE or {}
local Guidance = {}

Guidance.Name = "Infrared"
Guidance.desc = "This guidance package detects hot targets infront of itself, and guides the munition towards it."
Guidance.SeekDelay = 0.5 -- Re-seek drastically reduced cost so we can re-seek

-- Callback values
Guidance.Target = nil --Currently acquired target.
Guidance.SeekCone = 20 -- Cone to acquire targets within.
Guidance.ViewCone = 25 -- Cone to retain targets within.
Guidance.MinimumDistance = 200 -- Minimum distance for a target to be considered. ~5m
Guidance.MaximumDistance = 20000 -- -- Maximum distance for a target to be considered.
Guidance.SeekSensitivity = 1 --Sensitivity of the IR Seeker, higher sensitivity is for aircraft
Guidance.HeatAboveAmbient = 5 --Defines how many degrees are required above the ambient one to consider a target

function Guidance:Init()
	self.LastSeek = CurTime() - self.SeekDelay - 0.000001
	self.LastTargetPos = Vector()
end

function Guidance:Configure(missile)

	self.ViewCone		= (ACE_GetGunValue(missile.BulletData, "viewcone") or Guidance.ViewCone) * 1.2
	self.ViewConeCos		= (math.cos(math.rad(self.ViewCone))) * 1.2
	self.SeekCone		= (ACE_GetGunValue(missile.BulletData, "seekcone") or Guidance.SeekCone) * 1.2
	self.SeekSensitivity	= ACE_GetGunValue(missile.BulletData, "seeksensitivity") or Guidance.SeekSensitivity

end

--TODO: still a bit messy, refactor this so we can check if a flare exits the viewcone too.
function Guidance:GetGuidance(missile)

	self:CheckTarget(missile)

	if not IsValid(self.Target) then
		return {}
	end

	local missilePos = missile:GetPos()
	--local missileForward = missile:GetForward()
	--local targetPhysObj = self.Target:GetPhysicsObject()
	local targetPos = self.Target:GetPos() + Vector(0,0,25)

	local mfo	= missile:GetForward()
	local mdir	= (targetPos - missilePos):GetNormalized()
	local dot	= mfo:Dot(mdir)

	if dot < self.ViewConeCos then
		self.Target = nil
		return {}
	else
		self.TargetPos = targetPos
		return {TargetPos = targetPos, ViewCone = self.ViewCone * 1.3}
	end

end

function Guidance:CheckTarget(missile)

	local target = self:AcquireLock(missile)

	if IsValid(target) then
		self.Target = target
	end
end

function Guidance:GetWhitelistedEntsInCone(missile)

	local ScanArray = ACE.GlobalEntities
	if not next(ScanArray) then return {} end

	local missilePos       = missile:GetPos()
	local WhitelistEnts    = {}
	local LOSdata          = {}
	local LOStr            = {}

	local entpos           = vector_origin
	local difpos           = vector_origin
	local dist             = 0

	for scanEnt, _ in pairs(ScanArray) do

		-- skip any invalid entity
		if not IsValid(scanEnt) then continue end
		if not scanEnt.Heat and ACE.HasParent(scanEnt) then continue end

		entpos  = scanEnt:GetPos()
		difpos  = entpos - missilePos
		dist	= difpos:Length()

		-- skip any ent outside of minimun distance
		if dist < self.MinimumDistance then continue end

		-- skip any ent far than maximum distance
		if dist > self.MaximumDistance then continue end

		LOSdata.start		= missilePos
		LOSdata.endpos		= entpos
		LOSdata.collisiongroup  = COLLISION_GROUP_WORLD
		LOSdata.filter		= function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end
		LOSdata.mins			= Vector(0,0,0)
		LOSdata.maxs			= Vector(0,0,0)

		LOStr = util.TraceHull( LOSdata )

		--Trace did not hit world
		if not LOStr.Hit then
			table.insert(WhitelistEnts, scanEnt)
		end


	end

	return WhitelistEnts
end

-- Return the first entity found within the seek-tolerance, or the entity within the seek-cone closest to the seek-tolerance.
function Guidance:AcquireLock(missile)

	local curTime = CurTime()

	if self.LastSeek + self.SeekDelay > curTime then return nil end
	self.LastSeek = curTime

	--Part 1: get all ents in cone
	local found = self:GetWhitelistedEntsInCone(missile)

	--Part 2: get a good seek target
	if not next(found) then return NULL end

	local missilePos	= missile:GetPos()

	local bestAng    = math.huge
	local bestent    = NULL

	local Heat       = 0

	local entpos     = vector_origin
	local difpos     = vector_origin
	local dist       = 0

	local physEnt    = NULL

	local ang        = Angle()
	local absang     = Angle()
	local testang    = Angle()

	for _, classifyent in ipairs(found) do

		entpos  = classifyent:WorldSpaceCenter()
		difpos  = entpos - missilePos
		dist	= difpos:Length()

		--if the target is a Heat Emitter, track its heat
		if classifyent.Heat then

			Heat = self.SeekSensitivity * classifyent.Heat

		--if is not a Heat Emitter, track the friction's heat
		else
			physEnt = classifyent:GetPhysicsObject()

			--skip if it has not a valid physic object. It's amazing how gmod can break Guidance. . .
			--check if it's not frozen. If so, skip it, unmoveable stuff should not be even considered
			if IsValid(physEnt) and not physEnt:IsMoveable() then continue end

			Heat = ACE_InfraredHeatFromProp( self, classifyent , dist )
		end

		--Skip if not Hotter than AmbientTemp in deg C.
		if Heat <= ACE.AmbientTemp + self.HeatAboveAmbient then continue end

		ang	= missile:WorldToLocalAngles((entpos - missilePos):Angle())	--Used for testing if inrange
		absang	= Angle(math.abs(ang.p),math.abs(ang.y),0) --Since I like ABS so much

		if absang.p < self.SeekCone and absang.y < self.SeekCone then --Entity is within missile cone

			testang = absang.p + absang.y --Could do pythagorean stuff but meh, works 98% of time

			if self.Target == scanEnt then
				testang = testang / self.SeekSensitivity
			end

			testang = testang - Heat

			--Sorts targets as closest to being directly in front of radar
			if testang < bestAng then

				bestAng = testang
				bestent = classifyent

			end
		end
	end

	return bestent
end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function Guidance:GetDisplayConfig(Type)

	local seekCone =  (ACE.Weapons.Guns[Type].seekcone or 0 ) * 2
	local ViewCone = (ACE.Weapons.Guns[Type].viewcone or 0 ) * 2

	return
	{
		["Seeking"] = math.Round(seekCone, 1) .. " deg",
		["Tracking"] = math.Round(ViewCone, 1) .. " deg"
	}
end

ACE.RegisterGuidance( Guidance.Name, Guidance )
