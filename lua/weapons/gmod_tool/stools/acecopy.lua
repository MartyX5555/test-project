TOOL.Category		= "Construction"
TOOL.Name			= "#Tool.acecopy.listname"
TOOL.Author		= "Marty & Looter"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.EntityClass = nil
TOOL.EntityData = {}

-- The Copy tool. Works as a duplicator for creating ents, it can update existent ents too.

TOOL.GetEntityData = {
	ace_gun = function(Ent)
		local Data = {}
		Data.Id = Ent.Id
		Data.EntityColor = Ent:GetColor()
		Data.EntityMaterial = Ent:GetMaterial()
		Data.EntityWireName = Ent:GetNWString( "WireName", "Unknown" )
		return Data
	end,
	ace_rack = function(Ent)
		local Data = {}
		Data.Id = Ent.Id
		Data.EntityColor = Ent:GetColor()
		Data.EntityMaterial = Ent:GetMaterial()
		Data.EntityWireName = Ent:GetNWString( "WireName", "Unknown" )
		return Data
	end,
	ace_ammo = function(Ent)
		local Data = {}
		Data.Id = Ent.Id
		Data.RoundData = Ent.RoundData
		Data.Dimensions = Ent.Dimensions
		Data.EntityColor = Ent:GetColor()
		Data.EntityMaterial = Ent:GetMaterial()
		Data.EntityWireName = Ent:GetNWString( "WireName", "Unknown" )
		return Data
	end,
	ace_engine = function(Ent)
		local Data = {}
		Data.Id = Ent.Id
		Data.EntityColor = Ent:GetColor()
		Data.EntityMaterial = Ent:GetMaterial()
		Data.EntityWireName = Ent:GetNWString( "WireName", "Unknown" )
		return Data
	end,
	ace_gearbox =  function(Ent)
		local Data = {}
		Data.Id = Ent.Id
		Data.GearTable = Ent.GearTable
		Data.FinalDrive = Ent.FinalDrive
		Data.MinRPMTarget = Ent.MinRPMTarget
		Data.MaxRPMTarget = Ent.MaxRPMTarget
		Data.ShiftPoints = Ent.ShiftPoints
		Data.EntityColor = Ent:GetColor()
		Data.EntityMaterial = Ent:GetMaterial()
		Data.EntityWireName = Ent:GetNWString( "WireName", "Unknown" )
		return Data
	end,
	ace_fueltank = function(Ent)
		local Data = {}
		Data.Id = Ent.Id
		Data.SizeId = Ent.SizeId
		Data.FuelType = Ent.FuelType
		Data.Dimensions = Ent.Dimensions
		Data.Shape = Ent.Shape
		Data.EntityColor = Ent:GetColor()
		Data.EntityMaterial = Ent:GetMaterial()
		Data.EntityWireName = Ent:GetNWString( "WireName", "Unknown" )
		return Data
	end,
}


if CLIENT then

	language.Add( "Tool.acecopy.listname", ACETranslation.CopyToolText[1] )
	language.Add( "Tool.acecopy.name", ACETranslation.CopyToolText[2] )
	language.Add( "Tool.acecopy.desc", "Copy, update and create ACE compatible entities." )
	language.Add( "Tool.acecopy.left", "Create/Update an ACE Entity" )
	language.Add( "Tool.acecopy.right", "Copy an ACE entity" )
	language.Add( "Tool.acecopy.reload", "Resets current Data" )

	TOOL.Information = {
		{ name = "left", icon = "gui/lmb.png"},
		{ name = "right", icon = "gui/rmb.png" },
		{ name = "reload", icon = "gui/r.png" },
	}
	--Main menu building
	function TOOL.BuildCPanel( panel )
		panel:Help("#Tool.acecopy.desc")
	end
end

-- Updates or creates new entities based on the copied data.
function TOOL:LeftClick( trace )
	if CLIENT then return true end

	local ent = trace.Entity
	local ply = self:GetOwner()
	local Class = ent:GetClass()
	-- We update the entity only, when the factory update function allows it.
	if IsValid(ent) and Class == self.EntityClass then
		local EntityData = self.EntityData
		local success, msg = ent:Update( ply, EntityData.Id, EntityData )
		if success then
			ent:SetColor(EntityData.EntityColor)
			ent:SetMaterial(EntityData.EntityMaterial)
			ent:SetNWString("WireName", EntityData.EntityWireName)

			duplicator.StoreEntityModifier( ent, "colour", { Color = EntityData.EntityColor, RenderMode = 0, RenderFX = 0 } )
			duplicator.StoreEntityModifier( ent, "material", { MaterialOverride = EntityData.EntityMaterial} )
			duplicator.StoreEntityModifier( ent, "WireName", { name = EntityData.EntityWireName } )
		end
	ACE.SendNotify( ply, success, msg )
	elseif self.GetEntityData[self.EntityClass] then
		local NewEntClass = self.EntityClass
		local DupeClass = duplicator.FindEntityClass( NewEntClass )
		if DupeClass then

			local Pos = trace.HitPos
			local Ang = trace.HitNormal:Angle()
			Ang.pitch = Ang.pitch + 90
			local EntityData = self.EntityData

			-- Using the Duplicator entity register to find the right factory function
			local NewEnt = DupeClass.Func( ply, Pos, Ang, EntityData.Id, EntityData ) --aka function like MakeACE_Ammo
			if not IsValid(NewEnt) then ACE.SendNotify(ply, false, ACETranslation.ACEMenuTool[15]) return false end

			local TruePos = NewEnt:LocalToWorld(Vector(0,0,-NewEnt:OBBMins().z + 1))
			NewEnt:SetPos(TruePos)
			NewEnt:Activate()
			NewEnt:GetPhysicsObject():EnableMotion( false )
			NewEnt:SetColor(EntityData.EntityColor)
			NewEnt:SetMaterial(EntityData.EntityMaterial)
			NewEnt:SetNWString("WireName", EntityData.EntityWireName)

			duplicator.StoreEntityModifier( NewEnt, "colour", { Color = EntityData.EntityColor, RenderMode = 0, RenderFX = 0 } )
			duplicator.StoreEntityModifier( NewEnt, "material", { MaterialOverride = EntityData.EntityMaterial} )
			duplicator.StoreEntityModifier( NewEnt, "WireName", { name = EntityData.EntityWireName } )

			undo.Create( NewEntClass )
				undo.AddEntity( NewEnt )
				undo.SetPlayer( ply )
			undo.Finish()
		else
		ACE.SendNotify(ply, false, ACETranslation.ACEMenuTool[16])
			return false
		end
	end
	return true
end

-- Copies the data
function TOOL:RightClick( trace )
	if CLIENT then return true end

	local ent = trace.Entity
	local ply = self:GetOwner()
	local Class = ent:GetClass()
	local GetEntityData = self.GetEntityData[ent:GetClass()]
	if isfunction(GetEntityData) then
		self.EntityData = GetEntityData(ent)
		self.EntityClass = Class
	ACE.SendNotify( ply, true, "ACE Entity '" .. self.EntityData.EntityWireName .. "' (" .. Class .. ") copied succesfully" )
	end
	return true
end

function TOOL:Reload()
	if CLIENT then return true end
	self.EntityData = {}
	self.EntityClass = nil
end

