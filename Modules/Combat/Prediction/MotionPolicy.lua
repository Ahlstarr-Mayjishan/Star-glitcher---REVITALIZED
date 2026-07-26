--!strict

local MotionPolicy = {}

function MotionPolicy.VelocityHoldScale(
	observationAge: number,
	decayStart: number,
	maxHold: number
): number
	if observationAge <= decayStart then
		return 1
	end
	if observationAge >= maxHold or maxHold <= decayStart then
		return 0
	end

	local alpha = math.clamp((observationAge - decayStart) / (maxHold - decayStart), 0, 1)
	local smoothAlpha = alpha * alpha * (3 - (2 * alpha))
	return 1 - smoothAlpha
end

function MotionPolicy.ObservationCompensation(
	observationAge: number,
	maxAge: number,
	scale: number
): number
	return math.min(math.max(observationAge, 0), math.max(maxAge, 0))
		* math.max(scale, 0)
end

function MotionPolicy.IsTeleport(
	displacement: number,
	expectedSpeed: number,
	observationDt: number,
	minimumDistance: number,
	speedRatio: number
): boolean
	local expectedTravel = math.max(expectedSpeed, 0) * math.max(observationDt, 0)
	local threshold = math.max(
		minimumDistance,
		expectedTravel * (1 + math.max(speedRatio, 0)) + 4
	)
	return displacement > threshold
end

function MotionPolicy.StabilizerPlan(
	distance: number,
	isTeleport: boolean,
	baseResponse: number,
	catchupResponse: number,
	catchupDistance: number,
	emergencySnapDistance: number
)
	local safeDistance = math.max(distance, 0)
	local snap = isTeleport or safeDistance >= emergencySnapDistance
	local catchupAlpha = math.clamp(safeDistance / math.max(catchupDistance, 0.001), 0, 1)
	return {
		Snap = snap,
		Response = baseResponse
			+ ((catchupResponse - baseResponse) * catchupAlpha),
	}
end

return table.freeze(MotionPolicy)
