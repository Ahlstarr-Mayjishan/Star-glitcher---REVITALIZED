local AimPolicy = require("../Modules/Combat/AimPolicy")
local AimState = require("../Modules/Combat/AimState")
local AimController = require("../Modules/Combat/AimController")

local options = {
    AssistMode = "Camera Lock",
    TargetingMethod = "FOV",
    TargetScanHz = 100,
    AdaptiveTargetScan = true,
}

assert(AimPolicy.GetMode(options) == "Camera Lock", "known mode must be preserved")
assert(not AimPolicy.ShouldTrack(options, false, true), "FOV mode must release without input")

options.TargetingMethod = "Deadlock"
assert(AimPolicy.ShouldTrack(options, false, true), "deadlock must retain an acquired target")
options.AssistMode = "invalid"
assert(AimPolicy.GetMode(options) == "Off", "unknown mode must fail closed")

options.AssistMode = "Camera Lock"
options.TargetingMethod = "FOV"
local timing = { LastScan = 0, Accumulator = 0, FrameDtEma = 1 / 60 }
assert(not AimPolicy.AdvanceScan(options, timing, 0.004, 1), "scan must wait for interval")
assert(AimPolicy.AdvanceScan(options, timing, 0.006, 1.006), "scan must run at configured cadence")
AimPolicy.ResetScan(timing)
assert(timing.Accumulator == 0, "scan reset must discard stale accumulated time")

local state = AimState.new()
local first = {}
local second = {}
local part = {}
assert(state:SetTarget(first), "first target must be a transition")
assert(not state:SetTarget(first), "same target must not reset prediction")
assert(state:SetPart(part), "first target part must be a transition")
state:SetSolution({ AimPosition = "predicted" })
assert(state.Solution ~= nil, "state must hold the current solution")
assert(state:SetTarget(second), "switching targets must be detected")
assert(state.Part == nil and state.Solution == nil, "target switch must clear dependent state")
assert(state:Clear(), "clear must release an active target")
assert(not state:Clear(), "clear must be idempotent")

local entry = { Model = {}, Name = "Boss" }
local targetPart = { Position = "target-position" }
local calls = {
    Acquired = 0,
    Predicted = 0,
    Applied = 0,
    Cleared = 0,
}
local input = {}
function input:ShouldAssist()
    return true
end
local tracker = { CurrentTargetEntry = nil }
function tracker:IsEntryTargetable(candidate)
    return candidate == entry
end
function tracker:GetTargetPart(candidate)
    return candidate == entry and targetPart or nil
end
local selector = {}
function selector:GetClosestTarget()
    calls.Acquired += 1
    return entry
end
local predictor = {}
function predictor:NotifyTargetChanged() end
function predictor:PredictResult()
    calls.Predicted += 1
    return {
        AimPosition = "aim-position",
        RawPosition = "raw-position",
        Technique = nil,
    }
end
function predictor:RegisterShot() end
local actuator = {}
function actuator:Apply()
    calls.Applied += 1
end
function actuator:Rest()
    calls.Cleared += 1
end
function actuator:NotifyShot() end
local presentation = {}
function presentation:UpdateFOV() end
function presentation:Show() end
function presentation:Clear() end

local controllerOptions = {
    AssistMode = "Camera Lock",
    TargetingMethod = "FOV",
    TargetScanHz = 60,
    AdaptiveTargetScan = true,
}
local controller = AimController.new({ Options = controllerOptions }, {
    Input = input,
    Tracker = tracker,
    Selector = selector,
    Predictor = predictor,
    Actuator = actuator,
    Presentation = presentation,
}, AimPolicy, AimState)
controller:Step(1 / 30, {}, { Position = "origin" }, {})
assert(calls.Acquired == 1, "controller must acquire at the configured cadence")
assert(calls.Predicted == 1 and calls.Applied == 1, "valid target must reach prediction and actuation")
assert(tracker.CurrentTargetEntry == entry, "compatibility target mirror must follow controller state")

controllerOptions.AssistMode = "Off"
controller:Step(1 / 60, {}, { Position = "origin" }, {})
assert(controller.State.Entry == nil, "off mode must release controller state")
assert(tracker.CurrentTargetEntry == nil, "off mode must clear compatibility target mirror")
assert(calls.Cleared > 0, "off mode must clear active output")

controllerOptions.AssistMode = "Camera Lock"
selector.GetClosestTarget = function()
    return nil
end
controller:Step(1 / 30, {}, { Position = "origin" }, {})
assert(controller.State.Entry == nil, "an empty scan must clear the previous target")
local clearedAfterLostTarget = calls.Cleared
controller:Step(1 / 30, {}, { Position = "origin" }, {})
assert(calls.Cleared > clearedAfterLostTarget, "no-target frames must keep stale actuators disabled")

print("Aim pipeline: 22 cases passed")
