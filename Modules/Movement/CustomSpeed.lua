local RunService = game:GetService("RunService")

local CustomSpeed = {}
CustomSpeed.__index = CustomSpeed

function CustomSpeed.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, CustomSpeed)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Connection = nil
    self.TrackedHumanoid = nil
    self.BaseWalkSpeed = 16
    self._wasEnabled = false
    self._arbiterKey = "__STAR_GLITCHER_CUSTOM_SPEED"
    return self
end

function CustomSpeed:_captureBaseSpeed(humanoid)
    if humanoid then
        self.TrackedHumanoid = humanoid
        self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
    end
end

function CustomSpeed:_restoreBaseSpeed(humanoid)
    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
        return
    end

    if humanoid and math.abs(humanoid.WalkSpeed - self.BaseWalkSpeed) > 0.1 then
        humanoid.WalkSpeed = self.BaseWalkSpeed
    end
end

function CustomSpeed:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if hum and hum ~= self.TrackedHumanoid then
            self:_captureBaseSpeed(hum)
            self._wasEnabled = false
        end

        if not self.Options.CustomMoveSpeedEnabled then
            if hum and self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            end
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._wasEnabled = false
            return
        end

        if self.Options.SpeedMultiplierEnabled then
            if hum and self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            end
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._wasEnabled = false
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self._wasEnabled = false
            return
        end

        if not hum then
            return
        end

        if not self._wasEnabled then
            self:_captureBaseSpeed(hum)
            self._wasEnabled = true
        end

        if self.MovementArbiter then
            self.MovementArbiter:SetWalkExact(self._arbiterKey, self.Options.CustomMoveSpeed, 100)
        elseif math.abs(hum.WalkSpeed - self.Options.CustomMoveSpeed) > 0.1 then
            hum.WalkSpeed = self.Options.CustomMoveSpeed
        end
    end)
end

function CustomSpeed:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end

    local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if hum and self._wasEnabled then
        self:_restoreBaseSpeed(hum)
    end
end

return CustomSpeed
