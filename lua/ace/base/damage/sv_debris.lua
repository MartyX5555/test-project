local ACE = ACE or {}

-- Remove the entity
local function RemoveEntity( Entity )
	constraint.RemoveAll( Entity )
	Entity:Remove()
end


-- helper function to process children of an ace-destroyed prop
-- AP will HE-kill children props like a detonation; looks better than a directional spray of unrelated debris from the AP kill
local function ACE_KillChildProps( Entity, BlastPos, Energy )

	if ACE.DebrisChance <= 0 then return end

	local children = ACE_GetAllChildren(Entity, {}, true)
	RemoveEntity( Entity )

	-- Only do this if the Entity has real children with it.
	if next(children) then

		local count = 0
		local boom = {}

		-- do an initial processing pass on children, separating out explodey things to handle last
		for ent, _ in pairs( children ) do --print('table children: ' .. table.Count( children ))
			if not ACE_CanCheck(ent) then continue end -- we would be potentially dealing with props parented to holograms, being the last one that we need to discard.

			-- mark that it's already processed
			ent.ACE_Killed = true

			-- remove this ent from children table and move it to the explosive table
			if ent.IsExplosive and not ent.Exploding then

				table.insert( boom , ent )
				children[ent] = nil

				continue
			else
				-- can't use #table or :count() because of ent indexing...
				count = count + 1
			end
		end

		-- HE kill the children of this ent, instead of disappearing them by removing parent
		if count > 0 then

			local power = Energy / math.min(count,3)

			for child, _ in pairs( children ) do --print('table children#2: ' .. table.Count( children ))

				--Skip any invalid entity
				if not IsValid(child) then continue end

				local rand = math.random(0,100) / 100 --print(rand) print(ACE.DebrisChance)

				-- ignore some of the debris props to save lag
				if count > 10 and rand > ACE.DebrisChance then continue end

				ACE_HEKill( child, (child:GetPos() - BlastPos):GetNormalized(), power )
			end
		end

		-- explode stuff last, so we don't re-process all that junk again in a new explosion
		if next( boom ) then

			for _, child in pairs( boom ) do

				if not IsValid(child) or child.Exploding then continue end

				child.Exploding = true
				ACE_ScaledExplosion( child ) -- explode any crates that are getting removed

			end
		end
	end
end

-- Creates a debris related to explosive destruction.
function ACE_HEKill( Entity , HitVector , Energy , BlastPos )

	-- Completely Delete the Entity and blow out all the props attached to it via parent.
	-- if it hasn't been processed yet, check for children
	if not Entity.ACE_Killed then
		ACE_KillChildProps( Entity, BlastPos or Entity:GetPos(), Energy )
	end

	local Debris
	-- Create a debris only if the dead entity is greater than the specified scale.
	if Entity:BoundingRadius() > ACE.DebrisScale then

		Debris = ents.Create( "ace_debris" )
		if IsValid(Debris) then

			Debris:SetModel( Entity:GetModel() )
			Debris:SetAngles( Entity:GetAngles() )
			Debris:SetPos( Entity:GetPos() )
			Debris:SetMaterial("models/props_wasteland/metal_tram001a")
			Debris:Spawn()
			Debris:Activate()

			if math.random() < ACE.DebrisIgniteChance then
				Debris:Ignite(math.Rand(5,45),0)
			end

			-- Applies force to this debris
			local phys = Debris:GetPhysicsObject()
			local physent = Entity:GetPhysicsObject()
			local Parent = ACE_GetPhysicalParent( Entity )

			if IsValid(phys) and IsValid(physent) then
				phys:SetDragCoefficient( -50 )
				phys:SetMass( physent:GetMass() )
				phys:SetVelocity( Parent:GetVelocity() )
				phys:ApplyForceOffset( HitVector:GetNormalized() * Energy * 4, Debris:WorldSpaceCenter() + VectorRand() * 10  )

				if IsValid(Parent) then
					phys:SetVelocity(Parent:GetVelocity() )
				end
			end
		end
	end

	-- Remove the entity
	RemoveEntity( Entity )

	return Debris
end


-- Creates a debris related to kinetic destruction.
function ACE_APKill( Entity , HitVector , Power )

	-- Completely Delete the Entity and blow out all the props attached to it via parent.
	ACE_KillChildProps( Entity, Entity:GetPos(), Power )

	local Debris
	-- Create a debris only if the dead entity is greater than the specified scale.
	if Entity:BoundingRadius() > ACE.DebrisScale then

		Debris = ents.Create( "ace_debris" )
		if IsValid(Debris) then

			Debris:SetModel( Entity:GetModel() )
			Debris:SetAngles( Entity:GetAngles() )
			Debris:SetPos( Entity:GetPos() )
			Debris:SetMaterial(Entity:GetMaterial())
			Debris:SetColor(Color(120,120,120,255))
			Debris:Spawn()
			Debris:Activate()

			--Applies force to this debris
			local phys = Debris:GetPhysicsObject()
			local physent = Entity:GetPhysicsObject()
			local Parent =  ACE_GetPhysicalParent( Entity )

			if IsValid(phys) and IsValid(physent) then
				phys:SetDragCoefficient( -50 )
				phys:SetMass( physent:GetMass() )
				phys:SetVelocity(Parent:GetVelocity() )
				phys:ApplyForceOffset( HitVector:GetNormalized() * Power * 100, Debris:WorldSpaceCenter() + VectorRand() * 10 )

				if IsValid(Parent) then
					phys:SetVelocity( Parent:GetVelocity() )
				end
			end
		end
	end
	-- Remove the entity
	RemoveEntity( Entity )

	return Debris
end