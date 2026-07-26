local RunService = game:GetService("RunService")

local MovementArbiter = {}
MovementArbiter.__index = MovementArbiter

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

function MovementArbiter.new(options, localCharacter)
    local self = setmetatable({}, MovementArbiter)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.TrackedHumanoid = nil
    self.BaseWalkSpeed = DEFAULT_WALK_SPEED
    self.BaseJumpPower = DEFAULT_JUMP_POWER
    self._requests = {}
    self._appliedWalk = false
    self._appliedJump = false
    self._lastWriteAt = 0
    self.Status = "Idle"
    return self
end

function MovementArbiter:_ensureRequest(source)
    local request = self._requests[source]
    if not request then
        request = {}
        self._requests[source] = request
    end
    return request
end

function MovementArbiter:SetWalkExact(source, value, priority)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.WalkExact = tonumber(value)
    request.WalkPriority = tonumber(priority) or 0
end

function MovementArbiter:SetWalkMinimum(source, value)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.WalkMin = tonumber(value)
end

function MovementArbiter:SetJumpExact(source, value, priority)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.JumpExact = tonumber(value)
    request.JumpPriority = tonumber(priority) or 0
end

function MovementArbiter:SetJumpMinimum(source, value)
    if not source then
        return
    end

    local request = self:_ensureRequest(source)
    request.JumpMin = tonumber(value)
end

function MovementArbiter:ClearSource(source)
    if not source then
        return
    end
    self._requests[source] = nil
end

function MovementArbiter:GetBaseWalkSpeed()
    return self.BaseWalkSpeed
end

function MovementArbiter:_captureBase(humanoid)
    if not humanoid then
        return
    end

    self.TrackedHumanoid = humanoid
    self.BaseWalkSpeed = math.max(humanoid.WalkSpeed, DEFAULT_WALK_SPEED)
    self.BaseJumpPower = math.max(humanoid.JumpPower, DEFAULT_JUMP_POWER)
end

function MovementArbiter:_learnBase(humanoid, hasWalkExact, hasWalkMin, hasJumpExact, hasJumpMin)
    if not humanoid or (os.clock() - self._lastWriteAt) < 0.3 then
        return
    end

    if not hasWalkExact and not hasWalkMin and humanoid.WalkSpeed > (self.BaseWalkSpeed + 0.75) then
        self.BaseWalkSpeed = humanoid.WalkSpeed
    end

    if not hasJumpExact and not hasJumpMin and humanoid.JumpPower > (self.BaseJumpPower + 1) then
        self.BaseJumpPower = humanoid.JumpPower
    end
end

function MovementArbiter:_pickExact(kind)
    local bestValue = nil
    local bestPriority = -math.huge

    for _, request in pairs(self._requests) do
        local value = request[kind]
        if value ~= nil then
            local priorityKey = (kind == "WalkExact") and "WalkPriority" or "JumpPriority"
            local priority = request[priorityKey] or 0
            if priority > bestPriority then
                bestPriority = priority
                bestValue = value
            end
        end
    end

    return bestValue ~= nil, bestValue
end

function MovementArbiter:_pickMinimum(kind)
    local best = nil
    for _, request in pairs(self._requests) do
        local value = request[kind]
        if value ~= nil then
            best = best and math.max(best, value) or value
        end
    end
    return best ~= nil, best
end

function MovementArbiter:_writeHumanoidProperty(humanoid, propertyName, value)
    if not humanoid or value == nil then
        return false
    end

    if math.abs((humanoid[propertyName] or 0) - value) <= 0.1 then
        return false
    end

    humanoid[propertyName] = value
    self._lastWriteAt = os.clock()
    return true
end

function MovementArbiter:_applyWalk(humanoid)
    local hasExact, exactValue = self:_pickExact("WalkExact")
    local hasMin, minValue = self:_pickMinimum("WalkMin")

    if hasExact then
        self._appliedWalk = self:_writeHumanoidProperty(humanoid, "WalkSpeed", exactValue) or self._appliedWalk
        return hasExact, hasMin
    end

    if hasMin and humanoid.WalkSpeed < minValue then
        self._appliedWalk = self:_writeHumanoidProperty(humanoid, "WalkSpeed", minValue) or self._appliedWalk
        return hasExact, hasMin
    end

    if self._appliedWalk then
        self:_writeHumanoidProperty(humanoid, "WalkSpeed", self.BaseWalkSpeed)
        self._appliedWalk = false
    end

    return hasExact, hasMin
end

function MovementArbiter:_applyJump(humanoid)
    local hasExact, exactValue = self:_pickExact("JumpExact")
    local hasMin, minValue = self:_pickMinimum("JumpMin")

    if hasExact then
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        self._appliedJump = self:_writeHumanoidProperty(humanoid, "JumpPower", exactValue) or self._appliedJump
        return hasExact, hasMin
    end

    if hasMin and humanoid.JumpPower < minValue then
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        self._appliedJump = self:_writeHumanoidProperty(humanoid, "JumpPower", minValue) or self._appliedJump
        return hasExact, hasMin
    end

    if self._appliedJump then
        if not humanoid.UseJumpPower then
            humanoid.UseJumpPower = true
        end
        self:_writeHumanoidProperty(humanoid, "JumpPower", self.BaseJumpPower)
        self._appliedJump = false
    end

    return hasExact, hasMin
end

function MovementArbiter:_step()
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid ~= self.TrackedHumanoid then
        self:_captureBase(humanoid)
    end

    if not humanoid then
        self.Status = "Hum Missing"
        return
    end

    local hasWalkExact, hasWalkMin = self:_applyWalk(humanoid)
    local hasJumpExact, hasJumpMin = self:_applyJump(humanoid)
    self:_learnBase(humanoid, hasWalkExact, hasWalkMin, hasJumpExact, hasJumpMin)

    if hasWalkExact or hasJumpExact then
        self.Status = "Override Active"
    elseif hasWalkMin or hasJumpMin then
        self.Status = "Protection Active"
    else
        self.Status = "Idle"
    end
end

function MovementArbiter:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function()
        self:_step()
    end)
end

function MovementArbiter:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    if humanoid then
        if self._appliedWalk then
            self:_writeHumanoidProperty(humanoid, "WalkSpeed", self.BaseWalkSpeed)
        end
        if self._appliedJump then
            if not humanoid.UseJumpPower then
                humanoid.UseJumpPower = true
            end
            self:_writeHumanoidProperty(humanoid, "JumpPower", self.BaseJumpPower)
        end
    end

    self._appliedWalk = false
    self._appliedJump = false
    table.clear(self._requests)
end

return MovementArbiter
