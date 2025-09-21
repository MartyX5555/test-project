local ACE = ACE or {}
local Guidance = {}

Guidance.Name = "Antimissile"
Guidance.desc = "This guidance package detects a missile in front of itself, and guides the munition towards it."
Guidance.SeekDelay = 0.5 -- This instance must wait this long between target seeks.
Guidance.WireSeekDelay = 0.1 -- Delay between re-seeks if an entity is provided via wiremod.

-- Callback values
Guidance.SeekCone = 20 -- Cone to acquire targets within.
Guidance.ViewCone = 25 -- Cone to retain targets within.
Guidance.MinimumDistance = 196.85	-- Minimum distance for a target to be considered--a scant 5m
Guidance.Target = nil --Currently acquired target.

Guidance.SeekTolerance = math.cos( math.rad( 2 ) ) -- Targets this close to the front are good enough.

function Guidance:Init()
	self.LastSeek = CurTime() - self.SeekDelay - 0.000001
	self.LastTargetPos = Vector()
end

function Guidance:Configure(missile)

	local launcher = missile.Launcher
	local outputs = launcher.Outputs

	if outputs then

		local names = self:GetNamedWireInputs(missile)
		if #names > 0 then
			self.InputSource = launcher
			self.InputNames = names
		end
	end

	self.ViewCone = ACE_GetGunValue(missile.BulletData, "viewcone") or Guidance.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))
	self.SeekCone = ACE_GetGunValue(missile.BulletData, "seekcone") or Guidance.SeekCone

end

function Guidance:GetNamedWireInputs(missile)

	local launcher = missile.Launcher
	local outputs = launcher.Outputs

	local names = {}

	if outputs.Target and outputs.Target.Type == "ENTITY" then
		names[#names + 1] = "Target"
	end

	return names

end

--TODO: still a bit messy, refactor this so we can check if a flare exits the viewcone too.
function Guidance:GetGuidance(missile)

	self:CheckTarget(missile)

	if not IsValid(self.Target) or ACE.HasParent(self.Target) then
		return {}
	end

	local missilePos = missile:GetPos()
	local targetPos = self.Target:GetPos()

	local mfo	= missile:GetForward()
	local mdir	= (targetPos - missilePos):GetNormalized()
	local dot	= mfo:Dot(mdir)

	if dot < self.ViewConeCos then
		self.Target = nil
		return {}
	else
		self.TargetPos = targetPos
		return {TargetPos = targetPos, ViewCone = self.ViewCone}
	end

end

function Guidance:CheckTarget(missile)

	if not (self.Target or self.Override) then
		local target = self:AcquireLock(missile)

		if IsValid(target) then
			self.Target = target
		end
	end

end

function Guidance:GetWireTarget(missile)

	local launcher = missile.Launcher
	local outputs = launcher.Outputs

	if not IsValid(self.InputSource) then
		return nil
	end

	local outputs = self.InputSource.Outputs

	if not outputs then
		return nil
	end


	for _, name in pairs(self.InputNames) do

		local outTbl = outputs[name]

		if not (outTbl and outTbl.Value) then continue end

		local val = outTbl.Value

		if IsValid(val) and IsEntity(val) then
			return val
		end

	end

end

function JankCone (init, forward, range, cone)
	local Missiles = ACE.Missiles
	local tblout = {}

	if next(Missiles) then
		for v, _ in pairs (Missiles) do
			if not IsValid(v) then continue end
			local dist = (v:GetPos() - init):Length()
			local ang = math.deg(math.acos(math.Clamp(((v:GetPos() - init):GetNormalized()):Dot(forward), -1, 1)))
			if (dist > range) then continue end
			if (ang > cone) then continue end

			table.insert(tblout, v)
		end
	end
	return tblout
end

function Guidance:GetWhitelistedEntsInCone(missile)

	local missilePos = missile:GetPos()
	local missileForward = missile:GetForward()
	local minDot = math.cos(math.rad(self.SeekCone))

	--local found = ents.FindInCone(missilePos, missileForward, 50000, self.SeekCone)
	local found = JankCone(missilePos, missileForward, 50000, self.SeekCone)

	local foundAnim = {}
	--local foundEnt
	local minDistSqr = ( self.MinimumDistance * self.MinimumDistance )

	--local filter = self.Filter
	for _, foundEnt in pairs(found) do

		local foundLocalPos = foundEnt:GetPos() - missilePos
		local foundDistSqr = foundLocalPos:LengthSqr()

		if foundDistSqr < minDistSqr then continue end
		local foundDot = foundLocalPos:GetNormalized():Dot(missileForward)

		if foundDot < minDot then continue end
		table.insert(foundAnim, foundEnt)

		model = foundEnt:GetModel()
		--print(model)


	end

	return foundAnim

end

function Guidance:HasLOSVisibility(ent, missile)

	local traceArgs =
	{
		start = missile:GetPos(),
		endpos = ent:GetPos(),
		mask = MASK_SOLID_BRUSHONLY,
		filter = {missile, ent},
		mins = Vector(0,0,0),
		maxs = Vector(0,0,0)
	}

	local res = util.TraceHull(traceArgs)

	--debugoverlay.Line( missile:GetPos(), ent:GetPos(), 15, Color(res.Hit and 255 or 0, res.Hit and 0 or 255, 0), true )

	return not res.Hit

end

-- Return the first entity found within the seek-tolerance, or the entity within the seek-cone closest to the seek-tolerance.
function Guidance:AcquireLock(missile)

	local curTime = CurTime()

	if self.LastSeek + self.WireSeekDelay <= curTime then

		local wireEnt = self:GetWireTarget(missile)

		if wireEnt then
			--print("wiremod provided", wireEnt)
			return wireEnt
		end

	end

	if self.LastSeek + self.SeekDelay > curTime then
		--print("tried seeking within timeout period")
		return nil
	end
	self.LastSeek = curTime

	-- Part 1: get all whitelisted entities in seek-cone.
	local found = self:GetWhitelistedEntsInCone(missile)

	-- Part 2: get a good seek target
	local foundCt = table.Count(found)
	if foundCt < 2 then
		--print("shortcircuited and found", found[1])
		return found[1]

	end

	local missilePos = missile:GetPos()
	local missileForward = missile:GetForward()

	local mostCentralEnt
	local lastKey

	while not mostCentralEnt do

		local ent
		lastKey, ent = next(found, lastKey)

		if not ent then break end

		if self:HasLOSVisibility(ent, missile) then

			mostCentralEnt = ent

		end

	end

	if not mostCentralEnt then return nil end

	--local mostCentralPos = mostCentralEnt:GetPos()
	local highestDot = (mostCentralEnt:GetPos() - missilePos):GetNormalized():Dot(missileForward)
	local currentEnt
	local currentDot

	for _, ent in next, found, lastKey do

		currentEnt = ent
		currentDot = (currentEnt:GetPos() - missilePos):GetNormalized():Dot(missileForward)

		if currentDot > highestDot and self:HasLOSVisibility(currentEnt, missile) then
			mostCentralEnt = currentEnt
			highestDot = currentDot

			if currentDot >= self.SeekTolerance then
				--print("found", mostCentralEnt, "in tolerance")
				return currentEnt
			end
		end
	end

	--print("iterated and found", mostCentralEnt)

	return mostCentralEnt
end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function Guidance:GetDisplayConfig(Type)

	local seekCone = ACE.Weapons.Guns[Type].seekcone * 2 or 0
	local ViewCone = ACE.Weapons.Guns[Type].viewcone * 2 or 0

	return
	{
		["Seeking"] = math.Round(seekCone, 1) .. " deg",
		["Tracking"] = math.Round(ViewCone, 1) .. " deg"
	}
end

ACE.RegisterGuidance( Guidance.Name, Guidance )