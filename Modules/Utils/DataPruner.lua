local DataPruner = {}
DataPruner.__index = DataPruner

function DataPruner.new(taskScheduler, tracker, predictor)
    local self = setmetatable({}, DataPruner)
    self.TaskScheduler = taskScheduler
    self.Tracker = tracker
    self.Predictor = predictor
    self.Interval = 4
    self._alive = false
    return self
end

function DataPruner:Init()
    if self._alive then
        return
    end

    self._alive = true
    self:_queue()
end

function DataPruner:_run()
    local now = os.clock()

    if self.Tracker and self.Tracker.Prune then
        self.Tracker:Prune(now)
    end

    if self.Predictor and self.Predictor.Prune then
        self.Predictor:Prune(now)
    end
end

function DataPruner:_queue()
    if not self._alive then
        return
    end

    if not self.TaskScheduler then
        self:_run()
        task.delay(self.Interval, function()
            self:_queue()
        end)
        return
    end

    local selfRef = self
    self.TaskScheduler:Enqueue(function()
        if not selfRef._alive then
            return
        end

        selfRef:_run()
        task.delay(selfRef.Interval, function()
            selfRef:_queue()
        end)
    end, "__STAR_GLITCHER_DATA_PRUNER")
end

function DataPruner:Destroy()
    self._alive = false
end

return DataPruner
