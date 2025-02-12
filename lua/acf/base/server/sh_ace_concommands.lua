
if SERVER then

	concommand.Add( "acf_debris_clear", function(ply)
		if IsValid(ply) and not ply:IsAdmin() then print("not enough permissions!") return end

		if next(ACE.Debris) then
			for debris, _ in pairs(ACE.Debris) do
				if IsValid(debris) then
					debris:Remove()
				end
			end
		else
			print("no debris to clear!")
		end
	end)

	concommand.Add( "acf_mines_clear", function(ply)
		if IsValid(ply) and not ply:IsAdmin() then print("not enough permissions!") return end

		if next(ACE.Mines) then
			for mine, _ in pairs(ACE.Mines) do
				if IsValid(mine) then
					mine:Remove()
				end
			end
		else
			print("no mines to clear!")
		end
	end)

	concommand.Add( "acf_mines_explode_all", function(ply)
		if IsValid(ply) and not ply:IsSuperAdmin() then print("not enough permissions!") return end

		if next(ACE.Mines) then
			for mine, _ in pairs(ACE.Mines) do
				if IsValid(mine) then
					mine:Detonate()
				end
			end
		else
			print("no mines to explode!")
		end
	end)
end
