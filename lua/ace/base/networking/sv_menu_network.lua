

util.AddNetworkString("ACE_Network_Edit")
util.AddNetworkString("ACE_Network_Removal")

local ACE = ACE
ACE.Network = ACE.Network or {}

do
	--[[
		The functions below are used to network data from the client to the server
		Note: I hate how networking works.
		__________________________________________________________________________________________________________________________________________
		| TOOL SPAWNING NETWORK / SERVER FUNCTIONS:
		|
		| ACE.GetPlayerData(ply):
		| - Gets the whole Data table networked by this user
		|
		| ACE.GetPlayerTable(ply, type):
		| - Gets a specific data type of a user.
		|
		| ACE.GetPlayerValue(ply, type, value):
		| - Gets a specific value, according to the defined type and user.
		|__________________________________________________________________________________________________________________________________________
	]]

	-- Types are checked first if they exist as real types
	-- the Name of it must be a string
	-- accepted value formats: number, strings, vectors, angles, Colors.

	local Whitelist = {
		number = true,
		string = true,
		Vector = true,
		Angle = true,
		--Color = true, -- not exactly tables, but colors. See code below and https://wiki.facepunch.com/gmod/Global.type
	}

	local function getTruetype(value)
		if IsColor(value) then return "Color" end
		return type(value)
	end

	local function CheckValues( data )
		if not isstring(data.Type) then return false end
		if not (isstring(data.Name) or isnumber(data.Name)) then return false end
		if not Whitelist[getTruetype(data.Value)] then return false end
		return true
	end

	local function CreateNetworkContainer( ply )
		ACE.Network[ply] = ACE.Network[ply] or {}
	end

	local function GetNetworkContainer( ply )
		return ACE.Network[ply]
	end

	local function ClearNetworkContainer( ply )
		ACE.Network[ply] = {}
	end

	local function RemoveNetworkContainer( ply )
		ACE.Network[ply] = nil
	end

	net.Receive( "ACE_Network_Edit", function(len, ply)
		if not IsValid(ply) then RemoveNetworkContainer(ply) return end

		local Network = GetNetworkContainer( ply )
		local Content = net.ReadData(len / 8)
		local Decompress = util.Decompress(Content)
		local data = util.JSONToTable(Decompress)

		if CheckValues( data ) then
			local group = data.Type
			local name = data.Name
			local value = data.Value

			-- ooof, i need to avoid this. Its cursed.
			Network[group] = Network[group] or {}
			if data.Table then
				Network[group][data.Table] = Network[group][data.Table] or {}
				Network[group][data.Table][name] = value
			else
				Network[group][name] = value
			end
		else
			ErrorNoHaltWithStack("A networked variable didnt pass the test. Please ensure its not sending restricted value types!")
		end
	end)

	net.Receive( "ACE_Network_Removal", function(_, ply)
		if not IsValid(ply) then RemoveNetworkContainer(ply) return end

		local Mode = net.ReadString()

		if Mode == "remove_value" then
			local nametype = net.ReadString()
			local group = net.ReadString()
			local name

			if nametype == "number" then
				name = net.ReadFloat(name)
			elseif nametype == "string" then
				name = net.ReadString(name)
			end

			local NetworkData = GetNetworkContainer( ply )
			if NetworkData[group] and NetworkData[group][name] then
				NetworkData[group][name] = nil
				NetworkData[group] = next(NetworkData[group]) and NetworkData[group] or nil
			end
		else
			ClearNetworkContainer( ply )
		end
		--print("table result")
		--PrintTable(GetNetworkContainer( ply ))
	end)

	-- Returns all the data associated this player has created via menus, networked to the server.
	function ACE.GetPlayerData(ply)
		local NetworkData = GetNetworkContainer( ply )
		return istable(NetworkData) and NetworkData or {}
	end

	-- Returns a table of info associated with this player.
	function ACE.GetPlayerTable(ply, type)
		local NetworkData = ACE.GetPlayerData(ply)
		local NetworkInfo = NetworkData[type]
		return istable(NetworkInfo) and NetworkInfo or {}
	end

	-- Having the table/type, this returns a specific value of the player.
	function ACE.GetPlayerValue(ply, type, value)
		local NetworkInfo = ACE.GetPlayerTable(ply, type)
		local NetworkValue = NetworkInfo[value]
		return NetworkValue
	end

	-- Creates the table
	hook.Add( "PlayerInitialSpawn", "ACE_PlayerSpawn_Network", function( ply )
		CreateNetworkContainer( ply )
	end )
	-- Deletes the table
	hook.Add( "PlayerDisconnected", "ACE_PlayerLeave_Network", function(ply)
		RemoveNetworkContainer( ply )
	end )
end

