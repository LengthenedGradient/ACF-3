local ACF = ACF
local Sensors = ACF.Classes.Sensors

local function CreateMenu(Menu)
	ACF.SetClientData("PrimaryClass", "N/A")
	ACF.SetClientData("SecondaryClass", "N/A")

	ACF.SetToolMode("acf_menu", "Spawner", "Sensor")

	if not next(Sensors) then
		Menu:AddTitle("No Sensors Registered")
		Menu:AddLabel("No sensors have been registered. If this is incorrect, check your console for errors and contact the server owner.")
		return
	end

	Menu:AddTitle("Sensor Settings")

	local SensorClass = Menu:AddComboBox()
	local SensorList = Menu:AddComboBox()

	local Base = Menu:AddCollapsible("Sensor Information")
	local SensorName = Base:AddTitle()
	local SensorDesc = Base:AddLabel()
	local SensorPreview = Base:AddModelPreview()

	function SensorClass:OnSelect(Index, _, Data)
		if self.Selected == Data then return end

		self.ListData.Index = Index
		self.Selected = Data

		ACF.SetClientData("SensorClass", Data.ID)

		ACF.LoadSortedList(SensorList, Data.Items, "ID")
	end

	function SensorList:OnSelect(Index, _, Data)
		if self.Selected == Data then return end

		self.ListData.Index = Index
		self.Selected = Data

		local Preview = Data.Preview
		local ClassData = SensorClass.Selected

		ACF.SetClientData("Sensor", Data.ID)

		SensorName:SetText(Data.Name)
		SensorDesc:SetText(Data.Description or "No description provided.")

		SensorPreview:SetModel(Data.Model)
		SensorPreview:SetCamPos(Preview and Preview.Offset or Vector(45, 60, 45))
		SensorPreview:SetLookAt(Preview and Preview.Position or Vector())
		SensorPreview:SetHeight(Preview and Preview.Height or 80)
		SensorPreview:SetFOV(Preview and Preview.FOV or 75)

		Menu:ClearTemporal(Base)
		Menu:StartTemporal(Base)

		local CustomMenu = Data.CreateMenu or ClassData.CreateMenu

		if CustomMenu then
			CustomMenu(Data, Base)
		end

		Menu:EndTemporal(Base)
	end

	ACF.LoadSortedList(SensorClass, Sensors, "ID")
end

ACF.AddMenuItem(401, "Entities", "Sensors", "transmit", CreateMenu)