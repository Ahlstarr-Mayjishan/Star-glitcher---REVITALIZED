--[[
    InputHandler.lua - OOP User Interaction Class
    Handles mouseholding and assist availability checks.
]]

local UserInputService = game:GetService("UserInputService")

local InputHandler = {}
InputHandler.__index = InputHandler

function InputHandler.new(config)
    local self = setmetatable({}, InputHandler)
    self.Options = config.Options
    self.Holding = false
    self._lastShot = 0
    self._shotCallback = nil
    self._connections = {}
    return self
end

function InputHandler:Init()
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Holding = true
        end
    end))
    
    table.insert(self._connections, UserInputService.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            self.Holding = false
        end
    end))
    
    -- Hitmarker tracking (Register a shot)
    table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self._lastShot = os.clock()
            if self._shotCallback then
                self._shotCallback(self._lastShot)
            end
        end
    end))
end

function InputHandler:SetShotCallback(callback)
    self._shotCallback = callback
end

function InputHandler:ShouldAssist()
    if self.Options.HoldMouse2ToAssist then
        return self.Holding
    end
    return true -- Mode is always active otherwise
end

function InputHandler:WasShotRecently(seconds)
    return (os.clock() - self._lastShot) < (seconds or 1.5)
end

function InputHandler:Destroy()
    self._shotCallback = nil
    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return InputHandler
