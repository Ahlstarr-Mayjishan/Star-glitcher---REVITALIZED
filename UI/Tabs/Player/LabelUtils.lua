--[[
    LabelUtils.lua - Shared label helpers for Player tab UI
]]

local LabelUtils = {}

function LabelUtils.SetText(label, text)
    if not label then
        return
    end

    if type(label) == "table" and type(label.Set) == "function" then
        local ok = pcall(function()
            label:Set(text)
        end)
        if ok then
            return
        end
    end

    if typeof(label) == "Instance" then
        local textLabel = label:IsA("TextLabel") and label or label:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then
            textLabel.Text = text
        end
    end
end

return LabelUtils
