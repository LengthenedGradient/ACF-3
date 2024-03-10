DEFINE_BASECLASS("acf_base_simple")

include("shared.lua")

language.Add("Cleanup_acf_crew", "ACF Crewmates")
language.Add("Cleaned_acf_crew", "Cleaned up all ACF Crewmates")
language.Add("SBoxLimit__acf_crew", "You've reached the ACF Crewmate limit!")

function ENT:Initialize(...)
    BaseClass.Initialize(self, ...)
end

function ENT:Draw(...)
    BaseClass.Draw(self, ...)
end