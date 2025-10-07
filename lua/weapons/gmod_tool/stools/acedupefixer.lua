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

	Note:
	- Sometimes, the folder conversion can stop entirely if one of the dupes cause issues to the decoder. This is something i cannot fix from here, as thats from the advdupe2 side.
	- While the tool can do wonders, is not a 100% dupe fixer on its own. You will need to check your dupes anyways, for example, you should check e2s/systems that looks for specific entities like the ace ones. Maybe it can change.
	- The tool is EXPERIMENTAL. So please, i STRONGLY recommend you backup your dupes just in case. Any chosen dupe is COMPLETELY OVERWRITTEN by the tool. Overwritten dupes cannot be undone.
]]
if CLIENT then

	language.Add( "tool.acedupefixer.name", "ACE Dupe Fixer" )
	language.Add( "tool.acedupefixer.desc", "Attempts to repair old ACE dupes by replacing the old entities by their new counterparts." )
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

	local E2Pattern = "(:?)acf(%w*%b())"

	-- I hope to find a unified pattern.
	local SFPattern1 = "([^%w_])acf(%u)", "%1ace%2" -- acf.example()
	local SFPattern2 = "([^%w_])acf([%.:])", "%1ace%2" -- E:acfexample()

	------ Dupe Conversion functions ------
	local function ConvertDupe(dupepath)
		if not dupepath then return end

		local read = file.Read(dupepath)
		local success, dupe, info, _ = AdvDupe2.Decode(read)

		if success then
			for _, enttable in pairs(dupe.Entities) do

				-- Replaces any old ACF related class with a new one.
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
					enttable.EntityMods = newEntityMods
				end

				-- Replace old acf e2 functions with the ace functions.
				if enttable.Class == "gmod_wire_expression2" and enttable["_original"] and string.find(enttable["_original"], E2Pattern) then
					enttable["_original"] = string.gsub(enttable["_original"], E2Pattern, "%1ace%2")
				end

				-- Replace old acf sf functions with the ace functions
				-- SF chips are compressed in this stage. So we need to decompress to edit it. Then Compress it back once edited
				if SF and enttable.Class == "starfall_processor" then
					local info = enttable.EntityMods.SFDupeInfo
					local Dataname = info.starfall.mainfile
					local Data = info.starfall.files
					if isstring(Data) then
						local files = SF.DecompressFiles(Data)
						local sfcode = files[Dataname]
						if string.find(sfcode, SFPattern1) or string.find(sfcode, SFPattern2) then -- I hope to find a unified pattern
							sfcode = string.gsub(sfcode, SFPattern1)
							sfcode = string.gsub(sfcode, SFPattern2)
							files[Dataname] = sfcode
							info.starfall.files = SF.CompressFiles(files)
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
				panel:Help("If unintended, ")
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