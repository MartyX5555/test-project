--TODO: merge this file with cl_acemenu_gui.lua since having 2 files for the same function is irrevelant. Little transition has been made though

local ACFEnts = ACE.Weapons

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

		local default = "Dumb"	-- Dumb is the only acceptable default
		if not acemenupanel.CData.GuidanceSelect then
			acemenupanel.CData.GuidanceSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			acemenupanel.CData.GuidanceSelect:SetSize(100, 30)

			acemenupanel.CData.GuidanceSelect.OnSelect = function( _ , _ , data )
				RunConsoleCommand( "acemenu_data7", data )

				local gun = {}

				local gunId = acemenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACE.Weapons.Guns
					gun = guns[gunId]
				end

				local guidance = ACE.Guidance[data]
				if guidance and guidance.desc then
					acemenupanel:CPanelText("GuidanceDesc", guidance.desc .. "\n")

					local configPanel = ACFMissiles_CreateMenuConfiguration(guidance, acemenupanel.CData.GuidanceSelect, "acemenu_data7", acemenupanel.CData.GuidanceSelect.ConfigPanel, gun)
					acemenupanel.CData.GuidanceSelect.ConfigPanel = configPanel
				else
					acemenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")
				end
			end

			acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.GuidanceSelect )

			acemenupanel:CPanelText("GuidanceDesc", "Missiles and bombs can be given a guidance package to steer them during flight.\n")

			local configPanel = vgui.Create("DScrollPanel")
			acemenupanel.CData.GuidanceSelect.ConfigPanel = configPanel
			acemenupanel.CustomDisplay:AddItem( configPanel )

		else
			--acemenupanel.CData.GuidanceSelect:SetSize(100, 30)
			default = acemenupanel.CData.GuidanceSelect:GetValue()
			acemenupanel.CData.GuidanceSelect:SetVisible(true)
		end

		acemenupanel.CData.GuidanceSelect:Clear()
		for _, Value in pairs( gundata.guidance or {} ) do
			acemenupanel.CData.GuidanceSelect:AddChoice( Value, Value, Value == default )
		end


		-- Create fuse selection combobox + description label

		default = "Contact"  -- Contact is the only acceptable default
		if not acemenupanel.CData.FuseSelect then
			acemenupanel.CData.FuseSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			acemenupanel.CData.FuseSelect:SetSize(100, 30)

			acemenupanel.CData.FuseSelect.OnSelect = function( _ , _ , data )

				local gun = {}

				local gunId = acemenupanel.CData.CaliberSelect:GetValue()
				if gunId then
					local guns = ACE.Weapons.Guns
					gun = guns[gunId]
				end

				local fuse = ACE.Fuse[data]

				if fuse and fuse.desc then
					acemenupanel:CPanelText("FuseDesc", fuse.desc .. "\n")

					local configPanel = ACFMissiles_CreateMenuConfiguration(fuse, acemenupanel.CData.FuseSelect, "acemenu_data8", acemenupanel.CData.FuseSelect.ConfigPanel, gun)
					acemenupanel.CData.FuseSelect.ConfigPanel = configPanel
				else
					acemenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")
				end

				ACFMissiles_SetCommand(acemenupanel.CData.FuseSelect, acemenupanel.CData.FuseSelect.ControlGroup, "acemenu_data8")
			end

			acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.FuseSelect )

			acemenupanel:CPanelText("FuseDesc", "Missiles and bombs can be given a fuse to control when they detonate.\n")

			local configPanel = vgui.Create("DScrollPanel")
			configPanel:SetTall(0)
			acemenupanel.CData.FuseSelect.ConfigPanel = configPanel
			acemenupanel.CustomDisplay:AddItem( configPanel )
		else
			--acemenupanel.CData.FuseSelect:SetSize(100, 30)
			default = acemenupanel.CData.FuseSelect:GetValue()
			acemenupanel.CData.FuseSelect:SetVisible(true)
		end

		acemenupanel.CData.FuseSelect:Clear()
		for _, Value in pairs( gundata.fuses or {} ) do
			acemenupanel.CData.FuseSelect:AddChoice( Value, Value, Value == default ) -- Contact is the only acceptable default
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
		acemenupanel.CData.RackSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
		acemenupanel.CData.RackSelect:SetSize(100, 30)

		acemenupanel.CData.RackSelect.OnSelect = function( _ , _ , data )
			RunConsoleCommand( "acemenu_data9", data )

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

		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.RackSelect )

		local configPanel = vgui.Create("DScrollPanel")
		acemenupanel.CData.RackSelect.ConfigPanel = configPanel
		acemenupanel.CustomDisplay:AddItem( configPanel )

	else
		default = acemenupanel.CData.RackSelect:GetValue()
		acemenupanel.CData.RackSelect:SetVisible(true)
	end

	acemenupanel.CData.RackSelect:Clear()

	local default = node.mytable.rack
	for _, Value in pairs( ACE_GetCompatibleRacks(node.mytable.id) ) do
		acemenupanel.CData.RackSelect:AddChoice( Value, Value, Value == default )
	end


end




function ModifyACFMenu(panel)

	oldAmmoSelect = oldAmmoSelect or panel.AmmoSelect

	panel.AmmoSelect = function(panel, blacklist)

		oldAmmoSelect(panel, blacklist)

		acemenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , data )
			acemenupanel.AmmoData["Data"] = ACFEnts["Guns"][data]["round"]
			acemenupanel:UpdateAttribs()
			acemenupanel:UpdateAttribs()	--Note : this is intentional

			local gunTbl = ACFEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACE.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acemenupanel, Classes.GunClass[class].type == "missile", gunTbl ) end)
		end

		local data = acemenupanel.CData.CaliberSelect:GetValue()
		if data then
			local gunTbl = ACFEnts["Guns"][data]
			local class = gunTbl.gunclass

			local Classes = ACE.Classes
			timer.Simple(0.01, function() SetMissileGUIEnabled( acemenupanel, Classes.GunClass[class].type == "missile", gunTbl) end)
		end

	end

	local rootNodes = HomeNode.ChildNodes:GetChildren()  --lets find all our folder inside of Main menu

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

function FindACFMenuPanel()
	if acemenupanel then
		ModifyACFMenu(acemenupanel)
		timer.Remove("FindACFMenuPanel")
	end
end




timer.Create("FindACFMenuPanel", 0.1, 0, FindACFMenuPanel)
