--[[
    SilentResolver.lua - Silent Aim-Specific Aim Point Resolver
    Job: Convert raw prediction into a hitbox-safe aim point tuned for silent aim.
    Notes: Kept separate from aim-lock so packet aim can be sharper than visual aim.
]]

local SilentResolver = {}
SilentResolver.__index = SilentResolver

local function getEntryExtents(entry, part)
    local extents = part and part.Size or Vector3.new(2, 2, 2)
    local model = entry and entry.Model

    if model then
        local ok, modelExtents = pcall(model.GetExtentsSize, model)
        if ok and typeof(modelExtents) == "Vector3" then
            extents = Vector3.new(
                math.max(extents.X, modelExtents.X),
                math.max(extents.Y, modelExtents.Y),
                math.max(extents.Z, modelExtents.Z)
            )
        end
    end

    return extents
end

local function classifyAimProfile(entry, part, extents)
    if part and part:IsA("Part") and part.Shape == Enum.PartType.Ball then
        return "sphere"
    end

    if entry and entry.Humanoid then
        local isMini = math.min(extents.X, extents.Y, extents.Z) <= 2.4
            or extents.Y <= 4.3
            or (part and part.Size.Y <= 2.6)
            or entry.Humanoid.HipHeight <= 1.5

        return isMini and "mini_humanoid" or "humanoid"
    end

    return "box"
end

local function clampBoxOffset(offset, extents, innerScale)
    local half = extents * 0.5 * innerScale
    return Vector3.new(
        math.clamp(offset.X, -half.X, half.X),
        math.clamp(offset.Y, -half.Y, half.Y),
        math.clamp(offset.Z, -half.Z, half.Z)
    )
end

function SilentResolver.new(config)
    local self = setmetatable({}, SilentResolver)
    self.Options = config and config.Options or {}
    self.Prediction = config and config.Prediction or {}
    return self
end

function SilentResolver:Resolve(targetPart, targetPos, currentEntry)
    if not targetPart or not targetPos then
        return targetPos
    end

    local extents = getEntryExtents(currentEntry, targetPart)
    local minAxis = math.min(extents.X, extents.Y, extents.Z)
    local maxAxis = math.max(extents.X, extents.Y, extents.Z)
    local profile = classifyAimProfile(currentEntry, targetPart, extents)

    local center = targetPart.Position
    if profile == "mini_humanoid" then
        center = center + Vector3.new(0, math.clamp(extents.Y * 0.12, 0.16, 0.4), 0)
    elseif profile == "humanoid" then
        center = center + Vector3.new(0, math.clamp(extents.Y * 0.05, 0.08, 0.22), 0)
    end

    local rawOffset = targetPos - center
    if rawOffset.Magnitude <= 0.001 then
        return center
    end

    local tinyAlpha = math.clamp((2.8 - minAxis) / 1.8, 0, 1)
    local narrowAlpha = math.clamp((4.2 - maxAxis) / 2.6, 0, 1)
    local centerBias = math.max(tinyAlpha, narrowAlpha * 0.75)
    local innerScale = 0.42

    if profile == "mini_humanoid" then
        innerScale = 0.28
        centerBias = math.max(centerBias, 0.55)
    elseif profile == "humanoid" then
        innerScale = 0.34
        centerBias = math.max(centerBias, 0.2)
    elseif profile == "sphere" then
        innerScale = 0.4
    end

    local clampedOffset
    if profile == "sphere" then
        local radius = math.max(minAxis * 0.5 * innerScale, 0.2)
        clampedOffset = rawOffset.Magnitude > radius and (rawOffset.Unit * radius) or rawOffset
    else
        clampedOffset = clampBoxOffset(rawOffset, extents, innerScale)
    end

    local clampedPos = center + clampedOffset
    if centerBias > 0 then
        clampedPos = clampedPos:Lerp(center, math.clamp(centerBias * 0.45, 0, 0.4))
    end

    return clampedPos
end

return SilentResolver
