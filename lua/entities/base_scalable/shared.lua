DEFINE_BASECLASS("base_wire_entity")

ENT.PrintName      = "Base Scalable Entity"
ENT.WireDebugName  = "Base Scalable Entity"
ENT.Contact        = "Don't"
ENT.IsScalable     = true
ENT.UseCustomIndex = true

-- Used for storing data about a model mesh for use with scaling
ENT.ScaleData      = { Type = false, Path = false }

--- Initializes the ScaleData property for a given entity (stored under self.ScaleData)  
--- @param Type string The type to use (e.g. "Model") (unclear what else can be used here)
--- @param Path string The path to the model
--- @see ENT.GetModelMesh
--- @see ENT.GetModelSize
function ENT:SetScaleData(Type, Path)
	local Data = self.ScaleData

	Data.Type    = Type
	Data.Path    = Path
	Data.GetMesh = self["Get" .. Type .. "Mesh"] -- Usually self.GetModelMesh
	Data.GetSize = self["Get" .. Type .. "Size"] -- Usually self.GetModelSize
end

--- Returns the size of the entity (retrieved self.Size)
--- @return vector Size
function ENT:GetSize()
	local Size = self.Size

	if Size then
		return Vector(Size)
	end
end

--- Returns the scale of the entity (retrieved from self.Scale)
--- @return vector Size
function ENT:GetScale()
	local Scale = self.Scale

	if Scale then
		return Vector(Scale)
	end
end

--- Restores the entity to its original scale
function ENT:Restore()
	self:SetScale(self:GetScale())
end

do -- Model-based scalable entity methods
	-- When calling Ent.ScaleData.GetModelMesh or GetModelSize, these will be used.
	local ModelData = ACF.ModelData

	--- Returns the model's mesh at a given scale  
	--- @param Data table An entity's ScaleData table (see ENT.ScaleData)
	--- @param Scale (number | vector | nil) The scale to calculate the mesh at (if not specified, the original scale is used)
	--- @return {Mesh:table, Volume:number, Center:vector, Size:vector} # The model's mesh data
	function ENT.GetModelMesh(Data, Scale)
		return ModelData.GetModelMesh(Data.Path, Scale)
	end

	--- Returns the model's size at a given scale  
	--- @param Data table An entity's ScaleData table (see ENT.ScaleData)
	--- @param Scale (number | vector | nil) The scale to calculate the mesh at (if not specified, the original scale is used)
	--- @return vector # The model's mesh size
	function ENT.GetModelSize(Data, Scale)
		return ModelData.GetModelSize(Data.Path, Scale)
	end
end

do -- Custom entity scaling methods
	function ENT.GetCylinderMesh(Data, Scale)
		if isnumber(Scale) then Scale = Vector(Scale,Scale,Scale) end -- Make sure we have a vector

		local points = {}
		local fidelity = 16
		for i = 1, fidelity do
			local t = math.pi*2 / fidelity * i
			local cos = Scale.x/2 + math.cos(t) * Scale.x
			local sin = Scale.y/2 + math.sin(t) * Scale.y

			table.insert(points, Vector(cos, sin, 0))
			table.insert(points, Vector(cos, sin, Scale.z))
		end

		return points
	end

	function ENT.GetCylinderSize(Data, Scale) 
		local Scale = not Scale and 1 or Scale
		return Vector(Scale, Scale, Scale)
	end
end

-- Dirty, dirty hacking to prevent other addons initializing physics the wrong way
-- Required for stuff like Proper Clipping resetting the physics object when clearing out physclips (This part might not be true as of now)
do
	local EntMeta = FindMetaTable("Entity")

	function ENT:PhysicsInit(Solid, Bypass, ...)
		if Bypass then
			return EntMeta.PhysicsInit(self, Solid, Bypass, ...)
		end

		local Init = self.FirstInit

		if not Init then
			self.FirstInit = true
		end

		if Init or CLIENT then
			self:Restore()

			return true
		end
	end
end
