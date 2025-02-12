local ACE = ACE or {}
local ClassName = "Dumb"

local this = ACE.Guidance[ClassName] or inherit.NewBaseClass()
ACE.Guidance[ClassName] = this

this.Name = ClassName
this.desc = "This guidance package is empty and provides no control."

function this:Init()
end

function this:Configure()
end

function this:GetGuidance(missile)

	self:PreGuidance(missile)

	return self:ApplyOverride(missile) or {}
end

function this:PreGuidance(_)
end

function this:ApplyOverride()
end

function this:GetDisplayConfig()
	return {}
end
