local TargetClassifier = require("../Modules/Utils/TargetClassifier")
local classify = TargetClassifier.ClassifyCombatEvidence
local shouldRejectName = TargetClassifier.ShouldRejectStructuralName

assert(
	shouldRejectName({
		HasBlacklistedName = true,
		AuthoritativeEntityFolder = false,
	}),
	"decorative names outside the official entity container must remain rejected"
)
assert(not shouldRejectName({
	HasBlacklistedName = true,
	AuthoritativeEntityFolder = true,
}), "official combat entities must not be rejected solely because their boss name resembles a prop")

local cases = {
	{
		Name = "anchored statue rig with a normal Humanoid",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = true,
			MaxHealth = 100,
			IsBoss = false,
		},
		Expected = false,
	},
	{
		Name = "large statue misidentified as a boss by size",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = true,
			MaxHealth = 100,
			IsBoss = true,
		},
		Expected = false,
	},
	{
		Name = "anchored statue inside a scanned folder",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = true,
			MaxHealth = 100,
			IsBoss = true,
			StrongCombatFolder = true,
		},
		Expected = false,
	},
	{
		Name = "ordinary mobile enemy",
		Evidence = {
			IsAlive = true,
			IsAnchored = false,
			HasHumanoid = true,
			MaxHealth = 100,
			IsBoss = false,
		},
		Expected = true,
	},
	{
		Name = "anchored high-health humanoid boss",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = true,
			MaxHealth = 10000,
			IsBoss = true,
		},
		Expected = true,
	},
	{
		Name = "anchored non-humanoid boss with health",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = false,
			Health = 5000,
			IsBoss = true,
		},
		Expected = true,
	},
	{
		Name = "unmarked moving prop",
		Evidence = {
			IsAlive = true,
			IsAnchored = false,
			HasHumanoid = false,
			IsBoss = false,
		},
		Expected = false,
	},
	{
		Name = "entity inside a trusted combat folder",
		Evidence = {
			IsAlive = true,
			IsAnchored = false,
			HasHumanoid = false,
			IsBoss = false,
			StrongCombatFolder = true,
		},
		Expected = true,
	},
	{
		Name = "anchored Cube inside the authoritative game entity container",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = false,
			IsBoss = false,
			AuthoritativeEntityFolder = true,
		},
		Expected = true,
	},
	{
		Name = "anchored entity with an explicit combat marker",
		Evidence = {
			IsAlive = true,
			IsAnchored = true,
			HasHumanoid = true,
			MaxHealth = 100,
			IsBoss = false,
			ExplicitCombatMarker = true,
		},
		Expected = true,
	},
	{
		Name = "dead enemy",
		Evidence = {
			IsAlive = false,
			IsAnchored = false,
			HasHumanoid = true,
			IsBoss = true,
		},
		Expected = false,
	},
}

for _, case in ipairs(cases) do
	local actual = classify(case.Evidence)
	assert(
		actual == case.Expected,
		string.format("%s: expected %s, got %s", case.Name, tostring(case.Expected), tostring(actual))
	)
end

print(string.format("Target classification: %d cases passed", #cases + 2))
