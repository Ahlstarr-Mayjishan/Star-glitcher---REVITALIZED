--[[
    GamemodeTab.lua - Tab for Game-Specific Exploits
    Contains UltraHell and Kill Part Bypass.
]]

local function setLabelText(label, text)
    if not label then return end
    if type(label) == "table" and type(label.Set) == "function" then
        pcall(label.Set, label, text)
        return
    end
end

return function(Window, Options, killPartBypass, ultraHell, waypoint)
    local Tab = Window:CreateTab("Gamemode", 4483362458)
    
    Tab:CreateSection("Bypasses")

    Tab:CreateToggle({
        Name = "Kill Part Bypass",
        CurrentValue = Options.KillPartBypassEnabled or false,
        Flag = "KillPartBypassFlag",
        Callback = function(Value) Options.KillPartBypassEnabled = Value end,
    })

    Tab:CreateSection("UltraHell Gamemode")

    Tab:CreateLabel("Deal damage once to capture combat packet, then toggle UltraHell.")

    Tab:CreateToggle({
        Name = "UltraHell Multi-Hit",
        CurrentValue = Options.UltraHellEnabled or false,
        Flag = "UltraHellEnabledFlag",
        Callback = function(Value)
            Options.UltraHellEnabled = Value
            if Value and getgenv().Rayfield then
                getgenv().Rayfield:Notify({
                    Title = "UltraHell Armed",
                    Content = "Hit an enemy once to begin multi-hit cycle.",
                    Duration = 4,
                })
            end
        end,
    })

    Tab:CreateSection("Stage Teleports")

    Tab:CreateButton({
        Name = "Teleport to Stage 1",
        Interact = "Instant",
        Callback = function()
            local cf = CFrame.new(7997.925, 707.277, 361.218, 0.203, 3.342e-08, -0.979, -3.876e-08, 1, 2.607e-08, 0.979, 3.265e-08, 0.203)
            local char = game:GetService("Players").LocalPlayer.Character
            if char then char:PivotTo(cf) end
        end,
    })

    Tab:CreateButton({
        Name = "Teleport to Stage 2",
        Interact = "Instant",
        Callback = function()
            local cf = CFrame.new(8260.945, 1900.713, 640.922, 0.376, 2.271e-08, 0.926, -1.115e-08, 1, -1.998e-08, -0.926, -2.803e-09, 0.376)
            local char = game:GetService("Players").LocalPlayer.Character
            if char then char:PivotTo(cf) end
        end,
    })

    Tab:CreateButton({
        Name = "Teleport to Stage 3",
        Interact = "Instant",
        Callback = function()
            local cf = CFrame.new(102.725, 2105.546, 8404.134, 0.092, -5.482e-08, 0.995, 1.118e-07, 1, 4.47e-08, -0.995, 1.072e-07, 0.092)
            local char = game:GetService("Players").LocalPlayer.Character
            if char then char:PivotTo(cf) end
        end,
    })

    Tab:CreateButton({
        Name = "Get SupaGun",
        Interact = "Instant",
        Callback = function()
            local cf = CFrame.new(-683.702, 2063.087, 6963.396, 0.988, -9.108e-09, -0.152, -7.943e-09, 1, -1.114e-07, 0.152, 1.113e-07, 0.988)
            local char = game:GetService("Players").LocalPlayer.Character
            if char then char:PivotTo(cf) end
        end,
    })

    Tab:CreateSection("Custom Value")

    Tab:CreateSlider({
        Name = "Multi Hit Rate",
        Range = {1, 100},
        Increment = 1,
        Suffix = " hits/s",
        CurrentValue = tonumber(Options.UltraHellHitsPerSecond) or 10,
        Flag = "UltraHellHitsPerSecondFlag",
        Callback = function(Value)
            Options.UltraHellHitsPerSecond = Value
        end,
    })

    Tab:CreateSection("Status Scripts")

    local killPartLabel = Tab:CreateLabel("Kill Part Bypass: Idle")
    local ultraHellLabel = Tab:CreateLabel("UltraHell: Waiting for capture...")

    -- Status Loop
    task.spawn(function()
        local lastK = ""
        local lastU = ""
        while task.wait(0.4) do
            if killPartBypass then
                local txt = "Kill Part Bypass: " .. tostring(killPartBypass.Status or "Idle")
                if txt ~= lastK then lastK = txt; setLabelText(killPartLabel, txt) end
            end
            if ultraHell then
                local txt = "UltraHell: " .. tostring(ultraHell.Status or "Idle")
                if txt ~= lastU then lastU = txt; setLabelText(ultraHellLabel, txt) end
            end
        end
    end)

    return Tab
end
