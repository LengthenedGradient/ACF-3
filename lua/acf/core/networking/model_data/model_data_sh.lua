local ACF       = ACF
local ModelData = ACF.ModelData
local isnumber  = isnumber
local isvector  = isvector
local isstring  = isstring
local IsUseless = IsUselessModel

--- Checks if a scale is a valid number of vector
--- @param Scale any The scale to check
--- @return boolean # Whether the scale is valid
local function IsValidScale(Scale)
	if not Scale then return false end

	return isnumber(Scale) or isvector(Scale)
end

--- Returns a copy of the mesh after scaling it up
--- @param Mesh table The mesh data
--- @param Scale number The scale
--- @return table # The scaled up mesh copy
local function CopyMesh(Mesh, Scale)
	local Result = {}

	for I, Hull in ipairs(Mesh) do
		local Current = {}

		for J, Vertex in ipairs(Hull) do
			Current[J] = Vertex * Scale
		end

		Result[I] = Current
	end

	return Result
end

--- Returns the volume of a given mesh  
--- Internally calls the wrapper ENT:PhysicsInitMultiConvex, which will override the current physics object with a new one representing the inputted mesh
--- @param Mesh table The mesh to get the volume of
--- @return number # The volume of the mess
local function GetVolume(Mesh)
	local Entity = ModelData.Entity

	Entity:PhysicsInitMultiConvex(Mesh)

	local PhysObj = Entity:GetPhysicsObject()

	return PhysObj:GetVolume()
end

-------------------------------------------------------------------

--- Trims and lowercases a model path string (sanitization)
--- @param Model string The path to the model
--- @return string # The sanitized model path
function ModelData.GetModelPath(Model)
	if not isstring(Model) then return end
	if IsUseless(Model) then return end

	return Model:Trim():lower()
end

--- Returns a copy of a model's mesh at a different scale
--- @param Model string The path to the model
--- @param Scale number | vector | nil The scale of the data (passing nil keeps the original scale)
--- @return table # The scaled up mesh data
function ModelData.GetModelMesh(Model, Scale)
	local Data = ModelData.GetModelData(Model)
	if not Data then return end
	if not IsValidScale(Scale) then Scale = 1 end

	return CopyMesh(Data.Mesh, Scale)
end

--- Returns the volume of a model at a given scale
--- @param Model string The path to the model
--- @param Scale number | vector | nil The scale of the data (passing nil keeps the original scale) 
--- @return number # The volume of the model
function ModelData.GetModelVolume(Model, Scale)
	local Data = ModelData.GetModelData(Model)

	if not Data then return end
	if not IsValidScale(Scale) then
		return Data.Volume
	end

	local Mesh = CopyMesh(Data.Mesh, Scale)

	return GetVolume(Mesh)
end

--- Returns the center of a model at a given scale
--- @param Model string The path to the model
--- @param Scale number | vector | nil The scale of the data (passing nil keeps the original scale) 
--- @return number # The center of the model
function ModelData.GetModelCenter(Model, Scale)
	local Data = ModelData.GetModelData(Model)

	if not Data then return end
	if not IsValidScale(Scale) then Scale = 1 end

	return Data.Center * Scale
end

--- Returns the size of a model at a given scale
--- @param Model string The path to the model
--- @param Scale number | vector | nil The scale of the data (passing nil keeps the original scale) 
--- @return number # The size of the model
function ModelData.GetModelSize(Model, Scale)
	local Data = ModelData.GetModelData(Model)

	if not Data then return end
	if not IsValidScale(Scale) then Scale = 1 end

	return Data.Size * Scale
end
