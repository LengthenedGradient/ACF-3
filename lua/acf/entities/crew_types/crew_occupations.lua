local ACF         = ACF
local CrewTypes = ACF.Classes.CrewTypes

CrewTypes.Register("Loader", {
	Name        = "Loader",
	Description = "Loaders affect the reload rate of your guns. They prefer standing. To a limit, the more space you have the faster they reload.",
	Whitelist = {
		acf_gun = true,
	},
	ShouldScan = true,
	ScanStep = 9,
})

CrewTypes.Register("Gunner", {
	Name        = "Gunner",
	Description = "Gunners affect the accuracy of your gun and the slew rate of your turret. They prefer sitting.",
	Whitelist = {
		acf_gun = true,
		acf_turret = true,
	},
	ShouldScan = false,
})

CrewTypes.Register("Driver", {
	Name        = "Driver",
	Description = "Drivers affect the fuel efficiency of your engines. They prefer sitting. They will be disorientated if put in a turret.",
	Whitelist = {
		acf_engine = true,
	},
	ShouldScan = false,
})
