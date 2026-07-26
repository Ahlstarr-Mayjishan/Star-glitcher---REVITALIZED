--[[
    CompatAdapter.lua - Bridge from the legacy PredictionCore interface to the modern predictor pipeline
    Job: Provide a compatibility seam so future callers can stop depending on the God-file API.
]]

local CompatAdapter = {}
CompatAdapter.__index = CompatAdapter

function CompatAdapter.new(predictor)
    local self = setmetatable({}, CompatAdapter)
    self.Predictor = predictor
    return self
end

function CompatAdapter:PredictTargetPosition(origin, part, entry, dt)
    if not self.Predictor or not part then
        return part and part.Position or nil
    end

    local predicted = select(1, self.Predictor:Predict(origin, part, entry, dt or (1 / 60)))
    return predicted
end

function CompatAdapter:PredictWithStrafe(origin, part, entry, dt)
    return self:PredictTargetPosition(origin, part, entry, dt)
end

function CompatAdapter:GetSelectionTargetPosition(origin, part, entry, _isCurrentTarget, dt)
    return self:PredictTargetPosition(origin, part, entry, dt)
end

function CompatAdapter:StabilizeTargetPosition(entry, _part, rawPos)
    if entry then
        entry.StabilizedTargetPos = rawPos
    end
    return rawPos
end

return CompatAdapter
