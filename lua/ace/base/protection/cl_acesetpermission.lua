
local Menu = {}

-- the category the menu goes under
Menu.Category = "ACE"


-- the name of the item
Menu.Name = "Set Permission Mode"

-- the convar to execute when the player clicks on the tab
Menu.Command = ""



local Permissions = {}

local PermissionModes   = {}
local CurrentPermission = "default"
local DefaultPermission = "none"
local ModeDescTxt
local ModeDescDefault   = "Can't find any info for this mode!"
local currentMode
local currentModeTxt    = "\nThe current damage permission mode is %s."
local introTxt          = "Damage Permission Modes change the way that ACE damage works.\n\nYou can change the DP mode if you are an admin."

local statusTxt         = "\nCurrent Protection status:"
local condition         = "Unknown"

local cvarstat = false

local list
local button
local button2
local status
local status2

function ACE_ReceiveDPStatus()

	cvarstat = net.ReadBool() or false
	Permissions:Update()

end
net.Receive( "ACE_DPStatus", ACE_ReceiveDPStatus )

net.Receive("ACE_refreshpermissions", function()

	PermissionModes	= net.ReadTable()
	CurrentPermission	= net.ReadString()
	DefaultPermission	= net.ReadString()

	Permissions:Update()

end)

function Menu.MakePanel(Panel)

	Permissions:RequestUpdate()

	if not PermissionModes then return end

	Panel:SetName("Permission Modes")
	Panel:AddItem(txt)

	local txt = Panel:Help(introTxt)
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	txt:SizeToContents()
	Panel:AddItem(txt)

	status = Panel:Help(statusTxt)
	status:SetFont("DermaDefaultBold")
	status:SetContentAlignment( TEXT_ALIGN_CENTER )
	status:SizeToContents()
	Panel:AddItem(status)

	status2 = Panel:Help(condition)
	status2:SetFont("DermaDefaultBold")
	status2:SetContentAlignment( TEXT_ALIGN_CENTER )
	status2:SizeToContents()
	Panel:AddItem(status2)

	currentMode = Panel:Help(string.format(currentModeTxt, CurrentPermission))
	currentMode:SetContentAlignment( TEXT_ALIGN_CENTER )
	currentMode:SetFont("DermaDefaultBold")
	currentMode:SizeToContents()

	Panel:AddItem(currentMode)


	if LocalPlayer():IsAdmin() then

		list = vgui.Create("DListView")
		list:AddColumn("Mode")
		list:AddColumn("Active")
		list:AddColumn("Map Default")
		list:SetMultiSelect(false)
		list:SetSize(30,100)

		for permission in pairs(PermissionModes) do
			list:AddLine(permission, "", "")
		end

		for id,line in pairs(list:GetLines()) do
			if line:GetValue(1) == CurrentPermission then
				list:GetLine(id):SetValue(2,"Yes")
			end
			if line:GetValue(1) == DefaultPermission then
				list:GetLine(id):SetValue(3,"Yes")
			end
		end

		list.OnRowSelected = function(panel, line)
			if ModeDescTxt then
				ModeDescTxt:SetText(PermissionModes[panel:GetLine(line):GetValue(1)] or ModeDescDefault)
				ModeDescTxt:SizeToContents()
			end
		end
		Panel:AddItem(list)

		local txt = Panel:Help("What this mode does:")
		txt:SetContentAlignment( TEXT_ALIGN_CENTER )
		txt:SetFont("DermaDefaultBold")
		txt:SizeToContents()
		Panel:AddItem(txt)

		ModeDescTxt = Panel:Help(PermissionModes[CurrentPermission] or ModeDescDefault)
		ModeDescTxt:SetContentAlignment( TEXT_ALIGN_CENTER )
		ModeDescTxt:SizeToContents()
		Panel:AddItem(ModeDescTxt)

		--Button 1
		button = Panel:Button("Set Permission Mode")
		button.DoClick = function()
			local line = list:GetLine(list:GetSelectedLine())
			if not line then
				Permissions:RequestUpdate()
				return
			end

			local mode = line and line:GetValue(1)
			RunConsoleCommand("ACE_setpermissionmode",mode)
		end
		Panel:AddItem(button)

		--Button 2
		button2 = Panel:Button("Set Default Permission Mode")
		button2.DoClick = function()
			local line = list:GetLine(list:GetSelectedLine())
			if not line then
				Permissions:RequestUpdate()
				return
			end

			local mode = line and line:GetValue(1)
			RunConsoleCommand("ACE_setdefaultpermissionmode",mode)
		end
		Panel:AddItem(button2)
	end
end


function Permissions:Update()

	if IsValid(list) then
		for id,line in pairs(list:GetLines()) do
			if line:GetValue(1) == CurrentPermission then
				list:GetLine(id):SetValue(2,"Yes")
			else
				list:GetLine(id):SetValue(2,"")
			end
			if line:GetValue(1) == DefaultPermission then
				list:GetLine(id):SetValue(3,"Yes")
			else
				list:GetLine(id):SetValue(3,"")
			end
		end
	end

	if IsValid(currentMode) then
		currentMode:SetText(string.format(currentModeTxt, CurrentPermission))
		currentMode:SizeToContents()
	end

	if IsValid(button) then
		button:SetEnabled( cvarstat and CPPI )
		button2:SetEnabled( cvarstat and CPPI )
	end

	if IsValid(status2) then

		condition = ""

		local color	= Color(0,100,0)
		local warning	= false

		if not cvarstat or not CPPI then
			warning = true
			color = Color(255,0,0)

			if not cvarstat then
				condition	= condition .. "Disabled by the server. "
			end

			if not CPPI then
				condition	= condition .. "No CPPI found."
			end

		end

		if not warning then
			condition = "Active"
		end

		status2:SetText( condition )
		status2:SetColor( color )
		status2:SizeToContents()

	end

end


function Permissions:RequestUpdate()
	net.Start("ACE_refreshpermissions")
		net.WriteBit(true)
	net.SendToServer()
end


function Menu.OnSpawnmenuOpen()
	Permissions:RequestUpdate()
end



local cat = Menu.Category
local item = Menu.Name
local var  =  Menu.Command
local open = Menu.OnSpawnmenuOpen
local panel = Menu.MakePanel
local hookname = string.Replace(item," ","_")


hook.Add("SpawnMenuOpen", "ACE.SpawnMenuOpen." .. hookname, open)


hook.Add("PopulateToolMenu", "ACE.PopulateToolMenu." .. hookname, function()
	spawnmenu.AddToolMenuOption("Utilities", cat, item, item, var, "", panel)
end)
