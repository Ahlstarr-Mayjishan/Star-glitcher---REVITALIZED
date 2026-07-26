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
    self._originalCanCollide = setmetatable({}, { __mode = "k" })
    self._wasEnabled = false
    return self
end

function Noclip:_disableCollision(part)
    if self._originalCanCollide[part] == nil then
        self._originalCanCollide[part] = part.CanCollide
    end
    if part.CanCollide then
        part.CanCollide = false
    end
end

function Noclip:_restoreCollision()
    for part, originalValue in pairs(self._originalCanCollide) do
        if part and part.Parent then
            part.CanCollide = originalValue
        end
        self._originalCanCollide[part] = nil
    end
    self._wasEnabled = false
end

function Noclip:Init()
    self.Connection = RunService.Stepped:Connect(function()
        if not self.Options.NoclipEnabled then
            if self._wasEnabled then
                self:_restoreCollision()
            end
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
        self._wasEnabled = true
        
        for _, obj in ipairs(parts or character:GetDescendants()) do
            if obj:IsA("BasePart") then
                self:_disableCollision(obj)
            end
        end

        if rootPart then
            self:_disableCollision(rootPart)
        end
    end)
end

function Noclip:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
    self:_restoreCollision()
end

return Noclip
