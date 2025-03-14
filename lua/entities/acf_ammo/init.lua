
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability") -- Required to get the local BaseClass. A workaround uses this below

local ACE = ACE or {}
if not ACE.AmmoCrates then
	ACE.AmmoCrates = {}
end

local GunClasses = ACE.Classes.GunClass

local GunTable  = ACE.Weapons.Guns
local AmmoTable = ACE.Weapons.Ammo
local LegacyAmmoTable = ACE.Weapons.LegacyAmmo

local Inputs = {
	"Active"
}
local Outputs = {
	"Munitions (Returns the current number of rounds in this crate.)",
	"Capacity (Returns the capacity of this crate.)"
}

function ENT:Initialize()

	self.SpecialHealth       = true  --If true needs a special ACE_Activate function
	self.SpecialDamage       = true  --If true needs a special ACE_OnDamage function

	self.IsExplosive         = true
	self.Exploding           = false
	self.Damaged             = false

	self.CanUpdate           = true
	self.Load                = false
	self.EmptyMass           = 1
	self.AmmoMassMax         = 0
	self.NextMassUpdate      = 0

	self.Ammo                = 0
	self.IsTwoPiece          = false

	self.NextLegalCheck      = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max) -- give any spawning issues time to iron themselves out
	self.Legal               = true
	self.LegalIssues         = ""

	self.Active              = false
	self.Master              = {}
	self.Sequence            = 0

	self.Interval            = 1		-- Think Interval when its not damaged
	self.ExplosionInterval   = 0.01	-- Base Think Interval when its damaged and its about to explode

	self.Capacity            = 1
	self.AmmoMassMax         = 1
	self.Caliber             = 1
	self.RoFMul              = 1
	self.LastMass            = 1

	self.Inputs              = Wire_CreateInputs( self, Inputs )
	self.Outputs             = Wire_CreateOutputs( self, Outputs )

end

function ENT:InitializeOnCollector()
	ACE.AmmoCrates[self] = true
end

function ENT:OnRemoveCollectorData()
	ACE.AmmoCrates[self] = nil
end


function ENT:ACE_Activate( Recalc )

	local EmptyMass = math.max(self.EmptyMass, self:GetPhysicsObject():GetMass() - self.AmmoMassMax)

	self.ACE = self.ACE or {}

	local PhysObj = self:GetPhysicsObject()

	if not self.ACE.Area then
		self.ACE.Area = PhysObj:GetSurfaceArea() * 6.45
	end

	if not self.ACE.Volume then
		self.ACE.Volume = PhysObj:GetVolume() * 16.38
	end

	local Armour	= EmptyMass * 1000 / self.ACE.Area / 0.78 --So we get the equivalent thickness of that prop in mm if all it's weight was a steel plate
	local Health	= self.ACE.Volume / ACE.Threshold						--Setting the threshold of the prop Area gone
	local Percent	= 1

	if Recalc and self.ACE.Health and self.ACE.MaxHealth then
		Percent = self.ACE.Health / self.ACE.MaxHealth
	end

	self.ACE.Health    = Health * Percent
	self.ACE.MaxHealth = Health
	self.ACE.Armour    = Armour * (0.5 + Percent / 2)
	self.ACE.MaxArmour = Armour
	self.ACE.Type      = nil
	self.ACE.Mass      = self.Mass
	self.ACE.Density   = (self:GetPhysicsObject():GetMass() * 1000) / self.ACE.Volume
	self.ACE.Type      = "Prop"

	self.ACE.Material	= not isstring(self.ACE.Material) and ACE.BackCompMat[self.ACE.Material] or self.ACE.Material or "RHA"

	--Forces an update of mass
	self.LastMass = 1
	self:UpdateMass()

end

do

	local HEATtbl = {
		HEAT	= true,
		THEAT	= true,
		HEATFS  = true,
		THEATFS = true
	}

	local HEtbl = {
		HE	= true,
		HESH	= true,
		HEFS	= true
	}

	function ENT:ACE_OnDamage( Entity, Energy, FrArea, Angle, Inflictor, _, Type )	--This function needs to return HitRes

		local Mul	= (( HEATtbl[Type] and ACE.HEATMulAmmo ) or 1) --Heat penetrators deal bonus damage to ammo
		local HitRes	= ACE_PropDamage( Entity, Energy, FrArea * Mul, Angle, Inflictor ) --Calling the standard damage prop function

		if self.Exploding or not self.IsExplosive then return HitRes end

		if HitRes.Kill then

			if hook.Run("ACE_AmmoExplode", self, self.BulletData ) == false then return HitRes end

			self.Exploding = true

			if Inflictor and IsValid(Inflictor) and Inflictor:IsPlayer() then
				self.Inflictor = Inflictor
			end

			if self.Ammo > 1 and self.BulletData.Type ~= "Refill" then
				ACE_ScaledExplosion( self )
			else
				self:Remove()
			end
		end

		-- cookoff chance calculation
		if self.Damaged then return HitRes end

		if not next( self.BulletData or {} ) then
			self:Remove()
		else

			local Ratio	= ( HitRes.Damage / self.BulletData.RoundVolume ) ^ 0.2
			local CMul	= 1  --30% Chance to detonate, 5% chance to cookoff
			local DetRand	= 0

			--Heat penetrators deal bonus damage to ammo, 90% chance to detonate, 15% chance to cookoff
			if HEATtbl[Type] then
				CMul = 6
			elseif HEtbl[Type] then
				CMul = 10
			end

			if self.BulletData.Type == "Refill" then
				DetRand = 0.75
			else
				DetRand = math.Rand(0,1) * CMul
			end

			--Cook Off
			if DetRand >= 0.95 then

				self.Inflictor  = Inflictor
				self.Damaged	= ACE.CurTime + (5 - Ratio * 3)

			--Boom
			elseif DetRand >= 0.7 then

				self.Inflictor  = Inflictor
				self.Damaged	= 1 --Instant explosion guarenteed

			end

		end

		return HitRes --This function needs to return HitRes
	end

end


do

	-- Checks if the provided string vector matches the desired format.
	-- Define a pattern to match the format
	local pattern = "^%d+%.?%d*:%d+%.?%d*:%d+%.?%d*$"
	local function IsValidStringScale( Id )
		if not isstring( Id ) then return false end
		if not string.match(Id, pattern) then return false end
		return true
	end

	-- Converts an already verified string vector into a valid vector scale.
	local function ParseToVector( ScaleId )
		if not isstring(ScaleId) then return end

		local Result = string.Explode( ":", ScaleId )

		local X = tonumber(Result[1])
		local Y = tonumber(Result[2])
		local Z = tonumber(Result[3])

		return Vector(X, Y, Z)
	end

	-- Clamps the already converted scale so its within the size limits, defined on globals.
	local function ClampScale( Scale )
		if not isvector( Scale ) then return end

		local MinSize = ACE.CrateMinimumSize
		local MaxSize = ACE.CrateMaximumSize

		Scale.x = math.Clamp( math.Round(Scale.x, 1), MinSize, MaxSize)
		Scale.y = math.Clamp( math.Round(Scale.y, 1), MinSize, MaxSize)
		Scale.z = math.Clamp( math.Round(Scale.z, 1), MinSize, MaxSize)

		return Scale
	end

	-- Tries to convert a scale id, having a string format, to a vector scale. If its already a vector, skip the process.
	local function ConvertStringScale( ScaleId )
		if isvector( ScaleId ) then return ScaleId end
		if not IsValidStringScale( ScaleId ) then return end

		local Scale = ParseToVector( ScaleId )
		Scale = ClampScale( Scale )

		return Scale
	end

	-- If the incoming Id belongs to an invalid ammo crate, but belongs to the legacy crates list, convert it into its scalable counterpart.
	local function CreateLegacyScale( Id, Ammo )
		local Content = LegacyAmmoTable[Id]
		Scale = Vector( Content.Length, Content.Width, Content.Height )

		local Pos = Ammo:LocalToWorld( vector_up * Content.Offset )
		Ammo:SetPos( Pos ) -- necessary to do, since some old crates had not a coordinated origin at its center but the base of them.
		Ammo.LegacyPosInject = Pos

		return Scale
	end

	function MakeACE_Ammo(Owner, Pos, Angle, Id, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15)

		if not Owner:CheckLimit("_acf_ammo") then return false end

		local Ammo = ents.Create("acf_ammo")
		if IsValid(Ammo) then

			local Model
			local Weight
			local Dimensions

			ACE.SetEntityOwner(Ammo, Owner)
			Ammo:SetAngles(Angle)
			Ammo:SetPos(Pos)
			Ammo:Spawn()

			-- If the crate is not valid in the system, but it could be in the LegacyAmmoTable o be scalable.
			if not ACE_CheckAmmo( Id ) then

				local Scale

				if isstring(Id) and LegacyAmmoTable[Id] then
					Scale = CreateLegacyScale(Id, Ammo)
				else
					Scale = ConvertStringScale(Id)
				end

				if isvector(Scale) then

					local ModelData = ACE.ModelData["Box"]

					Id = Scale
					Model = ModelData.Model
					Weight = (Scale.x * Scale.y * Scale.z) / 200
					Dimensions = Scale

					local DefaultSize    = ModelData.DefaultSize
					local Mesh           = ModelData.CustomMesh
					local PhysMaterial   = ModelData.physMaterial
					local EntityScale    = Vector(Scale.x / DefaultSize, Scale.y / DefaultSize, Scale.z / DefaultSize)

					Ammo.ScaleData = {
						Mesh = Mesh,
						Scale = EntityScale,
						Size = DefaultSize,
						Material = PhysMaterial,
					}

					Ammo:SetMaterial("models/props_canal/metalwall005b")
					Ammo:SetModel( Model ) --Sending the model to client
					Ammo:PhysicsInit( SOLID_VPHYSICS )
					Ammo:SetMoveType( MOVETYPE_VPHYSICS )
					Ammo:SetSolid( SOLID_VPHYSICS )

					Ammo.IsScalable = true
					Ammo:ACE_SetScale( Ammo.ScaleData )

				else
					Id = "Shell100mm"
				end
			end

			-- If the crate is legacy, but still valid in the system
			if ACE_CheckAmmo( Id ) then

				local AmmoData = AmmoTable[Id]

				Model = AmmoData.model
				Weight = AmmoData.weight
				Dimensions = Vector( AmmoData.Length, AmmoData.Width, AmmoData.Height )

				Ammo:SetModel( Model )
				Ammo:PhysicsInit( SOLID_VPHYSICS )
				Ammo:SetMoveType( MOVETYPE_VPHYSICS )
				Ammo:SetSolid( SOLID_VPHYSICS )

			end

			Ammo.Id = Id
			Ammo.Model = Model
			Ammo.Dimensions = Dimensions

			Ammo:CreateAmmo(Id, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15)

			Ammo.Ammo        = Ammo.Capacity
			Ammo.EmptyMass   = Weight or 1
			Ammo.AmmoMass    = Ammo.EmptyMass + Ammo.AmmoMassMax

			Ammo.LastMass	= 1
			Ammo:UpdateMass()

			Owner:AddCount( "_acf_ammo", Ammo )
			Owner:AddCleanup( "acfmenu", Ammo )

			return Ammo
		end
	end
end

list.Set( "ACFCvars", "acf_ammo", {"id", "data1", "data2", "data3", "data4", "data5", "data6", "data7", "data8", "data9", "data10", "data11", "data12", "data13", "data14", "data15"} )
duplicator.RegisterEntityClass("acf_ammo", MakeACE_Ammo, "Pos", "Angle", "Id", "RoundId", "RoundType", "RoundPropellant", "RoundProjectile", "RoundData5", "RoundData6", "RoundData7", "RoundData8", "RoundData9", "RoundData10" , "RoundData11", "RoundData12", "RoundData13", "RoundData14", "RoundData15" )


function ENT:Update( ArgsTable )

	-- That table is the player data, as sorted in the ACFCvars above, with player who shot,
	-- and pos and angle of the tool trace inserted at the start

	local msg = "Ammo crate updated successfully!"

	if ArgsTable[6] == "Refill" then -- Argtable[6] is the round type. If it's refill it shouldn't be loaded into guns, so we refuse to change to it
		return false, "Refill ammo type is only avaliable for new crates!"
	end

	if ArgsTable[5] ~= self.RoundId then -- Argtable[5] is the weapon ID the new ammo loads into
		for _, Gun in pairs( self.Master ) do
			if IsValid( Gun ) then
				Gun:Unlink( self )
			end
		end
		msg = "New ammo type loaded, crate unlinked."
	else -- ammotype wasn't changed, but let's check if new roundtype is blacklisted
		local Blacklist = ACE.AmmoBlacklist[ ArgsTable[6] ] or {}

		for _, Gun in pairs( self.Master ) do
			if IsValid( Gun ) and table.HasValue( Blacklist, Gun.Class ) then
				Gun:Unlink( self )
				msg = "New round type cannot be used with linked gun, crate unlinked."
			end
		end
	end

	local AmmoPercent = self.Ammo / math.max(self.Capacity,1)

	self:CreateAmmo(ArgsTable[4], ArgsTable[5], ArgsTable[6], ArgsTable[7], ArgsTable[8], ArgsTable[9], ArgsTable[10], ArgsTable[11], ArgsTable[12], ArgsTable[13], ArgsTable[14], ArgsTable[15], ArgsTable[16], ArgsTable[17], ArgsTable[18], ArgsTable[19])

	self.Ammo = math.floor(self.Capacity * AmmoPercent)

	self.LastMass = 1 -- force update of mass
	self:UpdateMass()

	return true, msg

end

function ENT:UpdateOverlayText()

	local roundType = self.BulletData.Type

	if not next( self.BulletData or {} ) then  return end

	local text = ""

	if self.BulletData.Type == "Refill" then

		text = " - " .. roundType .. " - "

		if self.SupplyingTo and not next(self.SupplyingTo) then
			text = text .. "\nSupplying " .. #self.SupplyingTo .. " Ammo Crates"
		end

	else
		if self.BulletData.Tracer and self.BulletData.Tracer > 0 then
			roundType = roundType .. "-T"
		end

		text = roundType .. " - " .. self.Ammo .. " / " .. self.Capacity

		local RoundData = ACE.RoundTypes[ self.BulletData.Type ]

		if RoundData and RoundData.cratetxt then
			text = text .. "\n" .. RoundData.cratetxt( self.BulletData, self )
		end

		if self.IsScalable then
			local x = math.Round(self.Dimensions.x, 1) / 10
			local y = math.Round(self.Dimensions.y, 1) / 10
			local z = math.Round(self.Dimensions.z, 1) / 10

			local dims = x .. "x" .. y .. "x" .. z
			text = text .. "\n\n Size: " .. dims
		end

		if self.IsTwoPiece then
			text = text .. "\n\nUses 2 piece ammo\n30% reload penalty"
		end
	end

	if not self.Legal then
		text = text .. "\n\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACE.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )

end

do

	--List of ids which no longer stay on ACE. Useful to replace them with the closest counterparts
	local BackComp = {
		["20mmHRAC"]        = "20mmRAC",
		["30mmHRAC"]        = "30mmRAC",
		["105mmSB"]         = "100mmSBC",
		["120mmSB"]         = "120mmSBC",
		["140mmSB"]         = "140mmSBC",
		["170mmSB"]         = "170mmSBC",
		["70mmFFARDAGR"]    = "70mmFFAR",
		["9M113 ASM"]       = "9M133 ASM",
		["9M311"]           = "9M311 SAM",
		["SIMBAD-RC SAM"]   = "Mistral SAM"
	}

	--List of munitions no longer stay on ACE
	local AmmoComp = {
		["APDSS"]		= "APDS",
		["APFSDSS"]		= "APFSDS"
	}

	function ENT:CreateAmmo(_, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10 , Data11 , Data12 , Data13 , Data14 , Data15)

		if not ACE_CheckGun( Data1 ) then
			Data1 = BackComp[Data1] or "100mmC"
		end
		if not ACE_CheckRound( Data2 ) then
			Data2 = AmmoComp[ Data2 ] or "AP"
		end

		--For some reason, removing this will also break several things with missile code. bad
		self.RoundId            = Data1
		self.RoundType          = Data2							-- Type of round, IE AP, HE, HEAT ...
		self.RoundPropellant    = Data3					or 0	-- length of propellant
		self.RoundProjectile    = Data4					or 0	-- length of the projectile
		self.RoundData5         = Data5					or 0
		self.RoundData6         = Data6					or 0
		self.RoundData7         = Data7					or 0
		self.RoundData8         = Data8					or 0
		self.RoundData9         = Data9					or 0
		self.RoundData10        = tonumber(Data10)		or 0 -- Tracer. For some reason, both Data10 and Data are sent as strings. Needs to review this.
		self.RoundData11        = tonumber(Data11)		or 0 -- Two Piece check
		self.RoundData12        = Data12				or 0
		self.RoundData13        = Data13				or 0
		self.RoundData14        = Data14				or 0
		self.RoundData15        = Data15				or 0


		local PlayerData        = {}	--what a mess
		PlayerData.Id           = self.RoundId
		PlayerData.Type         = self.RoundType
		PlayerData.PropLength   = self.RoundPropellant
		PlayerData.ProjLength   = self.RoundProjectile
		PlayerData.Data5        = self.RoundData5
		PlayerData.Data6        = self.RoundData6
		PlayerData.Data7        = self.RoundData7
		PlayerData.Data8        = self.RoundData8
		PlayerData.Data9        = self.RoundData9
		PlayerData.Tracer       = self.RoundData10
		PlayerData.TwoPiece     = self.RoundData11
		PlayerData.Data12       = self.RoundData12
		PlayerData.Data13       = self.RoundData13
		PlayerData.Data14       = self.RoundData14
		PlayerData.Data15       = self.RoundData15

		self.ConvertData    = ACE.RoundTypes[self.RoundType].convert
		self.BulletData     = self:ConvertData( PlayerData )

		self:BuildAmmoCapacity()

	end

	local Floor = math.floor
	local MaxValue = math.max
	local toInch = 2.54		--Number used for cm -> inche conversion

	function ENT:BuildAmmoCapacity()

		local AmmoGunData = GunTable[self.BulletData.Id]
		local Vol		= Floor(self:GetPhysicsObject():GetVolume())
		local WireName	= "No data"
		local Capacity
		local AmmoMaxMass

		--ammo capacity start code
		if self.BulletData.Type == "Refill" then

			Capacity = 99999999 --can't use math huge because weight sets to 1
			AmmoMaxMass = Vol

			WireName = "ACE Universal Supply Crate"

		else

			self.IsTwoPiece = false

			--Getting entity's dimensions
			local Dimensions = self.Dimensions

			local GunId = AmmoGunData.gunclass
			local WeaponType = GunClasses[GunId].type

			local width
			local shellLength

			if WeaponType == "missile" then

				width = AmmoGunData.modeldiameter or (AmmoGunData.caliber / ACE.AmmoLengthMul / toInch)
				shellLength = AmmoGunData.length / ACE.AmmoLengthMul / toInch

			else

				width = AmmoGunData.caliber / ACE.AmmoWidthMul / toInch
				shellLength = ((self.BulletData.PropLength or 0) + (self.BulletData.ProjLength or 0)) / ACE.AmmoLengthMul / toInch

			end

			-- Calculate the capacity based on the dimensions of the entity and the dimensions of the ammo
			local cap1 = Floor(Dimensions.x / shellLength) * Floor(Dimensions.y / width) * Floor(Dimensions.z / width)
			local cap2 = Floor(Dimensions.y / shellLength) * Floor(Dimensions.x / width) * Floor(Dimensions.z / width)
			local cap3 = Floor(Dimensions.z / shellLength) * Floor(Dimensions.x / width) * Floor(Dimensions.y / width)

			--Split the shell in 2, leave the other piece next to it.
			local piececap1 = Floor(Dimensions.x / (shellLength / 2)) * Floor(Dimensions.y / (width * 2)) * Floor(Dimensions.z / width)
			local piececap2 = Floor(Dimensions.y / (shellLength / 2)) * Floor(Dimensions.x / (width * 2)) * Floor(Dimensions.z / width)
			local piececap3 = Floor(Dimensions.z / (shellLength / 2)) * Floor(Dimensions.x / (width * 2)) * Floor(Dimensions.y / width)

			local FCap	= MaxValue(cap1,cap2,cap3)
			local FpieceCap = MaxValue(piececap1,piececap2,piececap3)

			--Why would you need the 2 piece for rounds below 50mm? Unless you want legos there....
			--Missiles & bombs are excluded from using this method...
			if AmmoGunData.caliber >= 5 and WeaponType ~= "missile" and FpieceCap > FCap and self.BulletData.TwoPiece > 0 then
				FCap = FpieceCap
				self.IsTwoPiece = true
			end

			Capacity	= FCap
			AmmoMaxMass = ( (self.BulletData.ProjMass + self.BulletData.PropMass) * Capacity ) or 1

			debugoverlay.Box(self:GetPos() + Vector(0, 0, 50), -Vector(shellLength / 2, width / 2, width / 2), Vector(shellLength / 2, width / 2, width / 2), 20, Color(255, 0, 0, 100))
			debugoverlay.Text(self:GetPos() + Vector(0,0,50), "Bullet Dimensions", 20)
			debugoverlay.Text(self:GetPos() + Vector(0,0,15), "Mass per Round: " .. (self.BulletData.ProjMass + self.BulletData.PropMass) .. "kgs", 20 )
			debugoverlay.Text(self:GetPos() + Vector(0,0,10), "Total Ammo Mass: " .. self.AmmoMassMax .. "kgs", 20 )

			WireName = AmmoGunData.name .. " Ammo"

		-- end capacity calculations
		end

		self.AmmoMassMax = AmmoMaxMass
		self.Capacity	= Capacity
		self.Volume	= Vol --Used by the missile reload bonus
		self.Caliber	= AmmoGunData.caliber or 1
		self.RoFMul	= self.IsTwoPiece and 0.3 or 0						--30% ROF penalty for 2 piece

		self:SetNWString( "Ammo", self.Ammo )
		self:SetNWString( "WireName", WireName )

		self.NetworkData = ACE.RoundTypes[self.BulletData.Type].network
		self:NetworkData( self.BulletData )

		Wire_TriggerOutput( self, "Capacity", self.Capacity )
		self:UpdateOverlayText()

	end

end

function ENT:UpdateMass()

	self.Mass = self.EmptyMass + math.Round( self.AmmoMassMax * (self.Ammo / math.max(self.Capacity,1)) )

	--reduce superflous engine calls, update crate mass every 5 kgs change or every 10s-15s
	if math.abs((self.LastMass or 0) - self.Mass) > 5 or ACE.CurTime > self.NextMassUpdate then

		self.LastMass	= self.Mass
		self.NextMassUpdate = ACE.CurTime + math.Rand(10,15)

		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then

			phys:SetMass( self.Mass )

		end
	end

end

function ENT:GetInaccuracy()
	--local SpreadScale = ACE.SpreadScale
	local inaccuracy = 0
	local Gun = GunTable[self.RoundId]

	if Gun then
		inaccuracy = (GunClasses[Gun.gunclass] or {spread = 0}).spread
	end

	local coneAng = inaccuracy * ACE.GunInaccuracyScale
	return coneAng
end

function ENT:TriggerInput( iname, value )

	if (iname == "Active") then
		if value > 0 then
			self.Active = true

			if self.Legal then
				self.Load = true
				self:FirstLoad()
			end
		else
			self.Active = false
			self.Load = false
		end
	end

end

function ENT:FirstLoad()

	for Key in pairs(self.Master) do
		local Gun = self.Master[Key]
		if IsValid(Gun) and Gun.FirstLoad and Gun.BulletData.Type == "Empty" and Gun.Legal then
			Gun:LoadAmmo(false, false)
		end
	end

end

function ENT:Think()

	if not self.BulletData then return false end

	if ACE.CurTime > self.NextLegalCheck then

		self.Legal, self.LegalIssues = ACE_CheckLegal(self, self.Model, math.min(math.Round(self.EmptyMass,2),50000), nil, true, true)
		self.NextLegalCheck = ACE.Legal.NextCheck(self.legal)
		self:UpdateOverlayText()

		if not self.Legal then
			self.Load = false
		else
			--if legal, go back to the action
			if self.Active then self.Load = true end
		end

	end

	if self.BulletData.Type == "Refill" then
		self:UpdateOverlayText()
	else

		self:UpdateMass()

		if self.Ammo ~= self.AmmoLast or not self.Legal then
			self:UpdateOverlayText()
			self.AmmoLast = self.Ammo
		end
	end

	local color = self:GetColor()
	self:SetNWVector("TracerColour", Vector( color.r, color.g, color.b ) )

	local cvarGrav = GetConVar("sv_gravity")
	local vec = Vector(0,0,cvarGrav:GetInt() * -1)

	self:SetNWVector("Accel", vec)

	self:NextThink( CurTime() +  self.Interval )

	-- cookoff handling
	if self.Damaged then

		--Unlink any gun from this crate
		for Key in pairs(self.Master) do
			local Gun = self.Master[Key]
			if IsValid(Gun) then
				Gun:Unlink( self )
			end
		end

		local CrateType = self.BulletData.Type or "Refill"

		--If that is a refill, remove it
		if CrateType == "Refill" then

			self:Remove()

		-- immediately detonate if there's 1 or 0 shells
		elseif self.Ammo <= 1 or self.Damaged < CurTime() then

			ACE_ScaledExplosion( self ) -- going to let empty crates harmlessly poot still, as an audio cue it died

		else

			if math.Rand(0,150) > self.BulletData.RoundVolume ^ 0.5 and math.Rand(0,1) < self.Ammo / math.max(self.Capacity,1) and ACE.RoundTypes[CrateType] then

				self:EmitSound( "ambient/explosions/explode_4.wav", 350, math.max(255 - self.BulletData.PropMass * 100,60)  )
				self.BulletCookSpeed	= self.BulletCookSpeed or ACE_MuzzleVelocity( self.BulletData.PropMass, self.BulletData.ProjMass / 2, self.Caliber )

				self.BulletData.Pos = self:LocalToWorld(self:OBBCenter() + VectorRand() * (self:OBBMaxs() - self:OBBMins()) / 2)
				self.BulletData.Flight  = (VectorRand()):GetNormalized() * self.BulletCookSpeed * 39.37 + self:GetVelocity()

				self.BulletData.Owner	= self.BulletData.Owner or self.Inflictor or ACE.GetEntityOwner(self)
				self.BulletData.Gun	= self.BulletData.Gun	or self
				self.BulletData.Crate	= self.BulletData.Crate or self:EntIndex()

				self.CreateShell		= ACE.RoundTypes[CrateType].create
				self:CreateShell( self.BulletData )

				self.Ammo = self.Ammo - 1

			end

			self:NextThink( CurTime() + self.ExplosionInterval + self.BulletData.RoundVolume ^ 0.5 / 100 )

		end

	-- Completely new, fresh, genius, beautiful, flawless refill system.
	elseif self.BulletData.Type == "Refill" and self.Load then

		for crate, _ in pairs( ACE.AmmoCrates ) do

			if crate.BulletData.Type ~= "Refill" then

				local distsqrt = self:GetPos():DistToSqr( crate:GetPos() )

				if distsqrt < ACE.RefillDistance ^ 2 and crate.Capacity > crate.Ammo then

					self.SupplyingTo = self.SupplyingTo or {}

					if not table.HasValue( self.SupplyingTo, crate:EntIndex() ) then

						table.insert(self.SupplyingTo, crate:EntIndex())
						self:RefillEffect( crate )

					end

					local Supply = math.ceil((1 / ((crate.BulletData.ProjMass + crate.BulletData.PropMass) * 5000)) * self:GetPhysicsObject():GetMass() ^ 1.2)
					local Transfert = math.min(Supply, crate.Capacity - crate.Ammo)
					crate.Ammo	= crate.Ammo + Transfert

					crate.Supplied = true
					crate.Entity:EmitSound( "weapons/shotgun/shotgun_reload" .. math.random(1,3) .. ".wav", 350, 100, 0.30 )

				end
			end
		end
	end

	-- checks to stop supply
	if self.SupplyingTo then
		for k, EntID in pairs( self.SupplyingTo ) do
			local Ammo = ents.GetByIndex(EntID)
			if not IsValid( Ammo ) then
				table.remove(self.SupplyingTo, k)
				self:StopRefillEffect( EntID )
			else
				local dist = self:GetPos():Distance(Ammo:GetPos())
				-- If ammo crate is out of refill max distance or is full or our refill crate is damaged or just in-active then stop refiliing it.
				if (dist > ACE.RefillDistance) or (Ammo.Capacity <= Ammo.Ammo) or self.Damaged or not self.Load or not Ammo.Legal then
					table.remove(self.SupplyingTo, k)
					self:StopRefillEffect( EntID )
				end
			end
		end
	end

	Wire_TriggerOutput(self, "Munitions", self.Ammo)
	return true

end

util.AddNetworkString("ACE_RefillEffect")
function ENT:RefillEffect( Target )
	net.Start("ACE_RefillEffect")
		net.WriteUInt( self:EntIndex(), 14 )
		net.WriteUInt( Target:EntIndex(), 14 )
	net.Broadcast()
end

util.AddNetworkString("ACE_StopRefillEffect")
function ENT:StopRefillEffect( TargetID )
	net.Start("ACE_StopRefillEffect")
		net.WriteUInt( self:EntIndex(), 14 )
		net.WriteUInt( TargetID, 14 )
	net.Broadcast()
end

-- Legacy to new scalable entity workaround
-- So it looks like the advanced duplicator 2 forces a setpos reset based on the legacy crate. breaking the offset position during the paste.
-- So lets order it to setpos reset to the offset we have put for the conversion.
function ENT:OnDuplicated(EntTable)

	local LegacyPos = self.LegacyPosInject
	if isvector(LegacyPos) then

		EntTable.Pos = LegacyPos

		local DupeInfo = EntTable.BuildDupeInfo
		if DupeInfo then
			DupeInfo.PosReset = LegacyPos
		end
	end
	BaseClass.OnDuplicated(self, EntTable)
end

function ENT:OnRemove()

	for Key in pairs(self.Master) do
		if self.Master[Key] and self.Master[Key]:IsValid() then
			self.Master[Key]:Unlink( self )
			self.Ammo = 0
		end
	end
end