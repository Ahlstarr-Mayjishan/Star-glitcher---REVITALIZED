local Predictor = require("../Modules/Combat/Predictor")

local capturedEntry = nil
local capturedPosition = nil
local fakePredictor = {
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

print("Predictor feedback: 2 cases passed")
