
--[[------------------------
	1.- This is the file that displays the main menu, such as guns, ammo, mobility and subfolders.

	2.- Almost everything here has been documented, you should find the responsible function easily.

	3.- If you are going to do changes, please not to be a shitnuckle and write a note alongside the code that you´ve changed/edited. This should avoid issues with future developers.

]]--------------------------

local Classes = ACE.Classes
local ACFEnts = ACE.Weapons

local radarClasses    = Classes.Radar
local radars          = ACFEnts.Radars

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
			RunConsoleCommand( "acemenu_type", self.mytable.type )
			acemenupanel:UpdateDisplay( self.mytable )
		end
	end
end

PANEL = PANEL or {}

function PANEL:Init( )

	acemenupanel = self.Panel

	-- -- height
	self:SetTall( ScrH() - 150 )

	-- --Weapon Select
	local TreePanel = vgui.Create( "DTree", self )

--[[=========================
	Table distribution
]]--=========================

	self.GunClasses		= {}
	self.MisClasses		= {}
	self.ModClasses		= {}

	local FinalContainer = {}

	for ID,Table in pairs(Classes) do

		self.GunClasses[ID] = {}
		self.MisClasses[ID] = {}
		self.ModClasses[ID] = {}

		for ClassID,Class in pairs(Table) do

			Class.id = ClassID

			--Table content for Guns folder
			if Class.type == "Gun" then

				table.insert(self.GunClasses[ID], Class)
			--Table content for Missiles folder
			elseif Class.type == "missile" then

				table.insert(self.MisClasses[ID], Class)
			else

				table.insert(self.ModClasses[ID], Class)
			end

		end

		table.sort(self.GunClasses[ID], function(a,b) return a.id < b.id end )
		table.sort(self.MisClasses[ID], function(a,b) return a.id < b.id end )
		table.sort(self.ModClasses[ID], function(a,b) return a.id < b.id end )

	end

	for ID,Table in pairs(ACFEnts) do

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


	HomeNode = TreePanel:AddNode( "ACE Main Menu" , MainMenuIcon ) --Main Menu folder
	HomeNode:SetExpanded(true)
	HomeNode.mytable = {}
	HomeNode.mytable.guicreate = (function( _, Table ) ACFHomeGUICreate( Table ) end or nil)
	HomeNode.mytable.guiupdate = (function( _, Table ) ACFHomeGUIUpdate( Table ) end or nil)

	function HomeNode:DoClick()
		acemenupanel:UpdateDisplay(self.mytable)
	end

	------------------- Guns folder -------------------

	local Guns = HomeNode:AddNode( "Guns" , "icon16/attach.png" ) --Guns folder

	for _,Class in pairs(self.GunClasses["GunClass"]) do

		local SubNode = Guns:AddNode( Class.name or "No Name" , ItemIcon )

		for _, Ent in pairs(FinalContainer["Guns"]) do
			if Ent.gunclass == Class.id then

				local EndNode = SubNode:AddNode( Ent.name or "No Name", "icon16/newspaper.png")
				EndNode.mytable = Ent

				function EndNode:DoClick()
					RunConsoleCommand( "acemenu_type", self.mytable.type )
					acemenupanel:UpdateDisplay( self.mytable )
				end
			end
		end
	end

	------------------- Missiles folder -------------------

	local Missiles = HomeNode:AddNode( "Missiles" , "icon16/wand.png" ) --Missiles folder

	for _,Class in pairs(self.MisClasses["GunClass"]) do

		local SubNode = Missiles:AddNode( Class.name or "No Name" , ItemIcon )

		for _, Ent in pairs(FinalContainer["Guns"]) do
			if Ent.gunclass == Class.id then

				local EndNode = SubNode:AddNode( Ent.name or "No Name", "icon16/newspaper.png")
				EndNode.mytable = Ent

				function EndNode:DoClick()
				RunConsoleCommand( "acemenu_type", self.mytable.type )
				acemenupanel:UpdateDisplay( self.mytable )
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
				RunConsoleCommand( "acemenu_type", EngineData.type )
				acemenupanel:UpdateDisplay( EngineData )
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
				RunConsoleCommand( "acemenu_type", GearboxData.type )
				acemenupanel:UpdateDisplay( GearboxData )
				end
			end
		end

		-------------------- FuelTank folder --------------------

		--Creates the only button to access to fueltank config menu.
		for _, FuelTankData in pairs(FinalContainer["FuelTanks"]) do

			function FuelTanks:DoClick()
				RunConsoleCommand( "acemenu_type", FuelTankData.type )
				acemenupanel:UpdateDisplay( FuelTankData )
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
						RunConsoleCommand( "acemenu_type", self.mytable.type )
						acemenupanel:UpdateDisplay( self.mytable )
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
		local SSNode = SettingsNode:AddNode("Server", "icon16/cog.png")  --Server folder

		CSNode.mytable = {}
		SSNode.mytable = {}
		CSNode.mytable.guicreate = function( _, Table ) ACFCLGUICreate( Table ) end or nil
		SSNode.mytable.guicreate = function( _, Table ) ACFSVGUICreate( Table ) end or nil

		function CSNode:DoClick()
			acemenupanel:UpdateDisplay(self.mytable)
		end
		function SSNode:DoClick()
			acemenupanel:UpdateDisplay(self.mytable)
		end

	end

	--[[
	do
		-- Support button
		
		local Contact =  TreePanel:AddNode( "Contact Us" , "icon16/feed.png" ) --Options folder
		Contact.mytable = {}

		Contact.mytable.guicreate = (function( _, Table ) ContactGUICreate( Table ) end or nil)

		function Contact:DoClick()
			acemenupanel:UpdateDisplay(self.mytable)
		end
		
	end]]

	self.WeaponSelect = TreePanel

	http.Fetch("http://raw.github.com/RedDeadlyCreeper/ArmoredCombatExtended/master/changelog.txt", ACFChangelogHTTPCallBack, function() end)
end

function PANEL:UpdateDisplay( Table )

	RunConsoleCommand( "acemenu_id", Table.id or 0 )

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
]]--=========================
function ACFHomeGUICreate()

	if not acemenupanel.CustomDisplay then return end

	local versionstring

	if ACE.CurrentVersion and ACE.CurrentVersion > 0 then
	if ACE.Version >= ACE.CurrentVersion then
		versionstring = "Up To Date"
		color = Color(0,225,0,255)
	else
		versionstring = "Out Of Date"
		color = Color(225,0,0,255)

	end
	else
	versionstring = "No internet Connection available!"
	color = Color(225,0,0,255)
	end

	versiontext = "GitHub Version: " .. ACE.CurrentVersion .. "\nCurrent Version: " .. ACE.Version

	acemenupanel["CData"]["VersionInit"] = vgui.Create( "DLabel" )
	acemenupanel["CData"]["VersionInit"]:SetText(versiontext)
	acemenupanel["CData"]["VersionInit"]:SetTextColor( Color( 0, 0, 0) )
	acemenupanel["CData"]["VersionInit"]:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["VersionInit"] )


	acemenupanel["CData"]["VersionText"] = vgui.Create( "DLabel" )

	acemenupanel["CData"]["VersionText"]:SetFont("Trebuchet18")
	acemenupanel["CData"]["VersionText"]:SetText("ACE Is " .. versionstring .. "!\n\n")
	acemenupanel["CData"]["VersionText"]:SetTextColor( Color( 0, 0, 0) )
	acemenupanel["CData"]["VersionText"]:SizeToContents()

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["VersionText"] )
	-- end version

	acemenupanel:CPanelText("Header", "Changelog")  --changelog screen

--[[=========================
	Changelog table maker
]]--=========================

	if acemenupanel.Changelog then
	acemenupanel["CData"]["Changelist"] = vgui.Create( "DTree" )

	for i = 0, table.maxn(acemenupanel.Changelog) - 100 do

		local k = table.maxn(acemenupanel.Changelog) - i

		local Node = acemenupanel["CData"]["Changelist"]:AddNode( "Rev " .. k )
			Node.mytable = {}
			Node.mytable["rev"] = k
				function Node:DoClick()

				acemenupanel:UpdateAttribs( Node.mytable )

			end
		Node.Icon:SetImage( "icon16/newspaper.png" )

	end

	acemenupanel.CData.Changelist:SetSize( acemenupanel.CustomDisplay:GetWide(), 60 )

	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["Changelist"] )

	acemenupanel.CustomDisplay:PerformLayout()

	acemenupanel:UpdateAttribs( {rev = table.maxn(acemenupanel.Changelog)} )
	end

end

--[[=========================
	ACE information folder content updater
]]--=========================
function ACFHomeGUIUpdate( Table )

	acemenupanel:CPanelText("Changelog", acemenupanel.Changelog[Table["rev"]])
	acemenupanel.CustomDisplay:PerformLayout()

	local color
	local versionstring

	if ACE.CurrentVersion > 0 then
		if ACE.Version >= ACE.CurrentVersion then
			versionstring = "Up To Date"
			color = Color(0,225,0,255)
		else
			versionstring = "Out Of Date"
			color = Color(225,0,0,255)
		end
	else
		versionstring = "No internet Connection available!"
		color = Color(225,0,0,255)
	end

	local txt

	if ACE.CurrentVersion > 0 then
		txt = "ACE Is " .. versionstring .. "!\n\n"
	else
		txt = versionstring
	end

	acemenupanel["CData"]["VersionText"]:SetText(txt)
	acemenupanel["CData"]["VersionText"]:SetTextColor( Color( 0, 0, 0) )
	acemenupanel["CData"]["VersionText"]:SetColor(color)
	acemenupanel["CData"]["VersionText"]:SizeToContents()

end

--[[=========================
	Changelog.txt
]]--=========================

function ACFChangelogHTTPCallBack(contents)
	local Temp = string.Explode( "*", contents )

	acemenupanel.Changelog = {}  --changelog table
	for _,String in pairs(Temp) do
		acemenupanel.Changelog[tonumber(string.sub(String,2,4))] = string.Trim(string.sub(String, 5))
	end

	table.SortByKey(acemenupanel.Changelog,true)

	local Table = {}
	Table.guicreate = (function( _, Table ) ACFHomeGUICreate( Table ) end or nil)
	Table.guiupdate = (function( _, Table ) ACFHomeGUIUpdate( Table ) end or nil)
	acemenupanel:UpdateDisplay( Table )

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

	Sounds:CheckBox("Allow Tinnitus Noise", "acf_tinnitus")
	Sounds:ControlHelp( "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat." )

	Sounds:NumSlider( "Ambient overall sounds", "acf_sound_volume", 0, 100, 0 )
	Sounds:ControlHelp( "Adjusts the volume of ACE sounds like explosions, penetrations, ricochets, etc. Engines and some mechanic sounds are not affected yet." )

	acemenupanel.CustomDisplay:AddItem( Sounds )

	local Effects = vgui.Create( "DForm" )
	Effects:SetName("Rendering")

	Effects:CheckBox("Allow lighting rendering", "acf_enable_lighting")
	Effects:ControlHelp( "Enables lighting for explosions, muzzle flashes and rocket motors, increasing the inmersion during combat, however, may impact heavily the performance and it's possible it doesn't render properly in certain map surfaces." )

	Effects:CheckBox("Draw Mobility rope links", "ACE_MobilityRopeLinks")
	Effects:ControlHelp( "Allow you to see the links between engines and gearboxes (requires dupe restart)" )

	acemenupanel.CustomDisplay:AddItem( Effects )

	local DupeSection = vgui.Create( "DForm" )
	DupeSection:SetName("Dupe Loader")

	DupeSection:Help( "If for some reason, your ace dupe folder was damaged or deleted, you can restore them here." )
	DupeSection:Button("Restore ace dupe folders", "acf_dupes_remount" )

	acemenupanel.CustomDisplay:AddItem( DupeSection )

end

local function MenuNotifyError()

	local Note = vgui.Create( "DLabel" )
	Note:SetPos( 0, 0 )
	Note:SetColor( Color(10,10,10) )
	Note:SetText("Not available in this moment")
	Note:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( Note )

end


--[[=========================
	Serverside folder content
]]--=========================
function ACFSVGUICreate()	--Serverside folder content

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if not ply:IsSuperAdmin() then return end
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

	General:CheckBox("Enable HE push", "acf_hepush")
	General:ControlHelp( "Allow HE to push contraptions away" )

	General:CheckBox("Enable Recoil force", "acf_recoilpush")
	General:ControlHelp( "Gun's recoil will push the contraption back when firing" )

	General:NumSlider( "Debris Life Time", "acf_debris_lifetime", 0, 60, 2 )
	General:ControlHelp( "How many seconds debris will stand on the map before being deleted (0 means never)." )

	General:NumSlider( "Child debris chance", "acf_debris_children", 0, 1, 2 )
	General:ControlHelp( "Adjusts the chance of create debris when a contraption's gate have been destroyed" )

	--General:NumSlider( "Year", "acf_year", 1900, 2021, 0 )
	--General:ControlHelp( "Changes the year. This will affect the available weaponry (requires restart)." )

	acemenupanel.CustomDisplay:AddItem( General )

	local Spall = vgui.Create( "DForm" )
	Spall:SetName("Spalling")

	Spall:CheckBox("Enable Spalling", "acf_spalling")
	Spall:ControlHelp( "Enable additional spalling to be created during penetrations. Disable this to have better performance." )

	Spall:NumSlider( "Spalling Multipler", "acf_spalling_multipler", 1, 5, 0 )
	Spall:ControlHelp( "How much Spalling will be created during impacts? Applies for spalling created by impacts" )

	acemenupanel.CustomDisplay:AddItem( Spall )

	local Scaled = vgui.Create( "DForm" )
	Scaled:SetName("Cooking off")

	Scaled:NumSlider( "Max HE per explosion", "acf_explosions_scaled_he_max", 50, 1000, 0 )
	Scaled:ControlHelp( "The maximum amount of HE weight to detonate at once." )

	Scaled:NumSlider( "Max entities per explosion", "acf_explosions_scaled_ents_max", 1, 20, 0 )
	Scaled:ControlHelp( "The maximum amount of entities to detonate at once." )

	acemenupanel.CustomDisplay:AddItem( Scaled )

	local Legal = vgui.Create( "DForm" )
	Legal:SetName("Legality")

	Legal:CheckBox("Enable Legality checks", "acf_legalcheck")
	Legal:ControlHelp( "Enable the legality checks, which will punish with a lock time any stuff considered illegal." )

	Legal:CheckBox( "Allow not solid", "acf_legal_ignore_notsolid" )
	Legal:ControlHelp( "allow to use not solid" )

	Legal:CheckBox( "Allow any model", "acf_legal_ignore_model" )
	Legal:ControlHelp( "Allow ace ents to use any model" )

	Legal:CheckBox( "Allow any mass", "acf_legal_ignore_mass" )
	Legal:ControlHelp( "Allow ace ents to use any weight" )

	Legal:CheckBox( "Allow any material", "acf_legal_ignore_material" )
	Legal:ControlHelp( "Allow ace ents to use any material type" )

	Legal:CheckBox( "Allow any inertia", "acf_legal_ignore_inertia" )
	Legal:ControlHelp( "Allow ace ents to have any inertia in it" )

	Legal:CheckBox("Allow makesphere", "acf_legal_ignore_makesphere")
	Legal:ControlHelp( "Allow ace ents to have makesphere" )

	Legal:CheckBox( "Allow visclip", "acf_legal_ignore_visclip" )
	Legal:ControlHelp( "ace ents can have visclip at any case" )

	acemenupanel.CustomDisplay:AddItem( Legal )

end

--[[=========================
	Contact folder content -- Disabled since this is another version.
]]--=========================
--[[
function ContactGUICreate()

	acemenupanel["CData"]["Contact"] = vgui.Create( "DLabel" )
	acemenupanel["CData"]["Contact"]:SetPos( 0, 0 )
	acemenupanel["CData"]["Contact"]:SetColor( Color(10,10,10) )
	acemenupanel["CData"]["Contact"]:SetText("Contact Us")
	acemenupanel["CData"]["Contact"]:SetFont("Trebuchet24")
	acemenupanel["CData"]["Contact"]:SizeToContents()
	acemenupanel.CustomDisplay:AddItem( acemenupanel["CData"]["Contact"] )

	acemenupanel:CPanelText("desc1","If you want to contribute to ACE by providing us feedback, report bugs or tell us suggestions about new stuff to be added, our discord is a good place.")
	acemenupanel:CPanelText("desc2","Don't forget to check out our wiki, contains valuable information about how to use this addon. It's on WIP, but expect more content in future.")

	local Discord = vgui.Create("DButton")
	Discord:SetText( "Join our Discord!" )
	Discord:SetPos(0,0)
	Discord:SetSize(250,30)
	Discord.DoClick = function()
	gui.OpenURL("https://discord.gg/Y8aEYU6")
	end
	acemenupanel.CustomDisplay:AddItem( Discord )

	local Wiki = vgui.Create("DButton")
	Wiki:SetText( "Open Wiki" )
	Wiki:SetPos(0,0)
	Wiki:SetSize(250,30)
	Wiki.DoClick = function()
	gui.OpenURL("https://github.com/RedDeadlyCreeper/ArmoredCombatExtended/wiki")
	end
	acemenupanel.CustomDisplay:AddItem( Wiki )

	local Guide = vgui.Create("DButton")
	Guide:SetText( "ACE guidelines" )
	Guide:SetPos(0,0)
	Guide:SetSize(250,30)
	Guide.DoClick = function()
	gui.OpenURL("https://docs.google.com/document/d/1yaHq4Lfjad4KKa0Jg9s-5lCpPVjV7FE4HXoGaKpi4Fs/edit")
	end
	acemenupanel.CustomDisplay:AddItem( Guide )

end
]]
--===========================================================================================
-----Ammo & Gun selection content
--===========================================================================================

do

	local function CreateIdForCrate( self )

		if not acemenupanel.AmmoPanelConfig["LegacyAmmos"] then

			local X = math.Round( acemenupanel.AmmoPanelConfig["Crate_Length"], 1 )
			local Y = math.Round(acemenupanel.AmmoPanelConfig["Crate_Width"], 1 )
			local Z = math.Round(acemenupanel.AmmoPanelConfig["Crate_Height"], 1)

			local Id = X .. ":" .. Y .. ":" .. Z

			acemenupanel.AmmoData["Id"] = Id
			RunConsoleCommand( "acemenu_id", Id )

		end

		self:UpdateAttribs()

	end

	function PANEL:AmmoSelect( Blacklist )

	if not acemenupanel.CustomDisplay then return end
	if not Blacklist then Blacklist = {} end

	if not acemenupanel.AmmoData then

		acemenupanel.AmmoData               = {}
		acemenupanel.AmmoData["Id"]         = "10:10:10"  --default Ammo dimension on list
		acemenupanel.AmmoData["IdLegacy"]   = "Shell100mm"
		acemenupanel.AmmoData["Type"]       = "Ammo"
		acemenupanel.AmmoData["Classname"]  = Classes.GunClass["MG"]["name"]
		acemenupanel.AmmoData["ClassData"]  = Classes.GunClass["MG"]["id"]
		acemenupanel.AmmoData["Data"]       = ACFEnts["Guns"]["12.7mmMG"]["round"]
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
				RunConsoleCommand( "acemenu_id", acemenupanel.AmmoData["Id"] )
			else
				CreateIdForCrate( MainPanel )
			end

			MainPanel:UpdateAttribs()

		end

		CrateOldPanel:AddItem(LegacyCheck)

		local AmmoComboBox = vgui.Create( "DComboBox", CrateOldPanel )	--Every display and slider is placed in the Round table so it gets trashed when selecting a new round type
		AmmoComboBox:SetSize(acemenupanel.CustomDisplay:GetWide(), 30)

		for Key, Value in pairs( ACFEnts.Ammo ) do

			AmmoComboBox:AddChoice( Value.id , Key ) --Creates the list

		end

		AmmoComboBox.OnSelect = function( _ , _ , data )	-- calls the ID of the list
			if acemenupanel.AmmoPanelConfig["LegacyAmmos"] then
			RunConsoleCommand( "acemenu_id", data )
			acemenupanel.AmmoData["Id"] = data
			end

			acemenupanel.AmmoData["IdLegacy"] = data

			if acemenupanel.CData.CrateDisplay then

			local cratemodel = ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].model
			acemenupanel.CData.CrateDisplay:SetModel(cratemodel)
			acemenupanel:CPanelText("CrateDesc", ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

			end

			MainPanel:UpdateAttribs()

		end

		AmmoComboBox:SetText(acemenupanel.AmmoData["IdLegacy"])
		RunConsoleCommand( "acemenu_id", acemenupanel.AmmoData["Id"] )

		CrateOldPanel:AddItem(AmmoComboBox)

	--===========================================================================================
	-----Creating the Model display
	--===========================================================================================

		--Used to create the general model display
		if not acemenupanel.CData.CrateDisplay then

			acemenupanel:CPanelText("CrateDesc", ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].desc, nil, CrateOldPanel)

			acemenupanel.CData.CrateDisplay = vgui.Create( "DModelPanel", CrateOldPanel )
			acemenupanel.CData.CrateDisplay:SetSize(acemenupanel.CustomDisplay:GetWide(),acemenupanel.CustomDisplay:GetWide() / 2)
			acemenupanel.CData.CrateDisplay:SetCamPos( Vector( 250, 500, 250 ) )
			acemenupanel.CData.CrateDisplay:SetLookAt( Vector( 0, 0, 0 ) )
			acemenupanel.CData.CrateDisplay:SetFOV( 10 )
			acemenupanel.CData.CrateDisplay:SetModel(ACFEnts.Ammo[acemenupanel.AmmoData["IdLegacy"]].model)
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

		for Key, Value in pairs( ACFEnts.Guns ) do

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

	for Key, Value in pairs( ACFEnts.Guns ) do

		if acemenupanel.AmmoData["ClassData"] == Value.gunclass then
			acemenupanel.CData.CaliberSelect:AddChoice( Value.id , Key )
		end

	end

	acemenupanel.CData.CaliberSelect.OnSelect = function( _ , _ , data )
		acemenupanel.AmmoData["Data"] = acemenupanel.WeaponData["Guns"][data]["round"]
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

function ACE_CPanelText(Name, Desc, Font, Panel)

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
	ACE_CPanelText(Name, Desc, Font, Panel)
end