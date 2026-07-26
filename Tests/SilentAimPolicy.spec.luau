--!strict

local SilentAimPolicy = require("../Modules/Combat/SilentAimPolicy")

assert(
	SilentAimPolicy.ShouldRedirectAimSource(true),
	"locked aim-source reads must redirect even before a click"
)
assert(
	not SilentAimPolicy.ShouldRedirectAimSource(false),
	"aim-source reads must remain untouched without a target lock"
)
assert(
	SilentAimPolicy.ShouldRewriteSideEffect(true, 0.1, math.huge, 0.35),
	"remote/raycast side effects may redirect during the shot window"
)
assert(
	not SilentAimPolicy.ShouldRewriteSideEffect(true, 1, math.huge, 0.35),
	"remote/raycast side effects must remain gated outside the shot window"
)
assert(
	not SilentAimPolicy.ShouldRewriteSideEffect(false, 0, 0, 0.35),
	"side effects must remain untouched without a target lock"
)
assert(SilentAimPolicy.IsCombatRemoteName("ShootProjectile"), "explicit shoot remotes must be eligible")
assert(not SilentAimPolicy.IsCombatRemoteName("MinigameEvent"), "boss spawning remotes must never be rewritten")
assert(not SilentAimPolicy.IsCombatRemoteName("ProjectileReplication"), "replication remotes must never be rewritten")
assert(not SilentAimPolicy.IsCombatRemoteName("InitializeProjectile"), "projectile initialization remotes must never be rewritten")

print("Silent aim policy: 9 cases passed")
