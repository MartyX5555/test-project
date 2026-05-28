local ACE = ACE

-- This should help to fix the old ammodata to be relocated to the new location.

ACE.LegacyRoundData = {}

--- AP non Sabot rounds

ACE.LegacyRoundData["AP"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["APC"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["APBC"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["APCBC"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

-- Sabot rounds

ACE.LegacyRoundData["APDS"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "SCalMult",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["APFSDS"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "SCalMult",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HVAP"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "SCalMult",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HP"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "CavVol",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["FL"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "Flechettes",
	RoundData6 = "FlechetteSpread",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}


-- AP explosive Rounds
ACE.LegacyRoundData["APHE"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "FuseDelay",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}
ACE.LegacyRoundData["APHECBC"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "FuseDelay",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HE"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HEFS"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HESH"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HEAT"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "ConeAng",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["GLATGM"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "ConeAng",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["HEATFS"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "ConeAng",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["THEAT"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "ConeAng",
	RoundData13 = "ConeAng2",
	RoundData14 = "HEAllocation",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["THEATFS"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "ConeAng",
	RoundData13 = "ConeAng2",
	RoundData14 = "HEAllocation",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["SM"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData6 = "WPVol",
	RoundData7 = "FuseDelay",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["FLR"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
	RoundPropellant = "PropLength",
	RoundProjectile = "ProjLength",
	RoundData5 = "FillerVol",
	RoundData10 = "Tracer",
	RoundData11 = "TwoPiece",
}

ACE.LegacyRoundData["Refill"] = {
	RoundId = "RoundGunClass",
	RoundType = "RoundType",
}

-- Only if the crate has these values
ACE.LegacyOrdnanceRoundData = {
	RoundData7 = "Guidance",
	RoundData8 = "Fuse",
}