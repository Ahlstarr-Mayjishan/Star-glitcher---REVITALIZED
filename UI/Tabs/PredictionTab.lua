--[[
    PredictionTab.lua - Tab Prediction
    Prediction engine switches and range controls.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Prediction", 4483362458)

    Tab:CreateSection("Prediction Engine")

    Tab:CreateToggle({
        Name = "Enable Aim Prediction",
        CurrentValue = Options.PredictionEnabled,
        Flag = "PredictToggle",
        Callback = function(Value)
            Options.PredictionEnabled = Value
        end,
    })

    Tab:CreateToggle({
        Name = "Smart Prediction (Auto)",
        CurrentValue = Options.SmartPrediction,
        Flag = "SmartPredictToggle",
        Callback = function(Value)
            Options.SmartPrediction = Value
        end,
    })

    Tab:CreateDropdown({
        Name = "Technique Control",
        Options = {"Assisted", "Manual"},
        CurrentOption = {Options.PredictionTechniqueMode or "Assisted"},
        Flag = "PredictionTechniqueModeFlag",
        Callback = function(Value)
            Options.PredictionTechniqueMode = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateDropdown({
        Name = "Manual Technique",
        Options = {"Linear", "Strafe", "Orbit", "Airborne", "Dash Recovery"},
        CurrentOption = {Options.PredictionTechnique or "Linear"},
        Flag = "PredictionTechniqueFlag",
        Callback = function(Value)
            Options.PredictionTechnique = type(Value) == "table" and Value[1] or Value
        end,
    })

    Tab:CreateToggle({
        Name = "Technique Debug Overlay",
        CurrentValue = Options.PredictionTechniqueDebug == true,
        Flag = "PredictionTechniqueDebugFlag",
        Callback = function(Value)
            Options.PredictionTechniqueDebug = Value
        end,
    })

    Tab:CreateSlider({
        Name = "Projectile Velocity",
        Range = {50, 5000},
        Increment = 25,
        Suffix = " studs/s",
        CurrentValue = Options.ProjectileVelocity,
        Flag = "ProjectileVelocitySlider",
        Callback = function(Value)
            Options.ProjectileVelocity = Value
        end,
    })

    Tab:CreateSection("Target Response")

    Tab:CreateSlider({
        Name = "Maximum Distance",
        Range = {100, 5000},
        Increment = 50,
        Suffix = " Studs",
        CurrentValue = Options.MaxDistance,
        Flag = "DistanceSlider",
        Callback = function(Value)
            Options.MaxDistance = Value
        end,
    })

    return Tab
end
