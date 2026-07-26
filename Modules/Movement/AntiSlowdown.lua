--[[
    AntiSlowdown.lua - Neuro-Motor Defense Module
    Job: Preventing speed-related debuffs (Slows).
    Status: Decoupled with active walkspeed/jump monitoring.
]]

local RunService = game:GetService("RunService")
local clock = os.clock

local AntiSlowdown = {}
AntiSlowdown.__index = AntiSlowdown

function AntiSlowdown.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, AntiSlowdown)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.BaseJumpPower = 50
    self.TrackedHumanoid = nil

    self.Status = "Idle"
    self._lastAction = 0
    self._lastWriteTime = 0
    self._yieldingToSpeedOverride = false
    self._arbiterKey = "__STAR_GLITCHER_ANTI_SLOWDOWN"
    return self
end

function AntiSlowdown:_setStatus(status)
    if self.Status ~= status then
        self.Status = status
    end
end

function AntiSlowdown:CaptureBaseStats(humanoid)
    local hum = humanoid or (self.LocalCharacter and self.LocalCharacter:GetHumanoid())
    if not hum then
        return
    end

    self.TrackedHumanoid = hum
    self.BaseWalkSpeed = math.max(hum.WalkSpeed, 16)
    self.BaseJumpPower = math.max(hum.JumpPower, 50)
end

function AntiSlowdown:_learnLegitMovement(humanoid)
    local now = clock()
    if (now - self._lastWriteTime) < 0.25 then
        return
    end

    if humanoid.WalkSpeed > (self.BaseWalkSpeed + 1.5) then
        self.BaseWalkSpeed = humanoid.WalkSpeed
    end

    if humanoid.JumpPower > (self.BaseJumpPower + 1.5) then
        self.BaseJumpPower = humanoid.JumpPower
    end
end

function AntiSlowdown:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.NoSlowdown then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self:_setStatus("Disabled")
            return
        end

        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self:_setStatus("Hum Missing")
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                self:CaptureBaseStats(hum)
            end
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._yieldingToSpeedOverride = false
            self:_setStatus("Respawn Grace")
            return
        end

        if self.Options.CustomMoveSpeedEnabled or self.Options.SpeedMultiplierEnabled then
            self._yieldingToSpeedOverride = true
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self:_setStatus("Yielding to Speed Override")
            return
        end

        if self._yieldingToSpeedOverride then
            self._yieldingToSpeedOverride = false
            self:CaptureBaseStats(hum)
            self:_setStatus("Recalibrated")
            return
        end

        self:_setStatus("Monitoring Speed")

        if hum ~= self.TrackedHumanoid then
            self:CaptureBaseStats(hum)
        end

        self:_learnLegitMovement(hum)

        local actionTaken = false
        if self.MovementArbiter then
            self.MovementArbiter:SetWalkMinimum(self._arbiterKey, self.BaseWalkSpeed)
            self.MovementArbiter:SetJumpMinimum(self._arbiterKey, self.BaseJumpPower)
            actionTaken = hum.WalkSpeed < self.BaseWalkSpeed or hum.JumpPower < self.BaseJumpPower
        else
            if hum.WalkSpeed < self.BaseWalkSpeed then
                hum.WalkSpeed = self.BaseWalkSpeed
                self._lastWriteTime = clock()
                actionTaken = true
            end

            if hum.JumpPower < self.BaseJumpPower then
                hum.JumpPower = self.BaseJumpPower
                self._lastWriteTime = clock()
                actionTaken = true
            end
        end

        if actionTaken then
            self._lastAction = clock()
        end

        if (clock() - self._lastAction) < 1.0 then
            self:_setStatus("Active: SPEED PROTECTED")
        end
    end)
end

function AntiSlowdown:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end
end

return AntiSlowdown
