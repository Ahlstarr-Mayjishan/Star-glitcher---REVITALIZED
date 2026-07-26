--[[
    Noclip.lua - Phase Shifting Module
    Job: Disable physics collisions only.
    Notes: Kill-part touch suppression lives in KillPartBypass.lua so it can
    be controlled independently from noclip.
]]

local RunService = game:GetService("RunService")

local Noclip = {}
Noclip.__index = Noclip

function Noclip.new(options, localCharacter)
    local self = setmetatable({}, Noclip)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    return self
end

function Noclip:Init()
    self.Connection = RunService.Stepped:Connect(function()
        if not self.Options.NoclipEnabled then
            if self.Status ~= "Disabled" then
                self.Status = "Disabled"
            end
            return
        end

        local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        local parts = self.LocalCharacter and self.LocalCharacter.GetCharacterParts and self.LocalCharacter:GetCharacterParts()
        
        if not character then
            self.Status = "Char Missing"
            return
        end

        self.Status = "Active: Noclip"
        
        for _, obj in ipairs(parts or character:GetDescendants()) do
            if obj:IsA("BasePart") then
                if obj.CanCollide then
                    obj.CanCollide = false
                end
            end
        end

        if rootPart then
            rootPart.CanCollide = false
        end
    end)
end

function Noclip:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return Noclip
