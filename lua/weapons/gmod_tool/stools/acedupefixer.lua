TOOL.Category		= "Construction"
TOOL.Name			= "#tool.acedupefixer.name"
TOOL.Author		    = "Marty"
TOOL.Command		= nil
TOOL.ConfigName		= ""

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

	local function InitCoroutine(func)
		local co = coroutine.create(func)

		hook.Add("Think", "ACEDupeFixer_CoroutineControl", function()
			if coroutine.status(co) == "suspended" then
				coroutine.resume(co)
			elseif coroutine.status(co) == "dead" then
				hook.Remove("Think", "ACEDupeFixer_CoroutineControl")
			end
		end)
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
				function folderNode:DoRightClick()
					local Menu = DermaMenu()

					-- Simple option, but we're going to add an icon
					local SelectBtn = Menu:AddOption( "Select this folder and its contents", function()
						isfolder = true
						current_filepath = directory .. "/" .. folderName
						current_filename = string.Explode(".", folderName)[1]
						print("folder chosen!")

						-- Manually calling the function here.
						local root = self:GetRoot()
						root:OnNodeSelected( self )
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
				if string.EndsWith(fileName, ".txt") then
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
			addFilesRecursively(MainNode, FolderDir)
		end)
	end

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

	local iterator2 = 0
	local dupestick = 1 -- Processed dupes per tick.
	local function ConvertFolderContents(directory)
		local files, folders = file.Find(directory .. "/*", "DATA")

		if folders then
			for _, folderName in pairs(folders) do
				print("new folder found. Looking at it")
				ConvertFolderContents(directory .. "/" .. folderName)
			end
		end

		-- Añade archivos del directorio actual
		if files then
			for _, fileName in pairs(files) do
				if string.EndsWith(fileName, ".txt") then

					local file_to_process = directory .. "/" .. fileName

					print("Applying patch to the file:", file_to_process)
					ConvertDupe(file_to_process)

					if iterator2 > dupestick then
						iterator2 = 0
						coroutine.yield()
					else
						iterator2 = iterator2 + 1
					end
				end
			end
		end
	end

	------ Main menu ------

	local lastclick = 0
	local canconvert = false
	function TOOL.BuildCPanel(panel)

		panel:Help( "#tool.acedupefixer.desc")
		panel:Help( "#tool.acedupefixer.desc2")

		local dupelist = vgui.Create("DTree", panel)
		panel:AddItem(dupelist)
		dupelist:SetTall(300)
		dupelist:Dock(TOP)
		PopulateTreeFromFolder(dupelist)

		local refreshbtn = panel:Button("Refresh list")
		panel:AddItem(refreshbtn)
		refreshbtn:Dock(TOP)
		function refreshbtn:DoClick()
			PopulateTreeFromFolder(dupelist)
		end

		local DupeName = panel:Help("")

		function dupelist:OnNodeSelected( _ )

			canconvert = false

			local ctime = CurTime()
			local difftime = ctime - lastclick
			if difftime < 0.25 then -- check for double click
				DupeName:SetText("Selected file: " .. current_filename)
				canconvert = true
			elseif isfolder then
				DupeName:SetText("Selected folder: " .. current_filename)
				canconvert = true
			end
			lastclick = CurTime()
		end

		local convertbtn = panel:Button("Apply Conversion")
		panel:AddItem(convertbtn)
		convertbtn:Dock(TOP)
		function convertbtn:DoClick()
			if not canconvert then print("Double click to validate selection first.") return end
			if isfolder then
				print("Applying patch to all the dupes inside of the folder:", current_filepath)
				InitCoroutine(function()
					iterator2 = 0
					ConvertFolderContents(current_filepath)
				end)
			else
				print("Applying patch to the single file:", current_filepath)
				--ConvertDupe(current_filepath)
			end
		end
	end
end