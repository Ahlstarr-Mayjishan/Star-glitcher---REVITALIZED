--[[
    ResourceManager.lua - Optimized Module Loader with Cache & Local Override
    Handles fetching, caching, and version verification of modules.
]]

local ResourceManager = {}
ResourceManager.__index = ResourceManager

local HttpService = game:GetService("HttpService")
local CACHE_PATH = ".star_glitcher_cache"
local LOCAL_PATH_KEY = "BossAimAssist_LocalPath"

function ResourceManager.new(options, githubBase, manifest)
    local self = setmetatable({}, ResourceManager)
    self.Options = options
    self.GithubBase = githubBase
    self.Manifest = manifest
    self.Cache = {} -- Runtime cache
    self.SessionID = tostring(os.time())
    self.TrackedObjects = {}
    self.DeferredCleanup = {}
    self.Status = "Idle"
    
    -- Ensure cache directory exists if possible
    if makefolder then
        pcall(makefolder, CACHE_PATH)
    end
    
    return self
end

function ResourceManager:TrackObject(obj)
    if not obj then return end
    table.insert(self.TrackedObjects, obj)
end

function ResourceManager:TrackConnection(conn)
    if not conn then return end
    table.insert(self.TrackedObjects, conn)
end

function ResourceManager:DeferCleanup(fn)
    if type(fn) ~= "function" then return end
    table.insert(self.DeferredCleanup, fn)
end

function ResourceManager:ScheduleTrackedCleanup()
    -- Managed by RuntimeLifecycle call to Flush
end

function ResourceManager:Flush(multiplier)
    self.Status = "Cleaning resources..."
    local budget = math.ceil(15 * (multiplier or 1))
    local count = 0
    
    -- Execute deferred functions
    for i = #self.DeferredCleanup, 1, -1 do
        local fn = self.DeferredCleanup[i]
        pcall(fn)
        self.DeferredCleanup[i] = nil
    end

    -- Cleanup tracked objects (Connections first, then Instances)
    for i = #self.TrackedObjects, 1, -1 do
        local obj = self.TrackedObjects[i]
        if typeof(obj) == "RBXScriptConnection" then
            pcall(function() obj:Disconnect() end)
        elseif typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        elseif type(obj) == "function" then
            pcall(obj)
        end
        self.TrackedObjects[i] = nil
        count = count + 1
        if count >= budget then break end
    end
    self.Status = "Idle"
end

function ResourceManager:Boost(multiplier)
    -- Stub for compatibility with legacy calls
end

function ResourceManager:GetPendingCount()
    return #self.TrackedObjects + #self.DeferredCleanup
end

function ResourceManager:Destroy()
    self:Flush(10)
    table.clear(self.Cache)
end

function ResourceManager:GetSource(path)
    -- 1. Check Local Workspace (Developer Mode)
    if _G[LOCAL_PATH_KEY] then
        local fullPath = _G[LOCAL_PATH_KEY] .. path
        if readfile then
            local ok, content = pcall(readfile, fullPath)
            if ok and content then
                -- print("[Resource] Loaded local: " .. path)
                return content, "local"
            end
        end
    end

    -- 2. Check Cache with Version Verification
    local cachedFile = CACHE_PATH .. "/" .. path:gsub("/", "_")
    local fileManifest = self.Manifest.Files[path]
    local targetVersion = fileManifest and fileManifest.Version or 0
    
    if readfile and isfile and isfile(cachedFile) then
        local ok, content = pcall(readfile, cachedFile)
        if ok and content then
            -- Verify version (Stored at top of file as comment or separate meta file)
            local cachedVersion = content:match("-- @version%s+(%d+)")
            if tonumber(cachedVersion) == targetVersion then
                -- print("[Resource] Loaded from cache: " .. path)
                return content, "cache"
            end
        end
    end

    -- 3. Remote Fetch from GitHub
    local url = self.GithubBase .. path .. "?v=" .. self.SessionID
    local lastError = nil
    
    for attempt = 1, 3 do
        local ok, content = pcall(game.HttpGet, game, url)
        if ok and content and content ~= "404: Not Found" then
            -- Inject version metadata for next cache hit
            local versionHeader = "-- @version " .. targetVersion .. "\n"
            local processedContent = versionHeader .. content
            
            -- Save to cache
            if writefile then
                pcall(function()
                    writefile(cachedFile, processedContent)
                end)
            end
            
            -- warn("[Resource] Downloaded: " .. path)
            return processedContent, "remote"
        end
        lastError = content
        task.wait(0.2 * attempt)
    end

    error("[Resource] Fatal fetch error: Failed to load " .. path .. " after 3 attempts. Target URL: " .. url .. " | Error: " .. tostring(lastError))
end

function ResourceManager:Load(path)
    if self.Cache[path] then
        return self.Cache[path]
    end

    local source, method = self:GetSource(path)
    local compiler = loadstring or load
    if not compiler then
        error("[Resource] No Lua compiler available")
    end

    local chunk, err = compiler(source, "=" .. path)
    if not chunk then
        error("[Resource] Compilation error in " .. path .. ": " .. tostring(err))
    end

    local result = chunk()
    self.Cache[path] = result
    return result
end

function ResourceManager:Init()
    -- Initial setup if needed
    warn("[Resource] Systems initialized (Cache: " .. CACHE_PATH .. ")")
end

return ResourceManager
