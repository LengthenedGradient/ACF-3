--[[
	This file deals with creating a pointer entity for use with physobj calculations, and provides some library functions dealing with physobjects and models.
]]

local ACF       = ACF
local ModelData = ACF.ModelData
local Models    = ModelData.Models
local Network   = ACF.Networking

do -- Pointer entity creation
	local function Create()
		debug.Trace()

		if IsValid(ModelData.Entity) then return end -- No need to create it if it already exists

		local Entity = ents.Create("base_entity")

		if not IsValid(Entity) then return print("[SERVER] Failed to create ModelData entity") end

		-- Makes sure the entity is always networked
		function Entity:UpdateTransmitState()
			return TRANSMIT_ALWAYS -- "Always transmit the entity"
		end

		-- Setup initial 
		Entity:SetModel("models/props_junk/popcan01a.mdl")
		Entity:PhysicsInit(SOLID_VPHYSICS) -- "Uses the PhysObjects of the entity."
		Entity:SetMoveType(MOVETYPE_NONE) -- "Don't move"
		Entity:SetCollisionGroup(COLLISION_GROUP_WORLD) -- "Doesn't collide with players/props"
		Entity:SetNotSolid(true)
		Entity:SetNoDraw(true)
		Entity:Spawn()

		Entity:AddEFlags(EFL_FORCE_CHECK_TRANSMIT) -- Force the engine to transmit the entity even if a model isn't set 

		-- Whenever the entity is removed for whatever reason, recreate it.
		Entity:CallOnRemove("ACF_ModelData", function()
			hook.Add("Think", "ACF_ModelData_Entity", function()
				Create()
				hook.Remove("Think", "ACF_ModelData_Entity")
			end)
		end)

		Network.Broadcast("ACF_ModelData_Entity", Entity) -- Broadcast the entity to all clients

		ModelData.Entity = Entity
	end

	-- Serverside, this runs when all special/map entities are initialized. This way our pointer entity can be created safely and any subsequent entities wont override it.
	hook.Add("InitPostEntity", "ACF_ModelData", function()
		Create()
		hook.Remove("InitPostEntity", "ACF_ModelData")
	end)

	-- Runs when the player is loaded and it's safe to send net messages
	hook.Add("ACF_OnPlayerLoaded", "ACF_ModelData", function(Player)
		Network.Send("ACF_ModelData_Entity", Player, ModelData.Entity) -- (We could've made another pointer on client but sending this one is simpler.)
	end)

	-- Called whenever the Lua environment is about to be shut down, for example on map change, or when the server is going to shut down.
	-- This just prevents the entity from being recreated repeatedly as the server shuts down
	hook.Add("ShutDown", "ACF_ModelData", function()
		local Entity = ModelData.Entity

		if not IsValid(Entity) then return end

		Entity:RemoveCallOnRemove("ACF_ModelData") -- Removes the callback used in "CallOnRemove"
	end)
end

do -- Model data getter method
	local util = util

	--- Initializes (or overrides) a physics object for Modeldata.Entity, given a model
	--- @param Model string The model to use
	--- @return physobj # The created physics object
	local function CreatePhysObj(Model)
		util.PrecacheModel(Model) -- Cache the model for faster loading later

		local Entity = ModelData.Entity

		Entity:SetModel(Model)
		Entity:PhysicsInit(SOLID_VPHYSICS)

		return Entity:GetPhysicsObject()
	end

	--- Flattens the mesh from a list of hulls to a list of vertices  
	--- PhysObj:GetMeshConvexes() will return a list of hulls, which themselves contain vertices. This funtion returns a flattened version of that mesh.  
	--- @param PhysObj physobj The physics object to get a mesh from
	--- @return table # The flattened mesh data
	local function SanitizeMesh(PhysObj)
		local Mesh = PhysObj:GetMeshConvexes()

		for I, Hull in ipairs(Mesh) do
			for J, Vertex in ipairs(Hull) do
				Mesh[I][J] = Vertex.pos
			end
		end

		return Mesh
	end

	-------------------------------------------------------------------

	--- Returns data about the model's mesh   
	--- Internally creates a physobj via CreatePhysObj
	--- @param Model any The path to the model
	--- @return {Mesh:table, Volume:vector, Center:vector, Size:vector} # The data of the mesh
	function ModelData.GetModelData(Model)
		local Path = ModelData.GetModelPath(Model)

		if not Path then return end

		local Data = Models[Path]

		if Data then return Data end

		local PhysObj = CreatePhysObj(Path)

		if not IsValid(PhysObj) then return end

		local Min, Max = PhysObj:GetAABB()

		Data = {
			Mesh   = SanitizeMesh(PhysObj),
			Volume = PhysObj:GetVolume(),
			Center = (Min + Max) * 0.5,
			Size   = Max - Min,
		}

		Models[Path] = Data

		return Data
	end
end


hook.Add("ACF_OnLoadAddon", "ACF_ModelData", function()
	Network.CreateSender("ACF_ModelData_Entity", function(Queue, Entity)
		Queue.Index = Entity:EntIndex()
	end)

	Network.CreateReceiver("ACF_ModelData", function(Player, Data)
		for Model in pairs(Data) do
			Network.Send("ACF_ModelData", Player, Model)
		end
	end)

	Network.CreateSender("ACF_ModelData", function(Queue, Model)
		Queue[Model] = ModelData.GetModelData(Model)
	end)

	hook.Remove("ACF_OnLoadAddon", "ACF_ModelData")
end)
