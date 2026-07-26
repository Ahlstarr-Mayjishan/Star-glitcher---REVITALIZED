local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GravityController = {}
GravityController.__index = GravityController

local DEFAULT_GRAVITY = 196.2

function GravityController.new(options)
    local self = setmetatable({}, GravityController)
    self.Options = options
    self.Status = "Idle"
    self.BaseGravity = Workspace.Gravity or DEFAULT_GRAVITY
    self._connection = nil
    self._applied = false
    return self
end

function GravityController:_restore()
    if self._applied and math.abs(Workspace.Gravity - self.BaseGravity) > 0.05 then
        Workspace.Gravity = self.BaseGravity
    end
    self._applied = false
end

function GravityController:Init()
    if self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        if self.Options.GravityEnabled then
            local desired = math.clamp(tonumber(self.Options.GravityValue) or DEFAULT_GRAVITY, 0, 1000)
            if math.abs(Workspace.Gravity - desired) > 0.05 then
                Workspace.Gravity = desired
            end
            self._applied = true
            self.Status = string.format("Active: %.1f", desired)
            return
        end

        if not self._applied then
            self.BaseGravity = Workspace.Gravity
            self.Status = "Idle"
            return
        end

        self:_restore()
        self.Status = "Idle"
    end)
end

function GravityController:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    self:_restore()
end

return GravityController
