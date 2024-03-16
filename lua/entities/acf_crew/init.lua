AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

--===============================================================================================--
-- Local Funcs and Vars
--===============================================================================================--
local HookRun     = hook.Run
local Utilities   = ACF.Utilities
local Clock       = Utilities.Clock
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
			Data.Crew = "CRW-SIT" -- Driver default

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

		Entity.ACF.LegalMass = Class.Mass
		Entity.ACF.Model = Crew.Model

		local Phys = Entity:GetPhysicsObject()
		if IsValid(Phys) then Phys:SetMass(Class.Mass) end

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
		Entity.CrewType = ""

		UpdateCrew(Entity, Data, Class, Crew)

		if Class.OnSpawn then
			Class.OnSpawn(Entity, Data, Class, Crew)
		end

		hook.Run("ACF_OnEntitySpawn", "acf_crew", Entity, Data, Class, Crew)

		WireLib.TriggerOutput(Entity, "Entity", Entity)

		Entity:UpdateOverlay(true)

		CheckLegal(Entity)

		local x = Vector( 5, 5, 5 )
		hook.Add( "PostDrawTranslucentRenderables", "Boxxie", function()
			local pos = LocalPlayer():GetEyeTrace().HitPos -- position to render box at
	
			render.SetColorMaterial() -- white material for easy coloring
	
			cam.IgnoreZ( true ) -- makes next draw calls ignore depth and draw on top
			render.DrawBox( pos, angle_zero, x, -x, color_white ) -- draws the box 
			cam.IgnoreZ( false ) -- disables previous call
		end )

		return Entity
	end

	Entities.Register("acf_crew", Makeacf_Crew, "Crew")

	ACF.RegisterLinkSource("acf_gun", "Crew")
end

do
	local MaxDistance = ACF.LinkDistance * ACF.LinkDistance
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

		self:NextThink(Clock.CurTime + 1 + math.Rand(1,2))

		return true
	end
end

do
	function CalcFreeSpace(Crew, L, W, H)
		-- local Forward = 

	end


end


do
	function LinkCrew(Target, CrewEnt)
		if not Target.Crew then Target.Crew = {} end
		if Target.Crew[CrewEnt] then return false, "This entity is already linked to this crewmate!" end
		if CrewEnt.Links[Crew] then return false, "This entity is already linked to this crewmate!" end

		Target.Crew[CrewEnt] = true
		CrewEnt.Links[Target] = true

		local LUT = {
			acf_engine = "Driver",
			acf_gun = "Loader",
			acf_turret = "Gunner",
			prop_vehicle_prisoner_pod = "Commander",
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
		return false, "This weapon is not linked to this crewmate."
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
end

do -- Overlay Update
	function ENT:UpdateOverlayText()
		return "Crew Type: " .. self.CrewType
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
