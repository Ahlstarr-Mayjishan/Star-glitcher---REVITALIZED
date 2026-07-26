--[[
    BlatantTab.lua - Tab Blatant (Optimized v7.2 - Cleanup Edition)
    Contains explicit bypass-style options.
]]

return function(Window, Options)
    local Tab = Window:CreateTab("Blatant & Bypass", 4483362458)
    
    Tab:CreateSection("Client Masking")

    Tab:CreateToggle({
        Name = "Speed Spoof (Bypass)",
        CurrentValue = Options.SpeedSpoofEnabled or false,
        Flag = "SpeedSpoofFlag",
        Callback = function(Value) Options.SpeedSpoofEnabled = Value end,
    })

    Tab:CreateSection("Custom Value")
    Tab:CreateSection("Status Scripts")

    return Tab
end
