--[[
    NPCTracker.lua - Neural Entity Management Class
    Track, categorize, and filter game entities (NPCs/Mobs/Bosses).
    Fixes: Non-humanoid boss support and performance bottlenecks.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local NPCTracker = {}
NPCTracker.__index = NPCTracker

local DECORATIVE_NAME_HINTS = {
    "statue", "tuong", "tượng", "monument", "memorial", "mannequin",
    "display", "showcase", "preview", "sculpture", "dummy", "altar",
    "kiosk", "pedestal",
}

local STRONG_COMBAT_FOLDERS = {
    Enemies = true,
    Monsters = true,
    Bosses = true,
}

local HEALTH_VALUE_NAMES = {
    "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue",
}

local COMBAT_ATTRIBUTE_NAMES = {
    "Targetable", "Enemy", "Hostile", "IsEnemy", "IsBoss", "Boss",
}

function NPCTracker.new(config, detector, taskScheduler, targetClassifier, invalidationPolicy)
    local self = setmetatable({}, NPCTracker)
    self.Options = config.Options
    self.Blacklist = config.Blacklist or {"statue", "tuong", "Minigames", "monument", "altar", "dummy", "board", "spawn", "shop", "gui", "display", "map", "portal", "tele", "rsbroad", "landscape", "terrain", "sign", "summon", "bảng", "prompt", "interact"}
    self._blacklistLower = {}
    self.Detector = detector
    self.TaskScheduler = taskScheduler
    self.TargetClassifier = targetClassifier
    self.InvalidationPolicy = invalidationPolicy
    self.NativeTargetPolicy = nil
    
    self.CurrentTargetEntry = nil
    self._entries = {}
    self._folders = {"Entities", "Enemies", "Monsters", "NPCs", "Bosses"} -- Expanded folder list
    
    -- Performance: Polling Strategy
    self._lastScan = 0
    self._scanInterval = 0.1 -- Scan every 100ms instead of every frame
    self._dirtyScanInterval = 0.035
    self._cachedTargets = {}
    self._cacheDirty = true
    self._folderRefs = {}
    self._folderConnections = {}
    self._modelConnections = {}
    self._lastFolderRefresh = 0
    self._folderRefreshInterval = 2
    self._staleSweepInterval = 3
    self._entryExpiry = 18
    self._deadEntryExpiry = 6
    self._maxEntries = 180
    self._bossRefreshInterval = 1
    self._targetValidationInterval = 0.12
    self._schedulerAlive = false
    self._staleSweepScheduled = false
    self._staleSweepGeneration = 0

    for i, keyword in ipairs(self.Blacklist) do
        self._blacklistLower[i] = string.lower(keyword)
    end
    
    return self
end

function NPCTracker:SetNativeTargetPolicy(nativeTargetPolicy)
    self.NativeTargetPolicy = nativeTargetPolicy
end

function NPCTracker:Init()
    self._schedulerAlive = true
    self._cacheDirty = true
    self:_refreshFolderRefs()
    self:_queueStaleSweep()
end

function NPCTracker:Prune(now)
    now = now or os.clock()
    local entryCount = 0

    for model, entry in pairs(self._entries) do
        entryCount = entryCount + 1
        local lastSeen = entry and entry.LastSeen or 0
        local isDead = entry and entry.Humanoid and entry.Humanoid.Health <= 0
        local expiry = isDead and self._deadEntryExpiry or self._entryExpiry

        if not model
            or not model.Parent
            or not entry
            or not entry.PrimaryPart
            or not entry.PrimaryPart.Parent
            or not self:IsEntryTargetable(entry, true)
            or (lastSeen > 0 and (now - lastSeen) > expiry) then
            self._entries[model] = nil
        end
    end

    if entryCount > self._maxEntries then
        for model, entry in pairs(self._entries) do
            if not entry or (entry.LastSeen or 0) < (now - 4) then
                self._entries[model] = nil
            end
        end
    end
end

function NPCTracker:_disconnectModel(model)
    local connections = self._modelConnections[model]
    if not connections then
        return
    end
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    self._modelConnections[model] = nil
end

function NPCTracker:_invalidateModel(model, resetBoss, resetPart)
    local entry = self._entries[model]
    if entry then
        entry.LastValidation = 0
        if resetBoss then
            entry.LastBossCheck = 0
        end
        if resetPart then
            entry.ResolvedTargetPart = nil
            entry.ResolvedTargetKey = nil
        end
    end
    if resetBoss and self.Detector and self.Detector.Invalidate then
        self.Detector:Invalidate(model)
    end
    self._cacheDirty = true
end

function NPCTracker:_watchModel(model)
    if not model or not model:IsA("Model") or self._modelConnections[model] then
        return
    end

    local selfRef = self
    local connections = {}
    local function onDescendantChanged(descendant)
        local entry = selfRef._entries[model]
        local primaryPart = entry and entry.PrimaryPart
        local policyClass = descendant.ClassName
        if descendant:IsA("BasePart") then
            policyClass = "BasePart"
        elseif descendant:IsA("Humanoid") then
            policyClass = "Humanoid"
        elseif descendant:IsA("Folder") then
            policyClass = "Folder"
        elseif descendant:IsA("ValueBase") then
            policyClass = "ValueBase"
        end
        local action = selfRef.InvalidationPolicy.ClassifyDescendant(
            policyClass,
            descendant.Name,
            tostring(selfRef.Options.TargetPart or "HumanoidRootPart"),
            primaryPart ~= nil and primaryPart.Parent ~= nil
        )
        if action then
            selfRef:_invalidateModel(model, action.ResetBoss, action.ResetPart)
        end
    end

    connections[#connections + 1] = model.DescendantAdded:Connect(function(descendant)
        onDescendantChanged(descendant)
    end)
    connections[#connections + 1] = model.DescendantRemoving:Connect(function(descendant)
        onDescendantChanged(descendant)
    end)
    connections[#connections + 1] = model.AttributeChanged:Connect(function(attributeName)
        local action = selfRef.InvalidationPolicy.ClassifyAttribute(attributeName)
        if action then
            selfRef:_invalidateModel(model, action.ResetBoss, action.ResetPart)
        end
    end)
    connections[#connections + 1] = model.AncestryChanged:Connect(function(_, parent)
        if not parent then
            selfRef._entries[model] = nil
            selfRef:_disconnectModel(model)
        end
        selfRef._cacheDirty = true
    end)
    self._modelConnections[model] = connections
end

function NPCTracker:_refreshFolderRefs()
    local changed = false
    for i = 1, #self._folders do
        local nextFolder = Workspace:FindFirstChild(self._folders[i])
        if self._folderRefs[i] ~= nextFolder then
            changed = true
            self._folderRefs[i] = nextFolder
        end
    end

    if changed then
        for _, connection in ipairs(self._folderConnections) do
            connection:Disconnect()
        end
        table.clear(self._folderConnections)

        local selfRef = self
        for _, folder in ipairs(self._folderRefs) do
            if folder then
                for _, child in ipairs(folder:GetChildren()) do
                    self:_watchModel(child)
                end
                self._folderConnections[#self._folderConnections + 1] = folder.ChildAdded:Connect(function(child)
                    selfRef:_watchModel(child)
                    selfRef._cacheDirty = true
                end)
                self._folderConnections[#self._folderConnections + 1] = folder.ChildRemoved:Connect(function(child)
                    selfRef._entries[child] = nil
                    selfRef:_disconnectModel(child)
                    selfRef._cacheDirty = true
                end)
            end
        end
        self._cacheDirty = true
    end
end

function NPCTracker:_queueFolderRefresh()
    if not self.TaskScheduler or not self._schedulerAlive then
        self:_refreshFolderRefs()
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if selfRef._schedulerAlive then
            selfRef:_refreshFolderRefs()
        end
    end, "__STAR_GLITCHER_TRACKER_FOLDER_REFRESH")
end

function NPCTracker:_queueStaleSweep()
    if not self.TaskScheduler or not self._schedulerAlive or self._staleSweepScheduled then
        return
    end

    self._staleSweepScheduled = true
    self._staleSweepGeneration = self._staleSweepGeneration + 1
    local generation = self._staleSweepGeneration
    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._schedulerAlive then
            selfRef._staleSweepScheduled = false
            return
        end

        if generation ~= selfRef._staleSweepGeneration then
            selfRef._staleSweepScheduled = false
            return
        end

        selfRef:Prune(os.clock())
        selfRef._staleSweepScheduled = false

        task.delay(selfRef._staleSweepInterval, function()
            if selfRef._schedulerAlive and generation == selfRef._staleSweepGeneration then
                selfRef:_queueStaleSweep()
            end
        end)
    end, "__STAR_GLITCHER_TRACKER_STALE_SWEEP")
end

function NPCTracker:IsLocalCharacterModel(model)
    return model ~= nil and model == Players.LocalPlayer.Character
end

function NPCTracker:_HasBlacklistedName(model)
    if not model then return false end
    local modelName = string.lower(model.Name)
    for _, keyword in ipairs(self._blacklistLower) do
        if modelName:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

function NPCTracker:_HasDecorativeLineage(model)
    local current = model
    local depth = 0

    while current and current ~= Workspace and depth < 4 do
        local name = string.lower(tostring(current.Name or ""))
        for _, hint in ipairs(DECORATIVE_NAME_HINTS) do
            if name:find(hint, 1, true) then
                return true
            end
        end
        current = current.Parent
        depth = depth + 1
    end

    return false
end

function NPCTracker:_GetCombatFolderConfidence(model)
    for _, folder in ipairs(self._folderRefs) do
        if folder and (model.Parent == folder or model:IsDescendantOf(folder)) then
            local authoritativeEntityFolder = folder.Name == "Entities"
                and model.Parent == folder
            return STRONG_COMBAT_FOLDERS[folder.Name] == true, authoritativeEntityFolder
        end
    end
    return false, false
end

function NPCTracker:_HasExplicitCombatMarker(model)
    for _, attributeName in ipairs(COMBAT_ATTRIBUTE_NAMES) do
        if model:GetAttribute(attributeName) == true then
            return true
        end
    end

    for _, markerName in ipairs(COMBAT_ATTRIBUTE_NAMES) do
        local marker = model:FindFirstChild(markerName)
        if marker and marker:IsA("BoolValue") and marker.Value == true then
            return true
        end
    end

    local entityType = model:FindFirstChild("EntityType")
    if entityType and entityType:IsA("ValueBase") then
        return true
    end

    return false
end

function NPCTracker:_GetStatusFolder(model)
    return model and model:FindFirstChild("Status") or nil
end

function NPCTracker:_ReadStatusValue(model, name)
    local status = self:_GetStatusFolder(model)
    if not status then
        return nil
    end

    local direct = status:FindFirstChild(name)
    if direct and direct:IsA("ValueBase") then
        return direct.Value
    end

    local attributes = status:FindFirstChild("Attributes")
    local valueObject = attributes and attributes:FindFirstChild(name)
    if valueObject and valueObject:IsA("ValueBase") then
        return valueObject.Value
    end
    return nil
end

function NPCTracker:_IsParentRelatedToLocalPlayer(model)
    local localCharacter = Players.LocalPlayer.Character
    if not localCharacter then
        return false
    end

    local targetParentEntity = model:FindFirstChild("ParentEntity")
    if targetParentEntity
        and targetParentEntity:IsA("ObjectValue")
        and targetParentEntity.Value == localCharacter then
        return true
    end

    local localParentEntity = localCharacter:FindFirstChild("ParentEntity")
    return localParentEntity
        and localParentEntity:IsA("ObjectValue")
        and localParentEntity.Value == model
end

function NPCTracker:_PassesNativeTargetPolicy(model)
    if not self.NativeTargetPolicy then
        return true
    end

    local extraNPC = Workspace:FindFirstChild("ExtraNPC")
    local localCharacter = Players.LocalPlayer.Character
    return self.NativeTargetPolicy.IsEligible({
        IsExtraNPC = extraNPC ~= nil and model.Parent == extraNPC,
        IsSafeZoned = self:_ReadStatusValue(model, "SafeZoned") == true,
        TargetTeam = tonumber(self:_ReadStatusValue(model, "Team")),
        LocalTeam = tonumber(self:_ReadStatusValue(localCharacter, "Team")),
        IsParentRelated = self:_IsParentRelatedToLocalPlayer(model),
    })
end

function NPCTracker:_ReadHealthSignal(model, humanoid)
    if humanoid then
        return humanoid.Health, humanoid.MaxHealth
    end

    for _, valueName in ipairs(HEALTH_VALUE_NAMES) do
        local valueObject = model:FindFirstChild(valueName, true)
        if valueObject and (valueObject:IsA("NumberValue") or valueObject:IsA("IntValue")) then
            return tonumber(valueObject.Value), tonumber(valueObject.Value)
        end
    end

    local health = tonumber(model:GetAttribute("Health")) or tonumber(model:GetAttribute("HP"))
    local maxHealth = tonumber(model:GetAttribute("MaxHealth")) or tonumber(model:GetAttribute("MaxHP"))
    return health, maxHealth
end

function NPCTracker:_GetPrimaryPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
end

function NPCTracker:_IsTargetCandidate(model, existingEntry)
    -- GUARD: Ensure model validity
    if not model or not model:IsA("Model") or self:IsLocalCharacterModel(model) or not model.Parent then
        return false
    end

    -- PVP Check
    local isPlayerCharacter = Players:GetPlayerFromCharacter(model) ~= nil
    if isPlayerCharacter then
        return self.Options.TargetPlayersToggle == true
            and self:_PassesNativeTargetPolicy(model)
    end

    local strongCombatFolder, authoritativeEntityFolder = self:_GetCombatFolderConfidence(model)
    if authoritativeEntityFolder and not self:_PassesNativeTargetPolicy(model) then
        return false
    end

    -- Names such as Cube, Bomb, Stone, or Dummy may be legitimate summoned
    -- bosses. Only bypass the prop-name filter for direct children of the
    -- game's own workspace.Entities combat container.
    if self.TargetClassifier.ShouldRejectStructuralName({
        HasBlacklistedName = self:_HasBlacklistedName(model),
        HasDecorativeLineage = self:_HasDecorativeLineage(model),
        AuthoritativeEntityFolder = authoritativeEntityFolder,
    }) then
        return false
    end

    -- UNIVERSAL TARGETING: Support both Humanoid va Non-Humanoid (Bosses)
    local humanoid = existingEntry and existingEntry.Humanoid or model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    local isBoss = existingEntry and existingEntry.IsBoss
    if isBoss == nil then
        isBoss = self.Detector and self.Detector.IsBoss and self.Detector:IsBoss(model, humanoid)
    end
    
    if not primary then return false end

    -- STATIC OBJECT FILTER: Boss boards, shops, etc.
    -- Mobs/Bosses (even custom ones) usually have unanchored root parts.
    if not humanoid and primary.Anchored and not model:FindFirstChild("Health", true) then
        -- Only block if it's explicitly identified as a board/kiosk
        local lowerName = string.lower(model.Name)
        local isExplicitBoard = lowerName:find("board") or lowerName:find("summon") or lowerName:find("minigame") or lowerName:find("bảng")
        
        if isExplicitBoard then
            local hasUI = model:FindFirstChildWhichIsA("SurfaceGui", true) 
                or model:FindFirstChildWhichIsA("BillboardGui", true)
                or model:FindFirstChildWhichIsA("ProximityPrompt", true)
            
            if hasUI then
                return false
            end
        end
    end

    local health, maxHealth = self:_ReadHealthSignal(model, humanoid)
    if health ~= nil and health <= 0 then
        return false
    end

    local explicitCombatMarker = self:_HasExplicitCombatMarker(model)

    return self.TargetClassifier.ClassifyCombatEvidence({
        IsAlive = health == nil or health > 0,
        IsAnchored = primary.Anchored == true,
        HasHumanoid = humanoid ~= nil,
        Health = health,
        MaxHealth = maxHealth,
        IsBoss = isBoss == true,
        StrongCombatFolder = strongCombatFolder,
        AuthoritativeEntityFolder = authoritativeEntityFolder,
        ExplicitCombatMarker = explicitCombatMarker,
    })
end

function NPCTracker:IsEntryTargetable(entry, forceRefresh)
    if not entry or not entry.Model or not entry.Model.Parent then
        return false
    end

    local now = os.clock()
    if forceRefresh
        or entry.Targetable == nil
        or not entry.LastValidation
        or (now - entry.LastValidation) >= self._targetValidationInterval then
        entry.Targetable = self:_IsTargetCandidate(entry.Model, entry)
        entry.LastValidation = now
    end

    if not entry.Targetable then
        return false
    end

    return not entry.Humanoid or entry.Humanoid.Health > 0
end

function NPCTracker:GetTargets()
    local now = os.clock()

    local scanInterval = self._cacheDirty and self._dirtyScanInterval or self._scanInterval
    if (now - self._lastScan) < scanInterval then
        return self._cachedTargets
    end

    self._lastScan = now
    local result = self._cachedTargets
    table.clear(result)
    local seenModels = {}

    if (now - self._lastFolderRefresh) >= self._folderRefreshInterval then
        self._lastFolderRefresh = now
        self:_queueFolderRefresh()
    end

    local function trackModel(model)
        if not model or seenModels[model] then return end
        seenModels[model] = true
        
        local entry = self:_GetOrCreateEntry(model)
        if entry then
            self:_watchModel(model)
            entry.LastSeen = now
            entry.PrimaryPart = self:_GetPrimaryPart(model) or entry.PrimaryPart
            entry.Humanoid = model:FindFirstChildOfClass("Humanoid") or entry.Humanoid
            if (entry.LastBossCheck or 0) <= 0 or (now - entry.LastBossCheck) >= self._bossRefreshInterval then
                entry.IsBoss = self.Detector:IsBoss(model, entry.Humanoid)
                entry.LastBossCheck = now
            end
            if entry.PrimaryPart then
                entry.LastPos = entry.PrimaryPart.Position
            end

            -- Revalidate structure as well as health so cached statues cannot
            -- remain selectable after the classifier rejects them.
            if self:IsEntryTargetable(entry) then
                result[#result + 1] = entry
                return true
            end
        end
        return false
    end
    
    -- 1. Scan Folders (Entities/NPCs/Bosses)
    for i = 1, #self._folderRefs do
        local f = self._folderRefs[i]
        if f then
            for _, model in ipairs(f:GetChildren()) do
                if model:IsA("Model") then
                    trackModel(model)
                end
            end
        end
    end

    -- 2. Fallback Scan (Entities directly in Workspace)
    -- Skip this broad scan if dedicated entity folders already yielded targets.
    if #result == 0 then
        -- Avoid GetDescendants() which is catastrophic for performance.
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") then
                trackModel(obj)
            end
        end
    end
    
    -- 3. Scan Players (PvP Mode)
    if self.Options.TargetPlayersToggle then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer and p.Character then
                trackModel(p.Character)
            end
        end
    end

    self._cacheDirty = false
    return result
end

function NPCTracker:_GetOrCreateEntry(model)
    local existingEntry = self._entries[model]
    if existingEntry then
        return existingEntry
    end

    if not self:_IsTargetCandidate(model) then
        self._entries[model] = nil
        return nil
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    local primary = self:_GetPrimaryPart(model)
    local now = os.clock()
    
    if not primary then return nil end
    
    local entry = {
        Model = model,
        Humanoid = hum,
        PrimaryPart = primary,
        IsBoss = self.Detector:IsBoss(model, hum),
        Name = model.Name,
        LastPos = primary.Position,
        LastTime = now,
        LastSeen = now,
        LastBossCheck = now,
        LastValidation = now,
        Targetable = true,
    }
    
    self._entries[model] = entry
    return entry
end

function NPCTracker:GetTargetPart(entry)
    local model = entry.Model
    if not model or not model.Parent or self:IsLocalCharacterModel(model) then return nil end

    local targetKey = tostring(self.Options.TargetPart or "HumanoidRootPart")
    local cachedPart = entry.ResolvedTargetPart
    if cachedPart
        and cachedPart.Parent
        and entry.ResolvedTargetKey == targetKey
        and cachedPart:IsDescendantOf(model) then
        return cachedPart
    end

    local targetPart = model:FindFirstChild(targetKey)
    if not targetPart then
        if targetKey == "Torso" then
            targetPart = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
        elseif targetKey == "Head" then
            targetPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        end
    end

    local resolvedPart = targetPart
        or entry.PrimaryPart
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart", true)
    if resolvedPart then
        entry.PrimaryPart = resolvedPart
        entry.ResolvedTargetPart = resolvedPart
        entry.ResolvedTargetKey = targetKey
    end
    return resolvedPart
end

function NPCTracker:GetEntryCount()
    local count = 0
    for _ in pairs(self._entries) do
        count = count + 1
    end
    return count
end

function NPCTracker:ClearCache()
    table.clear(self._entries)
    table.clear(self._cachedTargets)
    self.CurrentTargetEntry = nil
    self._cacheDirty = true
    self._lastScan = 0
end

function NPCTracker:Destroy()
    self._schedulerAlive = false
    self._staleSweepScheduled = false
    self._staleSweepGeneration = self._staleSweepGeneration + 1
    for _, connection in ipairs(self._folderConnections) do
        connection:Disconnect()
    end
    table.clear(self._folderConnections)
    for model in pairs(self._modelConnections) do
        self:_disconnectModel(model)
    end
    self:ClearCache()
end

return NPCTracker

