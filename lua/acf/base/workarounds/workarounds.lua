

if CLIENT then

	--Copied from garrysmod CalcVehicleView function, to allow acf ents to be included into the filter
	function ACE_CalcVehicleView( Vehicle, ply, view )

		--Make sure that allowed seats use this override.
		if not Vehicle.ACE_CamOverride then return end

		if ( Vehicle.GetThirdPersonMode == nil or ply:GetViewEntity() ~= ply ) then
			-- This shouldn't ever happen.
			return
		end

		--
		-- If we're not in third person mode - then get outa here stalker
		--
		if ( not Vehicle:GetThirdPersonMode() ) then return view end

		-- Don't roll the camera
		-- view.angles.roll = 0

		local mn, mx = Vehicle:GetRenderBounds()
		local radius = ( mn - mx ):Length()
		local radius = radius + radius * Vehicle:GetCameraDistance()

		-- Trace back from the original eye position, so we don't clip through walls/objects
		local TargetOrigin = view.origin + ( view.angles:Forward() * -radius )
		local WallOffset = 4

		local tr = util.TraceHull( {
			start = view.origin,
			endpos = TargetOrigin,
			mask = CONTENTS_SOLID,
			filter = function()
				return false
			end,
			mins = Vector( -WallOffset, -WallOffset, -WallOffset ),
			maxs = Vector( WallOffset, WallOffset, WallOffset ),
		} )

		view.origin = tr.HitPos
		view.drawviewer = true

		--
		-- If the trace hit something, put the camera there.
		--
		if ( tr.Hit and not tr.StartSolid) then
			view.origin = view.origin + tr.HitNormal * WallOffset
		end

		return view

	end

	hook.Remove( "CalcVehicleView", "ACE_CalcVehicleView_Override")
	hook.Add( "CalcVehicleView", "ACE_CalcVehicleView_Override", ACE_CalcVehicleView)

end

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