--!strict

local manifest = require("../Core/manifest")

assert(manifest.Version == "1.4.0", "manifest release version must match this native compatibility update")
assert(manifest.Files["Modules/Core/Bootstrap/Normalize.lua"], "bootstrap normalize path must match the runtime require path")
assert(manifest.Files["Modules/Core/Bootstrap/RayfieldUI.lua"], "Rayfield bootstrap path must match the runtime require path")
assert(not manifest.Files["Core/Bootstrap/Normalize.lua"], "obsolete bootstrap cache key must not remain")
assert(manifest.Files["Modules/Utils/NativeTargetPolicy.lua"], "native target policy must ship through the remote loader")
assert(manifest.Files["Modules/Utils/NativeStatus.lua"], "native status adapter must ship through the remote loader")
assert(manifest.Files["Core/Main.lua"].Version >= 170, "core cache version must invalidate older remote copies")

print("Manifest compatibility: 7 cases passed")
