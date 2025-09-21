
ACF = ACF or {}
ACE = ACE or {}
ACEM = ACEM or {} -- temporal as its expected to be merged with the ACE table.
---------------------------------- Version ----------------------------------

ACE.Version           = 1000		-- ACE current version
ACE.CurrentVersion    = 0			-- just defining a variable, do not change
ACE.Year              = 2024		-- Current Year

---------------------------------- Legacy Version ----------------------------------

ACF.Version           = ACE.Version	-- Since some addons still use this variable

---------------------------------- Global DataTables ----------------------------------

ACE.Weapons           = {}
ACE.Classes           = {}
ACE.RoundTypes        = {}
ACE.IdRounds          = {}	--Lookup tables so i can get rounds classes from clientside with just an integer
ACE.AmmoBlacklist     = {}
ACE.ArmorMaterials    = {}
ACE.GSounds           = {}
ACE.MuzzleFlashes 	  = {}
ACE.Missiles = {} -- Current flying missiles
ACE.Guidance = {} -- Guidances

---------------------------------- Legacy Global DataTables ----------------------------------

ACF.Weapons           = {}
ACF.Classes           = {}
ACF.RoundTypes        = {}
ACF.IdRounds          = {}	--Lookup tables so i can get rounds classes from clientside with just an integer
ACF.AmmoBlacklist     = {}

---------------------------------- Useless/Ignore ----------------------------------
ACEM.FlareBurnMultiplier        = 0.5
ACEM.FlareDistractMultiplier    = 1 / 35

---------------------------------- General ----------------------------------

ACE.GunfireEnabled              = true

ACE.SpreadScale                 = 16					-- The maximum amount that damage can decrease a gun's accuracy.  Default 4x
ACE.GunInaccuracyScale          = 1						-- A multiplier for gun accuracy.
ACE.GunInaccuracyBias           = 2						-- Higher numbers make shots more likely to be inaccurate.  Choose between 0.5 to 4. Default is 2 (unbiased).

---------------------------------- Debris ----------------------------------

ACE.DebrisIgniteChance          = 0.25
ACE.DebrisScale                 = 20					-- Ignore debris that is less than this bounding radius.
ACE.DebrisChance                = 0.5
ACE.DebrisLifeTime              = 60

---------------------------------- Fuel & fuel Tank config ----------------------------------

ACE.LiIonED                     = 0.27					-- li-ion energy density: kw hours / liter --BEFORE to balance: 0.458
ACE.CuIToLiter                  = 0.0163871				-- cubic inches to liters

ACE.TorqueBoost                 = 1.25					-- torque multiplier from using fuel
ACE.DriverTorqueBoost           = 1.25					-- torque multiplier from having a driver
ACE.FuelRate                    = 10					-- multiplier for fuel usage, 1.0 is approx real world
ACE.ElecRate                    = 2						-- multiplier for electrics								--BEFORE to balance: 0.458
ACE.TankVolumeMul               = 1						-- multiplier for fuel tank capacity, 1.0 is approx real world

---------------------------------- Ammo Crate config ----------------------------------

ACE.CrateMaximumSize            = 250
ACE.CrateMinimumSize            = 5

ACE.RefillDistance              = 400					-- Distance in which ammo crate starts refilling.
ACE.RefillSpeed                 = 250					-- (ACE.RefillSpeed / RoundMass) / Distance

---------------------------------- Explosive config ----------------------------------

ACE.BoomMult                    = 3.5					-- How much more do ammocrates/fueltanks blow up, useful since crates detonate all at once now.

ACE.HEPower                     = 8000					-- HE Filler power per KG in KJ
ACE.HEDensity                   = 1.65					-- HE Filler density (That's TNT density)
ACE.HEFrag                      = 1500					-- Mean fragment number for equal weight TNT and casing
ACE.HEBlastPen                  = 0.4					-- Blast penetration exponent based of HE power
ACE.HEFeatherExp                = 0.5					-- exponent applied to HE dist/maxdist feathering, <1 will increasingly bias toward max damage until sharp falloff at outer edge of range
ACE.HEATMVScale                 = 0.75					-- Filler KE to HEAT slug KE conversion expotential
ACE.HEATMVScaleTan              = 0.75					-- Filler KE to HEAT slug KE conversion expotential
ACE.HEATMulAmmo                 = 30					-- HEAT slug damage multiplier; 13.2x roughly equal to AP damage
ACE.HEATMulFuel                 = 4						-- needs less multiplier, much less health than ammo
ACE.HEATMulEngine               = 10					-- likewise
ACE.HEATPenLayerMul             = 0.95					-- HEAT base energy multiplier
ACE.HEATAirGapFactor            = 0.15					-- % velocity loss for every meter traveled. 0.2x means HEAT loses 20% of its energy every 2m traveled. 1m is about typical for the sideskirt spaced armor of most tanks.
ACE.HEATBoomConvert             = 1 / 3					-- percentage of filler that creates HE damage at detonation
ACE.HEATPlungingReduction       = 4						-- Multiplier for the penarea of HEAT shells. 2x is a 50% reduction in penetration, 4x 25% and so on.

ACE.ScaledHEMax                 = 50
ACE.ScaledEntsMax               = 5

---------------------------------- Ballistic config ----------------------------------

ACE.Bullet                = {} 							-- When ACF is loaded, this table holds bullets
ACE.CurBulletIndex        = 0							-- used to track where to insert bullets
ACE.BulletIndexLimit      = 5000						-- The maximum number of bullets in flight at any one time TODO: fix the typo
ACE.SkyboxGraceZone       = 100							-- grace zone for the high angle fire
ACE.SkyboxMinCaliber      = 5

ACE.TraceFilter = {		-- entities that cause issue with acf and should be not be processed at all

	prop_vehicle_crane       = true,
	prop_dynamic             = true,
	npc_strider              = true,
	worldspawn               = true, --The worldspawn in infinite maps is fake. Since the IsWorld function will not do something to avoid this case, that i will put it here.
}

ACE.DragDiv               = 80							-- Drag fudge factor
ACE.VelScale              = 1							-- Scale factor for the shell velocities in the game world
ACE.PBase                 = 1050						-- 1KG of propellant produces this much KE at the muzzle, in kj
ACE.PScale                = 1							-- Gun Propellant power expotential
ACE.MVScale               = 0.5							-- Propellant to MV convertion expotential
ACE.PDensity              = 1.6							-- Gun propellant density (Real powders go from 0.7 to 1.6, i'm using higher densities to simulate case bottlenecking)
ACE.PhysMaxVel            = 8000


ACE.NormalizationFactor   = 0.15						-- at 0.1(10%) a round hitting a 70 degree plate will act as if its hitting a 63 degree plate, this only applies to capped and LRP ammunition.

---------------------------------- Misc & other ----------------------------------

ACE.LargeCaliber        = 10 --Gun caliber in CM to be considered a large caliber gun, 10cm = 100mm

ACE.APDamageMult        = 2						-- AP Damage Multipler			-1.1
ACE.APCDamageMult       = 1.5					-- APC Damage Multipler		-1.1
ACE.APBCDamageMult      = 1.5					-- APBC Damage Multipler		-1.05
ACE.APCBCDamageMult     = 1.0					-- APCBC Damage Multipler		-1.05
ACE.APHEDamageMult      = 1.5					-- APHE Damage Multipler
ACE.APDSDamageMult      = 1.5					-- APDS Damage Multipler
ACE.HVAPDamageMult      = 1.65					-- HVAP/APCR Damage Multipler
ACE.FLDamageMult        = 1.4					-- FL Damage Multipler
ACE.HEATDamageMult      = 2						-- HEAT Damage Multipler
ACE.HEDamageMult        = 2						-- HE Damage Multipler
ACE.HESHDamageMult      = 1.2					-- HESH Damage Multipler
ACE.HPDamageMult        = 8						-- HP Damage Multipler

ACE.Threshold           = 264.7					-- Health Divisor (don't forget to update cvar function down below)
ACE.PartialPenPenalty   = 5						-- Exponent for the damage penalty for partial penetration
ACE.PenAreaMod          = 0.85
ACE.KinFudgeFactor      = 2.1					-- True kinetic would be 2, over that it's speed biaised, below it's mass biaised
ACE.KEtoRHA             = 0.25					-- Empirical conversion from (kinetic energy in KJ)/(Area in Cm2) to RHA penetration
ACE.GroundtoRHA         = 0.15					-- How much mm of steel is a mm of ground worth (Real soil is about 0.15)
ACE.KEtoSpall           = 1
ACE.AmmoMod             = 2.6					-- Ammo modifier. 1 is 1x the amount of ammo
ACE.AmmoLengthMul       = 1
ACE.AmmoWidthMul        = 1
ACE.ArmorMod            = 1
ACE.SlopeEffectFactor   = 1.1					-- Sloped armor effectiveness: armor / cos(angle) ^ factor
ACE.Spalling            = 1
ACE.SpallMult           = 1


--Math in globals????

--UNLESS YOU WANT SPALL TO FLY BACKWARDS, BE ABSOLUTELY SURE TO MAKE SURE THIS VECTOR LENGTH IS LESS THAN 1
--The vector controls the spread pattern. The multiplier adjusts the tightness of the spread cone. ABSOLUTELY DO NOT MAKE THE MULTIPLIER MORE THAN 1. A Vector of 1,1,0.5. Results in half the vertical spall spread
ACE.SpallingDistribution = Vector(1,1,0.5):GetNormalized() * 0.45


---------------------------------- Particle colors  ----------------------------------

ACE.DustMaterialColor = {
	Concrete   = Color(100,100,100,150),
	Dirt       = Color(117,101,70,150),
	Sand       = Color(200,180,116,150),
	Glass      = Color(255,255,255,50),
}

--------------------------------------------------------------------------------------

--Convert old numeric IDs to the new string IDs
--Used to reconvert old material ids
ACE.BackCompMat = {
	[0] = "RHA",
	[1] = "CHA",
	[2] = "Cer",
	[3] = "Rub",
	[4] = "ERA",
	[5] = "Alum",
	[6] = "Texto"
}

---------------------------------- Serverside Convars ----------------------------------
if SERVER then

	--Sbox Limits
	CreateConVar("sbox_max_ace_gun", 24)					-- Gun limit
	CreateConVar("sbox_max_acf_rapidgun", 4)				-- Guns like RACs, MGs, and ACs
	CreateConVar("sbox_max_acf_largegun", 2)				-- Guns with a caliber above 100mm
	CreateConVar("sbox_max_acf_smokelauncher", 20)			-- smoke launcher limit
	CreateConVar("sbox_max_ace_ammo", 50)					-- ammo limit
	CreateConVar("sbox_max_acf_misc", 50)					-- misc ents limit
	CreateConVar("sbox_max_ace_rack", 12)					-- Racks limit

	CreateConVar("acf_mines_max", 10)						-- The mine limit
	CreateConVar("acf_meshvalue", 1)
	CreateConVar("acf_restrictinfo", 1)				-- 0=any, 1=owned

	-- Cvars for legality checking
	CreateConVar( "acf_legalcheck", 1 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_model", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_notsolid", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_mass", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_material", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_inertia", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_makesphere", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_visclip", 0 , FCVAR_ARCHIVE)
	CreateConVar( "acf_legal_ignore_parent", 0 , FCVAR_ARCHIVE)

	-- Prop Protection system
	CreateConVar( "acf_enable_dp", 0 , FCVAR_ARCHIVE )	-- Enable the inbuilt damage protection system.

	-- Cvars for recoil/he push
	CreateConVar("acf_hepush", 1, FCVAR_ARCHIVE)
	CreateConVar("acf_recoilpush", 1, FCVAR_ARCHIVE)

	-- New healthmod/armormod/ammomod cvars
	CreateConVar("acf_healthmod", 1, FCVAR_ARCHIVE)
	CreateConVar("acf_armormod", 1, FCVAR_ARCHIVE)
	CreateConVar("ace_ammomod", 1, FCVAR_ARCHIVE)
	CreateConVar("ace_gunfire", 1, FCVAR_ARCHIVE)

	-- Debris
	CreateConVar("acf_debris_lifetime", 30, FCVAR_ARCHIVE)
	CreateConVar("acf_debris_children", 1, FCVAR_ARCHIVE)

	-- Spalling
	CreateConVar("acf_spalling", 1, FCVAR_ARCHIVE)
	CreateConVar("acf_spalling_multipler", 1, FCVAR_ARCHIVE)

	-- Scaled Explosions
	CreateConVar("acf_explosions_scaled_he_max", 100, FCVAR_ARCHIVE)
	CreateConVar("acf_explosions_scaled_ents_max", 5, FCVAR_ARCHIVE)

	--Smoke
	CreateConVar("acf_wind", 600, FCVAR_ARCHIVE)


	local function ConvarCallback(CVar, _, New)

		if CVar == "acf_healthmod" then
			ACE.Threshold = 264.7 / math.max(New, 0.01)
		elseif CVar == "acf_armormod" then
			ACE.ArmorMod = 1 * math.max(New, 0)
		elseif CVar == "ace_ammomod" then
			ACE.AmmoMod = 1 * math.max(New, 0.01)
		elseif CVar == "acf_spalling" then
			ACE.Spalling = math.floor(math.Clamp(New, 0, 1))
		elseif CVar == "acf_spalling_multipler" then
			ACE.SpallMult = math.Clamp(New, 1, 5)
		elseif CVar == "ace_gunfire" then
			ACE.GunfireEnabled = tobool( New )
		elseif CVar == "acf_debris_lifetime" then
			ACE.DebrisLifeTime = math.max( New,0)
		elseif CVar == "acf_debris_children" then
			ACE.DebrisChance = math.Clamp(New,0,1)
		elseif CVar == "acf_explosions_scaled_he_max" then
			ACE.ScaledHEMax = math.max(New,50)
		elseif CVar == "acf_explosions_scaled_ents_max" then
			ACE.ScaledEntsMax = math.max(New,1)
		elseif CVar == "acf_enable_dp" then
			if ACE_SendDPStatus then
				ACE_SendDPStatus()
			end
		end
	end

	cvars.AddChangeCallback("acf_healthmod", ConvarCallback)
	cvars.AddChangeCallback("acf_armormod", ConvarCallback)
	cvars.AddChangeCallback("ace_ammomod", ConvarCallback)
	cvars.AddChangeCallback("acf_spalling", ConvarCallback)
	cvars.AddChangeCallback("acf_spalling_multipler", ConvarCallback)
	cvars.AddChangeCallback("ace_gunfire", ConvarCallback)
	cvars.AddChangeCallback("acf_debris_lifetime", ConvarCallback)
	cvars.AddChangeCallback("acf_debris_children", ConvarCallback)
	cvars.AddChangeCallback("acf_explosions_scaled_he_max", ConvarCallback)
	cvars.AddChangeCallback("acf_explosions_scaled_ents_max", ConvarCallback)
	cvars.AddChangeCallback("acf_enable_dp", ConvarCallback)


elseif CLIENT then
---------------------------------- Clientside Convars ----------------------------------

	CreateClientConVar( "acf_enable_lighting", 0, true ) --Should missiles emit light while their motors are burning?  Looks nice but hits framerate. Set to 1 to enable, set to 0 to disable, set to another number to set minimum light-size.
	CreateClientConVar( "acf_sens_irons", 0.5, true, false, "Reduce mouse sensitivity by this amount when zoomed in with iron sights on ACE SWEPs.", 0.01, 1)
	CreateClientConVar( "acf_sens_scopes", 0.2, true, false, "Reduce mouse sensitivity by this amount when zoomed in with scopes on ACE SWEPs.", 0.01, 1)
	CreateClientConVar( "acf_tinnitus", 1, true, false, "Allows the ear tinnitus effect to be applied when an explosive was detonated too close to your position, improving the inmersion during combat.", 0, 1 )
	CreateClientConVar( "acf_sound_volume", 100, true, false, "Adjusts the volume of explosions and gunshots.", 0, 100 )

end


do
	-- The name of the folder for the loader. Relative to lua folder
	local mainfolder_name = "acf"

	local function HasPrefix( File, Prefix)
		return string.lower(string.Left(File , 3)) == Prefix
	end

	-- Find recursively every file, through of subfolders.
	local function GetAllFiles(folder, foundFiles, Dircount)
		foundFiles = foundFiles or {}

		local files, directories = file.Find(folder .. "/*", "LUA")

		for _, fileName in ipairs(files) do
			table.insert(foundFiles, { File = fileName, Dir = folder .. "/" .. fileName })
		end

		for _, dirName in ipairs(directories) do
			GetAllFiles(folder .. "/" .. dirName, foundFiles, Dircount)
		end

		return foundFiles
	end

	-- Include all the found files to their respective realms
	local function IncludeAllFiles(files)

		for _, file_data in ipairs(files) do

			local fileName = file_data.File
			local dirName = file_data.Dir

			if SERVER and HasPrefix( fileName, "sv_" ) then
				include(dirName)
			elseif HasPrefix( fileName, "cl_" ) then
				if SERVER then
					AddCSLuaFile(dirName)
				else
					include(dirName)
				end
			elseif not HasPrefix( fileName, "sv_" ) then
				if SERVER then
					AddCSLuaFile(dirName)
				end

				include(dirName)
			end
		end
	end

	local function LoadAll()

		local files = GetAllFiles(mainfolder_name)

		if next(files) then
			IncludeAllFiles(files)

			if SERVER then
				print("================-[ ACE Global loader ]-===================\n")
				print("- Current version: " .. ACE.Version)
				print("- Detected " .. #files .. " files")
				print("- ACE is loaded and ready!")
				print("==========================================================")
			end
		end
	end
	LoadAll()
end