local RunService = game:GetService("RunService")

local SpeedMultiplier = {}
SpeedMultiplier.__index = SpeedMultiplier

function SpeedMultiplier.new(options, localCharacter, movementArbiter)
    local self = setmetatable({}, SpeedMultiplier)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.MovementArbiter = movementArbiter
    self.Connection = nil
    self.BaseWalkSpeed = 16
    self.TrackedHumanoid = nil
    self.Status = "Idle"
    self._lastBoostTime = 0
    self._lastWalkWriteTime = 0
    self._fallbackWarmupUntil = 0
    self._wasEnabled = false
    self._preEnableBaseSpeed = 16
    self._arbiterKey = "__STAR_GLITCHER_SPEED_MULTIPLIER"
    self._respawnRecoveryUntil = 0
    self._respawnRecoveryDuration = 1.1
    return self
end

function SpeedMultiplier:_getBaselineWalkSpeed(humanoid)
    local arbiterBase = self.MovementArbiter and self.MovementArbiter.GetBaseWalkSpeed and self.MovementArbiter:GetBaseWalkSpeed() or nil
    if arbiterBase and arbiterBase > 0 then
        return math.max(arbiterBase, 16)
    end

    if humanoid then
        return math.max(humanoid.WalkSpeed, 16)
    end

    return math.max(self.BaseWalkSpeed or 16, 16)
end

function SpeedMultiplier:_captureBaseSpeed(humanoid)
    self.TrackedHumanoid = humanoid
    self.BaseWalkSpeed = self:_getBaselineWalkSpeed(humanoid)
end

function SpeedMultiplier:_beginRespawnRecovery(humanoid)
    if humanoid and humanoid ~= self.TrackedHumanoid then
        self:_captureBaseSpeed(humanoid)
    end

    self._respawnRecoveryUntil = os.clock() + self._respawnRecoveryDuration
    self._fallbackWarmupUntil = 0
    self._wasEnabled = false

    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
    end
end

function SpeedMultiplier:_learnRespawnBase(humanoid)
    if not humanoid then
        return
    end

    local observed = math.max(humanoid.WalkSpeed or 0, 16)
    if observed > self.BaseWalkSpeed then
        self.BaseWalkSpeed = observed
    end
end

function SpeedMultiplier:_writeWalkSpeed(humanoid, value)
    if self.MovementArbiter then
        self.MovementArbiter:SetWalkExact(self._arbiterKey, value, 20)
        self._lastWalkWriteTime = os.clock()
        return
    end

    if not humanoid then
        return
    end

    if math.abs(humanoid.WalkSpeed - value) > 0.1 then
        humanoid.WalkSpeed = value
        self._lastWalkWriteTime = os.clock()
    end
end

function SpeedMultiplier:_restoreBaseSpeed(humanoid)
    if self.MovementArbiter then
        self.MovementArbiter:ClearSource(self._arbiterKey)
        return
    end

    if not humanoid then
        return
    end

    local restoreSpeed = math.max(self._preEnableBaseSpeed or self.BaseWalkSpeed or 16, 16)
    self.BaseWalkSpeed = restoreSpeed
    self:_writeWalkSpeed(humanoid, restoreSpeed)
end

function SpeedMultiplier:_learnLegitBaseSpeed(humanoid)
    local multiplier = math.max(self.Options.SpeedMultiplier or 1, 1)
    local now = os.clock()
    if (now - self._lastWalkWriteTime) < 0.35 then
        return
    end

    if not self.Options.SpeedMultiplierEnabled then
        self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, 16)
        return
    end

    local observedBase = humanoid.WalkSpeed / multiplier
    if observedBase > (self.BaseWalkSpeed + 0.75) then
        self.BaseWalkSpeed = observedBase
    end
end

function SpeedMultiplier:_applyVelocityFallback(humanoid, rootPart, desiredSpeed)
    if not rootPart or desiredSpeed <= 0 then
        return false
    end

    local now = os.clock()
    local moveDirection = humanoid.MoveDirection
    if moveDirection.Magnitude <= 0.05 then
        self._fallbackWarmupUntil = 0
        return false
    end

    local planarVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z)
    local currentSpeedAlongMove = planarVelocity:Dot(moveDirection)
    local perpendicularPlanarVelocity = planarVelocity - (moveDirection * currentSpeedAlongMove)
    local missingSpeed = desiredSpeed - currentSpeedAlongMove
    if missingSpeed <= 0.75 then
        self._fallbackWarmupUntil = 0
        return false
    end

    if self._fallbackWarmupUntil == 0 then
        self._fallbackWarmupUntil = now + 0.2
        return false
    end

    if now < self._fallbackWarmupUntil then
        return false
    end

    local targetAlongMove = math.min(desiredSpeed, math.max(currentSpeedAlongMove, 0) + math.max(missingSpeed * 0.45, 4))
    local targetPlanarVelocity = perpendicularPlanarVelocity + (moveDirection * targetAlongMove)
    local verticalVelocity = rootPart.AssemblyLinearVelocity.Y
    rootPart.AssemblyLinearVelocity = Vector3.new(targetPlanarVelocity.X, verticalVelocity, targetPlanarVelocity.Z)
    self._lastBoostTime = now
    return true
end

function SpeedMultiplier:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local hum = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
        if not hum then
            self.Status = "Hum Missing"
            return
        end

        if hum ~= self.TrackedHumanoid then
            self:_beginRespawnRecovery(hum)
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            self:_beginRespawnRecovery(hum)
            self.Status = "Respawn Grace"
            return
        end

        if now < self._respawnRecoveryUntil then
            self:_learnRespawnBase(hum)
            if self.MovementArbiter then
                self.MovementArbiter:ClearSource(self._arbiterKey)
            end
            self.Status = "Rebuilding Sprint"
            return
        end

        if self.Options.SpeedMultiplierEnabled and self.Options.CustomMoveSpeedEnabled then
            self.Options.CustomMoveSpeedEnabled = false
        end

        if not self.Options.SpeedMultiplierEnabled then
            self._fallbackWarmupUntil = 0
            if self._wasEnabled then
                self:_restoreBaseSpeed(hum)
            else
                self.BaseWalkSpeed = self:_getBaselineWalkSpeed(hum)
                if self.MovementArbiter then
                    self.MovementArbiter:ClearSource(self._arbiterKey)
                end
            end
            self._wasEnabled = false
            self.Status = "Disabled"
            return
        end

        if not self._wasEnabled then
            self._preEnableBaseSpeed = self:_getBaselineWalkSpeed(hum)
            self.BaseWalkSpeed = self._preEnableBaseSpeed
            self._fallbackWarmupUntil = 0
            self._wasEnabled = true
        else
            self:_learnLegitBaseSpeed(hum)
        end

        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        local desiredSpeed = self.BaseWalkSpeed * self.Options.SpeedMultiplier
        local boosted = false

        self:_writeWalkSpeed(hum, desiredSpeed)

        -- Some games ignore WalkSpeed entirely and drive movement from custom controllers.
        -- When that happens, nudge the root part's horizontal velocity along MoveDirection.
        if self.Options.SpeedMultiplier > 1 then
            boosted = self:_applyVelocityFallback(hum, rootPart, desiredSpeed)
        end

        if boosted then
            self.Status = "Active: Velocity Fallback"
        elseif math.abs(hum.WalkSpeed - desiredSpeed) <= 0.1 then
            self.Status = "Active: WalkSpeed"
        elseif self.MovementArbiter and (os.clock() - self._lastWalkWriteTime) < 0.35 then
            self.Status = "Active: Arbiter Sync"
        else
            self.Status = "Contested"
        end
    end)
end

function SpeedMultiplier:Destroy()
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

return SpeedMultiplier
