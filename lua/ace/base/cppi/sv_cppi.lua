if CLIENT then return end


--[[
	A very simple, but yet effective owner tracking. Can track the ownership of props, even if the user leaves the server, doing a backup if the user comes back (eventually)

	Not wanting to add a full CPPI integration when the only purpose is knowing the ownership of something.
	In any case, this will be completely overriden if a proper CPPI is installed, so it takes the work instead.
]]

local Entities = {}
local Backup = {}

function ACE.GetEntityOwner(Entity)
	if CPPI then return Entity:CPPIGetOwner() end

	local Owner = Entity.ACEOwner or (Entity.GetPlayer and Entity:GetPlayer())
	if not IsValid(Owner) then return end

	return Owner, Owner:UniqueID()
end

function ACE.SetEntityOwner(Entity, Player)
	if CPPI then return Entity:CPPISetOwner(Player) end

	local Container = Player and Entities[Player]

	Entity.ACEOwner = Player

	if Entity.SetPlayer then
		Entity:SetPlayer(Player)
	end

	if Container then
		Container[Entity] = true

		Entity:CallOnRemove("ACE_PropOnRemove", function()
			Container[Entity] = nil
		end)
	end
	return true
end

local function CreateContainers(Player, SteamID)
	if CPPI then return end

	local Container = {}

	local Backed = Backup[SteamID]
	if Backed then

		local RefreshedList = {}
		for ent, _ in pairs(Backed) do
			if not IsValid(ent) then continue end
			if ent.ACEOwner ~= Player then continue end

			RefreshedList[ent] = true
		end

		Entities[Player] = RefreshedList
		Backed = nil
	else
		Entities[Player] = Container
	end

	Player:CallOnRemove("ACE_OwnerOnDisconnect", function()
		if not next(Container) then return end

		Backup[SteamID] = Container
		Entities[Player] = nil
	end)
end
hook.Add("PlayerAuthed", "ACE_Ownership", CreateContainers)

local function SetOwner(Player, Entity)
	if CPPI then return end
	ACE.SetEntityOwner(Entity, Player)
end

hook.Add("PlayerSpawnedNPC", "ACE_OwnerProp", SetOwner)
hook.Add("PlayerSpawnedSENT", "ACE_OwnerProp", SetOwner)
hook.Add("PlayerSpawnedSWEP", "ACE_OwnerProp", SetOwner)
hook.Add("PlayerSpawnedVehicle", "ACE_OwnerProp", SetOwner)

local function SetOwner2(Player, _, Entity)
	if CPPI then return end
	ACE.SetEntityOwner(Entity, Player)
end

hook.Add("PlayerSpawnedEffect", "ACE_OwnerProp", SetOwner2)
hook.Add("PlayerSpawnedProp", "ACE_OwnerProp", SetOwner2)
hook.Add("PlayerSpawnedRagdoll", "ACE_OwnerProp", SetOwner2)

-- Temporal. To recreate the tables during restarts.
hook.Add("Tick", "TEST_ACE", function()

	for _, v in ipairs(player.GetAll()) do
		if not IsValid(v) then continue end
		if not Entities[v] then
			CreateContainers(v, v:SteamID())
		end
	end

end)