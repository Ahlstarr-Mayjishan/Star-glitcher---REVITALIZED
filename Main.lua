--[[
    Boss Aim Assist - Optimized Modular Bootstrapper
    v2.1.0 (Multi-Source Manifest & Cache Driven)
]]

local REMOTE_BASES = {
    "https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED/main/",
    "https://cdn.jsdelivr.net/gh/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED@main/",
}

local PRIMARY_BASE = REMOTE_BASES[1]

_G.StarGlitcher_RemoteBases = REMOTE_BASES
_G.StarGlitcher_GithubBase = PRIMARY_BASE
_G.StarGlitcher_BootloaderURL = PRIMARY_BASE .. "Main.lua"

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

local function fetchRemote(path)
    local errors = {}
    for _, base in ipairs(REMOTE_BASES) do
        local url = base .. path:gsub("^/+", "") .. "?v=" .. tostring(os.time())
        for attempt = 1, 2 do
            local ok, response = pcall(game.HttpGet, game, url)
            if ok and isValidSource(response) then
                return response, base
            end

            errors[#errors + 1] = string.format(
                "%s attempt %d: %s",
                url,
                attempt,
                tostring(response)
            )
            task.wait(0.15 * attempt)
        end
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

-- 1. Load Manifest & Resource Manager First
print("[Boot] Initializing Resources...")
local manifestSource, manifestBase, manifestError = fetchRemote("Core/manifest.lua")
local resourceManagerSource, managerBase, managerError = fetchRemote("Modules/Utils/ResourceManager.lua")

if manifestSource and resourceManagerSource then
    local manifest = compileRemote(manifestSource, "=Core/manifest.lua")
    local ResourceManager = compileRemote(resourceManagerSource, "=Modules/Utils/ResourceManager.lua")

    -- Instantiate Global Resource Manager
    local rm = ResourceManager.new({}, REMOTE_BASES, manifest)
    _G.StarGlitcher_ResourceManager = rm

    -- 2. Execute Core Main
    print("[Boot] Launching Core via " .. tostring(managerBase or manifestBase or PRIMARY_BASE))
    local coreMain = rm:Load("Core/Main.lua")
    return coreMain
else
    error(
        "[Boot] Critical failure: could not fetch bootstrap files from GitHub or CDN."
        .. " Manifest: " .. tostring(manifestError)
        .. " | ResourceManager: " .. tostring(managerError)
    )
end
