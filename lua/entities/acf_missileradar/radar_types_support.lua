
ACEM.RadarBehaviour = ACEM.RadarBehaviour or {}
ACEM.DefaultRadarSound = ACEM.DefaultRadarSound or "buttons/button16.wav"

function ACFM_GetMissilesInCone(pos, dir, degs)

	local ret = {}

	for missile, _ in pairs(ACE.Missiles) do

		if not IsValid(missile) then continue end

		if ACFM_ConeContainsPos(pos, dir, degs, missile:GetPos()) then
			ret[#ret + 1] = missile
		end

	end

	return ret

end

function ACFM_GetMissilesInSphere(pos, radius)

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
		return ACFM_GetMissilesInCone(self:GetPos(), self:GetForward(), self.ConeDegs)
	end
}


ACEM.RadarBehaviour["OMNI-AM"] =
{
	GetDetectedEnts = function(self)
		return ACFM_GetMissilesInSphere(self:GetPos(), self.Range)
	end
}
