--!strict

local AimMath = {}

function AimMath.FrameRateIndependentAlpha(baseAlpha: number, dt: number?, referenceFps: number?): number
    local clampedBase = math.clamp(baseAlpha, 0.0001, 1)
    local safeDt = math.clamp(dt or (1 / 60), 1 / 240, 0.1)
    local fps = math.max(referenceFps or 60, 1)
    return 1 - ((1 - clampedBase) ^ (safeDt * fps))
end

function AimMath.ExponentialAlpha(rate: number, dt: number?): number
    local safeRate = math.max(rate, 0)
    local safeDt = math.clamp(dt or (1 / 60), 1 / 240, 0.1)
    return 1 - math.exp(-safeRate * safeDt)
end

function AimMath.ShouldRefreshVisibility(
    now: number,
    lastCheck: number?,
    originMovementSquared: number,
    targetMovementSquared: number,
    interval: number,
    movementThresholdSquared: number
): boolean
    if lastCheck == nil or (now - lastCheck) >= interval then
        return true
    end

    return originMovementSquared >= movementThresholdSquared
        or targetMovementSquared >= movementThresholdSquared
end

return AimMath
