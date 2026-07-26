local PlaceProfiles = require("../Data/PlaceProfiles")

local MAIN_PLACE_ID = 11380216916
local ULTRAHELL_PLACE_ID = 17370343253

assert(not PlaceProfiles.IsUltraHell(MAIN_PLACE_ID), "the main Star Glitcher place must not initialize UltraHell logic")
assert(PlaceProfiles.IsUltraHell(ULTRAHELL_PLACE_ID), "Reality#012-1 must initialize UltraHell logic")
assert(not PlaceProfiles.IsUltraHell(0), "unknown places must default to the isolated main profile")

local mainProfile = PlaceProfiles.Get(MAIN_PLACE_ID)
assert(mainProfile.Name == "Main", "main place must resolve to the Main profile")
assert(not mainProfile.EnableGamemodeTools, "main profile must not expose game-mode tools")

local ultraHellProfile = PlaceProfiles.Get(ULTRAHELL_PLACE_ID)
assert(ultraHellProfile.Name == "UltraHell", "branch place must resolve to the UltraHell profile")
assert(ultraHellProfile.EnableGamemodeTools, "UltraHell profile must expose game-mode tools")

print("Place profiles: 7 cases passed")
