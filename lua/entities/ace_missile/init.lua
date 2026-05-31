AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local GunTable	= ACE.Weapons.Guns
local GuidanceTable = ACE.Guidance
local FuseTable	= ACE.Fuse

function ENT:Initialize()
	self.Inputs = WireLib.CreateInputs( self, { "Detonate" } )
	self.ThinkDelay = 0.1
	self.BulletData = {}

	self.DetonateOffset = nil
	self.SpecialDamage = true	-- If true needs a special ACE.OnDamage function
	self.SpecialHealth = true	-- If true needs a special ACE.Activate function
	self.DoNotDuplicate  = true

	self.Launcher = NULL
	self.ForceTdelay = 0
	self.CanTrack	= false		-- Used when the missile has waited the required time to guide
	self.Timer	= false

	self.CutoutTime = CurTime() + 10000

	self:SetNWFloat("LightSize", 0)
end

function ENT:InitializePhysics(model)
	if model then
		self:SetModel(model)
	end
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableMotion(true)
		phys:SetMass( 10 )
		phys:EnableGravity( false )
		phys:EnableMotion( false )
		self.PhysObj = phys
	end
	return phys
end
--===========================================================================================
----- BulletData functions
--===========================================================================================
function ENT:SetCrateData(Crate)
	if not IsValid(Crate) then return end

	local BulletData = table.Copy(Crate.BulletData)
	local gun = GunTable[BulletData.Id]
	local roundWeight = ACE.GetGunValue(bdata, "weight") or 10

	BulletData.Entity = self
	BulletData.Crate = self:EntIndex()
	BulletData.Owner = BulletData.Owner or ACE.GetEntityOwner(self)
	self:NetworkBulletData(BulletData)

	self.RoundData = table.Copy(Crate.RoundData) -- raw data.
	self.BulletData = BulletData -- converted data
	self.RoundWeight = roundWeight
	self:ConfigureFlight()
	self.TrackDelay = gun.guidelay or 0

	self:PrepareMissileSensors()
	local phys = self:InitializePhysics(gun.model)
	if IsValid(phys) then
		phys:SetMass( roundWeight )
	end
	self:SetColor(Crate:GetColor())

end
--===========================================================================================
----- Guidance and Fuse functions
--===========================================================================================
function ENT:SetGuidance(guidance)
	self.Guidance = guidance
	guidance:Configure(self)
	return guidance
end

function ENT:SetFuse(fuse)
	self.Fuse = fuse
	fuse:Configure(self, self.Guidance or self:SetGuidance(GuidanceTable.Dumb()))
	return fuse
end

function ENT:PrepareMissileSensors()

	local RoundData = self.RoundData
	local guidance  = RoundData.Guidance
	local fuse	= RoundData.Fuse

	if guidance then
		guidance = ACEM.CreateConfigurable(guidance, GuidanceTable, bdata, "guidance")
		if guidance then self:SetGuidance(guidance) end
	end

	if fuse then
		fuse = ACEM.CreateConfigurable(fuse, FuseTable, bdata, "fuses")
		if fuse then self:SetFuse(fuse) end
	end
end

function ENT:NetworkBulletData(BulletData)

	--if type(bullet) ~= "table" and bullet.BulletData then
	--	self:SetNWString( "Sound", bullet.Sound or (bullet.Primary and bullet.Primary.Sound))
	--	self:SetOwner(bullet:GetOwner())
	--	bullet = bullet.BulletData
	--end

	self:SetNWInt( "Caliber", BulletData.Caliber or 10)
	self:SetNWInt( "ProjMass", BulletData.ProjMass or 10)
	self:SetNWInt( "FillerMass", BulletData.FillerMass or 0)
	self:SetNWInt( "DragCoef", BulletData.DragCoef or 1)
	self:SetNWString( "AmmoType", BulletData.Type or "AP")
	self:SetNWInt( "Tracer" , BulletData.Tracer or 0)
	local col = BulletData.Colour or self:GetColor()
	self:SetNWVector( "Color" , Vector(col.r, col.g, col.b))
	self:SetNWVector( "TracerColour" , Vector(col.r, col.g, col.b))

end


--===========================================================================================
----- Physics functions
--===========================================================================================
function ENT:CalcFlight()
	if self.MissileDetonated then return end

	local Pos	= self.CurPos
	local Dir	= self.CurDir

	local LastVel	= self.LastVel
	local Flight	= self.FlightTime

	local Speed	= LastVel:Length()

	local Time	= CurTime()
	local DeltaTime = Time - self.LastThink

	if DeltaTime <= 0 then return end

	self.LastThink = Time
	Flight = Flight + DeltaTime

	if Speed == 0 then
		LastVel = Dir
		Speed = 1
	end

	-- Guidance calculations
	local Guidance  = self.Guidance:GetGuidance(self)
	local TargetPos = self.CanTrack and Guidance.TargetPos or nil --print("track:", self.CanTrack, Guidance.TargetPos)
	local Tdelay	= self.ForceTdelay >= self.TrackDelay and self.ForceTdelay or self.TrackDelay

	-- Track delay calculation
	if Guidance.TargetPos then
		if Tdelay > self.TrackDelay then
			if not self.Timer then
				self.Timer = true

				timer.Simple(Tdelay, function()
					if not IsValid(self) then return end
						self.CanTrack = true
				end )
			end
		else
			self.CanTrack = true
		end
	end

	-- Physics calculations:
	-- If the missile has guidance and can turn
	if TargetPos then

		local missileInac = self.guidanceInac

		local Dist	= Pos:Distance(TargetPos)
		TargetPos	= TargetPos + (Vector(0,0,self.Gravity * Dist / 100000)) + Vector(math.random(-missileInac,missileInac),math.random(-missileInac,missileInac),math.random(-missileInac,missileInac))
		local LOS	= (TargetPos - Pos):GetNormalized()
		local LastLOS	= self.LastLOS
		local NewDir	= Dir
		local DirDiff	= 0

		if LastLOS then

			local Agility	= self.Agility
			local SpeedMul  = math.min((Speed / DeltaTime / self.MinimumSpeed) ^ 3,1)

			local LOSDiff	= math.deg(math.acos( LastLOS:Dot(LOS) )) * 20
			local MaxTurn	= Agility * SpeedMul * 5

			if LOSDiff > 0.01 and MaxTurn > 0.1 then

				local LOSNormal = LastLOS:Cross(LOS):GetNormalized()
				local Ang = NewDir:Angle()
				Ang:RotateAroundAxis(LOSNormal, math.min(LOSDiff, MaxTurn))
				NewDir = Ang:Forward()

			end

			DirDiff = math.deg(math.acos( NewDir:Dot(LOS) ))
			if DirDiff > 0.01 then
				local DirNormal = NewDir:Cross(LOS):GetNormalized()
				local TurnAng = math.min(DirDiff, MaxTurn) / 10
				local Ang = NewDir:Angle()
				Ang:RotateAroundAxis(DirNormal, TurnAng)
				NewDir = Ang:Forward()
				DirDiff = DirDiff - TurnAng
			end
		end

		--FOV check
		if not Guidance.ViewCone or DirDiff <= Guidance.ViewCone then  -- ViewCone is active-seeker specific
			Dir = NewDir
		end
		self.LastLOS = LOS

	else
		-- has not guidance

		local DirAng        = Dir:Angle()
		local VelNorm       = LastVel / Speed
		local AimDiff       = Dir - VelNorm
		local DiffLength    = AimDiff:Length()

		if DiffLength >= 0.001 and DiffLength < 1.95 and  Time > self.GhostPeriod then

			local Torque       = DiffLength * self.TorqueMul * Speed * self.RotMultipler
			local AngVelDiff   = Torque / self.Inertia * DeltaTime
			local DiffAxis     = AimDiff:Cross(Dir):GetNormalized()

			self.RotAxis       = self.RotAxis + DiffAxis * AngVelDiff
		end

		self.RotAxis = self.RotAxis * 0.99

		DirAng:RotateAroundAxis(self.RotAxis, self.RotAxis:Length())
		Dir = DirAng:Forward()

		self.LastLOS = nil
	end

	--Rocket motor is out or drowned
	local DragCoef = 0
	if Time > self.CutoutTime or (self:WaterLevel() == 3 and self.NotDrownable ) then

		DragCoef = (self:WaterLevel() == 3 and self.NotDrownable ) and self.DragCoef * 5 or self.DragCoef --5 times extra drag underwater

		if self.Motor ~= 0 then
			self.Motor = 0
			self:StopParticles()
			self:SetNWFloat("LightSize", 0)
		end
	else
		DragCoef = self.DragCoefFlight
	end

	-- Inertia/Motor thrust calculation

	local Vel        = LastVel + (Dir * self.Motor - Vector(0,0,self.Gravity )) * ACE.VelScale * DeltaTime ^ 2
	local Up         = Dir:Cross(Vel):Cross(Dir):GetNormalized()
	local Speed      = Vel:Length()
	local VelNorm    = Vel / Speed
	local DotSimple  = Up.x * VelNorm.x + Up.y * VelNorm.y + Up.z * VelNorm.z

	Vel = Vel - Up * Speed * DotSimple * self.FinMultiplier

	local SpeedSq	= Vel:LengthSqr()
	local Drag		= Vel:GetNormalized() * (DragCoef * SpeedSq) / ACE.DragDiv * ACE.VelScale

	Vel				= Vel - Drag

	local EndPos		= Pos + Vel

	do

		-- Hit/Impact detection

		local tracedata	= {}
		tracedata.start	= Pos
		tracedata.endpos	= EndPos
		tracedata.filter	= self.Filter
		tracedata.mins	= vector_origin
		tracedata.maxs	= tracedata.mins

		--Becomes volumetric once ghosting is over. So we avoid most of expensive calculations below
		if Time > self.GhostPeriod then

			local MRadius = (self.BulletData.Caliber / 2) * 0.5
			local maxs = Vector(MRadius,MRadius,MRadius)
			local mins = -maxs

			tracedata.mins	= mins
			tracedata.maxs	= maxs
		end

		local trace = util.TraceHull(tracedata)

		-- We have CFW
		if trace.Hit then

			local IsPart = false
			local HitPos = trace.HitPos
			local HitTarget  = trace.Entity
			local conTarget	= ACE.GetContraption(HitTarget) or {}
			local conLauncher = ACE.GetContraption(self.Launcher) or {}

			local DirToHit = (HitPos - Pos):GetNormalized()
			local AngleDiff = math.deg(math.acos( Dir:Dot(DirToHit) )) --print("Angle Diff:", AngleDiff)

			if conTarget == conLauncher and AngleDiff > 10 then -- Not required to do anything else.

				--"Fraction: ",trace.Fraction)
				local mi, ma = HitTarget:GetCollisionBounds()
				debugoverlay.BoxAngles(HitTarget:GetPos(), mi, ma, HitTarget:GetAngles(), 5, Color(0,255,0,100))

				IsPart = true
			end

			-- Determine if the detected ent is not part of the same contraption that fired this missile.
			-- Also check theres no props directly in front of the trayectory, even if its from the same contraption.
			if not IsPart then
				self.HitNorm	= trace.HitNormal
				self:DoFlight(trace.HitPos)
				self.LastVel	= Vel / DeltaTime
				self:Detonate()
				return
			end

		end

		--Detonation by fuse, if available
		if Time > self.GhostPeriod and self.Fuse:GetDetonate(self, self.Guidance) then
			self.LastVel = Vel / DeltaTime
			self:Detonate()

			return
		end

	end

	self.TrueVel       = (EndPos - Pos) / DeltaTime
	self.LastVel       = Vel
	self.LastPos       = Pos
	self.CurPos        = EndPos
	self.CurDir        = Dir
	self.FlightTime    = Flight

	--Missile trajectory debugging
	--.Line(Pos, EndPos, 10, Color(0, 255, 0))
	--debugoverlay.Line(EndPos, EndPos + Dir:GetNormalized()  * 50, 10, Color(0, 0, 255))

	self:DoFlight()
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

function ENT:TriggerInput( inp, value )
	if inp == "Detonate" and value ~= 0 then
		self:Detonate()
	end
end

--===========================================================================================
----- Launch function
--===========================================================================================
function ENT:Launch()
	if not IsValid(self.PhysObj) then self.PhysObj = self:GetPhysicsObject() end

	if not self.Guidance then
		self:SetGuidance(GuidanceTable.Dumb())
	end

	if not self.Fuse then
		self:SetFuse(FuseTable.Contact())
	end

	self.Guidance:Init()
	self.Guidance:Configure(self)
	self.Fuse:Configure(self, self.Guidance)

	self.Launched	= true
	self.ThinkDelay = 1 / 66
	self.Filter	= self.Filter or {self}

	self:SetParent(nil)

	self:ConfigureFlight()
	self.PhysObj:EnableMotion(false)

	ACE.Missiles[self] = true

	self:Think()
end

do

	local PushThrust = 30000

	-- WARNING: Hardcoded
	function ENT:MotorStart( GunData, Round, BulletData )

		if not self.Launched then return end

		if GunData.prepush then

			--Put a little of gunpowder to missile so it can fly a few meters before main rocket starts
			self.Motor = PushThrust

			--Small push
			timer.Simple( 0.01, function()
				if not IsValid(self) then return end

				self.Motor = 0
			end )

			--Ignition
			timer.Simple( 0.5, function()
				if not IsValid(self) then return end
				if self.MissileDetonated then return end
				if self:WaterLevel() > 0 and self.NotDrownable then return end

				local Time = CurTime()

				self.MotorLength	= BulletData.PropMass / (Round.burnrate / 1000) * (1 - Round.starterpct)
				self.Motor		= Round.thrust

				if self.Motor > 0 or self.MotorLength > 0.1 then --Ignition -- must not be called here
					self.MissileIgnited = true
					self.CacheParticleEffect = CurTime() + 0.01
					self:SetNWFloat("LightSize", BulletData.Caliber * 3)
					self.CutoutTime	= Time + self.MotorLength -- must not be called here
				end

				if self.Motor > 0 then
					self:LaunchEffect()
				end

			end )
		elseif not GunData.prepush then

			local noThrust  = ACE.GetGunValue(BulletData, "nothrust")
			local Time	= CurTime()

			if noThrust then
				self.MotorLength	= 0
				self.Motor		= 0
			else
				self.MotorLength	= BulletData.PropMass / (Round.burnrate / 1000) * (1 - Round.starterpct)
				self.Motor		= Round.thrust
			end

			if self.Motor > 0 or self.MotorLength > 0.1 then
				self.MissileIgnited = true
				self.CacheParticleEffect = CurTime() + 0.01
				self:SetNWFloat("LightSize", BulletData.Caliber * 3)
				self.CutoutTime	= Time + self.MotorLength
			end

			if self.Motor > 0 then
				self:LaunchEffect()
			end

		end

		local DRTime = 1250 / self.Motor

		timer.Simple( DRTime , function()
			self.NotDrownable = true --Given time to allow missiles to escape from the water before their motors are drowned
		end)

	end
end

function ENT:ConfigureFlight()

	local BulletData	= self.BulletData
	local GunData	= GunTable[BulletData.Id]
	local Round		= GunData.round

	self:MotorStart( GunData, Round, BulletData )

	self.FlightTime        = 0
	self.Gravity           = GetConVar("sv_gravity"):GetFloat()
	self.DragCoef          = Round.dragcoef
	self.DragCoefFlight    = Round.dragcoefflight or Round.dragcoef
	self.MinimumSpeed      = Round.minspeed

	self.FinMultiplier     = Round.finmul
	self.Agility           = GunData.agility or 1
	self.guidanceInac      = GunData.guidanceInac or 0
	self.CurPos            = self:GetPos()
	self.CurDir            = self:GetForward():GetNormalized()
	self.LastPos           = self.CurPos
	self.HitNorm           = vector_origin
	self.FirstThink        = true
	self.MinArmingDelay    = math.max(Round.armdelay or GunData.armdelay, GunData.armdelay)

	local Mass             = GunData.weight
	local Length           = GunData.length
	local Width            = GunData.caliber

	self.RotMultipler      = GunData.rotmult or 1
	self.MaxTorque         = GunData.maxrottq or 1000000
	self.Inertia           = 0.08333 * Mass * (3.1416 * (Width / 2) ^ 2 + Length)
	self.TorqueMul         = Length * 3
	self.RotAxis           = vector_origin

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

		if self.FirstThink == true then
			self.FirstThink = false
			self.LastThink  = Time - self.ThinkDelay
			self.LastVel	= self.Launcher.acephysparent:GetVelocity() * self.ThinkDelay
			self.TrueVel = self.Launcher.acephysparent:GetVelocity()
		end

		self:CalcFlight()

		if self.CacheParticleEffect and (self.CacheParticleEffect <= Time) and (Time < self.CutoutTime) then

			if not (self:WaterLevel() == 3 and self.NotDrownable) then

				local effect = ACE.GetGunValue(self.BulletData, "effect")

				if effect then
					ParticleEffectAttach( effect, PATTACH_POINT_FOLLOW, self, self:LookupAttachment("exhaust") or 0 )
				end

			end

			self.CacheParticleEffect = nil
		end

		--Delete the missile if it was fired outside of the map
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

	--Missile is below min arming time, so it becomes physical and useless
	if self.Fuse and (CurTime() - self.Fuse.TimeStarted < self.MinArmingDelay or not self.Fuse:IsArmed()) then
		self:Dud()
		return
	end

	self.BulletData.Flight = self:GetForward() * (self.BulletData.MuzzleVel or 10)
	self:ForceDetonate()

end

function ENT:ForceDetonate()

	-- careful not to conflict with base class's self.Detonated
	self.MissileDetonated = true

	ACE.Missiles[self] = nil

	self.DetonateOffset = self.LastVel and self.LastVel:GetNormalized() * -1
	if self.Detonated then return end
	self.Detonated = true

	local bdata = self.BulletData
	local phys  = self:GetPhysicsObject()
	local pos	= self:GetPos()

	local phyvel =  phys and phys:GetVelocity() or Vector(0, 0, 1000)
	bdata.Flight =  bdata.Flight or phyvel

	if self.Fuse.PerformDetonation then
		self.Fuse:PerformDetonation( self, bdata, phys, pos )
	else
		ACE.Fuse.Contact():PerformDetonation( self, bdata, phys, pos )
	end

	timer.Simple(1, function() if IsValid(self) then if IsValid(self.FakeCrate) then self.FakeCrate:Remove() end self:Remove() end end)

	debugoverlay.Text(pos, "Missile Pos", 10 )

end

function ENT:Dud()

	self.MissileDetonated = true

	ACE.Missiles[self] = nil

	local Dud = self
	Dud:SetPos( self.CurPos )
	Dud:SetAngles( self.CurDir:Angle() )

	local Phys = Dud.PhysObj
	Phys:EnableGravity(true)
	Phys:EnableMotion(true)
	local Vel = self.LastVel

	if self.HitNorm ~= Vector(0,0,0) then
		local Dot	= self.CurDir:Dot(self.HitNorm)
		local NewDir	= self.CurDir - 2 * Dot * self.HitNorm
		local VelMul	= (0.8 + Dot * 0.7) * Vel:Length()
		Vel = NewDir * VelMul
	end

	if Vel then	--making check
		Phys:SetVelocity(Vel)
	end

	timer.Simple(30, function() if IsValid(self) then self:Remove() end end)
end

--===========================================================================================
----- Skin/Bodygroup/effect/Sound functions
--===========================================================================================
function ENT:LaunchEffect()
	local Effect = EffectData()
		Effect:SetEntity( self )
	util.Effect( "ace_missile_motor", Effect, true, true )
end

function ENT:UpdateSkin()

	if self.BulletData then

		local warhead = self.BulletData.Type

		local skins = ACE.GetGunValue(self.BulletData, "skinindex")
		if not skins then return end

		local skin = skins[warhead] or 0

		self:SetSkin(skin)

	end
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
function ENT:ACE_Activate( Recalc )

	local EmptyMass = self.RoundWeight or self.Mass or 10

	self.ACE = self.ACE or {}

	local PhysObj = self.PhysObj
	if not self.ACE.Area then
		self.ACE.Area = PhysObj:GetSurfaceArea() * 6.45
	end


	if not self.ACE.Volume then
		self.ACE.Volume = PhysObj:GetVolume() * 16.38
	end

	local ForceArmour = ACE.GetGunValue(self.BulletData, "armour")

	local Armour = ForceArmour or (EmptyMass * 1000 / self.ACE.Area / 0.78)	--So we get the equivalent thickness of that prop in mm if all it's weight was a steel plate
	local Health = self.ACE.Volume / ACE.Threshold							--Setting the threshold of the prop Area gone
	local Percent = 1

	if Recalc and self.ACE.Health and self.ACE.MaxHealth then
		Percent = self.ACE.Health / self.ACE.MaxHealth
	end

	self.ACE.Health	= Health * Percent
	self.ACE.MaxHealth  = Health
	self.ACE.Armour	= Armour * (0.5 + Percent / 2)
	self.ACE.MaxArmour  = Armour
	self.ACE.Type	= nil
	self.ACE.Mass	= self.Mass
	self.ACE.Density	= (self.PhysObj:GetMass() * 1000) / self.ACE.Volume
	self.ACE.Type	= "Prop"

	self.ACE.Material = ACE.VerifyMaterial(self.ACE.Material)

end

do

	local nullhit = {Damage = 0, Overkill = 1, Loss = 0, Kill = false}

	function ENT:ACE_OnDamage( Entity , Energy , FrArea , Angle , Inflictor )	--This function needs to return HitRes

		if self.Detonated or self.DisableDamage then return table.Copy(nullhit) end

		local HitRes = ACE.PropDamage( Entity , Energy , FrArea , Angle , Inflictor )	--Calling the standard damage prop function

		-- Detonate if the shot penetrates the casing.
		HitRes.Kill = HitRes.Kill or HitRes.Overkill > 0

		if HitRes.Kill then

			local CanDo = hook.Run("ACE_AmmoExplode", self, self.BulletData )
			if CanDo == false then return HitRes end

			self.Exploding = true

			if IsValid(Inflictor) and Inflictor:IsPlayer() then
				self.Inflictor = Inflictor
			end

			--self:ForceDetonate()

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

end
