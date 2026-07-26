--!strict

local Policy = require("../Modules/Utils/TrackerInvalidationPolicy")

local rootAdded = Policy.ClassifyDescendant("BasePart", "HumanoidRootPart", "HumanoidRootPart", false)
assert(rootAdded and rootAdded.ResetPart and rootAdded.ResetBoss, "a newly assembled root must invalidate target structure")

local effectPart = Policy.ClassifyDescendant("BasePart", "ExplosionShard", "HumanoidRootPart", true)
assert(effectPart == nil, "dynamic effect parts must not dirty the target cache")

local particle = Policy.ClassifyDescendant("ParticleEmitter", "Aura", "HumanoidRootPart", true)
assert(particle == nil, "visual descendants must not dirty the target cache")

local status = Policy.ClassifyDescendant("Folder", "Status", "HumanoidRootPart", true)
assert(status and not status.ResetBoss and not status.ResetPart, "native status structure must refresh eligibility only")

local bossMarker = Policy.ClassifyDescendant("BoolValue", "IsBoss", "HumanoidRootPart", true)
assert(bossMarker and bossMarker.ResetBoss, "native boss markers must invalidate boss classification")

local health = Policy.ClassifyDescendant("NumberValue", "Health", "HumanoidRootPart", true)
assert(health and health.ResetBoss, "health signals must invalidate fallback boss classification")

local unrelatedValue = Policy.ClassifyDescendant("StringValue", "Dialogue", "HumanoidRootPart", true)
assert(unrelatedValue == nil, "unrelated value objects must not trigger rescans")

local animatedAttribute = Policy.ClassifyAttribute("AnimationPhase")
assert(animatedAttribute == nil, "animated visual attributes must not dirty the target cache")

local healthAttribute = Policy.ClassifyAttribute("Health")
assert(healthAttribute and healthAttribute.ResetBoss, "health attributes must refresh fallback classification")

print("Tracker invalidation policy: 9 cases passed")
