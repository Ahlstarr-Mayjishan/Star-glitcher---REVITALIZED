--[[
    Predictor.lua - High-Performance Layered Orchestrator
    Analogy: The Neural Motor Network.
    Job: Orchestrates the 4 layers: Sampler -> Estimator -> Engine -> Stabilizer.
    Architecture: Orthogonal-First design (Zero feedback loop).
]]

local Predictor = {}
Predictor.__index = Predictor

function Predictor.new(config, loader, kalman, aimMath)
    local self = setmetatable({}, Predictor)
    self.Config = config
    self.Options = config.Options
    
    -- Load Layer Modules
    local Path = "Modules/Combat/Prediction/"
    local Sampler    = loader(Path.."Sampler.lua")
    local Estimator  = loader(Path.."Estimator.lua")
    local Engine     = loader(Path.."Engine.lua")
    local Stabilizer = loader(Path.."Stabilizer.lua")
    local TechniqueSelector = loader(Path.."TechniqueSelector.lua")
    local FeedbackLoop = loader(Path.."FeedbackLoop.lua")
    
    -- Instantiate shared stateless layers
    self.Sampler = Sampler.new(config)
    self.Engine = Engine.new(config)
    self.TechniqueSelector = TechniqueSelector.new(config)
    self.FeedbackLoop = FeedbackLoop.new(config)

    -- Keep stateful layers isolated per target so target switching does not
    -- bleed velocity smoothing or screen stabilization across different entries.
    self._EstimatorClass = Estimator
    self._StabilizerClass = Stabilizer
    self._KalmanFactory = kalman and kalman.new or nil
    self._AimMath = aimMath
    self._EntryStates = setmetatable({}, { __mode = "k" })
    self._lastPrune = 0
    self._pruneInterval = 5
    self._stateExpiry = 15
    return self
end

function Predictor:_PruneStates(now)
    local pruneBefore = now - self._stateExpiry
    for entry, state in pairs(self._EntryStates) do
        if not entry
            or not entry.Model
            or not entry.Model.Parent
            or ((entry.LastSeen or 0) > 0 and (entry.LastSeen or 0) < pruneBefore) then
            if state and state.Estimator and state.Estimator.Reset then
                state.Estimator:Reset()
            end
            self._EntryStates[entry] = nil
        end
    end

    if self.TechniqueSelector and self.TechniqueSelector.Prune then
        self.TechniqueSelector:Prune(self._stateExpiry, now)
    end
end

function Predictor:Prune(now)
    self:_PruneStates(now or os.clock())
end

function Predictor:_GetState(entry)
    local state = self._EntryStates[entry]
    if state then
        return state
    end

    local kalman = self._KalmanFactory and self._KalmanFactory(self.Config) or nil
    state = {
        Estimator = self._EstimatorClass.new(kalman, self.Config),
        Stabilizer = self._StabilizerClass.new(self._AimMath),
    }
    self._EntryStates[entry] = state
    return state
end

function Predictor:NotifyTargetChanged(entry, part)
    if not entry then
        return
    end

    local state = self:_GetState(entry)
    if state.Estimator and state.Estimator.Reset then
        state.Estimator:Reset()
    end
    if state.Stabilizer and state.Stabilizer.Reset then
        state.Stabilizer:Reset(part and part.Position or nil)
    end
end

function Predictor:RegisterShot(entry, targetPos)
    if self.FeedbackLoop and self.FeedbackLoop.RegisterShot then
        self.FeedbackLoop:RegisterShot(entry, targetPos)
    end
end

function Predictor:Predict(origin, part, entry, dt)
    if not part then
        return nil, nil
    end

    -- GUARD: Ensure entry exists
    if not entry then return part.Position end

    local now = os.clock()
    if (now - self._lastPrune) >= self._pruneInterval then
        self._lastPrune = now
        self:_PruneStates(now)
    end

    if self.FeedbackLoop then
        self.FeedbackLoop:Update(dt)
    end

    local state = self:_GetState(entry)
    
    -- 1. SAMPLING (Input Only)
    local raw = self.Sampler:GetRawState(part, entry.LastPos, entry.LastTime, dt)
    
    -- 2. ESTIMATION (Cleaning State)
    local est = state.Estimator:Estimate(raw, dt)
    
    -- Update entry metadata (Monitoring only, No logic)
    entry.LastPos = raw.Position
    entry.LastTime = raw.Time
    
    -- 3. TECHNIQUE SELECTION
    local techniqueDecision = self.TechniqueSelector:Decide(origin, raw.Position, est, entry)

    -- 4. PREDICTION (Exactly one strategy profile)
    local predicted = self.Engine:Calculate(origin, raw.Position, est, dt, entry, part, techniqueDecision)
    
    -- 5. ADAPTIVE CLOSED-LOOP FEEDBACK SCALING
    if self.FeedbackLoop then
        local leadScale = self.FeedbackLoop:GetLeadScaleFactor(entry)
        if leadScale < 1.0 then
            predicted = raw.Position:Lerp(predicted, leadScale)
        end
    end

    -- 6. PRESENTATION (Smoothing)
    return state.Stabilizer:Smooth(predicted, dt), predicted, techniqueDecision
end

function Predictor:Destroy()
    if self.TechniqueSelector and self.TechniqueSelector.Destroy then
        self.TechniqueSelector:Destroy()
    end

    if self.FeedbackLoop and self.FeedbackLoop.Reset then
        self.FeedbackLoop:Reset()
    end

    for entry, state in pairs(self._EntryStates) do
        if state and state.Estimator and state.Estimator.Reset then
            state.Estimator:Reset()
        end
        self._EntryStates[entry] = nil
    end
end

return Predictor

