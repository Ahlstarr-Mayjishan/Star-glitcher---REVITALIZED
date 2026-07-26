local RuntimeLifecycle = {}
RuntimeLifecycle.__index = RuntimeLifecycle

function RuntimeLifecycle.new(options, version, rayfield, resourceManager, cleaner, synapse, updateEntryUrl, executeUpdatedEntry, fetchRemoteVersion, getCleanupObjects, onResetState)
    local self = setmetatable({}, RuntimeLifecycle)
    self.Options = options
    self.Version = version
    self.Rayfield = rayfield
    self.ResourceManager = resourceManager
    self.Cleaner = cleaner
    self.Synapse = synapse
    self.UpdateEntryUrl = updateEntryUrl
    self.ExecuteUpdatedEntry = executeUpdatedEntry
    self.FetchRemoteVersion = fetchRemoteVersion
    self.GetCleanupObjects = getCleanupObjects
    self.OnResetState = onResetState
    self.SessionId = os.time()
    self.CleanupInProgress = false
    self.AutoUpdateLoopStarted = false
    self._connections = {}
    return self
end

function RuntimeLifecycle:RegisterConnection(connection)
    self._connections[#self._connections + 1] = connection
    return connection
end

function RuntimeLifecycle:PerformCleanup(fullSweep)
    if self.CleanupInProgress then
        return
    end
    self.CleanupInProgress = true

    pcall(function()
        self.Rayfield:Destroy()
    end)

    for _, connection in ipairs(self._connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self._connections)

    local objs = self.GetCleanupObjects and self.GetCleanupObjects() or {}
    if self.ResourceManager then
        self.ResourceManager:DeferCleanup(function()
            self.Synapse.clearAll()
        end)

        for _, obj in ipairs(objs) do
            self.ResourceManager:TrackObject(obj)
        end
        self.ResourceManager:ScheduleTrackedCleanup()
        self.ResourceManager:Flush(fullSweep and 1.5 or 0.75)
    else
        for _, obj in ipairs(objs) do
            if obj and obj.Destroy then
                pcall(function()
                    obj:Destroy()
                end)
            end
        end

        self.Synapse.clearAll()
    end

    _G.BossAimAssist_SessionID = nil
    _G.BossAimAssist_Update = nil
    _G.BossAimAssist_Cleanup = nil
    _G.BossAimAssist_CheckForUpdates = nil
    _G.__STAR_GLITCHER_AUTOUPDATE_BOOTED = nil
    _G.__STAR_GLITCHER_CORE_BOOT_UNTIL = nil
    _G.__STAR_GLITCHER_ENTRY_BOOT_UNTIL = nil

    if self.OnResetState then
        pcall(self.OnResetState)
    end

    if fullSweep then
        pcall(function()
            if self.Cleaner and self.Cleaner.Clean then
                self.Cleaner:Clean()
            end
        end)
        if self.ResourceManager then
            self.ResourceManager:Boost(1.5)
            self.ResourceManager:Flush(1.5)
        end
        pcall(function()
            collectgarbage("count")
            collectgarbage("count")
        end)
    end

    if self.ResourceManager then
        pcall(function()
            self.ResourceManager:Destroy()
        end)
    end

    self.CleanupInProgress = false
end

function RuntimeLifecycle:BindGlobals()
    _G.BossAimAssist_SessionID = self.SessionId

    _G.BossAimAssist_Cleanup = function(fullSweep)
        task.spawn(function()
            task.wait(0.25) -- Allow UI click animations to finish
            local ok, err = pcall(function()
                self:PerformCleanup(fullSweep == true)
            end)
            self.CleanupInProgress = false
            if not ok then
                warn("[Cleanup] Failed | Error: " .. tostring(err))
            end
        end)
    end

    _G.BossAimAssist_Update = function()
        local updateUrl = self.UpdateEntryUrl .. "?update=" .. tostring(os.time())
        task.spawn(function()
            task.wait(0.25) -- Allow UI click animations to finish
            self:PerformCleanup(true)
            task.wait(0.2)
            local ok, result = pcall(function()
                return self.ExecuteUpdatedEntry(updateUrl, "=updated-entry")
            end)
            if not ok then
                warn("[Update] Reload failed after cleanup | Error: " .. tostring(result))
            end
        end)
    end

    _G.BossAimAssist_CheckForUpdates = function(manual)
        local ok, remoteVersion = pcall(self.FetchRemoteVersion)

        if not ok then
            if manual and self.Rayfield and self.Rayfield.Notify then
                self.Rayfield:Notify({
                    Title = "Update Check Failed",
                    Content = "Version check failed. The remote file responded, but parsing or access failed.",
                    Duration = 5,
                    -- Image removed for compatibility
                })
            end
            return false
        end

        remoteVersion = tonumber(remoteVersion) or 0
        local currentVersion = tonumber(self.Version) or 0

        if remoteVersion > currentVersion then
            if self.Rayfield and self.Rayfield.Notify then
                self.Rayfield:Notify({
                    Title = "Update Found",
                    Content = string.format("Updating from r%d to r%d.", currentVersion, remoteVersion),
                    Duration = 3,
                    -- Image removed for compatibility
                })
            end
            task.spawn(function()
                task.wait(0.35)
                local updater = _G.BossAimAssist_Update
                if updater then
                    updater()
                end
            end)
            return true
        end

        if manual and self.Rayfield and self.Rayfield.Notify then
            self.Rayfield:Notify({
                Title = "Up To Date",
                Content = string.format("Current runtime r%d is already the newest version.", currentVersion),
                Duration = 4,
                -- Image removed for compatibility
            })
        end

        return false
    end
end

function RuntimeLifecycle:StartAutoUpdateLoop()
    if not _G.__STAR_GLITCHER_AUTOUPDATE_BOOTED then
        _G.__STAR_GLITCHER_AUTOUPDATE_BOOTED = true
        task.spawn(function()
            task.wait(1)
            if _G.BossAimAssist_CheckForUpdates then
                _G.BossAimAssist_CheckForUpdates(false)
            end
        end)
    end

    if self.AutoUpdateLoopStarted then
        return
    end
    self.AutoUpdateLoopStarted = true

    task.spawn(function()
        local lastCheck = 0

        while _G.BossAimAssist_SessionID == self.SessionId do
            task.wait(5)

            if not self.Options.AutoUpdateEnabled then
                lastCheck = os.clock()
                continue
            end

            local now = os.clock()
            local intervalSeconds = math.max(1, tonumber(self.Options.AutoUpdateIntervalMinutes) or 5) * 60
            if (now - lastCheck) < intervalSeconds then
                continue
            end

            lastCheck = now
            local checker = _G.BossAimAssist_CheckForUpdates
            if checker then
                checker(false)
            end
        end
    end)
end

return RuntimeLifecycle
