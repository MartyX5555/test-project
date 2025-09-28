
local ACE = ACE or {}

-------------------------- CFW Massratio Calculation --------------------------
do

	local HasConstraints = constraint.HasConstraints

	local function IsPhysical( ent )
		return HasConstraints( ent ) or not IsValid(ent:GetParent())
	end

	-- Contraption creation also calls the entityadded hook twice
	hook.Add("cfw.contraption.created", "ACE.PropGroups", function(con)
		con.aceparenttotal = 0 -- Parent ent count
		con.acephystotal = 0 -- Constraint ent count. It could contain parent-constrained props

		con.parented = {}
		con.physical = {}
		con.massratio = 0
		con.totalmass = 0 -- i know, i know
		hook.Run("ACE.CFW.ContraptionCreated", con)
	end)

	hook.Add("cfw.contraption.entityAdded", "ACE.PropGroups", function(con, ent)
		local physObj = ent:GetPhysicsObject()
		if IsValid(physObj) then

			local mass = physObj:GetMass()
			ent.acemass = mass

			con.totalmass = con.totalmass + mass --print("ADDMASS", con.totalmass)

			if IsPhysical( ent ) then
				con.physical[ent] = true
				con.acephystotal = con.acephystotal + mass
			else
				con.parented[ent] = true
			end
			con.aceparenttotal = con.totalmass - con.acephystotal
			con.massratio = math.min(con.acephystotal / con.totalmass, 1)
		end

		hook.Run("ACE.CFW.EntityAdded", con, ent)
	end)

	hook.Add("cfw.contraption.entityRemoved", "ACE.PropGroups", function(con, ent)
		local physObj = ent:GetPhysicsObject()
		if IsValid(physObj) then
			local mass = physObj:GetMass()

			con.totalmass = con.totalmass - mass

			if IsPhysical( ent ) then
				con.physical[ent] = nil
				con.acephystotal = con.acephystotal - mass
			else
				con.parented[ent] = nil
			end
			con.aceparenttotal = con.totalmass - con.acephystotal
			con.massratio = math.min(con.acephystotal / con.totalmass, 1)
		end

		hook.Run("ACE.CFW.EntityRemoved", con, ent)
	end)

	local PHYSOBJ = FindMetaTable("PhysObj")
	if not PHYSOBJ.LegacySetMass then
		PHYSOBJ.LegacySetMass = PHYSOBJ.SetMass
	end
	function PHYSOBJ:SetMass(mass, ...)
		timer.Simple(0,function()
			if not IsValid(self) then return end
			local ent = self:GetEntity()

			local oldmass = ent.acemass or 0 --print("mass:", mass, "oldmass:", oldmass, "physmass")

			if oldmass == 0 then return end
			ent.acemass = mass

			local con = ACE.GetContraption(ent)
			if con then

				con.totalmass = con.totalmass + (mass - oldmass) --print("SetMass ADDMASS", con.totalmass) print("operation!!!!")

				if IsPhysical( ent ) then
					--print("physical mass change!!!")
					con.acephystotal = con.acephystotal + (mass - oldmass)
				end

				con.aceparenttotal = con.totalmass - con.acephystotal
				con.massratio = math.min(con.acephystotal / con.totalmass, 1)

				--print("totalmass:", con.totalmass, con.acephystotal, con.aceparenttotal )
				--print("originalmass:", con.totalMass)
			end
		end)
		self:LegacySetMass(mass, ...)
	end

end



-------------------------- CFW functions --------------------------
do

	local ErrorMsg = "Contraption Framework (CFW) is not installed on the Server. Check ACE meets the required dependencies before using! Aborting..."

	function ACE.GetContraption( ent )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return end
		if not IsEntity(ent) or not IsValid(ent) then return end
		return ent:GetContraption()
	end

	function ACE.GetContraptionaceTotalMass( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then return 0 end
		return con.totalmass
	end

	function ACE.GetContraptionPhysicalMass( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then return 0 end
		return con.acephystotal
	end

	function ACE.GetContraptionaceparentotal( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then return 0 end
		return con.aceparenttotal
	end

	function ACE.GetContraptionMassRatio( con )
		if not CFW then ErrorNoHaltWithStack(ErrorMsg) return 0 end
		if not con then print("doesnt exist") return 0 end
		return con.massratio
	end

end