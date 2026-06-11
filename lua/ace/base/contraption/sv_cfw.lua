
local ACE = ACE or {}

-------------------------- CFW Massratio Calculation --------------------------
do
	--Key values: con.physicalMass, con.parentedMass & con.totalMass
	local function IsPhysical( ent )
		return not IsValid(ent:GetParent())
	end

	local function CreateData(con)
		con.ace_parentedents = {}
		con.ace_physicalents = {}
		con.ace_massratio = 0
		hook.Run("ACE.CFW.Init", con)
	end

	-- Contraption creation also calls the entityadded hook twice
	hook.Add("cfw.contraption.init", "ACE.PropGroups", CreateData)
	hook.Add("cfw.family.init", "ACE.PropGroups", CreateData)

	local function AddData(con, ent)
		if IsPhysical( ent ) then
			con.ace_physicalents[ent] = true
		else
			con.ace_parentedents[ent] = true
		end
		con.ace_massratio = math.min(con.physicalMass / con.totalMass, 1)

		hook.Run("ACE.CFW.EntityAdded", con, ent)
	end
	hook.Add("cfw.contraption.entityAdded", "ACE.PropGroups", AddData)
	hook.Add("cfw.family.added", "ACE.PropGroups", AddData)

	local function RemoveData(con, ent)
		if IsPhysical( ent ) then
			con.ace_physicalents[ent] = nil
		else
			con.ace_parentedents[ent] = nil
		end
		con.ace_massratio = math.min(con.physicalMass / con.totalMass, 1)

		hook.Run("ACE.CFW.EntityRemoved", con, ent)
	end

	hook.Add("cfw.contraption.entityRemoved", "ACE.PropGroups", RemoveData)
	hook.Add("cfw.family.subbed", "ACE.PropGroups", RemoveData)

	local function MassChanged(con)
		con.ace_massratio = math.min(con.physicalMass / con.totalMass, 1)
	end
	hook.Add("cfw.contraption.massChanged", "ACE.CFW.massChanged", MassChanged)
	hook.Add("cfw.family.massChanged", "ACE.CFW.massChanged", MassChanged)
end



-------------------------- CFW functions --------------------------
do

	local ErrorMsg = "Contraption Framework (CFW) is not installed on the Server. Check ACE meets the required dependencies before using! Aborting..."

	function ACE.GetContraption( ent )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return end
		if not IsEntity(ent) or not IsValid(ent) then return end
		return ent:CFW_GetContraption()
	end

	function ACE.GetContraptionTotalMass( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then return 0 end
		return con.totalMass
	end

	function ACE.GetContraptionPhysicalMass( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then return 0 end
		return con.physicalMass
	end

	function ACE.GetContraptionaParentMass( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then return 0 end
		return con.parentedMass
	end

	function ACE.GetContraptionMassRatio( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then print("doesnt exist") return 0 end
		return con.massratio
	end

end