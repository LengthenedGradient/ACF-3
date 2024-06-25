DEFINE_BASECLASS("acf_base_simple")

include("shared.lua")

language.Add("Cleanup_acf_crew", "ACF Crewmates")
language.Add("Cleaned_acf_crew", "Cleaned up all ACF Crewmates")
language.Add("SBoxLimit__acf_crew", "You've reached the ACF Crewmate limit!")


local JobLinks = {}
net.Receive("ACF_Crew_Jobs_Update",function() 
    JobLinks = net.ReadTable(true)
end)

function ENT:Initialize(...)
    BaseClass.Initialize(self, ...)
end

function ENT:Draw(...)
    BaseClass.Draw(self, ...)
end

function ENT:DrawOverlay() 
    for k,v in ipairs(JobLinks) do
        local p1 = self:WorldSpaceCenter()
        local p2 = v:WorldSpaceCenter()
        local p1s = p1:ToScreen()
        local p2s = p2:ToScreen()
        render.DrawLine(p1, p2, Color( 255, 0, 0 ))
        draw.SimpleTextOutlined(k, "ACF_Control", p1s.x, p1s.y, Color( 255, 255, 0 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
    end
end