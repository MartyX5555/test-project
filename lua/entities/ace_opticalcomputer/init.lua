AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:SpawnFunction( _, trace )

	if not trace.Hit then return end

	local SPos = (trace.HitPos + Vector(0,0,1))

	local ent = ents.Create( "ace_opticalcomputer" )
	ent:SetPos( SPos )
	ent:Spawn()
	ent:Activate()

	return ent
end

local ACE = ACE or {}
if not ACE.Opticals then
	ACE.Opticals = {}
end

function ENT:Initialize()

	self:SetModel( "models/props_lab/monitor01b.mdl" )
	self:SetMoveType(MOVETYPE_VPHYSICS);
	self:PhysicsInit(SOLID_VPHYSICS);
	self:SetUseType(SIMPLE_USE);
	self:SetSolid(SOLID_VPHYSICS);

end

function ENT:InitializeOnCollector()
	ACE.Opticals[self] = true
end

function ENT:OnRemoveCollectorData()
	ACE.Opticals[self] = nil
end

function ENT:Think()
	self:GetPhysicsObject():SetMass(65)
	self:NextThink(curTime() + 0.5)
	return true
end










