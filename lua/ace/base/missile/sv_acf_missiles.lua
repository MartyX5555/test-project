--[[
			  _____ ______	 __  __ _		  _ _
		/\	/  ____|  ____| |  \/  (_)	     (_) |
	   /  \ | |	   | |__	| \  / |_ ___ ___ _| | ___  ___
	  / /\ \| |	   |  __|	| |\/| | / __/ __| | |/ _ \/ __|
	 / ____ \ |____| |____	| |  | | \__ \__ \ | |  __/\__ \
	/_/	   \_\_____|______|	|_|  |_|_|___/___/_|_|\___||___/

	By Bubbus + Cre8or

	A reimplementation of XCF missiles and bombs, with guidance and more.
]]

local ACE = ACE or {}
--[[
	Differences with the default bullet function:
		1.- It doesnt count traceback, since the missile has no velocity and the bullet will not be hitting the initial launcher.
]]--
function ACEM.BulletLaunch(BulletData)

	-- Increment the index
	ACE.CurBulletIndex = ACE.CurBulletIndex + 1

	if ACE.CurBulletIndex > ACE.BulletIndexLimit then
		ACE.CurBulletIndex = 1
	end

	--Those are BulletData settings that are global and shouldn't change round to round
	BulletData.Gravity		= GetConVar("sv_gravity"):GetInt() * -1
	BulletData.Accel		= Vector(0,0,BulletData.Gravity)
	BulletData.LastThink	= ACE.SysTime
	BulletData.FlightTime	= 0
	BulletData.TraceBackComp	= 0

	BulletData.FuseDelay	= type(BulletData.FuseDelay) == "number" and BulletData.FuseDelay or 0

	if BulletData.Filter then
		table.Add(BulletData.Filter, { BulletData.Gun } )
	else
		BulletData.Filter = { BulletData.Gun }
	end

	BulletData.Index		= ACE.CurBulletIndex
	ACE.Bullet[ACE.CurBulletIndex] = table.Copy(BulletData)	--Place the bullet at the current index pos
ACE.BulletClient( ACE.CurBulletIndex, ACE.Bullet[ACE.CurBulletIndex], "Init" , 0 )
end

do
	local ResetVelocity = {

		AP = function(bdata)
			if not bdata.MuzzleVel then return end

			bdata.Flight:Normalize()
			bdata.Flight = bdata.Flight * (bdata.MuzzleVel * 39.37)
		end,
		HEAT = function(bdata)
			if not (bdata.MuzzleVel and bdata.SlugMV) then return end

			bdata.Flight:Normalize()

			local penmul = (bdata.penmul or ACE.GetGunValue(bdata, "penmul") or 1.2) * 0.77	--local penmul = (bdata.penmul or ACE.GetGunValue(bdata, "penmul") or 1.2) * 0.77

			bdata.Flight = bdata.Flight * (bdata.SlugMV * penmul) * 39.37
			bdata.NotFirstPen = false
		end,
		THEAT = function(bdata)
			DetCount = bdata.Detonated or 0

			if not (bdata.MuzzleVel and bdata.SlugMV and bdata.SlugMV1 and bdata.SlugMV2) then return end

			bdata.Flight:Normalize()

			local penmul = (bdata.penmul or ACE.GetGunValue(bdata, "penmul") or 1.2) * 0.77

			if DetCount == 1 then
				--print("Detonation1")
				bdata.Flight = bdata.Flight * (bdata.SlugMV * penmul) * 39.37
				bdata.NotFirstPen = false
			elseif DetCount == 2 then
				--print("Detonation2")
				bdata.Flight = bdata.Flight * (bdata.SlugMV2 * penmul) * 39.37
				bdata.NotFirstPen = false
			end
		end,
	}

	ResetVelocity.HE = ResetVelocity.AP
	ResetVelocity.HEP = ResetVelocity.AP
	ResetVelocity.SM = ResetVelocity.AP

	-- Resets the velocity of the bullet based on its current state on the serverside only.
	-- This will de-sync the clientside effect!
	local function DoResetVelocity(bdata)
		local resetFunc = ResetVelocity[bdata.Type] or ResetVelocity["AP"]
		return resetFunc(bdata)
	end

	--Restored old PropHit function, with some modifications so it doenst fuck up
	function ACE.DoReplicatedPropHit(Missile, Bullet)

		local FlightRes = { Entity = Missile, HitNormal = Missile.HitNorm, HitPos = Bullet.Pos, HitGroup = HITGROUP_GENERIC }
		local Index = Bullet.Index

		local BulletPropImpact = ACE.RoundTypes[Bullet.Type]["propimpact"]
		local Retry = BulletPropImpact( Index, Bullet, FlightRes.Entity ,  FlightRes.HitNormal , FlightRes.HitPos , FlightRes.HitGroup )				--If we hit stuff then send the resolution to the damage function

		--This is crucial, to avoid 2nd tandem munitions spawn on 1st Bullet hitpos
		Bullet.FirstPos = FlightRes.HitPos

		--Internally used in case of HEAT hitting world, penetrating or not
		if Retry == "Penetrated" then

			DoResetVelocity(Bullet)

			if Bullet.OnPenetrated then Bullet.OnPenetrated(Index, Bullet, FlightRes) end

			ACE.BulletClient( Index, Bullet, "Update" , 2 , FlightRes.HitPos  )
			ACE.CalcBulletFlight( Index, Bullet, true )
		else

			if Bullet.OnEndFlight then Bullet.OnEndFlight(Index, Bullet, FlightRes) end

			ACE.BulletClient( Index, Bullet, "Update" , 1 , FlightRes.HitPos  )
			ACE.BulletEndFlight = ACE.RoundTypes[Bullet.Type]["endflight"]
			ACE.BulletEndFlight( Index, Bullet, FlightRes.HitPos, FlightRes.HitNormal )
		end

	end
end

hook.Add( "InitPostEntity", "ACE_Missiles_DupeDeny", function()
	-- Need to ensure this is called after InitPostEntity because Adv. Dupe 2 resets its whitelist upon this event.
	timer.Simple(1, function()
		duplicator.Deny("ace_missile")
		duplicator.Deny("ace_missile_swep_guided")
	end)
end )

hook.Add( "InitPostEntity", "ACE_Missiles_AddLinkable", function()
	-- Need to ensure this is called after InitPostEntity because Adv. Dupe 2 resets its whitelist upon this event.
	timer.Simple(1, function()
		if ACE.E2_LinkTables and istable(ACE.E2_LinkTables) then
		ACE.E2_LinkTables["ace_rack"] = {AmmoLink = false}
		end
	end)
end )
