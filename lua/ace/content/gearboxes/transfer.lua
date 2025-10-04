
-- Transfer cases

local Gear2SW = 20
local Gear2MW = 40
local Gear2LW = 80

-- Inline

ACE.RegisterGearbox( "2Gear-L-S-NC", {
	name = "Transfer case, Inline, Small",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/linear_s.mdl",
	category = "Transfer",
	weight = Gear2SW,
	parentable = true,
	switch = 0.3,
	maxtq = 25000,
	gears = 2,
	doubleclutch = false,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-L-S", {
	name = "Transfer case, Inline, Small, Dual Clutch",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/linear_s.mdl",
	category = "Transfer",
	weight = Gear2SW,
	parentable = true,
	switch = 0.3,
	maxtq = 25000,
	gears = 2,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-L-M-NC", {
	name = "Transfer case, Inline, Medium",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/linear_m.mdl",
	category = "Transfer",
	weight = Gear2MW,
	parentable = true,
	switch = 0.4,
	maxtq = 50000,
	gears = 2,
	doubleclutch = false,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-L-M", {
	name = "Transfer case, Inline, Medium, Dual Clutch",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/linear_m.mdl",
	category = "Transfer",
	weight = Gear2MW,
	parentable = true,
	switch = 0.4,
	maxtq = 50000,
	gears = 2,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )


ACE.RegisterGearbox( "2Gear-L-L-NC", {
	name = "Transfer case, Inline, Large",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/linear_l.mdl",
	category = "Transfer",
	weight = Gear2LW,
	parentable = true,
	switch = 0.6,
	maxtq = 100000,
	gears = 2,
	doubleclutch = false,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 1
	}
} )

ACE.RegisterGearbox( "2Gear-L-L", {
	name = "Transfer case, Inline, Large, Dual Clutch",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/linear_l.mdl",
	category = "Transfer",
	weight = Gear2LW,
	parentable = true,
	switch = 0.6,
	maxtq = 100000,
	gears = 2,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 1
	}
} )

-- Transaxial

ACE.RegisterGearbox( "2Gear-T-S-NC", {
	name = "Transfer case, Small",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/transaxial_s.mdl",
	category = "Transfer",
	weight = Gear2SW,
	parentable = true,
	switch = 0.3,
	maxtq = 25000,
	gears = 2,
	doubleclutch = false,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-T-S", {
	name = "Transfer case, Small, Dual Clutch",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/transaxial_s.mdl",
	category = "Transfer",
	weight = Gear2SW,
	parentable = true,
	switch = 0.3,
	maxtq = 25000,
	gears = 2,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-T-M-NC", {
	name = "Transfer case, Medium",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/transaxial_m.mdl",
	category = "Transfer",
	weight = Gear2MW,
	parentable = true,
	switch = 0.4,
	maxtq = 50000,
	gears = 2,
	doubleclutch = false,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-T-M", {
	name = "Transfer case, Medium, Dual Clutch",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/transaxial_m.mdl",
	category = "Transfer",
	weight = Gear2MW,
	parentable = true,
	switch = 0.4,
	maxtq = 50000,
	gears = 2,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 0.5
	}
} )

ACE.RegisterGearbox( "2Gear-T-L-NC", {
	name = "Transfer case, Large",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/transaxial_l.mdl",
	category = "Transfer",
	weight = Gear2LW,
	parentable = true,
	switch = 0.6,
	maxtq = 100000,
	gears = 2,
	doubleclutch = false,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 1
	}
} )

ACE.RegisterGearbox( "2Gear-T-L", {
	name = "Transfer case, Large, Dual Clutch",
	desc = "2 speed gearbox, useful for low/high range and tank turning",
	model = "models/engines/transaxial_l.mdl",
	category = "Transfer",
	weight = Gear2LW,
	parentable = true,
	switch = 0.6,
	maxtq = 100000,
	gears = 2,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.5,
		[ 2 ] = -0.5,
		[ -1 ] = 1
	}
} )

