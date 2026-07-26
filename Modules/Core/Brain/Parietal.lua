--[[
    ParietalLobe.lua - Sensory & Input Processing
    Analogy: Integrates sensory information from various parts of the body.
    Script Job: Monitors user input and world entity tracking.
]]

local ParietalLobe = {}
ParietalLobe.__index = ParietalLobe

function ParietalLobe.new(input, tracker)
    local self = setmetatable({}, ParietalLobe)
    self.Input = input
    self.Tracker = tracker
    return self
end

function ParietalLobe:Process()
    local shouldAssist = self.Input:ShouldAssist()
    if not shouldAssist then
        return false, nil
    end
    return true, self.Tracker:GetTargets()
end

return ParietalLobe

