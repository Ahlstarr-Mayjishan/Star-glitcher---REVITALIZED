local Predictor = require("../Modules/Combat/Predictor")

local capturedEntry = nil
local capturedPosition = nil
local fakePredictor = {
	Options = {
		PredictionFeedbackEnabled = true,
	},
	FeedbackLoop = {
		RegisterShot = function(_, entry, targetPosition)
			capturedEntry = entry
			capturedPosition = targetPosition
		end,
	},
}

local entry = {}
local position = {}
Predictor.RegisterShot(fakePredictor, entry, position)

assert(capturedEntry == entry, "Predictor must forward the target entry to FeedbackLoop")
assert(capturedPosition == position, "Predictor must forward the predicted shot position")

capturedEntry = nil
fakePredictor.Options.PredictionFeedbackEnabled = false
Predictor.RegisterShot(fakePredictor, entry, position)
assert(capturedEntry == nil, "experimental feedback must stay disabled unless explicitly enabled")

local sampledLastPosition = nil
local sampledLastTime = nil
local predictionState = {
	LastPosition = "state-position",
	LastTime = 42,
	Estimator = {
		Estimate = function(_, raw)
			return raw
		end,
	},
	Stabilizer = {
		Smooth = function(_, predicted)
			return predicted
		end,
	},
}
local isolatedPredictor = {
	_lastPrune = os.clock(),
	_pruneInterval = 100,
	Sampler = {
		GetRawState = function(_, _, lastPosition, lastTime)
			sampledLastPosition = lastPosition
			sampledLastTime = lastTime
			return {
				Position = "next-position",
				Time = 99,
			}
		end,
	},
	TechniqueSelector = {
		Decide = function()
			return "technique"
		end,
	},
	Engine = {
		Calculate = function()
			return "predicted-position"
		end,
	},
	FeedbackLoop = nil,
	_GetState = function()
		return predictionState
	end,
}
local isolatedEntry = {
	LastPos = "tracker-position",
	LastTime = 7,
}

Predictor.PredictResult(isolatedPredictor, "origin", { Position = "part-position" }, isolatedEntry, 1 / 60)
assert(sampledLastPosition == "state-position", "prediction sampling must not use tracker monitoring position")
assert(sampledLastTime == 42, "prediction sampling must own its sample timestamp")
assert(predictionState.LastPosition == "next-position", "prediction state must advance after sampling")
assert(predictionState.LastTime == 99, "prediction timestamp must advance after sampling")

print("Predictor feedback/state isolation: 7 cases passed")
