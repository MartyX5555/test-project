
local ClassName = "Radio"


ACE = ACE or {}
ACE.Fuse = ACE.Fuse or {}

local this = ACE.Fuse[ClassName] or inherit.NewSubOf(ACE.Fuse.Contact)
ACE.Fuse[ClassName] = this

---



this.Name = ClassName

-- The entity to measure distance to.
this.Target = nil

-- the fuse may trigger at some point under this range - unless it's travelling so fast that it steps right on through.
this.Distance = 2000


this.desc = "This fuse tracks the guidance module's target and detonates when the distance becomes low enough.\nDistance in inches."


-- Configuration information for things like acfmenu.
this.Configurable = table.Copy(this:super().Configurable)

local configs = this.Configurable

configs[#configs + 1] =
{
	Name = "Distance",		-- name of the variable to change
	DisplayName = "Distance",	-- name displayed to the user
	CommandName = "Ds",		-- shorthand name used in console commands

	Type = "number",			-- lua type of the configurable variable
	Min = 0,					-- number specific: minimum value
	Max = 10000				-- number specific: maximum value

	-- in future if needed: min/max getter function based on munition type.  useful for modifying radar cones?
}

do

	local whitelist = {
		[ "ace_rack" ]				= true,
		[ "prop_vehicle_prisoner_pod" ] = true,
		[ "ace_crewseat_gunner" ]	= true,
		[ "ace_crewseat_loader" ]	= true,
		[ "ace_crewseat_driver" ]	= true,
		[ "ace_rwr_dir" ]			= true,
		[ "ace_rwr_sphere" ]			= true,
		[ "ace_radar" ]		= true,
		[ "ace_opticalcomputer" ]	= true,
		[ "gmod_wire_expression2" ]	= true,
		[ "gmod_wire_gate" ]			= true,
		[ "prop_physics" ]			= true,
		[ "ace_ecm" ]				= true,
		[ "ace_trackingradar" ]		= true,
		[ "ace_irst" ]				= true,
		[ "ace_gun" ]				= true,
		[ "ace_ammo" ]				= true,
		[ "ace_engine" ]				= true,
		[ "ace_fueltank" ]			= true,
		[ "ace_gearbox" ]			= true,
		[ "primitive_shape" ]		= true,
		[ "primitive_airfoil" ]		= true,
		[ "primitive_rail_slider" ]	= true,
		[ "primitive_slider" ]		= true,
		[ "primitive_ladder" ]		= true
	}

	local function FilterFunction(ent)

		local Class = ent:GetClass()

		--Skip ents like world entities
		if whitelist[Class] then
			return true
		end

		return false
	end

	--Question: Should radio fuze be limited to detect props in front of the missile only? Its weird it detonates by detecting something behind it.
	function this:GetDetonate(missile)

		if not self:IsArmed() then return false end

		local MissilePos = missile.CurPos
		local Dist = self.Distance

		local trace = {}
		trace.start         = missile.DPos or MissilePos
		trace.endpos        = MissilePos --small compensation for incoming impacts.
		trace.filter        = FilterFunction
		trace.mins          = Vector(-Dist, -Dist, -Dist)
		trace.maxs          = -trace.mins
		trace.ignoreworld   = true

		missile.DPos = MissilePos

		local tr = util.TraceHull(trace)

		if tr.Hit then

			local HitEnt = tr.Entity

			if ACE_Check( HitEnt ) then

				local HitPos	= HitEnt:GetPos()
				local tolocal	= missile:WorldToLocal(HitPos)

				local conLauncher = ACE.GetContraption( missile.Launcher )
				local conTarget = ACE.GetContraption( HitEnt ) -- 1 prop will not have a contraption. 2 linked props (weld, parent) will do.

				if conLauncher and conTarget then -- We only care about real contraptions. Not single props.

					if conLauncher ~= conTarget and tolocal.x > 0 then

						debugoverlay.Text(HitPos + Vector(0,0,20), "[CFW]- Valid Hit On: " .. (HitEnt:GetClass()) , 5 )
						debugoverlay.Box(MissilePos, trace.mins, trace.maxs, 1, Color(0,255,0,10))

						return true
					end

					debugoverlay.Text(HitPos + Vector(0,0,20), "[CFW] Invalid Hit on: " .. (HitEnt:GetClass()) , 5 )
					debugoverlay.Box(MissilePos, trace.mins, trace.maxs, 1, Color(255,0,0,10))

				end
			end
		end

		return false
	end
end


function this:GetDisplayConfig()
	return
	{
		["Arming delay"] = math.Round(self.Primer, 3) .. " s",
		["Distance"] = math.Round(self.Distance / 39.37, 1) .. " m"
	}
end
