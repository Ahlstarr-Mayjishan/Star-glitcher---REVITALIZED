--[[
    Sampler.lua - Pure Kinematic Data Extraction
    Analogy: The sensory nerves (Afferent fibers).
    Job: Extract raw position, velocity, and teleportation data without modification.
]]

local Sampler = {}
Sampler.__index = Sampler

local ZERO = Vector3.zero
local DEFAULT_DT = 1 / 60
local MIN_DT = 1 / 240
local MAX_DT = 0.25

function Sampler.new(config)
    local self = setmetatable({}, Sampler)
    local prediction = config and config.Prediction or nil
    self._teleportDistance = (prediction and prediction.TELEPORT_DETECTION_DISTANCE) or 22
    self._teleportRatio = (prediction and prediction.TELEPORT_DETECTION_SPEED_RATIO) or 0.55
    self._state = {
        Position = ZERO,
        Velocity = ZERO,
        RawVelocity = ZERO,
        PhysicsVelocity = ZERO,
        Displacement = ZERO,
        IsTeleport = false,
        Time = 0,
        TimeDelta = DEFAULT_DT,
    }
    return self
end

function Sampler:_ResolveVelocity(part, displacement, timeDelta)
    local physicsVelocity = part.AssemblyLinearVelocity or ZERO
    local sampledVelocity = ZERO

    if timeDelta > 0 then
        sampledVelocity = displacement / timeDelta
    end

    if physicsVelocity.Magnitude <= 0.01 then
        return sampledVelocity, sampledVelocity, physicsVelocity
    end

    if sampledVelocity.Magnitude <= 0.01 then
        return physicsVelocity, sampledVelocity, physicsVelocity
    end

    local disagreement = (sampledVelocity - physicsVelocity).Magnitude
    local blend = math.clamp(disagreement / math.max(24, sampledVelocity.Magnitude * 0.65), 0, 1)
    local resolvedVelocity = sampledVelocity:Lerp(physicsVelocity, 0.35 + (blend * 0.45))

    return resolvedVelocity, sampledVelocity, physicsVelocity
end

function Sampler:GetRawState(part, lastPos, lastTime, dt)
    local currentPos = part.Position
    local currentTime = os.clock()

    local displacement = lastPos and (currentPos - lastPos) or ZERO
    local timeDelta = dt or 0
    if lastTime then
        timeDelta = currentTime - lastTime
    end
    timeDelta = math.clamp((timeDelta and timeDelta > 0) and timeDelta or (dt or DEFAULT_DT), MIN_DT, MAX_DT)

    local velocity, sampledVelocity, physicsVelocity = self:_ResolveVelocity(part, displacement, timeDelta)

    local expectedTravel = velocity.Magnitude * timeDelta
    local teleportThreshold = math.max(self._teleportDistance, expectedTravel * (1 + self._teleportRatio) + 4)
    local isTeleport = lastPos ~= nil and displacement.Magnitude > teleportThreshold

    if isTeleport then
        velocity = physicsVelocity.Magnitude > 0.01 and physicsVelocity or ZERO
    end

    local state = self._state
    state.Position = currentPos
    state.Velocity = velocity
    state.RawVelocity = sampledVelocity
    state.PhysicsVelocity = physicsVelocity
    state.Displacement = displacement
    state.IsTeleport = isTeleport
    state.Time = currentTime
    state.TimeDelta = timeDelta
    return state
end

return Sampler

