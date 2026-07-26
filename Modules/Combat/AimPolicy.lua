local AimPolicy = {}

local VALID_MODES = {
    ["Off"] = true,
    ["Camera Lock"] = true,
    ["Silent Aim"] = true,
    ["Highlight Only"] = true,
}

function AimPolicy.GetMode(options)
    local mode = tostring(options.AssistMode or "Off")
    return VALID_MODES[mode] and mode or "Off"
end

function AimPolicy.IsDeadlock(options)
    return tostring(options.TargetingMethod or "FOV") == "Deadlock"
end

function AimPolicy.ShouldMaintain(options, hasTarget)
    return AimPolicy.GetMode(options) ~= "Off"
        and AimPolicy.IsDeadlock(options)
        and hasTarget == true
end

function AimPolicy.ShouldTrack(options, inputActive, hasTarget)
    return AimPolicy.GetMode(options) ~= "Off"
        and (inputActive == true or AimPolicy.ShouldMaintain(options, hasTarget))
end

function AimPolicy.GetScanInterval(options)
    local maxHz = math.clamp(tonumber(options.TargetScanHz) or 120, 30, 240)
    return 1 / maxHz
end

function AimPolicy.AdvanceScan(options, timing, dt, now)
    local interval = AimPolicy.GetScanInterval(options)
    if options.AdaptiveTargetScan == false then
        if (now - timing.LastScan) < interval then
            return false
        end
        timing.LastScan = now
        return true
    end

    local step = math.max(tonumber(dt) or timing.FrameDtEma or (1 / 60), 1 / 240)
    timing.FrameDtEma = timing.FrameDtEma + ((step - timing.FrameDtEma) * 0.18)
    timing.Accumulator = timing.Accumulator + step
    if timing.Accumulator < interval then
        return false
    end

    timing.Accumulator = math.max(0, timing.Accumulator - interval)
    if timing.Accumulator > (interval * 1.5) then
        timing.Accumulator = interval
    end
    timing.LastScan = now
    return true
end

function AimPolicy.ResetScan(timing)
    timing.Accumulator = 0
end

return AimPolicy
