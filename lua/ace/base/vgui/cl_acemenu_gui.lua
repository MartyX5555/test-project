
--[[------------------------
	1.- This is the file that displays the main menu, such as guns, ammo, mobility and subfolders.

	2.- Almost everything here has been documented, you should find the responsible function easily.

	3.- If you are going to do changes, please not to be a shitnuckle and write a note alongside the code that you´ve changed/edited. This should avoid issues with future developers.

]]--------------------------

local Classes = ACE.Classes
local ACEEnts = ACE.Weapons

local radarClasses    = Classes.Radar
local radars          = ACEEnts.Radars

local MainMenuIcon = "icon16/world.png"
local ItemIcon = "icon16/brick.png"
local ItemIcon2 = "icon16/newspaper.png"

local function AmmoBuildList( ParentNode, NodeName, AmmoTable )

	local AmmoNode = ParentNode:AddNode( NodeName, ItemIcon )

	table.sort(AmmoTable, function(a,b) return a.id < b.id end )

	for _,AmmoTable in pairs(AmmoTable) do

		local EndNode = AmmoNode:AddNode( AmmoTable.name or "No Name", ItemIcon2 )
		EndNode.mytable = AmmoTable

		function EndNode:DoClick()
			acemenupanel:UpdateDisplay( self.mytable )
			ACE.MenuSendValue( "Global", "Type", self.mytable.type)
		end
	end
end

PANEL = PANEL or {}

function PANEL:Init()

	acemenupanel = self.Panel

	-- -- height
	self:SetTall( ScrH() - 150 )

	-- --Weapon Select
	local TreePanel = vgui.Create( "DTree", self )

	-- --Table Distribution
	local GunClasses		= {}
	local MisClasses		= {}
	local ModClasses		= {}

	for ID,Table in pairs(Classes) do

		GunClasses[ID] = {}
		MisClasses[ID] = {}
		ModClasses[ID] = {}

		for ClassID,Class in pairs(Table) do

			Class.id = ClassID

			--Table content for Guns folder
			if Class.type == "Gun" then

				table.insert(GunClasses[ID], Class)
			--Table content for Missiles folder
			elseif Class.type == "missile" then

				table.insert(MisClasses[ID], Class)
			else

				table.insert(ModClasses[ID], Class)
			end

		end

		table.sort(GunClasses[ID], function(a,b) return a.id < b.id end )
		table.sort(MisClasses[ID], function(a,b) return a.id < b.id end )
		table.sort(ModClasses[ID], function(a,b) return a.id < b.id end )

	end

	local FinalContainer = {}
	for ID,Table in pairs(ACEEnts) do

		FinalContainer[ID] = {}

		for _,Data in pairs(Table) do
			table.insert( FinalContainer[ID], Data )
		end

		if ID == "Guns" then
			table.sort(FinalContainer[ID], function(a,b) if a.gunclass == b.gunclass then return a.caliber < b.caliber else return a.gunclass < b.gunclass end end)
		else
			table.sort(FinalContainer[ID], function(a,b) return a.id < b.id end )
		end

	end


	------------------- ACE information folder -------------------

	local HomeNode = TreePanel:AddNode( "ACE Main Menu" , MainMenuIcon ) --Main Menu folder
	HomeNode:SetExpanded(true)

	HomeNode.mytable = {}
	HomeNode.mytable.guicreate = (function( _, Table ) ACFHomeGUICreate( Table ) end or nil)
	HomeNode.mytable.guiupdate = (function( _, Table ) ACFHomeGUIUpdate( Table ) end or nil)
	timer.Simple(0.1, function() HomeNode:DoClick() end) --Select the main menu on menu open

	function HomeNode:DoClick()
		acemenupanel:UpdateDisplay(self.mytable)
	end

	acemenupanel.HomeNode = HomeNode

	------------------- Guns folder -------------------

	local Guns = HomeNode:AddNode( "Guns" , "icon16/attach.png" ) --Guns folder

	for _,Class in pairs(GunClasses["GunClass"]) do

		local SubNode = Guns:AddNode( Class.name or "No Name" , ItemIcon )

		for _, Ent in pairs(FinalContainer["Guns"]) do
			if Ent.gunclass == Class.id then

				local EndNode = SubNode:AddNode( Ent.name or "No Name", "icon16/newspaper.png")
				EndNode.mytable = Ent

				function EndNode:DoClick()
					acemenupanel:UpdateDisplay( self.mytable )
					ACE.MenuSendValue( "Global", "Type", self.mytable.type)
				end
			end
		end
	end

	------------------- Missiles folder -------------------

	local Missiles = HomeNode:AddNode( "Missiles" , "icon16/wand.png" ) --Missiles folder

	for _,Class in pairs(MisClasses["GunClass"]) do

		local SubNode = Missiles:AddNode( Class.name or "No Name" , ItemIcon )

		for _, Ent in pairs(FinalContainer["Guns"]) do
			if Ent.gunclass == Class.id then

				local EndNode = SubNode:AddNode( Ent.name or "No Name", "icon16/newspaper.png")
				EndNode.mytable = Ent

				function EndNode:DoClick()
					acemenupanel:UpdateDisplay( self.mytable )
					ACE.MenuSendValue( "Global", "Type", self.mytable.type )
				end
			end
		end
	end


	------------------- Ammo folder -------------------

	local Ammo = HomeNode:AddNode( "Ammo" , "icon16/box.png" ) --Ammo folder

	AmmoBuildList( Ammo, "Armor Piercing Rounds", list.Get("APRoundTypes") ) -- AP Content
	AmmoBuildList( Ammo, "High Explosive Rounds", list.Get("HERoundTypes") )	-- HE/HEAT Content
	AmmoBuildList( Ammo, "Special Purpose Rounds", list.Get("SPECSRoundTypes") ) -- Special Content

	do
		--[[==================================================
							Mobility folder
		]]--==================================================

		local Mobility    = HomeNode:AddNode( "Mobility" , "icon16/car.png" )	--Mobility folder
		local Engines     = Mobility:AddNode( "Engines" , ItemIcon )
		local Gearboxes   = Mobility:AddNode( "Gearboxes" , ItemIcon  )
		local FuelTanks   = Mobility:AddNode( "Fuel Tanks" , ItemIcon  )

		local EngineCatNodes    = {} --Stores all Engine Cats Nodes (V12, V8, I4, etc)
		local GearboxCatNodes   = {} --Stores all Gearbox Cats Nodes (CVT, Transfer, etc)

		-------------------- Engine folder --------------------

		--TODO: Do a menu like fueltanks to engines & gearboxes? Would be cleaner.

		--Creates the engine category
		for _, EngineData in pairs(FinalContainer["Engines"]) do

			local category = EngineData.category or "Missing Cat?"

			if not EngineCatNodes[category] then

				local Node = Engines:AddNode(category , ItemIcon)
				EngineCatNodes[category] = Node
			end
		end

		--Populates engine categories
		for _, EngineData in pairs(FinalContainer["Engines"]) do

			local name = EngineData.name or "Missing Name"
			local category = EngineData.category or ""

			if EngineCatNodes[category] then
				local Item = EngineCatNodes[category]:AddNode( name, ItemIcon )

				function Item:DoClick()
					acemenupanel:UpdateDisplay( EngineData )
					ACE.MenuSendValue( "Global", "Type", EngineData.type )
				end
			end
		end

		-------------------- Gearbox folder --------------------

		--Creates the gearbox category
		for _, GearboxData in pairs(FinalContainer["Gearboxes"]) do

			local category = GearboxData.category

			if not GearboxCatNodes[category] then

				local Node = Gearboxes:AddNode(category or "Missing?" , ItemIcon)
				GearboxCatNodes[category] = Node
			end
		end

		--Populates gearbox categories
		for _, GearboxData in pairs(FinalContainer["Gearboxes"]) do

			local name = GearboxData.name or "Missing Name"
			local category = GearboxData.category or ""

			if GearboxCatNodes[category] then
				local Item = GearboxCatNodes[category]:AddNode( name, ItemIcon )

				function Item:DoClick()
					acemenupanel:UpdateDisplay( GearboxData )
					ACE.MenuSendValue( "Global", "Type", GearboxData.type )
				end
			end
		end

		-------------------- FuelTank folder --------------------

		--Creates the only button to access to fueltank config menu.
		for _, FuelTankData in pairs(FinalContainer["FuelTanks"]) do

			function FuelTanks:DoClick()
				acemenupanel:UpdateDisplay( FuelTankData )
				ACE.MenuSendValue( "Global", "Type", FuelTankData.type )
			end

			break
		end
	end
	do
		--[[==================================================
							Sensor folder
		]]--==================================================

		local sensors	= HomeNode:AddNode("Sensors" , "icon16/transmit.png") --Sensor folder name

		local antimissile = sensors:AddNode("Anti-Missile Radar" , ItemIcon  )
		local tracking	= sensors:AddNode("Tracking Radar", ItemIcon)
		local irst		= sensors:AddNode("IRST", ItemIcon)

		local nods = {}

		if radarClasses then
			for k, v in pairs(radarClasses) do  --calls subfolders
				if v.type == "Anti-missile" then
					nods[k] = antimissile:AddNode( v.name or "No Name" , ItemIcon	)
				elseif v.type == "Tracking-Radar" then
					nods[k] = tracking
				elseif v.type == "IRST" then
					nods[k] = irst
				end
			end

			--calls subfolders content
			for _, Ent in pairs(radars) do

				local curNode = nods[Ent.class]

				if curNode then

					local EndNode = curNode:AddNode( Ent.name or "No Name", "icon16/newspaper.png" )
					EndNode.mytable = Ent

					function EndNode:DoClick()
						acemenupanel:UpdateDisplay( self.mytable )
						ACE.MenuSendValue( "Global", "Type", self.mytable.type )
					end
				end
			end --end radar folder
		end

	end

	do

		--[[==================================================
							Settings folder
		]]--==================================================

		local SettingsNode = TreePanel:AddNode( "Settings", "icon16/wrench_orange.png" ) --Options folder

		local CSNode = SettingsNode:AddNode("Client" , "icon16/user.png") --Client folder
		CSNode.mytable = {}
		CSNode.mytable.guicreate = function( _, Table ) ACFCLGUICreate( Table ) end or nil
		function CSNode:DoClick()
			acemenupanel:UpdateDisplay(self.mytable)
		end

		local ply = LocalPlayer()
		if ply:IsSuperAdmin() then
			local SSNode = SettingsNode:AddNode("Server", "icon16/cog.png")  --Server folder
			SSNode.mytable = {}
			SSNode.mytable.guicreate = function( _, Table ) ACFSVGUICreate( Table ) end or nil
			function SSNode:DoClick()
				acemenupanel:UpdateDisplay(self.mytable)
			end
		end
	end

	self.WeaponSelect = TreePanel
end

function PANEL:UpdateDisplay( Table )

	ACE.MenuDestroy()
	if Table.id then
		ACE.MenuSendValue( "Global", "Id", Table.id)
	end

	--If a previous display exists, erase it
	if acemenupanel.CustomDisplay then
		acemenupanel.CustomDisplay:Clear(true)
		acemenupanel.CustomDisplay = nil
		acemenupanel.CData = nil
	end
	--Create the space to display the custom data
	acemenupanel.CustomDisplay = vgui.Create( "DPanelList", acemenupanel )
	acemenupanel.CustomDisplay:SetSpacing( 10 )
	acemenupanel.CustomDisplay:EnableHorizontal( false )
	acemenupanel.CustomDisplay:EnableVerticalScrollbar( false )
	acemenupanel.CustomDisplay:SetSize( acemenupanel:GetWide(), acemenupanel:GetTall() )

	--Create a table for the display to store data
	acemenupanel["CData"] = acemenupanel["CData"] or {}

	acemenupanel.CreateAttribs = Table.guicreate
	acemenupanel.UpdateAttribs = Table.guiupdate
	acemenupanel:CreateAttribs( Table )

	acemenupanel:PerformLayout()

end

function PANEL:PerformLayout()

	--Starting positions
	local vspacing = 10
	local ypos = 0

	--Selection Tree panel
	acemenupanel.WeaponSelect:SetPos( 0, ypos )
	acemenupanel.WeaponSelect:SetSize( acemenupanel:GetWide(), ScrH() * 0.4 )
	ypos = acemenupanel.WeaponSelect.Y + acemenupanel.WeaponSelect:GetTall() + vspacing

	if acemenupanel.CustomDisplay then
		--Custom panel
		acemenupanel.CustomDisplay:SetPos( 0, ypos )
		acemenupanel.CustomDisplay:SetSize( acemenupanel:GetWide(), acemenupanel:GetTall() - acemenupanel.WeaponSelect:GetTall() - 10 )
		ypos = acemenupanel.CustomDisplay.Y + acemenupanel.CustomDisplay:GetTall() + vspacing
	end

end

--[[=========================
	ACE information folder content
=========================]]--
function ACFHomeGUICreate()
	if not acemenupanel.CustomDisplay then return end

	local currentpanel = acemenupanel.CustomDisplay
	local isExperimental = ACE.Version > ACE.CurrentVersion

	-- ====================================================
	-- 1. Lógica de Versiones (Procesamos los datos primero)
	-- ====================================================
	local versionType = "Unknown"
	local versionString = "No internet Connection available!"
	local statusColor = Color(225, 0, 0, 255)
	local statusText = versionString

	if ACE.CurrentVersion > 0 then
		versionType = isExperimental and "Experimental" or "Default"

		if isExperimental or ACE.Version == ACE.CurrentVersion then
			versionString = "Up To Date"
			statusColor = Color(0, 225, 0, 255)
		else
			versionString = "Out Of Date"
			statusColor = Color(225, 0, 0, 255)
		end

		statusText = "ACE Is " .. versionString .. "!\n"
	end

	local versionInfoText = "Latest Version: " .. ACE.CurrentVersion .. "\nYour Version: " .. ACE.Version .. "\nCurrent Build: " .. versionType


	-- ====================================================
	-- 2. Creación de la Interfaz Gráfica (VGUI)
	-- ====================================================

	local AboutHeader = vgui.Create( "DLabel" )
	AboutHeader:SetColor( Color(10,10,10) )
	AboutHeader:SetText("Version Details")
	AboutHeader:SetFont("DermaDefaultBold")
	AboutHeader:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( AboutHeader )
	acemenupanel["CData"]["AboutHeader"] = AboutHeader

	-- Etiqueta de información de versión
	local labelVersion = vgui.Create("DLabel")
	labelVersion:SetText(versionInfoText)
	labelVersion:SetTextColor(Color(0, 0, 0))
	labelVersion:SizeToContents()

	currentpanel:AddItem(labelVersion)
	acemenupanel["CData"]["VersionInit"] = labelVersion

	-- Etiqueta de estado de la versión
	local labelVersionStatus = vgui.Create("DLabel")
	labelVersionStatus:SetFont("Trebuchet18")
	labelVersionStatus:SetText(statusText)
	labelVersionStatus:SetTextColor(statusColor)
	labelVersionStatus:SizeToContents()

	currentpanel:AddItem(labelVersionStatus)
	acemenupanel["CData"]["VersionText"] = labelVersionStatus

	-- Botón de Changelog (Solo se crea si no existe)
	if not acemenupanel["CData"]["ChangelogButton"] then
		acemenupanel:CPanelText("Header", "For a complete changelog, visit our Github")

		local changelogButton = vgui.Create("DButton")
		changelogButton:SetText("View Commits")
		changelogButton.DoClick = function()
			local branch = isExperimental and "dev" or "main"
			gui.OpenURL("https://github.com/MartyX5555/test-project/commits/" .. branch .. "/")
		end

		currentpanel:AddItem(changelogButton)
		acemenupanel["CData"]["ChangelogButton"] = changelogButton
	end


	-- ====================================================
	-- 3. Actualización Final
	-- ====================================================
	currentpanel:PerformLayout()
end

--[[=========================
	Clientside folder content
]]--=========================
function ACFCLGUICreate()

	local Client = acemenupanel["CData"]["Options"]

	Client = vgui.Create( "DLabel" )
	Client:SetPos( 0, 0 )
	Client:SetColor( Color(10,10,10) )
	Client:SetText("ACE - Client Side Control Panel")
	Client:SetFont("DermaDefaultBold")
	Client:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Client )

	local Sub = vgui.Create( "DLabel" )
	Sub:SetPos( 0, 0 )
	Sub:SetColor( Color(10,10,10) )
	Sub:SetText("Client Side parameters can be adjusted here.")
	Sub:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Sub )

	local Sounds = vgui.Create( "DForm" )
	Sounds:SetName("Sounds")

	Sounds:CheckBox("Allow Tinnitus Noise", "ace_tinnitus")
	Sounds:ControlHelp( "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat." )

	Sounds:NumSlider( "Ambient overall sounds", "ace_sound_volume", 0, 100, 0 )
	Sounds:ControlHelp( "Adjusts the volume of ACE sounds like explosions, penetrations, ricochets, etc. Engines and some mechanic sounds are not affected yet." )

	acemenupanel.CustomDisplay:AddItem( Sounds )

	local Effects = vgui.Create( "DForm" )
	Effects:SetName("Rendering")

	Effects:CheckBox("Allow lighting rendering", "ace_enable_lighting")
	Effects:ControlHelp( "Enables lighting for explosions, muzzle flashes and rocket motors, increasing the inmersion during combat, however, may impact heavily the performance and it's possible it doesn't render properly in certain map surfaces." )

	Effects:CheckBox("Draw Mobility rope links", "ACE_MobilityRopeLinks")
	Effects:ControlHelp( "Allow you to see the links between engines and gearboxes (requires dupe restart)" )

	acemenupanel.CustomDisplay:AddItem( Effects )

	local DupeSection = vgui.Create( "DForm" )
	DupeSection:SetName("Dupe Loader")

	DupeSection:CheckBox("Deploy dupes", "ace_dupes_deploy")
	DupeSection:ControlHelp( "If enabled, allow dupes to be created on the advdupe2 folder. If you dont want them, disable this and delete the dupes on the advdupe2 folder, ACE will ignore them and wont remount them again. If you want to remount them, just delete this convar and restart your session or use the ace_dupes_remount command." )
	DupeSection:Help( "If you deleted one of the dupes, you can restore them here." )
	DupeSection:Button("Restore ace dupe folders", "ace_dupes_remount" )

	acemenupanel.CustomDisplay:AddItem( DupeSection )

end

local function MenuNotifyError()

	local Note = vgui.Create( "DLabel" )
	Note:SetPos( 0, 0 )
	Note:SetColor( Color(10,10,10) )
	Note:SetText("To edit the server side settings, use the console commands and ")
	Note:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Note )

end


--[[=========================
	Serverside folder content
]]--=========================
function ACFSVGUICreate()	--Serverside folder content

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if game.IsDedicated() then MenuNotifyError() return end

	local Server = acemenupanel["CData"]["Options"]

	Server = vgui.Create( "DLabel" )
	Server:SetPos( 0, 0 )
	Server:SetColor( Color(10,10,10) )
	Server:SetText("ACE - Server Side Control Panel")
	Server:SetFont("DermaDefaultBold")
	Server:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Server )

	local Sub = vgui.Create( "DLabel" )
	Sub:SetPos( 0, 0 )
	Sub:SetColor( Color(10,10,10) )
	Sub:SetText("Server Side parameters can be adjusted here")
	Sub:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Sub )

	local General = vgui.Create( "DForm" )
	General:SetName("General")

	General:CheckBox("Enable HE push", "ace_hepush")
	General:ControlHelp( "Allow HE to push contraptions away" )

	General:CheckBox("Enable Recoil force", "ace_recoilpush")
	General:ControlHelp( "Gun's recoil will push the contraption back when firing" )

	General:NumSlider( "Debris Life Time", "ace_debris_lifetime", 0, 60, 2 )
	General:ControlHelp( "How many seconds debris will stand on the map before being deleted (0 means never)." )

	General:NumSlider( "Child debris chance", "ace_debris_children", 0, 1, 2 )
	General:ControlHelp( "Adjusts the chance of create debris when a contraption's gate have been destroyed" )

	--General:NumSlider( "Year", "acf_year", 1900, 2021, 0 )
	--General:ControlHelp( "Changes the year. This will affect the available weaponry (requires restart)." )

	acemenupanel.CustomDisplay:AddItem( General )

	local Spall = vgui.Create( "DForm" )
	Spall:SetName("Spalling")

	Spall:CheckBox("Enable Spalling", "ace_spalling")
	Spall:ControlHelp( "Enable additional spalling to be created during penetrations. Disable this to have better performance." )

	Spall:NumSlider( "Spalling Multipler", "ace_spalling_multipler", 1, 5, 0 )
	Spall:ControlHelp( "How much Spalling will be created during impacts? Applies for spalling created by impacts" )

	acemenupanel.CustomDisplay:AddItem( Spall )

	local Scaled = vgui.Create( "DForm" )
	Scaled:SetName("Cooking off")

	Scaled:NumSlider( "Max HE per explosion", "ace_explosions_scaled_he_max", 50, 1000, 0 )
	Scaled:ControlHelp( "The maximum amount of HE weight to detonate at once." )

	Scaled:NumSlider( "Max entities per explosion", "ace_explosions_scaled_ents_max", 1, 20, 0 )
	Scaled:ControlHelp( "The maximum amount of entities to detonate at once." )

	acemenupanel.CustomDisplay:AddItem( Scaled )

	local Legal = vgui.Create( "DForm" )
	Legal:SetName("Legality")

	Legal:CheckBox("Enable Legality checks", "ace_legalcheck")
	Legal:ControlHelp( "Enable the legality checks, which will punish with a lock time any stuff considered illegal." )

	Legal:CheckBox( "Allow not solid", "ace_legal_ignore_notsolid" )
	Legal:ControlHelp( "allow to use not solid" )

	Legal:CheckBox( "Allow any model", "ace_legal_ignore_model" )
	Legal:ControlHelp( "Allow ace ents to use any model" )

	Legal:CheckBox( "Allow any mass", "ace_legal_ignore_mass" )
	Legal:ControlHelp( "Allow ace ents to use any weight" )

	Legal:CheckBox( "Allow any material", "ace_legal_ignore_material" )
	Legal:ControlHelp( "Allow ace ents to use any material type" )

	Legal:CheckBox( "Allow any inertia", "ace_legal_ignore_inertia" )
	Legal:ControlHelp( "Allow ace ents to have any inertia in it" )

	Legal:CheckBox("Allow makesphere", "ace_legal_ignore_makesphere")
	Legal:ControlHelp( "Allow ace ents to have makesphere" )

	Legal:CheckBox( "Allow visclip", "ace_legal_ignore_visclip" )
	Legal:ControlHelp( "ace ents can have visclip at any case" )

	acemenupanel.CustomDisplay:AddItem( Legal )

end

--===========================================================================================
-----Ammo & Gun selection content
--===========================================================================================

do

	local function CreateIdForCrate( self )

		if not acemenupanel.AmmoPanelConfig["LegacyAmmos"] then

			local X = math.Round( acemenupanel.AmmoPanelConfig["Crate_Length"], 1 )
			local Y = math.Round(acemenupanel.AmmoPanelConfig["Crate_Width"], 1 )
			local Z = math.Round(acemenupanel.AmmoPanelConfig["Crate_Height"], 1)
			local Scale = Vector(X,Y,Z)
			acemenupanel.AmmoData["Id"] = "Scalable"
			acemenupanel.AmmoData["Dimensions"] = Scale
			ACE.MenuSendValue( "Global", "Id", "Scalable")
			ACE.MenuSendValue( "Data", "Dimensions", Scale)
		end

		self:UpdateAttribs()

	end

	function PANEL:AmmoSelect( Blacklist )

		if not acemenupanel.CustomDisplay then return end
		if not Blacklist then Blacklist = {} end

		if not acemenupanel.AmmoData then

			acemenupanel.AmmoData               = {}
			acemenupanel.AmmoData["Id"]         = "Scalable"  --default Ammo dimension on list
			acemenupanel.AmmoData["Dimensions"] = Vector(10,10,10) --default dimensions for the scalable crate
			acemenupanel.AmmoData["IdLegacy"]   = "Shell100mm"
			acemenupanel.AmmoData["Type"]       = "Ammo"
			acemenupanel.AmmoData["Classname"]  = Classes.GunClass["MG"]["name"]
			acemenupanel.AmmoData["ClassData"]  = Classes.GunClass["MG"]["id"]
			acemenupanel.AmmoData["Data"]       = ACEEnts["Guns"]["12.7mmMG"]["round"]
		end

		if not acemenupanel.AmmoPanelConfig then

			acemenupanel.AmmoPanelConfig = {}
			acemenupanel.AmmoPanelConfig["ExpandedCatNew"] = true
			acemenupanel.AmmoPanelConfig["ExpandedCatOld"] = false
			acemenupanel.AmmoPanelConfig["LegacyAmmos"]	= false
			acemenupanel.AmmoPanelConfig["Crate_Length"]  = 10
			acemenupanel.AmmoPanelConfig["Crate_Width"]	= 10
			acemenupanel.AmmoPanelConfig["Crate_Height"]  = 10

		end

		local MainPanel = self
		local CrateNewCat = vgui.Create( "DCollapsibleCategory" )	-- Create a collapsible category
		acemenupanel.CustomDisplay:AddItem(CrateNewCat)
		CrateNewCat:SetLabel( "Crate Config" )						-- Set the name ( label )
		CrateNewCat:SetPos( 25, 50 )		-- Set position
		CrateNewCat:SetSize( 250, 100 )	-- Set size
		CrateNewCat:SetExpanded( acemenupanel.AmmoPanelConfig["ExpandedCatNew"] )

		function CrateNewCat:OnToggle( bool )
			acemenupanel.AmmoPanelConfig["ExpandedCatNew"] = bool
		end

		local CrateNewPanel = vgui.Create( "DPanelList" )
		CrateNewPanel:SetSpacing( 10 )
		CrateNewPanel:EnableHorizontal( false )
		CrateNewPanel:EnableVerticalScrollbar( true )
		CrateNewPanel:SetPaintBackground( false )
		CrateNewCat:SetContents( CrateNewPanel )

		local CrateOldCat = vgui.Create( "DCollapsibleCategory" )
		acemenupanel.CustomDisplay:AddItem(CrateOldCat)
		CrateOldCat:SetLabel( "Crate Config (legacy)" )
		CrateOldCat:SetPos( 25, 50 )
		CrateOldCat:SetSize( 250, 100 )
		CrateOldCat:SetExpanded( acemenupanel.AmmoPanelConfig["ExpandedCatOld"] )

		function CrateOldCat:OnToggle( bool )
			acemenupanel.AmmoPanelConfig["ExpandedCatOld"] = bool
		end

		local CrateOldPanel = vgui.Create( "DPanelList" )
		CrateOldPanel:SetSpacing( 10 )
		CrateOldPanel:EnableHorizontal( false )
		CrateOldPanel:EnableVerticalScrollbar( true )
		CrateOldPanel:SetPaintBackground( false )
		CrateOldCat:SetContents( CrateOldPanel )

		--===========================================================================================
		-----Creating the ammo crate selection
		--===========================================================================================

		--------------- NEW CONFIG ---------------
		do

			local MinCrateSize = ACE.CrateMinimumSize
			local MaxCrateSize = ACE.CrateMaximumSize

			acemenupanel:CPanelText("Crate_desc_new", "\nAdjust the dimensions for your crate. In inches.", nil, CrateNewPanel)

			local LengthSlider = vgui.Create( "DNumSlider" )
			LengthSlider:SetText( "Length" )
			LengthSlider:SetDark( true )
			LengthSlider:SetMin( MinCrateSize )
			LengthSlider:SetMax( MaxCrateSize )
			LengthSlider:SetValue( acemenupanel.AmmoPanelConfig["Crate_Length"] or 10 )
			LengthSlider:SetDecimals( 1 )

			function LengthSlider:OnValueChanged( value )
				acemenupanel.AmmoPanelConfig["Crate_Length"] = value
				CreateIdForCrate( MainPanel )
			end
			CrateNewPanel:AddItem(LengthSlider)

			local WidthSlider = vgui.Create( "DNumSlider" )
			WidthSlider:SetText( "Width" )
			WidthSlider:SetDark( true )
			WidthSlider:SetMin( MinCrateSize )
			WidthSlider:SetMax( MaxCrateSize )
			WidthSlider:SetValue( acemenupanel.AmmoPanelConfig["Crate_Width"] or 10 )
			WidthSlider:SetDecimals( 1 )

			function WidthSlider:OnValueChanged( value )
				acemenupanel.AmmoPanelConfig["Crate_Width"] = value
				CreateIdForCrate( MainPanel )
			end
			CrateNewPanel:AddItem(WidthSlider)

			local HeightSlider = vgui.Create( "DNumSlider" )
			HeightSlider:SetText( "Height" )
			HeightSlider:SetDark( true )
			HeightSlider:SetMin( MinCrateSize )
			HeightSlider:SetMax( MaxCrateSize )
			HeightSlider:SetValue( acemenupanel.AmmoPanelConfig["Crate_Height"] or 10 )
			HeightSlider:SetDecimals( 1 )

			function HeightSlider:OnValueChanged( value )
				acemenupanel.AmmoPanelConfig["Crate_Height"] = value
				CreateIdForCrate( MainPanel )
			end
			CrateNewPanel:AddItem(HeightSlider)

		end

		--------------- OLD CONFIG ---------------
		do

			acemenupanel:CPanelText("Crate_desc_legacy", "\nChoose a crate in the legacy way. Remember to enable the checkbox below to do so.", nil, CrateOldPanel)
			acemenupanel:CPanelText("Crate_desc_legacy2", "DISCLAIMER: These crates are deprecated and dont't follow any proper format like the capacity or size. Don't trust on these crates, apart they might be removed in a future!", nil, CrateOldPanel)

			local LegacyCheck = vgui.Create( "DCheckBoxLabel" ) -- Create the checkbox
			LegacyCheck:SetPos( 25, 50 )							-- Set the position
			LegacyCheck:SetText("Use Legacy Mode")					-- Set the text next to the box
			LegacyCheck:SetDark( true )
			LegacyCheck:SetChecked( acemenupanel.AmmoPanelConfig["LegacyAmmos"] or false )						-- Initial value
			LegacyCheck:SizeToContents()							-- Make its size the same as the contents

			function LegacyCheck:OnChange( val )
				acemenupanel.AmmoPanelConfig["LegacyAmmos"] = val
				if val then
					acemenupanel.AmmoData["Id"] =  acemenupanel.AmmoData["IdLegacy"]
					ACE.MenuSendValue( "Global", "Id", acemenupanel.AmmoData["Id"] )
					MainPanel:UpdateAttribs()
				else
					CreateIdForCrate( MainPanel )
				end
			end

			CrateOldPanel:AddItem(LegacyCheck)

			local AmmoComboBox = vgui.Create( "DComboBox", CrateOldPanel )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
			AmmoComboBox:SetSize(acemenupanel.CustomDisplay:GetWide(), 30)

			for Key, Value in pairs( ACEEnts.Ammo ) do

				AmmoComboBox:AddChoice( Value.id , Key ) --Creates the list

			end

			AmmoComboBox.OnSelect = function( _ , _ , data )	-- calls the ID of the list
				if acemenupanel.AmmoPanelConfig["LegacyAmmos"] then
					ACE.MenuSendValue( "Global", "Id", data )
					acemenupanel.AmmoData["Id"] = data
				end

				acemenupanel.AmmoData["IdLegacy"] = data

				if acemenupanel.CData.CrateDisplay then
					local cratemodel = ACEEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].model
					acemenupanel.CData.CrateDisplay:SetModel(cratemodel)
					acemenupanel:CPanelText("CrateDesc", ACEEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)
				end

				MainPanel:UpdateAttribs()

			end

			AmmoComboBox:SetText(acemenupanel.AmmoData["IdLegacy"])
			ACE.MenuSendValue( "Global", "Id", acemenupanel.AmmoData["Id"] )
			ACE.MenuSendValue( "Data", "Dimensions", acemenupanel.AmmoData["Dimensions"] )

			CrateOldPanel:AddItem(AmmoComboBox)

		--===========================================================================================
		-----Creating the Model display
		--===========================================================================================

			--Used to create the general model display
			if not acemenupanel.CData.CrateDisplay then

				acemenupanel:CPanelText("CrateDesc", ACEEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

				acemenupanel.CData.CrateDisplay = vgui.Create( "DModelPanel", CrateOldPanel )
				acemenupanel.CData.CrateDisplay:SetSize(acemenupanel.CustomDisplay:GetWide(),acemenupanel.CustomDisplay:GetWide() / 2)
				acemenupanel.CData.CrateDisplay:SetCamPos( Vector( 250, 500, 250 ) )
				acemenupanel.CData.CrateDisplay:SetLookAt( Vector( 0, 0, 0 ) )
				acemenupanel.CData.CrateDisplay:SetFOV( 10 )
				acemenupanel.CData.CrateDisplay:SetModel(ACEEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].model)
				acemenupanel.CData.CrateDisplay.LayoutEntity = function() end

				CrateOldPanel:AddItem(acemenupanel.CData.CrateDisplay)

			end

		end

		--===========================================================================================
		-----Creating the gun Class display
		--===========================================================================================

		acemenupanel.CData.ClassSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay)
		acemenupanel.CData.ClassSelect:SetSize(100, 30)

		local DComboList = {}

		for _, GunTable in pairs( Classes.GunClass ) do

			if not table.HasValue( Blacklist, GunTable.id ) then
				acemenupanel.CData.ClassSelect:AddChoice( GunTable.name , GunTable.id )
				DComboList[GunTable.id] = true

			end
		end

		acemenupanel.CData.ClassSelect:SetText( acemenupanel.AmmoData["Classname"] .. (not DComboList[acemenupanel.AmmoData["ClassData"]] and " - update caliber!" or "" ))
		acemenupanel.CData.ClassSelect:SetColor( not DComboList[acemenupanel.AmmoData["ClassData"]] and Color(255,0,0) or Color(0,0,0) )

		acemenupanel.CData.ClassSelect.OnSelect = function( _ , index , data )

			data = acemenupanel.CData.ClassSelect:GetOptionData(index) -- Why?

			acemenupanel.AmmoData["Classname"] = Classes.GunClass[data]["name"]
			acemenupanel.AmmoData["ClassData"] = Classes.GunClass[data]["id"]

			acemenupanel.CData.ClassSelect:SetColor( Color(0,0,0) )

			acemenupanel.CData.CaliberSelect:Clear()

			for Key, Value in pairs( ACEEnts.Guns ) do

				if acemenupanel.AmmoData["ClassData"] == Value.gunclass then
				acemenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
				end

			end

			MainPanel:UpdateAttribs()
			MainPanel:UpdateAttribs() --Note : this is intentional
		end

		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.ClassSelect )

		--===========================================================================================
		-----Creating the caliber selection display
		--===========================================================================================

		acemenupanel.CData.CaliberSelect = vgui.Create( "DComboBox", acemenupanel.CustomDisplay )
		acemenupanel.CData.CaliberSelect:SetSize(100, 30)

		acemenupanel.CData.CaliberSelect:SetText(acemenupanel.AmmoData["Data"]["id"]  )

		for Key, Value in pairs( ACEEnts.Guns ) do

			if acemenupanel.AmmoData["ClassData"] == Value.gunclass then
				acemenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
			end

		end

		acemenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , data )
			acemenupanel.AmmoData["Data"] = ACEEnts["Guns"][data]["round"]
			MainPanel:UpdateAttribs()
			MainPanel:UpdateAttribs() --Note : this is intentional

		end

		acemenupanel.CustomDisplay:AddItem( acemenupanel.CData.CaliberSelect )

	end
end

function PANEL:AmmoSlider(Name, Value, Min, Max, Decimals, Title, Desc) --Variable name in the table, Value, Min value, Max Value, slider text title, slider decimeals, description text below slider

	if not acemenupanel["CData"][Name] then

		acemenupanel["CData"][Name] = vgui.Create( "DNumSlider", acemenupanel.CustomDisplay )
		acemenupanel["CData"][Name].Label:SetSize( 0 )  --Note : this is intentional
		acemenupanel["CData"][Name]:SetTall( 50 )	-- make the slider taller to fit the new label
		acemenupanel["CData"][Name]:SetMin( 0 )
		acemenupanel["CData"][Name]:SetMax( 1000 )
		acemenupanel["CData"][Name]:SetDark( true )
		acemenupanel["CData"][Name]:SetDecimals( Decimals )

		acemenupanel["CData"][Name .. "_label"] = vgui.Create( "DLabel", acemenupanel["CData"][Name]) -- recreating the label
		acemenupanel["CData"][Name .. "_label"]:SetPos( 0, 0)
		acemenupanel["CData"][Name .. "_label"]:SetText( Title )
		acemenupanel["CData"][Name .. "_label"]:SizeToContents()
		acemenupanel["CData"][Name .. "_label"]:SetTextColor( Color( 0, 0, 0) )

		if acemenupanel.AmmoData[Name] then
				acemenupanel["CData"][Name]:SetValue(acemenupanel.AmmoData[Name])
		end

		acemenupanel["CData"][Name].OnValueChanged = function( _, val )

		if acemenupanel.AmmoData[Name] ~= val then

			acemenupanel.AmmoData[Name] = val
				self:UpdateAttribs( Name )
			end

		end

		acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name] )

	end

	acemenupanel["CData"][Name]:SetMin( Min )
	acemenupanel["CData"][Name]:SetMax( Max )
	acemenupanel["CData"][Name]:SetValue( Value )

	if not acemenupanel["CData"][Name .. "_text"] and Desc then

		acemenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )
		acemenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
		acemenupanel["CData"][Name .. "_text"]:SetTextColor( Color( 0, 0, 0) )
		acemenupanel["CData"][Name .. "_text"]:SetTall( 20 )
		acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name .. "_text"] )

	end

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acemenupanel["CData"][Name .. "_text"]:SetSize( acemenupanel.CustomDisplay:GetWide(), 14 )
	acemenupanel["CData"][Name .. "_text"]:SizeToContentsX()

end

-- Variable name in the table, slider text title, slider decimeals, description text below slider
function PANEL:AmmoCheckbox(Name, Title, Desc, Tooltip )

	if not acemenupanel["CData"][Name] then

	acemenupanel["CData"][Name] = acemenupanel["CData"][Name]

	acemenupanel["CData"][Name] = vgui.Create( "DCheckBoxLabel" )
	acemenupanel["CData"][Name]:SetText( Title or "" )
	acemenupanel["CData"][Name]:SetTextColor( Color( 0, 0, 0) )
	acemenupanel["CData"][Name]:SizeToContents()
	acemenupanel["CData"][Name]:SetChecked(acemenupanel.AmmoData[Name] or false)

	acemenupanel["CData"][Name].OnChange = function( _, bval )

		bval = bval and 1 or 0 -- converting to number since booleans sucks in this duty

		acemenupanel.AmmoData[Name] = tonumber(bval) --print(isstring(acemenupanel.AmmoData[Name]))

		self:UpdateAttribs()

	end

	if Tooltip and Tooltip ~= "" then
		acemenupanel["CData"][Name]:SetTooltip( Tooltip )
	end

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name] )

	end

	acemenupanel["CData"][Name]:SetText( Title )

	if not acemenupanel["CData"][Name .. "_text"] and Desc then

	acemenupanel["CData"][Name .. "_text"] = acemenupanel["CData"][Name .. "_text"]
	acemenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )
	acemenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
	acemenupanel["CData"][Name .. "_text"]:SetTextColor( Color( 0, 0, 0) )
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name .. "_text"] )

	end

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acemenupanel["CData"][Name .. "_text"]:SetSize( acemenupanel.CustomDisplay:GetWide(), 10 )
	acemenupanel["CData"][Name .. "_text"]:SizeToContentsX()

end

--[[-------------------------------------
	PANEL:CPanelText(Name, Desc, Font)

	1-Name: Identifier of this text
	2-Desc: The content of this text
	3-Font: The Font to be used in this text. Leave it empty or nil to use the default one
	4-
]]---------------------------------------

function ACE.CPanelText(Name, Desc, Font, Panel)

	if not acemenupanel["CData"][Name .. "_text"] then

		acemenupanel["CData"][Name .. "_text"] = vgui.Create( "DLabel" )

		acemenupanel["CData"][Name .. "_text"]:SetText( Desc or "" )
		acemenupanel["CData"][Name .. "_text"]:SetTextColor( Color( 0, 0, 0) )

		if Font then acemenupanel["CData"][Name .. "_text"]:SetFont( Font ) end

		acemenupanel["CData"][Name .. "_text"]:SetWrap(true)
		acemenupanel["CData"][Name .. "_text"]:SetAutoStretchVertical( true )

		if IsValid(Panel) then
			if Panel.AddItem then
				Panel:AddItem( acemenupanel["CData"][Name .. "_text"] )
			end
		else
			acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"][Name .. "_text"] )
		end
	end

	acemenupanel["CData"][Name .. "_text"]:SetText( Desc )
	acemenupanel["CData"][Name .. "_text"]:SetSize( acemenupanel.CustomDisplay:GetWide(), 10 )
	acemenupanel["CData"][Name .. "_text"]:SizeToContentsY()

end

--quick fix
function PANEL:CPanelText(Name, Desc, Font, Panel)
	ACE.CPanelText(Name, Desc, Font, Panel)
end