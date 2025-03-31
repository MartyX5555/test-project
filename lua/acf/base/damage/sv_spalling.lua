local ACE = ACE or {}
local PI = math.pi

-- This file is meant for the advanced damage functions used by the Armored Combat Framework
ACE.Spall		= {}
ACE.CurSpallIndex = 0
ACE.SpallMax	= 250

--Used for tracebug HE workaround
ACE.CritEnts = {
	acf_gun                    = true,
	acf_ammo                   = true,
	acf_engine                 = true,
	acf_gearbox                = true,
	acf_fueltank               = true,
	acf_rack                   = true,
	acf_missile                = true,
	ace_missile_swep_guided    = true,
	prop_vehicle_prisoner_pod  = true,
	gmod_wire_gate             = true
}


--Handles normal spalling
function ACE_Spall( HitPos , HitVec , Filter , KE , Caliber , Armour , Inflictor , Material)

	--Don't use it if it's not allowed to
	if not ACE.Spalling then return end

	local Mat		= Material or "RHA"
	local MatData	= ACE_GetMaterialData( Mat )

	-- Spall damage
	local SpallMul	= MatData.spallmult or 1

	-- Spall armor factor bias
	local ArmorMul	= MatData.ArmorMul or 1
	local UsedArmor	= Armour * ArmorMul

	if SpallMul > 0 and Caliber * 10 > UsedArmor and Caliber > 3 then

		-- Normal spalling core
		--For better consistency against light armor, spall no longer cares about the thickness of the armor but moreso the hole the cannon punches through and the energy it uses doing so.

		--Weight factor variable. Affects both the weight of the spall and indirectly affects the caliber of the spall
		--0.75 results in 11mm spall with a 120mm SBC
		--15 results in 20mm spall
		local WeightFactor = 15

		--Direct multiplier for spall velocity, used to fine-tune the spall penetration
		local Velocityfactor = 300

		local TotalWeight = PI * (Caliber / 2) ^ 2 * ArmorMul * WeightFactor
		local Spall = math.min(math.floor((Caliber - 3) * ACE.KEtoSpall * SpallMul * 1.33) * ACE.SpallMult, 32)
		local SpallWeight = TotalWeight / Spall * SpallMul
		local SpallVel = (KE * 16 / SpallWeight) ^ 0.5 / Spall * SpallMul * Velocityfactor
		local SpallArea = (SpallWeight / 7.8) ^ 0.33
		local SpallEnergy = ACE_Kinetic(SpallVel, SpallWeight, 800)

		for i = 1,Spall do

			ACE.CurSpallIndex = ACE.CurSpallIndex + 1
			if ACE.CurSpallIndex > ACE.SpallMax then
				ACE.CurSpallIndex = 1
			end

			-- Normal Trace creation
			local Index = ACE.CurSpallIndex

			ACE.Spall[Index] = {}
			ACE.Spall[Index].start  = HitPos
			ACE.Spall[Index].endpos = HitPos + ( HitVec:GetNormalized() + VectorRand() * ACE.SpallingDistribution ):GetNormalized() * math.max( SpallVel, 600 ) --Spall endtrace. Used to determine spread and the spall trace length. Only adjust the value in the max to determine the minimum distance spall will travel. 600 should be fine.
			ACE.Spall[Index].filter = table.Copy(Filter)
			ACE.Spall[Index].mins	= Vector(0,0,0)
			ACE.Spall[Index].maxs	= Vector(0,0,0)

			ACE_SpallTrace(HitVec, Index , SpallEnergy , SpallArea , Inflictor)

			--little sound optimization
			if i < math.max(math.Round(Spall / 2), 1) then
				sound.Play(ACE.Sounds["Penetrations"]["large"]["close"][math.random(1,#ACE.Sounds["Penetrations"]["large"]["close"])], HitPos, 75, 100, 0.5)
			end

		end
	end
end


--Dedicated function for HESH spalling
function ACE_PropShockwave( HitPos, HitVec, Filter, Caliber )

	--Don't even bother at calculating something that doesn't exist
	if not next(Filter) then return end

	--General
	local FindEnd	= true			--marked for initial loop
	local iteration	= 0				--since while has not index

	local EntsToHit	= Filter	--Used for the second tracer, where it tells what ents must hit

	--HitPos
	local HitFronts	= {}				--Any tracefronts hitpos will be stored here
	local HitBacks	= {}				--Any traceback hitpos will be stored here

	--Distances. Store any distance
	local FrontDists	= {}
	local BackDists	= {}

	local Normals	= {}

	--Results
	local fNormal	= Vector(0,0,0)
	local finalpos
	local TotalArmor	= {}

	--Tracefront general data--
	local TrFront	= {}
	TrFront.start	= HitPos
	TrFront.endpos	= HitPos + HitVec:GetNormalized() * Caliber * 1.5
	TrFront.ignoreworld = true
	TrFront.filter	= {}

	--Traceback general data--
	local TrBack		= {}
	TrBack.start		= HitPos + HitVec:GetNormalized() * Caliber * 1.5
	TrBack.endpos	= HitPos
	TrBack.ignoreworld  = true
	TrBack.filter	= function( ent ) if ( ent:EntIndex() == EntsToHit[#EntsToHit]:EntIndex()) then return true end end

	while FindEnd do

		iteration = iteration + 1
		--print('iteration #' .. iteration)

		--In case of total failure, this loop is limited to 1000 iterations, don't make me increase it even more.
		if iteration >= 1000 then FindEnd = false end

		--================-TRACEFRONT-==================-
		local tracefront = util.TraceHull( TrFront )

		--insert the hitpos here
		local HitFront = tracefront.HitPos
		table.insert( HitFronts, HitFront )

		--distance between the initial hit and hitpos of front plate
		local distToFront = math.abs( (HitPos - HitFront):Length() )
		table.insert( FrontDists, distToFront)

		--TraceFront's armor entity
		local Armour = tracefront.Entity.ACE and tracefront.Entity.ACE.Armour or 0

		--Code executed once its scanning the 2nd prop
		if iteration > 1 then

			--check if they are totally overlapped
			if math.Round(FrontDists[iteration-1]) ~= math.Round(FrontDists[iteration] ) then

				--distance between the start of ent1 and end of ent2
				local space = math.abs( (HitFronts[iteration] - HitBacks[iteration - 1]):Length() )

				--prop's material
				local mat = tracefront.Entity.ACE and tracefront.Entity.ACE.Material or "RHA"
				local MatData = ACE_GetMaterialData( mat )


				local Hasvoid = false
				local NotOverlap = false

				--print("DATA TABLE - DONT FUCKING DELETE")
				--print('distToFront: ' .. distToFront)
				--print('BackDists[iteration - 1]: ' .. BackDists[iteration - 1])
				--print('DISTS DIFF: ' .. distToFront - BackDists[iteration - 1])

				--check if we have void
				if space > 1 then
					Hasvoid = true
				end

				--check if we dont have props semi-overlapped
				if distToFront > BackDists[iteration - 1] then
					NotOverlap = true
				end

				--check if we have spaced armor, spall liners ahead, if so, end here
				if (Hasvoid and NotOverlap) or (tracefront.Entity:IsValid() and ACE.CritEnts[ tracefront.Entity:GetClass() ]) or MatData.Stopshock then
					--print("stopping")
					FindEnd	= false
					finalpos	= HitBacks[iteration - 1] + HitVec:GetNormalized() * 0.1
					fNormal	= Normals[iteration - 1]
					--print("iteration #' .. iteration .. ' / FINISHED!")

					break
				end
			end

			--start inserting new ents to the table when iteration pass 1, so we don't insert the already inserted prop (first one)
			table.insert( EntsToHit, tracefront.Entity)

		end

		--Filter this ent from being processed again in the next checks
		table.insert( TrFront.filter, tracefront.Entity )

		--Add the armor value to table
		table.insert( TotalArmor, Armour )

		--================-TRACEBACK-==================
		local traceback = util.TraceHull( TrBack )

		--insert the hitpos here
		local HitBack = traceback.HitPos
		table.insert( HitBacks, HitBack )

		--store the dist between the backhit and the hitvec
		local distToBack = math.abs( (HitPos - HitBack):Length() )
		table.insert( BackDists, distToBack)

		table.insert( Normals, traceback.HitNormal )

		--flag this iteration as lost
		if not tracefront.Hit then

			--print("[ACE|WARN]- TRACE HAS BROKEN!")

			FindEnd	= false
			finalpos	= HitBack + HitVec:GetNormalized() * 0.1
			fNormal	= Normals[iteration]
			--print("iteration #' .. iteration .. ' / FINISHED")

			break
		end

		--for red traceback
		--debugoverlay.Line( traceback.StartPos + Vector(0,0,#EntsToHit * 0.1), traceback.HitPos + Vector(0,0,#EntsToHit * 0.1), 20 , Color(math.random(100,255),0,0) )
		--for green tracefront
		--debugoverlay.Line( tracefront.StartPos + Vector(0,0,#EntsToHit * 0.1), tracefront.HitPos + Vector(0,0,#EntsToHit * 0.1), 20 , Color(0,math.random(100,255),0) )
	end

	local ArmorSum = 0
	for i = 1, #TotalArmor do
		--print("Armor prop count: ' .. i..", Armor value: ' .. TotalArmor[i])
		ArmorSum = ArmorSum + TotalArmor[i]
	end

	--print(ArmorSum)
	return finalpos, ArmorSum, TrFront.filter, fNormal
end


--Handles HESH spalling
function ACE_Spall_HESH( HitPos, HitVec, Filter, HEFiller, Caliber, Armour, Inflictor, Material )

	local spallPos, Armour, PEnts, fNormal = ACE_PropShockwave( HitPos, HitVec, Filter, Caliber )

	local Mat		= Material or "RHA"
	local MatData	= ACE_GetMaterialData( Mat )

	-- Spall damage
	local SpallMul	= MatData.spallmult or 1

	-- Spall armor factor bias
	local ArmorMul	= MatData.ArmorMul or 1
	local UsedArmor	= Armour * ArmorMul

	if SpallMul > 0 and HEFiller / 1501 * 4 > UsedArmor then

		--era stops the spalling at the cost of being detonated
		if MatData.IsExplosive then Filter[1].ACE.ERAexploding = true return end

		-- HESH spalling core
		local TotalWeight = PI * (Caliber / 2) ^ 2 * math.max(UsedArmor, 30) * 2500
		local Spall = math.min(math.floor((Caliber - 3) / 3 * ACE.KEtoSpall * SpallMul), 24) --24
		local SpallWeight = TotalWeight / Spall * SpallMul
		local SpallVel = (HEFiller * 16 / SpallWeight) ^ 0.5 / Spall * SpallMul
		local SpallArea = (SpallWeight / 7.8) ^ 0.33
		local SpallEnergy = ACE_Kinetic(SpallVel, SpallWeight, 800)

		for i = 1,Spall do

			ACE.CurSpallIndex = ACE.CurSpallIndex + 1
			if ACE.CurSpallIndex > ACE.SpallMax then
				ACE.CurSpallIndex = 1
			end

			-- HESH trace creation
			local Index = ACE.CurSpallIndex

			ACE.Spall[Index]			= {}
			ACE.Spall[Index].start	= spallPos
			ACE.Spall[Index].endpos	= spallPos + ((fNormal * 2500 + HitVec):GetNormalized() + VectorRand() / 3):GetNormalized() * math.max(SpallVel * 10,math.random(450,600)) --I got bored of spall not going across the tank
			ACE.Spall[Index].filter	= table.Copy(PEnts)

			ACE_SpallTrace(HitVec, Index , SpallEnergy , SpallArea , Inflictor )

			--little sound optimization
			if i < math.max(math.Round(Spall / 4), 1) then
				sound.Play(ACE.Sounds["Penetrations"]["large"]["close"][math.random(1,#ACE.Sounds["Penetrations"]["large"]["close"])], spallPos, 75, 100, 0.5)
			end
		end
	end
end


--Spall trace core. For HESH and normal spalling
function ACE_SpallTrace(HitVec, Index, SpallEnergy, SpallArea, Inflictor )

	local SpallRes = util.TraceLine(ACE.Spall[Index])

	-- Check if spalling hit something
	if SpallRes.Hit and ACE_Check( SpallRes.Entity ) then

		do

			local phys = SpallRes.Entity:GetPhysicsObject()

			if IsValid(phys) and ACE_CheckClips( SpallRes.Entity, SpallRes.HitPos ) then

				table.insert( ACE.Spall[Index].filter , SpallRes.Entity )

				ACE_SpallTrace( SpallRes.StartPos , Index , SpallEnergy , SpallArea , Inflictor, Material )
				return
			end

		end

		-- Get the spalling hitAngle
		local Angle		= ACE_GetHitAngle( SpallRes.HitNormal , HitVec )

		local Mat		= SpallRes.Entity.ACE.Material or "RHA"
		local MatData	= ACE_GetMaterialData( Mat )

		local spallarmor	= MatData.spallarmor

		SpallEnergy.Penetration = SpallEnergy.Penetration / spallarmor

		--extra damage for ents like ammo, engines, etc
		if ACE.CritEnts[ SpallRes.Entity:GetClass() ] then
			SpallEnergy.Penetration = SpallEnergy.Penetration * 1.5
		end

		-- Applies the damage to the impacted entity
		local HitRes = ACE_Damage( SpallRes.Entity , SpallEnergy , SpallArea , Angle , Inflictor, 0, nil, "Spall")

		-- If it's able to destroy it, kill it and filter it
		if HitRes.Kill then
			local Debris = ACE_APKill( SpallRes.Entity , HitVec:GetNormalized() , SpallEnergy.Kinetic )
			if IsValid(Debris) then
				table.insert( ACE.Spall[Index].filter , Debris )
				ACE_SpallTrace( SpallRes.HitPos , Index , SpallEnergy , SpallArea , Inflictor, Material )
			end
		end

		-- Applies a decal
		util.Decal("GunShot1",SpallRes.StartPos, SpallRes.HitPos, ACE.Spall[Index].filter )
--[[
		-- The entity was penetrated --Disabled since penetration values are not real
		if HitRes.Overkill > 0 then

			table.insert( ACE.Spall[Index].filter , SpallRes.Entity )

			-- Reduces the current SpallEnergy data for the next entity to hit
			SpallEnergy.Penetration = SpallEnergy.Penetration * (1-HitRes.Loss)
			SpallEnergy.Momentum = SpallEnergy.Momentum * (1-HitRes.Loss)

			-- Retry
			ACE_SpallTrace( SpallRes.HitPos , Index , SpallEnergy , SpallArea , Inflictor, Material )

			debugoverlay.Line( SpallRes.StartPos + Vector(2,0,0), SpallRes.HitPos + Vector(2,0,0), 10 , Color(255,255,0), true )

			return
		end
]]
		--debugoverlay.Line( SpallRes.StartPos + Vector(1,0,0), SpallRes.HitPos + Vector(1,0,0), 10 , Color(255,0,0), true )

	end

	--debugoverlay.Line( SpallRes.StartPos, SpallRes.HitPos, 10 , Color(0,255,0), true )
end