AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

--===============================================================================================--
-- Local Funcs and Vars
--===============================================================================================--
local ACF = ACF
local HookRun     = hook.Run
local HookRemove     = hook.Remove
local Utilities   = ACF.Utilities
local Clock       = Utilities.Clock
--===============================================================================================--
-- Entity initialization, update and verification
do
	local hook	   = hook
	local Classes	= ACF.Classes
	local Components = Classes.Components
	local Entities   = Classes.Entities
	local CheckLegal = ACF.CheckLegal

	util.AddNetworkString("ACF_Crew_Jobs_Update")

	local function VerifyData(Data)
		-- Set crew ID from component (?)
		if not Data.CrewID then
			Data.CrewID = Data.Component or Data.Id
		end

		local Class = Classes.GetGroup(Components, Data.CrewID)

		-- Default crew type should be sitting if not specified
		if not Class or Class.Entity ~= "acf_crew" then
			Data.CrewID = "CRW-SIT"
			Class = Classes.GetGroup(Components, Data.CrewID)
		end

		do -- External verifications
			if Class.VerifyData then
				Class.VerifyData(Data, Class)
			end

			hook.Run("ACF_VerifyData", "acf_crew", Data, Class)
		end
	end

	local function UpdateCrew(Entity, Data, Class, Crew)
		VerifyData(Data)

		Entity.ACF = Entity.ACF or {}
		Entity.ACF.Model = Crew.Model

		Entity:SetModel(Crew.Model)

		Entity:PhysicsInit(SOLID_VPHYSICS)
		Entity:SetMoveType(MOVETYPE_VPHYSICS)

		for _, V in ipairs(Entity.DataStore) do
			Entity[V] = Data[V]
		end

		Entity.Name = Crew.Name
		Entity.ShortName = Entity.CrewID
		Entity.EntType = Class.Name
		Entity.ClassData = Class
		Entity.OnUpdate = Crew.OnUpdate or Class.OnUpdate

		Entity:SetNWString("WireName", "ACF " .. Crew.Name)

		ACF.Activate(Entity, true)

		Entity.ACF.LegalMass = Class.Mass
		Entity.ACF.Model = Crew.Model

		local Phys = Entity:GetPhysicsObject()
		if IsValid(Phys) then Phys:SetMass(Class.Mass) end

		if Entity.OnUpdate then
			Entity:OnUpdate(Data, Class, Crew)
		end
	end

	function Makeacf_Crew(Player, Pos, Angle, Data)
		VerifyData(Data)

		local Class = Classes.GetGroup(Components, Data.CrewID)
		local Crew = Components.GetItem(Class.ID, Data.CrewID)
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
		Entity.CrewData = Crew
		Entity.Links = {} -- Job entities
		Entity.CrewLinks = {} -- Other crew linked to this
		Entity.CrewType = ""

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

	function ENT:Update(Data)
		VerifyData(Data)

		local Class = Classes.GetGroup(Components, Data.CrewID)
		local Crew = Class.Lookup[Data.CrewID]
		local OldClass = self.ClassData

		local CanUpdate, Reason = HookRun("ACF_PreEntityUpdate", "acf_crew", self, Data, Class, Crew)
		if CanUpdate == false then return CanUpdate, Reason end

		if OldClass.OnLast then
			OldClass.OnLast(self, OldClass)
		end

		HookRun("ACF_OnEntityLast", "acf_crew", self, OldClass)

		ACF.SaveEntity(self)

		UpdateCrew(self, Data, Class, Crew)

		ACF.RestoreEntity(self)

		if Class.OnUpdate then
			Class.OnUpdate(self, Data, Class, Crew)
		end

		HookRun("ACF_OnEntityUpdate", "acf_crew", self, Data, Class, Crew)

		return true, "Crew updated successfully!"
	end

	function ENT:UpdateOverlayText()
		str = ""
		for k,v in pairs(self.CrewLinks) do
			str = str .. tostring(v) .. " "
		end
		return str
	end
end

-- Entity methods

local function CheckCommonAncestor(e1,e2)
	local p1 = e1
	local p2 = e2
	while p1:GetParent():IsValid() do
		p1 = p1:GetParent()
	end
	while p2:GetParent():IsValid() do
		p2 = p2:GetParent()
	end
	return p1 == p2
end

do
	local MaxDistance = ACF.LinkDistance ^ 2
	print("MaxDistance",MaxDistance)
	local UnlinkSound = "physics/metal/metal_box_impact_bullet%s.wav"

	function ENT:Think()
		-- Check links on this entity
		local Links = self.Links
		if next(Links) then
			local Pos = self:GetPos()
			for LinkTarget in pairs(Links) do
				if Pos:DistToSqr(LinkTarget:GetPos()) > MaxDistance then
					local Sound = UnlinkSound:format(math.random(1, 3))
					LinkTarget:EmitSound(Sound, 70, 100, ACF.Volume)
					self:EmitSound(Sound, 70, 100, ACF.Volume)
					self:Unlink(LinkTarget)
				end
			end
		end

		-- Check lean angle
		

		self:NextThink(Clock.CurTime + 1 + math.Rand(1,2))
		return true
	end
end

-- Linkage Related
do
	function LinkCrew(Target, CrewEnt)
		if not Target.Crew then Target.Crew = {} end -- Safely make sure the link target has a crew list
		if Target.Crew[CrewEnt] then return false, "This entity is already linked to this crewmate!" end
		if CrewEnt.Links[Target] then return false, "This entity is already linked to this crewmate!" end

		Target.Crew[CrewEnt] = true
		CrewEnt.Links[Target] = true

		local LUT = {
			acf_engine = "Driver",
			acf_gun = "Loader",
			acf_turret = "Gunner",
		}

		CrewEnt.CrewType = LUT[Target:GetClass()] or ""

		if Target.CheckCrew then Target:CheckCrew() end
		if Target.UpdateOverlay then Target:UpdateOverlay() end
		CrewEnt:UpdateOverlay()

		return true, "Crewmate linked successfully"
	end

	function UnlinkCrew(Target, CrewEnt)
		if Target.Crew[CrewEnt] or CrewEnt.Links[Target] then
			Target.Crew[CrewEnt] = nil
			CrewEnt.Links[Target] = nil

			CrewEnt.CrewType = ""

			if Target.CheckCrew then Target:CheckCrew() end
			if Target.UpdateOverlay then Target:UpdateOverlay() end
			CrewEnt:UpdateOverlay()

			return true, "Crewmate unlinked successfully!"
		end
		return false, "This acf entity is not linked to this crewmate."
	end

	ACF.RegisterClassLink("acf_gun", "acf_crew", function(Gun, Crew)
		return LinkCrew(Gun, Crew)
	end)

	ACF.RegisterClassUnlink("acf_gun", "acf_crew", function(Gun, Crew)
		return UnlinkCrew(Gun, Crew)
	end)

	ACF.RegisterClassLink("acf_engine", "acf_crew", function(Engine, Crew)
		return LinkCrew(Engine, Crew)
	end)

	ACF.RegisterClassUnlink("acf_engine", "acf_crew", function(Engine, Crew)
		return UnlinkCrew(Engine, Crew)
	end)

	ACF.RegisterClassLink("prop_vehicle_prisoner_pod", "acf_crew", function(Pod, Crew)
		return LinkCrew(Pod, Crew)
	end)

	ACF.RegisterClassUnlink("prop_vehicle_prisoner_pod", "acf_crew", function(Pod, Crew)
		return UnlinkCrew(Pod, Crew)
	end)

	ACF.RegisterClassLink("acf_crew","acf_crew", function(From,To) 
		print(string.format("Link: [%s] -> [%s]",From,To))

		-- Safely add the new crew
		if not table.HasValue( To.CrewLinks, From) then
			table.insert(To.CrewLinks, From)
			net.Start("ACF_Crew_Jobs_Update")
			net.WriteTable(To.CrewLinks,true)
			net.Broadcast()
		end

		To:UpdateOverlay()
		From:UpdateOverlay()
		return true
	end)

	ACF.RegisterClassUnlink("acf_crew","acf_crew", function(From,To) 
		print(string.format("UnLink: [%s] -> [%s]",From,To))
		if table.HasValue( To.CrewLinks, From) then
			table.RemoveByValue(To.CrewLinks, From)
			net.Start("ACF_Crew_Jobs_Update")
			net.WriteTable(To.CrewLinks,true)
			net.Broadcast()
		end
		To:UpdateOverlay()
		From:UpdateOverlay()
		return true
	end)
end

-- Adv Dupe 2 Related
do
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

		HookRemove("AdvDupe_FinishPasting","crewdupefinished" .. self:EntIndex())

		for ent in pairs(self.Links) do
			self:Unlink(ent)
		end
	end
end