--!strict

local SilentAimPolicy = {}

function SilentAimPolicy.ShouldRedirectAimSource(hasTargetLock: boolean): boolean
	return hasTargetLock
end

function SilentAimPolicy.ShouldRewriteSideEffect(
	hasTargetLock: boolean,
	secondsSinceShot: number,
	secondsSinceRedirect: number,
	redirectWindow: number
): boolean
	if not hasTargetLock then
		return false
	end

	return secondsSinceShot <= redirectWindow or secondsSinceRedirect <= redirectWindow
end

return table.freeze(SilentAimPolicy)
