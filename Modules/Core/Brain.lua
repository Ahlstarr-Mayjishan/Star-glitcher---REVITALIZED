--[[
    Brain.lua - Central Nervous System (Orchestrator)
    Analogy: The Spinal Cord/CNS connecting all Brain Lobes.
    Job: Coordinates input, thought, and motor execution.
]]

local BrainFolder = "Modules/Core/Brain/"
local clock = os.clock

local Brain = {}
Brain.__index = Brain

function Brain.new(config, modules, loader)
    local self = setmetatable({}, Brain)
    self.Options = config.Options
    self.Config = config

    local Parietal = loader(BrainFolder .. "Parietal.lua")
    local Temporal = loader(BrainFolder .. "Temporal.lua")
    local Occipital = loader(BrainFolder .. "Occipital.lua")
    local Frontal = loader(BrainFolder .. "Frontal.lua")

    self.Parietal = Parietal.new(modules.Input, modules.Tracker)
    self.Temporal = Temporal.new(modules.Selector, modules.Predictor)
    self.Occipital = Occipital.new(modules.Visuals)
    self.Frontal = Frontal.new(modules.Aimbot, modules.SilentAim, self.Options)

    self._lastScan = 0
    self._scanInterval = 1 / 75 -- Optimized from 120Hz to 75Hz to eliminate jitters
    self._scanAccumulator = 0
    self._frameDtEma = 1 / 60
    return self
end

function Brain:_isDeadlockMode()
    return tostring(self.Options.TargetingMethod or "FOV") == "Deadlock"
end

function Brain:_getScanInterval()
    local maxHz = math.clamp(tonumber(self.Options.TargetScanHz) or 120, 30, 240)
    return 1 / maxHz
end

function Brain:Scan(mousePos, originPos, dt)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local deadlockMode = self:_isDeadlockMode()
    if not shouldAssist then
        if deadlockMode and self.Options.AssistMode ~= "Off" then
            return
        end
        self.Parietal.Tracker.CurrentTargetEntry = nil
        self._scanAccumulator = 0
        return
    end

    local scanInterval = self:_getScanInterval()
    self._scanInterval = scanInterval

    if self.Options.AdaptiveTargetScan == false then
        local now = clock()
        if (now - self._lastScan) < scanInterval then
            return
        end
        self._lastScan = now
    else
        local step = math.max(tonumber(dt) or self._frameDtEma or (1 / 60), 1 / 240)
        self._frameDtEma = self._frameDtEma + ((step - self._frameDtEma) * 0.18)
        self._scanAccumulator = self._scanAccumulator + step
        if self._scanAccumulator < scanInterval then
            return
        end

        self._scanAccumulator = math.max(0, self._scanAccumulator - scanInterval)
        if self._scanAccumulator > (scanInterval * 1.5) then
            self._scanAccumulator = scanInterval
        end

        self._lastScan = clock()
    end

    local target = self.Temporal:Scan(mousePos, originPos)
    self.Parietal.Tracker.CurrentTargetEntry = target
end

function Brain:Update(dt, mousePos, camCFrame)
    local shouldAssist = self.Parietal.Input:ShouldAssist()
    local entry = self.Parietal.Tracker.CurrentTargetEntry
    local maintainDeadlock = self:_isDeadlockMode() and self.Options.AssistMode ~= "Off" and entry ~= nil
    local shouldTrack = shouldAssist or maintainDeadlock

    -- Lazy Evaluation: Only process visual FOV rendering when enabled or tracking
    if self.Options.ShowFOV or self.Options.ShowTargetDot or shouldTrack then
        self.Occipital:UpdateFOV(mousePos)
    end

    if not shouldTrack or not entry then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local targetPart, targetPos, rawTargetPos, techniqueDecision = self.Temporal:Process(camCFrame.Position, dt)

    if not targetPart or not targetPos then
        self.Occipital:Clear()
        self.Frontal:Rest()
        return
    end

    local sPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    self.Occipital:Process(mousePos, sPos, targetPart, onScreen, techniqueDecision, entry)
    self.Frontal:Execute(targetPos, targetPart, entry, dt, rawTargetPos)
end

function Brain:Destroy()
    local lobes = {
        self.Parietal,
        self.Temporal,
        self.Occipital,
        self.Frontal,
    }

    for _, lobe in ipairs(lobes) do
        if lobe and lobe.Destroy then
            pcall(function()
                lobe:Destroy()
            end)
        end
    end

    self.Parietal = nil
    self.Temporal = nil
    self.Occipital = nil
    self.Frontal = nil
end

return Brain
