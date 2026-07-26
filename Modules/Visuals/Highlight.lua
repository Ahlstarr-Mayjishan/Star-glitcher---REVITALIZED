--[[
    TargetHighlight.lua - OOP Highlight Visualization Class
]]

local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local TargetHighlight = {}
TargetHighlight.__index = TargetHighlight

function TargetHighlight.new()
    local self = setmetatable({}, TargetHighlight)
    
    self.Instance = Instance.new("Highlight")
    self.Instance.FillColor = Color3.fromRGB(240, 60, 60)
    self.Instance.FillTransparency = 0.5
    self.Instance.OutlineColor = Color3.new(1, 1, 1)
    self.Instance.OutlineTransparency = 0
    self.Instance.Enabled = false
    self._adornee = nil
    self._enabled = false
    
    pcall(function() self.Instance.Parent = CoreGui end)
    if not self.Instance.Parent then
        self.Instance.Parent = Workspace.CurrentCamera
    end
    
    return self
end

function TargetHighlight:Set(part, enabled)
    if self._adornee == part and self._enabled == enabled then
        return
    end
    self._adornee = part
    self._enabled = enabled
    self.Instance.Adornee = part
    self.Instance.Enabled = enabled
end

function TargetHighlight:Clear()
    if not self._enabled and self._adornee == nil then
        return
    end
    self._adornee = nil
    self._enabled = false
    self.Instance.Adornee = nil
    self.Instance.Enabled = false
end

function TargetHighlight:Destroy()
    pcall(function() self.Instance:Destroy() end)
end

return TargetHighlight

