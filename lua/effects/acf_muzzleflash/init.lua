

--[[---------------------------------------------------------
	Initializes the effect. The data is a table of data
	which was passed from the server.
]]-----------------------------------------------------------
function EFFECT:Init( data )

	local Gun = data:GetEntity()
	if not IsValid(Gun) then return end

	local Propellant   = data:GetScale()
	local ReloadTime   = data:GetMagnitude()

	local Sound        = Gun:GetNWString( "Sound", "" )
	local SoundPitch   = Gun:GetNWInt( "SoundPitch", 100 )
	local Class        = Gun:GetNWString( "Class", "C" )
	local Caliber      = Gun:GetNWInt( "Caliber", 1 ) * 10
	local MuzzleEffect = Gun:GetNWString( "Muzzleflash", "50cal_muzzleflash_noscale" )

	--This tends to fail
	local Classes = ACF.Classes
	local ClassData	= Classes.GunClass[Class]
	local Attachment = "muzzle"

	if ClassData and Propellant > 0 then

		local longbarrel = ClassData.longbarrel

		if longbarrel and Gun:GetBodygroup( longbarrel.index ) == longbarrel.submodel then
			Attachment = longbarrel.newpos
		end

		if not IsValidSound( Sound ) then
			Sound = ClassData.sound
		end

		ACE_SGunFire( Gun, Sound, SoundPitch, Propellant )

		local Muzzle = Gun:GetAttachment( Gun:LookupAttachment(Attachment)) or { Pos = Gun:GetPos(), Ang = Gun:GetAngles() }

		-- Gets the appropiated muzzleflash according to the defined in the gun class
		local MuzzleTable = ACE.MuzzleFlashes
		local MuzzleFunction = MuzzleTable[MuzzleEffect].muzzlefunc
		--local MuzzleCallBack = MuzzleTable["Default"].muzzlefunc
		if MuzzleFunction then
			MuzzleFunction( self )
		--else
			--MuzzleCallBack( self )
		end

		--ParticleEffect( MuzzleEffect , Muzzle.Pos, Muzzle.Ang, Gun )

		if Gun:WaterLevel() ~= 3 and not ClassData.nolights then
			ACF_RenderLight(Gun:EntIndex(), Caliber * 75, Color(255, 128, 48), Muzzle.Pos + Muzzle.Ang:Forward() * (Caliber / 5))
		end

		if Gun.Animate then
			Gun:Animate( Class, ReloadTime, false )
		end
	else
		if Gun.Animate then
			Gun:Animate( Class, ReloadTime, true )
		end
	end

end


--[[---------------------------------------------------------
	THINK
-----------------------------------------------------------]]
function EFFECT:Think( )
	return false
end

--[[---------------------------------------------------------
	Draw the effect
-----------------------------------------------------------]]
function EFFECT:Render()
end


