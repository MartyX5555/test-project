-- Server-side crewseat functionality and helpers

local crewseatDebug = CreateConVar("ace_debug_crewseat_models", "0", FCVAR_ARCHIVE, "Log crewseat model/type changes during dupe paste")

-- Resolve a crewseat model type from dupe data or the current model path.
function ACE.CrewseatResolveModelType(ent, info)
	if not IsValid(ent) then return nil end

	local modelPath = (info and info.Model) or ent:GetModel()
	if not modelPath then return nil end

	local modelType = ACE.CrewseatModelLookup and ACE.CrewseatModelLookup[modelPath]
	if not modelType or not (ACE.CrewseatModels and ACE.CrewseatModels[modelType]) then
		return nil
	end

	if ent.ModelType ~= modelType then
		ent.ModelType = modelType
	end

	local model = ACE.CrewseatModels[modelType]
	if model and ent.Model ~= model then
		ent:SetModel(model)
		ent.Model = model
	end

	return modelType
end

-- Check whether crewseat model debugging is enabled.
function ACE.CrewseatDebugEnabled()
	return crewseatDebug:GetBool()
end

-- Print a crewseat debug line when enabled.
function ACE.CrewseatDebugLog(ent, stage, info, extra)
	if not ACE.CrewseatDebugEnabled() then return end

	local owner = "Unknown"
	local ply = ACE.GetEntityOwner(ent)
	if IsValid(ply) then owner = ply:Nick() end

	local infoModel = info and info.Model or "nil"
	local infoModelType = info and info.ModelType or "nil"
	local entClass = IsValid(ent) and ent:GetClass() or "unknown"
	local entIndex = IsValid(ent) and ent:EntIndex() or 0
	local model = IsValid(ent) and ent:GetModel() or "nil"
	local modelType = IsValid(ent) and (ent.ModelType or "nil") or "nil"

	print(string.format("[ACE Crewseat] %s(%d) owner=%s stage=%s infoModel=%s infoModelType=%s model=%s modelType=%s extra=%s",
		entClass, entIndex, owner, stage, infoModel, infoModelType, model, modelType, extra or "none"))
end

-- Apply dupe model data with a fallback model type and optional legacy override.
function ACE.CrewseatApplyDupeModel(ent, info, defaultModelType, legacyForceSitting)
	local modelType = info.ModelType
	local legacyLocked = false
	local reason = "preserved"

	ent.ACE_DupeInfoModel = info.Model
	ent.ACE_DupeInfoModelType = info.ModelType

	if legacyForceSitting and info.ModelType == nil and info.Model == nil then
		modelType = "Sitting"
		legacyLocked = true
		reason = "legacy forced sitting"
	end

	if not modelType or not ACE.CrewseatModels[modelType] then
		local modelPath = info.Model or ent:GetModel()
		modelType = (modelPath and ACE.CrewseatModelLookup[modelPath]) or modelType
		if modelType and ACE.CrewseatModels[modelType] then
			reason = "restored from model path"
		end
	end

	if not modelType or not ACE.CrewseatModels[modelType] then
		modelType = defaultModelType or "Sitting"
		reason = "class default fallback"
	end

	ent.ModelType = modelType
	ent.ACE_LegacyCrewseatModelLocked = legacyLocked or nil
	ent.ACE_DupeResolveReason = reason

	local model = ACE.CrewseatModels[modelType]
	if model then
		ent:SetModel(model)
		ent.Model = model
	end

	return modelType, legacyLocked, reason
end

-- Defer model sync so the duplicator can finish applying model data.
function ACE.CrewseatDeferredModelSync(ent, info)
	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if ent.ACE_LegacyCrewseatModelLocked then return end
		local beforeModel = ent:GetModel()
		local beforeType = ent.ModelType
		local modelType = ACE.CrewseatResolveModelType(ent, info)
		if modelType and (beforeModel ~= ent:GetModel() or beforeType ~= ent.ModelType) then
			ent.ACE_DupeDeferredModel = ent:GetModel()
			ent.ACE_DupeDeferredModelType = ent.ModelType
			ent.ACE_DupeDeferredResolved = modelType
			ACE.CrewseatDebugLog(ent, "DeferredSync", info, "resolved=" .. tostring(modelType))
		end
	end)
end

-- Dump crewseat state for debugging from console.
concommand.Add("ace_crewseat_dump", function(_, _, args)
	local target = tonumber(args[1] or "")

	local function dumpSeat(ent)
		if not IsValid(ent) then return end

		local owner = ACE.GetEntityOwner(ent)
		local ownerName = IsValid(owner) and owner:Nick() or "Unknown"
		local model = ent:GetModel() or "nil"
		local modelType = ent.ModelType or "nil"
		local infoModel = ent.ACE_DupeInfoModel or "nil"
		local infoModelType = ent.ACE_DupeInfoModelType or "nil"
		local resolveReason = ent.ACE_DupeResolveReason or "nil"
		local spawnModel = ent.ACE_DupeSpawnModel or "nil"
		local spawnModelType = ent.ACE_DupeSpawnModelType or "nil"
		local spawnLegacy = ent.ACE_DupeSpawnLegacy and "true" or "false"
		local initModel = ent.ACE_InitModel or "nil"
		local initModelType = ent.ACE_InitModelType or "nil"
		local deferredModel = ent.ACE_DupeDeferredModel or "nil"
		local deferredType = ent.ACE_DupeDeferredModelType or "nil"
		local deferredResolved = ent.ACE_DupeDeferredResolved or "nil"
		local weight = tonumber(ent.Weight) or 0
		local legal = ent.Legal and "true" or "false"
		local issues = ent.LegalIssues or ""

		print(string.format("[ACE Crewseat] %s(%d) owner=%s model=%s modelType=%s weight=%.2f legal=%s issues=%s",
			ent:GetClass(), ent:EntIndex(), ownerName, model, modelType, weight, legal, issues))
		print(string.format("[ACE Crewseat] dupe infoModel=%s infoModelType=%s resolveReason=%s deferredModel=%s deferredModelType=%s deferredResolved=%s",
			infoModel, infoModelType, resolveReason, deferredModel, deferredType, deferredResolved))
		print(string.format("[ACE Crewseat] dupe spawnModel=%s spawnModelType=%s initModel=%s initModelType=%s",
			spawnModel, spawnModelType, initModel, initModelType))
		print(string.format("[ACE Crewseat] dupe spawnLegacy=%s", spawnLegacy))
	end

	if target then
		dumpSeat(Entity(target))
		return
	end

	for seat in pairs(ACE.Crewseats or {}) do
		dumpSeat(seat)
	end
end)

-- Rare crew names (easter eggs)
local rareNames = {
	"Mr.Marty", "RDC", "Cheezus", "KemGus", "Golem Man", "Arend", "Mac",
	"Firstgamerable", "kerbal cadet", "Psycho Dog", "Ferv", "Rice",
	"spEAM", "Orange_Fox", "Dedem", "Garry"
}

local randomPrefixes = {
	"John", "Bob", "Sam", "Joe", "Ben", "Alex", "Chris", "David", "Eric", "Frank",
	"Antonio", "Ivan", "Alexander", "Victor", "Elon", "Vladimir", "Donald"
}
local randomSuffixes = {
	"Smith", "Johnson", "Dover", "Wang", "Kim", "Lee", "Brown", "Davis", "Evans",
	"Garcia", "", "Russel", "King", "Musk", "Popov"
}

function ACE.GenerateCrewName()
	local randomNum = math.random(1, 100)

	if randomNum <= 2 then
		return rareNames[math.random(1, #rareNames)]
	end

	local prefix = randomPrefixes[math.random(1, #randomPrefixes)]
	local suffix = randomSuffixes[math.random(1, #randomSuffixes)]
	return prefix .. " " .. suffix
end

-- =========================================================
-- CREWSEAT COMMON HELPERS
-- =========================================================

-- Shared initialization for crewseats
function ACE.InitializeCrewseat(ent, modelType)
	local class = ent:GetClass()

	-- Validate model type, fallback to default if invalid
	if not modelType or not ACE.CrewseatModels or not ACE.CrewseatModels[modelType] then
		modelType = (ACE.CrewseatDefaults and ACE.CrewseatDefaults[class]) or "Sitting"
	end

	local model = ACE.CrewseatModels[modelType]

	ent:SetModel(model)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetUseType(SIMPLE_USE)
	ent:SetSolid(SOLID_VPHYSICS)

	local phys = ent:GetPhysicsObject()
	local crewData = ent.CrewseatData
	local weight = (crewData and crewData.weight) or ent.Weight or 60

	if IsValid(phys) then
		phys:SetMass(weight)
	end

	ent.Master = {}
	ent.ACE = ent.ACE or {}
	ent.ACE.Health = ent.ACE.Health or 1
	ent.ACE.MaxHealth = ent.ACE.MaxHealth or 1
	ent.ACE.Armour = ent.ACE.Armour or 1

	ent.Name = ent.Name or ACE.GenerateCrewName()
	ent.Weight = weight
	ent.AnglePenalty = 0
	ent.GForcePenalty = 0

	ent.ModelType = modelType
	ent.Model = model

	ent.ACE_InitModelType = modelType
	ent.ACE_InitModel = model

	ent.Sound = ent.Sound or ("npc/combine_soldier/die" .. tostring(math.random(1, 3)) .. ".wav")
	ent.SoundPitch = ent.SoundPitch or 100

	ent.NextLegalCheck = (ACE.CurTime or CurTime()) + math.random(ACE.Legal.Min, ACE.Legal.Max)
	ent.Legal = true
	ent.LegalIssues = ""

	ent.SpecialHealth = false
	ent.SpecialDamage = true
	ent.CanUpdate = true
	ACE.Crewseats = ACE.Crewseats or {}
	ACE.Crewseats[ent] = true

	-- Initialize g-force state
	ent.ACE_GForceState = nil
	ACE.CalculateGForce(ent)

	return model
end

-- Shared update function for tool left-click in-situ update
function ACE.UpdateCrewseatModel(ent, _, _, Data)
	if not IsValid(ent) then return false, "Invalid entity" end

	local modelType = (istable(Data) and Data.ModelType) or (isstring(Data) and Data) or nil
	if not modelType or not ACE.CrewseatModels[modelType] then
		return false, "Invalid model pose specified"
	end

	if ent.ModelType == modelType then
		return false, "Crewseat is already in pose " .. modelType
	end

	local model = ACE.CrewseatModels[modelType]
	ent.ModelType = modelType
	ent.Model = model
	ent:SetModel(model)

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(ent.Weight or 60)
		phys:Wake()
	end

	ent.NextLegalCheck = 0
	if ent.UpdateOverlayText then ent:UpdateOverlayText() end

	return true, "Updated crewseat pose to " .. modelType
end

-- Shared angle penalty calculation
local startPenalty = 45
local maxPenalty = 90
local vec_up = Vector(0, 0, 1)

function ACE.UpdateCrewseatAnglePenalty(ent)
	local dot = math.Clamp(ent:GetUp():Dot(vec_up), -1, 1)
	local curSeatAngle = math.deg(math.acos(dot))

	ent.AnglePenalty = math.Clamp(math.Remap(curSeatAngle, startPenalty, maxPenalty, 0, 1), 0, 1)
	return ent.AnglePenalty
end

-- G-force penalty calculation (0..1)
-- Penalties start at 2G excess and max out at 6G excess
function ACE.UpdateGForcePenalty(ent)
	local gTotal, gVec, gExcess = ACE.CalculateGForce(ent)
	ent.CurrentGForce = gTotal
	ent.GForceVector = gVec
	ent.CurrentGForceExcess = gExcess

	ent.GForcePenalty = math.Clamp(math.Remap(gExcess, 2, 6, 0, 1), 0, 1)
	return ent.GForcePenalty, gTotal, gExcess
end

-- Crewseat-specific legal check (includes model validation)
function ACE.CrewseatLegalCheck(ent)
	if ent.IsReplacing then
		ent.Legal = false
		ent.LegalIssues = "Apparently He Died"
		return false
	end

	if (ACE.CurTime or CurTime()) > ent.NextLegalCheck then
		local currentModel = ent:GetModel()
		if ent.Model ~= currentModel then
			ent.Model = currentModel
		end

		ent.Legal, ent.LegalIssues = ACE.CheckLegal(ent, ent.Model, math.Round(ent.Weight, 2), nil, true, true)

		if ent.Legal and not (ACE.IsValidCrewseatModel and ACE.IsValidCrewseatModel(currentModel)) then
			ent.Legal = false
			ent.LegalIssues = "Invalid crewseat model"
		end

		ent.NextLegalCheck = ACE.Legal.NextCheck(ent.Legal)
	end

	return ent.Legal
end

-- Shared OnRemove
function ACE.CrewseatOnRemove(ent)
	if ACE.Crewseats then ACE.Crewseats[ent] = nil end
	for Key in pairs(ent.Master or {}) do
		if ent.Master[Key] and ent.Master[Key]:IsValid() then
			ent.Master[Key]:Unlink(ent)
		end
	end
end

-- Shared damage function
function ACE.CrewseatDamage(ent, Entity, Energy, FrArea, Inflictor)
	ent.ACE.Armour = 3
	local HitRes = ACE.PropDamage(Entity, Energy, FrArea, 0, Inflictor)
	return HitRes
end

-- Play death sound
function ACE.CrewseatDeathSound(ent)
	EmitSound(ent.Sound, ent:GetPos(), 50, CHAN_AUTO, 1, 75, 0, ent.SoundPitch)
end

-- Find replacement loader seat
function ACE.FindReplacementLoader(ent, maxDistSqr)
	maxDistSqr = maxDistSqr or 624100 -- 20m squared (790 inches)

	local closestDist = math.huge
	local replaceEnt = nil

	for SeatEnt in pairs(ACE.Crewseats or {}) do
		if not IsValid(SeatEnt) then continue end
		if ACE.GetEntityOwner(SeatEnt) ~= ACE.GetEntityOwner(ent) then continue end
		if SeatEnt:GetClass() ~= "ace_crewseat_loader" then continue end
		if SeatEnt.IsReplacing then continue end

		local sqDist = SeatEnt:GetPos():DistToSqr(ent:GetPos())
		if sqDist < maxDistSqr and sqDist < closestDist then
			closestDist = sqDist
			replaceEnt = SeatEnt
		end
	end

	return replaceEnt, closestDist
end
