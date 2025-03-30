local ACE = ACE or {}

-- optimization; reuse tables for ballistics traces
local TraceRes  = {}
local TraceInit = { output = TraceRes }

--Used for filter certain undesired ents inside of HE processing
ACE.HEFilter = {
	gmod_wire_hologram       = true,
	starfall_hologram        = true,
	prop_vehicle_crane       = true,
	prop_dynamic             = true,
	ace_debris               = true,
	sent_tanktracks_legacy   = true,
	sent_tanktracks_auto     = true,
	sent_prop2mesh 			 = true,
	ace_flares               = true
}

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

--I don't want HE processing every ent that it has in range
local function FindPropsInExplosionRadius( Hitpos, Radius )

	local Table = {}
	for _, ent in pairs( ents.FindInSphere( Hitpos, Radius ) ) do
		--skip any undesired ent
		if ent.ACE_KilledBase then continue end
		if ACE.HEFilter[ent:GetClass()] then continue end
		if not ent:IsSolid() then continue end

		table.insert( Table, ent )

	end

	return Table
end

--[[----------------------------------------------------------------------------
	Function:
		ACE_HE
	Arguments:
		HitPos	- detonation center,
		FillerMass  - mass of TNT being detonated in KG
		FragMass	- mass of the round casing for fragmentation purposes
		Inflictor	- owner of said TNT
		NoOcc	- table with entities to ignore
		Gun		- gun entity from which round is fired
	Purpose:
		Handles ACF explosions
------------------------------------------------------------------------------]]

local PI = math.pi

function ACE_HE( Hitpos , _ , FillerMass, FragMass, Inflictor, NoOcc, Gun )

	local Radius       = ACE_CalculateHERadius(FillerMass) -- Scalling law found on the net, based on 1PSI overpressure from 1 kg of TNT at 15m.
	local MaxSphere    = 4 * PI * (Radius * 2.54) ^ 2 -- Surface Area of the sphere at maximum radius
	local Power        = FillerMass * ACE.HEPower -- Power in KiloJoules of the filler mass of  TNT
	local Amp          = math.min(Power / 2000, 50)

	local Fragments    = math.max(math.floor((FillerMass / FragMass) * ACE.HEFrag), 2)
	local FragWeight   = FragMass / Fragments
	local FragVel      = ( Power * 50000 / FragWeight / Fragments ) ^ 0.5
	local FragArea     = (FragWeight / 7.8) ^ 0.33

	local OccFilter	= istable(NoOcc) and NoOcc or { NoOcc }
	local LoopKill	= true

	local Targets	= FindPropsInExplosionRadius( Hitpos, Radius )		-- Will give tiny HE just a pinch of radius to help it hit the player

	while LoopKill and Power > 0 do

		LoopKill = false

		local PowerSpent    = 0
		local DamageTable        = {}
		local TotalArea     = 0

		for i,Tar in ipairs(Targets) do

			if not IsValid(Tar) then continue end
			if Power <= 0 or Tar.Exploding then continue end

			local Type = ACE_Check(Tar)
			if Type then

				local TargetPos = Tar:GetPos()
				local TargetCenter = Tar:WorldSpaceCenter()
				local TargetDist = TargetPos:Distance(Hitpos)
				if TargetDist > Radius then continue end

				--Check if we have direct LOS with the victim prop. Laggiest part of HE
				TraceInit.start    = Hitpos
				TraceInit.endpos   = TargetCenter
				TraceInit.filter   = OccFilter

				util.TraceLine(TraceInit, true)

				--if above failed getting the target. Try again by nearest point instead.
				if not TraceRes.Hit then

					local Hitat = Tar:NearestPoint( Hitpos )

					--Done for dealing damage vs players and npcs
					if Type == "Squishy" then

						local hugenumber = 99999999999

						--Modified to attack the feet, center, or eyes, whichever is closest to the explosion
						--This is for scanning potential victims, damage goes later.
						local cldist = Hitpos:Distance( Hitat ) or hugenumber
						local Tpos
						local Tdis = hugenumber

						local Eyes = Tar:LookupAttachment("eyes")
						if Eyes then

							local Eyeat = Tar:GetAttachment( Eyes )
							if Eyeat then
								--Msg("Hitting Eyes\n")
								Tpos = Eyeat.Pos
								Tdis = Hitpos:Distance( Tpos ) or hugenumber
								if Tdis < cldist then
									Hitat = Tpos
									cldist = cldist
								end
							end
						end

						Tpos = TargetCenter
						Tdis = Hitpos:Distance( Tpos ) or hugenumber
						if Tdis < cldist then
							Hitat = Tpos
							cldist = cldist
						end
					end

					--if hitpos is inside of hitbox of the victim prop, nearest point will not work as intended
					if Hitat == Hitpos then Hitat = TargetPos end

					TraceInit.endpos = Hitat + (Hitat-Hitpos):GetNormalized() * 100
					util.TraceLine( TraceInit )
				end

				--HE has direct view with the prop, so lets damage it
				if TraceRes.Hit and TraceRes.Entity == Tar then

					Targets[i]		= nil  --Remove the thing we just hit from the table so we don't hit it again in the next round
					local DamageData		= {}

					DamageData.Ent		= Tar

					if ACE.CritEnts[Tar:GetClass()] then
						DamageData.LocalHitpos = WorldToLocal(Hitpos, Angle(0,0,0), TargetPos, Tar:GetAngles())
					end

					DamageData.Dist = TargetDist
					DamageData.Vec = (TargetPos - Hitpos):GetNormalized()

					local Sphere		= math.max(4 * PI * (DamageData.Dist * 2.54 ) ^ 2,1) --Surface Area of the sphere at the range of that prop
					local AreaAdjusted  = Tar.ACE.Area

					--Project the Area of the prop to the Area of the shadow it projects at the explosion max radius
					DamageData.Area = math.min(AreaAdjusted / Sphere,0.5) * MaxSphere
					table.insert(DamageTable, DamageData) --Add it to the Damage table so we know to damage it once we tallied everything

					-- is it adding it too late?
					TotalArea = TotalArea + DamageData.Area
				end
			else

				Targets[i] = NULL	--Target was invalid, so let's ignore it
				table.insert( OccFilter , Tar ) -- updates the filter in TraceInit too
			end

		end

		--Now that we have the props to damage, apply it here
		for _, Table in ipairs(DamageTable) do

			local Tar              = Table.Ent
			local TargetPos        = Tar:GetPos()
			local Feathering       = (1-math.min(1,Table.Dist / Radius)) ^ ACE.HEFeatherExp --print("Distance:", Table.Dist, "Radius:", Radius, "Ratio:", Table.Dist / Radius)
			local AreaFraction     = Table.Area / TotalArea
			local PowerFraction    = Power * AreaFraction  --How much of the total power goes to that prop
			local AreaAdjusted     = (Tar.ACE.Area / ACE.Threshold) * Feathering

			local BlastRes
			local Blast = {
				Penetration = PowerFraction ^ ACE.HEBlastPen * AreaAdjusted
			}

			local FragRes
			local FragHit	= Fragments * AreaFraction
			FragVel	= math.max(FragVel - ( (Table.Dist / FragVel) * FragVel ^ 2 * FragWeight ^ 0.33 / 10000 ) / ACE.DragDiv,0)
			local FragKE	= ACE_Kinetic( FragVel , FragWeight * FragHit, 1500 )
			if FragHit < 0 then
				if math.Rand(0,1) > FragHit then FragHit = 1 else FragHit = 0 end
			end

			-- erroneous HE penetration bug workaround; retries trace on crit ents after a short delay to ensure a hit.
			-- we only care about hits on critical ents, saves on processing power
			-- not going to re-use tables in the timer, shouldn't make too much difference

			-- Really required?

			if ACE.CritEnts[Tar:GetClass()] then

				timer.Simple(0.03, function()
					if not IsValid(Tar) then return end

					--recreate the hitpos and hitat, add slight jitter to hitpos and move it away some
					local NewHitpos = LocalToWorld(Table.LocalHitpos + Table.LocalHitpos:GetNormalized() * 3, Angle(math.random(),math.random(),math.random()), TargetPos, Tar:GetAngles())
					local NewHitat  = Tar:NearestPoint( NewHitpos )

					local Occlusion	= {
						start = NewHitpos,
						endpos = NewHitat + (NewHitat-NewHitpos):GetNormalized() * 100,
						filter = NoOcc,
					}
					local Occ	= util.TraceLine( Occlusion )

					if not Occ.Hit and NewHitpos ~= NewHitat then
						local NewHitat  = TargetPos
						Occlusion.endpos	= NewHitat + (NewHitat-NewHitpos):GetNormalized() * 100
						Occ = util.TraceLine( Occlusion )
					end

					if not (Occ.Hit and Occ.Entity:EntIndex() ~= Tar:EntIndex()) and not (not Occ.Hit and NewHitpos ~= NewHitat) then

						BlastRes = ACE_Damage ( Tar	, Blast  , AreaAdjusted , 0	, Inflictor , 0	, Gun , "HE" )
						FragRes = ACE_Damage ( Tar , FragKE , FragArea * FragHit , 0 , Inflictor , 0, Gun, "Frag" )

						if (BlastRes and BlastRes.Kill) or (FragRes and FragRes.Kill) then
							ACE_HEKill( Tar, (TargetPos - NewHitpos):GetNormalized(), PowerFraction , Hitpos)
						else
							ACE_KEShove(Tar, NewHitpos, (TargetPos - NewHitpos):GetNormalized(), PowerFraction * 20 * (GetConVar("acf_hepush"):GetFloat() or 1) ) --0.333
						end
					end
				end)

				--calculate damage that would be applied (without applying it), so HE deals correct damage to other props
				BlastRes = ACE_CalcDamage( Tar, Blast, AreaAdjusted, 0 )

			else

				BlastRes = ACE_Damage ( Tar  , Blast , AreaAdjusted , 0 , Inflictor ,0 , Gun, "HE" )
				FragRes = ACE_Damage ( Tar , FragKE , FragArea * FragHit , 0 , Inflictor , 0, Gun, "Frag" )

				if (BlastRes and BlastRes.Kill) or (FragRes and FragRes.Kill) then

					--Add the debris created to the ignore so we don't hit it in other rounds
					local Debris = ACE_HEKill( Tar , Table.Vec , PowerFraction , Hitpos )
					table.insert( OccFilter , Debris )

					LoopKill = true --look for fresh targets since we blew a hole somewhere

				else

					--Assuming about 1/30th of the explosive energy goes to propelling the target prop (Power in KJ * 1000 to get J then divided by 33)
					ACE_KEShove(Tar, Hitpos, Table.Vec, PowerFraction * 20 * (GetConVar("acf_hepush"):GetFloat() or 1) )

				end
			end

			PowerSpent = PowerSpent + PowerFraction * BlastRes.Loss / 2--Removing the energy spent killing props


		end

		Power = math.max(Power - PowerSpent,0)
	end

	util.ScreenShake( Hitpos, Amp, Amp, Amp / 15, Radius * 10 )
	--debugoverlay.Sphere(Hitpos, Radius, 10, Color(255,0,0,32), 1) --developer 1	in console to see

end

do
	-- Config
	local AmmoExplosionScale = 0.5
	local FuelExplosionScale = 0.005

	--converts what would be multiple simultaneous cache detonations into one large explosion
	function ACE_ScaledExplosion( ent )
		if ent.RoundType and ent.RoundType == "Refill" then return end

		local HEWeight
		local ExplodePos = {}

		local MaxGroup    = ACE.ScaledEntsMax	-- Max number of ents to be cached. Reducing this value will make explosions more realistic at the cost of more explosions = lag
		local MaxHE       = ACE.ScaledHEMax	-- Max amount of HE to be cached. This is useful when we dont want nukes being created by large amounts of clipped ammo.

		local Inflictor   = ent.Inflictor or nil
		local Owner       = ACE.GetEntityOwner(ent) or NULL

		if ent:GetClass() == "acf_fueltank" then

			local Fuel       = ent.Fuel	or 0
			local Capacity   = ent.Capacity  or 0
			local Type       = ent.FuelType  or "Petrol"

			HEWeight = ( math.min( Fuel, Capacity ) / ACE.FuelDensity[Type] ) * FuelExplosionScale
		else

			local HE       = ent.BulletData.FillerMass	or 0
			local Propel   = ent.BulletData.PropMass	or 0
			local Ammo     = ent.Ammo					or 0

			HEWeight = ( ( HE + Propel * ( ACE.PBase / ACE.HEPower ) ) * Ammo ) * AmmoExplosionScale
		end

		local Radius    = ACE_CalculateHERadius( HEWeight )
		local Pos       = ent:LocalToWorld(ent:OBBCenter())

		table.insert(ExplodePos, Pos)

		local LastHE = 0
		local Search = true
		local Filter = { ent }

		ent:Remove()

		local CExplosives = ACE.Explosives

		while Search do

			if #CExplosives == 1 then break end

			for i,Found in ipairs( CExplosives ) do

				if #Filter > MaxGroup or HEWeight > MaxHE then break end
				if not IsValid(Found) then continue end
				if Found:GetPos():DistToSqr(Pos) > Radius ^ 2 then continue end

				if not Found.Exploding then

					local EOwner = ACE.GetEntityOwner(Found) or NULL

					--Don't detonate explosives which we are not allowed to.
					if Owner ~= EOwner then continue end

					local Hitat = Found:NearestPoint( Pos )

					local Occlusion = {}
						Occlusion.start   = Pos
						Occlusion.endpos  = Hitat + (Hitat-Pos):GetNormalized() * 100
						Occlusion.filter  = Filter
					local Occ = util.TraceLine( Occlusion )

					--Filters any ent which blocks the trace.
					if Occ.Fraction == 0 then

						table.insert(Filter,Occ.Entity)

						Occlusion.filter	= Filter

						Occ = util.TraceLine( Occlusion )

					end

					if Occ.Hit and Occ.Entity:EntIndex() == Found.Entity:EntIndex() then

						local FoundHEWeight

						if Found:GetClass() == "acf_fueltank" then

							local Fuel       = Found.Fuel	or 0
							local Capacity   = Found.Capacity or 0
							local Type       = Found.FuelType or "Petrol"

							FoundHEWeight = ( math.min( Fuel, Capacity ) / ACE.FuelDensity[Type] ) * FuelExplosionScale
						else

							if Found.RoundType == "Refill" then Found:Remove() continue end

							local HE       = Found.BulletData.FillerMass	or 0
							local Propel   = Found.BulletData.PropMass	or 0
							local Ammo     = Found.Ammo					or 0

							FoundHEWeight = ( ( HE + Propel * ( ACE.PBase / ACE.HEPower)) * Ammo ) * AmmoExplosionScale
						end

						table.insert( ExplodePos, Found:LocalToWorld(Found:OBBCenter()) )

						HEWeight = HEWeight + FoundHEWeight

						Found.IsExplosive   = false
						Found.DamageAction  = false
						Found.KillAction    = false
						Found.Exploding     = true

						table.insert( Filter,Found )
						table.remove( CExplosives,i )
						Found:Remove()
					else

						if IsValid(Occ.Entity) and Occ.Entity:GetClass() ~= "acf_ammo" and Occ.Entity:GetClass() == "acf_fueltank" then
							if vFireInstalled then
								Occ.Entity:Ignite( _, HEWeight )
							else
								Occ.Entity:Ignite( 120, HEWeight / 10 )
							end
						end
					end
				end


			end

			if HEWeight > LastHE then
				Search = true
				LastHE = HEWeight
				Radius = ACE_CalculateHERadius( HEWeight )
			else
				Search = false
			end

		end

		local totalpos = Vector()
		for _, cratepos in pairs(ExplodePos) do
			totalpos = totalpos + cratepos
		end
		local AvgPos = totalpos / #ExplodePos

		HEWeight	= HEWeight * ACE.BoomMult
		Radius	= ACE_CalculateHERadius( HEWeight )

		ACE_HE( AvgPos , vector_origin , HEWeight , HEWeight , Inflictor , ent, ent )

		--util.Effect not working during MP workaround. Waiting a while fixes the issue.
		timer.Simple(0, function()
			local Flash = EffectData()
				Flash:SetAttachment( 1 )
				Flash:SetOrigin( AvgPos )
				Flash:SetNormal( -vector_up )
				Flash:SetRadius( math.max( Radius , 1 ) )
			util.Effect( "ace_explosion", Flash )
		end )

	end

end



function ACE_CalculateHERadius( HEWeight )
	local Radius = HEWeight ^ 0.33 * 8 * 39.37
	return Radius
end
