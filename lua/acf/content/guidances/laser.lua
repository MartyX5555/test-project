local ACE = ACE or {}
local Guidance = {}

Guidance.Name = "Laser"
Guidance.desc = "This guidance package reads a target-position from the launcher and guides the munition towards it."
Guidance.InputSource = nil -- An entity with a Position wire-output

-- Callback values
Guidance.ViewCone = 30 -- Cone to retain targets within.

function Guidance:Init()
end

function Guidance:Configure(missile)

	local launcher = missile.Launcher
	local outputs = launcher.Outputs

	if outputs then

		local names = self:GetNamedWireInputs(missile)


		if #names > 0 then

			self.InputSource = launcher
			self.InputNames = names

		else

			names = self:GetFallbackWireInputs(missile)

			if #names > 0 then
				self.InputSource = launcher
				self.InputNames = names
			end
		end
	end

	self.ViewCone = ACE_GetGunValue(missile.BulletData, "viewcone") or Guidance.ViewCone
	self.ViewConeCos = math.cos(math.rad(self.ViewCone))

end

function Guidance:GetNamedWireInputs(missile)

	local launcher = missile.Launcher
	local outputs = launcher.Outputs

	local names = {}

	-- If we have a Position output, we're in business.
	if outputs.Position and outputs.Position.Type == "VECTOR" then

		names[#names + 1] = "Position"

	end


	if outputs.Target and outputs.Target.Type == "ENTITY" then

		names[#names + 1] = "Target"

	end


	return names

end

function Guidance:GetFallbackWireInputs(missile)

	local launcher = missile.Launcher
	local outputs = launcher.Outputs

	-- To avoid ambiguity, only link if there's a single vector output.
	local foundOutput = nil

	for k, v in pairs(outputs) do
		if v.Type == "VECTOR" then
			if foundOutput then
				foundOutput = nil
				break
			else
				foundOutput = k
			end
		end
	end

	if foundOutput then
		return {foundOutput}
	end

end


function Guidance:GetGuidance(missile)

	local posVec = self:GetWireTarget()

	if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
		return {TargetPos = nil}
	end

	if posVec then
		local mfo	= missile:GetForward()
		local mdir	= (posVec - missile:GetPos()):GetNormalized()
		local dot	= mfo.x * mdir.x + mfo.y * mdir.y + mfo.z * mdir.z

		if dot < self.ViewConeCos then
			return {TargetPos = nil}
		end


		local GCtr = util.TraceHull( {
			start = missile:GetPos(),
			endpos = posVec ,
			collisiongroup  = COLLISION_GROUP_WORLD,
			mins = Vector(0,0,0),
			maxs = Vector(0,0,0),
			filter = function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end
		})

		if (GCtr.Hit) then
			return {TargetPos = nil}
		end


	end

	self.TargetPos = posVec
	return {TargetPos = posVec, ViewCone = self.ViewCone}

end

function Guidance:GetWireTarget()

	if not IsValid(self.InputSource) then
		return {}
	end

	local outputs = self.InputSource.Outputs

	if not outputs then
		return {}
	end

	local posVec

	for _, name in pairs(self.InputNames) do

		local outTbl = outputs[name]

		if not (outTbl and outTbl.Value) then continue end

		local val = outTbl.Value

		if isvector(val) and (val.x ~= 0 or val.y ~= 0 or val.z ~= 0) then
			posVec = val
			break
		elseif IsEntity(val) and IsValid(val) then
			posVec = val:GetPos()
			break
		end

	end

	return posVec
end

--Another Stupid Workaround. Since guidance degrees are not loaded when ammo is created
function Guidance:GetDisplayConfig(Type)

	local ViewCone = ACE.Weapons.Guns[Type].viewcone * 2 or 0

	return
	{
		["Tracking"] = math.Round(ViewCone, 1) .. " deg"
	}
end

ACE.RegisterGuidance( Guidance.Name, Guidance )