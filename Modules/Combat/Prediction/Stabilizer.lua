--!strict

--[[
    Stabilizer.lua - Vision & Presentation Smoothing
    Analogy: The vestibulo-ocular reflex (Vision stabilization).
    Job: Resolve micro-jitters without modifying core prediction state.
]]

local Stabilizer = {}
Stabilizer.__index = Stabilizer

local DEFAULT_DT = 1 / 60
local ZERO = Vector3.zero

function Stabilizer.new(aimMath, config, motionPolicy)
    local self = setmetatable({}, Stabilizer)
    self.AimMath = aimMath
    local prediction = config and config.Prediction or {}
    self.MotionPolicy = motionPolicy
    self.BaseSmoothing = prediction.STABILIZER_BASE_RESPONSE or 26
    self.CatchupSmoothing = prediction.STABILIZER_CATCHUP_RESPONSE or 96
    self.CatchupDistance = prediction.STABILIZER_CATCHUP_DISTANCE or 8
    self.EmergencySnapDistance = prediction.STABILIZER_EMERGENCY_SNAP_DISTANCE or 48
    self._lastTarget = ZERO
    return self
end

function Stabilizer:Reset(targetPos)
    self._lastTarget = targetPos or ZERO
end

function Stabilizer:Smooth(targetPos, dt, isTeleport)
    local lastTarget = self._lastTarget
    if lastTarget == ZERO then
        self._lastTarget = targetPos
        return targetPos
    end

    local delta = targetPos - lastTarget
    local deltaMagnitude = delta.Magnitude
    local plan = self.MotionPolicy
        and self.MotionPolicy.StabilizerPlan(
            deltaMagnitude,
            isTeleport == true,
            self.BaseSmoothing,
            self.CatchupSmoothing,
            self.CatchupDistance,
            self.EmergencySnapDistance
        )
        or {
            Snap = isTeleport == true or deltaMagnitude >= self.EmergencySnapDistance,
            Response = self.CatchupSmoothing,
        }
    if plan.Snap then
        self._lastTarget = targetPos
        return targetPos
    end

    local alpha = self.AimMath.ExponentialAlpha(plan.Response, dt or DEFAULT_DT)
    local result = lastTarget:Lerp(targetPos, alpha)

    self._lastTarget = result
    return result
end

return Stabilizer
