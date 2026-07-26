--[[
    Controller.lua - Player tab controller
    Job: Compose layout and status refresh helpers for the Player tab.
]]

local Controller = {}
Controller.__index = Controller

function Controller.new(layout, statusLoop, labelUtils)
    local self = setmetatable({}, Controller)
    self.Layout = layout
    self.StatusLoop = statusLoop
    self.LabelUtils = labelUtils
    self._statusLoopHandle = nil
    return self
end

function Controller:Build(Window, Options, noSlowdown, noStun, speedMultiplier, gravityController, floatController, jumpBoost, noclip, charCleaner)
    local Tab = Window:CreateTab("Player", 4483362458)
    local refs = self.Layout.Build(Tab, Options, charCleaner)

    if self._statusLoopHandle and self._statusLoopHandle.Destroy then
        self._statusLoopHandle:Destroy()
    end

    self._statusLoopHandle = self.StatusLoop.Start(refs, {
        noSlowdown = noSlowdown,
        noStun = noStun,
        speedMultiplier = speedMultiplier,
        gravityController = gravityController,
        floatController = floatController,
        jumpBoost = jumpBoost,
        noclip = noclip,
    }, self.LabelUtils)

    return Tab
end

function Controller:Destroy()
    if self._statusLoopHandle and self._statusLoopHandle.Destroy then
        self._statusLoopHandle:Destroy()
        self._statusLoopHandle = nil
    end
end

return Controller
