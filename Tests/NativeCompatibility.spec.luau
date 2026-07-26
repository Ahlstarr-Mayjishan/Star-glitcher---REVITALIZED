--!strict

local NativeTargetPolicy = require("../Modules/Utils/NativeTargetPolicy")
local NativeStatus = require("../Modules/Utils/NativeStatus")

assert(NativeTargetPolicy.IsEligible({ TargetTeam = 0, LocalTeam = 0 }), "team 0 is native FFA")
assert(not NativeTargetPolicy.IsEligible({ TargetTeam = 999, LocalTeam = 999 }), "matching native boss teams are allied")
assert(not NativeTargetPolicy.IsEligible({ TargetTeam = 4, LocalTeam = 4 }), "same non-FFA team is allied")
assert(NativeTargetPolicy.IsEligible({ TargetTeam = 4, LocalTeam = 2 }), "different native teams are enemies")
assert(not NativeTargetPolicy.IsEligible({ TargetTeam = -1, LocalTeam = 2 }), "neutral native entities are not targets")
assert(not NativeTargetPolicy.IsEligible({ TargetTeam = 0, LocalTeam = -1 }), "neutral local entities cannot damage targets")
assert(not NativeTargetPolicy.IsEligible({ IsSafeZoned = true }), "safe-zoned entities are not targets")
assert(not NativeTargetPolicy.IsEligible({ IsExtraNPC = true }), "native ExtraNPC models are decorative")
assert(not NativeTargetPolicy.IsEligible({ IsParentRelated = true }), "owned summons must not target their owner")

local stunned = {
	Value = true,
	IsA = function(_, className)
		return className == "ValueBase" or className == "BoolValue"
	end,
}
local walkSpeed = {
	Value = 55,
	IsA = function(_, className)
		return className == "ValueBase"
	end,
}
local attributes = {
	FindFirstChild = function(_, name)
		return name == "Stunned" and stunned or nil
	end,
}
local status = {
	FindFirstChild = function(_, name)
		if name == "Attributes" then
			return attributes
		end
		return name == "WalkSpeed" and walkSpeed or nil
	end,
}
local character = {
	FindFirstChild = function(_, name)
		return name == "Status" and status or nil
	end,
}

assert(NativeStatus.Read(character, "WalkSpeed") == 55, "native status adapter must read direct stat values")
assert(NativeStatus.Read(character, "Stunned") == true, "native status adapter must read calculated attributes")
assert(NativeStatus.ClearBooleanFlags(character, { Stunned = true }) == 1, "native CC flag must be cleared in place")
assert(stunned.Value == false, "native status objects must be preserved instead of destroyed")

print("Native compatibility: 13 cases passed")
