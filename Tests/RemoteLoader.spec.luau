local ResourceManager = require("../Modules/Utils/ResourceManager")

local RAW_BASE = "https://raw.githubusercontent.com/example/project/main/"
local CDN_BASE = "https://cdn.jsdelivr.net/gh/example/project@main/"

local normalized = ResourceManager.NormalizeBases({
	RAW_BASE,
	CDN_BASE,
	RAW_BASE,
})

assert(#normalized == 2, "duplicate remote bases must be removed")
assert(normalized[1] == RAW_BASE, "the primary source must retain priority")
assert(normalized[2] == CDN_BASE, "the CDN source must remain available as fallback")

assert(
	ResourceManager.BuildUrl(RAW_BASE, "/Core/Main.lua", "123") == RAW_BASE .. "Core/Main.lua?v=123",
	"remote URL joining must remove duplicate slashes and append the cache key"
)

assert(ResourceManager.IsValidSource("return {}"), "valid Luau source must be accepted")
assert(not ResourceManager.IsValidSource(""), "empty responses must be rejected")
assert(not ResourceManager.IsValidSource("404: Not Found"), "GitHub 404 bodies must be rejected")
assert(not ResourceManager.IsValidSource("<!DOCTYPE html><html></html>"), "HTML proxy error pages must be rejected")
assert(ResourceManager.VersionNumber("1.6.0") == 1006000, "semantic release versions must compare numerically")
assert(ResourceManager.VersionNumber("1.10.2") > ResourceManager.VersionNumber("1.9.99"), "minor versions must not compare lexically")

print("Remote loader: 11 cases passed")
