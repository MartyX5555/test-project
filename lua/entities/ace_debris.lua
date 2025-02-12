
AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Debris"

cleanup.Register( "Debris" )

if CLIENT then return end

local ACE = ACE or {}
if not ACE.Debris then
	ACE.Debris = {}
end

function ENT:Initialize()

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )

	local phys = self:GetPhysicsObject()

	if IsValid( phys ) then

		phys:Wake()
		phys:SetMaterial("jeeptire")

	end

	ACE.Debris[self] = true

	local DebrisLifespan = ACE.DebrisLifeTime
	if DebrisLifespan > 0 then
		timer.Simple(DebrisLifespan, function()
			if not IsValid(self) then return end
			self:Remove()
		end)
	end
end

function ENT:OnRemove()
	ACE.Debris[self] = nil
end