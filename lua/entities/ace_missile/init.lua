AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local GunTable	= ACE.Weapons.Guns
--local GuidanceTable = ACE.Guidance
--local FuseTable	= ACE.Fuse

function ENT:Initialize()

	self.Detonated = false

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(100)
		phys:EnableMotion(false)
	end

end

local function RocketThrust( Missile )
	return Missile.Thrust * Missile.ThrustRatio
end

local function ConfigureFlightParameters( Missile )

	Missile.DVel = vector_origin
	Missile.NextPos = Missile:GetPos()
	Missile.RotAxis = vector_origin
	Missile.LastThink = CurTime()


end

function ENT:BurnFuel()

	local Diff = self.MotorFuel - (self.MotorFuel - self.BurnRate)

	self.MotorFuel = self.MotorFuel - self.BurnRate --Should be same as BurnRate. When the fuel runs out, the thrust value is cut according to a ratio.
	self.ThrustRatio = Diff / self.BurnRate

end

function ENT:Launch()

	self.Launched        = true

	self.InRack = true
	self.CanDetonate = false
	self.PodLengthDistance = 126 or 0 -- 126 will be a value coming from the plataform if the delay ignition is 0. Otherwise, its 0

	local MissileData = GunTable[self.BulletData.Id]
	local MissileRound = MissileData.round
	local BulletData = self.BulletData

	self.Maxlength       = MissileData.length
	self.Thrust          = 1000--MissileRound.thrust
	self.ThrustRatio  	 = 1
	self.CritSpeed 		 = 10000 -- Define the minimal speed for the components to work. Increasing it means you must increase
	self.MaxFin          = 50000--MissileRound.finmul
	self.Resistance      = 0.1--MissileData.rotmult
	self.BurnRate        = MissileRound.burnrate
	self.MaxMotorFuel    = BulletData.PropMass / (MissileRound.burnrate / 1000)
	self.MotorFuel       = self.MaxMotorFuel

	self.TraceFilter = { self.Launcher, self }

	self:SetModel( MissileData.round.model or MissileData.model )

	if IsValid(self:GetParent()) then
		self:SetParent(nil)
	end

	ConfigureFlightParameters( self )

	debugoverlay.Cross( self:GetPos() + Vector(0,0,5), 30, 1, Color( 0, 255, 34), true )

end

function ENT:PerformTrace()

	if not self.Launched then return end
	if self.InRack then return end

	local tr = {}
	tr.start = self:GetPos() - self:GetForward() * (self.Maxlength / 5)
	tr.endpos = self.NextPos + self:GetForward() * (self.Maxlength / 5)
	tr.filter = self.TraceFilter
	local trace = util.TraceLine(tr)

	if trace.Hit then
		debugoverlay.Line( tr.start, tr.endpos, 1, Color( 255, 0, 0), true )

		if IsValid(trace.Entity) then
			trace.Entity:SetColor(Color(255,0,0))
		end

		self:Detonate()
	else
		debugoverlay.Line( tr.start, tr.endpos, 1, Color( 0, 0, 255), true )
	end

end

--Purpose: perform the flight calcs while the missile is inside of the tube. No gravity and position relative to tube is required here.
local function FlightInRack( Missile, _, DeltaTime )

	local Launcher = Missile.Launcher

	Missile.LCurPos = Missile.LCurPos or Launcher:WorldToLocal(Missile:GetPos())

	-- Cualquier code para definir Dir deberia ir aca
	-- Final force sum
	local RocketDir = Vector(1,0,0) * Missile.Thrust
	local Vel = Missile.DVel + RocketDir  * DeltaTime
	local LNextPos = Missile.LCurPos + Vel * DeltaTime print(LNextPos)

	Missile.DVel = Vel
	Missile.NextPos = Launcher:LocalToWorld( LNextPos )
	Missile.LCurPos = LNextPos

	debugoverlay.Cross( Missile.NextPos, 10, 5, Color(255,0,0), true )

	Missile:PerformTrace()

	Missile:SetPos(Missile.NextPos)
	Missile:SetAngles(Launcher:GetAngles())

	if LNextPos:LengthSqr() > Missile.PodLengthDistance ^ 2 then
		Missile.InRack = false

		if IsValid(Launcher) then

			Missile.DVel:Rotate(Launcher:GetAngles())

			Missile.DVel = Missile.DVel + Launcher:GetVelocity()
			-- Use the global velocity as needed
			-- ...
		end

	end

end

--The real flight calc is here. I recycled some parts from ACF-2 missile code, but well structured for future part replacement.
local function RealFlight( Missile, Speed, DeltaTime )

	Missile.CanDetonate = true

	local Dir = Missile:GetForward()
	local CurPos = Missile:GetPos()
	local VelNorm = Missile.DVel / Speed
	local Gravity = physenv.GetGravity()

	-- Cualquier code para definir Dir deberia ir aca
	local CritSpeed = Missile.CritSpeed
	local Drag = Dir * -500

	do
		local DirAng = Dir:Angle()
		local GravFactor = 0.1
		local Ratio = math.max( (CritSpeed - Speed) / CritSpeed, 0.1 ) -- keep 10% of the GravFactor to affect the missile anyways.
		local pitchAdjustment = -GravFactor * Ratio print(pitchAdjustment)
		DirAng:RotateAroundAxis(DirAng:Right(), pitchAdjustment)
		Dir = DirAng:Forward()
	end


	local FinRatio = math.min(Speed / CritSpeed, 1) --print("FINRATIO:", FinRatio)
	local FinPower = Missile.MaxFin * FinRatio

	-- Fin force calculation. A modified extract from ACF2 missile code.
	local Up = Dir:Cross(Missile.DVel):Cross(Dir):GetNormalized()
	local Dot1 = Up * VelNorm
	local DotSimple = Dot1.x + Dot1.y + Dot1.z
	local Fin = -Up * DotSimple * FinPower

	-- Final force sum
	local RocketDir = Dir * RocketThrust( Missile )
	local Vel = Missile.DVel + (RocketDir + Gravity + Drag + Fin ) * DeltaTime

	local NextPos = CurPos + Vel * DeltaTime

	Missile.DVel = Vel
	Missile.NextPos = NextPos

	Missile:PerformTrace()

	Missile:SetPos(NextPos)
	Missile:SetAngles(Dir:Angle())

end

function ENT:PerformFlight()
	if not self.Launched then return end

	local DeltaTime = FrameTime()

	-- GLOBAL variables
	local Speed = math.max(self.DVel:Length(), 1) --finally, a unified way to get the speed

	if self.InRack then
		FlightInRack( self, Speed, DeltaTime )
	else
		RealFlight( self, Speed, DeltaTime )
	end

	self:BurnFuel()

end

function ENT:Detonate()

	self.Detonated = true
	self:Remove()

end

--===========================================================================================
----- Think
--===========================================================================================
function ENT:Think()

	self:PerformFlight()

	self:NextThink(CurTime())
	return true
end

function ENT:OnRemove()

	print("DELETED")

end
