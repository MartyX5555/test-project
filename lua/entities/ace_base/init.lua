AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local ErrorMsg = "Wiremod is not installed on the Server. Check ACE has the required dependencies before using! Aborting..."

-- Wire inputs/outputs
function ENT:SetWireInputs(Inputs)
	if not WireLib then ErrorNoHaltWithStack(ErrorMsg) return end
	return WireLib.CreateInputs(self, Inputs)
end

function ENT:SetWireOutputs(Outputs, Types, Descs)
	if not WireLib then ErrorNoHaltWithStack(ErrorMsg) return end
	if Types then
		return WireLib.CreateSpecialOutputs(self, Outputs, Types, Descs)
	end
	return WireLib.CreateOutputs(self, Outputs)
end

function ENT:TriggerWireOutput(name, value)
	if not WireLib then return end
	WireLib.TriggerOutput(self, name, value)
end

function ENT:SetWireOverlayText(txt)
	if not WireLib or not self.SetOverlayText then return end
	self:SetOverlayText(txt)
end
