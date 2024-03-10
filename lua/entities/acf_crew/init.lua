AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

--===============================================================================================--
-- Local Funcs and Vars
--===============================================================================================--
local HookRun     = hook.Run

--===============================================================================================--
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

	ACF.RegisterClassLink("acf_engine", "acf_crew", function(Engine, Target)
		if not Engine.Crew then Engine.Crew = {} end
		if Engine.Crew[Target] then return false, "This engine is already linked to this crewmate!" end
		if Target.Links[Crew] then return false, "This engine is already linked to this crewmate!" end
		if not Target.CrewData.LinkableEnts["acf_engine"] then return false, Target.CrewData.CrewType .. " cannot be linked to a engine" end

		Engine.Crew[Target] = true -- Make the crew linked to the gun
		Target.Links[Engine] = true

		Engine:UpdateOverlay()
		Target:UpdateOverlay()

		return true, "Crewmate linked successfully!"
	end)

	ACF.RegisterClassUnlink("acf_engine", "acf_crew", function(Engine, Target)
		if Engine.Crew[Target] or Target.Links[Engine] then
			Engine.Crew[Target] = nil
			Target.Links[Engine] = nil -- Make the crew unlinked to the gun

			Engine:UpdateOverlay()
			Target:UpdateOverlay()

			return true, "Crewmate unlinked successfully!"
		end

		return false, "This Engine is not linked to this crewmate."
	end)
end

do -- Overlay Update
	function ENT:UpdateOverlayText()
		local Str = "Linked to: \n"
		for ent,_ in pairs(self.Links) do
			Str = Str .. "" .. tostring(ent) .. "\n"
		end
		return Str
		-- return "CREW_OVERLAY"--Text:format(Status, Size, self.FuelType, Content)
	end
end

function ENT:PreEntityCopy()
	if next(self.Links) then
		local Entities = {}

		for LinkTarget in pairs(self.Links) do
			Entities[#Entities + 1] = LinkTarget:EntIndex()
		end

		duplicator.StoreEntityModifier(self, "ACFCrews", Entities)
	end

	-- Wire dupe info
	self.BaseClass.PreEntityCopy(self)
end

function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	local EntMods = Ent.EntityMods

	if EntMods.ACFCrews then
		for _, EntID in pairs(EntMods.ACFCrews) do
			self:Link(CreatedEntities[EntID])
		end

		EntMods.ACFCrews = nil
	end

	--Wire dupe info
	self.BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)
end

function ENT:OnRemove()
	local Class = self.ClassData

	if Class.OnLast then
		Class.OnLast(self, Class)
	end

	HookRun("ACF_OnEntityLast", "acf_crew", self, Class)

	for ent in pairs(self.Links) do
		self:Unlink(ent)
	end
end
