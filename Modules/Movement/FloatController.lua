local RunService = game:GetService("RunService")

local FloatController = {}
FloatController.__index = FloatController

local AIR_STATES = {
    [Enum.HumanoidStateType.Freefall] = true,
    [Enum.HumanoidStateType.Jumping] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
}

function FloatController.new(options, localCharacter)
    local self = setmetatable({}, FloatController)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self._connection = nil
    return self
end

function FloatController:Init()
    if self._connection then
        return
    end

    self._connection = RunService.Heartbeat:Connect(function()
        if not self.Options.FloatEnabled then
            self.Status = "Idle"
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            self.Status = "Respawn grace"
            return
        end

        local _, humanoid, root = self.LocalCharacter:GetState()
        if not humanoid or not root then
            self.Status = "Waiting for character"
            return
        end

        local state = humanoid:GetState()
        if not AIR_STATES[state] then
            self.Status = "Grounded"
            return
        end

        local velocity = root.AssemblyLinearVelocity
        local maxFallSpeed = -math.clamp(tonumber(self.Options.FloatFallSpeed) or 8, 0, 80)
        if velocity.Y < maxFallSpeed then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, maxFallSpeed, velocity.Z)
            self.Status = string.format("Softening fall: %.1f", math.abs(maxFallSpeed))
        else
            self.Status = "Airborne hold"
        end
    end)
end

function FloatController:Destroy()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

return FloatController
