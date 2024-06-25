DEFINE_BASECLASS("acf_base_simple")

include("shared.lua")

language.Add("Cleanup_acf_crew", "ACF Crewmates")
language.Add("Cleaned_acf_crew", "Cleaned up all ACF Crewmates")
language.Add("SBoxLimit__acf_crew", "You've reached the ACF Crewmate limit!")

-- Deals with crew linking to crew entities
net.Receive("ACF_Crew_Reps",function()
    local Entity = net.ReadEntity()
    local Count = net.ReadInt(8)
    Entity.ReplaceLinks = {}
    for i = 1, Count do
        Entity.ReplaceLinks[i] = net.ReadEntity()
    end
end)

-- Deals with crew linking to non crew entities
net.Receive("ACF_Crew_Links",function()
    local Entity = net.ReadEntity()
    local Count = net.ReadInt(8)
    Entity.TargetLinks = {}
    for i = 1, Count do
        Entity.TargetLinks[i] = net.ReadEntity()
    end
end)

function ENT:Initialize(...)
    BaseClass.Initialize(self, ...)
end

function ENT:Draw(...)
    BaseClass.Draw(self, ...)
end

local red = Color(255,0,0)
local yellow = Color(255,255,0)
local green = Color(0,255,0,100)
function ENT:DrawOverlay()
    if self.ReplaceLinks then
        local p2scs = {}
        for k,v in ipairs(self.ReplaceLinks) do
            if not IsValid(v) then continue end
            local p1 = self:WorldSpaceCenter()
            local p2 = v:WorldSpaceCenter()
            p2scs[k] = p2:ToScreen()
            render.DrawLine(p1, p2, red)


            local dir = (p1 - p2):GetNormalized()
            local dir2 = EyeVector()
            local right = (dir:Cross(dir2)):GetNormalized()
            local avg = (p1 + p2)/2

            render.DrawLine(avg+dir/2*5, avg+(-dir/2-right)*5, red)
            render.DrawLine(avg+dir/2*5, avg+(-dir/2+right)*5, red)
        end

        -- Want to avoid rapidly restarting 2d context in the previous for loop, so we do these in series
        cam.Start2D()
        for k,v in ipairs(self.ReplaceLinks) do
            if not IsValid(v) then continue end
            draw.SimpleTextOutlined(""..k, "ACF_Control", p2scs[k].x, p2scs[k].y, yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, color_black)
        end
        cam.End2D()
    end

    if self.TargetLinks then
        for k,v in ipairs(self.TargetLinks) do
            if not IsValid(v) then continue end
            render.DrawWireframeBox(v:GetPos(), v:GetAngles(), v:OBBMins(), v:OBBMaxs(), green, true)
        end
    end
end