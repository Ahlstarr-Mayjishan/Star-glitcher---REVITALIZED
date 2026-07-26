--[[
    Layout.lua - Player tab layout builder
]]

local Layout = {}

function Layout.Build(Tab, Options)
    local refs = {}

    Tab:CreateSection("Movement")

    Tab:CreateToggle({
        Name = "Fixed Move Speed",
        CurrentValue = Options.CustomMoveSpeedEnabled,
        Flag = "CustomMoveSpeedEnabledFlag",
        Callback = function(Value)
            Options.CustomMoveSpeedEnabled = Value
            if Value then
                Options.SpeedMultiplierEnabled = false
            end
        end,
    })

    Tab:CreateSection("Legit Multiplier")

    Tab:CreateToggle({
        Name = "Speed Multiplier",
        CurrentValue = Options.SpeedMultiplierEnabled,
        Flag = "SpeedMultiplierEnabledFlag",
        Callback = function(Value)
            Options.SpeedMultiplierEnabled = Value
            if Value then
                Options.CustomMoveSpeedEnabled = false
            end
        end,
    })

    Tab:CreateSection("Mobility")

    Tab:CreateToggle({
        Name = "Jump Boost",
        CurrentValue = Options.JumpBoostEnabled,
        Flag = "JumpBoostEnabledFlag",
        Callback = function(Value)
            Options.JumpBoostEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Float",
        CurrentValue = Options.FloatEnabled,
        Flag = "FloatEnabledFlag",
        Callback = function(Value)
            Options.FloatEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Custom Gravity",
        CurrentValue = Options.GravityEnabled,
        Flag = "GravityEnabledFlag",
        Callback = function(Value)
            Options.GravityEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Noclip",
        CurrentValue = Options.NoclipEnabled,
        Flag = "NoclipEnabledFlag",
        Callback = function(Value)
            Options.NoclipEnabled = Value
        end,
    })

    Tab:CreateSection("Anti-Debuff")

    Tab:CreateToggle({
        Name = "No Slowdown",
        CurrentValue = Options.NoSlowdown,
        Flag = "NoSlowdownFlag",
        Callback = function(Value)
            Options.NoSlowdown = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Stun",
        CurrentValue = Options.NoStun,
        Flag = "NoStunFlag",
        Callback = function(Value)
            Options.NoStun = Value
        end,
    })

    Tab:CreateToggle({
        Name = "No Delay (Attribute Cleaner)",
        CurrentValue = Options.NoDelay,
        Flag = "NoDelayFlag",
        Callback = function(Value)
            Options.NoDelay = Value
        end,
    })

    Tab:CreateSection("Custom Value")

    Tab:CreateSlider({
        Name = "Walk Speed (Fixed)",
        Range = { 1, 250 },
        Increment = 1,
        CurrentValue = Options.CustomMoveSpeed or 16,
        Flag = "CustomMoveSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.CustomMoveSpeed = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Multiplier Factor",
        Range = { 1, 5 },
        Increment = 0.1,
        CurrentValue = Options.SpeedMultiplier or 1.0,
        Flag = "SpeedMultiplierFlag",
        Suffix = "x",
        Callback = function(Value)
            Options.SpeedMultiplier = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Jump Power",
        Range = { 1, 300 },
        Increment = 1,
        CurrentValue = Options.JumpBoostPower or 70,
        Flag = "JumpBoostPowerFlag",
        Callback = function(Value)
            Options.JumpBoostPower = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Float Fall Speed",
        Range = { 0, 40 },
        Increment = 1,
        CurrentValue = Options.FloatFallSpeed or 8,
        Flag = "FloatFallSpeedFlag",
        Suffix = " studs/s",
        Callback = function(Value)
            Options.FloatFallSpeed = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Gravity Value",
        Range = { 0, 500 },
        Increment = 1,
        CurrentValue = Options.GravityValue or 196.2,
        Flag = "GravityValueFlag",
        Callback = function(Value)
            Options.GravityValue = Value
        end,
    })

    Tab:CreateSection("Status Scripts")

    refs.speedMultiplierLabel = Tab:CreateLabel("Multi Speed Status: Idle")
    refs.noclipLabel = Tab:CreateLabel("Noclip Status: Idle")
    refs.jumpBoostLabel = Tab:CreateLabel("Jump Boost Status: Idle")
    refs.floatLabel = Tab:CreateLabel("Float Status: Idle")
    refs.gravityLabel = Tab:CreateLabel("Gravity Status: Idle")
    refs.slowdownLabel = Tab:CreateLabel("No Slowdown: Idle")
    refs.stunLabel = Tab:CreateLabel("No Stun: Idle")

    Tab:CreateSection("Maintenance")

    Tab:CreateButton({
        Name = "Clean Status Char",
        Interact = "Click to Reset",
        Callback = function()
            if charCleaner then
                charCleaner:Clean()
                if Rayfield and Rayfield.Notify then
                    Rayfield:Notify({
                        Title = "Status Cleaned",
                        Content = "Character state and environment interactions restored.",
                        Duration = 3,
                        Image = 4483362458,
                    })
                end
            end
        end,
    })

    return refs
end

return Layout
