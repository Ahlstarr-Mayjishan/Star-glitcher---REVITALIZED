local Players = game:GetService("Players")
local clock = os.clock

local LocalCharacter = {}
LocalCharacter.__index = LocalCharacter

function LocalCharacter.new(taskScheduler)
    local self = setmetatable({}, LocalCharacter)
    self.Player = Players.LocalPlayer
    self.TaskScheduler = taskScheduler
    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil
    self.PlayerGui = nil
    self.LastSpawnTime = 0
    self.RespawnGracePeriod = 1.25
    self._connections = {}
    self._characterConnections = {}
    self._characterParts = {}
    self._characterPartIndex = {}
    self._schedulerAlive = false
    return self
end

function LocalCharacter:_disconnectCharacterSignals()
    for _, connection in ipairs(self._characterConnections) do
        connection:Disconnect()
    end
    table.clear(self._characterConnections)
end

function LocalCharacter:_clearPartCache()
    table.clear(self._characterParts)
    table.clear(self._characterPartIndex)
end

function LocalCharacter:_trackPart(part)
    if not part or not part:IsA("BasePart") or self._characterPartIndex[part] then
        return
    end

    self._characterParts[#self._characterParts + 1] = part
    self._characterPartIndex[part] = #self._characterParts
end

function LocalCharacter:_untrackPart(part)
    local index = self._characterPartIndex[part]
    if not index then
        return
    end

    local lastIndex = #self._characterParts
    local lastPart = self._characterParts[lastIndex]
    self._characterParts[index] = lastPart
    self._characterParts[lastIndex] = nil
    self._characterPartIndex[part] = nil

    if lastPart and lastPart ~= part then
        self._characterPartIndex[lastPart] = index
    end
end

function LocalCharacter:_rebuildPartCache(character)
    self:_disconnectCharacterSignals()
    self:_clearPartCache()

    if not character then
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        self:_trackPart(descendant)
    end

    self._characterConnections[#self._characterConnections + 1] = character.DescendantAdded:Connect(function(descendant)
        self:_trackPart(descendant)
    end)
    self._characterConnections[#self._characterConnections + 1] = character.DescendantRemoving:Connect(function(descendant)
        self:_untrackPart(descendant)
    end)
end

function LocalCharacter:_refresh(character)
    local characterChanged = character ~= self.Character
    self.Character = character
    self.Humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    self.RootPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart")
    ) or nil
    self.PlayerGui = self.Player and self.Player:FindFirstChildOfClass("PlayerGui") or nil

    if characterChanged then
        self:_rebuildPartCache(character)
    end
end

function LocalCharacter:_queueRefresh()
    if not self.TaskScheduler or not self._schedulerAlive then
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._schedulerAlive then
            return
        end

        local currentCharacter = selfRef.Player and selfRef.Player.Character or nil
        selfRef:_refresh(currentCharacter)

        task.delay(0.25, function()
            if selfRef._schedulerAlive then
                selfRef:_queueRefresh()
            end
        end)
    end, "__STAR_GLITCHER_LOCAL_CHARACTER_REFRESH")
end

function LocalCharacter:Init()
    self:_refresh(self.Player and self.Player.Character or nil)
    self._schedulerAlive = true

    if self.Character then
        self.LastSpawnTime = clock()
    end

    if not self.Player then
        return
    end

    table.insert(self._connections, self.Player.CharacterAdded:Connect(function(character)
        self.LastSpawnTime = clock()
        self:_refresh(character)
    end))

    table.insert(self._connections, self.Player.CharacterRemoving:Connect(function(character)
        if self.Character == character then
            self:_refresh(nil)
        end
    end))

    self:_queueRefresh()
end

function LocalCharacter:GetCharacter()
    local character = self.Player and self.Player.Character or nil
    if character ~= self.Character then
        self:_refresh(character)
        if character then
            self.LastSpawnTime = clock()
        end
    end
    return self.Character
end

function LocalCharacter:GetHumanoid()
    local character = self:GetCharacter()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
    if humanoid ~= self.Humanoid then
        self.Humanoid = humanoid
    end
    return self.Humanoid
end

function LocalCharacter:GetRootPart()
    local character = self:GetCharacter()
    local rootPart = character and (
        character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChildWhichIsA("BasePart")
    ) or nil
    if rootPart ~= self.RootPart then
        self.RootPart = rootPart
    end
    return self.RootPart
end

function LocalCharacter:GetState()
    return self:GetCharacter(), self:GetHumanoid(), self:GetRootPart()
end

function LocalCharacter:GetCharacterParts()
    self:GetCharacter()
    return self._characterParts
end

function LocalCharacter:IsLocalHumanoid(instance)
    local humanoid = self:GetHumanoid()
    return humanoid ~= nil and instance == humanoid
end

function LocalCharacter:IsRespawning()
    if not self.Character then
        return false
    end
    return (clock() - (self.LastSpawnTime or 0)) < self.RespawnGracePeriod
end

function LocalCharacter:Destroy()
    self._schedulerAlive = false

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
    self:_disconnectCharacterSignals()
    self:_clearPartCache()
end

return LocalCharacter
