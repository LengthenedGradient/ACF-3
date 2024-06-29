-- I do it this way because the components menu forces me to...
-- 


local ACF        = ACF
local Components = ACF.Classes.Components
local CrewTypes = ACF.Classes.CrewTypes

Components.Register("CrewModels", {
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
		local Entries = CrewTypes.GetEntries()

		-- Information about the crew model
		Menu:AddLabel("Mass: " .. Data.Class.Mass)
		Menu:AddLabel("Generally, crew that are more upright will perform better. You can link one crew to multiple components and they will take jobs in that order.")
		ACF.SetClientData("PrimaryClass", "acf_crew")

		-- Information about the crew type
		local CrewClass = Menu:AddComboBox()

		local Base = Menu:AddCollapsible("Occupation Information")
		local CrewClassDesc = Base:AddLabel()

		function CrewClass:OnSelect(Index, _, Data)
			if self.Selected == Data then return end

			self.ListData.Index = Index
			self.Selected = Data

			CrewClassDesc:SetText(Data.Description or "No description provided.")

			ACF.SetClientData("CrewTypeID", Data.ID)
		end

		ACF.LoadSortedList(CrewClass, Entries, "ID")

	end,
})

do
	Components.RegisterItem("Standing", "CrewModels", {
		Name = "Standing Crew Member",
		Description = "This posture best suits a loader.",
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
	Components.RegisterItem("Sitting", "CrewModels", {
		Name = "Sitting Crew Member",
		Description = "This posture best suits a driver/gunner.",
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