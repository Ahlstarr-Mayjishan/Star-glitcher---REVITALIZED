--[[
    KillPartBypass.lua
    Job: Suppress touch/query hits on the local character so environmental
    kill parts are less likely to register against it.
]]

local RunService = game:GetService("RunService")

local KillPartBypass = {}
KillPartBypass.__index = KillPartBypass

function KillPartBypass.new(options, localCharacter)
    local self = setmetatable({}, KillPartBypass)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Connection = nil
    self.Status = "Idle"
    return self
end

local function suppressPartSensors(part)
    pcall(function()
        if part.CanTouch then
            part.CanTouch = false
        end
        if part.CanQuery then
            part.CanQuery = false
        end
    end)
end

function KillPartBypass:Init()
    self.Connection = RunService.Stepped:Connect(function()
        local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
        local rootPart = self.LocalCharacter and self.LocalCharacter:GetRootPart()
        local parts = self.LocalCharacter and self.LocalCharacter.GetCharacterParts and self.LocalCharacter:GetCharacterParts()

        if not character then
            self.Status = "Char Missing"
            return
        end

        if not self.Options.KillPartBypassEnabled then
            if self.Status ~= "Disabled" then
                self.Status = "Disabled"
                task.spawn(function()
                    for i = 1, 5 do
                        local char = self.LocalCharacter and self.LocalCharacter:GetCharacter()
                        local parts = self.LocalCharacter and self.LocalCharacter.GetCharacterParts and self.LocalCharacter:GetCharacterParts()
                        if char then
                            for _, obj in ipairs(parts or char:GetDescendants()) do
                                if obj:IsA("BasePart") then
                                    pcall(function()
                                        obj.CanTouch = true
                                        obj.CanQuery = true
                                    end)
                                end
                            end
                        end
                        task.wait(0.2)
                    end
                end)
            end
            return
        end

        self.Status = "Active: Touch Mask"

        for _, obj in ipairs(parts or character:GetDescendants()) do
            if obj:IsA("BasePart") then
                suppressPartSensors(obj)
            end
        end

        if rootPart then
            suppressPartSensors(rootPart)
        end
    end)
end

function KillPartBypass:Destroy()
    if self.Connection then
        self.Connection:Disconnect()
        self.Connection = nil
    end
end

return KillPartBypass
