
local Category = "Armoured Combat Framework" -- If ACF3 or ACE, the vehicles should be in the same category

-- There is ACF or ACF3 installed
if ACF then

	local function HandleACFPodAnimation( _, player )
		return player:LookupSequence("drive_pd")
	end

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

	list.Set( "Vehicles", "acf_pilotseat", {

		Name = "Standard Pilot Seat",
		Class = "prop_vehicle_prisoner_pod",
		Category = Category,

		Author = "Lazermaniac",
		Information = "A generic seat for accurate damage modelling.",
		Model = "models/vehicles/pilot_seat.mdl",
		KeyValues = {
			vehiclescript	=	"scripts/vehicles/prisoner_pod.txt",
			limitview		=	"0"
		},
	} )

end







