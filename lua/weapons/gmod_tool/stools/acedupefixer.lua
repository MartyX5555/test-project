TOOL.Category		= "Construction"
TOOL.Name			= "#tool.acedupefixer.name"
TOOL.Author		    = "Marty"
TOOL.Command		= nil
TOOL.ConfigName		= ""

--[[
	This tool will attempt to replace:
	- Entity classes: for example, if the entity class was changed.
	- Entity Modifiers: modifiers like those used to store armor or sounds inside of entities.
	- E2/SF functions: functions like E:acfIsAmmo() is replaced to E:aceIsAmmo.
	- Sound extensions: converts old .wav sounds to .mp3 if they were converted.

	Note:
	- Sometimes, the folder conversion can stop entirely if one of the dupes cause issues to the decoder. This is something i cannot fix from here, as thats from the advdupe2 side.
	- While the tool can do wonders, is not a 100% dupe fixer on its own. You will need to check your dupes anyways, for example, you should check e2s/systems that looks for specific entities like the ace ones. Maybe it can change.
	- The tool is EXPERIMENTAL. So please, i STRONGLY recommend you backup your dupes just in case. Any chosen dupe is COMPLETELY OVERWRITTEN by the tool. Overwritten dupes cannot be undone.
	- This tool was tested with E2s and Starfall chips using the newer compilers/datastructs. Old SF/E2 chips with legacy datastructs is NOT supported!
]]
if CLIENT then

	language.Add( "tool.acedupefixer.name", "ACE Dupe Fixer" )
	language.Add( "tool.acedupefixer.desc", "Attempts to repair old ACE dupes by replacing old entities, modifiers, and sound extensions." )
	language.Add( "tool.acedupefixer.desc2", "Note: This tool is experimental and errors could occur. The chosen file will be overwriten. Make sure to keep a backup in any case." )
	language.Add( "tool.acedupefixer.0", "To fix a dupe, choose a dupe that uses ACE from the list in the menu." )

	-- old entities to convert from.
	local ACFToACEtbl = {
		acf_gun = "ace_gun",
		acf_ammo = "ace_ammo",
		acf_engine = "ace_engine",
		acf_fueltank = "ace_fueltank",
		acf_gearbox = "ace_gearbox",
		acf_rack = "ace_rack",
		acf_missileradar = "ace_radar",
		acf_opticalcomputer = "ace_opticalcomputer",
	}
	-- old entity modifiers to convert from.
	local ACFToACEMods = {
		acf_replacesound = "ace_sounddata",
		acfsettings = "ace_armordata",
	}

	-- menu icons
	local foldericon = "icon16/folder.png"
	local dupeicon = "icon16/brick.png"


	-- file management values
	local FolderDir = "advdupe2" -- The folder where we will retrieve the dupes. This should be where the advdupe2 dupes are located.
	local isfolder = nil
	local current_filename = nil
	local current_filepath = nil
	local istreefinished = nil

	local function InitCoroutine(func, ondeadfunc, interval)
		local co = coroutine.create(func)

		local nextcorotime = 0
		hook.Add("Think", "ACEDupeFixer_CoroutineControl", function()
			local curtime = CurTime()
			if curtime > nextcorotime and coroutine.status(co) == "suspended" then
				coroutine.resume(co)
				if interval then
					nextcorotime = curtime + (interval / 1000)
				end
			elseif coroutine.status(co) == "dead" then
				hook.Remove("Think", "ACEDupeFixer_CoroutineControl")
				if ondeadfunc then
					ondeadfunc()
				end
			end
		end)
	end

	-- Filter unreadable dupes from the folder.
	local function IsValidDupeFile(dupefile)
		if not string.EndsWith(dupefile, ".txt") then return false end -- wtf dont put jpg files here.
		local noformat = string.sub( dupefile, 1, #dupefile - 4 )
		local found = string.find(noformat, "%.") -- invalid dupe formats, like having extra points, cause problems to the decoder.
		if found then return false end
		return true
	end

	------ Dupe list Construction ------
	local iterator = 0
	local nodes = 100 -- Created nodes per tick.
	local function addFilesRecursively(parent, directory)
		local files, folders = file.Find(directory .. "/*", "DATA")

		-- Recorre las subcarpetas y llama a la función de nuevo
		if folders then
			for _, folderName in pairs(folders) do
				local folderNode = parent:AddNode(folderName, foldericon)

				function folderNode:DoClick()
					isfolder = true
				end

				function folderNode:DoRightClick()
					local Menu = DermaMenu()

					-- Simple option, but we're going to add an icon
					local SelectBtn = Menu:AddOption( "Select this folder and its contents", function()
						isfolder = true
						current_filepath = directory .. "/" .. folderName
						current_filename = string.Explode(".", folderName)[1]
						--print("folder chosen!")

						-- Manually calling the function here.
						local root = self:GetRoot()
						root:OnFolderSelected()
					end )
					SelectBtn:SetIcon( "icon16/folder.png" )	-- Icons are in materials/icon16 folder

					-- Open the menu
					Menu:Open()
				end
				addFilesRecursively(folderNode, directory .. "/" .. folderName)

				if iterator > nodes then
					iterator = 0
					coroutine.yield()
				else
					iterator = iterator + 1
				end

			end
		end

		-- Añade archivos del directorio actual
		if files then
			for _, fileName in pairs(files) do
				if IsValidDupeFile(fileName) then
					local dupeNode = parent:AddNode(fileName, dupeicon)
					function dupeNode:DoClick()
						isfolder = nil
						current_filepath = directory .. "/" .. fileName
						current_filename = string.Explode(".", fileName)[1]
					end
					if iterator > nodes then
						iterator = 0
						coroutine.yield()
					else
						iterator = iterator + 1
					end
				end
			end
		end
	end

	local function PopulateTreeFromFolder(dtree)
		dtree:Clear()
		local MainNode = dtree:AddNode("Advanced Duplicator 2", folderName)
		MainNode:SetExpanded( true )
		InitCoroutine(function()
			iterator = 0
			istreefinished = nil
			addFilesRecursively(MainNode, FolderDir)
		end, function()
			istreefinished = true
		end)
	end

	local function FixQuotedSound(quote, path)
		if string.lower(string.sub(path, -4)) == ".wav" then
			local fixed = ACE.GetFixedSound(path)
			if fixed ~= path then
				return quote .. fixed .. quote
			end
		end
	end

	local function FixCodeSounds(code, allowSingleQuotes)
		if not isstring(code) then return code, false end
		local changed = false

		local newCode = string.gsub(code, '(["])([^"\r\n]+)(["])', function(q1, path, _)
			local rep = FixQuotedSound(q1, path)
			if rep then
				changed = true
				return rep
			end
		end)

		if allowSingleQuotes then
			newCode = string.gsub(newCode, "(['])([^'\r\n]+)(['])", function(q1, path, _)
				local rep = FixQuotedSound(q1, path)
				if rep then
					changed = true
					return rep
				end
			end)
		end

		return newCode, changed
	end

	-- Applies prefix and sound extensions fixes to E2.
	local E2Pattern = "(:?)acf(%w*%b())"

	local function FixE2(src)
		if not isstring(src) then return src end
		if string.find(src, E2Pattern) then
			src = string.gsub(src, E2Pattern, "%1ace%2")
		end
		local fixedSrc = FixCodeSounds(src, false)
		return fixedSrc
	end

	-- Applies prefix and sound extensions fixes to Starfall.
	-- I hope to find a unified pattern.
	local SFPattern1 = "([^%w_])acf(%u)" -- acfExample()
	local SFPattern2 = "([^%w_])acf([%.:])" -- acf.example() / E:acfexample()

	local function FixSF(src)
		if not isstring(src) then return src, false end
		local changed = false

		if string.find(src, SFPattern1) then
			src = string.gsub(src, SFPattern1, "%1ace%2")
			changed = true
		end
		if string.find(src, SFPattern2) then
			src = string.gsub(src, SFPattern2, "%1ace%2")
			changed = true
		end

		local fixedSrc, soundChanged = FixCodeSounds(src, true)
		return fixedSrc, (changed or soundChanged)
	end

	------ Dupe Conversion functions ------
	local function ConvertDupe(dupepath)
		if not dupepath then return end

		local read = file.Read(dupepath)
		local success, dupe, info, _ = AdvDupe2.Decode(read)

		if success then
			for _, enttable in pairs(dupe.Entities) do

				-- Replaces any old ACE related class with a new one.
				if ACFToACEtbl[enttable.Class] then
					enttable.Class = ACFToACEtbl[enttable.Class]
				end

				-- Replace any entity modifier with a new one.
				if enttable.EntityMods then
					local newEntityMods = {}
					for tablename, moddata in pairs(enttable.EntityMods) do
						if ACFToACEMods[tablename] then
							newEntityMods[ACFToACEMods[tablename]] = moddata
						else
							newEntityMods[tablename] = moddata
						end
					end

					-- Fix sounds in ace_sounddata if present
					if newEntityMods.ace_sounddata and isstring(newEntityMods.ace_sounddata[1]) then
						newEntityMods.ace_sounddata[1] = ACE.GetFixedSound(newEntityMods.ace_sounddata[1])
					end

					enttable.EntityMods = newEntityMods
				end

				-- Fix direct entity sound properties if present
				if isstring(enttable.Sound) then
					enttable.Sound = ACE.GetFixedSound(enttable.Sound)
				end
				if isstring(enttable.SoundPath) then
					enttable.SoundPath = ACE.GetFixedSound(enttable.SoundPath)
				end

				-- Replace old acf e2 functions with the ace functions, and fix sounds.
				-- We are also fixing any possible included e2 library connected to this code.
				if enttable.Class == "gmod_wire_expression2" then

					if enttable["_original"] then
						enttable["_original"] = FixE2(enttable["_original"])
					end

					if istable(enttable["inc_files"]) then
						for incPath, incCode in pairs(enttable["inc_files"]) do
							enttable["inc_files"][incPath] = FixE2(incCode)
						end
					end
				end

				-- Replace old acf sf functions with the ace functions and fix sounds.
				-- SF chips are compressed in this stage. So we need to decompress to edit it. Then Compress it back once edited.
				if SF and enttable.Class == "starfall_processor" and enttable.EntityMods and enttable.EntityMods.SFDupeInfo then
					local sfInfo = enttable.EntityMods.SFDupeInfo
					if sfInfo.starfall and sfInfo.starfall.files then
						local Data = sfInfo.starfall.files
						if isstring(Data) then
							local files = SF.DecompressFiles(Data) -- contains all of the SF codes. Index being the file name, content is code.
							local changed = false
							for fname, sfcode in pairs(files) do
								local patchedcode, edited = FixSF(sfcode)
								if edited then
									files[fname] = patchedcode
									changed = true
								end
							end
							if changed then
								sfInfo.starfall.files = SF.CompressFiles(files)
							end
						end
					end
				end
			end
			AdvDupe2.Encode(dupe, info, function(data)
				local writeFile = file.Open(dupepath, "wb", "DATA")
				if not writeFile then print("File could not be written! (" .. dupepath .. ")") return end
				writeFile:Write(data)
				writeFile:Close()
			end)
		else
			print("Dupe could not be decoded!")
		end
	end

	local function ConvertFolderContents(directory)
		local files, folders = file.Find(directory .. "/*", "DATA")

		if folders then
			for _, folderName in pairs(folders) do
				local folder_to_go = directory .. "/" .. folderName
				ConvertFolderContents(folder_to_go)
			end
		end

		-- Añade archivos del directorio actual
		if files then
			for _, fileName in pairs(files) do
				if IsValidDupeFile(fileName) then

					local file_to_process = directory .. "/" .. fileName

					print("Applying patch to the file:", file_to_process)
					ConvertDupe(file_to_process)
					coroutine.yield()
				end
			end
		end
	end

	------ Main menu ------

	local lastclick = 0
	local canconvert = false
	function TOOL.BuildCPanel(panel)

		if not AdvDupe2 then
			panel:Help( "Unable to use this tool. You need Advanced Duplicator 2 to be installed on the server.")
			if game.IsDedicated() then
				panel:Help("If unintended, please inform this error to the server administrator.")
			end
			return
		end

		panel:Help( "#tool.acedupefixer.desc")
		panel:Help( "#tool.acedupefixer.desc2")

		local dupelist = vgui.Create("DTree", panel)
		panel:AddItem(dupelist)
		dupelist:SetTall(300)
		dupelist:Dock(TOP)
		PopulateTreeFromFolder(dupelist)

		local refreshbtn = panel:Button("Refresh list")
		refreshbtn:SetTooltip( "Refresh the list" )
		panel:AddItem(refreshbtn)
		refreshbtn:Dock(TOP)
		function refreshbtn:DoClick()
			PopulateTreeFromFolder(dupelist)
		end

		local DupeName = panel:Help("")

		function dupelist:OnNodeSelected( _ )
			if isfolder then return end
			canconvert = false

			local ctime = CurTime()
			local difftime = ctime - lastclick
			if difftime < 0.25 then -- check for double click
				DupeName:SetText("Selected file: " .. current_filename)
				canconvert = true
			end
			lastclick = CurTime()
		end
		function dupelist:OnFolderSelected()
			DupeName:SetText("Selected folder: " .. current_filename)
			canconvert = true
		end

		local convertbtn = panel:Button("Apply Conversion")
		panel:AddItem(convertbtn)
		convertbtn:Dock(TOP)
		convertbtn:SetTooltip( "Apply the fixes to the selected dupe." )
		function convertbtn:DoClick()
			if OnDupeConversion then print("You are already patching dupes. Please wait until it finishes.") return end
			if not istreefinished then print("list must be finished before processing.") return end
			if not canconvert then print("Double click to validate selection first.") return end
			if isfolder then
				print("Applying patch to all the dupes inside of the folder:", current_filepath)
				InitCoroutine(function()
					OnDupeConversion = true
					ConvertFolderContents(current_filepath)
				end,
				function()
					OnDupeConversion = false
					print("All the dupes were processed!")
				end, 25)
			else
				print("Applying patch to the single file:", current_filepath)
				ConvertDupe(current_filepath)
			end
		end
	end
end