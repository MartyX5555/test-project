--visual concept: Here's where should be every acf function
local ACE = ACE or {}

-- Helper function if a entity has a parent.
-- Use it if you dont need the parent entity for anything else
function ACE.HasParent(ent)
	return IsValid(ent:GetParent())
end

-- returns last parent in chain, which has physics
function ACE_GetPhysicalParent( obj )
	if not IsValid(obj) then return nil end

	--check for fresh cached parent
	if obj.acfphysparent and ACE.CurTime < obj.acfphysstale then
		return obj.acfphysparent
	end

	local Parent = obj

	while ACE.HasParent(Parent) do
		Parent = Parent:GetParent()
	end

	--update cached parent
	obj.acfphysparent = Parent
	obj.acfphysstale = ACE.CurTime + 10 --when cached parent is considered stale and needs updating

	return Parent
end

--Creates or updates the ACF entity data in a passive way. Meaning this entity wont be updated unless it really requires it (like a shot, damage, looking it using armor tool, etc)
function ACE_Activate( Entity , Recalc )

	--Density of steel = 7.8g cm3 so 7.8kg for a 1mx1m plate 1m thick
	if Entity.SpecialHealth then
		Entity:ACE_Activate( Recalc )
		return
	end

	Entity.ACE = Entity.ACE or {}

	local Count
	local PhysObj = Entity:GetPhysicsObject()

	if PhysObj:GetMesh() then Count = #PhysObj:GetMesh() end
	if PhysObj:IsValid() and Count and Count > 100 then

		if not Entity.ACE.Area then
			Entity.ACE.Area = (PhysObj:GetSurfaceArea() * 6.45) * 0.52505066107
		end
	else
		local Size = Entity.OBBMaxs(Entity) - Entity.OBBMins(Entity)
		if not Entity.ACE.Area then
			Entity.ACE.Area = ((Size.x * Size.y) + (Size.x * Size.z) + (Size.y * Size.z)) * 6.45
		end
	end

	-- Setting Armor properties for the first time (or reuse old data if present)
	Entity.ACE.Ductility	= Entity.ACE.Ductility or 0
	Entity.ACE.Material	= not isstring(Entity.ACE.Material) and ACE.BackCompMat[Entity.ACE.Material] or Entity.ACE.Material or "RHA"

	local Area	= Entity.ACE.Area
	local Ductility = math.Clamp( Entity.ACE.Ductility, -0.8, 0.8 )

	local Mat	= Entity.ACE.Material or "RHA"
	local MatData	= ACE_GetMaterialData( Mat )

	local massMod	= MatData.massMod

	local Armour	= ACE_CalcArmor( Area, Ductility, Entity:GetPhysicsObject():GetMass() / massMod ) -- So we get the equivalent thickness of that prop in mm if all its weight was a steel plate
	local Health	= ( Area / ACE.Threshold ) * ( 1 + Ductility ) -- Setting the threshold of the prop Area gone

	local Percent	= 1

	if Recalc and Entity.ACE.Health and Entity.ACE.MaxHealth then
		Percent = Entity.ACE.Health / Entity.ACE.MaxHealth
	end

	Entity.ACE.Health	= Health * Percent
	Entity.ACE.MaxHealth	= Health
	Entity.ACE.Armour = Armour * (0.5 + Percent / 2)
	Entity.ACE.MaxArmour	= Armour * ACE.ArmorMod
	Entity.ACE.Type		= nil
	Entity.ACE.Mass		= PhysObj:GetMass()

	if Entity:IsPlayer() or Entity:IsNPC() then
		Entity.ACE.Type = "Squishy"
	elseif Entity:IsVehicle() then
		Entity.ACE.Type = "Vehicle"
	else
		Entity.ACE.Type = "Prop"
	end
end

function ACE_Check( Entity )

	if not IsValid(Entity) then return false end

	local physobj = Entity:GetPhysicsObject()
	if not ( physobj:IsValid() and (physobj:GetMass() or 0) > 0 and not Entity:IsWorld() and not Entity:IsWeapon() ) then return false end

	local Class = Entity:GetClass()
	if ( Class == "gmod_ghost" or Class == "ace_debris" or Class == "prop_ragdoll" or string.find( Class , "func_" )  ) then return false end

	if not Entity.ACE or (Entity.ACE and isnumber(Entity.ACE.Material)) then
		ACE_Activate( Entity )
	elseif Entity.ACE.Mass ~= physobj:GetMass() then
		ACE_Activate( Entity , true )
	end

	return Entity.ACE.Type
end

function ACE_Damage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun, Type )

	local Activated = ACE_Check( Entity )
	local CanDo = hook.Run("ACE_BulletDamage", Activated, Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun )
	if not CanDo or not Activated then -- above (default) hook does nothing with activated. Excludes godded players.
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	--print("damage!!!", Entity:GetClass())

	if Entity.SpecialDamage then
		return Entity:ACE_OnDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Type )
	elseif Activated == "Prop" then

		return ACE_PropDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone , Type)
	elseif Activated == "Vehicle" then

		return ACE_VehicleDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun , Type)
	elseif Activated == "Squishy" then

		return ACE_SquishyDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun , Type)
	end

end



function ACE_CalcDamage( Entity , Energy , FrArea , Angle , Type) --y=-5/16x + b

	local HitRes			= {}
	local armor			= Entity.ACE.Armour																						-- Armor
	local losArmor		= armor / math.abs( math.cos(math.rad(Angle)) ^ ACE.SlopeEffectFactor )									-- LOS Armor
	local losArmorHealth = armor ^ 1.1 * (3 + math.min(1 / math.abs(math.cos(math.rad(Angle)) ^ ACE.SlopeEffectFactor), 2.8) * 0.5)	-- Bc people had to abuse armor angling, FML

	local Mat			= Entity.ACE.Material or "RHA"	--very important thing
	local MatData		= ACE_GetMaterialData( Mat )
	local damageMult		= isstring(Type) and ACE[Type .. "DamageMult"] or 1

	-- RHA Penetration
	local maxPenetration = (Energy.Penetration / FrArea) * ACE.KEtoRHA

	-- Projectile caliber. Messy, function signature
	local caliber = 20 * (FrArea ^ (1 / ACE.PenAreaMod) / 3.1416) ^ 0.5

	--Nifty shell information debugging.
--	print("Type: "..Type)
--	print("Penetration: "..math.Round(maxPenetration,3).."mm")
--	print("Caliber: "..math.Round(caliber,3).."mm")

	local ACE_ArmorResolution = MatData["ArmorResolution"]
	HitRes = ACE_ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)

	return HitRes
end

-- replaced with _ due to lack of use: Inflictor, Bone
function ACE_PropDamage( Entity , Energy , FrArea , Angle , _, _, Type)

	local HitRes = ACE_CalcDamage( Entity , Energy , FrArea , Angle  , Type)

	HitRes.Kill = false
	if HitRes.Damage >= Entity.ACE.Health then
		HitRes.Kill = true
	else

		--In case of HitRes becomes NAN. That means theres no damage, so leave it as 0
		if HitRes.Damage ~= HitRes.Damage then HitRes.Damage = 0 end

		Entity.ACE.Health = Entity.ACE.Health - HitRes.Damage
		Entity.ACE.Armour = Entity.ACE.MaxArmour * (0.5 + Entity.ACE.Health / Entity.ACE.MaxHealth / 2) --Simulating the plate weakening after a hit

		if Entity.ACE.PrHealth then
			ACE_UpdateVisualHealth(Entity)
		end
		Entity.ACE.PrHealth = Entity.ACE.Health
	end

	return HitRes

end

-- replaced with _ due to lack of use: Bone
function ACE_VehicleDamage(Entity, Energy, FrArea, Angle, Inflictor, _, Gun, Type)

	local HitRes = ACE_CalcDamage( Entity , Energy , FrArea , Angle  , Type)
	local Driver = Entity:GetDriver()
	local validd = Driver:IsValid()

	--In case of HitRes becomes NAN. That means theres no damage, so leave it as 0
	if HitRes.Damage ~= HitRes.Damage then HitRes.Damage = 0 end

	if validd then
		local dmg = 40
		Driver:TakeDamage( HitRes.Damage * dmg , Inflictor, Gun )
	end

	HitRes.Kill = false
	if HitRes.Damage >= Entity.ACE.Health then --Drivers will no longer survive seat destruction
		if validd then
			Driver:Kill()
		end
		HitRes.Kill = true
	else
		Entity.ACE.Health = Entity.ACE.Health - HitRes.Damage
		Entity.ACE.Armour = Entity.ACE.Armour * (0.5 + Entity.ACE.Health / Entity.ACE.MaxHealth / 2) --Simulating the plate weakening after a hit
	end

	return HitRes
end

function ACE_SquishyDamage(Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun, Type)
	local Size = Entity:BoundingRadius()
	local Mass = Entity:GetPhysicsObject():GetMass()
	local HitRes = {}
	local Damage = 0

	--We create a dummy table to pass armour values to the calc function
	local Target = {
		ACE = {
			Armour = 0.1
		}
	}

	if Bone then
		--This means we hit the head
		if Bone == 1 then
			Target.ACE.Armour = Mass * 0.02 --Set the skull thickness as a percentage of Squishy weight, this gives us 2mm for a player, about 22mm for an Antlion Guard. Seems about right
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, Angle, Type) --This is hard bone, so still sensitive to impact angle
			Damage = HitRes.Damage * 20

			--If we manage to penetrate the skull, then MASSIVE DAMAGE
			if HitRes.Overkill > 0 then
				Target.ACE.Armour = Size * 0.25 * 0.01 --A quarter the bounding radius seems about right for most critters head size
				HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0, Type)
				Damage = Damage + HitRes.Damage * 100
			end

			Target.ACE.Armour = Mass * 0.065 --Then to check if we can get out of the other side, 2x skull + 1x brains
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, Angle, Type)
			Damage = Damage + HitRes.Damage * 20
		elseif Bone == 0 or Bone == 2 or Bone == 3 then
			--This means we hit the torso. We are assuming body armour/tough exoskeleton/zombie don't give fuck here, so it's tough
			Target.ACE.Armour = Mass * 0.04 --Set the armour thickness as a percentage of Squishy weight, this gives us 8mm for a player, about 90mm for an Antlion Guard. Seems about right
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, Angle, Type) --Armour plate,, so sensitive to impact angle
			Damage = HitRes.Damage * 5

			if HitRes.Overkill > 0 then
				Target.ACE.Armour = Size * 0.5 * 0.02 --Half the bounding radius seems about right for most critters torso size
				HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0, Type)
				Damage = Damage + HitRes.Damage * 25 --If we penetrate the armour then we get into the important bits inside, so DAMAGE
			end

			Target.ACE.Armour = Mass * 0.185 --Then to check if we can get out of the other side, 2x armour + 1x guts
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, Angle, Type)
			Damage = Damage + HitRes.Damage * 5
		elseif Bone == 4 or Bone == 5 then
			--This means we hit an arm or appendage, so ormal damage, no armour
			Target.ACE.Armour = Size * 0.2 * 0.02 --A fitht the bounding radius seems about right for most critters appendages
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0, Type) --This is flesh, angle doesn't matter
			Damage = HitRes.Damage * 10 --Limbs are somewhat less important
		elseif Bone == 6 or Bone == 7 then
			Target.ACE.Armour = Size * 0.2 * 0.02 --A fitht the bounding radius seems about right for most critters appendages
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0, Type) --This is flesh, angle doesn't matter
			Damage = HitRes.Damage * 10 --Limbs are somewhat less important
		elseif Bone == 10 then
			--This means we hit a backpack or something
			Target.ACE.Armour = Size * 0.1 * 0.02 --Arbitrary size, most of the gear carried is pretty small
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0, Type) --This is random junk, angle doesn't matter
			Damage = HitRes.Damage * 1 --Damage is going to be fright and shrapnel, nothing much
		else --Just in case we hit something not standard
			Target.ACE.Armour = Size * 0.2 * 0.02
			HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0)
			Damage = HitRes.Damage * 10
		end
	else --Just in case we hit something not standard
		Target.ACE.Armour = Size * 0.2 * 0.02
		HitRes = ACE_CalcDamage(Target, Energy, FrArea, 0, Type)
		Damage = HitRes.Damage * 10
	end

	local dmg = 2.5

	if Type == "Spall" then
		dmg = 0.03
		--print(Damage * dmg)
	end

	Entity:TakeDamage(Damage * dmg, Inflictor, Gun)
	HitRes.Kill = false

	return HitRes
end

----------------------------------------------------------
-- Returns a table of all physically connected entities
-- ignoring ents attached by only nocollides
----------------------------------------------------------
function ACE_GetAllPhysicalConstraints( ent, ResultTable )

	ResultTable = ResultTable or {}

	if not IsValid( ent ) then return end
	if ResultTable[ ent ] then return end

	ResultTable[ ent ] = ent

	local ConTable = constraint.GetTable( ent )

	for _, con in ipairs( ConTable ) do

		-- skip shit that is attached by a nocollide
		if con.Type ~= "NoCollide" then
			for _, Ent in pairs( con.Entity ) do
				ACE_GetAllPhysicalConstraints( Ent.Entity, ResultTable )
			end
		end

	end

	return ResultTable

end

-- for those extra sneaky bastards
function ACE_GetAllChildren( ent, ResultTable )

	--if not ent.GetChildren then return end  --shouldn't need to check anymore, built into glua now

	ResultTable = ResultTable or {}

	if not IsValid( ent ) then return end
	if ResultTable[ ent ] then return end

	ResultTable[ ent ] = ent

	local ChildTable = ent:GetChildren()

	for _, v in pairs( ChildTable ) do

		ACE_GetAllChildren( v, ResultTable )

	end

	return ResultTable

end

-- returns any wheels linked to this or child gearboxes
function ACE_GetLinkedWheels( MobilityEnt )
	if not IsValid( MobilityEnt ) then return {} end

	local ToCheck = {}
	local Checked = {}
	local Wheels  = {}

	local links = MobilityEnt.GearLink or MobilityEnt.WheelLink -- handling for usage on engine or gearbox

	--print('total links: ' .. #links)
	--print(MobilityEnt:GetClass())

	for _, link in pairs( links ) do
		--print(link.Ent:GetClass())
		table.insert(ToCheck, link.Ent)
	end

	--print("max checks: " .. #ToCheck)

	--print('total ents to check: ' .. #ToCheck)

	-- use a stack to traverse the link tree looking for wheels at the end
	while #ToCheck > 0 do

		local Ent = table.remove(ToCheck,#ToCheck)

		if IsValid(Ent) then

			if Ent:GetClass() == "acf_gearbox" then

				Checked[Ent:EntIndex()] = true

				for _, v in pairs( Ent.WheelLink ) do

					if IsValid(v.Ent) and not Checked[v.Ent:EntIndex()] then
						table.insert(ToCheck, v.Ent)
					else
						v.Notvalid = true
					end


				end
			else
				Wheels[Ent] = Ent -- indexing it same as ACE_GetAllPhysicalConstraints, for easy merge.  whoever indexed by entity in that function, uuuuuuggghhhhh
			end
		end
	end

	--print('Wheels found: ' .. table.Count(Wheels))

	return Wheels
end

--[[----------------------------------------------------------------------
	A variation of the CreateKeyframeRope( ... ) for usage on ACE
	This one is more simple than the original function.
	Creates a rope without any constraint
------------------------------------------------------------------------]]
function ACE_CreateLinkRope( Pos, Ent1, LPos1, Ent2, LPos2 )

	local rope = ents.Create( "keyframe_rope" )
	rope:SetPos( Pos )
	rope:SetKeyValue( "Width", 1 )
	rope:SetKeyValue( "Type", 2 )

	rope:SetKeyValue( "RopeMaterial", "cable/cable2" )

	-- Attachment point 1
	rope:SetEntity( "StartEntity", Ent1 )
	rope:SetKeyValue( "StartOffset", tostring( LPos1 ) )
	rope:SetKeyValue( "StartBone", 0 )

	-- Attachment point 2
	rope:SetEntity( "EndEntity", Ent2 )
	rope:SetKeyValue( "EndOffset", tostring( LPos2 ) )
	rope:SetKeyValue( "EndBone", 0 )

	rope:Spawn()
	rope:Activate()

	-- Delete the rope if the attachments get killed
	Ent1:DeleteOnRemove( rope )
	Ent2:DeleteOnRemove( rope )

	return rope

end

--[[----------------------------------------------------------------------
	This function will look for the driver/operator of a gun/rack based
	from the used gun inputs when firing.
	Meant for determining if the driver seat is legal.
------------------------------------------------------------------------]]
local WireTable = {
	gmod_wire_adv_pod = true,
	gmod_wire_pod = true,
	gmod_wire_keyboard = true,
	gmod_wire_joystick = true,
	gmod_wire_joystick_multi = true
}

function ACE_GetWeaponUser( Weapon, inp )
	if not IsValid(inp) then return end

	if inp:GetClass() == "gmod_wire_adv_pod" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_pod" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_keyboard" then
		if IsValid(inp.ply) then
			return inp.ply
		end
	elseif inp:GetClass() == "gmod_wire_joystick" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_joystick_multi" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_expression2" then
		if inp.Inputs.Fire then
			return ACE_GetWeaponUser( Weapon, inp.Inputs.Fire.Src )
		elseif inp.Inputs.Shoot then
			return ACE_GetWeaponUser( Weapon, inp.Inputs.Shoot.Src )
		elseif inp.Inputs then
			for _,v in pairs(inp.Inputs) do
				if IsValid(v.Src) and WireTable[v.Src:GetClass()] then
					return ACE_GetWeaponUser( Weapon, v.Src )
				end
			end
		end
	end

	return ACE.GetEntityOwner(inp)
end

