--!strict

local SilentAimPolicy = {}

local REMOTE_BLACKLIST = {
	"sprint",
	"speed",
	"walk",
	"jump",
	"action",
	"interact",
	"dialogue",
	"inventory",
	"tab",
	"shop",
	"trade",
	"quest",
	"mission",
	"chat",
	"menu",
	"equip",
	"unequip",
	"minigame",
	"spawn",
	"replication",
	"initialize",
}

function SilentAimPolicy.IsCombatRemoteName(remoteName: string): boolean
	local normalized = string.lower(remoteName)
	for _, word in REMOTE_BLACKLIST do
		if string.find(normalized, word, 1, true) then
			return false
		end
	end

	return string.find(normalized, "shoot", 1, true) ~= nil
		or string.find(normalized, "fire", 1, true) ~= nil
		or string.find(normalized, "attack", 1, true) ~= nil
		or string.find(normalized, "hit", 1, true) ~= nil
		or string.find(normalized, "damage", 1, true) ~= nil
		or string.find(normalized, "impact", 1, true) ~= nil
end

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
