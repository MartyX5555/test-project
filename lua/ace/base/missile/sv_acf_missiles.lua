--[[
			  _____ ______	 __  __ _		  _ _
		/\	/  ____|  ____| |  \/  (_)	     (_) |
	   /  \ | |	   | |__	| \  / |_ ___ ___ _| | ___  ___
	  / /\ \| |	   |  __|	| |\/| | / __/ __| | |/ _ \/ __|
	 / ____ \ |____| |	    | |  | | \__ \__ \ | |  __/\__ \
	/_/	   \_\_____|_|	    |_|  |_|_|___/___/_|_|\___||___/

	By Bubbus + Cre8or

	A reimplementation of XCF missiles and bombs, with guidance and more.
]]

local ACE = ACE or {}
--[[
	Differences with the default bullet function:
		1.- It doesnt count traceback, since the missile has no velocity and the bullet will not be hitting the initial launcher.
]]--
function ACFM_BulletLaunch(BulletData)

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

	BulletData.FuseLength	= type(BulletData.FuseLength) == "number" and BulletData.FuseLength or 0

	if BulletData.Filter then
		table.Add(BulletData.Filter, { BulletData.Gun } )
	else
		BulletData.Filter = { BulletData.Gun }
	end

	BulletData.Index		= ACE.CurBulletIndex
	ACE.Bullet[ACE.CurBulletIndex] = table.Copy(BulletData)	--Place the bullet at the current index pos
	ACE_BulletClient( ACE.CurBulletIndex, ACE.Bullet[ACE.CurBulletIndex], "Init" , 0 )

end



function ACFM_ExpandBulletData(bullet)

	local toconvert		= {}
	toconvert["Id"]		= bullet["Id"]			or "12.7mmMG"
	toconvert["Type"]	= bullet["Type"]			or "AP"
	toconvert["PropLength"] = bullet["PropLength"]	or 0
	toconvert["ProjLength"] = bullet["ProjLength"]	or 0
	toconvert["Data5"]	= bullet["FillerVol"]	or bullet["Flechettes"] or bullet["Data5"]	or 0
	toconvert["Data6"]	= bullet["ConeAng"]		or bullet["FlechetteSpread"] or bullet["Data6"] or 0
	toconvert["Data7"]	= bullet["Data7"]		or 0
	toconvert["Data8"]	= bullet["Data8"]		or 0
	toconvert["Data9"]	= bullet["Data9"]		or 0
	toconvert["Data10"]	= bullet["Tracer"]		or bullet["Data10"]		or 0
	toconvert["Colour"]	= bullet["Colour"]		or Color(255, 255, 255)
	toconvert["Data13"]	= bullet["ConeAng2"]		or bullet["Data13"]		or 0
	toconvert["Data14"]	= bullet["HEAllocation"]	or bullet["Data14"]		or 0
	toconvert["Data15"]	= bullet["Data15"]		or 0

	local rounddef	= ACE.RoundTypes[bullet.Type] or error("No definition for the shell-type", bullet.Type)
	local conversion	= rounddef.convert

	if not conversion then error("No conversion available for this shell!") end
	local ret = conversion( nil, toconvert )

	ret.Pos		= bullet.Pos	or Vector(0,0,0)
	ret.Flight	= bullet.Flight or Vector(0,0,0)
	ret.Type		= ret.Type	or bullet.Type

	local cvarGrav  = GetConVar("sv_gravity")
	ret.Accel	= cvarGrav
	if ret.Tracer == 0 and bullet["Tracer"] and bullet["Tracer"] > 0 then ret.Tracer = bullet["Tracer"] end
	ret.Colour	= toconvert["Colour"]

	ret.Sound = bullet.Sound

	return ret

end




function ACFM_MakeCrateForBullet(self, bullet)

	if type(bullet) ~= "table" and bullet.BulletData then
		self:SetNWString( "Sound", bullet.Sound or (bullet.Primary and bullet.Primary.Sound))
		self:SetOwner(bullet:GetOwner())
		bullet = bullet.BulletData
	end


	self:SetNWInt( "Caliber", bullet.Caliber or 10)
	self:SetNWInt( "ProjMass", bullet.ProjMass or 10)
	self:SetNWInt( "FillerMass", bullet.FillerMass or 0)
	self:SetNWInt( "DragCoef", bullet.DragCoef or 1)
	self:SetNWString( "AmmoType", bullet.Type or "AP")
	self:SetNWInt( "Tracer" , bullet.Tracer or 0)
	local col = bullet.Colour or self:GetColor()
	self:SetNWVector( "Color" , Vector(col.r, col.g, col.b))
	self:SetNWVector( "TracerColour" , Vector(col.r, col.g, col.b))
	self:SetColor(col)

end




-- TODO: modify ACF to use this global table, so any future tweaks won't break anything here.
ACE.FillerDensity =
{
	SM =	2000,
	HE =	1000,
	HEAT =  1450,
	THEAT =  1450,
}




function ACFM_CompactBulletData(crate)

	local compact = {}

	compact["Id"] =			crate.RoundId	or crate.Id
	compact["Type"] =			crate.RoundType	or crate.Type
	compact["PropLength"] =	crate.PropLength	or crate.RoundPropellant
	compact["ProjLength"] =	crate.ProjLength	or crate.RoundProjectile
	compact["Data5"] =			crate.Data5		or crate.RoundData5		or crate.FillerVol	or crate.CavVol			or crate.Flechettes
	compact["Data6"] =			crate.Data6		or crate.RoundData6		or crate.ConeAng		or crate.FlechetteSpread
	compact["Data7"] =			crate.Data7		or crate.RoundData7
	compact["Data8"] =			crate.Data8		or crate.RoundData8
	compact["Data9"] =			crate.Data9		or crate.RoundData9
	compact["Data10"] =		crate.Data10		or crate.RoundData10		or crate.Tracer
--11
--12
	compact["Data13"] =		crate.Data13		or crate.RoundData13
	compact["Data14"] =		crate.Data14		or crate.RoundData14
	compact["Data15"] =		crate.Data15		or crate.RoundData15

	compact["Colour"] =		crate.GetColor and crate:GetColor() or crate.Colour
	compact["Sound"] =		crate.Sound


	if not compact.Data5 and crate.FillerMass then
		local Filler = ACE.FillerDensity[compact.Type]

		if Filler then
			compact.Data5 = crate.FillerMass / ACE.HEDensity * Filler
		end
	end

	return compact
end

--Restored old PropHit function, with some modifications so it doenst fuck up
function ACE_DoReplicatedPropHit(Missile, Bullet)

	local FlightRes = { Entity = Missile, HitNormal = Missile.HitNorm, HitPos = Bullet.Pos, HitGroup = HITGROUP_GENERIC }
	local Index = Bullet.Index

	local ACE_BulletPropImpact = ACE.RoundTypes[Bullet.Type]["propimpact"]
	local Retry = ACE_BulletPropImpact( Index, Bullet, FlightRes.Entity ,  FlightRes.HitNormal , FlightRes.HitPos , FlightRes.HitGroup )				--If we hit stuff then send the resolution to the damage function

	--This is crucial, to avoid 2nd tandem munitions spawn on 1st Bullet hitpos
	Bullet.FirstPos = FlightRes.HitPos

	--Internally used in case of HEAT hitting world, penetrating or not
	if Retry == "Penetrated" then

		ACFM_ResetVelocity(Bullet)

		if Bullet.OnPenetrated then Bullet.OnPenetrated(Index, Bullet, FlightRes) end

		ACE_BulletClient( Index, Bullet, "Update" , 2 , FlightRes.HitPos  )
		ACE_CalcBulletFlight( Index, Bullet, true )
	else

		if Bullet.OnEndFlight then Bullet.OnEndFlight(Index, Bullet, FlightRes) end

		ACE_BulletClient( Index, Bullet, "Update" , 1 , FlightRes.HitPos  )
		ACE_BulletEndFlight = ACE.RoundTypes[Bullet.Type]["endflight"]
		ACE_BulletEndFlight( Index, Bullet, FlightRes.HitPos, FlightRes.HitNormal )
	end

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

			local penmul = (bdata.penmul or ACE_GetGunValue(bdata, "penmul") or 1.2) * 0.77	--local penmul = (bdata.penmul or ACE_GetGunValue(bdata, "penmul") or 1.2) * 0.77

			bdata.Flight = bdata.Flight * (bdata.SlugMV * penmul) * 39.37
			bdata.NotFirstPen = false
		end,
		THEAT = function(bdata)
			DetCount = bdata.Detonated or 0

			if not (bdata.MuzzleVel and bdata.SlugMV and bdata.SlugMV1 and bdata.SlugMV2) then return end

			bdata.Flight:Normalize()

			local penmul = (bdata.penmul or ACE_GetGunValue(bdata, "penmul") or 1.2) * 0.77

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
	function ACFM_ResetVelocity(bdata)
		local resetFunc = ResetVelocity[bdata.Type] or ResetVelocity["AP"]
		return resetFunc(bdata)
	end
end


hook.Add( "InitPostEntity", "ACFMissiles_DupeDeny", function()
	-- Need to ensure this is called after InitPostEntity because Adv. Dupe 2 resets its whitelist upon this event.
	timer.Simple(1, function()
		duplicator.Deny("ace_missile")
		duplicator.Deny("ace_missile_swep_guided")
	end)
end )


hook.Add( "InitPostEntity", "ACFMissiles_AddLinkable", function()
	-- Need to ensure this is called after InitPostEntity because Adv. Dupe 2 resets its whitelist upon this event.
	timer.Simple(1, function()
		if ACE_E2_LinkTables and istable(ACE_E2_LinkTables) then
			ACE_E2_LinkTables["ace_rack"] = {AmmoLink = false}
		end
	end)
end )
