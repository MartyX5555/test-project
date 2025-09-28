local ACE = ACE or {}
local Guidance = {}

Guidance.Name = "Dumb"
Guidance.desc = "This guidance package is empty and provides no control."

-- Original idea: skip functions if its not going to be used.

function Guidance:Init()
end

function Guidance:Configure()
end

function Guidance:GetGuidance()
	return {}
end

function Guidance:GetDisplayConfig()
	return {}
end

ACE.RegisterGuidance( Guidance.Name, Guidance )