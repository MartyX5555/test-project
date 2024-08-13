


do


	--This is a fully loaded bullet removal
	function ACE_RemoveBulletClient( Bullet, Index )

		if Bullet then

			local BulletEnt = Bullet.Effect
			if IsValid(BulletEnt) then
				BulletEnt.Alive = false
				BulletEnt:Remove()
			end

			if ACF.BulletEffect[Index] then
				ACF.BulletEffect[Index] = nil
			end
		end
	end

	--Applies only to bullets that wants only their entity removed but keeping on the main table
	local function RemoveBulletEffect( Effect )
		if IsValid(Effect) then
			Effect.Alive = false
			Effect:Remove()
		end
	end

	function EFFECT:Init( data )

		self.Index = data:GetMaterialIndex()
		self.CreateTime = ACF.CurTime

		local Hit = data:GetScale()
		local BulletData = ACF.BulletEffect[self.Index]

		--Scale encodes the hit type, so if it's 0 it's a new bullet, else it's an update so we need to remove the effect
		if (Hit > 0 and BulletData) then

			BulletData.SimFlight = data:GetStart() * 10	--Updating old effect with new values
			BulletData.SimPos = data:GetOrigin()

			--Bullet has reached end of flight, remove old effect
			if Hit == 1 then

				BulletData.Impacted = true

				self.HitEnd = ACF.RoundTypes[BulletData.AmmoType]["endeffect"]
				self:HitEnd( BulletData )
				ACF.BulletEffect[self.Index] = nil		--This is crucial, to effectively remove the bullet flight model from the client

				if IsValid(BulletData.Tracer) then BulletData.Tracer:Finish() end

			--Bullet penetrated, don't remove old effect
			elseif Hit == 2 then

				self.HitPierce = ACF.RoundTypes[BulletData.AmmoType]["pierceeffect"]
				self:HitPierce( BulletData )

			--Bullet ricocheted, don't remove old effect
			elseif Hit == 3 then

				self.HitRicochet = ACF.RoundTypes[BulletData.AmmoType]["ricocheteffect"]
				self:HitRicochet( BulletData )

			end

			-- This will make sure the trace wont spawn behind the surface where it did hit.
			if IsValid(BulletData.Tracer) then
				BulletData.Counter = 0
			end

			ACF_SimBulletFlight( BulletData, self.Index )
			RemoveBulletEffect( self )

		else

			local Crate = data:GetEntity()

			--TODO: Check if it is actually a crate
			if not IsValid(Crate) then
				RemoveBulletEffect( self )
				return
			end

			local BulletData           = {}
			BulletData.IsMissile       = BulletData.IsMissile or (data:GetAttachment() == 1)
			BulletData.SimFlight       = data:GetStart() * 10
			BulletData.SimPos          = data:GetOrigin()
			BulletData.SimPosLast      = BulletData.SimPos
			BulletData.Caliber         = Crate:GetNWFloat( "Caliber", 10 )
			BulletData.RoundMass       = Crate:GetNWFloat( "ProjMass", 10 )
			BulletData.FillerMass      = Crate:GetNWFloat( "FillerMass", 0 )
			BulletData.WPMass          = Crate:GetNWFloat( "WPMass", 0 )
			BulletData.DragCoef        = Crate:GetNWFloat( "DragCoef", 1 )
			BulletData.AmmoType        = Crate:GetNWString( "AmmoType", "AP" )

			BulletData.Accel           = Crate:GetNWVector( "Accel", Vector(0,0,-600))

			BulletData.LastThink       = CurTime() --ACF.CurTime
			BulletData.Effect          = self.Entity
			BulletData.CrackCreated    = false
			BulletData.InitialPos      = BulletData.SimPos --Store the first pos, se we can limit the crack sound at certain distance
			BulletData.Crate           = Crate

			BulletData.BulletModel     = Crate:GetNWString( "BulletModel", "models/munitions/round_100mm_shot.mdl" )

			if Crate:GetNWFloat( "Tracer" ) > 0 then
				BulletData.Counter        = 0
				BulletData.Tracer         = ParticleEmitter( BulletData.SimPos )
				BulletData.TracerColour   = Crate:GetNWVector( "TracerColour", Crate:GetColor() ) or Vector(255,255,255)
			end

			--Moving the effect to the calculated position
			self:SetPos( BulletData.SimPos )
			self:SetAngles( BulletData.SimFlight:Angle() )
			self:SetModel( BulletData.BulletModel )

			--Add all that data to the bullet table, overwriting if needed
			ACF.BulletEffect[self.Index] = BulletData
			self.Alive = true

			ACF_SimBulletFlight( BulletData, self.Index )

		end

	end

end



function EFFECT:HitEnd()
	--You overwrite this with your own function, defined in the ammo definition file
	ACF.BulletEffect[self.Index] = nil		--Failsafe
end

function EFFECT:HitPierce()
	--You overwrite this with your own function, defined in the ammo definition file
	ACF.BulletEffect[self.Index] = nil		--Failsafe
end

function EFFECT:HitRicochet()
	--You overwrite this with your own function, defined in the ammo definition file
	ACF.BulletEffect[self.Index] = nil		--Failsafe
end

function EFFECT:Think()

	local Bullet = ACF.BulletEffect[self.Index]

	if self.Alive and Bullet and self.CreateTime > ACF.CurTime-30 then
		return true
	end

	--if the bullet will be not stand in the map, less its tracer
	if Bullet and IsValid(Bullet.Tracer) then Bullet.Tracer:Finish() end
	return false
end

--Check if the crack is allowed to perform or not
local function CanBulletCrack( Bullet )

	if Bullet.IsMissile then return false end
	if Bullet.CrackCreated then return false end
	if ACE_SInDistance( Bullet.InitialPos, 750 ) then return false end
	if not ACE_SInDistance( Bullet.SimPos, math.max(Bullet.Caliber * 100 * ACE.CrackDistanceMultipler,250) ) then return false end
	if Bullet.Impacted then return false end

	local SqrtSpeed = (Bullet.SimPos - Bullet.SimPosLast):LengthSqr()
	if SqrtSpeed < 50 ^ 2 then return false end

	return true
end

local TracerLengthMult = 2.5--1.25 -- A multipler for the tracer length. 1.25 will cover a distance 25% greater than the distance between the bullet pos and its previous location.
function EFFECT:ApplyMovement( Bullet, Index )

	-- the bullet will never come back to the map.
	local setPos = Bullet.SimPos
	if (math.abs(setPos.x) > 16380) or (math.abs(setPos.y) > 16380) or (setPos.z < -16380) then
		ACE_RemoveBulletClient( Bullet, Index )
		return
	end

	--We don't need small bullets to stay outside of skybox. This is meant for large calibers only.
	if setPos.z > 16380 and Bullet.Caliber < 5 then
		ACE_RemoveBulletClient( Bullet, Index )
		return
	end

	self:SetPos( setPos ) --Moving the effect to the calculated position
	self:SetAngles( Bullet.SimFlight:Angle() )

	--sonic crack sound
	if CanBulletCrack( Bullet ) then
		ACE_SBulletCrack(Bullet, Bullet.Caliber)
	end

	if Bullet.Tracer and IsValid(Bullet.Tracer) then

		--Bullet.Caliber = 100 / 10

		--We require this so the tracer is not spawned in middle of the gun (when initially fired)
		Bullet.Counter = Bullet.Counter + 1

		local DeltaPos = Bullet.SimPos - Bullet.SimPosLast
		local Dist = DeltaPos:Length()
		local Limit = Bullet.Counter > 3 and 999999999999 or Dist
		local Length = math.Clamp(Dist * TracerLengthMult, 0, Limit)

		if Length > 0 then
			local Light = Bullet.Tracer:Add( "sprites/acf_tracer.vmt", setPos )
			if Light then
				Light:SetAngles( Bullet.SimFlight:Angle() )
				Light:SetVelocity( Bullet.SimFlight:GetNormalized())
				Light:SetColor( Bullet.TracerColour.x, Bullet.TracerColour.y, Bullet.TracerColour.z )
				Light:SetDieTime( math.Clamp(ACF.CurTime - self.CreateTime, 0.075, 0.1) ) -- 0.075, 0.1
				Light:SetStartAlpha( 180 )
				Light:SetStartSize( 40 * Bullet.Caliber ) -- 5
				Light:SetEndSize( Bullet.Caliber ) --15 * Bullet.Caliber
				Light:SetStartLength( -Length )
			end

			local Smoke = Bullet.Tracer:Add( "particle/smokesprites_000" .. math.random(1,9), setPos) --- (DeltaPos * i / MaxSprites) )
			if Smoke then
				Smoke:SetAngles( Bullet.SimFlight:Angle() )
				Smoke:SetVelocity( Bullet.SimFlight * 0.01 )
				Smoke:SetColor( 200 , 200 , 200 )
				Smoke:SetDieTime( math.Rand(0.5,1) ) -- 1.2
				Smoke:SetStartAlpha( math.random(1,20) )
				Smoke:SetEndAlpha( 0 )
				Smoke:SetStartSize( 2 )
				Smoke:SetEndSize( Length / (Bullet.Caliber * 50) )
				Smoke:SetAirResistance( 150 )
				Smoke:SetStartLength( -Length )
				Smoke:SetEndLength( -Length ) --Length
			end

		end


	end
end

function EFFECT:Render()

	local Bullet = ACF.BulletEffect[self.Index]

	if (Bullet) then
		self.Entity:SetModelScale( Bullet.Caliber / 10 , 0 )
		self.Entity:DrawModel()	-- Draw the model.
	end

end
