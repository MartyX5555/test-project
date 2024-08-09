do
	local SendDelay = 1 -- in miliseconds
	local RenderProps = {
		Entities = {},
		Clock = 0
	}
	function ACF_UpdateVisualHealth( Entity )
		if not Entity.ACF.OnRenderQueue then
			table.insert(RenderProps.Entities, Entity )
			Entity.ACF.OnRenderQueue = true
		end
	end
	function ACF_SendVisualDamage()

		local Time = CurTime()

		if next(RenderProps.Entities) and Time >= RenderProps.Clock then

			for k, Ent in ipairs(RenderProps.Entities) do
				if not Ent:IsValid() then
					table.remove( RenderProps.Entities, k )
				end
			end

			local Entity = RenderProps.Entities[1]
			if IsValid(Entity) then
				net.Start("ACF_RenderDamage", true) -- i dont care if the message is not received under extreme cases since its simply a visual effect only.
					net.WriteUInt(Entity:EntIndex(), 13)
					net.WriteFloat(Entity.ACF.MaxHealth)
					net.WriteFloat(Entity.ACF.Health)
				net.Broadcast()

				Entity.ACF.OnRenderQueue = nil
			end
			table.remove( RenderProps.Entities, 1 )

			RenderProps.Clock = Time + (SendDelay / 1000)
		end
	end
	hook.Add("Think","ACF_RenderPropDamage", ACF_SendVisualDamage )
end