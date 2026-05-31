
ACEM.RadarBehaviour = ACEM.RadarBehaviour or {}
ACEM.DefaultRadarSound = ACEM.DefaultRadarSound or "buttons/button16.wav"

function ACEM.ConeContainsPos(conePos, coneDir, degs, pos)

	local minDot = math.cos( math.rad(degs) )

	local testDir = pos - conePos
	testDir:Normalize()

	local dot = coneDir:Dot(testDir)

	return dot >= minDot
end

function ACEM.GetMissilesInCone(pos, dir, degs)

	local ret = {}

	for missile, _ in pairs(ACE.Missiles) do

		if not IsValid(missile) then continue end

		if ACEM.ConeContainsPos(pos, dir, degs, missile:GetPos()) then
			ret[#ret + 1] = missile
		end

	end

	return ret

end

function ACEM.GetMissilesInSphere(pos, radius)

	local ret = {}

	local radSqr = radius * radius

	for missile, _ in pairs(ACE.Missiles) do

		if not IsValid(missile) then continue end

		if pos:DistToSqr(missile:GetPos()) <= radSqr then
			ret[#ret + 1] = missile
		end

	end

	return ret

end

ACEM.RadarBehaviour["DIR-AM"] =
{
	GetDetectedEnts = function(self)
		return ACEM.GetMissilesInCone(self:GetPos(), self:GetForward(), self.ConeDegs)
	end
}


ACEM.RadarBehaviour["OMNI-AM"] =
{
	GetDetectedEnts = function(self)
		return ACEM.GetMissilesInSphere(self:GetPos(), self.Range)
	end
}
