do
	local SendDelay = 1 -- in miliseconds
	local RenderProps = {
		Entities = {},
		Clock = 0
	}
	function ACE_UpdateVisualHealth( Entity )
		if not Entity.ACE.OnRenderQueue then
			table.insert(RenderProps.Entities, Entity )
			Entity.ACE.OnRenderQueue = true
		end
	end
	local function SendVisualDamage()

		local Time = CurTime()

		if next(RenderProps.Entities) and Time >= RenderProps.Clock then

			for k, Ent in ipairs(RenderProps.Entities) do
				if not Ent:IsValid() then
					table.remove( RenderProps.Entities, k )
				end
			end

			local Entity = RenderProps.Entities[1]
			if IsValid(Entity) then
				net.Start("ACE_RenderDamage", true) -- i dont care if the message is not received under extreme cases since its simply a visual effect only.
					net.WriteUInt(Entity:EntIndex(), 13)
					net.WriteFloat(Entity.ACE.MaxHealth)
					net.WriteFloat(Entity.ACE.Health)
				net.Broadcast()

				Entity.ACE.OnRenderQueue = nil
			end
			table.remove( RenderProps.Entities, 1 )

			RenderProps.Clock = Time + (SendDelay / 1000)
		end
	end
	hook.Add("Think","ACE_RenderPropDamage", SendVisualDamage )
end