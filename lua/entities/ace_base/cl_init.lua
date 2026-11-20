include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local InfoWhileSeated = CreateClientConVar("ace_infowhileseated", 0, true, false)

-- Copied from base_wire_entity: DoNormalDraw's notip arg isn't accessible from ENT:Draw defined there.
function ENT:Draw(flags)
	local lply = LocalPlayer()
	local hideBubble = not InfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	if BaseClass and BaseClass.DoNormalDraw then
		BaseClass.DoNormalDraw(self, hideBubble, hideBubble, flags)
	else
		self:DrawModel(flags)
	end

	if Wire_Render then
		Wire_Render(self)
	end

	if Wire_DrawTracerBeam and self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam(self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false)
	end
end
