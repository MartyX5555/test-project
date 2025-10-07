local ACE = ACE or {}
local Guidance = {}

Guidance.Name = "Wire"
Guidance.desc = "This guidance package is controlled by the launcher, which reads a target-position and steers the munition towards it. Has a limited guidance distance."
Guidance.InputSource = nil -- An entity with a Position wire-output
Guidance.WireLength = 19685	-- Length of the guidance wire		-- about 500m
Guidance.WireSnapped = false -- Disables guidance when true

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

	self.WireSnapped = false
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

	local launcher = self.InputSource

	if not IsValid(launcher) then
		return {}
	end

	local launcherPos = launcher:GetPos()
	local distMsl = missile:GetPos():DistToSqr(launcherPos)		-- We're using squared distance to optimise

	if distMsl > self.WireLength ^ 2 then
		self.WireSnapped = true
		return {TargetPos = nil}
	end


	local posVec = self:GetWireTarget() --print("wire vector:", posVec)

	if not posVec or type(posVec) ~= "Vector" or posVec == Vector() then
		return {TargetPos = nil}
	else
		local distTrgt = posVec:DistToSqr(launcherPos)
		if distMsl > distTrgt then
			return {TargetPos = nil}
		end
	end


	self.TargetPos = posVec
	return {TargetPos = posVec}

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

function Guidance:GetDisplayConfig()
	return {["Wire Length"] = math.Round(self.WireLength / 39.37, 1) .. " m"}
end

ACE.RegisterGuidance( Guidance.Name, Guidance )