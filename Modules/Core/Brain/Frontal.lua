--[[
    FrontalLobe.lua - Executive Function & Motor Control
    Analogy: Planning and executing movements (Aimbot/Silent Aim).
    Script Job: Dispatches actual aimbot actions based on brain decisions.
]]

local FrontalLobe = {}
FrontalLobe.__index = FrontalLobe

function FrontalLobe.new(aimbot, silentAim, options)
    local self = setmetatable({}, FrontalLobe)
    self.Aimbot = aimbot
    self.SilentAim = silentAim
    self.Options = options
    return self
end

function FrontalLobe:Execute(targetPos, part, entry, dt, rawTargetPos)
    local mode = self.Options.AssistMode
    
    if mode == "Camera Lock" then
        self.SilentAim:Clear()
        self.Aimbot:Update(targetPos, self.Options.Smoothness, dt)
    elseif mode == "Silent Aim" then
        self.SilentAim:SetState(true, part, rawTargetPos or targetPos, entry, dt)
    elseif mode == "Highlight Only" then
        self.SilentAim:Clear()
    else
        self:Rest()
    end
end

function FrontalLobe:Rest()
    self.SilentAim:Clear()
end

return FrontalLobe

