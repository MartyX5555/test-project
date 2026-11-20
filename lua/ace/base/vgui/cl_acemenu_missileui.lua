
function ACEMissiles_MenuSlider(config, controlGroup, combo, conCmd, min, max)

	local slider = vgui.Create( "DNumSlider" )
		slider.Label:SetText(config.DisplayName or "")
		slider.Label:SetDark(true)
		slider:SetMin( min )
		slider:SetMax( max )
		slider:SetValue( config.Min )
		slider:SetDecimals( 2 )
		slider.Configurable = config

		slider.GetConfigValue = function( slider )
			local config = slider.Configurable
			return math.Round(math.Clamp(slider:GetValue(), config.Min, config.Max), 3)
		end

		slider.OnValueChanged = function()
			ACEMissiles_SetCommand(combo, controlGroup, conCmd)
		end

		controlGroup[#controlGroup + 1] = slider

	return slider

end

function ACEMissiles_SetCommand(combo, controlGroup, conCmd)

	if not controlGroup then
		local name = tostring(combo:GetValue())
		print("cvars:", conCmd, name)
		ACE.MenuSendTableValue("Data", "RoundData", conCmd, name)
	else
		local name = tostring(combo:GetValue())
		local kvString = ""

		if #controlGroup > 0 then
			local i = 1
			repeat
				local control = controlGroup[i]
				kvString = kvString .. ":" .. control.Configurable.CommandName .. "=" .. tostring(control:GetConfigValue())
				i = i + 1
			until i > #controlGroup
		end
		ACE.MenuSendTableValue("Data", "RoundData", conCmd,  name .. tostring(kvString))
	end

end

local ACEMissiles_ConfigurationFactory = {
	number = function(config, controlGroup, combo, conCmd, gundata)
				local min = config.MinConfig and gundata.armdelay or config.Min
				return ACEMissiles_MenuSlider(config, controlGroup, combo, conCmd, min, config.Max)
			end
}

function ACEMissiles_CreateMenuConfiguration(tbl, combo, conCmd, existingPanel, gundata)

	local panel = existingPanel or vgui.Create("DScrollPanel")

	panel:Clear()

	if not tbl.Configurable or #tbl.Configurable < 1 then
		panel:SetTall(0)
		return panel
	end

	local controlGroup = {}
	local height = 0

	for _, config in pairs(tbl.Configurable) do
		local control = ACEMissiles_ConfigurationFactory[config.Type](config, controlGroup, combo, conCmd, gundata)
		control:Dock(TOP)
		control:DockMargin(6, 0, 6, 0)
		panel:Add(control)
		height = height + control:GetTall()
	end

	panel:SetTall(height + 2)

	combo.ControlGroup = controlGroup

	return panel
end