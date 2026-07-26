--[[
    AntiStun.lua - Neurological Defense Module (Bug Fixed)
    Job: Preventing character CC (Stun, Ragdoll, Sit, Fall).
    Status: Fully decoupled with active monitoring.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local clock = os.clock

local AntiStun = {}
AntiStun.__index = AntiStun

function AntiStun.new(options, localCharacter)
    local self = setmetatable({}, AntiStun)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.TrackedHumanoid = nil

    self.Status = "Idle"
    self._lastAction = 0
    return self
end

function AntiStun:_setStatus(status)
    if self.Status ~= status then
        self.Status = status
    end
end

function AntiStun:_restoreStateGuards(humanoid)
    if not humanoid then
        return
    end
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
    end)
end

function AntiStun:_applyStateGuards(humanoid)
    if not humanoid then
        return
    end
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid.PlatformStand = false
        humanoid.Sit = false
    end)
end

function AntiStun:Init()
    self.Connection = RunService.Heartbeat:Connect(function()
        local _, hum = self.LocalCharacter and self.LocalCharacter:GetState()
        
        -- PROACTIVE SCAN: If module says hum is missing, check the direct player object
        if not hum then
            local lp = Players.LocalPlayer
            local char = lp.Character
            hum = char and char:FindFirstChildOfClass("Humanoid")
        end

        if not self.Options.NoStun then
            self:_setStatus("Disabled")
            if hum == self.TrackedHumanoid then
                self:_restoreStateGuards(hum)
                self.TrackedHumanoid = nil
            end
            return
        end

        if not hum then
            self:_setStatus("Hum Missing")
            return
        end

        if self.LocalCharacter and self.LocalCharacter.IsRespawning and self.LocalCharacter:IsRespawning() then
            if hum ~= self.TrackedHumanoid then
                if self.TrackedHumanoid then
                    self:_restoreStateGuards(self.TrackedHumanoid)
                end
                self.TrackedHumanoid = hum
            end
            self:_setStatus("Respawn Grace")
            return
        end

        self:_setStatus("Active: Monitoring")

        if hum ~= self.TrackedHumanoid then
            if self.TrackedHumanoid then
                self:_restoreStateGuards(self.TrackedHumanoid)
            end
            self.TrackedHumanoid = hum
            self:_applyStateGuards(hum)
        end

        local state = hum:GetState()
        local actionTaken = false

        if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            actionTaken = true
        end

        if hum.PlatformStand then
            hum.PlatformStand = false
            actionTaken = true
        end

        if hum.Sit then
            hum.Sit = false
            actionTaken = true
        end

        if actionTaken then
            self._lastAction = clock()
        end

        if (clock() - self._lastAction) < 1.0 then
            self:_setStatus("Active: CC PROTECTED")
        end
    end)
end

function AntiStun:Destroy()
    if self.TrackedHumanoid then
        self:_restoreStateGuards(self.TrackedHumanoid)
        self.TrackedHumanoid = nil
    end
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return AntiStun
