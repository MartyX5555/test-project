AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

CreateConVar("sbox_max_ace_gearbox", 12)				-- Gearbox limit

local GearboxTable = ACE.Weapons.Gearboxes

do

	local GearboxWireDescs = {
		["Gear"]		= "Sets the gear of this gearbox.",
		["GearUp"]		= "Increases one gear above the current one.",
		["GearDown"]	= "Decreases one gear below the current one.",
		["Clutch"]		= "Applies Clutch to gearbox. Values from 0 to 1.",
		["Brake"]		= "Applies Brake to gearbox. The value you put, the strenght of the brake."
	}

	function ENT:Initialize()

		self.IsGeartrain	= true
		self.Master			= {}
		self.IsMaster		= true

		self.WheelLink		= {} -- a "Link" has these components: Ent, Side, Axis, Rope, RopeLen, Output, ReqTq, Vel

		self.TotalReqTq		= 0
		self.RClutch		= 0
		self.LClutch		= 0
		self.LBrake			= 0
		self.RBrake			= 0
		self.SteerRate		= 0

		self.Gear			= 0
		self.GearRatio		= 0
		self.ChangeFinished = 0

		self.LegalThink		= 0

		self.RPM			= {}
		self.CurRPM			= 0
		self.CVT			= false
		self.DoubleDiff		= false
		self.Auto			= false
		self.InGear			= false
		self.CanUpdate		= true
		self.LastActive		= 0
		self.Legal			= true
		self.Parentable		= false
		self.RootParent		= nil
		self.NextLegalCheck = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
		self.LegalIssues	= ""

		--self.Heat		= ACE.AmbientTemp

	end

	--[[
		Data1-9 are Gears including the reverse one for non automatic gears.
		Data10 is ALWAYS Final Drive
		If auto, Data8 is always reverse, for some odd reason.
		Besides that, Data9 is shifting points for automatic gears.
		Remaining data is retrieved from the Gearbox table.

		New order in Data:
		Data.GearTable = it will contain all the num of gears
		Data.FinalDrive = final drive
		Data.ShiftPoints = ShiftPoints (if it has it.)

		Data.MinRPMTarget = CVT uses this prev: Data3
		Data.MaxRPMTarget = CVT uses this  prev: Data4
	]]
	local Max = math.max
	local ToNumber = tonumber
	local function VerifyGearboxId(Id)
		if not ACE.CheckGearbox( Id ) then
			return "1Gear-T-S" --deal with it
		end
		return Id
	end
	local function VerifyGearboxData(GearboxData, Data)
		if istable(Data.GearTable) and #Data.GearTable > 0 then
			Data.FinalDrive = ToNumber(Data.FinalDrive) or 0.5
			if GearboxData.cvt then
				Data.MinRPMTarget = Max(ToNumber(Data.MinRPMTarget) or 1,1)
				Data.MaxRPMTarget = Max(ToNumber(Data.MaxRPMTarget) or 0, Data.MinRPMTarget + 1)
			elseif GearboxData.auto then
				Data.ShiftPoints = {}
				Data.GearTable[GearboxData.gears + 1] = ToNumber(Data.GearTable[GearboxData.gears + 1]) or -0.1
				for i = 1, 7 do
					Data.ShiftPoints[i] =  Max(ToNumber(Data.ShiftPoints[i]) or 10, 0)
				end
			end
			-- Validate GearTable
			for i = 1, GearboxData.gears do
				Data.GearTable[i] = ToNumber(Data.GearTable[i]) or 0.1 * i
			end
			return
		end
		Data.GearTable = {}
		Data.FinalDrive = ToNumber(Data["Gear0"]) or 0.5
		if GearboxData.cvt then
			Data.MinRPMTarget = Max(ToNumber(Data["Gear3"]) or 1,1)
			Data.MaxRPMTarget = Max(ToNumber(Data["Gear4"]) or 0,Data.MinRPMTarget + 1)
		elseif GearboxData.auto then
			Data.ShiftPoints = {}
			Data.GearTable[GearboxData.gears + 1] = ToNumber(Data["Gear8"]) or -0.1
			for part in string.gmatch(Data["Gear9"], "[^,]+") do
				Data.ShiftPoints[#Data.ShiftPoints + 1] = Max(ToNumber(part) or 10, 0)
			end
		end
		-- Validate GearTable
		for i = 1, GearboxData.gears do
			Data.GearTable[i] = ToNumber(Data["Gear" .. i]) or i * 0.1
		end
	end

	function MakeACE_Gearbox(Owner, Pos, Angle, Id, Data)
		if not Owner:CheckLimit("_ace_gearbox") then return false end

		local Gearbox	= ents.Create("ace_gearbox")
		if not IsValid( Gearbox ) then return false end

		Id = VerifyGearboxId(Id)
		local GearboxData = GearboxTable[Id]

		VerifyGearboxData(GearboxData, Data)

		Gearbox:SetAngles(Angle)
		Gearbox:SetPos(Pos)
		Gearbox:Spawn()

		ACE.SetEntityOwner(Gearbox, Owner)
		Gearbox.Id            = Id
		Gearbox.Model         = GearboxData.model
		Gearbox.Mass          = GearboxData.weight		or 1
		Gearbox.SwitchTime    = GearboxData.switch
		Gearbox.MaxTorque     = GearboxData.maxtq		or 0
		Gearbox.Gears         = GearboxData.gears		or 2 --hmmmmmm ok? just if everything fails
		Gearbox.Dual          = GearboxData.doubleclutch	or false
		Gearbox.CVT           = GearboxData.cvt			or false
		Gearbox.DoubleDiff    = GearboxData.doublediff	or false
		Gearbox.Auto          = GearboxData.auto			or false
		Gearbox.Parentable    = GearboxData.parentable	or false

		if Gearbox.CVT then
			Gearbox.MinRPMTarget = Data.MinRPMTarget
			Gearbox.MaxRPMTarget = Data.MaxRPMTarget
			Gearbox.CVTRatio = nil
		end

		Gearbox.GearTable = Data.GearTable or {}
		Gearbox.GearTable[0] = GearboxData.geartable[0]
		Gearbox.FinalDrive = Data.FinalDrive
		Gearbox.GearRatio = (Gearbox.GearTable[0] or 0) * Gearbox.FinalDrive

		if Gearbox.Auto then
			Gearbox.ShiftPoints = Data.ShiftPoints or {}
			Gearbox.ShiftPoints[0] = -1
			Gearbox.Reverse = Gearbox.Gears + 1
			Gearbox.Drive = 1
			Gearbox.ShiftScale = 1
		end

		Gearbox:SetModel( Gearbox.Model )

		local Inputs = {"Gear (" .. GearboxWireDescs["Gear"] .. ")","Gear Up (" .. GearboxWireDescs["GearUp"] .. ")","Gear Down (" .. GearboxWireDescs["GearDown"] .. ")"}
		if Gearbox.CVT then
			table.insert(Inputs,"CVT Ratio")
		elseif Gearbox.DoubleDiff then
			table.insert(Inputs, "Steer Rate")
		elseif Gearbox.Auto then
			table.insert(Inputs, "Hold Gear")
			table.insert(Inputs, "Shift Speed Scale")
			Gearbox.Hold = false
		end

		if Gearbox.Dual then
			table.insert(Inputs, "Left Clutch")
			table.insert(Inputs, "Right Clutch")
			table.insert(Inputs, "Left Brake")
			table.insert(Inputs, "Right Brake")
		else
			table.insert(Inputs, "Clutch (" .. GearboxWireDescs["Clutch"] .. ")")
			table.insert(Inputs, "Brake (" .. GearboxWireDescs["Brake"] .. ")")
		end

		local Outputs = { "Ratio", "Entity", "Current Gear" }
		local OutputTypes = { "NORMAL", "ENTITY", "NORMAL" }
		if Gearbox.CVT then
			table.insert(Outputs,"Min Target RPM")
			table.insert(Outputs,"Max Target RPM")
			table.insert(OutputTypes,"NORMAL")
		end

		Gearbox.Inputs = Wire_CreateInputs( Gearbox, Inputs )
		Gearbox.Outputs = WireLib.CreateSpecialOutputs( Gearbox, Outputs, OutputTypes )
		Wire_TriggerOutput(Gearbox, "Entity", Gearbox)

		if Gearbox.CVT then
			Wire_TriggerOutput(Gearbox, "Min Target RPM", Gearbox.MinRPMTarget)
			Wire_TriggerOutput(Gearbox, "Max Target RPM", Gearbox.MaxRPMTarget)
		end

		Gearbox.LClutch = Gearbox.MaxTorque
		Gearbox.RClutch = Gearbox.MaxTorque

		Gearbox:PhysicsInit( SOLID_VPHYSICS )
		Gearbox:SetMoveType( MOVETYPE_VPHYSICS )
		Gearbox:SetSolid( SOLID_VPHYSICS )

		local phys = Gearbox:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetMass( Gearbox.Mass )
			Gearbox.ModelInertia = 0.99 * phys:GetInertia() / phys:GetMass() -- giving a little wiggle room
		end

		Gearbox.In = Gearbox:WorldToLocal(Gearbox:GetAttachment(Gearbox:LookupAttachment( "input" )).Pos)
		Gearbox.OutL = Gearbox:WorldToLocal(Gearbox:GetAttachment(Gearbox:LookupAttachment( "driveshaftL" )).Pos)
		Gearbox.OutR = Gearbox:WorldToLocal(Gearbox:GetAttachment(Gearbox:LookupAttachment( "driveshaftR" )).Pos)

		Owner:AddCount("_ace_gearbox", Gearbox)
		Owner:AddCleanup( "acemenu", Gearbox )

		Gearbox:ChangeGear(1)

		if Gearbox.Dual or Gearbox.DoubleDiff then
			Gearbox:SetBodygroup(1, 1)
		else
			Gearbox:SetBodygroup(1, 0)
		end

		Gearbox:SetNWString( "WireName", GearboxData.name )
		Gearbox:UpdateOverlayText()

	ACE.Activate( Gearbox, 0 )

		return Gearbox
	end
	duplicator.RegisterEntityClass("ace_gearbox", MakeACE_Gearbox, "Pos", "Angle", "Id", "Data" )

end

function ENT:Update( _, Id, Data )
	-- That table is the player data, as sorted in the ACECvars above, with player who shot,
	-- and pos and angle of the tool trace inserted at the start

	local GearboxData = GearboxTable[Id]
	if GearboxData.model ~= self.Model then
		return false, "The new gearbox must have the same model!"
	end

	if self.Id ~= Id then

		self.Id           = Id
		self.Mass         = GearboxData.weight		or 1
		self.SwitchTime   = GearboxData.switch
		self.MaxTorque    = GearboxData.maxtq		or 0
		self.Gears        = GearboxData.gears		or 2
		self.Dual         = GearboxData.doubleclutch	or false
		self.CVT          = GearboxData.cvt			or false
		self.DoubleDiff   = GearboxData.doublediff	or false
		self.Auto         = GearboxData.auto			or false
		self.Parentable   = GearboxData.parentable	or false

		local Inputs = {"Gear","Gear Up","Gear Down"}
		if self.CVT then
			table.insert(Inputs,"CVT Ratio")
		elseif self.DoubleDiff then
			table.insert(Inputs, "Steer Rate")
		elseif self.Auto then
			table.insert(Inputs, "Hold Gear")
			table.insert(Inputs, "Shift Speed Scale")
			self.Hold = false
		end

		if self.Dual then
			table.insert(Inputs, "Left Clutch")
			table.insert(Inputs, "Right Clutch")
			table.insert(Inputs, "Left Brake")
			table.insert(Inputs, "Right Brake")
		else
			table.insert(Inputs, "Clutch")
			table.insert(Inputs, "Brake")
		end

		local Outputs = { "Ratio", "Entity", "Current Gear" }
		local OutputTypes = { "NORMAL", "ENTITY", "NORMAL" }
		if self.CVT then
			table.insert(Outputs,"Min Target RPM")
			table.insert(Outputs,"Max Target RPM")
			table.insert(OutputTypes,"NORMAL")
		end

		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetMass( self.Mass )
		end

		self.Inputs = Wire_CreateInputs( self, Inputs )
		self.Outputs = WireLib.CreateSpecialOutputs( self, Outputs, OutputTypes )
		Wire_TriggerOutput( self, "Entity", self )
	end

	if self.CVT then
		self.MinRPMTarget = Data.MinRPMTarget or 0
		self.MaxRPMTarget = math.max(Data.MaxRPMTarget or 0,Data.MinRPMTarget + 100)
		self.CVTRatio = nil
		Wire_TriggerOutput(self, "Min Target RPM", self.MinRPMTarget)
		Wire_TriggerOutput(self, "Max Target RPM", self.MaxRPMTarget)
	end

	self.GearTable = Data.GearTable or {}
	self.GearTable[0] = GearboxData.geartable[0]
	self.FinalDrive = Data.FinalDrive or 0.5
	self.GearRatio = (self.GearTable[0] or 0) * self.FinalDrive

	if self.Auto then
		self.ShiftPoints = Data.ShiftPoints or {}
		self.ShiftPoints[0] = -1
		self.Reverse = self.Gears + 1
		self.Drive = 1
		self.ShiftScale = 1
	end

	self.Gear = 1
	self.GearRatio = (self.GearTable[self.Gear] or 0) * self.FinalDrive
	self.ChangeFinished = CurTime() + self.SwitchTime
	self.InGear = false

	if self.Dual or self.DoubleDiff then
		self:SetBodygroup(1, 1)
	else
		self:SetBodygroup(1, 0)
	end

	self:SetNWString( "WireName", GearboxData.name )
	self:UpdateOverlayText()

ACE.Activate( self, 1 )

	return true, "Gearbox updated successfully!"
end

function ENT:UpdateOverlayText()

	local text = ""

	text = text .. "Current Gear: " .. self.Gear .. "\n\n"

	if self.CVT then
		text = text .. "Reverse Gear: " .. math.Round( self.GearTable[ 2 ], 2 ) -- maybe a better name than "gear 2"...?
		text = text .. "\nTarget: " .. math.Round( self.MinRPMTarget ) .. " - " .. math.Round( self.MaxRPMTarget ) .. " RPM\n"
	elseif self.Auto then
		for i = 1, self.Gears do
			text = text .. "Gear " .. i .. ": " .. math.Round( self.GearTable[ i ], 2 ) .. ", Upshift @ " .. math.Round( self.ShiftPoints[i] / 10.936, 1 ) .. " kph / " .. math.Round( self.ShiftPoints[i] / 17.6 ,1 ) .. " mph\n"
		end
	else
		for i = 1, self.Gears do
			text = text .. "Gear " .. i .. ": " .. math.Round( self.GearTable[ i ], 2 ) .. "\n"
		end
	end
	if self.Auto then
		text = text .. "\nReverse Gear: " .. math.Round( self.GearTable[ self.Reverse ], 2 ) .. "\n"
	end

	text = text .. "\nFinal Drive Ratio: " .. math.Round( self.FinalDrive, 2 ) .. "\n\n"
	text = text .. "Torque Rating: " .. self.MaxTorque .. " Nm / " .. math.Round( self.MaxTorque * 0.73 ) .. " ft-lb"

	if not self.Legal then
		text = text .. "\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )

end


-- prevent people from changing bodygroup
function ENT:CanProperty( _, property )

	return property ~= "bodygroups"

end

function ENT:TriggerInput( iname, value )

	if ( iname == "Gear" ) then
		if self.Auto then
			self:ChangeDrive(value)
		else
			self:ChangeGear(value)
		end
	elseif ( iname == "Gear Up" ) and value ~= 0 then
		if self.Auto then
			self:ChangeDrive(self.Drive + 1)
		else
			self:ChangeGear(self.Gear + 1)
		end
	elseif ( iname == "Gear Down" ) and value ~= 0 then
		if self.Auto then
			self:ChangeDrive(self.Drive - 1)
		else
			self:ChangeGear(self.Gear - 1)
		end
	elseif ( iname == "Clutch" ) then
		self.LClutch = math.Clamp(1-value,0,1) * self.MaxTorque
		self.RClutch = math.Clamp(1-value,0,1) * self.MaxTorque
	elseif ( iname == "Brake" ) then
		self.LBrake = math.Clamp(value,0,100)
		self.RBrake = math.Clamp(value,0,100)
	elseif ( iname == "Left Brake" ) then
		self.LBrake = math.Clamp(value,0,100)
	elseif ( iname == "Right Brake" ) then
		self.RBrake = math.Clamp(value,0,100)
	elseif ( iname == "Left Clutch" ) then
		self.LClutch = math.Clamp(1-value,0,1) * self.MaxTorque
	elseif ( iname == "Right Clutch" ) then
		self.RClutch = math.Clamp(1-value,0,1) * self.MaxTorque
	elseif ( iname == "CVT Ratio" ) then
		self.CVTRatio = math.Clamp(value,0,1)
	elseif ( iname == "Steer Rate" ) then
		self.SteerRate = math.Clamp(value,-1,1)
	elseif ( iname == "Hold Gear" ) then
		self.Hold = value ~= 0
	elseif ( iname == "Shift Speed Scale" ) then
		self.ShiftScale = math.Clamp(value,0.1,1.5)
	end

end

function ENT:Think()

	if ACE.CurTime > self.NextLegalCheck then
		self.Legal, self.LegalIssues = ACE.CheckLegal(self, self.Model, math.Round(self.Mass,2), self.ModelInertia, true, true) -- requiresweld overrides parentable, need to set it false for parent-only gearboxes
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)
		self:UpdateOverlayText()

		if self.Legal and self.Parentable then self.RootParent = ACE.GetPhysicalParent(self) end
	end

	local Time = CurTime()

	if self.LastActive + 2 > Time then
		self:CheckRopes()
	end

	self:NextThink( Time + math.random( 5, 10 ) )
	return true

end

function ENT:CheckRopes()

	for Key, Link in pairs( self.WheelLink ) do

		local Ent = Link.Ent

		--skips any invalid entity and remove from list
		if not IsValid(Ent) then print("[ACE | WARN]- We found invalid ents linked to a gear, removing it. . .") table.remove(self.WheelLink, Key) continue end

		local OutPos = self:LocalToWorld( Link.Output )
		local InPos = Ent:GetPos()
		if Ent.IsGeartrain then
			InPos = Ent:LocalToWorld( Ent.In )
		end

		-- make sure it is not stretched too far
		if OutPos:Distance( InPos ) > Link.RopeLen * 1.5 then
			self:Unlink( Ent )
			local soundstr =  "physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav"
			self:EmitSound(soundstr,500,100)
		end

		-- make sure the angle is not excessive
		if not self:Checkdriveshaft( Ent ) then
			self:Unlink( Ent )
			local soundstr =  "physics/metal/metal_box_impact_bullet" .. tostring(math.random(1, 3)) .. ".wav"
			self:EmitSound(soundstr,500,100)
		end
	end
end

-- Check if every entity we are linked to still actually exists
-- and remove any links that are invalid.
function ENT:CheckEnts()

	for Key, Link in pairs( self.WheelLink ) do

		if not IsValid( Link.Ent ) then
			table.remove( self.WheelLink, Key )
		continue end

		local Phys = Link.Ent:GetPhysicsObject()
		if not IsValid( Phys ) then
			Link.Ent:Remove()
			table.remove( self.WheelLink, Key )
		end

	end

end

function ENT:Calc( InputRPM, InputInertia )
	if not self.Legal then return 0 end

	if self.LastActive == CurTime() then
		return math.min( self.TotalReqTq, self.MaxTorque )
	end

	if self.ChangeFinished < CurTime() then
		self.InGear = true
	end

	self:CheckEnts()

	local BoxPhys = self:GetPhysicsObject()
	local SelfWorld = BoxPhys:LocalToWorldVector( BoxPhys:GetAngleVelocity() )

	if self.CVT and self.Gear == 1 then
		if self.CVTRatio and self.CVTRatio > 0 then
			self.GearTable[1] = math.Clamp(self.CVTRatio,0.01,1)
		else
			self.GearTable[1] = math.Clamp((InputRPM - self.MinRPMTarget) / ((self.MaxRPMTarget - self.MinRPMTarget) or 1),0.05,1)
		end
		self.GearRatio = (self.GearTable[1] or 0) * self.FinalDrive
		Wire_TriggerOutput(self, "Ratio", self.GearRatio)
	end

	if self.Auto and self.Drive == 1 and self.InGear then
		local Base = ACE.GetPhysicalParent( self )
		local PhysObj = Base:GetPhysicsObject()
		local vel = PhysObj:GetVelocity():Length()
		if vel > (self.ShiftPoints[self.Gear] * self.ShiftScale) and not (self.Gear == self.Gears) and not self.Hold then
			self:ChangeGear(self.Gear + 1)
		elseif vel < (self.ShiftPoints[self.Gear-1] * self.ShiftScale) then
			self:ChangeGear(self.Gear - 1)
		end
	end

	self.TotalReqTq = 0

	for Key, Link in pairs( self.WheelLink ) do

		if not IsValid( Link.Ent ) then table.remove( self.WheelLink, Key ) continue end
		if Link.Notvalid then continue end

		local Clutch = 0
		if Link.Side == 0 then
			Clutch = self.LClutch
		elseif Link.Side == 1 then
			Clutch = self.RClutch
		end

		Link.ReqTq = 0
		if Link.Ent.IsGeartrain then
			if not Link.Ent.Legal then continue end
			local Inertia = 0
			if self.GearRatio ~= 0 then Inertia = InputInertia / self.GearRatio end
			Link.ReqTq = math.min( Clutch, math.abs( Link.Ent:Calc( InputRPM * self.GearRatio, Inertia ) * self.GearRatio ) )
		elseif self.DoubleDiff then
			local RPM = self:CalcWheel( Link, SelfWorld )
			if self.GearRatio ~= 0 and ( ( InputRPM > 0 and RPM < InputRPM ) or ( InputRPM < 0 and RPM > InputRPM ) ) then
				local NTq = math.min( Clutch, ( InputRPM - RPM) * InputInertia)

				if self.SteerRate ~= 0 then
					Sign = self.SteerRate / math.abs( self.SteerRate )
				else
					Sign = 0
				end
				if Link.Side == 0 then
						local DTq = math.Clamp( ( self.SteerRate * ( ( InputRPM * ( math.abs( self.SteerRate ) + 1 ) ) - (RPM * Sign) ) ) * InputInertia, -self.MaxTorque, self.MaxTorque )
					Link.ReqTq = ( NTq + DTq )
				elseif Link.Side == 1 then
						local DTq = math.Clamp( ( self.SteerRate * ( ( InputRPM * ( math.abs( self.SteerRate ) + 1 ) ) + (RPM * Sign) ) ) * InputInertia, -self.MaxTorque, self.MaxTorque )
					Link.ReqTq = ( NTq - DTq )
				end
			end
		else
			local RPM = self:CalcWheel( Link, SelfWorld )
			if self.GearRatio ~= 0 and ( ( InputRPM > 0 and RPM < InputRPM ) or ( InputRPM < 0 and RPM > InputRPM ) ) then
				Link.ReqTq = math.min( Clutch, ( InputRPM - RPM ) * InputInertia )
			end
		end
		self.TotalReqTq = self.TotalReqTq + math.abs( Link.ReqTq )


	end

	--I would need to learn more about this, disabled atm
	--self.Heat = ACE.HeatFromGearbox( self , InputRPM)
	--Wire_TriggerOutput(self, "Heat", self.Heat)

	return math.min( self.TotalReqTq, self.MaxTorque )

end

function ENT:CalcWheel( Link, SelfWorld )

	local Wheel = Link.Ent
	local WheelPhys = Wheel:GetPhysicsObject()
	local VelDiff = WheelPhys:LocalToWorldVector( WheelPhys:GetAngleVelocity() ) - SelfWorld
	local BaseRPM = VelDiff:Dot( WheelPhys:LocalToWorldVector( Link.Axis ) )
	Link.Vel = BaseRPM

	if self.GearRatio == 0 then return 0 end

	-- Reported BaseRPM is in angle per second and in the wrong direction, so we convert and add the gearratio
	return BaseRPM / self.GearRatio / -6

end

function ENT:Act( Torque, DeltaTime, MassRatio )

	if not self.Legal then self.LastActive = CurTime() return end
	--internal torque loss from being damaged
	local Loss = math.Clamp(((1 - 0.4) / 0.5) * ((self.ACE.Health / self.ACE.MaxHealth) - 1) + 1, 0.4, 1)

	--internal torque loss from inefficiency
	local Slop = self.Auto and 0.9 or 1

	local ReactTq = 0
	-- Calculate the ratio of total requested torque versus what's avaliable, and then multiply it but the current gearratio
	local AvailTq = 0
	if Torque ~= 0 and self.GearRatio ~= 0 then
		AvailTq = math.min( math.abs( Torque ) / self.TotalReqTq, 1 ) / self.GearRatio * -( -Torque / math.abs( Torque ) ) * Loss * Slop
	end

	for _, Link in pairs( self.WheelLink ) do

		if Link.Notvalid then continue end

		local Brake = 0
		if Link.Side == 0 then
			Brake = self.LBrake
		elseif Link.Side == 1 then
			Brake = self.RBrake
		end

		if Link.Ent.IsGeartrain then
			Link.Ent:Act( Link.ReqTq * AvailTq, DeltaTime, MassRatio )
		else
			self:ActWheel( Link, Link.ReqTq * AvailTq, Brake, DeltaTime )
			ReactTq = ReactTq + Link.ReqTq * AvailTq
		end


	end

	local BoxPhys
	if IsValid( self.RootParent ) then
		BoxPhys = self.RootParent:GetPhysicsObject()
	else
		BoxPhys = self:GetPhysicsObject()
	end

	if IsValid( BoxPhys ) and ReactTq ~= 0 then
		local Torque = self:GetRight() * math.Clamp( 2 * math.deg( ReactTq * MassRatio ) * DeltaTime, -500000, 500000 )
		BoxPhys:ApplyTorqueCenter( Torque )
	end

	self.LastActive = CurTime()

end

function ENT:ActWheel( Link, Torque, Brake, DeltaTime )

	local Phys = Link.Ent:GetPhysicsObject()
	local TorqueAxis = Phys:LocalToWorldVector( Link.Axis )

	local BrakeMult = 0
	if Brake > 0 then
		BrakeMult = Link.Vel * Link.Inertia * Brake / 5
	end

	local Torque = TorqueAxis * math.Clamp( math.deg( -Torque * 1.5 - BrakeMult ) * DeltaTime, -500000, 500000 )
	Phys:ApplyTorqueCenter( Torque )
end

function ENT:ChangeGear(value)

	local new = math.Clamp(math.floor(value),0,self.Gears)
	if self.Gear == new then return end

	self.Gear = new
	self.GearRatio = (self.GearTable[self.Gear] or 0) * self.FinalDrive
	self.ChangeFinished = CurTime() + self.SwitchTime
	self.InGear = false

	Wire_TriggerOutput(self, "Current Gear", self.Gear)
	self:EmitSound("buttons/lever7.wav",250,100)
	Wire_TriggerOutput(self, "Ratio", self.GearRatio)

end

--handles gearing for automatics; 0=neutral, 1=forward autogearing, 2=reverse
function ENT:ChangeDrive(value)

	local new = math.Clamp(math.floor(value),0,2)
	if self.Drive == new then return end

	self.Drive = new
	if self.Drive == 2 then
		self.Gear = self.Reverse
		self.GearRatio = (self.GearTable[self.Gear] or 0) * self.FinalDrive
		self.ChangeFinished = CurTime() + self.SwitchTime
		self.InGear = false

		Wire_TriggerOutput(self, "Current Gear", self.Gear)
		self:EmitSound("buttons/lever7.wav",250,100)
		Wire_TriggerOutput(self, "Ratio", self.GearRatio)
	else
		self:ChangeGear(self.Drive) --autogearing in :calc will set correct gear
	end

end

do

	--[[
	--HARDCODED. USE MODELDEFINITION INSTEAD
	local TransAxialGearboxes = {
		["models/engines/transaxial_l.mdl"] = true,
		["models/engines/transaxial_m.mdl"] = true,
		["models/engines/transaxial_s.mdl"] = true,
		["models/engines/transaxial_t.mdl"] = true --mhm ace extras invading...
	}
	]]

	function ENT:Checkdriveshaft( NextEnt )

		local InPos = vector_origin
		if NextEnt.IsGeartrain then
			InPos = NextEnt.In
		end
		local InPosWorld = NextEnt:LocalToWorld( InPos )

		local OutPos	= self.OutR
		if self:WorldToLocal( InPosWorld ).y < 0 then
			OutPos  = self.OutL
		end
		local OutPosWorld = self:LocalToWorld( OutPos )

		local MaxAngle = 0.7 --magic number to define the max tolerance of link between gearboxes
		local Direction = ( self:GetRight() * OutPos.y ):GetNormalized()
		local DrvAngle = ( OutPosWorld - InPosWorld ):GetNormalized():Dot( Direction )

		if DrvAngle < MaxAngle then
			return false
		--else
			--[[ --Disabled since this could break several builds. When we have more junctions, this could be enforced.
			--Now, do the same, but from gearbox's point this time.
			Direction 	= TransAxialGearboxes[ NextEnt:GetModel() ] and -NextEnt:GetForward() or -NextEnt:GetRight() --transaxial like those T junctions. Forward is for Straight like gearboxes.
			DrvAngle 	= ( InPosWorld - OutPosWorld ):GetNormalized():Dot( Direction )

			if DrvAngle < MaxAngle then
				return false
			end
			]]
		end

		return true
	end

end

function ENT:Link( Target )

	if not IsValid( Target ) or not table.HasValue( { "prop_physics", "ace_gearbox", "tire" }, Target:GetClass() ) then
		return false, "Can only link props or gearboxes!"
	end

	-- Check if target is already linked
	for _, Link in pairs( self.WheelLink ) do
		if Link.Ent == Target then
			return false, "That is already linked to this gearbox!"
		end
	end

	-- make sure the angle is not excessive
	if not self:Checkdriveshaft( Target ) then
		return false, "Cannot link due to excessive driveshaft angle!"
	end

	local InPos = Vector( 0, 0, 0 )
	if Target.IsGeartrain then
		InPos = Target.In
	end
	local InPosWorld = Target:LocalToWorld( InPos )

	local OutPos	= self.OutR
	local Side	= 1
	if self:WorldToLocal( InPosWorld ).y < 0 then
		OutPos  = self.OutL
		Side	= 0
	end
	local OutPosWorld = self:LocalToWorld( OutPos )

	local Rope = nil
	if ACE.GetEntityOwner(self):GetInfoNum( "ACE_MobilityRopeLinks", 1) == 1 then
		Rope = ACE.CreateLinkRope( OutPosWorld, self, OutPos, Target, InPos )
	end

	local Phys	= Target:GetPhysicsObject()
	local Axis	= Phys:WorldToLocalVector( self:GetRight() )
	local Inertia	= ( Axis * Phys:GetInertia() ):Length()

	local Link = {
		Ent			= Target,
		Side		= Side,
		Axis		= Axis,
		Inertia		= Inertia,
		Rope		= Rope,
		RopeLen		= ( OutPosWorld - InPosWorld ):Length(),
		Output		= OutPos,
		ReqTq		= 0,
		Vel			= 0
	}
	table.insert( self.WheelLink, Link )

	return true, "Link successful!"

end

function ENT:Unlink( Target )

	for Key, Link in pairs( self.WheelLink ) do

		if Link.Ent == Target then

			-- Remove any old physical ropes leftover from dupes
			for _, Rope in pairs( constraint.FindConstraints( Link.Ent, "Rope" ) ) do
				if Rope.Ent1 == self or Rope.Ent2 == self then
					Rope.Constraint:Remove()
				end
			end

			if IsValid( Link.Rope ) then
				Link.Rope:Remove()
			end

			table.remove( self.WheelLink, Key )

			return true, "Unlink successful!"

		end

	end

	return false, "That entity is not linked to this gearbox!"

end

function ENT:PreEntityCopy()

	-- Link Saving
	local info = {}
	local entids = {}

	-- Clean the table of any invalid entities
	for Key, Link in pairs( self.WheelLink ) do
		if not IsValid( Link.Ent ) then
			table.remove( self.WheelLink, Key )
		end
	end

	-- Then save it
	for _, Link in pairs( self.WheelLink ) do
		table.insert( entids, Link.Ent:EntIndex() )
	end

	info.entities = entids
	if info.entities then
		duplicator.StoreEntityModifier( self, "WheelLink", info )
	end

	--Wire dupe info
	self.BaseClass.PreEntityCopy( self )

end

function ENT:PostEntityPaste( Player, Ent, CreatedEntities )

	-- Link Pasting
	if Ent.EntityMods and Ent.EntityMods.WheelLink and Ent.EntityMods.WheelLink.entities then
		local WheelLink = Ent.EntityMods.WheelLink
		if WheelLink.entities and next( WheelLink.entities ) then
			timer.Simple( 0, function() -- this timer is a workaround for an ad2/makespherical issue https://github.com/nrlulz/ACF/issues/14#issuecomment-22844064
				for _, ID in pairs( WheelLink.entities ) do
					local Linked = CreatedEntities[ ID ]
					if IsValid( Linked ) then
						self:Link( Linked )
					end
				end
			end )
		end
		Ent.EntityMods.WheelLink = nil
	end

	--Wire dupe info
	self.BaseClass.PostEntityPaste( self, Player, Ent, CreatedEntities )

end

function ENT:OnRemove()

	for Key in pairs(self.Master) do	--Let's unlink ourselves from the engines properly
		if IsValid( self.Master[Key] ) then
			self.Master[Key]:Unlink( self )
		end
	end

end