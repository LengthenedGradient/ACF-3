--[[
	Order is used as a member for sorting when loading into comboboxes.
]]

local Classes = ACF.Classes
local CrateTypes   = Classes.CrateTypes

CrateTypes.Register("AMMO_CRATE_CONTAINER", {
	Order = 1,
	Name = "Scaleable Ammo Box",
	Description = "Standard ammunition stowage. For use with manual loaders only.",
})

CrateTypes.Register("AMMO_CRATE_CAROUSEL", {
	Order = 2,
	Name = "Carousel Ammo Box",
	Description = "Mechanized ammunition stowage. Often found on eastern T-series tanks.",
})

CrateTypes.Register("AMMO_CRATE_CASETTE", {
	Order = 3,
	Name = "Casette Ammo Box",
	Description = "Mechanized ammunition stowage. Often found on western bustle autoloaders",
})

do -- Registering containers
	CrateTypes.RegisterItem("DEFAULT", "AMMO_CRATE_CONTAINER", {
		Order = 1,
		Name = "Default Container",
		Description = "Description LOL",
		Model = "models/holograms/rcube_thin.mdl",
		Material = "phoenix_storms/Future_vents"
	})
end

do -- Registering Carousels
	CrateTypes.RegisterItem("DEFAULT", "AMMO_CRATE_CAROUSEL", {
		Order = 1,
		Name = "Default Carousel",
		Description = "Description LOL",
		Model = "models/hunter/tubes/circle2x2.mdl",
		Material = "phoenix_storms/Future_vents"
	})
end

do -- Registering Casettes
	CrateTypes.RegisterItem("DEFAULT", "AMMO_CRATE_CASETTE", {
		Order = 1,
		Name = "Default Casette",
		Description = "Description LOL",
		Model = "models/holograms/cube.mdl",
		Material = "phoenix_storms/Future_vents"
	})
	CrateTypes.RegisterItem("DRUM", "AMMO_CRATE_CASETTE", {
		Order = 2,
		Name = "Revolver Drum Casette",
		Description = "Description LOL",
		Model = "models/hunter/tubes/circle2x2.mdl",
		Material = "phoenix_storms/Future_vents"
	})
end