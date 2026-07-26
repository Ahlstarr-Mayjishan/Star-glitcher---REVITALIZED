--[[
    ResourceManager.lua - Optimized Module Loader with Cache & Local Override
    Handles fetching, caching, and version verification of modules.
]]

local ResourceManager = {}
ResourceManager.__index = ResourceManager

local CACHE_PATH = ".star_glitcher_cache"
local LOCAL_PATH_KEY = "BossAimAssist_LocalPath"

function ResourceManager.NormalizeBases(remoteBases)
    if type(remoteBases) == "string" then
        remoteBases = {remoteBases}
    end

    local normalized = {}
    local seen = {}
    for _, base in ipairs(type(remoteBases) == "table" and remoteBases or {}) do
        if type(base) == "string" and base ~= "" then
            local clean = base:gsub("/+$", "") .. "/"
            if not seen[clean] then
                seen[clean] = true
                normalized[#normalized + 1] = clean
            end
        end
    end
    return normalized
end

function ResourceManager.BuildUrl(base, path, cacheKey)
    local cleanBase = tostring(base):gsub("/+$", "")
    local cleanPath = tostring(path):gsub("^/+", "")
    local url = cleanBase .. "/" .. cleanPath
    if cacheKey ~= nil then
        url = url .. "?v=" .. tostring(cacheKey)
    end
    return url
end

function ResourceManager.IsValidSource(content)
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

function ResourceManager.new(options, remoteBases, manifest)
    local self = setmetatable({}, ResourceManager)
    self.Options = options
    self.RemoteBases = ResourceManager.NormalizeBases(remoteBases)
    assert(#self.RemoteBases > 0, "[Resource] At least one remote source is required")
    self.GithubBase = self.RemoteBases[1]
    self.ActiveBase = self.RemoteBases[1]
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

    -- 3. Remote Fetch (GitHub primary, CDN mirrors as fallback)
    local lastError = nil

    for _, base in ipairs(self.RemoteBases) do
        local url = ResourceManager.BuildUrl(base, path, self.SessionID)
        for attempt = 1, 2 do
            local ok, content = pcall(game.HttpGet, game, url)
            if ok and ResourceManager.IsValidSource(content) then
                self.ActiveBase = base

                -- Inject version metadata for next cache hit
                local versionHeader = "-- @version " .. targetVersion .. "\n"
                local processedContent = versionHeader .. content

                -- Save to cache
                if writefile then
                    pcall(function()
                        writefile(cachedFile, processedContent)
                    end)
                end

                return processedContent, "remote"
            end
            lastError = string.format("%s (attempt %d): %s", url, attempt, tostring(content))
            task.wait(0.15 * attempt)
        end
    end

    error("[Resource] Fatal fetch error: Failed to load " .. path .. " from every configured source. Last error: " .. tostring(lastError))
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
