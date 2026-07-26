--[[
    TargetDot.lua - OOP Target Locking Dot Visualization Class
]]

local TargetDot = {}
TargetDot.__index = TargetDot

function TargetDot.new()
    local self = setmetatable({}, TargetDot)
    self._visible = false
    self._x = nil
    self._y = nil

    self.Drawing = Drawing.new("Circle")
    self.Drawing.Visible = false
    self.Drawing.Filled = true
    self.Drawing.Radius = 4
    self.Drawing.Color = Color3.fromRGB(240, 60, 60)
    self.Drawing.Thickness = 1

    return self
end

function TargetDot:Set(screenPos, visible)
    if visible and screenPos then
        if self._x ~= screenPos.X or self._y ~= screenPos.Y then
            self.Drawing.Position = Vector2.new(screenPos.X, screenPos.Y)
            self._x = screenPos.X
            self._y = screenPos.Y
        end
        if not self._visible then
            self.Drawing.Visible = true
            self._visible = true
        end
    elseif self._visible then
        self.Drawing.Visible = false
        self._visible = false
    end
end

function TargetDot:Destroy()
    pcall(function()
        self.Drawing:Remove()
    end)
end

return TargetDot
