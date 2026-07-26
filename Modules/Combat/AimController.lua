local clock = os.clock

local AimController = {}
AimController.__index = AimController

function AimController.new(config, modules, policy, state)
    return setmetatable({
        Options = config.Options,
        Input = modules.Input,
        Tracker = modules.Tracker,
        Selector = modules.Selector,
        Predictor = modules.Predictor,
        Actuator = modules.Actuator,
        Presentation = modules.Presentation,
        Policy = policy,
        State = state.new(),
        Timing = {
            LastScan = 0,
            Accumulator = 0,
            FrameDtEma = 1 / 60,
        },
        _notifiedEntry = nil,
        _notifiedPart = nil,
        _destroyed = false,
    }, AimController)
end

function AimController:_release()
    self.State:Clear()
    self.Tracker.CurrentTargetEntry = nil
    self._notifiedEntry = nil
    self._notifiedPart = nil
    self.Policy.ResetScan(self.Timing)
    self.Presentation:Clear()
    self.Actuator:Rest()
end

function AimController:_acquire(mousePosition, originPosition, dt)
    if not self.Policy.AdvanceScan(self.Options, self.Timing, dt, clock()) then
        return
    end
    self.State:SetTarget(
        self.Selector:GetClosestTarget(mousePosition, originPosition, self.State.Entry)
    )
    self.Tracker.CurrentTargetEntry = self.State.Entry
end

function AimController:_validateTarget()
    local entry = self.State.Entry
    if not entry then
        return nil
    end
    if self.Tracker.IsEntryTargetable and not self.Tracker:IsEntryTargetable(entry) then
        self:_release()
        return nil
    end

    local part = self.Tracker:GetTargetPart(entry)
    if not part then
        self:_release()
        return nil
    end

    self.State:SetPart(part)
    if entry ~= self._notifiedEntry or part ~= self._notifiedPart then
        self.Predictor:NotifyTargetChanged(entry, part)
        self._notifiedEntry = entry
        self._notifiedPart = part
    end
    return part
end

function AimController:Step(dt, mousePosition, cameraCFrame, camera)
    if self._destroyed or not camera then
        return
    end

    local mode = self.Policy.GetMode(self.Options)
    local inputActive = mode ~= "Off" and self.Input:ShouldAssist()
    if inputActive then
        self:_acquire(mousePosition, cameraCFrame.Position, dt)
    end

    local shouldTrack = self.Policy.ShouldTrack(
        self.Options,
        inputActive,
        self.State.Entry ~= nil
    )
    self.Presentation:UpdateFOV(mousePosition, shouldTrack)
    if not shouldTrack then
        self:_release()
        return
    end

    local part = self:_validateTarget()
    if not part then
        return
    end

    local solution = self.Predictor:PredictResult(
        cameraCFrame.Position,
        part,
        self.State.Entry,
        dt
    )
    if not solution or not solution.AimPosition then
        self:_release()
        return
    end

    self.State:SetSolution(solution)
    self.Presentation:Show(self.State, camera)
    self.Actuator:Apply(mode, self.State, dt)
end

function AimController:OnShot(now)
    local entry = self.State.Entry
    if not entry then
        return
    end
    self.Predictor:RegisterShot(entry, self.State.Part and self.State.Part.Position or nil)
    self.Actuator:NotifyShot(now, entry)
end

function AimController:Destroy()
    self._destroyed = true
    self:_release()
end

return AimController
