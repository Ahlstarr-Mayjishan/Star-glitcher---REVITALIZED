--!strict

local NativeTargetPolicy = {}

export type Evidence = {
	IsExtraNPC: boolean?,
	IsSafeZoned: boolean?,
	TargetTeam: number?,
	LocalTeam: number?,
	IsParentRelated: boolean?,
}

function NativeTargetPolicy.IsEligible(evidence: Evidence): boolean
	if evidence.IsExtraNPC or evidence.IsSafeZoned or evidence.IsParentRelated then
		return false
	end

	local targetTeam = evidence.TargetTeam
	local localTeam = evidence.LocalTeam
	if targetTeam == -1 or localTeam == -1 then
		return false
	end

	if targetTeam ~= nil
		and targetTeam ~= 0
		and localTeam ~= nil
		and targetTeam == localTeam then
		return false
	end

	return true
end

return table.freeze(NativeTargetPolicy)
