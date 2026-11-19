--[[
	ACE Missile Entity (Server)

	Flight state architecture:
	- State 1: FlightInRack (constrained local-space motion along launcher rail/tube with gravity assist and safe Dismount timeout)
	- State 2: RealFlight (free-flight integration, guidance, motor burnout, impact trace, and fuse evaluation)

	Future ACE-Project-Team parity roadmap (intended to replace RealFlight internals without adding state branches):
	- PID + thrust-vectoring (thrusterturnrate) steering controller and predictiondelay straight-running phase.
	- Two-stage propulsion (booster acceleration/duration/delay + main sustainer motor).
	- Underwater/torpedo thrust modes (waterthrusttype 0-4) and buoyancy physics (WaterZHeight).
	- Inertial target prediction (HasInertial), launcher datalink fallback (HasDatalink), and ECM jamming (IsJammed).
	- Rail-active guidance preview and launcher scuttle support.
]]--

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local GunTable      = ACE.Weapons.Guns
local GuidanceTable = ACE.Guidance
local FuseTable     = ACE.Fuse

local function CreateSensorInstance(sensorClass)
	if not sensorClass then return nil end

	local mt = getmetatable(sensorClass)
	if mt and mt.__call then
		return sensorClass()
	end

	return table.Copy(sensorClass)
end

local function GetLauncherVelocity(launcher)
	if not IsValid(launcher) then return vector_origin end

	local parent = ACE.GetPhysicalParent(launcher)
	if IsValid(parent) then
		return parent:GetVelocity()
	end

	return launcher:GetVelocity()
end

function ENT:Initialize()
	self.BaseClass.Initialize(self)

	self.Inputs = WireLib.CreateInputs(self, { "Detonate" })
	self.ThinkDelay = 0.1
	self.BulletData = {}
	self.RoundData = {}

	self.DetonateOffset = nil
	self.SpecialDamage = true	-- If true needs a special ACE_OnDamage function
	self.SpecialHealth = true	-- If true needs a special ACE_Activate function
	self.DoNotDuplicate = true

	self.Launcher = self.Launcher or NULL
	self.ForceTdelay = self.ForceTdelay or 0
	self.TrackDelay = 0
	self.CanTrack = false		-- Used when the missile has waited the required time to guide
	self.Timer = false

	self.InRack = false
	self.InRackTime = 0
	self.MaxInRackTime = ACE.MissileInRackTimeout or 2
	self.PodLengthDistance = 0
	self.Motor = 0
	self.NoThrust = false

	self.CutoutTime = CurTime() + 10000

	self:SetNWFloat("LightSize", 0)
end

function ENT:InitializePhysics(model)
	if model then
		self:SetModel(model)
	end

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableGravity(false)
		phys:EnableMotion(false)
		self.PhysObj = phys
	end

	return phys
end

--===========================================================================================
----- BulletData functions
--===========================================================================================
function ENT:SetMissileData(BulletData, RoundData)
	if not istable(BulletData) or not BulletData.Id then return end

	local bdata = table.Copy(BulletData)
	local gun = GunTable[bdata.Id]
	if not gun then return end

	local roundWeight = ACE.GetGunValue(bdata, "weight") or 10

	bdata.Entity = self
	bdata.Crate = self:EntIndex()
	bdata.Owner = bdata.Owner or ACE.GetEntityOwner(self)
	self:NetworkBulletData(bdata)

	self.RoundData = istable(RoundData) and table.Copy(RoundData) or {}
	self.BulletData = bdata
	self.RoundWeight = roundWeight
	self.TrackDelay = gun.guidelay or 0
	self.NoThrust = ACE.GetGunValue(bdata, "nothrust") or false

	self:PrepareMissileSensors()

	local model = ACE.GetGunValue(bdata, "model")
	local phys = self:InitializePhysics(model)
	if IsValid(phys) then
		phys:SetMass(roundWeight)
	end

	self:UpdateBodygroups()
	self:UpdateSkin()
end

function ENT:SetCrateData(Crate)
	if not IsValid(Crate) then return end

	self:SetMissileData(Crate.BulletData, Crate.RoundData)
	self:SetColor(Crate:GetColor())
end

--===========================================================================================
----- Guidance and Fuse functions
--===========================================================================================
function ENT:SetGuidance(guidance)
	local inst = CreateSensorInstance(guidance)
	self.Guidance = inst
	if inst and inst.Init then
		inst:Init()
	end
	if inst and inst.Configure then
		inst:Configure(self)
	end
	return inst
end

function ENT:SetFuse(fuse)
	local inst = CreateSensorInstance(fuse)
	self.Fuse = inst
	if inst and inst.Configure then
		inst:Configure(self, self.Guidance or self:SetGuidance(GuidanceTable.Dumb))
	end
	return inst
end

function ENT:PrepareMissileSensors()
	local RoundData = self.RoundData or {}
	local guidance = RoundData.Guidance
	local fuse = RoundData.Fuse

	if guidance then
		guidance = ACEM.CreateConfigurable(guidance, GuidanceTable, self.BulletData, "guidance")
		if guidance then
			self:SetGuidance(guidance)
		end
	end

	if fuse then
		fuse = ACEM.CreateConfigurable(fuse, FuseTable, self.BulletData, "fuses")
		if fuse then
			self:SetFuse(fuse)
		end
	end
end

function ENT:NetworkBulletData(BulletData)
	self:SetNWInt("Caliber", BulletData.Caliber or 10)
	self:SetNWInt("ProjMass", BulletData.ProjMass or 10)
	self:SetNWInt("FillerMass", BulletData.FillerMass or 0)
	self:SetNWInt("DragCoef", BulletData.DragCoef or 1)
	self:SetNWString("AmmoType", BulletData.Type or "AP")
	self:SetNWInt("Tracer", BulletData.Tracer or 0)

	local col = BulletData.Colour or self:GetColor()
	self:SetNWVector("Color", Vector(col.r, col.g, col.b))
	self:SetNWVector("TracerColour", Vector(col.r, col.g, col.b))
end

--===========================================================================================
----- Flight State Modules (RealFlight helpers + FlightInRack)
--===========================================================================================
local function UpdateGuidance(Missile, Pos, Dir, Speed, DeltaTime)
	local Guidance = Missile.Guidance:GetGuidance(Missile)
	local TargetPos = Missile.CanTrack and Guidance.TargetPos or nil
	local Tdelay = Missile.ForceTdelay >= Missile.TrackDelay and Missile.ForceTdelay or Missile.TrackDelay

	-- Track delay calculation
	if Guidance.TargetPos then
		if Tdelay > Missile.TrackDelay then
			if not Missile.Timer then
				Missile.Timer = true

				timer.Simple(Tdelay, function()
					if not IsValid(Missile) then return end
					Missile.CanTrack = true
				end)
			end
		else
			Missile.CanTrack = true
		end
	end

	if TargetPos then
		local missileInac = Missile.guidanceInac
		local Dist = Pos:Distance(TargetPos)
		TargetPos = TargetPos + Vector(0, 0, Missile.Gravity * Dist / 100000) + Vector(math.random(-missileInac, missileInac), math.random(-missileInac, missileInac), math.random(-missileInac, missileInac))

		local LOS = (TargetPos - Pos):GetNormalized()
		local LastLOS = Missile.LastLOS
		local NewDir = Dir
		local DirDiff = 0

		if LastLOS then
			local Agility = Missile.Agility
			local SpeedMul = math.min((Speed / DeltaTime / Missile.MinimumSpeed) ^ 3, 1)

			local LOSDiff = math.deg(math.acos(math.Clamp(LastLOS:Dot(LOS), -1, 1))) * 20
			local MaxTurn = Agility * SpeedMul * 5

			if LOSDiff > 0.01 and MaxTurn > 0.1 then
				local LOSNormal = LastLOS:Cross(LOS):GetNormalized()
				local Ang = NewDir:Angle()
				Ang:RotateAroundAxis(LOSNormal, math.min(LOSDiff, MaxTurn))
				NewDir = Ang:Forward()
			end

			DirDiff = math.deg(math.acos(math.Clamp(NewDir:Dot(LOS), -1, 1)))
			if DirDiff > 0.01 then
				local DirNormal = NewDir:Cross(LOS):GetNormalized()
				local TurnAng = math.min(DirDiff, MaxTurn) / 10
				local Ang = NewDir:Angle()
				Ang:RotateAroundAxis(DirNormal, TurnAng)
				NewDir = Ang:Forward()
				DirDiff = DirDiff - TurnAng
			end
		end

		-- FOV check
		if not Guidance.ViewCone or DirDiff <= Guidance.ViewCone then
			Dir = NewDir
		end
		Missile.LastLOS = LOS
	else
		local DirAng = Dir:Angle()
		local VelNorm = Missile.LastVel / Speed
		local AimDiff = Dir - VelNorm
		local DiffLength = AimDiff:Length()

		if DiffLength >= 0.001 and DiffLength < 1.95 and CurTime() > Missile.GhostPeriod then
			local Torque = DiffLength * Missile.TorqueMul * Speed * Missile.RotMultipler
			local AngVelDiff = Torque / Missile.Inertia * DeltaTime
			local DiffAxis = AimDiff:Cross(Dir):GetNormalized()

			Missile.RotAxis = Missile.RotAxis + DiffAxis * AngVelDiff
		end

		Missile.RotAxis = Missile.RotAxis * 0.99

		DirAng:RotateAroundAxis(Missile.RotAxis, Missile.RotAxis:Length())
		Dir = DirAng:Forward()

		Missile.LastLOS = nil
	end

	return Dir
end

local function UpdateMotorState(Missile, Time)
	if Time > Missile.CutoutTime or (Missile:WaterLevel() == 3 and Missile.NotDrownable) then
		if Missile.Motor ~= 0 then
			Missile.Motor = 0
			Missile:StopParticles()
			Missile:SetNWFloat("LightSize", 0)
		end

		-- 5 times extra drag underwater
		return (Missile:WaterLevel() == 3 and Missile.NotDrownable) and (Missile.DragCoef * 5) or Missile.DragCoef
	end

	return Missile.DragCoefFlight
end

local function IntegrateFlightVelocity(Missile, Dir, LastVel, DragCoef, DeltaTime)
	local Vel = LastVel + (Dir * Missile.Motor - Vector(0, 0, Missile.Gravity)) * ACE.VelScale * DeltaTime ^ 2
	local Up = Dir:Cross(Vel):Cross(Dir):GetNormalized()
	local Speed = math.max(Vel:Length(), 0.0001)
	local VelNorm = Vel / Speed
	local DotSimple = Up.x * VelNorm.x + Up.y * VelNorm.y + Up.z * VelNorm.z

	Vel = Vel - Up * Speed * DotSimple * Missile.FinMultiplier

	local SpeedSq = Vel:LengthSqr()
	local Drag = Vel:GetNormalized() * (DragCoef * SpeedSq) / ACE.DragDiv * ACE.VelScale

	return Vel - Drag
end

local function PerformImpactAndFuseCheck(Missile, Pos, EndPos, Dir, Vel, DeltaTime, Time)
	local tracedata = {
		start = Pos,
		endpos = EndPos,
		filter = Missile.Filter,
		mins = vector_origin,
		maxs = vector_origin
	}

	-- Becomes volumetric once ghosting is over to avoid expensive hull traces inside launch clearance
	if Time > Missile.GhostPeriod then
		local MRadius = (Missile.BulletData.Caliber / 2) * 0.5
		local maxs = Vector(MRadius, MRadius, MRadius)
		tracedata.mins = -maxs
		tracedata.maxs = maxs
	end

	local trace = util.TraceHull(tracedata)

	if trace.Hit then
		local IsPart = false
		local HitPos = trace.HitPos
		local HitTarget = trace.Entity
		local conTarget = ACE.GetContraption(HitTarget) or {}
		local conLauncher = ACE.GetContraption(Missile.Launcher) or {}

		local DirToHit = (HitPos - Pos):GetNormalized()
		local AngleDiff = math.deg(math.acos(math.Clamp(Dir:Dot(DirToHit), -1, 1)))

		if IsValid(Missile.Launcher) and conTarget == conLauncher and AngleDiff > 10 then
			if IsValid(HitTarget) then
				local mi, ma = HitTarget:GetCollisionBounds()
				debugoverlay.BoxAngles(HitTarget:GetPos(), mi, ma, HitTarget:GetAngles(), 5, Color(0, 255, 0, 100))
			end

			IsPart = true
		end

		if not IsPart then
			Missile.HitNorm = trace.HitNormal
			Missile:DoFlight(trace.HitPos)
			Missile.LastVel = Vel / DeltaTime
			Missile:Detonate()
			return true
		end
	end

	-- Detonation by fuse, if available
	if Time > Missile.GhostPeriod and Missile.Fuse:GetDetonate(Missile, Missile.Guidance) then
		Missile.LastVel = Vel / DeltaTime
		Missile:Detonate()
		return true
	end

	return false
end

local function ExitRack(Missile, DeltaTime)
	local Launcher = Missile.Launcher

	Missile.InRack = false

	local worldVel = Vector(Missile.LocalVel.x, Missile.LocalVel.y, Missile.LocalVel.z)
	if IsValid(Launcher) then
		worldVel:Rotate(Launcher:GetAngles())
		worldVel = worldVel + GetLauncherVelocity(Launcher)
	end

	Missile.TrueVel = worldVel
	Missile.LastVel = worldVel * DeltaTime
	Missile.CurDir = IsValid(Launcher) and Launcher:GetForward():GetNormalized() or Missile.CurDir
	Missile.LastPos = Missile.CurPos

	local GunData = GunTable[Missile.BulletData.Id]
	Missile.GhostPeriod = CurTime() + ((GunData and GunData.ghosttime) or 1)

	Missile:DoFlight()
end

local function FlightInRack(Missile, DeltaTime)
	local Launcher = Missile.Launcher
	if not IsValid(Launcher) then
		Missile:Dismount()
		return
	end

	local Time = CurTime()
	Missile.InRackTime = Missile.InRackTime + DeltaTime

	UpdateMotorState(Missile, Time)

	local railForward = Launcher:GetForward():GetNormalized()
	local gravityAccel = Vector(0, 0, -Missile.Gravity):Dot(railForward)
	local totalAccel = (Missile.Motor or 0) + gravityAccel

	Missile.LocalVel.x = math.max(Missile.LocalVel.x + totalAccel * DeltaTime, 0)

	local nextLocalPos = Missile.LCurPos + Vector(Missile.LocalVel.x * DeltaTime, 0, 0)
	Missile.LCurPos = nextLocalPos
	Missile.CurPos = Launcher:LocalToWorld(nextLocalPos)
	Missile.CurDir = railForward
	Missile.FlightTime = Missile.FlightTime + DeltaTime

	Missile:DoFlight()

	if (nextLocalPos.x - Missile.LStartX) >= Missile.PodLengthDistance then
		ExitRack(Missile, DeltaTime)
		return
	end

	if Missile.InRackTime >= Missile.MaxInRackTime then
		Missile:Dismount()
		return
	end
end

local function RealFlight(Missile, DeltaTime)
	local Pos = Missile.CurPos
	local Dir = Missile.CurDir
	local LastVel = Missile.LastVel
	local Speed = LastVel:Length()
	local Time = CurTime()

	if Speed == 0 then
		LastVel = Dir
		Speed = 1
		Missile.LastVel = LastVel
	end

	Dir = UpdateGuidance(Missile, Pos, Dir, Speed, DeltaTime)

	local DragCoef = UpdateMotorState(Missile, Time)
	local Vel = IntegrateFlightVelocity(Missile, Dir, LastVel, DragCoef, DeltaTime)
	local EndPos = Pos + Vel

	if PerformImpactAndFuseCheck(Missile, Pos, EndPos, Dir, Vel, DeltaTime, Time) then
		return
	end

	Missile.TrueVel = (EndPos - Pos) / DeltaTime
	Missile.LastVel = Vel
	Missile.LastPos = Pos
	Missile.CurPos = EndPos
	Missile.CurDir = Dir
	Missile.FlightTime = Missile.FlightTime + DeltaTime

	Missile:DoFlight()
end

function ENT:PerformFlight(DeltaTime)
	if self.MissileDetonated then return end
	if DeltaTime <= 0 then return end

	if self.InRack then
		FlightInRack(self, DeltaTime)
	else
		RealFlight(self, DeltaTime)
	end
end

function ENT:DoFlight(ToPos, ToDir)
	local setPos = ToPos or self.CurPos
	local setDir = ToDir or self.CurDir

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetPos(setPos)
		phys:SetAngles(setDir:Angle())
		phys:Wake()
	else
		self:SetPos(setPos)
		self:SetAngles(setDir:Angle())
	end
end

function ENT:TriggerInput(inp, value)
	if inp == "Detonate" and value ~= 0 then
		self:Detonate()
	end
end

--===========================================================================================
----- Launch & Dismount functions
--===========================================================================================
function ENT:Launch(ShootDir, UseRail, PodLength)
	if not IsValid(self.PhysObj) then self.PhysObj = self:GetPhysicsObject() end

	local BulletData = self.BulletData
	local GunData = GunTable[BulletData.Id]
	if not GunData then return end

	if self.RackModelApplied then
		self:InitializePhysics(ACE.GetGunValue(BulletData, "model"))
		self.RackModelApplied = nil
	end

	if not self.Guidance then
		self:SetGuidance(GuidanceTable.Dumb)
	end

	if not self.Fuse then
		self:SetFuse(FuseTable.Contact)
	end

	if self.Guidance.Init then
		self.Guidance:Init()
	end
	if self.Guidance.Configure then
		self.Guidance:Configure(self)
	end
	if self.Fuse.Configure then
		self.Fuse:Configure(self, self.Guidance)
	end

	self.Launched = true
	self.ThinkDelay = engine.TickInterval()
	self.Filter = self.Filter or { self }
	self.LaunchDir = ShootDir and ShootDir:GetNormalized() or self:GetForward():GetNormalized()

	local podLen = PodLength or 0
	self.InRack = (UseRail and podLen > 0 and IsValid(self.Launcher)) and true or false
	self.PodLengthDistance = podLen
	self.InRackTime = 0
	self.MaxInRackTime = ACE.MissileInRackTimeout or 2

	if self.InRack then
		self.LCurPos = self.Launcher:WorldToLocal(self:GetPos())
		self.LStartX = self.LCurPos.x
		self.LocalVel = Vector(0, 0, 0)
	end

	self:SetParent(nil)

	self:ConfigureFlight()

	if self.InRack and IsValid(self.Launcher) then
		self.CurPos = self.Launcher:LocalToWorld(self.LCurPos)
		self.CurDir = self.Launcher:GetForward():GetNormalized()
		self:DoFlight()
	else
		self.CurDir = self.LaunchDir
	end

	if IsValid(self.PhysObj) then
		self.PhysObj:EnableMotion(false)
		self.PhysObj:EnableGravity(false)
	end

	ACE.Missiles[self] = true

	self:Think()
end

function ENT:Dismount()
	if self.MissileDetonated then return end

	self.MissileDetonated = true
	self.Motor = 0
	self:StopParticles()
	self:SetNWFloat("LightSize", 0)
	ACE.Missiles[self] = nil

	self:Remove()
end

do
	local PushThrust = 30000

	function ENT:MotorStart(GunData, Round, BulletData)
		if not self.Launched then return end

		local noThrust = ACE.GetGunValue(BulletData, "nothrust")

		if GunData.prepush and not noThrust then
			-- Put a little gunpowder push on the missile so it can fly a few meters before the main rocket starts
			self.Motor = PushThrust

			timer.Simple(0.01, function()
				if not IsValid(self) then return end
				self.Motor = 0
			end)

			timer.Simple(0.5, function()
				if not IsValid(self) then return end
				if self.MissileDetonated then return end
				if self:WaterLevel() > 0 and self.NotDrownable then return end

				local Time = CurTime()

				self.MotorLength = BulletData.PropMass / (Round.burnrate / 1000) * (1 - Round.starterpct)
				self.Motor = Round.thrust

				if self.Motor > 0 or self.MotorLength > 0.1 then
					self.MissileIgnited = true
					self.CacheParticleEffect = Time + 0.01
					self:SetNWFloat("LightSize", BulletData.Caliber * 3)
					self.CutoutTime = Time + self.MotorLength
				end

				if self.Motor > 0 then
					self:LaunchEffect()
				end
			end)
		else
			local Time = CurTime()

			if noThrust then
				self.MotorLength = 0
				self.Motor = 0
			else
				self.MotorLength = BulletData.PropMass / (Round.burnrate / 1000) * (1 - Round.starterpct)
				self.Motor = Round.thrust
			end

			if self.Motor > 0 or self.MotorLength > 0.1 then
				self.MissileIgnited = true
				self.CacheParticleEffect = Time + 0.01
				self:SetNWFloat("LightSize", BulletData.Caliber * 3)
				self.CutoutTime = Time + self.MotorLength
			end

			if self.Motor > 0 then
				self:LaunchEffect()
			end
		end

		if self.Motor > 0 then
			local DRTime = 1250 / self.Motor

			timer.Simple(DRTime, function()
				if not IsValid(self) then return end
				self.NotDrownable = true -- Allow missiles to escape water briefly before motor drowning applies
			end)
		end
	end
end

function ENT:ConfigureFlight()
	local BulletData = self.BulletData
	local GunData = GunTable[BulletData.Id]
	local Round = GunData.round

	self:MotorStart(GunData, Round, BulletData)

	self.FlightTime = 0
	self.Gravity = GetConVar("sv_gravity"):GetFloat()
	self.DragCoef = Round.dragcoef
	self.DragCoefFlight = Round.dragcoefflight or Round.dragcoef
	self.MinimumSpeed = Round.minspeed

	self.FinMultiplier = Round.finmul
	self.Agility = GunData.agility or 1
	self.guidanceInac = GunData.guidanceInac or 0
	self.CurPos = self:GetPos()
	self.CurDir = self.LaunchDir or self:GetForward():GetNormalized()
	self.LastPos = self.CurPos
	self.HitNorm = Vector(0, 0, 0)
	self.FirstThink = true
	self.MinArmingDelay = math.max(Round.armdelay or GunData.armdelay, GunData.armdelay)

	local Mass = GunData.weight
	local Length = GunData.length
	local Width = GunData.caliber

	self.RotMultipler = GunData.rotmult or 1
	self.MaxTorque = GunData.maxrottq or 1000000
	self.Inertia = 0.08333 * Mass * (3.1416 * (Width / 2) ^ 2 + Length)
	self.TorqueMul = Length * 3
	self.RotAxis = Vector(0, 0, 0)

	self.GhostPeriod = CurTime() + (GunData.ghosttime or 1)

	self:UpdateBodygroups()
	self:UpdateSkin()
end

--===========================================================================================
----- Think
--===========================================================================================
function ENT:Think()
	if self.Launched and not self.MissileDetonated then
		local Time = CurTime()

		if self.FirstThink then
			self.FirstThink = false
			self.LastThink = Time - self.ThinkDelay

			local parentVel = GetLauncherVelocity(self.Launcher)
			self.LastVel = parentVel * self.ThinkDelay
			self.TrueVel = parentVel
		end

		local DeltaTime = Time - self.LastThink
		if DeltaTime > 0 then
			self.LastThink = Time
			self:PerformFlight(DeltaTime)
		end

		if self.MissileDetonated then return true end

		if self.CacheParticleEffect and (self.CacheParticleEffect <= Time) and (Time < self.CutoutTime) then
			if not (self:WaterLevel() == 3 and self.NotDrownable) then
				local effect = ACE.GetGunValue(self.BulletData, "effect")

				if effect then
					ParticleEffectAttach(effect, PATTACH_POINT_FOLLOW, self, self:LookupAttachment("exhaust") or 0)
				end
			end

			self.CacheParticleEffect = nil
		end

		-- Delete the missile if it was fired outside of the map
		if not self:IsInWorld() then
			self:Remove()
			return
		end
	end

	self:NextThink(CurTime() + self.ThinkDelay)
	return true
end

--===========================================================================================
----- Detonation functions
--===========================================================================================
function ENT:Detonate()
	self:StopParticles()
	self.Motor = 0
	self:SetNWFloat("LightSize", 0)

	-- Missile is below min arming time, so it becomes physical and useless
	if self.Fuse and (CurTime() - self.Fuse.TimeStarted < self.MinArmingDelay or not self.Fuse:IsArmed()) then
		self:Dud()
		return
	end

	self.BulletData.Flight = self:GetForward() * (self.BulletData.MuzzleVel or 10)
	self:ForceDetonate()
end

function ENT:ForceDetonate()
	-- Careful not to conflict with base class's self.Detonated
	self.MissileDetonated = true

	ACE.Missiles[self] = nil

	self.DetonateOffset = self.LastVel and self.LastVel:GetNormalized() * -1
	if self.Detonated then return end
	self.Detonated = true

	local bdata = self.BulletData
	local phys = self:GetPhysicsObject()
	local pos = self:GetPos()

	local phyvel = phys and phys:GetVelocity() or Vector(0, 0, 1000)
	bdata.Flight = bdata.Flight or phyvel

	if self.Fuse and self.Fuse.PerformDetonation then
		self.Fuse:PerformDetonation(self, bdata, phys, pos)
	else
		FuseTable.Contact():PerformDetonation(self, bdata, phys, pos)
	end

	timer.Simple(1, function()
		if IsValid(self) then
			if IsValid(self.FakeCrate) then
				self.FakeCrate:Remove()
			end
			self:Remove()
		end
	end)

	debugoverlay.Text(pos, "Missile Pos", 10)
end

function ENT:Dud()
	self.MissileDetonated = true

	ACE.Missiles[self] = nil

	self:SetPos(self.CurPos)
	self:SetAngles(self.CurDir:Angle())

	local Phys = self.PhysObj
	if IsValid(Phys) then
		Phys:EnableGravity(true)
		Phys:EnableMotion(true)
		local Vel = self.LastVel

		if self.HitNorm ~= vector_origin and Vel then
			local Dot = self.CurDir:Dot(self.HitNorm)
			local NewDir = self.CurDir - 2 * Dot * self.HitNorm
			local VelMul = (0.8 + Dot * 0.7) * Vel:Length()
			Vel = NewDir * VelMul
		end

		if Vel then
			Phys:SetVelocity(Vel)
		end
	end

	timer.Simple(30, function()
		if IsValid(self) then
			self:Remove()
		end
	end)
end

--===========================================================================================
----- Skin/Bodygroup/Effect/Sound functions
--===========================================================================================
function ENT:LaunchEffect()
	local Effect = EffectData()
		Effect:SetEntity(self)
	util.Effect("ace_missile_motor", Effect, true, true)
end

function ENT:UpdateSkin()
	if not self.BulletData then return end

	local warhead = self.BulletData.Type
	local skins = ACE.GetGunValue(self.BulletData, "skinindex")
	if not skins then return end

	local skin = skins[warhead] or 0
	self:SetSkin(skin)
end

function ENT:UpdateBodygroups()
	local bodygroups = self:GetBodyGroups()

	for _, group in pairs(bodygroups) do
		if string.lower(group.name) == "guidance" and self.Guidance then
			self:ApplyBodySubgroup(group, self.Guidance.Name)
			continue
		end

		if string.lower(group.name) == "warhead" and self.BulletData then
			self:ApplyBodySubgroup(group, self.BulletData.Type)
			continue
		end
	end
end

function ENT:ApplyBodySubgroup(group, targetname)
	local name = string.lower(targetname) .. ".smd"

	for subId, subName in pairs(group.submodels) do
		if string.lower(subName) == name then
			self:SetBodygroup(group.id, subId)
			return
		end
	end
end

--===========================================================================================
----- OnDamage functions
--===========================================================================================
function ENT:ACE_Activate(Recalc)
	local EmptyMass = self.RoundWeight or self.Mass or 10

	self.ACE = self.ACE or {}

	local PhysObj = self.PhysObj
	if not self.ACE.Area and IsValid(PhysObj) then
		self.ACE.Area = PhysObj:GetSurfaceArea() * 6.45
	end

	if not self.ACE.Volume and IsValid(PhysObj) then
		self.ACE.Volume = PhysObj:GetVolume() * 16.38
	end

	local ForceArmour = ACE.GetGunValue(self.BulletData, "armour")

	local Armour = ForceArmour or (EmptyMass * 1000 / math.max(self.ACE.Area or 1, 1) / 0.78)
	local Health = (self.ACE.Volume or 1) / ACE.Threshold
	local Percent = 1

	if Recalc and self.ACE.Health and self.ACE.MaxHealth then
		Percent = self.ACE.Health / self.ACE.MaxHealth
	end

	self.ACE.Health = Health * Percent
	self.ACE.MaxHealth = Health
	self.ACE.Armour = Armour * (0.5 + Percent / 2)
	self.ACE.MaxArmour = Armour
	self.ACE.Type = nil
	self.ACE.Mass = self.Mass
	self.ACE.Density = IsValid(PhysObj) and ((PhysObj:GetMass() * 1000) / math.max(self.ACE.Volume or 1, 1)) or 1
	self.ACE.Type = "Prop"

	self.ACE.Material = ACE.VerifyMaterial(self.ACE.Material)
end

do
	local nullhit = { Damage = 0, Overkill = 1, Loss = 0, Kill = false }

	function ENT:ACE_OnDamage(Entity, Energy, FrArea, Angle, Inflictor)
		if self.Detonated or self.DisableDamage then return table.Copy(nullhit) end

		local HitRes = ACE.PropDamage(Entity, Energy, FrArea, Angle, Inflictor)

		HitRes.Kill = HitRes.Kill or HitRes.Overkill > 0

		if HitRes.Kill then
			local CanDo = hook.Run("ACE_AmmoExplode", self, self.BulletData)
			if CanDo == false then return HitRes end

			self.Exploding = true

			if IsValid(Inflictor) and Inflictor:IsPlayer() then
				self.Inflictor = Inflictor
			end
		end

		return HitRes
	end
end

local dontDrive = {
	ace_missile = true,
	ace_missile_swep_guided = true
}

hook.Add("CanDrive", "ace_missile_CanDrive", function(_, ent)
	if dontDrive[ent:GetClass()] then return false end
end)

function ENT:CanTool(ply, _, mode)
	if mode ~= "wire_adv" or (ply ~= ACE.GetEntityOwner(self)) then return false end
	return true
end

function ENT:OnRemove()
	self.BaseClass.OnRemove(self)
	ACE.Missiles[self] = nil
	self:StopParticles()
end
