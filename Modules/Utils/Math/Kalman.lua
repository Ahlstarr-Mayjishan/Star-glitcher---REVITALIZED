--[[
    KalmanFilter.lua - OOP Noise Reduction Class
    A scientific implementation of 1D Kalman Filter for linear motion smoothing.
]]

local Kalman = {}
Kalman.__index = Kalman

local DEFAULT_DT = 1 / 60
local MIN_DT = 1 / 240
local MAX_DT = 0.25

function Kalman.new()
    local self = setmetatable({}, Kalman)
    self.P = 1.2 -- Estimation error covariance
    self.Q = 0.08 -- Process noise covariance
    self.R = 0.45 -- Measurement noise covariance
    self.Value = nil
    self.Trend = Vector3.zero
    self.Velocity = Vector3.zero
    return self
end

function Kalman:Reset(seed)
    self.P = 1.2
    self.Value = seed
    self.Trend = Vector3.zero
    self.Velocity = seed or Vector3.zero
end

function Kalman:Update(measurement, dt, context)
    if measurement == nil then
        return self.Value or Vector3.zero
    end

    dt = math.clamp(dt or DEFAULT_DT, MIN_DT, MAX_DT)

    if not self.Value then
        self:Reset(measurement)
        return measurement
    end

    if context and context.IsTeleport then
        self:Reset(measurement)
        return measurement
    end

    local confidence = math.clamp((context and context.Confidence) or 1, 0.05, 1)
    local shock = math.max((context and context.Shock) or 0, 0)
    local shockAlpha = math.clamp(shock / 180, 0, 1)
    local dtScale = dt / DEFAULT_DT

    -- Predict next velocity using the currently estimated trend before blending.
    local predicted = self.Value + (self.Trend * dt)
    local innovation = measurement - predicted

    local adaptiveQ = self.Q * (0.8 + dtScale + (shockAlpha * 2.6))
    local adaptiveR = self.R * (1.25 - (confidence * 0.55))

    self.P = math.clamp(self.P + adaptiveQ, 0.01, 12)

    local gain = self.P / (self.P + adaptiveR)
    self.Value = predicted + (innovation * gain)

    local trendGain = math.clamp((0.10 + (gain * 0.55) + (shockAlpha * 0.2)) / dtScale, 0.08, 0.95)
    self.Trend = self.Trend + ((innovation / dt) * trendGain)

    if shockAlpha < 0.2 then
        local damping = math.clamp((0.12 + ((1 - confidence) * 0.18)) * dtScale * 0.35, 0, 0.35)
        self.Trend = self.Trend * (1 - damping)
    end

    self.P = math.clamp((1 - gain) * self.P, 0.01, 12)
    self.Velocity = self.Value

    return self.Value
end

return Kalman

