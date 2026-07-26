local AimMath = require("../Modules/Combat/AimMath")

local function assertNear(actual, expected, epsilon, message)
	assert(
		math.abs(actual - expected) <= epsilon,
		string.format("%s: expected %.8f, got %.8f", message, expected, actual)
	)
end

local baseAlpha = 0.18
local alphaAt60 = AimMath.FrameRateIndependentAlpha(baseAlpha, 1 / 60, 60)
assertNear(alphaAt60, baseAlpha, 1e-8, "60 FPS preserves configured smoothing")

local alphaAt120 = AimMath.FrameRateIndependentAlpha(baseAlpha, 1 / 120, 60)
local compoundedAt120 = 1 - ((1 - alphaAt120) ^ 2)
assertNear(compoundedAt120, baseAlpha, 1e-8, "two 120 FPS frames equal one 60 FPS frame")

local alphaAt30 = AimMath.FrameRateIndependentAlpha(baseAlpha, 1 / 30, 60)
local twoReferenceFrames = 1 - ((1 - baseAlpha) ^ 2)
assertNear(alphaAt30, twoReferenceFrames, 1e-8, "one 30 FPS frame equals two 60 FPS frames")

local exponentialAt60 = AimMath.ExponentialAlpha(18, 1 / 60)
local exponentialAt120 = AimMath.ExponentialAlpha(18, 1 / 120)
assertNear(
	1 - ((1 - exponentialAt120) ^ 2),
	exponentialAt60,
	1e-8,
	"exponential smoothing is frame-rate independent"
)

assert(
	AimMath.ShouldRefreshVisibility(10, nil, 0, 0, 0.1, 36),
	"missing visibility sample must refresh"
)
assert(
	not AimMath.ShouldRefreshVisibility(10.05, 10, 4, 9, 0.1, 36),
	"fresh visibility sample with small movement must be reused"
)
assert(
	AimMath.ShouldRefreshVisibility(10.11, 10, 0, 0, 0.1, 36),
	"expired visibility sample must refresh"
)
assert(
	AimMath.ShouldRefreshVisibility(10.02, 10, 49, 0, 0.1, 36),
	"large camera movement must invalidate visibility cache"
)
assert(
	AimMath.ShouldRefreshVisibility(10.02, 10, 0, 49, 0.1, 36),
	"large target movement must invalidate visibility cache"
)

print("Aim math: 9 cases passed")
