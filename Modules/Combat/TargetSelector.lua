--[[
    TargetSelector.lua - OOP Target Selection Class
    Logic for finding the most optimal target based on distance and FOV.
    Optimized for crosshair proximity with lightweight sticky targeting.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TargetSelector = {}
TargetSelector.__index = TargetSelector

function TargetSelector.new(config, tracker, predictor, aimMath)
    local self = setmetatable({}, TargetSelector)
    self.Options = config.Options
    self.Tracker = tracker
    self.Predictor = predictor
    self.AimMath = aimMath
    self._stickyBias = 1.12
    self._destroyed = false
    self._visibilityCache = setmetatable({}, { __mode = "k" })
    self._raycastParams = RaycastParams.new()
    self._raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    self._raycastParams.IgnoreWater = true
    self._raycastFilter = {}
    return self
end

function TargetSelector:Init()
    self._destroyed = false
end

function TargetSelector:_getMethod()
    local method = tostring(self.Options.TargetingMethod or "FOV")
    if method == "Distance" or method == "Deadlock" then
        return method
    end
    return "FOV"
end

function TargetSelector:_isEntryValid(entry, localCharacter, originPos, maxDistance)
    if not entry or not entry.Model or entry.Model == localCharacter then
        return nil, nil, nil
    end

    if self.Tracker.IsEntryTargetable and not self.Tracker:IsEntryTargetable(entry) then
        return nil, nil, nil
    end

    local part = self.Tracker:GetTargetPart(entry)
    if not part or (localCharacter and part:IsDescendantOf(localCharacter)) then
        return nil, nil, nil
    end

    local toTarget = part.Position - originPos
    local distance = toTarget.Magnitude
    if distance > maxDistance then
        return nil, nil, nil
    end

    return part, distance, toTarget
end

function TargetSelector:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
    local part, distance = self:_isEntryValid(entry, localCharacter, originPos, maxDistance)
    if not part then
        return nil, nil
    end

    if method == "Distance" then
        return distance, part
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return nil, nil
    end

    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return nil, nil
    end

    local dx = screenPos.X - mouseX
    local dy = screenPos.Y - mouseY
    return (dx * dx) + (dy * dy), part
end

function TargetSelector:_hasLineOfSight(entry, part, originPos, localCharacter)
    if self.Options.VisibilityCheckEnabled == false then
        return true
    end

    local targetModel = entry and entry.Model
    if not targetModel or not part then
        return false
    end

    local now = os.clock()
    local targetPos = part.Position
    local cached = self._visibilityCache[entry]
    local originMovementSquared = math.huge
    local targetMovementSquared = math.huge
    if cached then
        local originDelta = originPos - cached.Origin
        local targetDelta = targetPos - cached.Target
        originMovementSquared = originDelta:Dot(originDelta)
        targetMovementSquared = targetDelta:Dot(targetDelta)
    end

    local interval = math.clamp(tonumber(self.Options.VisibilityRefreshInterval) or 0.1, 0.04, 0.5)
    local movementThreshold = math.max(tonumber(self.Options.VisibilityMovementThreshold) or 6, 1)
    local shouldRefresh = self.AimMath.ShouldRefreshVisibility(
        now,
        cached and cached.CheckedAt or nil,
        originMovementSquared,
        targetMovementSquared,
        interval,
        movementThreshold * movementThreshold
    )
    if cached and not shouldRefresh then
        return cached.Visible
    end

    local direction = targetPos - originPos
    local visible = direction.Magnitude <= 0.001
    if not visible then
        local raycastFilter = self._raycastFilter
        table.clear(raycastFilter)
        if localCharacter then
            raycastFilter[1] = localCharacter
        end
        self._raycastParams.FilterDescendantsInstances = raycastFilter
        local result = Workspace:Raycast(originPos, direction, self._raycastParams)
        visible = result == nil
            or result.Instance == part
            or result.Instance:IsDescendantOf(targetModel)
    end

    self._visibilityCache[entry] = {
        CheckedAt = now,
        Origin = originPos,
        Target = targetPos,
        Visible = visible,
    }
    return visible
end

function TargetSelector:GetClosestTarget(mousePos, originPos, preferredEntry)
    if self._destroyed then
        return nil
    end

    local bestTarget = nil
    local localCharacter = Players.LocalPlayer.Character
    local mouseX = mousePos.X
    local mouseY = mousePos.Y
    local maxDistance = self.Options.MaxDistance or 2500
    local method = self:_getMethod()
    local fov = self.Options.FOV or 150
    local bestScore = method == "Distance" and maxDistance or (fov * fov)

    if method == "Deadlock" and preferredEntry then
        local lockedPart = self:_isEntryValid(preferredEntry, localCharacter, originPos, maxDistance)
        if lockedPart and self:_hasLineOfSight(preferredEntry, lockedPart, originPos, localCharacter) then
            return preferredEntry
        end
    end

    -- Keep the current target when it is still meaningfully valid to avoid
    -- rescoring churn and target thrash in crowded scenes.
    if preferredEntry then
        local preferredScore, preferredPart = self:_scoreEntry(
            preferredEntry,
            localCharacter,
            mouseX,
            mouseY,
            originPos,
            maxDistance,
            method
        )
        if preferredScore
            and preferredScore <= (bestScore * self._stickyBias)
            and self:_hasLineOfSight(preferredEntry, preferredPart, originPos, localCharacter) then
            bestTarget = preferredEntry
            bestScore = preferredScore
        end
    end

    local entries = self.Tracker:GetTargets()
    for i = 1, #entries do
        local entry = entries[i]
        if entry ~= preferredEntry then
            local score, part = self:_scoreEntry(entry, localCharacter, mouseX, mouseY, originPos, maxDistance, method)
            if score
                and score < bestScore
                and self:_hasLineOfSight(entry, part, originPos, localCharacter) then
                bestScore = score
                bestTarget = entry
            end
        end
    end

    return bestTarget
end

function TargetSelector:Destroy()
    self._destroyed = true
    table.clear(self._visibilityCache)
end

return TargetSelector
