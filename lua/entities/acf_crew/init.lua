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
local Contraption = ACF.Contraption
local hook	   = hook
local Classes	= ACF.Classes
local Components = Classes.Components
local CrewTypes = Classes.CrewTypes
local Entities   = Classes.Entities
local CheckLegal = ACF.CheckLegal

do


	util.AddNetworkString("ACF_Crew_Reps")
	util.AddNetworkString("ACF_Crew_Links")

	local function VerifyData(Data)
		-- Set crew ID from component (?)
		if not Data.CrewModel then
			Data.CrewModel = Data.Component or Data.Id
		end

		local Class = Classes.GetGroup(Components, Data.CrewModel)

		-- Default crew type should be sitting if not specified
		if not Class or Class.Entity ~= "acf_crew" then
			Data.CrewModel = "Sitting"
			Class = Classes.GetGroup(Components, Data.CrewModel)
		end

		if not Data.CrewTypeID then
			Data.CrewTypeID = "Driver"
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
		Entity.ShortName = Entity.CrewModel
		Entity.EntType = Class.Name
		Entity.ClassData = Class
		Entity.OnUpdate = Crew.OnUpdate or Class.OnUpdate

		Entity.CrewType = CrewTypes.Get(Data.CrewTypeID)

		Entity:SetNWString("WireName", "ACF " .. Crew.Name) -- Set overlay wire entity name

		ACF.Activate(Entity, true)

		Entity.ACF.LegalMass = Class.Mass -- TODO: Still necessary?
		Entity.ACF.Model = Crew.Model

		local Phys = Entity:GetPhysicsObject()
		if IsValid(Phys) then Phys:SetMass(Class.Mass) end

		-- local PhysObj = Entity.ACF.PhysObj
		-- if IsValid(PhysObj) then
		-- 	Contraption.SetMass(Entity, Class.Mass)
		-- end

		if Entity.OnUpdate then
			Entity:OnUpdate(Data, Class, Crew)
		end

		Entity:UpdateOverlay(true)
	end

	function MakeCrew(Player, Pos, Angle, Data)
		VerifyData(Data)

		local Class = Classes.GetGroup(Components, "CrewModels")
		local Crew = Components.GetItem(Class.ID, Data.CrewModel)
		local CrewType = CrewTypes.Get(Data.CrewTypeID)
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
		Entity.TargetLinks = {} -- Targets linked to this crew (dictionary)
		Entity.ReplaceLinksOrdered = {} -- Crew to replace this crew (array)
		Entity.ReplaceLinks = {} -- Crew to replace this crew (dictionary)
		Entity.AllLinks = {} -- All links (targets and crew) linked to this crew
		Entity.CrewType = CrewType
		Entity.LeanAngle = 0

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

	Entities.Register("acf_crew", MakeCrew)

	-- TODO: Determine sources
	ACF.RegisterLinkSource("acf_gun", "Crew")

	function ENT:Update(Data)
		VerifyData(Data)

		local Class = Classes.GetGroup(Components, Data.CrewModel)
		local Crew = Class.Lookup[Data.CrewModel]
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
		str = string.format("Health: %s%%\nRole: %s\nLean Angle: %s",100,self.CrewType.ID,self.LeanAngle)

		return str
	end
end

-- Entity methods
do
	-- Think logic (mostly checks and stuff that updates frequently)
	local function traceVisHullCube(pos1, pos2, boxsize, filter)
		local res = TraceHull({
			start = pos1,
			endpos = pos2,
			filter = filter,
			mins = -boxsize / 2,
			maxs = boxsize / 2
		})

		local length = pos1:Distance(pos2)
		local truelength = res.Fraction * length
		return res.Fraction, length, truelength
	end

	local function GetAncestor(e)
		local p = e
		while p:GetParent():IsValid() do
			p = p:GetParent()
		end
		return p
	end

	local VertVec = Vector(0,0,1)
	local function GetUpwards(forwards)
		return forwards:Cross(VertVec):Cross(forwards):GetNormalized()
	end

	local MaxDistance = ACF.LinkDistance ^ 2
	local UnlinkSound = "physics/metal/metal_box_impact_bullet%s.wav"

	function ENT:Think()
		-- Check links on this entity
		local AllLinks = self.AllLinks
		if next(AllLinks) then
			local Pos = self:GetPos()
			for Link in pairs(AllLinks) do
				-- Check distance limit and common ancestry
				local OutOfRange = Pos:DistToSqr(Link:GetPos()) > MaxDistance
				local DiffAncestors = (GetAncestor(self) ~= GetAncestor(Link))
				if OutOfRange or DiffAncestors then
					local Sound = UnlinkSound:format(math.random(1, 3))
					Link:EmitSound(Sound, 70, 100, ACF.Volume)
					self:EmitSound(Sound, 70, 100, ACF.Volume)
					self:Unlink(Link)
					Link:Unlink(self)
				end

				-- Unlink from stuff that died
				if not IsValid(Link) then self:Unlink(Link) end
			end
		end

		-- Check lean angle (If crew have no ancestor this won't update)
		local Ancestor = GetAncestor(self)
		if Ancestor ~= self then
			-- Determine deviation between baseplate upwards and crew upwards in degrees
			local BaseUp = GetUpwards(Ancestor:GetForward())
			local CrewUp = self:GetUp()
			local LeanAngle = math.Round(math.deg(math.acos(BaseUp:Dot(CrewUp) / (BaseUp:Length() * CrewUp:Length()))),2)

			-- Update overlay if lean angle changes
			if self.LeanAngle ~= LeanAngle then
				self.LeanAngle = LeanAngle
				self:UpdateOverlay()
			end
		end

		self:NextThink(Clock.CurTime + 1 + math.Rand(1,2))
		return true
	end
end

-- Linkage Related
do
	--- Starts a net message and sends an array of entities using counts
	local function BroadcastEntities(name,entity,tbl,bits)
		print(name,entity,bits)
		net.Start(name)
		net.WriteEntity(entity)
		net.WriteInt(#tbl, bits)
		for _,v in ipairs(tbl) do
			net.WriteEntity(v)
		end
		net.Broadcast()
	end

	local function LinkCrew(Target, CrewEnt)
		if not Target.Crew then Target.Crew = {} end -- Safely make sure the link target has a crew list
		if Target.Crew[CrewEnt] then return false, "This entity is already linked to this crewmate!" end
		if CrewEnt.TargetLinks[Target] then return false, "This entity is already linked to this crewmate!" end

		Target.Crew[CrewEnt] = true
		CrewEnt.TargetLinks[Target] = true
		CrewEnt.AllLinks[Target] = true

		BroadcastEntities("ACF_Crew_Links", CrewEnt, table.GetKeys(CrewEnt.TargetLinks), 8)
		if Target.CheckCrew then Target:CheckCrew() end
		if Target.UpdateOverlay then Target:UpdateOverlay() end
		CrewEnt:UpdateOverlay()

		return true, "Crewmate linked successfully"
	end

	local function UnlinkCrew(Target, CrewEnt)
		if Target.Crew[CrewEnt] or CrewEnt.TargetLinks[Target] then
			Target.Crew[CrewEnt] = nil
			CrewEnt.TargetLinks[Target] = nil
			CrewEnt.AllLinks[Target] = nil

			BroadcastEntities("ACF_Crew_Links", CrewEnt, table.GetKeys(CrewEnt.TargetLinks), 8)
			if Target.CheckCrew then Target:CheckCrew() end
			if Target.UpdateOverlay then Target:UpdateOverlay() end
			CrewEnt:UpdateOverlay()

			return true, "Crewmate unlinked successfully!"
		end
		return false, "This acf entity is not linked to this crewmate."
	end

	--- Register basic linkages from crew to guns, engines
	for k,v in ipairs({"acf_gun","acf_engine","prop_vehicle_prisoner_pod", "acf_turret"}) do
		ACF.RegisterClassLink(v, "acf_crew", function(Target, Crew) return LinkCrew(Target, Crew) end)
		ACF.RegisterClassUnlink(v, "acf_crew", function(Target, Crew) return UnlinkCrew(Target, Crew) end)
	end

	-- Crew -> Crew linkage handling
	ACF.RegisterClassLink("acf_crew","acf_crew", function(From,To)
		print(string.format("Link: [%s] -> [%s]",From,To))

		-- Safely add the new crew
		if not table.HasValue(To.ReplaceLinksOrdered, From) then
			table.insert(To.ReplaceLinksOrdered, From)
			BroadcastEntities("ACF_Crew_Reps", To, To.ReplaceLinksOrdered, 8)

			To.ReplaceLinks[From] = true
			To.AllLinks[From] = true

			To:UpdateOverlay()
			From:UpdateOverlay()
			return true, "Crew replacement added!"
		end
		return false, "Crew replacement already exists."
	end)

	ACF.RegisterClassUnlink("acf_crew","acf_crew", function(From,To)
		print(string.format("UnLink: [%s] -> [%s]",From,To))
		if table.HasValue(To.ReplaceLinksOrdered, From) then
			table.RemoveByValue(To.ReplaceLinksOrdered, From)
			BroadcastEntities("ACF_Crew_Reps", To, To.ReplaceLinksOrdered, 8)

			To.ReplaceLinks[From] = nil
			To.AllLinks[From] = nil

			To:UpdateOverlay()
			From:UpdateOverlay()
			return true, "Crew replacement removed!"
		end
		return false, "Crew replacement already removed."
	end)
end

-- Adv Dupe 2 Related
do
	function ENT:PreEntityCopy()
		if next(self.TargetLinks) then
			local Entities = {}
			for Ent in pairs(self.TargetLinks) do
				Entities[#Entities + 1] = Ent:EntIndex()
			end
			duplicator.StoreEntityModifier(self, "CrewTargetLinks", Entities)
		end

		if next(self.ReplaceLinksOrdered) then
			local Entities = {}
			for _, Ent in ipairs(self.ReplaceLinksOrdered) do
				Entities[#Entities + 1] = Ent:EntIndex()
			end
			duplicator.StoreEntityModifier(self, "CrewReplacementLinks", Entities)
		end

		print("PreCopy CrewTypeID: ", self.CrewType.ID)
		duplicator.StoreEntityModifier(self, "CrewTypeID", {self.CrewType.ID})

		-- Wire dupe info
		self.BaseClass.PreEntityCopy(self)
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		local EntMods = Ent.EntityMods

		-- Note: Since this happens *after* the entity is made, it relies on the entity to 
		print("PostCopy CrewTypeID: ",EntMods.CrewTypeID[1])
		if EntMods.CrewTypeID then
			self.CrewType = CrewTypes.Get(EntMods.CrewTypeID[1])
		end

		if EntMods.CrewTargetLinks then
			for _, EntID in pairs(EntMods.CrewTargetLinks) do
				self:Link(CreatedEntities[EntID])
			end

			EntMods.CrewTargetLinks = nil
		end

		if EntMods.CrewReplacementLinks then
			for _, EntID in ipairs(EntMods.CrewReplacementLinks) do
				CreatedEntities[EntID]:Link(self)
			end
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

		for ent in pairs(self.AllLinks) do
			self:Unlink(ent)
		end
	end
end