
--[[
	set up to provide a random, fairly low cost legality check that discourages trying to game legality checking
	with a hard to predict check time and punishing lockout time
	usage:
	Ent.Legal, Ent.LegalIssues = ACF_CheckLegal(Ent, Model, MinMass, MinInertia, NeedsGateParent, CanVisclip )
	Ent.NextLegalCheck = ACF.LegalSettings:NextCheck(Ent.Legal)
]]

ACF = ACF or {}

ACF.Legal = {}
ACF.Legal.Min		= 5	-- min seconds between checks --5
ACF.Legal.Max		= 25	-- max seconds between checks --25
ACF.Legal.Lockout	= 35	-- lockout time on not legal  --35
ACF.Legal.NextCheck  = function(_, Legal) return ACF.CurTime + (Legal and math.random(ACF.Legal.Min, ACF.Legal.Max) or ACF.Legal.Lockout) end


local function IsLegalityActivated()
	return math.max(GetConVar("acf_legalcheck"):GetInt(), 0) > 0
end

local factorycommand = "acf_legal_ignore_"
local function IsRestricted(type)
	local convar = factorycommand .. type
	if not ConVarExists( convar ) then return end
	return  math.max(GetConVar(convar):GetInt(), 0) == 0
end

--[[
	checks if an ent meets the given requirements for legality
	MinInertia needs to be mass normalized (normalized=inertia/mass)
	ballistics doesn't check visclips on anything except prop_physics, so no need to check on acf ents
]]--

do

	local AllowedMaterials = {
		RHA = true,
		CHA = true,
		Alum = true
	}
	local ValidCollisionGroups = {
		[COLLISION_GROUP_NONE] = true,
		[COLLISION_GROUP_WORLD] = true,
		[COLLISION_GROUP_VEHICLE] = true
	}

	--TODO: remove unused functions
	function ACF_CheckLegal(Ent, Model, MinMass, MinInertia, _, CanVisclip )

		local problems = {} --problems table definition
		if not IsLegalityActivated() then return #problems == 0, table.concat(problems, ", ") end

		-- check it exists
		if not ACF_Check( Ent ) then return { Legal = false, Problems = {"Invalid Ent"} } end

		local physobj = Ent:GetPhysicsObject()

		-- check if physics is valid
		if not IsValid(physobj) then return { Legal = false, Problems = {"Invalid Physics"} } end


		-- make sure traces can hit it (fade door, propnotsolid)
		if IsRestricted("solid") and not Ent:IsSolid() then
			table.insert(problems,"Not solid")
		end

		-- check if the model matches
		if Model ~= nil and IsRestricted("model") and Ent:GetModel() ~= Model then
			table.insert(problems,"Wrong model")
		end

		-- check mass
		if not IsRestricted("mass") then

			--Lets assume that input minmass is also rounded like here.
			local CMass = math.Round(physobj:GetMass(),2)

			if MinMass ~= nil and CMass < MinMass then
				table.insert(problems,"Under min mass")
			end

		end

		-- check material
		-- Allowed materials: rha, cast and aluminum
		if IsRestricted("material") then

			local material = Ent.ACF.Material or "RHA"

			if not AllowedMaterials[material] then
				table.insert(problems,"Material not legal")
			end
		end

		-- check inertia components
		if IsRestricted("inertia") and MinInertia ~= nil then
			local inertia = physobj:GetInertia() / physobj:GetMass()
			if (inertia.x < MinInertia.x) or (inertia.y < MinInertia.y) or (inertia.z < MinInertia.z) then
				table.insert(problems,"Under min inertia")
			end
		end

		-- check makesphere
		if IsRestricted("makesphere") and physobj:GetVolume() == nil then
			table.insert(problems,"Has makesphere")
		end

		-- check for clips
		if IsRestricted("visclip") and not CanVisclip and (Ent.ClipData ~= nil) and (#Ent.ClipData > 0) then
			table.insert(problems,"Has visclip")
		end

		-- check for bad collision groups
		if IsRestricted("notsolid") and not ValidCollisionGroups[Ent:GetCollisionGroup()] then
			table.insert(problems, "Bad collision group")
		end

		-- legal if number of problems is 0
		return #problems == 0, table.concat(problems, ", ")

	end
end
