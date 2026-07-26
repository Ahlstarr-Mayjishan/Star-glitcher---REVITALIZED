--[[
    Engine.lua - Orthogonal Prediction Strategies
    Analogy: The Cognitive Decision Process.
    Job: Select exactly ONE strategy per frame: Intercept or Linear Extrapolation.
]]

local Engine = {}
Engine.__index = Engine

local Stats = game:GetService("Stats")
local DEFAULT_PROJECTILE_SPEED = 1000
local ZERO = Vector3.zero

local TARGET_PROFILE_BOX = "box"
local TARGET_PROFILE_SPHERE = "sphere"
local TARGET_PROFILE_MINI_HUMANOID = "mini_humanoid"
local TARGET_PROFILE_HUMANOID = "humanoid"

function Engine.new(config)
    local self = setmetatable({}, Engine)
    self.Config = config
    self.Options = config.Options
    self.Prediction = config.Prediction or {}
    self.PvP = config.PvP or {}
    self._cachedPing = 50
    self._lastPingCheck = 0
    return self
end

function Engine:_GetLatency()
    local now = os.clock()
    if now - self._lastPingCheck >= 1 then
        self._lastPingCheck = now
        pcall(function()
            local raw = Stats.Network.ServerStatsItem("Data Ping"):GetValueString()
            self._cachedPing = tonumber((raw:gsub("[^%d%.]", ""))) or self._cachedPing
        end)
    end
    return math.clamp(self._cachedPing / 2000, 0, 0.2)
end

function Engine:_GetPingMultiplier()
    if self.Options.TargetPlayersToggle then
        return math.clamp(self.PvP.PING_MULTIPLIER or 1.5, 1, 2.25)
    end
    return 1
end

function Engine:_ResolveTargetProfile(entry, part)
    if not part then
        return TARGET_PROFILE_BOX, 0
    end

    local size = part.Size
    local model = entry and entry.Model
    local humanoid = entry and entry.Humanoid

    if humanoid then
        local modelHeight = 0
        if model then
            local extents = model:GetExtentsSize()
            modelHeight = extents.Y
        end

        local isMiniHumanoid = size.Y <= 2.6
            or size.X <= 2.6
            or modelHeight > 0 and modelHeight <= 4.25
            or humanoid.HipHeight <= 1.5

        if isMiniHumanoid then
            return TARGET_PROFILE_MINI_HUMANOID, math.clamp(math.max(size.Y * 0.3, modelHeight * 0.12), 0.35, 0.85)
        end

        return TARGET_PROFILE_HUMANOID, math.clamp(size.Y * 0.08, 0.08, 0.3)
    end

    if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
        return TARGET_PROFILE_SPHERE, 0
    end

    return TARGET_PROFILE_BOX, 0
end

function Engine:_GetLateralTrust(profile, confidence, lateralAlpha, shockAlpha)
    local base
    local confGain
    local lateralGain
    local cap

    if profile == TARGET_PROFILE_MINI_HUMANOID then
        base = 0.24
        confGain = 0.28
        lateralGain = 0.24
        cap = 0.56
    elseif profile == TARGET_PROFILE_HUMANOID then
        base = 0.18
        confGain = 0.22
        lateralGain = 0.18
        cap = 0.42
    elseif profile == TARGET_PROFILE_SPHERE then
        base = 0.14
        confGain = 0.18
        lateralGain = 0.16
        cap = 0.36
    else
        base = 0.2
        confGain = 0.2
        lateralGain = 0.18
        cap = 0.4
    end

    return math.clamp((base + (confidence * confGain) + (lateralAlpha * lateralGain)) * (1 - shockAlpha * 0.35), 0.08, cap)
end

function Engine:_GetDistanceRatio(distance)
    local startDist = self.Prediction.DISTANCE_PREDICTION_START or 180
    local maxDist = self.Prediction.DISTANCE_PREDICTION_MAX or math.max(startDist + 1, 1800)
    if distance <= startDist then
        return 0
    end
    return math.clamp((distance - startDist) / math.max(maxDist - startDist, 1), 0, 1)
end

function Engine:_IsBeamLike(projectileSpeed)
    local beamFloor = self.Prediction.SMART_PROJECTILE_SPEED_MIN or 3400
    return projectileSpeed >= beamFloor
end

function Engine:_getTechniqueProfile(decision)
    local technique = decision and decision.Technique or "Linear"

    if technique == "Strafe" then
        return {
            TimeScale = 1.02,
            LateralScale = 1.22,
            AccelScale = 1.04,
            JerkScale = 0.92,
            VerticalScale = 0.95,
            TrustBias = 0.03,
        }
    end

    if technique == "Orbit" then
        return {
            TimeScale = 1.04,
            LateralScale = 1.34,
            AccelScale = 0.98,
            JerkScale = 0.82,
            VerticalScale = 0.92,
            TrustBias = 0.04,
        }
    end

    if technique == "Airborne" then
        return {
            TimeScale = 1.01,
            LateralScale = 0.9,
            AccelScale = 1.12,
            JerkScale = 0.88,
            VerticalScale = 1.26,
            TrustBias = 0.02,
        }
    end

    if technique == "Dash Recovery" then
        return {
            TimeScale = 0.82,
            LateralScale = 0.72,
            AccelScale = 0.42,
            JerkScale = 0.18,
            VerticalScale = 0.84,
            TrustBias = -0.12,
        }
    end

    return {
        TimeScale = 0.98,
        LateralScale = 0.86,
        AccelScale = 0.74,
        JerkScale = 0.52,
        VerticalScale = 0.94,
        TrustBias = 0.01,
    }
end

function Engine:Calculate(origin, targetPos, est, dt, entry, part, techniqueDecision)
    local Options = self.Options
    local configuredAimOffset = tonumber(Options.AimOffset) or 0
    if configuredAimOffset ~= 0 then
        targetPos = targetPos + Vector3.new(0, configuredAimOffset, 0)
    end
    if not Options.PredictionEnabled then
        return targetPos
    end

    local velocity = est.Velocity or ZERO
    local accel = est.Acceleration or ZERO
    local jerk = est.Jerk or ZERO
    local confidence = math.clamp(est.Confidence or 0, 0, 1)
    local motionShock = est.MotionShock or 0
    local speed = velocity.Magnitude
    local technique = self:_getTechniqueProfile(techniqueDecision)
    local targetProfile, aimBiasY = self:_ResolveTargetProfile(entry, part)

    if aimBiasY ~= 0 then
        targetPos = targetPos + Vector3.new(0, aimBiasY, 0)
    end

    local toTarget = targetPos - origin
    local distance = toTarget.Magnitude
    if distance <= 0.001 then
        return targetPos
    end

    local projectileSpeed = Options.ProjectileVelocity or Options.ProjectileSpeed or DEFAULT_PROJECTILE_SPEED
    projectileSpeed = math.max(projectileSpeed, 1)
    local beamLike = self:_IsBeamLike(projectileSpeed)

    local travelTime = distance / projectileSpeed
    local latency = self:_GetLatency() * self:_GetPingMultiplier()
    local frameComp = math.min(math.max(est.TimeDelta or dt or 0, 0), 1 / 20) * 0.5
    local totalTime = (travelTime + latency + frameComp) * technique.TimeScale

    local shotDir = toTarget.Unit
    local forwardSpeed = velocity:Dot(shotDir)
    local lateralVelocity = velocity - (shotDir * forwardSpeed)
    local lateralSpeed = lateralVelocity.Magnitude

    local shockAlpha = math.clamp(motionShock / 180, 0, 1)
    local speedAlpha = math.clamp(speed / 140, 0, 1)
    local lateralAlpha = math.clamp(lateralSpeed / 110, 0, 1)
    local distanceRatio = self:_GetDistanceRatio(distance)
    local linearStability = math.clamp(1 - (accel.Magnitude / math.max(self.Prediction.BRAKE_ACCEL_THRESHOLD or 20, 1) * 0.06) - (shockAlpha * 0.35), 0, 1)
    local closeOrbitAlpha = 0
    local closeOrbitDistance = self.Prediction.CLOSE_ORBIT_DISTANCE or 135
    if distance <= closeOrbitDistance then
        local fullDistance = self.Prediction.CLOSE_ORBIT_FULL_ALPHA_DISTANCE or 42
        closeOrbitAlpha = math.clamp(1 - ((distance - fullDistance) / math.max(closeOrbitDistance - fullDistance, 1)), 0, 1)
    end

    if beamLike then
        totalTime = totalTime * math.clamp(self.Prediction.BEAM_TIME_BIAS or 0.92, 0.72, 1.1)
    end

    if distanceRatio > 0 then
        local distanceTimeGain = self.Prediction.DISTANCE_TIME_GAIN or 0.68
        local distanceBonus = distanceRatio * (0.01 + (distanceTimeGain * 0.035)) * (0.65 + (confidence * 0.35))
        totalTime = totalTime + distanceBonus
    end

    if linearStability >= (self.Prediction.LINEAR_MOTION_DOT_THRESHOLD or 0.91) then
        totalTime = totalTime + (self.Prediction.LINEAR_MOTION_TIME_BONUS or 0.02) * (0.55 + (distanceRatio * 0.45))
    end

    if lateralSpeed >= (self.Prediction.CLOSE_ORBIT_STRAFE_THRESHOLD or 14) and closeOrbitAlpha > 0 then
        totalTime = totalTime + (self.Prediction.CLOSE_ORBIT_LEAD_BONUS_TIME or 0.018) * closeOrbitAlpha
    end

    local predictedOffset = velocity * totalTime

    -- CTRV (Constant Turn Rate and Velocity) Curved Motion Extrapolation
    local angularVel = est.AngularVelocity or 0
    if math.abs(angularVel) > 0.15 and speed > 5 then
        local omega = angularVel
        local wt = omega * totalTime
        local sinWt = math.sin(wt)
        local cosWt = math.cos(wt)
        -- Curved offset in local velocity orientation
        local localX = (speed / omega) * sinWt
        local localZ = (speed / omega) * (1 - cosWt)
        local velDir = velocity.Unit
        local rightDir = Vector3.new(-velDir.Z, 0, velDir.X)
        local curvedOffsetHorizontal = (velDir * localX) + (rightDir * localZ)
        -- Blend curved model with linear model based on confidence
        local curveBlend = math.clamp(math.abs(omega) * 0.8, 0.2, 0.85)
        predictedOffset = Vector3.new(
            predictedOffset.X * (1 - curveBlend) + curvedOffsetHorizontal.X * curveBlend,
            predictedOffset.Y,
            predictedOffset.Z * (1 - curveBlend) + curvedOffsetHorizontal.Z * curveBlend
        )
    end

    -- Strafing targets often miss because lateral movement needs slightly more
    -- aggressive lead than front/back motion under frame + ping delay.
    if lateralSpeed > 0.01 then
        local lateralTrust = self:_GetLateralTrust(targetProfile, confidence, lateralAlpha, shockAlpha) * technique.LateralScale
        local distanceStrafeGain = 1 + ((self.Prediction.DISTANCE_STRAFE_GAIN or 1.2) - 1) * distanceRatio * 0.35
        if beamLike then
            distanceStrafeGain = distanceStrafeGain * math.clamp(self.Prediction.BEAM_STRAFE_BIAS or 0.78, 0.5, 1.05)
        end
        if closeOrbitAlpha > 0 then
            distanceStrafeGain = distanceStrafeGain * (1 + (closeOrbitAlpha * 0.2))
        end
        predictedOffset = predictedOffset + (lateralVelocity * totalTime * lateralTrust)
        predictedOffset = predictedOffset + (lateralVelocity * totalTime * (distanceStrafeGain - 1) * (0.18 + (confidence * 0.12)))
    end

    if Options.SmartPrediction and (est.Stable or speed > 65) then
        local accelTrust = math.clamp(confidence * (1 - shockAlpha * 0.7), 0, 1)
        local jerkTrust = math.clamp(accelTrust * (1 - shockAlpha * 0.45), 0, 1)

        local profileBonus = targetProfile == TARGET_PROFILE_MINI_HUMANOID and 0.08 or (targetProfile == TARGET_PROFILE_BOX and 0.04 or 0)
        local accelWeight = math.clamp((1.08 - (totalTime * 0.3)) * (0.65 + (speedAlpha * 0.45) + (lateralAlpha * 0.2) + profileBonus), 0.24, 1.34) * accelTrust * technique.AccelScale
        local jerkWeight = math.clamp((0.58 - totalTime) * (0.45 + (speedAlpha * 0.35) + (lateralAlpha * 0.15) + (profileBonus * 0.5)), 0.05, 0.6) * jerkTrust * technique.JerkScale

        predictedOffset = predictedOffset + ((0.5 * accel * (totalTime ^ 2)) * accelWeight)
        predictedOffset = predictedOffset + (((1 / 6) * jerk * (totalTime ^ 3)) * jerkWeight)
    end

    if technique.VerticalScale ~= 1 then
        predictedOffset = Vector3.new(
            predictedOffset.X,
            predictedOffset.Y * technique.VerticalScale,
            predictedOffset.Z
        )
    end

    if forwardSpeed > 0.01 and accel.Magnitude > 0.01 then
        local accelDir = accel.Unit
        local brakeDot = accelDir:Dot(shotDir)
        if brakeDot <= (self.Prediction.REVERSE_RESPONSE_DOT or -0.05) then
            local brakeThreshold = self.Prediction.BRAKE_ACCEL_THRESHOLD or 20
            local brakeAlpha = math.clamp(accel.Magnitude / math.max(brakeThreshold, 1), 0, 1)
            local brakeCap = self.Prediction.ACCEL_CORRECTION_MAX_RATIO or 0.38
            local brakeReduction = math.clamp(brakeAlpha * (0.16 + (1 - confidence) * 0.08), 0.04, brakeCap)
            predictedOffset = predictedOffset - (shotDir * forwardSpeed * totalTime * brakeReduction)
        end
    end

    local leadCap = self.Prediction.MAX_LEAD_DIST or math.huge
    if self.Options.TargetPlayersToggle then
        leadCap = self.PvP.MAX_LEAD_DIST or leadCap
    end

    local maxOffset = math.max(
        18 + (speed * (0.14 + (confidence * 0.18))),
        distance * (0.22 + (speedAlpha * 0.18) + (lateralAlpha * 0.06))
    )
    if targetProfile == TARGET_PROFILE_MINI_HUMANOID then
        maxOffset = maxOffset * 1.08
    elseif targetProfile == TARGET_PROFILE_SPHERE then
        maxOffset = maxOffset * 0.96
    end
    maxOffset = math.min(maxOffset, leadCap)
    if predictedOffset.Magnitude > maxOffset then
        predictedOffset = predictedOffset.Unit * maxOffset
    end

    local predictedPos = targetPos + predictedOffset
    local trustFactor = math.clamp(
        (confidence * 0.75) + ((est.Stable and 0.15) or 0) + (speedAlpha * 0.12) + (lateralAlpha * 0.12) - (shockAlpha * 0.2) + technique.TrustBias,
        0.12,
        1
    )
    return targetPos:Lerp(predictedPos, trustFactor)
end

return Engine
