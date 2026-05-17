
CreateClientConVar("ace_dupes_deploy", "1", true, false, "If enabled, allow dupes to be created on the advdupe2 folder. If you dont want them, disable this and delete the dupes on the advdupe2 folder, ACE will ignore them and wont remount them again. If you want to remount them, just delete this convar and restart your session or use the ace_dupes_remount command.")

local function CanDeploy()
	if GetConVar("ace_dupes_deploy"):GetInt() == 0 then return false end
	return true
end

-- dev note: If theres a reason to move the container, ensure to let the addon know here.
local folderPath = "materials/ace/vehicles/"
local dupeformat = ".vmt"

	-- Explanation:
	-- If the dupespawned file doesnt exist, that means all the dupes must be loaded.
	-- If the dupespawned file exists, we only update the dupes that exists on the advdupe2 folder, and ignore those that the user could remove. Completely abort the process if the user has removed all the dupes, since that means they dont want them at all.
function ACE_Dupes_Refresh()

	if not CanDeploy() then
		return true, "Dupes deployment is disabled." -- We return true here because we dont want to show an error message if the user has intentionally disabled the deployment, since that is not an error.
	end

	if not AdvDupe2 then
		return false, "Advanced Duplicator 2 is not installed. Dupes won't be loaded."
	end

	if not file.Exists(folderPath, "GAME") then
		return false, "Unable to load the dupes. Please verify the addon installation. If this persists, report this to the developers."
	end

	local files = file.Find(folderPath .. "acedupe_*" .. dupeformat, "GAME")
	if not next(files) then
		return false, "No dupes were found inside of the vehicles folder. Please verify the addon installation. If this persists, report this to the developers."
	end

	local Status = 0 -- 0 = No changes, 1 = Deployed, 2 = Updated
	for _, txtfile in ipairs(files) do

		local file_content        = file.Read(folderPath .. txtfile, "GAME") or ""
		local file_naming         = string.Explode("_", txtfile)
		local file_name_concat    = table.concat( file_naming, " ", 3) -- Parses the file name
		local file_name           = string.Replace( file_name_concat, dupeformat, "" )

		local file_directory   = "advdupe2/ace " .. file_naming[2]
		local final_path = file_directory .. "/" .. file_name .. ".txt"

		-- Recreate the file
		if not file.Exists(final_path, "DATA") then
			if not file.Exists(file_directory, "DATA") then
				file.CreateDir(file_directory)
			end
			file.Write(final_path, file_content)

			if Status < 1 then
				Status = 1
			end

		-- If the file already exists, we check if the content is different, if it is, we update it, if not, we do nothing.
		else
			local cfile_content = file.Read(final_path, "DATA") or ""
			if util.SHA256(cfile_content) ~= util.SHA256(file_content) then
				file.Write(final_path, file_content)
				if Status < 2 then
					Status = 2
				end
			end
		end
	end

	local message = Status == 0 and "No changes were made to the dupes." or (Status == 1 and "Dupes deployed successfully." or "Dupes updated successfully.")
	return true, message
end

timer.Simple(1,function()
	local success, message = ACE_Dupes_Refresh()
	print("[ACE | " .. (success and "INFO" or "ERROR") .. "]- " .. message)
end)

-- In case the user wants them back in case of deletion
concommand.Remove("ace_dupes_remount") -- We remove it first to avoid duplicates in case this file is reloaded for some reason.
concommand.Add( "ace_dupes_remount", function()

	file.Delete("ace/ace_dupespawn.txt")
	local success, message = ACE_Dupes_Refresh()
	print("[ACE | " .. (success and "INFO" or "ERROR") .. "]- " .. message)

	notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 7)
	surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
end )
