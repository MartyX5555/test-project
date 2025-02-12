
local ACE = ACE or {}
if not ACE.GlobalEntities then

	ACE.GlobalEntities = {} -- Any entity should go here, parented or not.
	ACE.Explosives = {} --Explosive entities like ammocrates & fueltanks go here
	ACE.ScalableEnts = {}
end

--list of classname ents which should be added to the contraption ents.
local AllowedEnts = {
	acf_rack                  = true,
	prop_vehicle_prisoner_pod = true,
	ace_crewseat_gunner       = true,
	ace_crewseat_loader       = true,
	ace_crewseat_driver       = true,
	ace_rwr_dir               = true,
	ace_rwr_sphere            = true,
	acf_missileradar          = true,
	acf_opticalcomputer       = true,
	gmod_wire_expression2     = true,
	gmod_wire_gate            = true,
	prop_physics              = true,
	ace_ecm                   = true,
	ace_trackingradar         = true,
	ace_irst                  = true,
	acf_gun                   = true,
	acf_ammo                  = true,
	acf_engine                = true,
	acf_fueltank              = true,
	acf_gearbox               = true,
	primitive_shape           = true,
	primitive_airfoil         = true,
	primitive_rail_slider     = true,
	primitive_slider          = true,
	primitive_ladder          = true
}

--used mostly by contraption. Put here any entity which contains IsExplosive boolean
ACE.ExplosiveEnts = {
	acf_ammo     = true,
	acf_fueltank = true
}

-- whitelist for things that can be turned into debris
ACE.AllowedDebris = {
	acf_gun                   = true,
	acf_rack                  = true,
	acf_gearbox               = true,
	acf_engine                = true,
	prop_physics              = true,
	prop_vehicle_prisoner_pod = true
}

-- insert any new entity to the Contraption List
function ACE.AddEntityToCollector(Ent, ForceInsert)
	if not IsValid(Ent) then return end
	local class = Ent:GetClass()
	if not ForceInsert and not AllowedEnts[class] then return end

	if ACE.ExplosiveEnts[class] then
		ACE.Explosives[Ent] = true
	end

	if Ent.IsScalable then
		ACE.ScalableEnts[Ent] = true
	end

	if Ent.InitializeOnCollector then
		print("called collector init for:", class)
		Ent:InitializeOnCollector()
	end

	ACE.GlobalEntities[Ent] = true

	Ent:CallOnRemove("ACE_PropOnRemove", function()

		ACE.Explosives[Ent] = nil
		ACE.ScalableEnts[Ent] = nil

		if Ent.OnRemoveCollectorData then
			print("called collector removal for:", class)
			Ent:OnRemoveCollectorData()
		end

		ACE.GlobalEntities[Ent] = nil
	end)
end

hook.Add("OnEntityCreated", "ACE_EntRegister", function(Ent)
	timer.Simple(0, function() ACE.AddEntityToCollector(Ent) end)
end)
