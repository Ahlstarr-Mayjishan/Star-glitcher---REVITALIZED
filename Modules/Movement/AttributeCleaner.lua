local RunService = game:GetService("RunService")

local AttributeCleaner = {}
AttributeCleaner.__index = AttributeCleaner

function AttributeCleaner.new(options, localCharacter, nativeStatus)
    local self = setmetatable({}, AttributeCleaner)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.NativeStatus = nativeStatus
    self.Connection = nil
    self._lastSweep = 0
    self._sweepInterval = 0.12
    return self
end

local NATIVE_CC_FLAGS = {
    Stunned = true,
    Frozen = true,
    Ragdolled = true,
    Slowed = true,
    Snared = true,
    Immobilized = true,
}

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

        if self.NativeStatus then
            self.NativeStatus.ClearBooleanFlags(char, NATIVE_CC_FLAGS)
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
