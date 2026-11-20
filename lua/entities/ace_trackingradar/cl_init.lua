include("shared.lua")

function ACETrackRadarGUICreate( Table )

	if not (ACE and next(ACE.Classes) and next(ACE.Classes.Radar) and Table) then
		acemenupanel:CPanelText("Error1", "There was an error trying to gather the information for this sensor", "DermaDefaultBold")
		acemenupanel:CPanelText("Error3", "If the problem persists, report it to the server owner as soon as possible!")
		return
	end

	acemenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	local RadarMenu = acemenupanel.CData.DisplayModel

	RadarMenu = vgui.Create( "DModelPanel", acemenupanel.CustomDisplay )
		RadarMenu:SetModel( Table.model )
		RadarMenu:SetCamPos( Vector( 250, 500, 250 ) )
		RadarMenu:SetLookAt( Vector( 0, 0, 0 ) )
		RadarMenu:SetFOV( 20 )
		RadarMenu:SetSize(acemenupanel:GetWide(),acemenupanel:GetWide())
		RadarMenu.LayoutEntity = function() end
	acemenupanel.CustomDisplay:AddItem( RadarMenu )

	acemenupanel:CPanelText("ClassDesc", ACE.Classes.Radar[Table.class].desc)
	acemenupanel:CPanelText("GunDesc", Table.desc)
	acemenupanel:CPanelText("ViewCone", "View cone : " .. ((Table.viewcone or 180) * 2) .. " degs")
	acemenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. " kg")
	--acemenupanel:CPanelText("GunParentable", "\nThis radar can be parented\n","DermaDefaultBold")

	acemenupanel.CustomDisplay:PerformLayout()

end


