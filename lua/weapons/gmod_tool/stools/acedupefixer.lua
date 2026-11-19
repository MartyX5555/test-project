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
	language.Add( "tool.acedupefixer.desc", "Attempts to repair old ACE dupes by replacing obsolete entities, modifiers, and sound extensions." )
	language.Add( "tool.acedupefixer.desc2", "This tool is experimental and unintended problems can occur. The affected dupes will be overwritten. You are advised to do a backup before proceeding." )
	language.Add( "tool.acedupefixer.0", "To fix a dupe, choose a dupe that uses ACE from the list in the menu." )

	-- Client ConVar for overwrite warning safety prompt
	local cvarSkipWarn = CreateClientConVar("ace_dupefixer_skip_warning","0",true,false,"If enabled (1), skips the overwrite confirmation popup when fixing dupes in ACE Dupe Fixer.",0, 1)

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

	local istreefinished = false
	local IsConversionRunning = false

	local function NotifyUser(msg, notifyType, duration)
		notification.AddLegacy(msg, notifyType or NOTIFY_GENERIC, duration or 4)
		if notifyType == NOTIFY_ERROR or notifyType == NOTIFY_HINT then
			surface.PlaySound("buttons/button10.wav")
		end
	end

	local function InitCoroutine(taskName, func, ondeadfunc, interval)
		local hookId = "ACEDupeFixer_" .. (taskName or "Task")
		local co = coroutine.create(func)

		local nextcorotime = 0
		hook.Add("Think", hookId, function()
			local curtime = CurTime()
			if curtime > nextcorotime and coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					print("[ACE DupeFixer] Coroutine error (" .. (taskName or "Task") .. "): " .. tostring(err))
					hook.Remove("Think", hookId)
					if ondeadfunc then
						ondeadfunc()
					end
					return
				end
				if interval then
					nextcorotime = curtime + (interval / 1000)
				end
			elseif coroutine.status(co) == "dead" then
				hook.Remove("Think", hookId)
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

	local SelectedItems = {} -- Stores the selected items in the tree. Key is the path, value is a table with info about the item.

	local function ClearSelection()
		SelectedItems = {}
	end

	local function IsPathSelected(path)
		return SelectedItems[path] ~= nil
	end

	-- Zero-allocation parent check (traverses parent node references instead of string.Explode in Paint)
	local function HasSelectedAncestorNode(node)
		if not IsValid(node) then return false end
		local cur = node.ParentFolderNode
		while IsValid(cur) do
			if cur.ItemPath and SelectedItems[cur.ItemPath] then
				return true
			end
			cur = cur.ParentFolderNode
		end
		return false
	end

	local function ToggleItemSelection(node, name, path, isFolder)
		if SelectedItems[path] then
			SelectedItems[path] = nil
		else
			SelectedItems[path] = {
				path = path,
				isFolder = isFolder,
				name = name,
				node = node,
			}
		end
	end

	local NodeMarkMargin = 2
	local CheckTexture = Material("icon16/accept.png")
	local CrossIcon = Material("icon16/cross.png")

	local SelectedDirColor = Color(113,255,113)
	local SelectedInherColor = Color(201,253,201)

	local function SetupNodeInteractions(node, name, path, isFolder, parentFolderNode, RefreshUI)
		node.ItemPath = path
		node.IsFolder = isFolder
		node.ItemName = name
		node.ParentFolderNode = parentFolderNode

		function node:Paint(w, _)
			local IsDirectSelect = IsPathSelected(path)
			local IsInheritSelect = not IsDirectSelect and HasSelectedAncestorNode(self)

			if IsDirectSelect then
				draw.RoundedBox( 3, NodeMarkMargin, 0, w - NodeMarkMargin * 2, 17, SelectedDirColor)
			elseif IsInheritSelect then
				surface.SetDrawColor(SelectedInherColor.r,SelectedInherColor.g,SelectedInherColor.b)
				surface.DrawRect( NodeMarkMargin + 1, 0, w - 1 - NodeMarkMargin * 2, 17 )
			end

			-- Draw pre-cached checkbox indicator [✓] / [•]
			local iconX = w - 24
			if IsDirectSelect then
				surface.SetMaterial(CheckTexture)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(iconX, 1, 16, 16)
			elseif IsInheritSelect then
				draw.SimpleText("•", "DermaDefaultBold", iconX + 7, 8, SelectedDirColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

		end

		-- Both files and folders toggle selection on click/double-click
		-- Folder expansion/collapse is exclusively handled by clicking the [+] / [-] button or context menu
		function node:DoClick()
			local ctime = CurTime()
			local difftime = ctime - (self.LastClickCurTime or 0)
			if difftime < 0.3 then -- check for double click
				ToggleItemSelection(node, name, path, isFolder)
				if RefreshUI then RefreshUI() end
			end
			self.LastClickCurTime = CurTime()
			return true -- Prevent GMod DTree from expanding/collapsing folder on click
		end
	end

	------ Dupe list Construction ------
	local iterator = 0
	local nodes = 100 -- Created nodes per tick.
	local function addFilesRecursively(parent, directory, RefreshUI, onItemAdded, onYield)
		local files, folders = file.Find(directory .. "/*", "DATA")

		-- Recorre las subcarpetas y llama a la función de nuevo
		if folders then
			for _, folderName in pairs(folders) do
				local folderNode = parent:AddNode(folderName, foldericon)
				local subPath = directory .. "/" .. folderName

				SetupNodeInteractions(folderNode, folderName, subPath, true, parent, RefreshUI)
				if onItemAdded then onItemAdded() end
				addFilesRecursively(folderNode, directory .. "/" .. folderName, RefreshUI, onItemAdded, onYield)

				if iterator > nodes then
					iterator = 0
					if onYield then onYield() end
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
					local subPath = directory .. "/" .. fileName

					SetupNodeInteractions(dupeNode, fileName, subPath, nil, parent, RefreshUI)
					if onItemAdded then onItemAdded() end

					if iterator > nodes then
						iterator = 0
						if onYield then onYield() end
						coroutine.yield()
					else
						iterator = iterator + 1
					end
				end
			end
		end
	end

	local mainfolder_name = "Advanced Duplicator 2"
	local function PopulateTreeFromFolder(dtree, RefreshUI, progressBar)
		if IsConversionRunning then
			NotifyUser("A dupe conversion is on the way! Wait until it finishes.", NOTIFY_ERROR)
			return
		end

		dtree:Clear()
		local MainNode = dtree:AddNode(mainfolder_name, foldericon)
		MainNode:SetExpanded( true )
		SetupNodeInteractions(MainNode, mainfolder_name, FolderDir, true, dtree, RefreshUI)

		if IsValid(progressBar) then
			progressBar:StartTask("Loading dupe list...", "Found: 0 items", 1, true)
		end

		local foundCount = 0
		InitCoroutine("TreeLoader", function()
			iterator = 0
			istreefinished = false
			addFilesRecursively(MainNode, FolderDir, RefreshUI, function()
				foundCount = foundCount + 1
			end, function()
				if IsValid(progressBar) then
					progressBar:UpdateProgress(foundCount, nil, "Found: " .. foundCount .. " items")
				end
			end)
		end, function()
			istreefinished = true
			if IsValid(progressBar) then
				progressBar:FinishTask()
			end
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

		local newCode = string.gsub(code, '(["\163])([^"\163\r\n\128]+)(["\163])', function(q1, path, _)
			local rep = FixQuotedSound(q1, path)
			if rep then
				changed = true
				return rep
			end
		end)

		if allowSingleQuotes then
			newCode = string.gsub(newCode, "(['])([^'\r\n\128]+)(['])", function(q1, path, _)
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
	local E2Pattern = "(:?)acf(%w*%s*%()"

	local function FixE2(src)
		if not isstring(src) then return src end
		local funcedited, soundedited
		if string.find(src, E2Pattern) then
			src = string.gsub(src, E2Pattern, "%1ace%2")
			funcedited = true
		end
		local fixedSrc, soundedited = FixCodeSounds(src, false)
		return fixedSrc, (funcedited or soundedited)
	end

	-- Applies prefix and sound extensions fixes to Starfall.
	-- I hope to find a unified pattern.
	local SFPattern1 = "%f[%w_]acf(%u)" -- acfExample()
	local SFPattern2 = "%f[%w_]acf([%.:])" -- acf.example() / E:acfexample()

	local function FixSF(src)
		if not isstring(src) then return src, false end
		local changed = false

		if string.find(src, SFPattern1) then
			src = string.gsub(src, SFPattern1, "ace%1")
			changed = true
		end
		if string.find(src, SFPattern2) then
			src = string.gsub(src, SFPattern2, "ace%1")
			changed = true
		end

		local fixedSrc, soundChanged = FixCodeSounds(src, true)
		return fixedSrc, (changed or soundChanged)
	end

	--Number codes:
	--  0: No Changes
	--  1: Modified
	-- -1: An error occurred.
	------ Dupe Conversion functions ------
	local function ConvertDupe(dupepath)
		if not dupepath then return -1 end -- non existant dupepath

		local read = file.Read(dupepath)
		if not read or #read == 0 then return -1 end -- invalid file or empty

		local success, dupe, info, _ = AdvDupe2.Decode(read)
		if not success then return -1 end -- unreadable format for the AdvDupe2's Decode

		local IsModified = false
		for _, enttable in pairs(dupe.Entities) do

			-- Replaces any old ACE related class with a new one.
			if ACFToACEtbl[enttable.Class] then
				enttable.Class = ACFToACEtbl[enttable.Class]
				IsModified = true
			end

			-- Replace any entity modifier with a new one.
			if enttable.EntityMods then
				local newEntityMods = {}
				for tablename, moddata in pairs(enttable.EntityMods) do
					if ACFToACEMods[tablename] then
						newEntityMods[ACFToACEMods[tablename]] = moddata
						IsModified = true
					else
						newEntityMods[tablename] = moddata
					end
				end

				-- Fix sounds in ace_sounddata if present
				if newEntityMods.ace_sounddata and isstring(newEntityMods.ace_sounddata[1]) then
					local oldSound = newEntityMods.ace_sounddata[1]
					local fixedSound = ACE.GetFixedSound(oldSound)
					if fixedSound ~= oldSound then
						newEntityMods.ace_sounddata[1] = fixedSound
						IsModified = true
					end
				end

				enttable.EntityMods = newEntityMods
			end

			-- Replace old acf e2 functions with the ace functions, and fix sounds.
			-- We are also fixing any possible included e2 library connected to this code.
			if enttable.Class == "gmod_wire_expression2" then

				local MainEdited, SubEdited

				if enttable["_original"] then
					enttable["_original"], MainEdited = FixE2(enttable["_original"])
				end

				if istable(enttable["inc_files"]) then
					local localEdited
					for incPath, incCode in pairs(enttable["inc_files"]) do
						enttable["inc_files"][incPath], localEdited = FixE2(incCode)
						if not SubEdited and localEdited then
							SubEdited = localEdited
						end
					end
				end

				if MainEdited or SubEdited then
					IsModified = true
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
							IsModified = true
						end
					end
				end
			end
		end
		-- We will only encode if the dupe was effectively modified!
		if IsModified then
			local encodeDone = false
			local writeSuccess = false
			AdvDupe2.Encode(dupe, info, function(data)
				local writeFile = file.Open(dupepath, "wb", "DATA")
				if not writeFile then -- for some odd reason, the modified dupe could not be recompiled again. How?
					return -1
				end
				writeFile:Write(data)
				writeFile:Close()
				writeSuccess = true
				encodeDone = true
			end)

			-- Wait for the asynchronous encoder callback before returning
			while not encodeDone do
				coroutine.yield()
			end

			if writeSuccess then
				return 1
			else
				return -1
			end

		else
			return 0
		end
	end

	local function CollectTargetFiles()
		local queue = {}
		local visited = {}

		local function traverse(dir)
			local files, folders = file.Find(dir .. "/*", "DATA")
			if files then
				for _, f in ipairs(files) do
					local full = dir .. "/" .. f
					if IsValidDupeFile(f, true, full) and not visited[full] then
						visited[full] = true
						table.insert(queue, full)
					end
				end
			end
			if folders then
				for _, sub in ipairs(folders) do
					traverse(dir .. "/" .. sub)
				end
			end
		end

		for path, info in pairs(SelectedItems) do
			if info.isFolder then
				traverse(path)
			else
				if IsValidDupeFile(string.GetFileFromFilename(path), true, path) and not visited[path] then
					visited[path] = true
					table.insert(queue, path)
				end
			end
		end

		return queue
	end

	local function ClampFileName(name, maxLen)
		if #name > maxLen then
			return string.sub(name, 1, maxLen - 3) .. "..."
		end
		return name
	end

	local MaxDupes = 25
	local function RunConversion(progressBar, OnFinish)
		if IsConversionRunning then
			NotifyUser("A dupe conversion is on the way! Wait until it finishes.", NOTIFY_ERROR)
			return
		end
		if not istreefinished then
			NotifyUser("Wait until the dupe list finishes loading.", NOTIFY_HINT)
			return
		end

		local targetFiles = CollectTargetFiles()
		local total = #targetFiles
		if total == 0 then
			NotifyUser("No valid dupe files found in current selection.", NOTIFY_ERROR)
			return
		end

		IsConversionRunning = true

		local stats = {
			total = total,
			modified = 0,
			unchanged = 0,
			failed = 0,
		}
		local faileddupes = {}

		if IsValid(progressBar) then
			progressBar:StartTask("Converting...", "Modified: 0 | Unchanged: 0 | Failed: 0", total, false)
		end

		InitCoroutine("Convert", function()
			for idx, dupePath in ipairs(targetFiles) do
				local rawFileName = string.GetFileFromFilename(dupePath)
				local fileName = ClampFileName(rawFileName, 22)
				if IsValid(progressBar) then
					local line1 = "Converting: " .. fileName .. " (" .. idx .. " / " .. total .. ")"
					local line2 = "Modified: " .. stats.modified .. " | Unchanged: " .. stats.unchanged .. " | Failed: " .. stats.failed
					progressBar:UpdateProgress(idx - 1, line1, line2)
				end

				local status = ConvertDupe(dupePath)

				if status == 1 then
					stats.modified = stats.modified + 1
				elseif status == 0 then
					stats.unchanged = stats.unchanged + 1
				else
					stats.failed = stats.failed + 1
					table.insert(faileddupes, { fileName = rawFileName, dupePath = dupePath })
				end

				if IsValid(progressBar) then
					local line1 = "Converting: " .. fileName .. " (" .. idx .. " / " .. total .. ")"
					local line2 = "Modified: " .. stats.modified .. " | Unchanged: " .. stats.unchanged .. " | Failed: " .. stats.failed
					progressBar:UpdateProgress(idx, line1, line2)
				end
				coroutine.yield()
			end
		end,
		function()
			IsConversionRunning = false
			ClearSelection()
			if IsValid(progressBar) then
				progressBar:FinishTask()
			end

			if stats.failed > 0 then
				notification.AddLegacy( "Some Dupes could not be fixed. Check the console for details.", NOTIFY_GENERIC, 7 )

				MsgC(Color(255, 220, 100), "======================================================================\n")
				MsgC(Color(255, 220, 100), "WARNING: " .. stats.failed .. " dupe(s) could not be worked on.\n")
				MsgC(Color(255, 220, 100), "Please verify you can actually load them from the Advanced Duplicator 2:\n\n")

				for i, entry in ipairs(faileddupes) do
					local folderPath = string.GetPathFromFilename(entry.dupePath)
					MsgC(Color(255, 220, 100), "[" .. i .. "] ", Color(255, 255, 255), entry.fileName .. "\n")
					MsgC(Color(170, 170, 170), "    -> " .. folderPath .. "\n")
				end
				MsgC(Color(255, 220, 100), "======================================================================\n")
			end


			if isfunction(OnFinish) then OnFinish(stats) end
		end, MaxDupes)
	end


	------ Main menu ------

	local ExperimentalColorBack = Color(255,0,0,25)
	local ExperimentalColorMain = Color(255,25,25)

	local function CreateWarningMessage(panel)
		local warningmessagebase = vgui.Create("DPanel", panel)
		warningmessagebase:SetTall(50)
		warningmessagebase:Dock(TOP)
		warningmessagebase:DockMargin(0,2,0,2)
		function warningmessagebase:Paint(w,h)
			surface.SetDrawColor(ExperimentalColorBack)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(ExperimentalColorMain)
			surface.DrawOutlinedRect(0, 0, w, h)
		end
		if panel.AddItem then
			panel:AddItem(warningmessagebase)
		end

		local warningmessage = vgui.Create("DLabel", warningmessagebase)
		warningmessage:SetWrap(true)
		warningmessage:SetText("#tool.acedupefixer.desc2")
		warningmessage:Dock(FILL)
		warningmessage:SetTextColor(ExperimentalColorMain)

		warningmessage:SetContentAlignment( 5 )
		warningmessage:SetTextInset( 10, 0 )

		function warningmessage:Paint(_,_)
		end
	end

	local messageWarn = "You are about to modify %s dupe files through the ACE dupefixer. Do you want to continue?"
	local frameXSize = 400
	local frameYSize = 200
	local function CreateConversionWarningPopup(executeConversion)

		local dframe = vgui.Create("DFrame")
		dframe:SetSize(frameXSize, frameYSize)
		dframe:SetTitle("Danger Zone - Please confirm")
		--dframe:DockPadding(10,6,10,6)
		dframe:Center()
		dframe:MakePopup()

		function dframe:Paint(w,h)
			-- Draws a rounded box with the color faded_black stored above.
			draw.RoundedBox(4, 0, 0, w, h, Color(30,30,30,250))
		end

		local targetFiles = CollectTargetFiles()
		local total = #targetFiles

		CreateWarningMessage(dframe)

		local warningmessage = vgui.Create("DLabel", dframe)
		warningmessage:SetTall(45)
		warningmessage:SetWrap(true)
		warningmessage:SetText(string.format(messageWarn, total))
		warningmessage:SetTextColor(color_white)
		warningmessage:Dock(TOP)

		warningmessage:SetContentAlignment( 4 )
		warningmessage:SetTextInset( 10, 0 )

		local checkPanel = vgui.Create("DPanel", dframe)
		checkPanel:Dock(TOP)
		checkPanel:DockMargin(16, 0, 16, 8)
		checkPanel:SetTall(20)
		checkPanel.Paint = function() end

		local CacheBool = cvarSkipWarn:GetBool()
		local dontAsk = vgui.Create("DCheckBoxLabel", checkPanel)
		dontAsk:Dock(FILL)
		dontAsk:SetText("Don't ask me again")
		dontAsk:SetFont("DermaDefault")
		dontAsk:SetTextColor(color_white)
		dontAsk:SetValue(CacheBool)
		function dontAsk:OnChange(val)
			CacheBool = val
		end

		local ButtonXSize = 180
		local ButtonYSize = 30
		local Spacer = 5
		local ButtonsPanel = vgui.Create("DPanel", dframe)
		ButtonsPanel:Dock(FILL)
		ButtonsPanel.Paint = function() end

		local AcceptButton = vgui.Create("DButton", ButtonsPanel)
		AcceptButton:SetSize(ButtonXSize, ButtonYSize)
		AcceptButton:SetPos(Spacer, 5)
		AcceptButton:SetText("Yes")
		function AcceptButton:DoClick()
			executeConversion()
			cvarSkipWarn:SetBool(CacheBool) -- we only want to change this convar is the skip was marked and the conversion was done once.
			dframe:Close()
		end

		local CancelButton = vgui.Create("DButton", ButtonsPanel)
		CancelButton:SetSize(ButtonXSize, ButtonYSize)
		CancelButton:SetPos(frameXSize - Spacer - 10 - ButtonXSize, 5) --10 represents the dframe default dockpadding.
		CancelButton:SetText("No")
		function CancelButton:DoClick()
			dframe:Close()
		end

	end

	local FolderIcon = Material("icon16/folder.png")
	local DupeIcon = Material("icon16/brick.png")

	-- Reusable progress bar with external top-left status lines (hidden when idle)
	local function CreateProgressBar(parent)
		local barPanel = vgui.Create("DPanel")
		barPanel:Dock(TOP)
		barPanel:SetTall(0)
		barPanel:DockMargin(0, 2, 0, 4)
		barPanel:SetVisible(false)

		barPanel.Fraction = 0
		barPanel.Line1 = ""
		barPanel.Line2 = ""
		barPanel.TotalSteps = 1
		barPanel.CurrentStep = 0
		barPanel.Indeterminate = false

		local function RelayoutParent()
			if not IsValid(parent) then return end
			if parent.InvalidateLayout then parent:InvalidateLayout(true) end
			local p1 = parent:GetParent()
			if IsValid(p1) and p1.InvalidateLayout then
				p1:InvalidateLayout(true)
				local p2 = p1:GetParent()
				if IsValid(p2) and p2.InvalidateLayout then
					p2:InvalidateLayout(true)
				end
			end
		end

		function barPanel:Paint(w, _)
			if w <= 0 then return end

			-- External top-left status lines (nothing drawn inside the bar)
			draw.SimpleText(self.Line1, "DermaDefault", 0, 0, Color(50, 50, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(self.Line2, "DermaDefault", 0, 16, Color(90, 90, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			-- Empty sleek progress bar below the status lines
			local barY = 34
			local barH = 12

			surface.SetDrawColor(225, 225, 225)
			surface.DrawRect(0, barY, w, barH)

			if self.Indeterminate then
				local segW = math.min(math.max(w * 0.3, 30), w)
				local t = math.sin(CurTime() * 4) * 0.5 + 0.5
				local segX = (w - segW) * t
				surface.SetDrawColor(70, 195, 70)
				surface.DrawRect(segX, barY, segW, barH)
			else
				local fillW = math.Clamp(w * self.Fraction, 0, w)
				if fillW > 0 then
					surface.SetDrawColor(70, 195, 70)
					surface.DrawRect(0, barY, fillW, barH)
				end
			end

			surface.SetDrawColor(100, 100, 100)
			surface.DrawOutlinedRect(0, barY, w, barH)
		end

		function barPanel:StartTask(line1, line2, totalSteps, isIndeterminate)
			self.Line1 = line1 or ""
			self.Line2 = line2 or ""
			self.TotalSteps = math.max(totalSteps or 1, 1)
			self.CurrentStep = 0
			self.Fraction = 0
			self.Indeterminate = isIndeterminate and true or false

			self:SetVisible(true)
			self:SetTall(50)

			if IsValid(self.ContainerPanel) then
				self.ContainerPanel:SetVisible(true)
				self.ContainerPanel:InvalidateLayout(true)
			end

			RelayoutParent()
		end

		function barPanel:UpdateProgress(currentStep, line1, line2)
			self.CurrentStep = currentStep or self.CurrentStep
			if not self.Indeterminate then
				self.Fraction = math.Clamp(self.CurrentStep / self.TotalSteps, 0, 1)
			end
			if line1 then self.Line1 = line1 end
			if line2 then self.Line2 = line2 end
		end

		function barPanel:HideBar()
			self.Fraction = 0
			self.Indeterminate = false
			self:SetVisible(false)
			self:SetTall(0)
			if IsValid(self.ContainerPanel) then
				self.ContainerPanel:SetVisible(false)
			end
			RelayoutParent()
		end

		function barPanel:FinishTask()
			self:HideBar()
		end

		return barPanel
	end

	function TOOL.BuildCPanel(panel)

		if not AdvDupe2 then
			panel:Help( "Unable to use this tool. You need Advanced Duplicator 2 to be installed on the server.\n\nOnce downloaded, you will need to restart the server.")
			if game.IsDedicated() then
				panel:Help("If unintended, please inform this error to the server administrator.")
			elseif LocalPlayer():IsListenServerHost() then
				local DownloadButton = vgui.Create("DButton", panel)
				DownloadButton:Dock(TOP)
				DownloadButton:SetText("Get Advanced Duplicator 2")
				panel:AddItem(DownloadButton)
				function DownloadButton:DoClick()
					gui.OpenURL( "https://steamcommunity.com/sharedfiles/filedetails/?id=773402917" )
				end
			end
			return
		end
		panel:Help( "#tool.acedupefixer.desc")

		-- Create the warning message.
		CreateWarningMessage(panel)

		-- Create the whole DTree
		local dupelistbase = vgui.Create("DPanel", panel)
		dupelistbase:SetTall(300)
		panel:AddItem(dupelistbase)

		function dupelistbase:Paint(_, _)
		end

		local dupelistitlebox = vgui.Create("DPanel",dupelistbase)
		dupelistitlebox:SetTall(18)
		dupelistitlebox:Dock(TOP)
		function dupelistitlebox:Paint(w, h)

			draw.RoundedBox( 3, 0, 0, w, h + 5, Color(100,100,100))

			surface.SetFont( "DebugFixedSmall" )
			surface.SetTextColor( 255, 255, 255)
			surface.SetTextPos( 10, 2 )
			surface.DrawText( "Choose the dupes here." )
		end

		local Space = 4
		local dupelistdtreebase = vgui.Create("DPanel",dupelistbase)
		dupelistdtreebase:Dock(FILL)
		dupelistdtreebase:DockPadding( Space, Space, Space, Space )
		function dupelistdtreebase:Paint(w, h)
			surface.SetDrawColor(Color(240,240,240))
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(Color(100,100,100))
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		local dupelist = vgui.Create("DTree", dupelistdtreebase)
		dupelist:Dock(FILL)
		function dupelist:Paint(_, _)
		end

		-- Create the whole DTree
		local selectlistbase = vgui.Create("DPanel", panel)
		selectlistbase:SetTall(150)
		panel:AddItem(selectlistbase)

		local selectlistitlebox = vgui.Create("DPanel",selectlistbase)
		selectlistitlebox:SetTall(18)
		selectlistitlebox:Dock(TOP)
		function selectlistitlebox:Paint(w, h)

			draw.RoundedBox( 3, 0, 0, w, h + 5, Color(100,100,100))

			surface.SetFont( "DebugFixedSmall" )
			surface.SetTextColor( 255, 255, 255)
			surface.SetTextPos( 10, 2 )
			surface.DrawText( "Marked Selection" )
		end

		local selectlist = vgui.Create("DPanel",selectlistbase)
		selectlist:Dock(FILL)
		selectlist:DockPadding(1, 1, 1, 1)
		function selectlist:Paint(w, h)
			surface.SetDrawColor(Color(100,100,100))
			surface.DrawRect(0, 0, w, h)
		end
		local scrolllist = vgui.Create("DScrollPanel",selectlist)
		scrolllist:Dock(FILL)
		function scrolllist:Paint(w, h)
			surface.SetDrawColor(Color(240,240,240))
			surface.DrawRect(0, 0, w, h)

			if not next(SelectedItems) then
				draw.SimpleText( "To Select a dupe, Double click on the folder/file.", "DermaDefault", w / 2, h / 2, Color(90, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end
		end
		local infoLabel
		local progressBar

		local function RefreshUI()
			if not IsValid(scrolllist) then return end
			scrolllist:Clear()

			for path, info in SortedPairs(SelectedItems) do

				local row = scrolllist:Add("DButton")
				row:Dock(TOP)
				row:SetTall(22)
				row:DockMargin(Space, 1, Space, 0)
				row:SetText("")
				row:SetTooltip(info.path)
				function row:Paint(w, h)
					local bg = self:IsHovered() and Color(160,255,160) or SelectedDirColor
					draw.RoundedBox(3, 0, 0, w, h, bg)

					-- Static Icons
					surface.SetDrawColor(255, 255, 255, 255)

					local CheckiconX = 10
					surface.SetMaterial(CheckTexture)
					surface.DrawTexturedRect(CheckiconX, 3, 16, 16)

					local rowIcon = info.isFolder and FolderIcon or DupeIcon
					surface.SetMaterial(rowIcon)
					surface.DrawTexturedRect(CheckiconX + 30, 3, 16, 16)

					local maxlength = 28
					local clampedtext = string.sub( info.path, 1, maxlength ) .. (#info.path > maxlength and "..." or "")
					surface.SetFont( "DermaDefault" )
					surface.SetTextColor( 90, 90, 90)
					surface.SetTextPos( CheckiconX + 50, 4 )
					surface.DrawText( clampedtext )

				end
				-- Navigate through the dtree to the selected node.
				function row:DoClick()

					local cur = info.node.ParentFolderNode
					while IsValid(cur) do
						if cur.SetExpanded then
							cur:SetExpanded(true)
						end
						cur = cur.ParentFolderNode
					end

					dupelist:SetSelectedItem(info.node)
					dupelist:ScrollToChild(info.node)
				end

				local removeButton = vgui.Create( "DButton", row )
				removeButton:Dock(RIGHT)
				removeButton:SetText("")
				removeButton:SetWide( row:GetTall() )			-- OPTIONAL: Use instead of SizeToContents() if you know/want to fix the size
				function removeButton:Paint(_, _)
					-- Static Icons
					local CheckiconX = 0
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(CrossIcon)
					surface.DrawTexturedRect(CheckiconX, 3, 16, 16)
				end
				function removeButton:DoClick()
					SelectedItems[path] = nil
					RefreshUI()
				end
			end

			if IsValid(infoLabel) then
				local selectedCount = #CollectTargetFiles()
				infoLabel:SetText("Selected: " .. selectedCount .. " dupe files.")
			end
		end

		-- Clear button
		local clearbtn = panel:Button("Clear Selection")
		clearbtn:SetTooltip( "Clears your current selection." )
		clearbtn:SetIcon("icon16/cancel.png")
		panel:AddItem(clearbtn)
		clearbtn:Dock(TOP)
		function clearbtn:DoClick()
			if not next(SelectedItems) then
				NotifyUser("Your Selection is already empty.", NOTIFY_HINT, 2.5)
				return
			end
			ClearSelection()
			RefreshUI()
			NotifyUser("Selection cleared.", NOTIFY_CLEANUP, 2.5)
		end

		-- Refresh button
		local refreshbtn = panel:Button("Refresh dupe list")
		refreshbtn:SetTooltip( "Performs another advanced duplicator folder lookup." )
		refreshbtn:SetIcon("icon16/arrow_refresh.png")
		panel:AddItem(refreshbtn)
		refreshbtn:Dock(TOP)
		function refreshbtn:DoClick()
			if IsConversionRunning then
				NotifyUser("A dupe conversion is on the way! Wait until it finishes.", NOTIFY_ERROR)
				return
			end
			ClearSelection()
			PopulateTreeFromFolder(dupelist, RefreshUI, progressBar)
			RefreshUI()
		end

		local function executeConversion()
			RunConversion(progressBar, function(stats)
				RefreshUI()
				if IsValid(infoLabel) and stats then
					infoLabel:SetText("Conversion Complete!\n" .. stats.modified .. " modified, " .. stats.unchanged .. " unchanged, " .. stats.failed .. " failed.")
				end
			end)
		end

		-- Convert button
		local convertbtn = panel:Button("Apply Conversion")
		panel:AddItem(convertbtn)
		convertbtn:Dock(TOP)
		convertbtn:SetTooltip( "Apply the fixes to the selected folder/files." )
		convertbtn:SetIcon("icon16/page_white_wrench.png")
		function convertbtn:DoClick()
			if IsConversionRunning then
				NotifyUser("A dupe conversion is on the way! Wait until it finishes.", NOTIFY_ERROR)
				return
			end
			if not istreefinished then
				NotifyUser("Wait until the dupe list finishes loading.", NOTIFY_HINT)
				return
			end
			if not next(SelectedItems) then
				NotifyUser("Select at least one dupe or folder first.", NOTIFY_HINT)
				return
			end
			if #CollectTargetFiles() == 0 then
				NotifyUser("No valid dupe files found in current selection.", NOTIFY_ERROR)
				return
			end
			if not cvarSkipWarn:GetBool() then
				CreateConversionWarningPopup(executeConversion)
				return
			end
			executeConversion()
		end

		-- General info label (selection count and post-conversion summary)
		infoLabel = vgui.Create("DLabel", panel)
		infoLabel:Dock(TOP)
		infoLabel:DockMargin(0, 4, 0, 2)
		infoLabel:SetTall(24)
		infoLabel:SetTextColor(Color(60, 60, 60))
		infoLabel:SetText("Selected: 0 dupe files.")
		panel:AddItem(infoLabel)

		-- Reusable progress bar (hidden until loading or converting)
		progressBar = CreateProgressBar(panel)
		panel:AddItem(progressBar)
		progressBar.ContainerPanel = progressBar:GetParent()
		progressBar:HideBar()

		PopulateTreeFromFolder(dupelist, RefreshUI, progressBar)
	end
end