local ACF        = ACF
local Components = ACF.Classes.Components

Components.Register("CRW", {
	Name   = "Crew Member",
	Entity = "acf_crew",
	Mass = 65,
	LimitConVar = {
		Name   = "_acf_crew",
		Amount = 10,
		Text   = "Maximum amount of acf crewmates a player can create."
	}
})

do
	Components.RegisterItem("CRW-STAND", "CRW", {
		Name = "Standing Crew Member",
		Description = "Represents a tank's crew member. \nThis posture best suits a loader.",
		Model = "models/chairs_playerstart/standingpose.mdl",
		BaseErgoScores = {
			["Gunner"] = 1,
			["Loader"] = 1,
			["Driver"] = 1,
			["Commander"] = 1,
		},
		Preview = {
			FOV = 100,
		},
		CreateMenu = function(Data, Menu)
			Menu:AddLabel("Mass: " .. Data.Class.Mass)

			local str = "Base Ergonomics Scores: \n"
			for k,v in pairs(Data.BaseErgoScores) do
				str = str .. k .. ": " .. v .. "\n"
			end
			Menu:AddLabel(str)

			ACF.SetClientData("PrimaryClass", "acf_crew")
		end,
	})
end

do
	Components.RegisterItem("CRW-SIT", "CRW", {
		Name = "Sitting Crew Member",
		Description = "Represents a tank's crew member. \nThis posture best suits a driver/gunner.",
		Model = "models/chairs_playerstart/sitpose.mdl",
		BaseErgoScores = {
			["Gunner"] = 1,
			["Loader"] = 1,
			["Driver"] = 1,
			["Commander"] = 1,
		},
		Preview = {
			FOV = 100,
		},
		CreateMenu = function(Data, Menu)
			Menu:AddLabel("Mass: " .. Data.Class.Mass)

			local str = "Base Ergonomics Scores: \n"
			for k,v in pairs(Data.BaseErgoScores) do
				str = str .. k .. ": " .. v .. "\n"
			end
			Menu:AddLabel(str)

			ACF.SetClientData("PrimaryClass", "acf_crew")
		end,
	})
end

do
	Components.RegisterItem("CRW-PRONE", "CRW", {
		Name = "Prone Crew Member",
		Description = "Represents a tank's crew member. \nThis posture has horrible ergonomics, but can fit in very short spaces.",
		Model = "models/chairs_playerstart/pronepose.mdl",
		BaseErgoScores = {
			["Gunner"] = 0.1,
			["Loader"] = 0.1,
			["Driver"] = 0.1,
			["Commander"] = 0.1,
		},
		Preview = {
			FOV = 100,
		},
		CreateMenu = function(Data, Menu)
			Menu:AddLabel("Mass: " .. Data.Class.Mass)

			local str = "Base Ergonomics Scores: \n"
			for k,v in pairs(Data.BaseErgoScores) do
				str = str .. k .. ": " .. v .. "\n"
			end
			Menu:AddLabel(str)

			ACF.SetClientData("PrimaryClass", "acf_crew")
		end,
	})
end