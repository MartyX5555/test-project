--[[
	
]]

local function HandleACFPodAnimation( _, player )
	return player:LookupSequence("drive_pd")
end

local Category = "Armoured Combat Framework"

if list.HasEntry( "Vehicles", "acf_pod" ) then

	list.Set( "Vehicles", "acf_pod", {
		Name = "Standard Driver Pod",
		Class = "prop_vehicle_prisoner_pod",
		Category = Category,

		Author = "Lazermaniac",
		Information = "Modified prisonpod for more realistic player damage",
		Model = "models/vehicles/driver_pod.mdl",
		KeyValues = {
			vehiclescript	=	"scripts/vehicles/prisoner_pod.txt",
			limitview		=	"0"
					},
		Members = {
			HandleAnimation = HandleACFPodAnimation
		}
	} )

end

if list.HasEntry( "Vehicles", "acf_pilotseat" ) then

	list.Set( "Vehicles", "acf_pilotseat", {
		Name = "Standard Driver Pod",
		Class = "prop_vehicle_prisoner_pod",
		Category = Category,

		Author = "Lazermaniac",
		Information = "Modified prisonpod for more realistic player damage",
		Model = "models/vehicles/driver_pod.mdl",
		KeyValues = {
			vehiclescript	=	"scripts/vehicles/prisoner_pod.txt",
			limitview		=	"0"
					},
		Members = {
			HandleAnimation = HandleACFPodAnimation
		}
	} )

end


local V = {
	-- Required information
	Name = "Standard Pilot Seat",
	Class = "prop_vehicle_prisoner_pod",
	Category = Category,

	-- Optional information
	Author = "Lazermaniac",
	Information = "A generic seat for accurate damage modelling.",
	Model = "models/vehicles/pilot_seat.mdl",
	KeyValues = {
					vehiclescript	=	"scripts/vehicles/prisoner_pod.txt",
					limitview		=	"0"
				},
}
list.Set( "Vehicles", "acf_pilotseat", V )
