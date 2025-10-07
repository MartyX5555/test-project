
local ACE = ACE or {}
if not ACE.GlobalEntities then

	ACE.GlobalEntities = {} -- Any entity should go here, parented or not.
	ACE.Explosives = {} --Explosive entities like ammocrates & fueltanks go here
	ACE.ScalableEnts = {}
end

--list of classname ents which should be added to the contraption ents.
local AllowedEnts = {
	ace_rack                     = true,
	prop_vehicle_prisoner_pod    = true,
	ace_crewseat_gunner          = true,
	ace_crewseat_loader          = true,
	ace_crewseat_driver          = true,
	ace_rwr_dir                  = true,
	ace_rwr_sphere               = true,
	ace_radar                    = true,
	ace_opticalcomputer          = true,
	gmod_wire_expression2        = true,
	gmod_wire_gate               = true,
	prop_physics                 = true,
	ace_ecm                      = true,
	ace_trackingradar            = true,
	ace_irst                     = true,
	ace_gun                      = true,
	ace_ammo                     = true,
	ace_engine                   = true,
	ace_fueltank                 = true,
	ace_gearbox                  = true,
	primitive_shape              = true,
	primitive_airfoil            = true,
	primitive_rail_slider        = true,
	primitive_slider             = true,
	primitive_ladder             = true
}

-- insert any new entity to the Collector List
function ACE.AddEntityToCollector(Ent, ForceInsert)
	if not IsValid(Ent) then return end
	local class = Ent:GetClass()
	if not ForceInsert and not AllowedEnts[class] then return end

	if Ent.IsExplosive then
		ACE.Explosives[Ent] = true
	end

	if Ent.IsScalable then
		ACE.ScalableEnts[Ent] = true
	end

	if Ent.InitializeOnCollector then
		Ent:InitializeOnCollector()
	end

	ACE.GlobalEntities[Ent] = true

	Ent:CallOnRemove("ACE_PropOnRemove", function()

		ACE.Explosives[Ent] = nil
		ACE.ScalableEnts[Ent] = nil

		if Ent.OnRemoveCollectorData then
			Ent:OnRemoveCollectorData()
		end

		ACE.GlobalEntities[Ent] = nil
	end)
end

hook.Add("OnEntityCreated", "ACE_EntRegister", function(Ent)
	timer.Simple(0, function() ACE.AddEntityToCollector(Ent) end)
end)
