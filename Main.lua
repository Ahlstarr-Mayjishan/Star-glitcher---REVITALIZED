--[[
    Boss Aim Assist - Optimized Modular Bootstrapper
    v2.3.0 (Release-Coherent Multi-CDN Bootstrap)
]]

local STABLE_RELEASE_REF = "eb0184cbe075701e0bca818c2f0edca0d3f58183"
local STABLE_RELEASE_BASE = "https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED@" .. STABLE_RELEASE_REF .. "/"
local DYNAMIC_REMOTE_BASES = {
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED/main/",
    "https://cdn.statically.io/gh/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED/main/",
    "https://raw.githack.com/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED/main/",
    "https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED@main/",
}
local REMOTE_BASES = {STABLE_RELEASE_BASE}
for _, base in ipairs(DYNAMIC_REMOTE_BASES) do
    REMOTE_BASES[#REMOTE_BASES + 1] = base
end

local function isValidSource(content)
    if type(content) ~= "string" or content:match("^%s*$") then
        return false
    end

    local normalized = content:match("^%s*(.-)%s*$")
    if normalized == "404: Not Found" then
        return false
    end

    local prefix = normalized:sub(1, 32):lower()
    return not prefix:find("<!doctype html", 1, true)
        and not prefix:find("<html", 1, true)
end

local function fetchFromBase(base, path)
    local errors = {}
    local url = base .. path:gsub("^/+", "") .. "?v=" .. tostring(os.time())
    for attempt = 1, 2 do
        local ok, response = pcall(game.HttpGet, game, url)
        if ok and isValidSource(response) then
            return response
        end

        errors[#errors + 1] = string.format("%s attempt %d: %s", url, attempt, tostring(response))
        task.wait(0.15 * attempt)
    end
    return nil, table.concat(errors, " | ")
end

local function fetchRemote(path, bases)
    local errors = {}
    for _, base in ipairs(bases or REMOTE_BASES) do
        local response, fetchError = fetchFromBase(base, path)
        if response then
            return response, base
        end
        errors[#errors + 1] = fetchError
    end
    return nil, nil, table.concat(errors, " | ")
end

local function compileRemote(source, chunkName)
    local compiler = loadstring or load
    if not compiler then
        error("[Boot] This executor does not provide loadstring/load.")
    end

    local chunk, compileError = compiler(source, chunkName)
    if not chunk then
        error("[Boot] Failed to compile " .. chunkName .. ": " .. tostring(compileError))
    end
    return chunk()
end

local function versionNumber(version)
    local major, minor, patch = tostring(version or "0"):match("^(%d+)%.(%d+)%.(%d+)")
    return (tonumber(major) or 0) * 1000000
        + (tonumber(minor) or 0) * 1000
        + (tonumber(patch) or 0)
end

local function selectManifest()
    local best = nil
    local errors = {}
    local candidates = {}
    local pending = #REMOTE_BASES
    for index, base in ipairs(REMOTE_BASES) do
        task.spawn(function()
            local ok, source, fetchError = pcall(fetchFromBase, base, "Core/manifest.lua")
            candidates[index] = {
                Base = base,
                Source = ok and source or nil,
                Error = ok and fetchError or source,
            }
            pending = pending - 1
        end)
    end

    while pending > 0 do
        task.wait()
    end

    for _, candidate in ipairs(candidates) do
        local source = candidate.Source
        if source then
            local ok, manifest = pcall(compileRemote, source, "=Core/manifest.lua")
            if ok and type(manifest) == "table" and type(manifest.Files) == "table" then
                local score = versionNumber(manifest.Version)
                if not best or score > best.Score then
                    best = {
                        Base = candidate.Base,
                        Manifest = manifest,
                        Score = score,
                    }
                end
            else
                errors[#errors + 1] = candidate.Base .. ": " .. tostring(manifest)
            end
        else
            errors[#errors + 1] = tostring(candidate.Error)
        end
    end
    return best, table.concat(errors, " | ")
end

-- 1. Load Manifest & Resource Manager First
print("[Boot] Initializing Resources...")
local selectedManifest, manifestError = selectManifest()
local orderedBases = {}
if selectedManifest then
    orderedBases[1] = selectedManifest.Base
end
for _, base in ipairs(REMOTE_BASES) do
    if not selectedManifest or base ~= selectedManifest.Base then
        orderedBases[#orderedBases + 1] = base
    end
end
local resourceManagerSource, _, managerError = fetchRemote("Modules/Utils/ResourceManager.lua", orderedBases)

if selectedManifest and resourceManagerSource then
    local activeBase = selectedManifest.Base
    _G.StarGlitcher_RemoteBases = orderedBases
    _G.StarGlitcher_DynamicRemoteBases = DYNAMIC_REMOTE_BASES
    _G.StarGlitcher_GithubBase = activeBase
    _G.StarGlitcher_BootloaderURL = DYNAMIC_REMOTE_BASES[1] .. "Main.lua"
    local manifest = selectedManifest.Manifest
    local ResourceManager = compileRemote(resourceManagerSource, "=Modules/Utils/ResourceManager.lua")

    -- Instantiate Global Resource Manager
    local rm = ResourceManager.new({}, orderedBases, manifest)
    _G.StarGlitcher_ResourceManager = rm

    -- 2. Execute Core Main
    print("[Boot] Launching Core via " .. tostring(activeBase))
    local coreMain = rm:Load("Core/Main.lua")
    return coreMain
else
    error(
        "[Boot] Critical failure: could not fetch bootstrap files from GitHub or CDN."
        .. " Manifest: " .. tostring(manifestError)
        .. " | ResourceManager: " .. tostring(managerError)
    )
end
