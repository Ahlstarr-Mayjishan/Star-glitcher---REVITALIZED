--!strict

local TrackerInvalidationPolicy = {}

local STRUCTURAL_PART_NAMES = {
	HumanoidRootPart = true,
	Torso = true,
	UpperTorso = true,
	Head = true,
}

local COMBAT_VALUE_NAMES = {
	Health = true,
	HP = true,
	HitPoints = true,
	BossHealth = true,
	EnemyHealth = true,
	HealthValue = true,
	Team = true,
	SafeZoned = true,
	ParentEntity = true,
	Targetable = true,
	Enemy = true,
	Hostile = true,
	IsEnemy = true,
	IsBoss = true,
	Boss = true,
	EntityType = true,
}

export type Action = {
	ResetBoss: boolean,
	ResetPart: boolean,
}

local function combatValueAction(name: string): Action?
	if not COMBAT_VALUE_NAMES[name] and name ~= "MaxHealth" and name ~= "MaxHP" then
		return nil
	end

	return {
		ResetBoss = name == "IsBoss"
			or name == "Boss"
			or name == "Health"
			or name == "HP"
			or name == "MaxHealth"
			or name == "MaxHP"
			or name == "BossHealth"
			or name == "EnemyHealth"
			or name == "HealthValue",
		ResetPart = false,
	}
end

function TrackerInvalidationPolicy.ClassifyAttribute(name: string): Action?
	return combatValueAction(name)
end

function TrackerInvalidationPolicy.ClassifyDescendant(
	className: string,
	name: string,
	targetPartName: string,
	hasUsablePrimaryPart: boolean
): Action?
	if className == "Humanoid" then
		return { ResetBoss = true, ResetPart = false }
	end

	if className == "BasePart" then
		if not hasUsablePrimaryPart
			or STRUCTURAL_PART_NAMES[name] == true
			or name == targetPartName then
			return { ResetBoss = true, ResetPart = true }
		end
		return nil
	end

	if className == "Folder" and (name == "Status" or name == "Attributes") then
		return { ResetBoss = false, ResetPart = false }
	end

	if COMBAT_VALUE_NAMES[name] then
		return combatValueAction(name)
	end

	return nil
end

return table.freeze(TrackerInvalidationPolicy)
