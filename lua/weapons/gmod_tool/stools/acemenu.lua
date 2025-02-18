
TOOL.Category		= "Construction"
TOOL.Name			= "#Tool.acemenu.listname"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar[ "type" ] = "gun"
TOOL.ClientConVar[ "id" ] = "7.62mmMG" --Used by guns and crates (as example)

TOOL.ClientConVar[ "data1" ] = "7.62mmMG"
TOOL.ClientConVar[ "data2" ] = "AP"
TOOL.ClientConVar[ "data3" ] = 0
TOOL.ClientConVar[ "data4" ] = 0
TOOL.ClientConVar[ "data5" ] = 0
TOOL.ClientConVar[ "data6" ] = 0
TOOL.ClientConVar[ "data7" ] = 0
TOOL.ClientConVar[ "data8" ] = 0
TOOL.ClientConVar[ "data9" ] = 0
TOOL.ClientConVar[ "data10" ] = 0
TOOL.ClientConVar[ "data11" ] = 0
TOOL.ClientConVar[ "data12" ] = 0
TOOL.ClientConVar[ "data13" ] = 0
TOOL.ClientConVar[ "data14" ] = 0
TOOL.ClientConVar[ "data15" ] = 0

TOOL.SelectedEntities = {}

cleanup.Register( "acfmenu" )

if CLIENT then
	language.Add( "Tool.acemenu.listname", ACFTranslation.ACFMenuTool[1] )
	language.Add( "Tool.acemenu.name", ACFTranslation.ACFMenuTool[2] )
	language.Add( "Tool.acemenu.desc", ACFTranslation.ACFMenuTool[3] )
	language.Add( "Tool.acemenu.0", ACFTranslation.ACFMenuTool[4] )
	language.Add( "Tool.acemenu.1", ACFTranslation.ACFMenuTool[5] )

	language.Add( "Undone_ACF Entity", ACFTranslation.ACFMenuTool[6] )
	language.Add( "Undone_acf_engine",ACFTranslation.ACFMenuTool[7] )
	language.Add( "Undone_acf_gearbox", ACFTranslation.ACFMenuTool[8] )
	language.Add( "Undone_acf_ammo", ACFTranslation.ACFMenuTool[9] )
	language.Add( "Undone_acf_gun", ACFTranslation.ACFMenuTool[10] )
	language.Add( "SBoxLimit_acf_gun", ACFTranslation.ACFMenuTool[11] )
	language.Add( "SBoxLimit_acf_rack", ACFTranslation.ACFMenuTool[12] )
	language.Add( "SBoxLimit_acf_ammo", ACFTranslation.ACFMenuTool[13] )
	language.Add( "SBoxLimit_acf_sensor", ACFTranslation.ACFMenuTool[14] )

	-- These still need translations, hardcoding as english for now
	language.Add("tool.acemenu.left", "Create/Update entity")
	language.Add("tool.acemenu.right", "Link/Unlink entities")

	language.Add("tool.acemenu.stage1.link", "Link selected entities to this entity")
	language.Add("tool.acemenu.stage1.unlink", "(Hold Use) Unlink selected entities from this entity")
	language.Add("tool.acemenu.stage1.multiselect", "(Hold Shift) Select more entities")
	language.Add("tool.acemenu.stage1.reload", "Deselect all entities")

	TOOL.Information = {
		{ name = "left", stage = 0 },
		{ name = "right", stage = 0 },

		{ name = "stage1.link", stage = 1, icon = "gui/rmb.png" },
		{ name = "stage1.unlink", stage = 1, icon = "gui/rmb.png", icon2 = "gui/info" },
		{ name = "stage1.multiselect", icon = "gui/rmb.png", icon2 = "gui/info", stage = 1 },
		{ name = "stage1.reload", stage = 1, icon = "gui/r.png" }
	}

	--[[------------------------------------
		BuildCPanel
	--------------------------------------]]
	function TOOL.BuildCPanel( CPanel )

		local pnldef_ACFmenu = vgui.RegisterFile( "acf/base/vgui/cl_acemenu_gui.lua" )

		-- create
		local DPanel = vgui.CreateFromTable( pnldef_ACFmenu )
		CPanel:AddPanel( DPanel )

	end
end

-- Spawn/update functions
function TOOL:LeftClick( trace )

	if CLIENT then return true end
	if not IsValid( trace.Entity ) and not trace.Entity:IsWorld() then return false end

	local ply	= self:GetOwner()
	local Type	= self:GetClientInfo( "type" )
	local Id	= self:GetClientInfo( "id" )
	local entClass

	local TypeId = ACE.Weapons[Type][Id]

	if not TypeId then
		if Type == "Ammo" then
			entClass = "acf_ammo"
		elseif Type == "FuelTanks" then
			entClass = "acf_fueltanks"
		end
	else
		entClass = TypeId["ent"]
	end

	local DupeClass = duplicator.FindEntityClass( entClass )

	if DupeClass then

		local ArgTable = {}
		ArgTable[2] = trace.HitNormal:Angle():Up():Angle()
		ArgTable[1] = trace.HitPos + trace.HitNormal * 50

		debugoverlay.Cross(trace.HitPos, 5, 5, Color(255,0,0), true)
		debugoverlay.Cross(ArgTable[1], 5, 5, Color(255,0,0), true)

		local ArgList = list.Get("ACFCvars")

		-- Reading the list packaged with the ent to see what client CVar it needs
		for Number, Key in pairs( ArgList[entClass] ) do
			ArgTable[ Number + 2 ] = self:GetClientInfo( Key )
		end

		if trace.Entity:GetClass() == entClass and trace.Entity.CanUpdate then
			table.insert( ArgTable, 1, ply )
			local success, msg = trace.Entity:Update( ArgTable )
			ACE_SendNotify( ply, success, msg )
		else
			-- Using the Duplicator entity register to find the right factory function
			local Ent = DupeClass.Func( ply, unpack( ArgTable ) ) --aka function like MakeACE_Ammo
			if not IsValid(Ent) then ACE_SendNotify(ply, false, ACFTranslation.ACFMenuTool[15]) return false end

			Ent:Activate()
			Ent:DropToFloor()
			Ent:GetPhysicsObject():EnableMotion( false )

			undo.Create( entClass )
				undo.AddEntity( Ent )
				undo.SetPlayer( ply )
			undo.Finish()
		end

		return true
	else
		print(ACFTranslation.ACFMenuTool[16])
	end

end

function TOOL:SelectEntity(ent)
	if CLIENT then return end

	if not self.SelectedEntities[ent] then
		self.SelectedEntities[ent] = ent:GetColor()
		ent:SetColor(Color(0, 255, 0))
	else
		ent:SetColor(self.SelectedEntities[ent])
		self.SelectedEntities[ent] = nil
	end
end

function TOOL:DeselectAll()
	if CLIENT then return end

	for ent, color in pairs(self.SelectedEntities) do
		if IsValid(ent) then
			ent:SetColor(color)
		end

		self.SelectedEntities[ent] = nil
	end
end

local function linkEnts(e1, e2, unlink)
	if e1.IsMaster and e2:GetClass() ~= "acf_engine" and (e1:GetClass() ~= "acf_gearbox" or e2:GetClass() ~= "acf_gearbox") then
		if unlink then
			return e1:Unlink(e2)
		else
			return e1:Link(e2)
		end
	elseif e2.IsMaster then
		if unlink then
			return e2:Unlink(e1)
		else
			return e2:Link(e1)
		end
	else
		return false, "Neither entity is a master entity"
	end
end

function TOOL:RightClick( trace )
	local ent = trace.Entity
	local ply = self:GetOwner()
	local validEnt = IsValid(ent)
	local stage = self:GetStage()

	if validEnt and stage == 0 then
		self:SelectEntity(ent)
		self:SetStage(1)

		return true
	elseif stage == 1 then
		if not validEnt then
			self:DeselectAll()
			self:SetStage(0)

			return true
		end

		local holdingShift = ply:KeyDown(IN_SPEED)
		local holdingUse = ply:KeyDown(IN_USE)

		if holdingShift then
			if validEnt then
				self:SelectEntity(ent)
			end

			return true
		else
			if SERVER then
				for selected in pairs(self.SelectedEntities) do
					if ent ~= selected and validEnt and IsValid(selected) then
						local success, msg = linkEnts(ent, selected, holdingUse)

						ACE_SendNotify(ply, success, msg)
					end
				end
			end

			self:DeselectAll()
			self:SetStage(0)

			return true
		end
	end
end

function TOOL:Holster()
	self:SetStage(0)
	self:DeselectAll()
end

function TOOL:Reload()
	self:SetStage(0)
	self:DeselectAll()

	return self:GetStage() == 1
end