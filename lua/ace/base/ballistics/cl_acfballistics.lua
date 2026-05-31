local ACE = ACE
ACE.BulletEffect = {}

function ACE.ManageBulletEffects()

	if next(ACE.BulletEffect) then

		for Index,Bullet in pairs(ACE.BulletEffect) do
		ACE.SimBulletFlight( Bullet, Index )			--This is the bullet entry in the table, the omnipresent Index var refers to this
		end
	end
end
hook.Remove( "Think", "ACE_ManageBulletEffects" )
hook.Add("Think", "ACE_ManageBulletEffects", ACE.ManageBulletEffects)



function ACE.SimBulletFlight( Bullet, Index )
	if not Bullet or not Index then return end

	Bullet.DeltaTime = CurTime() - Bullet.LastThink --intentionally not using cached curtime value

	local Drag = Bullet.SimFlight:GetNormalized() * ( Bullet.DragCoef * Bullet.SimFlight:LengthSqr() ) / ACE.DragDiv

	Bullet.SimPosLast	= Bullet.SimPos
	Bullet.SimPos		= Bullet.SimPos + (Bullet.SimFlight * ACE.VelScale * Bullet.DeltaTime)		--Calculates the next shell position
	Bullet.SimFlight	= Bullet.SimFlight + (Bullet.Accel - Drag) * Bullet.DeltaTime			--Calculates the next shell vector

--	print(Bullet.SimFlight:Length()/39.37)

	if Bullet and Bullet.Effect:IsValid() then
		Bullet.Effect:ApplyMovement( Bullet, Index )
	end
	Bullet.LastThink = CurTime() --ACE.CurTime --intentionally not using cached curtime value

end
