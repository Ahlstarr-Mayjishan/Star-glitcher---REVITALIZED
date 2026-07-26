local RunService = game:GetService("RunService")

local TaskScheduler = {}
TaskScheduler.__index = TaskScheduler

local DEFAULT_FRAME_BUDGET = 0.001
local COMPACT_THRESHOLD = 256

function TaskScheduler.new(options)
    local self = setmetatable({}, TaskScheduler)
    self.Options = options
    self.Connection = nil
    self.Status = "Idle"
    self._queue = {}
    self._head = 1
    self._tail = 0
    self._activeKeys = {}
    self._frameBudget = DEFAULT_FRAME_BUDGET
    self._lastHitch = 0
    return self
end

function TaskScheduler:_compactQueue()
    if self._head <= 1 then
        return
    end

    local pending = self:GetPendingCount()
    if pending <= 0 then
        self._head = 1
        self._tail = 0
        return
    end

    local compacted = table.create and table.create(pending) or {}
    local nextIndex = 1
    for i = self._head, self._tail do
        local job = self._queue[i]
        if job ~= nil then
            compacted[nextIndex] = job
            nextIndex = nextIndex + 1
        end
    end

    self._queue = compacted
    self._head = 1
    self._tail = nextIndex - 1
end

function TaskScheduler:_maybeCompactQueue()
    if self._head > COMPACT_THRESHOLD and self._head > (self._tail * 0.5) then
        self:_compactQueue()
    end
end

function TaskScheduler:_push(job)
    self._tail = self._tail + 1
    self._queue[self._tail] = job
end

function TaskScheduler:_pop()
    if self._head > self._tail then
        return nil
    end

    local job = self._queue[self._head]
    self._queue[self._head] = nil
    self._head = self._head + 1

    if self._head > self._tail then
        self._head = 1
        self._tail = 0
    end

    return job
end

function TaskScheduler:GetPendingCount()
    return math.max(0, self._tail - self._head + 1)
end

function TaskScheduler:Enqueue(callback, key)
    if type(callback) ~= "function" then
        return false
    end

    if key ~= nil then
        if self._activeKeys[key] then
            return false
        end
        self._activeKeys[key] = true
    end

    self:_push({
        Callback = callback,
        Key = key,
    })
    return true
end

function TaskScheduler:_getBudget(dt)
    local budget = self._frameBudget
    local now = os.clock()

    if dt and dt > (1 / 35) then
        self._lastHitch = now
        budget = budget * 0.5
    elseif (now - self._lastHitch) < 0.75 then
        budget = budget * 0.7
    end

    return budget
end

function TaskScheduler:_runJob(job)
    if not job then
        return false
    end

    if job.Key ~= nil then
        self._activeKeys[job.Key] = nil
    end

    local ok, err = pcall(job.Callback)
    if not ok then
        warn("[TaskScheduler] Job failed | Error: " .. tostring(err))
    end
    return ok
end

function TaskScheduler:_step(dt)
    local startTime = os.clock()
    local budget = self:_getBudget(dt)
    local processed = 0

    local iterations = 0
    local maxIterations = 100

    while self:GetPendingCount() > 0 do
        iterations = iterations + 1
        if iterations > maxIterations then
            break
        end

        if (os.clock() - startTime) >= budget then
            break
        end

        local job = self:_pop()
        if not job then
            break
        end

        if self:_runJob(job) then
            processed = processed + 1
        end
    end

    local pending = self:GetPendingCount()
    self:_maybeCompactQueue()
    if pending > 0 then
        self.Status = string.format("Batching (%d pending)", pending)
    elseif processed > 0 then
        self.Status = "Settled"
    else
        self.Status = "Idle"
    end
end

function TaskScheduler:Init()
    if self.Connection then
        return
    end

    self.Connection = RunService.Heartbeat:Connect(function(dt)
        self:_step(dt)
    end)
end

function TaskScheduler:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end

    table.clear(self._queue)
    table.clear(self._activeKeys)
    self._head = 1
    self._tail = 0
    self.Status = "Idle"
end

return TaskScheduler
