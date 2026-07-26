--[[
    PlayerTab.lua - Compatibility wrapper
    Job: Delegate Player tab construction to an injected controller.
]]

return function(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, controller, charCleaner)
    if controller and controller.Build then
        return controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, charCleaner)
    end

    error("PlayerTab controller was not provided", 2)
end
