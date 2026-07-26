--[[
    GarbageCollector.lua - Memory & Workspace Optimization v1.0
    Job: Proactive cleanup of visual debris, effects, and orphaned instances.
    Analogy: The Lymphatic System (Cleaning up cellular debris).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local GarbageCollector = {}
GarbageCollector.__index = GarbageCollector

function GarbageCollector.new(options, resourceManager)
    local self = setmetatable({}, GarbageCollector)
    self.Options = options
    self.ResourceManager = resourceManager
    self.Connection = nil
    self._lastClean = 0
    self._cleanInterval = 60 -- Default to every 60 seconds
    self._queued = {}
    self._queuedMap = setmetatable({}, { __mode = "k" })
    self._queueSize = 0
    self._scanIndex = 1
    self._scanList = nil
    self._scanBatchSize = 30
    self._destroyBudget = 4
    self._collectStepSize = 24
    self._manualBoostUntil = 0
    self._manualDrainCap = 80
    self._frameBudget = 0.0008
    self.Status = "Idle"
    return self
end

local DEBRIS_TAGS = {
    "Debris", "Effect", "Projectile", "Shell", "Bullet", 
    "Particle", "Emitter", "Orb", "Trail", "Beam", "Visual"
}

function GarbageCollector:_getPlayerPosition()
    local char = LocalPlayer and LocalPlayer.Character
    local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    return root and root.Position or nil
end

function GarbageCollector:_isDebrisCandidate(instance, playerPos)
    if not instance or not instance.Parent then
        return false
    end

    if not (instance:IsA("BasePart") or instance:IsA("Model") or instance:IsA("Folder")) then
        return false
    end

    local name = instance.Name:lower()
    local matched = false
    for _, tag in ipairs(DEBRIS_TAGS) do
        if name:find(tag:lower(), 1, true) then
            matched = true
            break
        end
    end
    if not matched or instance:FindFirstChildOfClass("Humanoid") then
        return false
    end

    if not playerPos then
        return true
    end

    local ok, position = pcall(function()
        return instance:GetPivot().Position
    end)
    if not ok then
        return false
    end

    return (position - playerPos).Magnitude > 300
end

function GarbageCollector:_queueInstance(instance)
    if self._queuedMap[instance] then
        return false
    end

    self._queuedMap[instance] = true
    self._queueSize = self._queueSize + 1
    self._queued[self._queueSize] = instance
    return true
end

function GarbageCollector:_beginScan()
    self._scanList = Workspace:GetChildren()
    self._scanIndex = 1
    self.Status = "Scanning Debris"
end

function GarbageCollector:_processScan(batchSize)
    local scanList = self._scanList
    if not scanList then
        return 0, true
    end

    local playerPos = self:_getPlayerPosition()
    local queuedCount = 0
    local endIndex = math.min(self._scanIndex + batchSize - 1, #scanList)

    for i = self._scanIndex, endIndex do
        local instance = scanList[i]
        if self:_isDebrisCandidate(instance, playerPos) and self:_queueInstance(instance) then
            queuedCount = queuedCount + 1
        end
    end

    self._scanIndex = endIndex + 1
    local done = self._scanIndex > #scanList
    if done then
        self._scanList = nil
        self._scanIndex = 1
    end

    return queuedCount, done
end

function GarbageCollector:_processFullScan(batchSize)
    local totalQueued = 0
    local scanBatchSize = math.max(batchSize or self._scanBatchSize, 1)
    local startTime = os.clock()

    while self._scanList do
        local queuedCount = 0
        local done = false
        queuedCount, done = self:_processScan(scanBatchSize)
        totalQueued = totalQueued + (queuedCount or 0)
        
        if done then
            break
        end

        -- Time-slicing: yield to avoid freezing the main thread
        if (os.clock() - startTime) >= 0.0022 then
            task.wait()
            startTime = os.clock() -- Reset timer after yield
        end
    end

    return totalQueued
end

function GarbageCollector:_drainQueue(destroyBudget, gcStepSize, ignoreFrameBudget)
    local destroyed = 0
    local deferred = 0
    local processed = 0
    local startTime = os.clock()

    while self._queueSize > 0 and (destroyBudget == nil or processed < destroyBudget) do
        if not ignoreFrameBudget and (os.clock() - startTime) >= self._frameBudget then
            break
        end

        local instance = self._queued[self._queueSize]
        self._queued[self._queueSize] = nil
        self._queueSize = self._queueSize - 1
        processed = processed + 1

        self._queuedMap[instance] = nil
        if instance and instance.Parent then
            pcall(function()
                instance:Destroy()
            end)
            destroyed = destroyed + 1
        end
    end

    if destroyed > 0 and not self.ResourceManager then
        -- collectgarbage("step", gcStepSize) -- Restricted in some environments
    end

    return destroyed, deferred, processed
end

function GarbageCollector:_stepCleanup()
    local now = os.clock()
    local manualBoost = now < self._manualBoostUntil
    local localPressure = self._queueSize
    local deferredPressure = 0
    if self.ResourceManager and self.ResourceManager.GetPendingCount then
        deferredPressure = self.ResourceManager:GetPendingCount()
    end

    local scanMultiplier = 1
    local destroyMultiplier = 1
    if localPressure >= 1000 then
        scanMultiplier = 1.0
        destroyMultiplier = 6.0
    elseif localPressure >= 500 then
        scanMultiplier = 1.5
        destroyMultiplier = 3.0
    elseif localPressure >= 200 then
        scanMultiplier = 1.7
        destroyMultiplier = 1.5
    elseif localPressure >= 80 then
        scanMultiplier = 1.3
        destroyMultiplier = 1.2
    end

    local scanBatchSize = (manualBoost and math.ceil(self._scanBatchSize * 1.35) or self._scanBatchSize)
    scanBatchSize = math.max(scanBatchSize, math.ceil(scanBatchSize * scanMultiplier))

    local destroyBudget = (manualBoost and math.ceil(self._destroyBudget * 1.5) or self._destroyBudget)
    destroyBudget = math.max(destroyBudget, math.ceil(destroyBudget * destroyMultiplier))
    local gcStepSize = manualBoost and math.ceil(self._collectStepSize * 1.5) or self._collectStepSize

    if deferredPressure >= 400 then
        destroyBudget = math.max(1, math.floor(destroyBudget * 0.25))
    elseif deferredPressure >= 150 then
        destroyBudget = math.max(1, math.floor(destroyBudget * 0.45))
    elseif deferredPressure >= 50 then
        destroyBudget = math.max(1, math.floor(destroyBudget * 0.7))
    end

    if not self._scanList and self._queueSize == 0 then
        if now - self._lastClean < self._cleanInterval then
            self.Status = "Idle"
            return
        end
        self._lastClean = now
        self:_beginScan()
    end

    local queuedCount = 0
    local scanDone = true
    if self._scanList then
        if self._queueSize < 1500 then
            queuedCount, scanDone = self:_processScan(scanBatchSize)
        else
            scanDone = false
        end
    end

    local destroyed, deferred = self:_drainQueue(destroyBudget, gcStepSize, false)

    if self._scanList then
        self.Status = string.format("Scanning (%d queued)", self._queueSize)
    elseif self._queueSize > 0 then
        self.Status = string.format("Cleaning (%d left)", self._queueSize)
    elseif destroyed > 0 or deferred > 0 or queuedCount > 0 or not scanDone then
        self.Status = "Cleanup Settled"
    else
        self.Status = "Idle"
    end
end

function GarbageCollector:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        if not self.Options.AutoCleanEnabled then return end

        self:_stepCleanup()
    end)
end

function GarbageCollector:Clean()
    self._manualBoostUntil = os.clock() + 4
    if self.ResourceManager then
        self.ResourceManager:Boost(2.5)
    end
    if not self._scanList then
        self._lastClean = 0
        self:_beginScan()
    end

    local found = 0
    local destroyed = 0
    local deferred = 0
    if self._scanList then
        found = self:_processFullScan(math.max(self._scanBatchSize * 8, 200))
    end
    local immediateDrain = math.min(self._queueSize, self._manualDrainCap)
    destroyed, deferred = self:_drainQueue(immediateDrain, self._collectStepSize, true)

    if self.ResourceManager and self.ResourceManager:GetPendingCount() > 0 then
        self.Status = string.format(
            "Smart Cleanup (%d local / %d deferred)",
            self._queueSize,
            self.ResourceManager:GetPendingCount()
        )
    else
        self.Status = self._queueSize > 0 and string.format("Cleaning (%d left)", self._queueSize) or "Cleanup Settled"
    end
    return destroyed, found, deferred, self._queueSize
end

function GarbageCollector:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    for i = 1, self._queueSize do
        local instance = self._queued[i]
        self._queuedMap[instance] = nil
    end
end

return GarbageCollector

