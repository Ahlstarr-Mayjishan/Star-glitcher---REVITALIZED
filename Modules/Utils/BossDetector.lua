--[[
    BossDetector.lua - OOP Target Classification Class
    Identifies bosses across humanoid and non-humanoid enemy types.
]]

local BossDetector = {}
BossDetector.__index = BossDetector

local NAME_HINTS = {
    "boss", "king", "queen", "lord", "orb", "sphere", "core",
}

local HEALTH_HINTS = {
    "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue",
}

local function containsBossHint(text)
    local lowered = string.lower(tostring(text or ""))
    for _, hint in ipairs(NAME_HINTS) do
        if lowered:find(hint, 1, true) then
            return true
        end
    end
    return false
end

local function getModelBounds(model)
    if not model or not model:IsA("Model") then
        return Vector3.new(0, 0, 0), 0
    end

    local ok, _, size = pcall(model.GetBoundingBox, model)
    if ok and typeof(size) == "Vector3" then
        return size, size.X * size.Y * size.Z
    end

    local minPos = Vector3.new(math.huge, math.huge, math.huge)
    local maxPos = Vector3.new(-math.huge, -math.huge, -math.huge)
    local foundPart = false

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            foundPart = true
            local half = descendant.Size * 0.5
            local pos = descendant.Position
            minPos = Vector3.new(
                math.min(minPos.X, pos.X - half.X),
                math.min(minPos.Y, pos.Y - half.Y),
                math.min(minPos.Z, pos.Z - half.Z)
            )
            maxPos = Vector3.new(
                math.max(maxPos.X, pos.X + half.X),
                math.max(maxPos.Y, pos.Y + half.Y),
                math.max(maxPos.Z, pos.Z + half.Z)
            )
        end
    end

    if not foundPart then
        return Vector3.new(0, 0, 0), 0
    end

    local fallbackSize = maxPos - minPos
    return fallbackSize, fallbackSize.X * fallbackSize.Y * fallbackSize.Z
end

local function getLargestPart(model)
    local bestPart = nil
    local bestVolume = -1

    if not model then
        return nil
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
            if volume > bestVolume then
                bestPart = descendant
                bestVolume = volume
            end
        end
    end

    return bestPart
end

local function getPrimaryPart(model)
    if not model then
        return nil
    end

    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or getLargestPart(model)
end

local function readHealthLikeValue(model, humanoid)
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end

    if not model then
        return nil, nil
    end

    for _, hint in ipairs(HEALTH_HINTS) do
        local child = model:FindFirstChild(hint, true)
        if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
            local value = tonumber(child.Value)
            if value then
                return value, value
            end
        end
    end

    local attrHealth = tonumber(model:GetAttribute("Health")) or tonumber(model:GetAttribute("HP"))
    local attrMaxHealth = tonumber(model:GetAttribute("MaxHealth")) or tonumber(model:GetAttribute("MaxHP"))
    if attrHealth or attrMaxHealth then
        return attrHealth or attrMaxHealth, attrMaxHealth or attrHealth
    end

    return nil, nil
end

function BossDetector.new()
    local self = setmetatable({}, BossDetector)
    self.CheckInterval = 10
    self._cache = setmetatable({}, { __mode = "k" })
    self._destroyed = false
    return self
end

function BossDetector:Init()
    self._destroyed = false
end

function BossDetector:IsBoss(model, humanoid)
    if self._destroyed then
        return false
    end

    if not model or not model:IsA("Model") then
        return false
    end

    -- Native boss indicators and minigame spawning use this attribute as the
    -- authoritative classification. Respect explicit false as well as true.
    local nativeBoss = model:GetAttribute("IsBoss")
    if nativeBoss ~= nil then
        return nativeBoss == true
    end

    local now = os.clock()
    local cached = self._cache[model]
    if cached and cached.ExpiresAt and cached.ExpiresAt > now then
        return cached.Value == true
    end

    local primary = getPrimaryPart(model)
    local size, boundsScale = getModelBounds(model)
    local health, maxHealth = readHealthLikeValue(model, humanoid or model:FindFirstChildOfClass("Humanoid"))
    local nameHint = containsBossHint(model.Name)
    local displayHint = humanoid and containsBossHint(humanoid.DisplayName)
    local primaryIsBall = primary and primary:IsA("Part") and primary.Shape == Enum.PartType.Ball
    local isAnchored = primary and primary.Anchored == true
    local hasStrongHealthSignal = (maxHealth and maxHealth > 500)
        or (not humanoid and health and health > 0)
    local isBoss = false
    local isStaticBoard = false
    local lowerName = string.lower(model.Name)
    local isOrbType = lowerName:find("orb") or lowerName:find("sphere") or lowerName:find("core")

    -- Verify if it's a static board/info sign
    if not humanoid and (primary and primary.Anchored) and not isOrbType then
        local hasUI = model:FindFirstChildWhichIsA("SurfaceGui", true) 
            or model:FindFirstChildWhichIsA("BillboardGui", true)
            or model:FindFirstChildWhichIsA("ProximityPrompt", true)

        if hasUI then
            if lowerName:find("board") or lowerName:find("summon") or lowerName:find("minigame") or lowerName:find("kiosk") or lowerName:find("sign") or lowerName:find("bảng") then
                isStaticBoard = true
            end
        end
    end

    -- Large decorative rigs and statues used to become bosses solely because
    -- their bounding box exceeded the size threshold. Anchored models require
    -- a meaningful combat-health signal before shape/name heuristics apply.
    if isStaticBoard or (isAnchored and not hasStrongHealthSignal) then
        isBoss = false
    elseif displayHint
        or nameHint
        or isOrbType
        or (maxHealth and maxHealth > 500)
        or (boundsScale > 70 and (not isAnchored or hasStrongHealthSignal)) then
        -- Name hints, high health, bounds, or specific shapes (Orbs) are strong boss indicators
        isBoss = true
    elseif primaryIsBall then
        local maxAxis = math.max(size.X, size.Y, size.Z, primary.Size.X, primary.Size.Y, primary.Size.Z)
        local minAxis = math.min(primary.Size.X, primary.Size.Y, primary.Size.Z)

        if maxAxis >= 5 or (minAxis >= 3.5 and (health or 0) > 150) then
            isBoss = true
        end
    end

    self._cache[model] = {
        Value = isBoss,
        ExpiresAt = now + math.max(self.CheckInterval or 10, 1),
    }

    return isBoss
end

function BossDetector:Destroy()
    self._destroyed = true
    table.clear(self._cache)
end

return BossDetector
