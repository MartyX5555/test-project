--[[]
do
	local dupefile = ""
	local data = file.Read(dupefile, "DATA")
	local success, dupe, info, moreinfo = AdvDupe2.Decode(data)

	PrintTable(dupe)
end
]]

local CurrentPath = ""

-- This pattern looks for a dot followed by any sequence of alphanumeric characters at the end of the string
local function GetType(path)
	local bool = string.match(path, "^.+(%..+)$")
	local Type = bool and "file" or "folder"

	return Type
end

function ACE_OpenDupeFixerMenu()

	local Panel  = vgui.Create("DFrame") -- The name of the panel we don't have to parent it.
	Panel:SetTitle("Dupe Fixer") -- Set the title in the top left to "Derma Frame".
	Panel:SetSize(500, 400) -- Set the size to 300x by 200y.
	Panel:Center()

	Panel:MakePopup() -- Makes your mouse be able to move around.

	local Dtree = vgui.Create("DTree", Panel)
	Dtree:SetSize(Panel:GetWide() / 2, Panel:GetTall())
	Dtree:Dock(RIGHT)

	local node = Dtree:AddNode( "Advanced Duplicator 2")
	node:MakeFolder( "advdupe2", "DATA", true )

	local LeftPanel = vgui.Create("DPanel", Panel)
	LeftPanel:SetSize(Panel:GetWide() / 2, Panel:GetTall())
	LeftPanel:DockPadding(20, 20, 20, 20)
	LeftPanel:Dock(FILL)

	local ExecuteButton = vgui.Create("DButton", LeftPanel)
	ExecuteButton:Dock(TOP)
	ExecuteButton:SetText( "Say hi" )					-- Set the text on the button

	ExecuteButton:SetSize( LeftPanel:GetWide(), 30 )					-- Set the size


	function Dtree:OnNodeSelected( Node )
		CurrentPath = Node:GetFolder() or Node:GetFileName()
		print("selected: ", GetType(CurrentPath) ,CurrentPath)
	end

	function ExecuteButton:DoClick()
		local data = file.Read(CurrentPath, "DATA")
		local _, dupe, _, _ = AdvDupe2.Decode(data)

		for k, EntityData in pairs(dupe.Entities) do
			print("Entity: ", k)
			PrintTable(EntityData)
		end
	end

end
ACE_OpenDupeFixerMenu()