local RunService = game:GetService("RunService")

local AttributeCleaner = {}
AttributeCleaner.__index = AttributeCleaner

function AttributeCleaner.new(options, localCharacter)
    local self = setmetatable({}, AttributeCleaner)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self._lastSweep = 0
    self._sweepInterval = 0.12
    return self
end

local function shouldClearName(lowerName)
    if not lowerName or lowerName == "" then
        return false
    end

    -- Only clear explicit movement-impairing debuffs.
    -- Avoid generic names like "delay", "cooldown", or "root" because
    -- many games use them for legitimate form-switch / ability logic.
    return lowerName:find("slow", 1, true)
        or lowerName:find("stun", 1, true)
        or lowerName:find("freeze", 1, true)
        or lowerName:find("ragdoll", 1, true)
        or lowerName:find("snare", 1, true)
        or lowerName:find("immobile", 1, true)
end

function AttributeCleaner:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoDelay then
            return
        end

        local now = os.clock()
        if (now - self._lastSweep) < self._sweepInterval then
            return
        end
        self._lastSweep = now

        local char = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        if not char then
            return
        end

        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("ValueBase") then
                local n = child.Name:lower()
                if shouldClearName(n) then
                    child:Destroy()
                end
            end
        end

        for attr, _ in pairs(char:GetAttributes()) do
            local lower = attr:lower()
            if shouldClearName(lower) then
                char:SetAttribute(attr, nil)
            end
        end
    end)
end

function AttributeCleaner:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AttributeCleaner
