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
local TraceHull = util.TraceHull
local TimerSimple	= timer.Simple

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
	return res.Fraction, length, truelength, res.HitPos
end

local function iterScan(ent, reps)
	local localoffset = ent.CrewModel.OffsetL
	local center = ent:LocalToWorld(localoffset)
	local count = ent.ScanCount

	-- Iterate reps times and iterate over time
	for i = 1, reps do
		local index = ent.ScanIndex
		local disp = ent.ScanDisplacements[index]
		local p1 = center
		local p2 = ent:LocalToWorld(localoffset + disp*50)
		local frac, _, _, hitpos= traceVisHullCube(p1, p2, Vector(6,6,6), ent)
		debugoverlay.Line(p1,hitpos,1,Color(255,0,0))
		ent.ScanLengths[index] = frac

		index = index  + 1
		if index > count then index = 1 end
		ent.ScanIndex = index
	end

	-- Update based on old values
	local sum = 0
	for i = 1, count do
		sum = sum + ent.ScanLengths[i]
	end
	print(sum)
	return sum / count
end

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
		Entity.ACF = Entity.ACF or {}
		Entity.ACF.Model = Crew.Model

		Entity:SetModel(Crew.Model)

		Entity:PhysicsInit(SOLID_VPHYSICS)
		Entity:SetMoveType(MOVETYPE_VPHYSICS)

		-- Loads Entity.CrewTypeID from Data
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

		Entity.ACF.LegalMass = Class.Mass -- TODO: Still necessary?
		Entity.ACF.Model = Crew.Model

		ACF.Activate(Entity, true)

		local PhysObj = Entity.ACF.PhysObj
		if IsValid(PhysObj) then
			Contraption.SetMass(Entity, Class.Mass)
		end

		if Entity.OnUpdate then
			Entity:OnUpdate(Data, Class, Crew)
		end

		Entity:UpdateOverlay(true)
	end

	function MakeCrew(Player, Pos, Angle, Data)
		VerifyData(Data)

		local Class = Classes.GetGroup(Components, "CrewModels")
		local CrewModel = Components.GetItem(Class.ID, Data.CrewModel)
		local CrewType = CrewTypes.Get(Data.CrewTypeID)

		local Limit = Class.LimitConVar.Name
		if not Player:CheckLimit(Limit) then return false end

		local CanSpawn	= HookRun("ACF_PreEntitySpawn", "acf_crew", Player, Data, Class)
		if CanSpawn == false then return false end

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

		Entity.ClassData = Class
		Entity.CrewModel = CrewModel
		Entity.CrewType = CrewType
		Entity.CrewTypeID = Data.CrewTypeID

		Entity.LeanAngle = 0

		-- Initialize scanning related and update lengths for all directions in one pass
		Entity.ScanDisplacements, Entity.ScanLengths, Entity.ScanCount = Class.GenerateScanSetup()
		Entity.ScanIndex = 1 -- Index of current distance to update
		Entity.ScanFraction = iterScan(Entity,Entity.ScanCount)

		UpdateCrew(Entity, Data, Class, CrewModel)

		if Class.OnSpawn then
			Class.OnSpawn(Entity, Data, Class, CrewModel)
		end

		hook.Run("ACF_OnEntitySpawn", "acf_crew", Entity, Data, Class, CrewModel)

		WireLib.TriggerOutput(Entity, "Entity", Entity)

		Entity:UpdateOverlay(true)

		CheckLegal(Entity)

		return Entity
	end

	Entities.Register("acf_crew", MakeCrew, "CrewTypeID")

	-- TODO: Determine sources
	ACF.RegisterLinkSource("acf_gun", "Crew")
	ACF.RegisterLinkSource("acf_engine", "Crew")
	ACF.RegisterLinkSource("acf_turret", "Crew")

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
		local Health = math.Round(self.ACF.Health / self.ACF.MaxHealth * 100)
		str = string.format("Health: %s HP\nRole: %s\nLean Angle: %s", Health, self.CrewType.ID, self.LeanAngle)
		if self.CrewType.ShouldScan then
			str = str .. "\nErgonomics: " .. math.Round(self.ScanFraction,2)
		end
		return str
	end
end

-- Entity methods
do
	-- Think logic (mostly checks and stuff that updates frequently)
	local MaxDistance = ACF.LinkDistance ^ 2
	local UnlinkSound = "physics/metal/metal_box_impact_bullet%s.wav"

	function ENT:Think()
		-- Check links on this entity
		local AllLinks = self.AllLinks
		if next(AllLinks) then
			local Pos = self:GetPos()
			for Link in pairs(AllLinks) do
				-- If the link is invalid, remove it and skip it
				if not IsValid(Link) then self:Unlink(Link) continue end

				-- Check distance limit and common ancestry
				local OutOfRange = Pos:DistToSqr(Link:GetPos()) > MaxDistance
				-- #TODO: FIX
				-- local DiffAncestors = self:GetAncestor() ~= Link:GetAncestor()
				if OutOfRange or DiffAncestors then
					local Sound = UnlinkSound:format(math.random(1, 3))
					Link:EmitSound(Sound, 70, 100, ACF.Volume)
					self:EmitSound(Sound, 70, 100, ACF.Volume)
					self:Unlink(Link)
					Link:Unlink(self)
				end
			end
		end

		-- Check world lean angle and update ergonomics
		local LeanDot = Vector(0,0,1):Dot(self:GetUp())
		self.LeanAngle = math.Round(math.deg(math.acos(LeanDot)),2)

		-- Update space ergonomics if needed
		if self.CrewType.ShouldScan then
			self.ScanFraction = iterScan(self,self.CrewType.ScanStep or 1)
		end

		self:UpdateOverlay()
		self:NextThink(Clock.CurTime + 1 + math.Rand(1,2))
		return true
	end

	function ENT:ACF_Activate(Recalc)
		local PhysObj = self.ACF.PhysObj
		local Mass    = PhysObj:GetMass()
		local Area    = PhysObj:GetSurfaceArea() * ACF.InchToCmSq
		local Armour  = 5 -- Human body isn't that thick but we have to put something here
		local Health  = 100
		local Percent = 1

		if Recalc and self.ACF.Health and self.ACF.MaxHealth then
			Percent = self.ACF.Health / self.ACF.MaxHealth
		end

		self.ACF.Area      = Area
		self.ACF.Health    = Health * Percent
		self.ACF.MaxHealth = Health
		self.ACF.Armour    = Armour * Percent
		self.ACF.MaxArmour = Armour
		self.ACF.Type      = "Prop"
	end

	function ENT:ACF_OnDamage(DmgResult, DmgInfo)
		local Health = self.ACF.Health
		local HitRes = DmgResult:Compute()

		HitRes.Kill = false

		-- Prevent entity from being destroyed (clamp health)
		local NewHealth = math.max(0, Health - HitRes.Damage)

		self.ACF.Health = NewHealth
		self.ACF.Armour = self.ACF.MaxArmour * (NewHealth / self.ACF.MaxHealth)

		-- If we reach 0, replace the crew with the next one
		if NewHealth == 0 and not self.ToBeReplaced then
			-- self.ToBeReplaced will be initialized here if not already (since it wont be used elsewhere in the code, partial initialization is fine.)
			self.ToBeReplaced = true

			print("Dead; Switching Crew")
			EmitSound( "death_bell.wav", self:GetPos())

			TimerSimple(3, function()
				self.ToBeReplaced = false

				-- Search for the first valid and alive crew
				for k,v in ipairs(self.ReplaceLinksOrdered) do
					if IsValid(v) and v.ACF.Health and v.ACF.Health > 0 then
						-- Swapping healths is effectively the same thing as swapping positions (assuming proficiency not lost)
						self.ACF.Health, v.ACF.Health = v.ACF.Health, self.ACF.Health
						self.ACF.Armour = self.ACF.MaxArmour * (self.ACF.Health / self.ACF.MaxHealth)
						v.ACF.Armour = v.ACF.MaxArmour * (v.ACF.Health / v.ACF.MaxHealth)
					end
				end
			end)
		end

		self:UpdateOverlay()

		return HitRes
	end

	function ENT:ACF_OnRepaired(OldArmor, OldHealth, Armor, Health) -- Normally has OldArmor, OldHealth, Armor, and Health passed
		-- Dead crew should not be revivable
		if OldArmor == 0 then self.ACF.Armour = 0 end
		if OldHealth == 0 then self.ACF.Health = 0 end

		self.ACF.Armour = self.ACF.MaxArmour * (self.ACF.Health / self.ACF.MaxHealth)
		self:UpdateOverlay()
	end
end

-- Linkage Related
do
	--- Starts a net message and sends an array of entities using counts
	local function BroadcastEntities(name,entity,tbl,bits)
		print(name,entity,bits)
		PrintTable(tbl)
		net.Start(name)
		net.WriteEntity(entity)
		net.WriteInt(#tbl, bits)
		for _,v in ipairs(tbl) do
			print("Send",v,IsValid(v))
			net.WriteEntity(v)
		end
		net.Broadcast()
	end

	local function LinkCrew(Target, CrewEnt)
		if not Target.Crew then Target.Crew = {} end -- Safely make sure the link target has a crew list

		-- Early returns
		if Target.Crew[CrewEnt] then return false, "This entity is already linked to this crewmate!" end
		if CrewEnt.TargetLinks[Target] then return false, "This entity is already linked to this crewmate!" end
		if not CrewEnt.CrewType.Whitelist[Target:GetClass()] then return false, "This entity cannot be linked with this occupation" end

		Target.Crew[CrewEnt] = true
		CrewEnt.TargetLinks[Target] = true
		CrewEnt.AllLinks[Target] = true

		-- Update overlay and client side info
		BroadcastEntities("ACF_Crew_Links", CrewEnt, table.GetKeys(CrewEnt.TargetLinks), 8)
		if Target.CheckCrew then Target:CheckCrew() end
		if Target.UpdateOverlay then Target:UpdateOverlay() end
		CrewEnt:UpdateOverlay()

		return true, "Crewmate linked successfully"
	end

	local function UnlinkCrew(Target, CrewEnt)
		if Target.Crew[CrewEnt] and CrewEnt.TargetLinks[Target] then
			Target.Crew[CrewEnt] = nil
			CrewEnt.TargetLinks[Target] = nil
			CrewEnt.AllLinks[Target] = nil

			-- Update overlay and client side info
			BroadcastEntities("ACF_Crew_Links", CrewEnt, table.GetKeys(CrewEnt.TargetLinks), 8)
			if Target.CheckCrew then Target:CheckCrew() end
			if Target.UpdateOverlay then Target:UpdateOverlay() end
			CrewEnt:UpdateOverlay()

			return true, "Crewmate unlinked successfully!"
		end
		return false, "This acf entity is not linked to this crewmate."
	end

	--- Register basic linkages from crew to guns, engines
	for k,v in ipairs({"acf_gun","acf_engine", "acf_turret"}) do
		ACF.RegisterClassLink(v, "acf_crew", function(Target, Crew) return LinkCrew(Target, Crew) end)
		ACF.RegisterClassUnlink(v, "acf_crew", function(Target, Crew) return UnlinkCrew(Target, Crew) end)
	end

	-- Crew -> Crew linkage handling
	ACF.RegisterClassLink("acf_crew","acf_crew", function(From,To)
		print(string.format("Link: [%s] -> [%s]",From,To))

		-- Safely add the new crew
		if not table.HasValue(To.ReplaceLinksOrdered, From) then
			table.insert(To.ReplaceLinksOrdered, From)
			To.ReplaceLinks[From] = true
			To.AllLinks[From] = true

			BroadcastEntities("ACF_Crew_Reps", To, To.ReplaceLinksOrdered, 8)

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
			To.ReplaceLinks[From] = nil
			To.AllLinks[From] = nil

			print("replacement")

			BroadcastEntities("ACF_Crew_Reps", To, To.ReplaceLinksOrdered, 8)

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
		if next(self.ReplaceLinksOrdered) then
			local Entities = {}
			for _, Ent in ipairs(self.ReplaceLinksOrdered) do
				Entities[#Entities + 1] = Ent:EntIndex()
			end
			duplicator.StoreEntityModifier(self, "CrewReplacementLinks", Entities)
		end

		if next(self.TargetLinks) then
			local Entities = {}
			for Ent in pairs(self.TargetLinks) do
				Entities[#Entities + 1] = Ent:EntIndex()
			end
			duplicator.StoreEntityModifier(self, "CrewTargetLinks", Entities)
		end

		-- Wire dupe info
		self.BaseClass.PreEntityCopy(self)
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		local EntMods = Ent.EntityMods

		if EntMods.CrewReplacementLinks then
			for _, EntID in ipairs(EntMods.CrewReplacementLinks) do
				CreatedEntities[EntID]:Link(self)
			end
		end

		if EntMods.CrewTargetLinks then
			for _, EntID in pairs(EntMods.CrewTargetLinks) do
				self:Link(CreatedEntities[EntID])
			end

			EntMods.CrewTargetLinks = nil
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

		-- WireLib.Remove(self)
	end
end