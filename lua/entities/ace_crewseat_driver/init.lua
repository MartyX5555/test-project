AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local round = math.Round

local CrewseatTable = ACE.Weapons.Crewseats

function ENT:Initialize()
	ACE.InitializeCrewseat(self, self.ModelType)

	self.LinkedEngine = nil

	self.Inputs = WireLib.CreateInputs(self, {})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Health (Current health percentage)",
		"IsLinked (1 if linked to an engine)",
		"Name (Crew member name) [STRING]",
	})

	self:UpdateWireOutputs()
end

function ACE.MakeCrewseatDriver(Owner, Pos, Angle, Id, Data)
	if not IsValid(Owner) then return false end
	if not Owner:CheckLimit("_ace_crewseat") then return false end

	Id = Id or "Crewseat_Driver"

	local entData = CrewseatTable and CrewseatTable[Id]
	if not entData then return false end

	local ent = ents.Create("ace_crewseat_driver")
	if not IsValid(ent) then return false end

	ent:SetAngles(Angle)
	ent:SetPos(Pos)

	ent.CrewseatData = entData

	local modelType = (istable(Data) and Data.ModelType) or (isstring(Data) and Data) or nil
	if not modelType or modelType == "" then
		modelType = entData.defaultModel or "Sitting"
	end
	ent.ModelType = modelType
	ent.ACE_DupeSpawnModelType = modelType
	ent.ACE_DupeSpawnModel = ACE.CrewseatModels and ACE.CrewseatModels[modelType] or nil

	ent:Spawn()
	ACE.SetEntityOwner(ent, Owner)

	ent.Id = Id

	Owner:AddCount("_ace_crewseat", ent)
	Owner:AddCleanup("acemenu", ent)

	return ent
end

list.Set("ACFCvars", "ace_crewseat_driver", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_crewseat_driver", ACE.MakeCrewseatDriver, "Pos", "Angle", "Id", "ModelType")

function ENT:Update(ply, Id, Data)
	return ACE.UpdateCrewseatModel(self, ply, Id, Data)
end

function ENT:GetPoseModifiers()
	return ACE.GetPoseModifiers(self) or { gforce = 1, tilt = 1 }
end

function ENT:Think()
	ACE.UpdateCrewseatAnglePenalty(self)
	ACE.CrewseatLegalCheck(self)

	local eng = self.LinkedEngine
	if not self.Legal and IsValid(eng) then
		eng:Unlink(self)
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:OnRemove()
	ACE.CrewseatOnRemove(self)
end

function ENT:UpdateWireOutputs()
	local hp = round(self.ACE.Health / self.ACE.MaxHealth * 100)
	local isLinked = IsValid(self.LinkedEngine) and 1 or 0

	WireLib.TriggerOutput(self, "Health", hp)
	WireLib.TriggerOutput(self, "IsLinked", isLinked)
	WireLib.TriggerOutput(self, "Name", self.Name or "Unknown")
end

function ENT:UpdateOverlayText()
	local hp = round(self.ACE.Health / self.ACE.MaxHealth * 100)
	local pose = self:GetPoseModifiers()
	local isStanding = ACE.IsStandingPose(self.ModelType)

	local str = self.Name
	str = str .. "\n\nHealth: " .. hp .. "%"
	str = str .. "\nPose: " .. (isStanding and "Standing" or "Sitting")

	if pose.desc then
		str = str .. "\n  " .. pose.desc
	end

	local tiltPenalty = (self.AnglePenalty or 0) * (pose.tilt or 1)
	if tiltPenalty > 0.1 then
		str = str .. "\n\nTilt Penalty: " .. round(tiltPenalty * 100) .. "%"
	end

	if not self.Legal then
		str = str .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - (ACE.CurTime or CurTime())) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end

function ENT:BuildDupeInfo()
	local info = self.BaseClass.BuildDupeInfo(self) or {}
	info.ModelType = self.ModelType
	info.Model = self.Model
	return info
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	self.BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)

	local class = self:GetClass()
	local defaultModelType = (ACE.CrewseatDefaults and ACE.CrewseatDefaults[class]) or "Sitting"

	ACE.CrewseatDebugLog(self, "ApplyDupeInfoStart", info, "model=" .. tostring(self:GetModel()))
	local modelType, _, reason = ACE.CrewseatApplyDupeModel(self, info, defaultModelType, false)
	ACE.CrewseatDebugLog(self, "ApplyDupeInfoEnd", info, "resolved=" .. tostring(modelType) .. " reason=" .. tostring(reason))
	ACE.CrewseatDeferredModelSync(self, info)
end

function ENT:ACE_OnDamage(Entity, Energy, FrArea, _, Inflictor, _, _)
	local HitRes = ACE.CrewseatDamage(self, Entity, Energy, FrArea, Inflictor)

	if HitRes.Kill or HitRes.Overkill > 1 then
		self:ConsumeCrewseats()
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	return HitRes
end

function ENT:ConsumeCrewseats()
	EmitSound(self.Sound, self:GetPos(), 50, CHAN_AUTO, 1, 75, 0, self.SoundPitch)

	self.Legal = false
	self.LegalIssues = "Apparently He Died"
	self.IsReplacing = true

	self:SetNoDraw(true)
	self:SetNotSolid(true)

	self.PreviousEngineStates = {}

	for _, Link in pairs(self.Master) do
		if IsValid(Link) then
			self.PreviousEngineStates[Link] = Link.Active
			Link.HasDriver = false
		end
	end

	local ReplaceEnt, ClosestDist = ACE.FindReplacementLoader(self)
	local ReplaceSeat = false

	if IsValid(ReplaceEnt) then
		ReplaceSeat = true
		self.Name = ReplaceEnt.Name
		ACE.HEKill(ReplaceEnt, VectorRand(), 0)

		local ReplaceTime = 5 + math.sqrt(ClosestDist) / 39.37 * 1

		timer.Create("CrewDie" .. self:GetCreationID(), ReplaceTime, 1, function()
			if IsValid(self) then
				self:ResetLinks()
			end
		end)
	else
		self.IsReplacing = false
		ACE.HEKill(self, VectorRand(), 0)
	end

	return ReplaceSeat
end

function ENT:ResetLinks()
	self.IsReplacing = false
	self.ACE.Health = self.ACE.MaxHealth or 1
	self.ACE.Armour = self.ACE.MaxArmour or 1
	self.NextLegalCheck = 0
	self:SetNoDraw(false)
	self:SetNotSolid(false)

	for _, Link in pairs(self.Master) do
		if IsValid(Link) then
			table.insert(Link.CrewLink, self)
			self.LinkedEngine = Link
			Link.HasDriver = true

			if self.PreviousEngineStates and self.PreviousEngineStates[Link] then
				Link:TriggerInput("Active", 1)
			end
		end
	end

	self.PreviousEngineStates = nil
end
