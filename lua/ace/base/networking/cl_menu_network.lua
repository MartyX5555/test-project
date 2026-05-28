local ACE = ACE

do
	--[[
		The functions below are used to network data from the client to the server
		Note: I hate how networking works.
		________________________________________________________________________________________________________________________________________
		| TOOL SPAWNING NETWORK / CLIENT FUNCTIONS:
		|
		| ACE.MenuSendValue( group, name, value):
		| - Sends a value to the server, which can be retrieved with one of the functions above.
		| - You can send numbers, strings, vectors, angles and colors.
		|
		| ACE.MenuSendTableValue( group, table, name, value):
		| - Sends a value to the server. Once on the server, will be stored in a table with the specified name.
		| - You can send numbers, strings, vectors, angles and colors.
		|
		| ACE.MenuDeleteValue(group, name)
		| - Delete a value previously sent to the server. This will remove the group if all of their values were removed.
		|
		| ACE.MenuDestroy():
		| - Destroys all the networked data you have sent. Useful when the menu needs to be reseted.
		|________________________________________________________________________________________________________________________________________
	]]

	local function getTruetype(value)
		if IsColor(value) then return "Color" end
		return type(value)
	end

	function ACE.MenuSendValue( group, name, value)
		if not isstring(group) then
			error("The network only accepts strings as type (Got a " .. getTruetype(group) .. " instead)")
		end
		if not (isnumber(name) or isstring(name)) then
			error("The network only accepts strings or numbers as a valid Name! (Got a " .. getTruetype(name) .. " instead)")
		end
		if istable(value) and not IsColor(value) then
			error("The Network rejects tables as value in this method. To send tables, use ACE.MenuSendTableValue() instead!")
		end
		--print("NetworkCall:", type, name, value)
		local data = { Type = group, Name = name, Value = value }
		local JSON = util.TableToJSON(data)
		local Compress = util.Compress(JSON)

		net.Start("ACE_Network_Edit")
			net.WriteData(Compress)
		net.SendToServer()
	end


		--ACE.MenuDestroy()
		--local test_group = "DataTest"
		--local test_name = "CorrectData"
		--local test_value = 103
		--ACE.MenuSendValue( test_group, test_name, test_value)
		--ACE.MenuSendValue( test_group, "AnotherData", "hello World")
		--timer.Simple(5, function()
		--	ACE.MenuDeleteValue(test_group, test_name)
		--end)


	function ACE.MenuSendTableValue(group, table, name, value)
		if not isstring(group) then
			error("The network only accepts strings as type (Got a " .. getTruetype(group) .. " instead)")
		end
		if not isstring(table) then
			error("The network only accepts strings as a table name! (Got a " .. getTruetype(table) .. " instead)")
		end
		if not (isnumber(name) or isstring(name)) then
			error("The network only accepts strings or numbers as a valid Name! (Got a " .. getTruetype(name) .. " instead)")
		end
		if istable(value) and not IsColor(value) then
			error("Sorry, but you cannot send tables inside of this table ATM.")
		end

		--print("NetworkCall table:", type, name, value)
		local data = { Type = group, Table = table, Name = name, Value = value }
		local JSON = util.TableToJSON(data)
		local Compress = util.Compress(JSON)

		net.Start("ACE_Network_Edit")
			net.WriteData(Compress)
		net.SendToServer()
	end

	function ACE.MenuDestroy()
		net.Start("ACE_Network_Removal")
		net.SendToServer()
	end

	function ACE.MenuDeleteValue(group, name)
		if not isstring(group) then
			error("The network only accepts strings as type (Got a " .. getTruetype(group) .. " instead)")
		end
		if not (isnumber(name) or isstring(name)) then
			error("The network only accepts strings or numbers as a valid Name! (Got a " .. getTruetype(name) .. " instead)")
		end
		net.Start("ACE_Network_Removal")
			net.WriteString("remove_value")
			net.WriteString(getTruetype(name))
			net.WriteString(group)

			if isnumber(name) then
				net.WriteFloat(name)
			elseif isstring(name) then
				net.WriteString(name)
			end
		net.SendToServer()
	end
	--[[
	function ACE.MenuDeleteTableValue(group, name)
		net.Start("ACE_Network_Removal")
		net.SendToServer()
	end
	]]

end



