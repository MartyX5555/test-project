
-- V8 engines

-- Petrol

ACE.RegisterEngine( "5.7-V8", {
	name = "5.7L V8 Petrol",
	desc = "Car sized petrol engine, good power and mid range torque",
	model = "models/engines/v8s.mdl",
	sound = "acf_engines/v8_petrolsmall.wav",
	category = "V8",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 260,
	torque = 320,
	flywheelmass = 0.15,
	idlerpm = 800,
	limitrpm = 6500
} )

ACE.RegisterEngine( "9.0-V8", {
	name = "9.0L V8 Petrol",
	desc = "Thirsty, giant V8, for medium applications",
	model = "models/engines/v8m.mdl",
	sound = "acf_engines/v8_petrolmedium.wav",
	category = "V8",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 400,
	torque = 460,
	flywheelmass = 0.25,
	idlerpm = 700,
	limitrpm = 5500
} )

ACE.RegisterEngine( "18.0-V8", {
	name = "18.0L V8 Petrol",
	desc = "American gasoline tank V8, good overall power and torque and fairly lightweight",
	model = "models/engines/v8l.mdl",
	sound = "acf_engines/v8_petrollarge.wav",
	category = "V8",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 850,
	torque = 1458,
	flywheelmass = 2.8,
	idlerpm = 600,
	limitrpm = 3800
} )

-- Diesel

ACE.RegisterEngine( "4.5-V8", {
	name = "4.5L V8 Diesel",
	desc = "Light duty diesel v8, good for light vehicles that require a lot of torque",
	model = "models/engines/v8s.mdl",
	sound = "acf_engines/v8_dieselsmall.wav",
	category = "V8",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 320,
	torque = 415,
	flywheelmass = 0.75,
	idlerpm = 800,
	limitrpm = 5000
} )

ACE.RegisterEngine( "7.8-V8", {
	name = "7.8L V8 Diesel",
	desc = "Redneck chariot material. Truck duty V8 diesel, has a good, wide powerband",
	model = "models/engines/v8m.mdl",
	sound = "acf_engines/v8_dieselmedium2.wav",
	category = "V8",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 520,
	torque = 700,
	flywheelmass = 1.6,
	idlerpm = 650,
	limitrpm = 4000
} )

ACE.RegisterEngine( "19.0-V8", {
	name = "19.0L V8 Diesel",
	desc = "Heavy duty diesel V8, used in heavy construction equipment and tanks",
	model = "models/engines/v8l.mdl",
	sound = "acf_engines/v8_diesellarge.wav",
	category = "V8",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 1200,
	torque = 2300,
	flywheelmass = 4.5,
	idlerpm = 500,
	limitrpm = 2500
} )
