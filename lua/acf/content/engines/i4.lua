
-- Inline 4 engines

-- Petrol

ACE.RegisterEngine( "1.5-I4", {
	name = "1.5L I4 Petrol",
	desc = "Small car engine, not a whole lot of git",
	model = "models/engines/inline4s.mdl",
	sound = "acf_engines/i4_petrolsmall2.wav",
	category = "I4",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 50,
	torque = 90,
	flywheelmass = 0.06,
	idlerpm = 900,
	limitrpm = 7500
} )

ACE.RegisterEngine( "3.7-I4", {
	name = "3.7L I4 Petrol",
	desc = "Large inline 4, sees most use in light trucks",
	model = "models/engines/inline4m.mdl",
	sound = "acf_engines/i4_petrolmedium2.wav",
	category = "I4",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 200,
	torque = 240,
	flywheelmass = 0.2,
	idlerpm = 900,
	limitrpm = 6500
} )

ACE.RegisterEngine( "16.0-I4", {
	name = "16.0L I4 Petrol",
	desc = "Giant, thirsty I4 petrol, most commonly used in boats",
	model = "models/engines/inline4l.mdl",
	sound = "acf_engines/i4_petrollarge.wav",
	category = "I4",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 600,
	torque = 850,
	flywheelmass = 4,
	idlerpm = 500,
	limitrpm = 3500
} )

-- Diesel

ACE.RegisterEngine( "1.6-I4", {
	name = "1.6L I4 Diesel",
	desc = "Small and light diesel, for low power applications requiring a wide powerband",
	model = "models/engines/inline4s.mdl",
	sound = "acf_engines/i4_diesel2.wav",
	category = "I4",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 90,
	torque = 150,
	flywheelmass = 0.2,
	idlerpm = 650,
	limitrpm = 5000
} )

ACE.RegisterEngine( "3.1-I4", {
	name = "3.1L I4 Diesel",
	desc = "Light truck duty diesel, good overall grunt",
	model = "models/engines/inline4m.mdl",
	sound = "acf_engines/i4_dieselmedium.wav",
	category = "I4",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 250,
	torque = 320,
	flywheelmass = 1,
	idlerpm = 500,
	limitrpm = 4000
} )

ACE.RegisterEngine( "15.0-I4", {
	name = "15.0L I4 Diesel",
	desc = "Small boat sized diesel, with large amounts of torque",
	model = "models/engines/inline4l.mdl",
	sound = "acf_engines/i4_diesellarge.wav",
	category = "I4",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 800,
	torque = 1400,
	flywheelmass = 5,
	idlerpm = 450,
	limitrpm = 2100
} )
