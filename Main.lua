--[[
    Boss Aim Assist - Optimized Modular Bootstrapper
    v2.0.0 (Manifest & Cache Driven)
]]

local GITHUB_CONFIG = {
    User = "Ahlstarr-Mayjishan",
    Repo = "Scripting-Roblox-",
    Branch = "main",
    Folder = "STAR GLITCHER ~ REVITALIZED"
}

local GITHUB_BASE = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s/", 
    GITHUB_CONFIG.User, GITHUB_CONFIG.Repo, GITHUB_CONFIG.Branch, 
    GITHUB_CONFIG.Folder:gsub(" ", "%%20"):gsub("~", "%%7E")
)

_G.StarGlitcher_BootloaderURL = GITHUB_BASE .. "Main.lua"

local function fetchRemote(path)
    local ok, res = pcall(game.HttpGet, game, GITHUB_BASE .. path .. "?v=" .. os.time())
    if ok and res ~= "404: Not Found" then
        return res
    end
    return nil
end

-- 1. Load Manifest & Resource Manager First
print("[Boot] Initializing Resources...")
local manifestSource = fetchRemote("Core/manifest.lua")
local resourceManagerSource = fetchRemote("Modules/Utils/ResourceManager.lua")

if manifestSource and resourceManagerSource then
    local manifest = loadstring(manifestSource)()
    local ResourceManager = loadstring(resourceManagerSource)()
    
    -- Instantiate Global Resource Manager
    local rm = ResourceManager.new({}, GITHUB_BASE, manifest)
    _G.StarGlitcher_ResourceManager = rm
    
    -- 2. Execute Core Main
    print("[Boot] Launching Core...")
    local coreMain = rm:Load("Core/Main.lua")
    return coreMain
else
    error("[Boot] Critical failure: Could not fetch Manifest or ResourceManager from GitHub.")
end
