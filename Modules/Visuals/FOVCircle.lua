--[[
    FOVCircle.lua - OOP FOV Visualization Class
]]

local UserInputService = game:GetService("UserInputService")

local FOVCircle = {}
FOVCircle.__index = FOVCircle

function FOVCircle.new(options)
    local self = setmetatable({}, FOVCircle)
    self.Options = options
    self._visible = false
    self._radius = options.FOV or 150
    self._x = nil
    self._y = nil

    self.Drawing = Drawing.new("Circle")
    self.Drawing.Position = UserInputService:GetMouseLocation()
    self.Drawing.Radius = self._radius
    self.Drawing.Filled = false
    self.Drawing.Color = Color3.fromRGB(255, 255, 255)
    self.Drawing.Visible = false
    self.Drawing.Thickness = 1.5

    return self
end

function FOVCircle:_shouldShow()
    local method = tostring(self.Options.TargetingMethod or "FOV")
    return self.Options.ShowFOV == true and method ~= "Distance" and method ~= "Deadlock"
end

function FOVCircle:Update(mousePos)
    if self:_shouldShow() then
        if self._x ~= mousePos.X or self._y ~= mousePos.Y then
            self.Drawing.Position = mousePos
            self._x = mousePos.X
            self._y = mousePos.Y
        end
        if not self._visible then
            self.Drawing.Visible = true
            self._visible = true
        end
        if self._radius ~= self.Options.FOV then
            self.Drawing.Radius = self.Options.FOV
            self._radius = self.Options.FOV
        end
    elseif self._visible then
        self.Drawing.Visible = false
        self._visible = false
    end
end

function FOVCircle:Destroy()
    pcall(function()
        self.Drawing:Remove()
    end)
end

return FOVCircle
