AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

do
	local hook	   = hook
	local Classes	= ACF.Classes
	local Components = Classes.Components
	local Entities   = Classes.Entities
	local CheckLegal = ACF.CheckLegal

	local function VerifyData(Data)
		if not Data.Crew then
			Data.Crew = Data.Component or Data.Id
		end

		local Class = Classes.GetGroup(Components, Data.Crew)

		if not Class or Class.Entity ~= "acf_crew" then
			Data.Crew = "CRW-Driver" -- Driver default

			Class = Classes.GetGroup(Components, Data.Crew)
		end

		do -- External verifications
			if Class.VerifyData then
				Class.VerifyData(Data, Class)
			end

			hook.Run("ACF_VerifyData", "acf_crew", Data, Class)
		end
	end

	local function UpdateCrew(Entity, Data, Class, Crew)
		Entity.ACF = Entity.ACF or {}
		Entity.ACF.Model = Crew.Model

		Entity:SetModel(Crew.Model)

		Entity:PhysicsInit(SOLID_VPHYSICS)
		Entity:SetMoveType(MOVETYPE_VPHYSICS)

		for _, V in ipairs(Entity.DataStore) do
			Entity[V] = Data[V]
		end

		Entity.Name = Crew.Name
		Entity.ShortName = Entity.Crew
		Entity.EntType = Class.Name
		Entity.ClassData = Class
		Entity.OnUpdate = Crew.OnUpdate or Class.OnUpdate

		Entity:SetNWString("WireName", "ACF " .. Crew.Name)

		ACF.Activate(Entity, true)

		Entity.ACF.LegalMass = Crew.Mass
		Entity.ACF.Model = Crew.Model

		local Phys = Entity:GetPhysicsObject()
		if IsValid(Phys) then Phys:SetMass(Crew.Mass) end

		if Entity.OnUpdate then
			Entity:OnUpdate(Data, Class, Crew)
		end

		if Entity.OnDamaged then
			Entity:OnDamaged()
		end
	end

	function Makeacf_Crew(Player, Pos, Angle, Data)
		VerifyData(Data)

		local Class = Classes.GetGroup(Components, Data.Crew)
		local Crew = Class.Lookup[Data.Crew]
		local Limit = Class.LimitConVar.Name

		if not Player:CheckLimit(Limit) then return false end

		local Entity = ents.Create("acf_crew")

		if not IsValid(Entity) then return end

		Entity:SetPlayer(Player)
		Entity:SetAngles(Angle)
		Entity:SetPos(Pos)
		Entity:Spawn()

		Player:AddCleanup("acf_crew", Entity)
		Player:AddCount(Limit, Entity)

		Entity.Owner = Player
		Entity.DataStore = Entities.GetArguments("acf_crew")
		Entity.CrewData = Crew -- Store a reference to Class.Lookup[Data.Crew]
		Entity.Links = {}

		UpdateCrew(Entity, Data, Class, Crew)

		if Class.OnSpawn then
			Class.OnSpawn(Entity, Data, Class, Crew)
		end

		hook.Run("ACF_OnEntitySpawn", "acf_crew", Entity, Data, Class, Crew)

		WireLib.TriggerOutput(Entity, "Entity", Entity)

		Entity:UpdateOverlay(true)

		CheckLegal(Entity)

		return Entity
	end

	Entities.Register("acf_crew", Makeacf_Crew, "Crew")

	ACF.RegisterLinkSource("acf_gun", "Crew")
end

do
	ACF.RegisterClassLink("acf_gun", "acf_crew", function(Gun, Target)
		if not Gun.Crew then Gun.Crew = {} end
		if Gun.Crew[Target] then return false, "This weapon is already linked to this crewmate!" end
		if Target.Links[Crew] then return false, "This weapon is already linked to this crewmate!" end
		if not Target.CrewData.LinkableEnts["acf_gun"] then return false, Target.CrewData.CrewType .. " cannot be linked to a weapon" end

		Gun.Crew[Target] = true -- Make the crew linked to the gun
		Target.Links[Gun] = true

		Gun:UpdateOverlay()
		Target:UpdateOverlay()

		return true, "Crewmate linked successfully!"
	end)

	ACF.RegisterClassUnlink("acf_gun", "acf_crew", function(Gun, Target)
		if Gun.Crew[Target] or Target.Links[Gun] then
			Gun.Crew[Target] = nil
			Target.Links[Gun] = nil -- Make the crew unlinked to the gun

			Gun:UpdateOverlay()
			Target:UpdateOverlay()

			return true, "Crewmate unlinked successfully!"
		end

		return false, "This weapon is not linked to this crewmate."
	end)

	ACF.RegisterClassLink("acf_gearbox", "acf_crew", function(Gearbox, Target)
		if not Gearbox.Crew then Gearbox.Crew = {} end
		if Gearbox.Crew[Target] then return false, "This gearbox is already linked to this crewmate!" end
		if Target.Links[Crew] then return false, "This gearbox is already linked to this crewmate!" end
		if not Target.CrewData.LinkableEnts["acf_gearbox"] then return false, Target.CrewData.CrewType .. " cannot be linked to a gearbox" end

		Gearbox.Crew[Target] = true -- Make the crew linked to the gun
		Target.Links[Gearbox] = true

		Gearbox:UpdateOverlay()
		Target:UpdateOverlay()

		return true, "Crewmate linked successfully!"
	end)

	ACF.RegisterClassUnlink("acf_gearbox", "acf_crew", function(Gearbox, Target)
		if Gearbox.Crew[Target] or Target.Links[Gearbox] then
			Gearbox.Crew[Target] = nil
			Target.Links[Gearbox] = nil -- Make the crew unlinked to the gun

			Gearbox:UpdateOverlay()
			Target:UpdateOverlay()

			return true, "Crewmate unlinked successfully!"
		end

		return false, "This gearbox is not linked to this crewmate."
	end)
end

do -- Overlay Update
	function ENT:UpdateOverlayText()
		return "Linked: " .. #table.GetKeys(self.Links)
		-- return "CREW_OVERLAY"--Text:format(Status, Size, self.FuelType, Content)
	end
end

--[[
function ENT:Initialize()
	if self:GetModel() == "models/vehicles/pilot_seat.mdl" then
		self:SetPos(self:LocalToWorld(Vector(0, 15.3, -14)))
	end
	self:SetModel( "models/chairs_playerstart/sitpose.mdl" )
	self:SetMoveType(MOVETYPE_VPHYSICS);
	self:PhysicsInit(SOLID_VPHYSICS);
	self:SetUseType(SIMPLE_USE);
	self:SetSolid(SOLID_VPHYSICS);

	self.Master = {}
	self.ACF = {}
	self.ACF.Health = 1
	self.ACF.MaxHealth = 1
end
]]