local ACF        = ACF
local Components = ACF.Classes.Components

Components.Register("CRW", {
	Name   = "Crew Member",
	Entity = "acf_crew",
	LimitConVar = {
		Name   = "_acf_crew",
		Amount = 20,
		Text   = "Maximum amount of acf crewmates a player can create."
	}
})

do
	Components.RegisterItem("CRW-Driver", "CRW", {
		Name = "Driver Crewseat",
		Description = "temp desc",
		Model = "models/chairs_playerstart/sitpose.mdl",
		Mass = 65,
		CrewType = "Driver",
		LinkableEnts = {
			["acf_gearbox"] = true,
		},
		Preview = {
			FOV = 100,
		},
		CreateMenu = function(Data, Menu)
			Menu:AddLabel("hi " .. Data.Mass)

			ACF.SetClientData("PrimaryClass", "acf_crew")
		end,
	})
end

do
	Components.RegisterItem("CRW-Gunner", "CRW", {
		Name = "Gunner Crewseat",
		Description = "temp desc",
		Model = "models/chairs_playerstart/sitpose.mdl",
		Mass = 65,
		CrewType = "Gunner",
		LinkableEnts = {
			["acf_gun"] = true,
		},
		Preview = {
			FOV = 100,
		},
		CreateMenu = function(Data, Menu)
			Menu:AddLabel("hi " .. Data.Mass)

			ACF.SetClientData("PrimaryClass", "acf_crew")
		end,
	})
end

do
	Components.RegisterItem("CRW-Loader", "CRW", {
		Name = "Loader Crewseat",
		Description = "temp desc",
		Model = "models/chairs_playerstart/sitpose.mdl",
		Mass = 65,
		CrewType = "Loader",
		LinkableEnts = {
			["acf_gun"] = true,
		},
		Preview = {
			FOV = 100,
		},
		CreateMenu = function(Data, Menu)
			Menu:AddLabel("hi " .. Data.Mass)

			ACF.SetClientData("PrimaryClass", "acf_crew")
		end,
	})
end