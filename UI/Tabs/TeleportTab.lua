return function(Window, Options, waypointTeleport)
    local Tab = Window:CreateTab("Teleport", 4483362458)

    local waypointDropdown = Tab:CreateDropdown({
        Name = "Waypoint List",
        Options = waypointTeleport and waypointTeleport:GetWaypointNames() or { "(No waypoints yet)" },
        CurrentOption = { waypointTeleport and waypointTeleport.SelectedWaypointName or "(No waypoints yet)" },
        Flag = "TeleportWaypointDropdown",
        Callback = function(Value)
            local selected = type(Value) == "table" and Value[1] or Value
            if waypointTeleport then
                waypointTeleport:SetSelectedWaypoint(selected)
            end
        end,
    })

    if waypointTeleport then
        waypointTeleport:SetDropdown(waypointDropdown)
    end

    local customNameInput = ""

    Tab:CreateInput({
        Name = "Custom Waypoint Name",
        PlaceholderText = "Leave blank for auto-time name",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            customNameInput = Text or ""
        end,
    })

    Tab:CreateButton({
        Name = "Set Waypoint",
        Callback = function()
            if not waypointTeleport then
                return
            end

            local nameToSet = customNameInput ~= "" and customNameInput or nil
            local ok, detail = waypointTeleport:SetWaypoint(nameToSet)
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = ok and "Waypoint Saved" or "Waypoint Failed",
                    Content = ok and ("Saved " .. tostring(detail)) or tostring(detail),
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateButton({
        Name = "Go To Selected Waypoint",
        Callback = function()
            if not waypointTeleport then
                return
            end

            local ok, detail = waypointTeleport:GotoSelectedWaypoint()
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = ok and "Teleport Started" or "Teleport Failed",
                    Content = ok and ("Heading to " .. tostring(detail) .. " via " .. tostring(Options.TeleportMethod or "Tween")) or tostring(detail),
                    Duration = 4,
                    -- Image removed for compatibility
                })
            end
        end,
    })

    Tab:CreateDropdown({
        Name = "Method",
        Options = { "Tween", "Teleport" },
        CurrentOption = { Options.TeleportMethod or "Tween" },
        Flag = "TeleportMethodDropdown",
        Callback = function(Value)
            Options.TeleportMethod = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateSection("Custom Value")

    Tab:CreateSlider({
        Name = "Tween Speed",
        Range = { 10, 1000 },
        Increment = 10,
        CurrentValue = Options.TeleportTweenSpeed or 150,
        Flag = "TeleportTweenSpeedSlider",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.TeleportTweenSpeed = Value
        end,
    })

    Tab:CreateSection("Status Scripts")

    return Tab
end
