local TechniqueSelector = {}
TechniqueSelector.__index = TechniqueSelector

local ZERO = Vector3.zero

local TECHNIQUE_LINEAR = "Linear"
local TECHNIQUE_STRAFE = "Strafe"
local TECHNIQUE_ORBIT = "Orbit"
local TECHNIQUE_AIRBORNE = "Airborne"
local TECHNIQUE_DASH = "Dash Recovery"

function TechniqueSelector.new(config)
    local self = setmetatable({}, TechniqueSelector)
    self.Options = config.Options
    self.Prediction = config.Prediction or {}
    self._states = setmetatable({}, { __mode = "k" })
    self._holdTime = 0.12
    self._stickMargin = 0.04
    return self
end

function TechniqueSelector:Prune(expiry, now)
    local pruneBefore = (now or os.clock()) - (expiry or 15)
    for entry, state in pairs(self._states) do
        if not entry
            or not entry.Model
            or not entry.Model.Parent
            or ((entry.LastSeen or 0) > 0 and (entry.LastSeen or 0) < pruneBefore)
            or (state and state.LastSwitch > 0 and state.LastSwitch < (pruneBefore - 8)) then
            self._states[entry] = nil
        end
    end
end

function TechniqueSelector:Destroy()
    table.clear(self._states)
end

function TechniqueSelector:_getState(entry)
    if not entry then
        return nil
    end

    local state = self._states[entry]
    if state then
        return state
    end

    state = {
        Technique = nil,
        LastSwitch = 0,
        LastReason = nil,
    }
    self._states[entry] = state
    return state
end

function TechniqueSelector:_makeDecision(technique, reason, score, confidence)
    return {
        Technique = technique,
        Reason = reason,
        Score = score or 0,
        Confidence = confidence or 0,
    }
end

function TechniqueSelector:_getMode()
    local mode = tostring(self.Options.PredictionTechniqueMode or "Assisted")
    if mode == "Manual" then
        return "Manual"
    end
    return "Assisted"
end

function TechniqueSelector:_getManualTechnique()
    local technique = tostring(self.Options.PredictionTechnique or TECHNIQUE_LINEAR)
    if technique == TECHNIQUE_STRAFE
        or technique == TECHNIQUE_ORBIT
        or technique == TECHNIQUE_AIRBORNE
        or technique == TECHNIQUE_DASH then
        return technique
    end
    return TECHNIQUE_LINEAR
end

function TechniqueSelector:_collectMetrics(origin, targetPos, est)
    local velocity = est.Velocity or ZERO
    local accel = est.Acceleration or ZERO
    local jerk = est.Jerk or ZERO
    local confidence = math.clamp(est.Confidence or 0, 0, 1)
    local shockAlpha = math.clamp((est.MotionShock or 0) / 180, 0, 1)
    local toTarget = targetPos - origin
    local distance = toTarget.Magnitude
    local shotDir = distance > 0.001 and toTarget.Unit or Vector3.new(0, 0, 1)

    local forwardSpeed = velocity:Dot(shotDir)
    local lateralVelocity = velocity - (shotDir * forwardSpeed)
    local lateralSpeed = lateralVelocity.Magnitude
    local verticalSpeed = math.abs(velocity.Y)
    local verticalAccel = math.abs(accel.Y)
    local speed = velocity.Magnitude
    local distanceRatio = 0

    local startDist = self.Prediction.DISTANCE_PREDICTION_START or 180
    local maxDist = self.Prediction.DISTANCE_PREDICTION_MAX or math.max(startDist + 1, 1800)
    if distance > startDist then
        distanceRatio = math.clamp((distance - startDist) / math.max(maxDist - startDist, 1), 0, 1)
    end

    local orbitDistance = self.Prediction.CLOSE_ORBIT_DISTANCE or 135
    local orbitRatio = 0
    if distance <= orbitDistance * 1.2 then
        orbitRatio = math.clamp(1 - (distance / math.max(orbitDistance * 1.2, 1)), 0, 1)
    end

    return {
        Confidence = confidence,
        ShockAlpha = shockAlpha,
        Speed = speed,
        ForwardSpeed = forwardSpeed,
        LateralSpeed = lateralSpeed,
        VerticalSpeed = verticalSpeed,
        VerticalAccel = verticalAccel,
        Distance = distance,
        DistanceRatio = distanceRatio,
        OrbitRatio = orbitRatio,
        IsTeleport = est.IsTeleport == true,
        AccelMagnitude = accel.Magnitude,
        JerkMagnitude = jerk.Magnitude,
    }
end

function TechniqueSelector:_scoreLinear(metrics)
    local score = 0.38
        + (metrics.Confidence * 0.34)
        + ((1 - metrics.ShockAlpha) * 0.18)
        + ((1 - math.clamp(metrics.LateralSpeed / 120, 0, 1)) * 0.12)
    return score, "stable forward motion"
end

function TechniqueSelector:_scoreStrafe(metrics)
    local lateralAlpha = math.clamp(metrics.LateralSpeed / 110, 0, 1)
    local score = 0.18
        + (lateralAlpha * 0.46)
        + (metrics.Confidence * 0.16)
        + ((1 - metrics.ShockAlpha) * 0.08)
        + (metrics.DistanceRatio * 0.06)
    return score, "high lateral movement"
end

function TechniqueSelector:_scoreOrbit(metrics)
    local orbitiness = math.clamp(metrics.LateralSpeed / math.max(metrics.Speed, 1), 0, 1)
    local lowForward = 1 - math.clamp(math.abs(metrics.ForwardSpeed) / math.max(metrics.Speed, 1), 0, 1)
    local score = 0.12
        + (metrics.OrbitRatio * 0.28)
        + (orbitiness * 0.26)
        + (lowForward * 0.16)
        + (metrics.Confidence * 0.12)
    return score, "close circular strafe"
end

function TechniqueSelector:_scoreAirborne(metrics, entry)
    local airborneAlpha = math.clamp(metrics.VerticalSpeed / 50, 0, 1)
    local accelAlpha = math.clamp(metrics.VerticalAccel / 120, 0, 1)
    local score = 0.14
        + (airborneAlpha * 0.42)
        + (accelAlpha * 0.16)
        + (metrics.Confidence * 0.14)

    if entry and entry.PrimaryPart and math.abs(entry.PrimaryPart.AssemblyLinearVelocity.Y) > 6 then
        score = score + 0.08
    end

    return score, "strong vertical motion"
end

function TechniqueSelector:_scoreDash(metrics)
    local score = 0.08
        + (metrics.ShockAlpha * 0.44)
        + (math.clamp(metrics.AccelMagnitude / 260, 0, 1) * 0.14)
        + (math.clamp(metrics.JerkMagnitude / 2200, 0, 1) * 0.14)

    if metrics.IsTeleport then
        score = score + 0.22
    end

    return score, metrics.IsTeleport and "teleport / blink shock" or "dash or hard direction break"
end

function TechniqueSelector:_pickAssisted(entry, metrics)
    local scores = {}

    local linearScore, linearReason = self:_scoreLinear(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_LINEAR, linearReason, linearScore, metrics.Confidence)

    local strafeScore, strafeReason = self:_scoreStrafe(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_STRAFE, strafeReason, strafeScore, metrics.Confidence)

    local orbitScore, orbitReason = self:_scoreOrbit(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_ORBIT, orbitReason, orbitScore, metrics.Confidence)

    local airborneScore, airborneReason = self:_scoreAirborne(metrics, entry)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_AIRBORNE, airborneReason, airborneScore, metrics.Confidence)

    local dashScore, dashReason = self:_scoreDash(metrics)
    scores[#scores + 1] = self:_makeDecision(TECHNIQUE_DASH, dashReason, dashScore, metrics.Confidence)

    local best = scores[1]
    local byTechnique = {}
    for i = 1, #scores do
        local decision = scores[i]
        byTechnique[decision.Technique] = decision
        if decision.Score > best.Score then
            best = decision
        end
    end

    local state = self:_getState(entry)
    local now = os.clock()
    if state and state.Technique then
        local current = byTechnique[state.Technique]
        if current then
            local withinHold = (now - state.LastSwitch) < self._holdTime
            local closeEnough = current.Score >= (best.Score - self._stickMargin)
            if withinHold or closeEnough then
                current.Reason = withinHold and ("holding " .. string.lower(state.Technique)) or current.Reason
                best = current
            end
        end
    end

    if state then
        if state.Technique ~= best.Technique then
            state.Technique = best.Technique
            state.LastSwitch = now
        end
        state.LastReason = best.Reason
    end

    return best
end

function TechniqueSelector:Decide(origin, targetPos, est, entry)
    if not entry or not targetPos then
        return self:_makeDecision(TECHNIQUE_LINEAR, "no target", 0, 0)
    end

    if self:_getMode() == "Manual" then
        return self:_makeDecision(self:_getManualTechnique(), "manual override", 1, math.clamp(est.Confidence or 0, 0, 1))
    end

    local metrics = self:_collectMetrics(origin, targetPos, est)
    return self:_pickAssisted(entry, metrics)
end

return TechniqueSelector
