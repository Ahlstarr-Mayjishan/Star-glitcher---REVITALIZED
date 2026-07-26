--!strict

local MotionPolicy = require("../Modules/Combat/Prediction/MotionPolicy")

local function assertNear(actual, expected, epsilon, message)
	assert(math.abs(actual - expected) <= epsilon, message)
end

assert(MotionPolicy.VelocityHoldScale(0.03, 0.06, 0.12) == 1, "fresh held velocity must remain intact")
assert(MotionPolicy.VelocityHoldScale(0.12, 0.06, 0.12) == 0, "stale held velocity must expire")
local midScale = MotionPolicy.VelocityHoldScale(0.09, 0.06, 0.12)
assert(midScale > 0 and midScale < 1, "held velocity must decay smoothly")

assertNear(
	MotionPolicy.ObservationCompensation(0.08, 0.1, 0.9),
	0.072,
	1e-8,
	"replication age must become bounded lead time"
)
assertNear(
	MotionPolicy.ObservationCompensation(0.4, 0.1, 0.9),
	0.09,
	1e-8,
	"replication compensation must remain capped"
)

local teleportSnap = MotionPolicy.StabilizerPlan(2, true, 26, 96, 8, 48)
assert(teleportSnap.Snap, "confirmed teleports must snap immediately")
local packetCatchup = MotionPolicy.StabilizerPlan(6, false, 26, 96, 8, 48)
assert(not packetCatchup.Snap and packetCatchup.Response > 26, "normal packet steps must catch up smoothly")
local emergencySnap = MotionPolicy.StabilizerPlan(60, false, 26, 96, 8, 48)
assert(emergencySnap.Snap, "extreme discontinuities must fail safe with a snap")
assert(
	not MotionPolicy.IsTeleport(30, 300, 0.1, 22, 0.55),
	"expected high-speed packet movement must not look like a teleport"
)
assert(
	MotionPolicy.IsTeleport(80, 300, 0.1, 22, 0.55),
	"an implausible discontinuity must be classified as a teleport"
)

print("Motion policy: 10 cases passed")
