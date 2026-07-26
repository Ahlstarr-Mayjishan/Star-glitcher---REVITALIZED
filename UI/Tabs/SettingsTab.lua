--[[
    SettingsTab.lua - Settings and script management
    UI toggle key, config actions, and maintenance tools.
]]

return function(Window, Options, cleaner, resourceManager, tracker, taskScheduler)
    local Tab = Window:CreateTab("Settings", 4483362458)
    local controller = {
        Tab = Tab,
        Alive = true,
    }

    local function setLabelText(label, text)
        if not label then
            return
        end

        if type(label) == "table" and type(label.Set) == "function" then
            local ok = pcall(function()
                label:Set(text)
            end)
            if ok then
                return
            end
        end

        if typeof(label) == "Instance" then
            local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
            if textLabel then
                textLabel.Text = text
            end
        end
    end

    Tab:CreateSection("Optimization & Safety")

    local cleanerLabel, resourceLabel, trackerLabel, schedulerLabel, resourcePendingLabel

    Tab:CreateToggle({
        Name = "Auto-Clean Debris",
        CurrentValue = Options.AutoCleanEnabled,
        Flag = "AutoCleanFlag",
        Callback = function(Value)
            Options.AutoCleanEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Smart Cleanup Scheduler",
        CurrentValue = Options.SmartCleanupEnabled ~= false,
        Flag = "SmartCleanupEnabledFlag",
        Callback = function(Value)
            Options.SmartCleanupEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Runtime Stats Debug",
        CurrentValue = Options.RuntimeStatsDebug == true,
        Flag = "RuntimeStatsDebugFlag",
        Callback = function(Value)
            Options.RuntimeStatsDebug = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Auto Clean + Update",
        CurrentValue = Options.AutoUpdateEnabled == true,
        Flag = "AutoUpdateEnabledFlag",
        Callback = function(Value)
            Options.AutoUpdateEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Rejoin on Kick",
        CurrentValue = Options.RejoinOnKickEnabled == true,
        Flag = "RejoinOnKickEnabledFlag",
        Callback = function(Value)
            Options.RejoinOnKickEnabled = Value
        end,
    })

    Tab:CreateButton({
        Name = "Clean Memory & Debris Now",
        Callback = function()
            if cleaner then
                local destroyed, found, deferred, remaining = cleaner:Clean()
                Rayfield:Notify({
                    Title = "Cleanup Scheduled",
                    Content = string.format(
                        "Found %d debris, destroyed %d now, deferred %d, remaining local %d.",
                        found or 0,
                        destroyed or 0,
                        deferred or 0,
                        remaining or 0
                    ),
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateSection("UI & Controls")

    Tab:CreateDropdown({
        Name = "UI Toggle Key (saved for next reload)",
        Options = {
            "RightControl", "LeftControl", "RightShift", "LeftShift",
            "RightAlt", "LeftAlt", "Backquote", "Insert",
            "Home", "End", "PageUp", "PageDown",
            "F1", "F2", "F3", "F4", "F6", "F7", "F8", "F9", "F10",
        },
        CurrentOption = { Options.ToggleUIKey or "RightControl" },
        Flag = "ToggleUIKey",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            Options.ToggleUIKey = selected
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "UI Key Updated",
                    Content = "UI toggle key saved as " .. tostring(selected) .. ". It applies immediately and will persist after reload.",
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateButton({
        Name = "Destroy Script (Emergency Stop)",
        Callback = function()
            if _G.BossAimAssist_Cleanup then
                task.spawn(function()
                    local ok, err = pcall(function()
                        _G.BossAimAssist_Cleanup(false)
                    end)
                    if not ok and Rayfield and Rayfield.Notify then
                        Rayfield:Notify({
                            Title = "Emergency Stop Failed",
                            Content = tostring(err),
                            Duration = 5,
                            -- Image removed for compatibility
                        })
                    end
                end)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Run Clean + Update Now",
        Callback = function()
            local updater = _G.BossAimAssist_Update
            if updater then
                task.defer(updater)
            elseif _G.BossAimAssist_Cleanup then
                task.defer(function()
                    _G.BossAimAssist_Cleanup(true)
                end)
            end
        end,
    })

    Tab:CreateButton({
        Name = "Check for Updates",
        Callback = function()
            if _G.BossAimAssist_CheckForUpdates then
                _G.BossAimAssist_CheckForUpdates(true)
            elseif Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "Updater Unavailable",
                    Content = "This runtime does not expose the update checker yet. Reload from Main.lua.",
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateSection("Configuration")

    Tab:CreateButton({
        Name = "Save Current Config",
        Callback = function()
            Rayfield:SaveConfiguration()
        end,
    })

    Tab:CreateButton({
        Name = "Rejoin Server (Same Instance)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
        end,
    })

    Tab:CreateButton({
        Name = "Server Hop (Join New Instance)",
        Callback = function()
            local ts = game:GetService("TeleportService")
            local p = game:GetService("Players").LocalPlayer
            local http = game:GetService("HttpService")

            pcall(function()
                local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                local content = game:HttpGet(url)
                local data = http:JSONDecode(content)

                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        ts:TeleportToPlaceInstance(game.PlaceId, s.id, p)
                        return
                    end
                end

                Rayfield:Notify({
                    Title = "Server Hop Failed",
                    Content = "No suitable new servers found at this time.",
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end)
        end,
    })

    Tab:CreateSection("Script Management")

    task.spawn(function()
        local lastCleanerText
        local lastResourceText
        local lastTrackerText
        local lastSchedulerText
        local lastResourcePendingText

        while controller.Alive do
            if cleaner then
                local nextText = "Cleanup Status: " .. tostring(cleaner.Status)
                if nextText ~= lastCleanerText then
                    setLabelText(cleanerLabel, nextText)
                    lastCleanerText = nextText
                end
            end
            if resourceManager then
                local nextText = string.format(
                    "Resource Manager: %s",
                    tostring(resourceManager.Status)
                )
                if nextText ~= lastResourceText then
                    setLabelText(resourceLabel, nextText)
                    lastResourceText = nextText
                end
            end

            local statsEnabled = Options.RuntimeStatsDebug == true
            local trackerText = statsEnabled
                and string.format("Tracker Entries: %d", tracker and tracker.GetEntryCount and tracker:GetEntryCount() or 0)
                or "Tracker Entries: Hidden"
            if trackerText ~= lastTrackerText then
                setLabelText(trackerLabel, trackerText)
                lastTrackerText = trackerText
            end

            local schedulerText = statsEnabled
                and string.format("Task Scheduler: %d pending", taskScheduler and taskScheduler.GetPendingCount and taskScheduler:GetPendingCount() or 0)
                or "Task Scheduler: Hidden"
            if schedulerText ~= lastSchedulerText then
                setLabelText(schedulerLabel, schedulerText)
                lastSchedulerText = schedulerText
            end

            local resourcePendingText = statsEnabled
                and string.format("Resource Pending: %d", resourceManager and resourceManager.GetPendingCount and resourceManager:GetPendingCount() or 0)
                or "Resource Pending: Hidden"
            if resourcePendingText ~= lastResourcePendingText then
                setLabelText(resourcePendingLabel, resourcePendingText)
                lastResourcePendingText = resourcePendingText
            end

            task.wait(0.5)
        end
    end)

    Tab:CreateToggle({
        Name = "Auto-Execute",
        CurrentValue = Options.AutoExecuteEnabled or false,
        Flag = "AutoExecuteFlag",
        Callback = function(Value)
            Options.AutoExecuteEnabled = Value
            if Value then
                local command = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Ahlstarr-Mayjishan/Scripting-Roblox-/main/STAR%20GLITCHER%20~%20REVITALIZED/Main.lua?v=" .. tostring(os.time())))()]]
                if writefile then
                    pcall(function()
                        writefile("BossAimAssist_Loader.lua", command)
                        Rayfield:Notify({
                            Title = "Auto-Execute Enabled",
                            Content = "Loader saved to workspace/BossAimAssist_Loader.lua. Move this to your autoexec folder.",
                            Duration = 5,
                            -- Image removed for compatibility
                        })
                    end)
                else
                    Rayfield:Notify({
                        Title = "Error",
                        Content = "Your executor does not support writefile.",
                        Duration = 5,
                        -- Image removed for compatibility
                    })
                end
            else
                if delfile then
                    pcall(function()
                        delfile("BossAimAssist_Loader.lua")
                        Rayfield:Notify({
                            Title = "Auto-Execute Disabled",
                            Content = "Loader file removed from workspace.",
                            Duration = 5,
                            -- Image removed for compatibility
                        })
                    end)
                end
            end
        end,
    })

    Tab:CreateSection("Custom Value")

    Tab:CreateSlider({
        Name = "Update Check Interval",
        Range = { 1, 30 },
        Increment = 1,
        CurrentValue = Options.AutoUpdateIntervalMinutes or 5,
        Flag = "AutoUpdateIntervalMinutesFlag",
        Suffix = " min",
        Callback = function(Value)
            Options.AutoUpdateIntervalMinutes = Value
        end,
    })

    Tab:CreateSection("Status Scripts")

    cleanerLabel = Tab:CreateLabel("Cleanup Status: Idle")
    resourceLabel = Tab:CreateLabel("Resource Manager: Idle")
    trackerLabel = Tab:CreateLabel("Tracker Entries: Hidden")
    schedulerLabel = Tab:CreateLabel("Task Scheduler: Hidden")
    resourcePendingLabel = Tab:CreateLabel("Resource Pending: Hidden")

    function controller:Destroy()
        self.Alive = false
    end

    return controller
end
