--[[
    Normalize.lua - Bootstrap option normalization helpers
    Job: Keep startup normalization logic out of Core/Main.lua.
]]

local Normalize = {}

function Normalize.ToggleUIKeyCode(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value
    end

    if type(value) == "string" then
        local keyCode = Enum.KeyCode[value]
        if keyCode then
            return keyCode
        end
    end

    return Enum.KeyCode.RightControl
end

function Normalize.ToggleUIKey(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        return value.Name
    end

    if type(value) == "string" and Enum.KeyCode[value] then
        return value
    end

    return "RightControl"
end

function Normalize.TargetingMethod(value)
    if type(value) ~= "string" then
        return "FOV"
    end

    local normalized = string.lower(value)
    if normalized == "fov" then
        return "FOV"
    end
    if normalized == "distance" then
        return "Distance"
    end
    if normalized == "deadlock" then
        return "Deadlock"
    end

    return "FOV"
end

return Normalize
