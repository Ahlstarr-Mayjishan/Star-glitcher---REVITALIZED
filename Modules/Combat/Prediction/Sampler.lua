--!strict

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

function Sampler.new(config, motionPolicy)
    local self = setmetatable({}, Sampler)
    local prediction = config and config.Prediction or nil
    self._teleportDistance = (prediction and prediction.TELEPORT_DETECTION_DISTANCE) or 22
    self._teleportRatio = (prediction and prediction.TELEPORT_DETECTION_SPEED_RATIO) or 0.55
    self._positionEpsilon = (prediction and prediction.POSITION_CHANGE_EPSILON) or 0.01
    self._velocityHoldDecayStart = (prediction and prediction.VELOCITY_HOLD_DECAY_START) or 0.055
    self._velocityHoldMax = (prediction and prediction.VELOCITY_HOLD_MAX) or 0.12
    self.MotionPolicy = motionPolicy
    self._state = {
        Position = ZERO,
        Velocity = ZERO,
        RawVelocity = ZERO,
        PhysicsVelocity = ZERO,
        Displacement = ZERO,
        IsTeleport = false,
        Time = 0,
        TimeDelta = DEFAULT_DT,
        ObservationAge = 0,
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

function Sampler:GetRawState(part, lastPos, lastTime, dt, motionState)
    local currentPos = part.Position
    local currentTime = os.clock()

    local frameDisplacement = lastPos and (currentPos - lastPos) or ZERO
    local frameDt = dt or 0
    if lastTime then
        frameDt = currentTime - lastTime
    end
    frameDt = math.clamp((frameDt and frameDt > 0) and frameDt or (dt or DEFAULT_DT), MIN_DT, MAX_DT)

    local displacement = frameDisplacement
    local observationDt = frameDt
    local observationAge = 0
    local observationChanged = lastPos ~= nil and frameDisplacement.Magnitude > self._positionEpsilon

    if motionState then
        if not motionState.LastObservedPosition then
            motionState.LastObservedPosition = currentPos
            motionState.LastObservationTime = currentTime
            motionState.HeldVelocity = ZERO
            observationChanged = false
            displacement = ZERO
        else
            displacement = currentPos - motionState.LastObservedPosition
            observationChanged = displacement.Magnitude > self._positionEpsilon
            if observationChanged then
                observationDt = math.clamp(
                    currentTime - (motionState.LastObservationTime or currentTime),
                    MIN_DT,
                    MAX_DT
                )
                motionState.LastObservedPosition = currentPos
                motionState.LastObservationTime = currentTime
            else
                observationAge = math.max(
                    currentTime - (motionState.LastObservationTime or currentTime),
                    0
                )
            end
        end
    end

    local velocity
    local sampledVelocity
    local physicsVelocity = part.AssemblyLinearVelocity or ZERO
    local previousHeldVelocity = motionState and motionState.HeldVelocity or ZERO

    if observationChanged then
        velocity, sampledVelocity, physicsVelocity = self:_ResolveVelocity(
            part,
            displacement,
            observationDt
        )
    elseif physicsVelocity.Magnitude > 0.01 then
        velocity = physicsVelocity
        sampledVelocity = physicsVelocity
    else
        local heldVelocity = motionState and motionState.HeldVelocity or ZERO
        local holdScale = self.MotionPolicy
            and self.MotionPolicy.VelocityHoldScale(
                observationAge,
                self._velocityHoldDecayStart,
                self._velocityHoldMax
            )
            or 0
        velocity = heldVelocity * holdScale
        sampledVelocity = velocity
    end

    local expectedSpeed = math.max(previousHeldVelocity.Magnitude, physicsVelocity.Magnitude)
    local isTeleport = observationChanged
        and self.MotionPolicy
        and self.MotionPolicy.IsTeleport(
            displacement.Magnitude,
            expectedSpeed,
            observationDt,
            self._teleportDistance,
            self._teleportRatio
        )
        or false

    if isTeleport then
        velocity = physicsVelocity.Magnitude > 0.01 and physicsVelocity or ZERO
    end
    if motionState and (observationChanged or physicsVelocity.Magnitude > 0.01) then
        motionState.HeldVelocity = velocity
    end

    local state = self._state
    state.Position = currentPos
    state.Velocity = velocity
    state.RawVelocity = sampledVelocity
    state.PhysicsVelocity = physicsVelocity
    state.Displacement = displacement
    state.IsTeleport = isTeleport
    state.Time = currentTime
    state.TimeDelta = observationChanged and observationDt or frameDt
    state.ObservationAge = observationAge
    return state
end

return Sampler

