local ACE = ACE or {}

function ACE_GetHitAngle( HitNormal , HitVector )

	HitVector = HitVector * -1
	local Angle = math.min(math.deg(math.acos(HitNormal:Dot( HitVector:GetNormalized() ) ) ),89.999 )
	--print("Angle : " ..Angle.. "\n")
	return Angle

end

--Calculates the vector of the ricochet of a round upon impact at a set angle
function ACE_RicochetVector(Flight, HitNormal)
	local Vec = Flight:GetNormalized()

	return Vec - ( 2 * Vec:Dot(HitNormal) ) * HitNormal
end

-- Handles the impact of a round on a target
function ACE_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone  )

--[[
	print("======DATA=======")
	print(HitNormal)
	print(Bullet["Flight"])
	print("======DATA=======")

	debugoverlay.Line(HitPos, HitPos + (Bullet["Flight"]), 5, Color(255,100,0), true )
	debugoverlay.Line(HitPos, HitPos + (HitNormal * 100), 5, Color(255,255,0), true )
]]
	Bullet.Ricochets = Bullet.Ricochets or 0

	local Angle	= ACE_GetHitAngle( HitNormal , Bullet["Flight"] )
	local HitRes	= ACE_Damage( Target, Energy, Bullet["PenArea"], Angle, Bullet["Owner"], Bone, Bullet["Gun"], Bullet["Type"] )

	HitRes.Ricochet = false

	local Ricochet  = 0
	local ricoProb  = 1

	--Missiles are special. This should be dealt with guns only
	if (IsValid(Bullet["Gun"]) and Bullet["Gun"]:GetClass() ~= "acf_missile" and Bullet["Gun"]:GetClass() ~= "ace_missile_swep_guided") or not IsValid(Bullet["Gun"]) then

		local sigmoidCenter = Bullet.DetonatorAngle or ( (Bullet.Ricochet or 55) - math.max(Speed / 39.37 - (Bullet.LimitVel or 800),0) / 100 ) --Changed the abs to a min. Now having a bullet slower than normal won't increase chance to richochet.

		--Guarenteed Richochet
		if Angle > 85 then
			ricoProb = 0

		--Guarenteed to not richochet
		elseif Bullet.Caliber * 3.33 > Target.ACE.Armour / math.max(math.sin(90-Angle),0.0001)  then
			ricoProb = 1

		else
			ricoProb = math.min(1-(math.max(Angle - sigmoidCenter,0) / sigmoidCenter * 4),1)
		end
	end

	-- Checking for ricochet. The angle value is clamped but can cause game crashes if this overflow check doesnt exist. Why?
	if ricoProb < math.random() and Angle < 90 then
		Ricochet	= math.Clamp(Angle / 90, 0.1, 1) -- atleast 10% of energy is kept
		HitRes.Loss	= 1 - Ricochet
		Energy.Kinetic = Energy.Kinetic * HitRes.Loss
	end

	if HitRes.Kill then
		local Debris = ACE_APKill( Target , (Bullet["Flight"]):GetNormalized() , Energy.Kinetic )
		table.insert( Bullet["Filter"] , Debris )
	end

	if Ricochet > 0 and Bullet.Ricochets < 3 and IsValid(Target) then

		Bullet.Ricochets	= Bullet.Ricochets + 1
		Bullet["Pos"]	= HitPos + HitNormal * 0.75
		Bullet.FlightTime	= 0
		Bullet.Flight	= (ACE_RicochetVector(Bullet.Flight, HitNormal) + VectorRand() * 0.025):GetNormalized() * Speed * Ricochet

		if IsValid( ACE_GetPhysicalParent(Target):GetPhysicsObject() ) then
			Bullet.TraceBackComp = math.max(ACE_GetPhysicalParent(Target):GetPhysicsObject():GetVelocity():Dot(Bullet["Flight"]:GetNormalized()),0)
		end

		HitRes.Ricochet = true

	end

	ACE_KEShove( Target, HitPos, Bullet["Flight"]:GetNormalized(), Energy.Kinetic * HitRes.Loss * 1000 * Bullet["ShovePower"] * (GetConVar("acf_recoilpush"):GetFloat() or 1))

	return HitRes
end

--Handles Ground penetrations
function ACE_PenetrateGround( Bullet, Energy, HitPos, HitNormal )

	Bullet.GroundRicos = Bullet.GroundRicos or 0

	local MaxDig = (( Energy.Penetration * 1 / Bullet.PenArea ) * ACE.KEtoRHA / ACE.GroundtoRHA ) / 25.4

	--print("Max Dig: ' .. MaxDig .. '\nEnergy Pen: ' .. Energy.Penetration .. '\n")

	local HitRes = {Penetrated = false, Ricochet = false}
	local TROffset = 0.235 * Bullet.Caliber / 1.14142 --Square circumscribed by circle. 1.14142 is an aproximation of sqrt 2. Radius and divide by 2 for min/max cancel.

	local DigRes = util.TraceHull( {

		start = HitPos + Bullet.Flight:GetNormalized() * 0.1,
		endpos = HitPos + Bullet.Flight:GetNormalized() * (MaxDig + 0.1),
		filter = Bullet.Filter,
		mins = Vector( -TROffset, -TROffset, -TROffset ),
		maxs = Vector( TROffset, TROffset, TROffset ),
		mask = MASK_SOLID_BRUSHONLY

		} )

	--debugoverlay.Box( DigRes.StartPos, Vector( -TROffset, -TROffset, -TROffset ), Vector( TROffset, TROffset, TROffset ), 5, Color(0,math.random(100,255),0) )
	--debugoverlay.Box( DigRes.HitPos, Vector( -TROffset, -TROffset, -TROffset ), Vector( TROffset, TROffset, TROffset ), 5, Color(0,math.random(100,255),0) )
	--debugoverlay.Line( DigRes.StartPos, HitPos + Bullet.Flight:GetNormalized() * (MaxDig + 0.1), 5 , Color(0,math.random(100,255),0) )

	local loss = DigRes.FractionLeftSolid

	--couldn't penetrate
	if loss == 1 or loss == 0 then

		local Ricochet  = 0
		local Speed	= Bullet.Flight:Length() / ACE.VelScale
		local Angle	= ACE_GetHitAngle( HitNormal, Bullet.Flight )
		local MinAngle  = math.min(Bullet.Ricochet - Speed / 39.37 / 30 + 20,89.9)  --Making the chance of a ricochet get higher as the speeds increase

		if Angle > math.random(MinAngle,90) and Angle < 89.9 then	--Checking for ricochet
			Ricochet = Angle / 90 * 0.75
		end

		if Ricochet > 0 and Bullet.GroundRicos < 2 then
			Bullet.GroundRicos  = Bullet.GroundRicos + 1
			Bullet.Pos		= HitPos + HitNormal * 1
			Bullet.Flight	= (ACE_RicochetVector(Bullet.Flight, HitNormal) + VectorRand() * 0.05):GetNormalized() * Speed * Ricochet
			HitRes.Ricochet	= true
		end

	--penetrated
	else
		Bullet.Flight	= Bullet.Flight * (1 - loss)
		Bullet.Pos		= DigRes.StartPos + Bullet.Flight:GetNormalized() * 0.25 --this is actually where trace left brush
		HitRes.Penetrated	= true
	end

	return HitRes
end

--helper function to replace ENT:ApplyForceOffset()
--Gmod applyforce creates weird torque when moving https://github.com/Facepunch/garrysmod-issues/issues/5159
local m_insq = 1 / 39.37 ^ 2
local function ACE_ApplyForceOffset(Phys, Force, Pos)
	Phys:ApplyForceCenter(Force)
	local off = Pos - Phys:LocalToWorld(Phys:GetMassCenter())
	local angf = off:Cross(Force) * m_insq * 360 / (2 * 3.1416)
	Phys:ApplyTorqueCenter(angf)
end

--Handles ACE forces (HE Push, Recoil, etc)
function ACE_KEShove(Target, Pos, Vec, KE )
	if not IsValid(Target) then return end

	local CanDo = hook.Run("ACE_KEShove", Target, Pos, Vec, KE )
	if CanDo == false then return end

	--Gets the baseplate of target
	local parent = ACE_GetPhysicalParent(Target)
	local phys	= parent:GetPhysicsObject()
	if not IsValid(phys) then return end

	local Scaling = 1
	--Scale down the offset relative to chassis if the gun is parented
	if Target ~= parent then
		parent:SetColor(Color(255,255,151))
		Scaling = 0.001
	end

	local Local	= parent:WorldToLocal(Pos) * Scaling
	local Res	= Local + phys:GetMassCenter()
	Pos = parent:LocalToWorld(Res)

	local massratio = 1
	local con = ACE.GetContraption( parent )
	if con then
		massratio = ACE.GetContraptionMassRatio( con ) print("ratio:", massratio)
	end
	ACE_ApplyForceOffset(phys, Vec:GetNormalized() * KE * massratio, Pos )

end