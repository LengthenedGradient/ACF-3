local ACF        = ACF
local Components = ACF.Classes.Components

Components.Register("CRW", {
	Name   = "Crew Member",
	Entity = "acf_crew",
	Mass = 80,
	MaxLeans = {
		Gunner = 15.01,
		Loader = 15.01,
		Driver = 45.01,
	},
	-- MaxLeanEfficiency = 1,
	LimitConVar = {
		Name   = "_acf_crew",
		Amount = 8,
		Text   = "Maximum amount of acf crewmates a player can create."
	},
	CreateMenu = function(Data, Menu)
		local str = "Maximum Lean Angles:\n"
		for k,v in pairs(Data.Class.MaxLeans) do
			str = str .. k .. ": " .. math.Round(v) .. "\n"
		end
		Menu:AddLabel(str)

		Menu:AddLabel("Mass: " .. Data.Class.Mass)

		local str = "Base Ergonomics Scores: \n"
		for k,v in pairs(Data.BaseErgoScores) do
			str = str .. k .. ": " .. v .. "\n"
		end
		Menu:AddLabel(str)

		local InstructionsBase = Menu:AddCollapsible("Usage Instructions:")
		InstructionsBase:AddLabel("Generally, crew that are more upright will perform better. You can link one crew to multiple components and they will take jobs in that order.")
		InstructionsBase:AddLabel("Gunners affect the accuracy of your gun and the slew rate of your turret. They prefer sitting.")
		InstructionsBase:AddLabel("Drivers affect the fuel efficiency of your engines. They prefer sitting. They will be disorientated if put in a turret.")
		InstructionsBase:AddLabel("Loaders affect the reload rate of your guns. They prefer standing. To a limit, the more space you have the faster they reload.")

		ACF.SetClientData("PrimaryClass", "acf_crew")
	end,
})

do
	Components.RegisterItem("CRW-STD", "CRW", {
		Name = "Standing Crew Member",
		Description = "Tank crew member. \nThis posture best suits a loader.",
		Model = "models/chairs_playerstart/standingpose.mdl",
		BaseErgoScores = {
			Gunner = 0.75,
			Loader = 1,
			Driver = 0.5,
		},
		Preview = {
			FOV = 100,
		},
	})
end

do
	Components.RegisterItem("CRW-SIT", "CRW", {
		Name = "Sitting Crew Member",
		Description = "Tank crew member. \nThis posture best suits a driver/gunner.",
		Model = "models/chairs_playerstart/sitpose.mdl",
		BaseErgoScores = {
			Gunner = 1,
			Loader = 0.75,
			Driver = 1,
		},
		Preview = {
			FOV = 100,
		},
	})
end