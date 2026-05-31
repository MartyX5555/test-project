
local function checkIfDataIsMissile(data)

	local guns = ACE.Weapons.Guns
	local class = guns[data.Id]

	if not (class and class.gunclass) then
		if oldDisplayData then
			oldDisplayData(data)
		end
		return
	end

	local classes = ACE.Classes.GunClass
	class = classes[class.gunclass]

	return class.type and class.type == "missile"

end




function ACEM.ModifyRoundDisplayFuncs()

	local roundTypes = ACE.RoundTypes

	if not ACEM.RoundDisplayFuncs then

		ACEM.RoundDisplayFuncs = {}

		for k, v in pairs(roundTypes) do
			ACEM.RoundDisplayFuncs[k] = v.getDisplayData
		end

	end


	for k, v in pairs(roundTypes) do

		local oldDisplayData = ACEM.RoundDisplayFuncs[k]

		if oldDisplayData then
			v.getDisplayData = function(data)

				if not checkIfDataIsMissile(data) then
					return oldDisplayData(data)
				end

				-- NOTE: if these replacements cause side-effects somehow, move to a masking-metatable approach

				local MuzzleVel = data.MuzzleVel
				local slugMV = data.SlugMV
				local slugMV2 = data.SlugMV2

				data.MuzzleVel = 0
				data.SlugMV = (slugMV or 0) * (ACE.GetGunValue(data.Id, "penmul") or 1.2)
				data.SlugMV2 = (slugMV2 or 0) * (ACE.GetGunValue(data.Id, "penmul") or 1.2)

				local ret = oldDisplayData(data)

				data.SlugMV = slugMV
				data.SlugMV2 = slugMV2
				data.MuzzleVel = MuzzleVel

				return ret
			end
		end
	end

end




local function configConcat(tbl, sep)

	local toConcat = {}

	for k, v in pairs(tbl) do
		toConcat[#toConcat + 1] = tostring(k) .. " = " .. tostring(v)
	end

	return table.concat(toConcat, sep)

end




function ACEM.ModifyCrateTextFuncs()

	local roundTypes = ACE.RoundTypes

	if not ACEM.CrateTextFuncs then

		ACEM.CrateTextFuncs = {}

		for k, v in pairs(roundTypes) do
			ACEM.CrateTextFuncs[k] = v.cratetxt
		end

	end


	for k, v in pairs(roundTypes) do

		local oldCratetxt = ACEM.CrateTextFuncs[k]

		if oldCratetxt then
			v.cratetxt = function(data, crate)

				local origCrateTxt = oldCratetxt(data)

				if not checkIfDataIsMissile(data) then
					return origCrateTxt
				end

				local str = { origCrateTxt }

				local Type = IsValid(crate) and crate.RoundData.RoundGunClass

				local guidance  = IsValid(crate) and crate.RoundData.Guidance
				local fuse	= IsValid(crate) and crate.RoundData.Fuse

				if guidance then
					guidance = ACEM.CreateConfigurable(guidance, ACE.Guidance, bdata, "guidance")
					if guidance and guidance.Name ~= "Dumb" then
						str[#str + 1] = "\n\n"
						str[#str + 1] = guidance.Name
						str[#str + 1] = " guidance\n("
						str[#str + 1] = configConcat(guidance:GetDisplayConfig(Type), ", ")
						str[#str + 1] = ")"
					end
				end

				if fuse then
					fuse = ACEM.CreateConfigurable(fuse, ACE.Fuse, bdata, "fuses")
					if fuse then
						str[#str + 1] = "\n\n"
						str[#str + 1] = fuse.Name
						str[#str + 1] = " fuse\n("
						str[#str + 1] = configConcat(fuse:GetDisplayConfig(), ", ")
						str[#str + 1] = ")"
					end
				end

				return table.concat(str)
			end

			ACE.RoundTypes[k].cratetxt = v.cratetxt
		end
	end

end




function ACEM.ModifyRoundBaseGunpowder()

	local oldGunpowder = ACEM.ModifiedRoundBaseGunpowder and oldGunpowder or ACE.RoundBaseGunpowder


ACE.RoundBaseGunpowder = function(PlayerData, Data, ServerData, GUIData)

		PlayerData, Data, ServerData, GUIData = oldGunpowder(PlayerData, Data, ServerData, GUIData)

		Data.RoundGunClass = PlayerData.RoundGunClass

		return PlayerData, Data, ServerData, GUIData

	end


	ACEM.ModifiedRoundBaseGunpowder = true

end

timer.Simple(1, ACEM.ModifyRoundBaseGunpowder)
timer.Simple(1, ACEM.ModifyRoundDisplayFuncs)
timer.Simple(1, ACEM.ModifyCrateTextFuncs)



