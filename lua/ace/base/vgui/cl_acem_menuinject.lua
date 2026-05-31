--TODO: merge this file with cl_acemenu_gui.lua since having 2 files for the same function is irrevelant. Little transition has been made though

local ACEEnts = ACE.Weapons

function SetMissileGUIEnabled(_, enabled, gundata)

	if enabled then

		-- Create guidance selection combobox + description label

		if not acemenupanel.CData.MissileSpacer then
			local spacer = vgui.Create("DPanel")
			spacer:SetSize(24, 24)
			spacer.Paint = function() end
			acemenupanel.CData.MissileSpacer = spacer

			acemenupanel.CustomDisplay:AddItem(spacer)
		end

		local Current_Guidance = "Dumb"	-- Dumb is the only acceptable default
		if not acemenupanel.CData.GuidanceSelect then
			local GuidanceSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			GuidanceSelect:SetSize(100, 30)

			function GuidanceSelect:OnSelect( _ , _ , data )
				ACE.MenuSendTableValue("Data", "RoundData", "Guidance", data)

				local gun = {}

				local gunId = acemenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACE.Weapons.Guns
					gun = guns[gunId]
				end

				local guidance = ACE.Guidance[data]
				if guidance and guidance.desc then
					acemenupanel:CPanelText("GuidanceDesc", guidance.desc .. "\n")

					local configPanel = ACFMissiles_CreateMenuConfiguration(guidance, self, "Guidance", self.ConfigPanel, gun)
					self.ConfigPanel = configPanel
				else
					acemenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")
				end
			end

			acemenupanel.CustomDisplay:AddItem( GuidanceSelect )

			acemenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")

			local configPanel = vgui.Create("DScrollPanel")
			GuidanceSelect.ConfigPanel = configPanel
			acemenupanel.CData.GuidanceSelect = GuidanceSelect
			acemenupanel.CustomDisplay:AddItem( configPanel )

		else
			Current_Guidance = acemenupanel.CData.GuidanceSelect:GetValue()
			acemenupanel.CData.GuidanceSelect:SetVisible(true)
		end

		acemenupanel.CData.GuidanceSelect:Clear()
		for _, Value in pairs( gundata.guidance or {} ) do
			acemenupanel.CData.GuidanceSelect:AddChoice( Value, Value, Value == Current_Guidance )
		end

		-- Create fuse selection combobox + description label

		local Current_Fuse = "Contact"  -- Contact is the only acceptable default
		if not acemenupanel.CData.FuseSelect then
			local FuseSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			FuseSelect:SetSize(100, 30)

			function FuseSelect:OnSelect( _ , _ , data )

				local gun = {}

				local gunId = acemenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACE.Weapons.Guns
					gun = guns[gunId]
				end

				local fuse = ACE.Fuse[data]

				if fuse and fuse.desc then
					acemenupanel:CPanelText("FuseDesc", fuse.desc .. "\n")

					local configPanel = ACFMissiles_CreateMenuConfiguration(fuse, self, "Fuse", self.ConfigPanel, gun)
					self.ConfigPanel = configPanel
				else
					acemenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")
				end

				ACFMissiles_SetCommand(FuseSelect, FuseSelect.ControlGroup, "Fuse")
			end

			acemenupanel.CustomDisplay:AddItem( FuseSelect )

			acemenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")

			local configPanel = vgui.Create("DScrollPanel")
			configPanel:SetTall(0)
			FuseSelect.ConfigPanel = configPanel
			acemenupanel.CData.FuseSelect = FuseSelect
			acemenupanel.CustomDisplay:AddItem( configPanel )
		else
			--acemenupanel.CData.FuseSelect:SetSize(100, 30)
			Current_Fuse = acemenupanel.CData.FuseSelect:GetValue()
			acemenupanel.CData.FuseSelect:SetVisible(true)
		end

		acemenupanel.CData.FuseSelect:Clear()
		for _, Value in pairs( gundata.fuses or {} ) do
			acemenupanel.CData.FuseSelect:AddChoice( Value, Value, Value == Current_Fuse ) -- Contact is the only acceptable default
		end

	else

		-- Delete everything!  Tried just making them invisible but they seem to break.

		if acemenupanel.CData.MissileSpacer then
			acemenupanel.CData.MissileSpacer:Remove()
			acemenupanel.CData.MissileSpacer = nil
		end


		if acemenupanel.CData.GuidanceSelect then

			if acemenupanel.CData.GuidanceSelect.ConfigPanel then
				acemenupanel.CData.GuidanceSelect.ConfigPanel:Remove()
				acemenupanel.CData.GuidanceSelect.ConfigPanel = nil
			end

			acemenupanel.CData.GuidanceSelect:Remove()
			acemenupanel.CData.GuidanceSelect = nil
		end

		if acemenupanel.CData.GuidanceDesc_text then
			acemenupanel.CData.GuidanceDesc_text:Remove()
			acemenupanel.CData.GuidanceDesc_text = nil
		end


		if acemenupanel.CData.FuseSelect then

			if acemenupanel.CData.FuseSelect.ConfigPanel then
				acemenupanel.CData.FuseSelect.ConfigPanel:Remove()
				acemenupanel.CData.FuseSelect.ConfigPanel = nil
			end

			acemenupanel.CData.FuseSelect:Remove()
			acemenupanel.CData.FuseSelect = nil
		end

		if acemenupanel.CData.FuseDesc_text then
			acemenupanel.CData.FuseDesc_text:Remove()
			acemenupanel.CData.FuseDesc_text = nil
		end

	end

end




function CreateRackSelectGUI(node)

	local Current_Rack = node.mytable.rack
	if not acemenupanel.CData.MissileSpacer then
		local spacer = vgui.Create("DPanel")
		spacer:SetSize(24, 24)
		spacer.Paint = function() end
		acemenupanel.CData.MissileSpacer = spacer

		acemenupanel.CustomDisplay:AddItem(spacer)
	end

	if not acemenupanel.CData.RackSelect then

		acemenupanel:CPanelText("RackChooseMsg", "Choose the desired rack below")

		--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
		local RackSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
		RackSelect:SetSize(100, 30)

		function RackSelect:OnSelect( _ , _ , data )
			ACE.MenuSendValue( "Global", "Type", "Racks") -- Simple hack to tell the ace menu to look for racks and not guns this time.
			ACE.MenuSendValue( "Global", "Id", data)

			local rack = ACE.Weapons.Racks[data]

			if rack then
				if not acemenupanel.CData.RackModel then
					acemenupanel.CData.RackModel = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
					acemenupanel.CData.RackModel:SetModel( rack.model or "models/props_c17/FurnitureToilet001a.mdl" )
					acemenupanel.CData.RackModel:SetCamPos( Vector( 250, 500, 250 ) )
					acemenupanel.CData.RackModel:SetLookAt( Vector( 0, 0, 0 ) )
					acemenupanel.CData.RackModel:SetFOV( 20 )
					acemenupanel.CData.RackModel:SetSize(acemenupanel:GetWide() / 3,acemenupanel:GetWide() / 3)
					acemenupanel.CData.RackModel.LayoutEntity = function() end
					acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.RackModel )
				else
					acemenupanel.CData.RackModel:SetModel( rack.model )
				end

				acemenupanel:CPanelText("RackTitle", rack.name or "Missing Name","DermaDefaultBold")
				acemenupanel:CPanelText("RackDesc", (rack.desc or "Missing Desc") .. "\n")

				acemenupanel:CPanelText("RackEweight", "Weight when empty : " .. (rack.weight or "Missing weight") .. "kg")
				acemenupanel:CPanelText("RackFweight", "Weight when fully loaded : " .. ( (rack.weight or 0) + (table.Count(rack.mountpoints) * node.mytable.weight) ) .. "kg")
				acemenupanel:CPanelText("Rack_Year", "Year : " .. rack.year .. "\n")
			end
		end
		--ACE.MenuSendValue( "Global", "Id", Table.id)

		acemenupanel.CustomDisplay:AddItem( RackSelect )

		local configPanel = vgui.Create("DScrollPanel")
		RackSelect.ConfigPanel = configPanel
		acemenupanel.CData.RackSelect = RackSelect
		acemenupanel.CustomDisplay:AddItem( configPanel )

	else
		Current_Rack = acemenupanel.CData.RackSelect:GetValue()
		acemenupanel.CData.RackSelect:SetVisible(true)
	end

	acemenupanel.CData.RackSelect:Clear()
	for _, Value in pairs( ACE.GetCompatibleRacks(node.mytable.id) ) do
		acemenupanel.CData.RackSelect:AddChoice( Value, Value, Value == Current_Rack )
	end
end




function ModifyACFMenu(panel)

	oldAmmoSelect = oldAmmoSelect or panel.AmmoSelect

	panel.AmmoSelect = function(panel, blacklist)

		oldAmmoSelect(panel, blacklist)

		acemenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , data )
			acemenupanel.AmmoData["Data"] = ACEEnts["Guns"][data]["round"]
			acemenupanel:UpdateAttribs()
			acemenupanel:UpdateAttribs()	--Note : this is intentional

			local gunTbl = ACEEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACE.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acemenupanel, Classes.GunClass[class].type == "missile", gunTbl ) end)
		end

		local data = acemenupanel.CData.CaliberSelect:GetValue()
		if data then
			local gunTbl = ACEEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACE.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acemenupanel, Classes.GunClass[class].type == "missile", gunTbl) end)
		end

	end

	local rootNodes = acemenupanel.HomeNode.ChildNodes:GetChildren()  --lets find all our folder inside of Main menu

	local gunsNode

	for _, node in pairs(rootNodes) do -- iterating though found folders

		if node:GetText() == "Missiles" then	--Missile folder is the one that we need
			gunsNode = node
			break
		end
	end

	if gunsNode then
		local classNodes = gunsNode.ChildNodes:GetChildren()
		local gunClasses = ACE.Classes.GunClass

		for _, node in pairs(classNodes) do
			local gunNodeElement = node.ChildNodes

			if gunNodeElement then
				local gunNodes = gunNodeElement:GetChildren()

				for _, gun in pairs(gunNodes) do
					local class = gunClasses[gun.mytable.gunclass]

					if (class and class.type == "missile") and not gun.ACFMOverridden then
						local oldclick = gun.DoClick

						gun.DoClick = function(self)
							oldclick(self)
							CreateRackSelectGUI(self)
						end

						gun.ACFMOverridden = true
					end
				end
			else
				ErrorNoHalt("ACEM: Unable to find guns for class " .. node:GetText() .. ".\n")
			end
		end
	else
		ErrorNoHalt("ACEM: Unable to find the ACF Guns node.")
	end

end

hook.Add("ACE_PostMenuLoad", "ACE_MissileModifications", function()
	if not acemenupanel then ErrorNoHalt("ACE Menu didnt initialize properly. This should not happen!!!") return end
	ModifyACFMenu(acemenupanel)
end)