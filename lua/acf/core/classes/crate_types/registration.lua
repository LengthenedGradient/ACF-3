local Classes = ACF.Classes
local CrateTypes   = Classes.CrateTypes
local Entries = {}


function CrateTypes.Register(ID, Data)
	local Group = Classes.AddGroup(ID, Entries, Data)
	return Group
end

function CrateTypes.RegisterItem(ID, ClassID, Data)
	local Class = Classes.AddGroupItem(ID, ClassID, Entries, Data)
	return Class
end

Classes.AddGroupedFunctions(CrateTypes, Entries)