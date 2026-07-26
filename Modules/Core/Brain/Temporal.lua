--[[
    TemporalLobe.lua - Processing sensory input into cognition.
    Analogy: High-level cognition and logic orchestration.
    Job: Orchestrates the target selection and prediction pipeline.
]]

local TemporalLobe = {}
TemporalLobe.__index = TemporalLobe

function TemporalLobe.new(selector, predictor)
    local self = setmetatable({}, TemporalLobe)
    self.Selector = selector
    self.Predictor = predictor

    self._targetEntry = nil
    self._targetPart = nil
    self._prediction = nil
    self._rawPrediction = nil
    self._techniqueDecision = nil
    self._lastEntry = nil
    self._lastPart = nil
    return self
end

function TemporalLobe:Scan(mousePos, originPos)
    local nextEntry = self.Selector:GetClosestTarget(mousePos, originPos, self._targetEntry)
    if nextEntry ~= self._targetEntry then
        self._targetEntry = nextEntry
        self._targetPart = nil
        self._prediction = nil
    else
        self._targetEntry = nextEntry
    end
    return self._targetEntry
end

function TemporalLobe:Process(originPos, dt)
    if not self._targetEntry then
        if self._lastEntry then
            self.Predictor:NotifyTargetChanged(nil)
            self._lastEntry = nil
            self._lastPart = nil
        end
        self._targetPart = nil
        self._prediction = nil
        self._rawPrediction = nil
        self._techniqueDecision = nil
        return nil, nil
    end

    if self._targetEntry.Humanoid and self._targetEntry.Humanoid.Health <= 0 then
        self._targetEntry = nil
        self._targetPart = nil
        self._prediction = nil
        self._rawPrediction = nil
        self._techniqueDecision = nil
        if self._lastEntry then
            self.Predictor:NotifyTargetChanged(nil)
            self._lastEntry = nil
            self._lastPart = nil
        end
        return nil, nil
    end

    self._targetPart = self.Selector.Tracker:GetTargetPart(self._targetEntry)
    if not self._targetPart then
        self._targetEntry = nil
        self._prediction = nil
        self._rawPrediction = nil
        self._techniqueDecision = nil
        if self._lastEntry then
            self.Predictor:NotifyTargetChanged(nil)
            self._lastEntry = nil
            self._lastPart = nil
        end
        return nil, nil
    end

    if self._targetEntry ~= self._lastEntry or self._targetPart ~= self._lastPart then
        self.Predictor:NotifyTargetChanged(self._targetEntry, self._targetPart)
        self._lastEntry = self._targetEntry
        self._lastPart = self._targetPart
    end

    self._prediction, self._rawPrediction, self._techniqueDecision = self.Predictor:Predict(originPos, self._targetPart, self._targetEntry, dt)

    return self._targetPart, self._prediction, self._rawPrediction, self._techniqueDecision
end

return TemporalLobe
