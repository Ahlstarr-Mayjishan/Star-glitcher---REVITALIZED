--!strict

--[[
    Estimator.lua - State Estimation & Noise Removal (Physics Damping v2)
    Analogy: Inferior Colliculus (Auditory/Visual processing before perception).
    Job: Filtering raw velocity, detecting acceleration/jerk, and scoring confidence.
    Fixes: Jitter/Shakiness (rung) via progressive damping filters.
]]

local Estimator = {}
Estimator.__index = Estimator

local ZERO = Vector3.zero
local DEFAULT_DT = 1 / 60
local MIN_DT = 1 / 240
local MAX_DT = 0.25

function Estimator.new(kalman, config)
    local self = setmetatable({}, Estimator)
    self.Kalman = kalman
    self.Config = config
    self._prevVelocity = ZERO
    self._prevAcceleration = ZERO
    self._prevJerk = ZERO
    self._prevYaw = 0
    self._prevAngularVel = 0
    self._kalmanContext = {
        Confidence = 0.95,
        Shock = 0,
        IsTeleport = false,
    }
    self._result = {
        Velocity = ZERO,
        Acceleration = ZERO,
        Jerk = ZERO,
        AngularVelocity = 0,
        Confidence = 1,
        Stable = true,
        MotionShock = 0,
        IsTeleport = false,
        RawVelocity = ZERO,
        PhysicsVelocity = ZERO,
        TimeDelta = DEFAULT_DT,
        ObservationAge = 0,
    }
    return self
end

function Estimator:Reset()
    self._prevVelocity = ZERO
    self._prevAcceleration = ZERO
    self._prevJerk = ZERO
    self._prevYaw = 0
    self._prevAngularVel = 0
    if self.Kalman then
        if self.Kalman.Reset then
            self.Kalman:Reset()
        else
            self.Kalman.Value = nil
            self.Kalman.P = 1
        end
    end
end

function Estimator:Estimate(raw, dt)
    local sampleDt = math.clamp((raw and raw.TimeDelta) or dt or DEFAULT_DT, MIN_DT, MAX_DT)
    local measurement = raw.Velocity or ZERO
    local sampleVelocity = raw.RawVelocity or measurement
    local physicsVelocity = raw.PhysicsVelocity or measurement

    local motionShock = (measurement - self._prevVelocity).Magnitude
    if raw.IsTeleport then
        motionShock = math.max(motionShock, 220)
    end

    local filteredVel = measurement
    if self.Kalman and self.Kalman.Update then
        local kalmanContext = self._kalmanContext
        kalmanContext.Confidence = raw.IsTeleport and 0.05 or 0.95
        kalmanContext.Shock = motionShock
        kalmanContext.IsTeleport = raw.IsTeleport
        filteredVel = self.Kalman:Update(measurement, sampleDt, kalmanContext)
    end

    if not raw.IsTeleport and physicsVelocity.Magnitude > 0.01 then
        local agreement = 1 - math.clamp((sampleVelocity - physicsVelocity).Magnitude / math.max(40, physicsVelocity.Magnitude * 0.8), 0, 1)
        local physicsBlend = math.clamp(0.18 + (agreement * 0.32), 0.08, 0.5)
        filteredVel = filteredVel:Lerp(physicsVelocity, physicsBlend)
    end

    local accel = ZERO
    local jerk = ZERO
    local angularVel = 0

    if raw.IsTeleport then
        filteredVel = physicsVelocity.Magnitude > 0.01 and physicsVelocity or filteredVel
    else
        local rawAccel = (filteredVel - self._prevVelocity) / sampleDt
        local accelResponse = math.clamp(sampleDt * (12 + math.min(motionShock / 12, 18)), 0.08, 0.95)
        accel = self._prevAcceleration:Lerp(rawAccel, accelResponse)

        local rawJerk = (accel - self._prevAcceleration) / sampleDt
        local jerkResponse = math.clamp(sampleDt * (8 + math.min(motionShock / 20, 12)), 0.05, 0.85)
        jerk = self._prevJerk:Lerp(rawJerk, jerkResponse)

        -- Calculate horizontal angular velocity (turn rate)
        local currentYaw = math.atan2(-filteredVel.Z, filteredVel.X)
        local horizontalSpeedSquared = (filteredVel.X * filteredVel.X)
            + (filteredVel.Z * filteredVel.Z)
        if horizontalSpeedSquared > 1 then
            local deltaYaw = currentYaw - self._prevYaw
            -- Normalize angle delta to [-pi, pi]
            while deltaYaw > math.pi do deltaYaw = deltaYaw - (2 * math.pi) end
            while deltaYaw < -math.pi do deltaYaw = deltaYaw + (2 * math.pi) end
            local rawAngularVel = deltaYaw / sampleDt
            angularVel = self._prevAngularVel + ((rawAngularVel - self._prevAngularVel) * math.clamp(sampleDt * 10, 0.05, 0.8))
            self._prevYaw = currentYaw
            self._prevAngularVel = angularVel
        end
    end

    local filterLag = (measurement - filteredVel).Magnitude
    local physicsDisagreement = 0
    if physicsVelocity.Magnitude > 0.01 and sampleVelocity.Magnitude > 0.01 then
        physicsDisagreement = (sampleVelocity - physicsVelocity).Magnitude
    end

    local score = 1.0
    if raw.IsTeleport then
        score = 0.05
    else
        score = score - math.clamp(filterLag / 160, 0, 0.32)
        score = score - math.clamp(accel.Magnitude / 260, 0, 0.28)
        score = score - math.clamp(jerk.Magnitude / 2200, 0, 0.18)
        score = score - math.clamp(motionShock / 200, 0, 0.22)
        score = score - math.clamp(physicsDisagreement / 220, 0, 0.12)
        score = math.clamp(score, 0.18, 1)
    end

    self._prevVelocity = filteredVel
    self._prevAcceleration = accel
    self._prevJerk = jerk

    local result = self._result
    result.Velocity = filteredVel
    result.Acceleration = accel
    result.Jerk = jerk
    result.AngularVelocity = angularVel
    result.Confidence = score
    result.Stable = score > 0.72 and motionShock < 110
    result.MotionShock = motionShock
    result.IsTeleport = raw.IsTeleport == true
    result.RawVelocity = measurement
    result.PhysicsVelocity = physicsVelocity
    result.TimeDelta = sampleDt
    result.ObservationAge = math.max(raw.ObservationAge or 0, 0)
    return result
end

return Estimator

