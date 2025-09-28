
ACE.RegisterRadarClass("OMNI-AM", {
	name = "Spherical Anti-missile Radar",
	type = "Anti-missile",
	desc = ACFTranslation.Radar[5],
} )




ACE.RegisterRadar("SmallOMNI-AM", {
	name		= "Small Spherical Anti-Missile Radar",
	ent			= "ace_radar",
	desc		= ACFTranslation.Radar[6],
	model		= "models/radar/radar_sp_sml.mdl",
	class		= "OMNI-AM",
	weight		= 300,
	range		= 7874 -- range in inches.
} )


ACE.RegisterRadar("MediumOMNI-AM", {
	name		= "Medium Spherical Anti-Missile Radar",
	ent			= "ace_radar",
	desc		= ACFTranslation.Radar[7],
	model		= "models/radar/radar_sp_mid.mdl", -- medium one is for now scalled big one - will be changed
	class		= "OMNI-AM",
	weight		= 600,
	range		= 15748 -- range in inches.
} )


ACE.RegisterRadar("LargeOMNI-AM", {
	name		= "Large Spherical Anti-Missile Radar",
	ent			= "ace_radar",
	desc		= ACFTranslation.Radar[8],
	model		= "models/radar/radar_sp_big.mdl",
	class		= "OMNI-AM",
	weight		= 1200,
	range		= 31496 -- range in inches.
} )
