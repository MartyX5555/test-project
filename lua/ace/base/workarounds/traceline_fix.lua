
-- Workaround to issue: https://github.com/Facepunch/garrysmod-issues/issues/4142. Brought from ACF3
-- WARNING: MASK_SHOT breaks the tracehull stability, leaving in traceline level.
local Hull = util.TraceHull
local Zero = Vector()

-- Available for use, just in case
if not util.LegacyTraceLine then
	util.LegacyTraceLine = util.TraceLine
end

function util.TraceLine(TraceData, ...)
	if not istable(TraceData) then
		ErrorNoHaltWithStack("bad argument #1 to 'TraceLine' (table expected, got " .. type(TraceData) .. ")")
		return
	end

	-- We only want to modify the mins/maxs in this execution, as this input table could have been used by tracehulls too.
	TraceData.premins = TraceData.mins
	TraceData.premaxs = TraceData.maxs

	TraceData.mins = Zero
	TraceData.maxs = Zero

	local TraceRes = Hull(TraceData, ...)

	TraceData.mins = TraceData.premins
	TraceData.maxs = TraceData.premaxs

	TraceData.premins = nil
	TraceData.premaxs = nil

	-- TraceHulls don't hit player hitboxes properly, if we hit a player, retry as a regular TraceLine
	-- This fixes issues with SWEPs and toolgun traces hitting players when aiming near but not at them
	local HitEnt = TraceRes.Entity

	if istable(TraceRes) and IsValid(HitEnt) and (HitEnt:IsPlayer() or HitEnt:IsNPC()) then
		return util.LegacyTraceLine(TraceData, ...)
	end

	return TraceRes
end