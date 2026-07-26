--!strict

-- Native Status layout:
-- Character.Status.SafeZoned / Team
-- Character.Status.Attributes.<calculated status value>

local NativeStatus = {}

local function getContainers(character)
    local containers = {}
    local status = character and character:FindFirstChild("Status")
    if status then
        containers[#containers + 1] = status
        local attributes = status:FindFirstChild("Attributes")
        if attributes then
            containers[#containers + 1] = attributes
        end
    end
    return containers
end

function NativeStatus.Read(character, name)
    for _, container in ipairs(getContainers(character)) do
        local valueObject = container:FindFirstChild(name)
        if valueObject and valueObject:IsA("ValueBase") then
            return valueObject.Value
        end
    end
    return nil
end

function NativeStatus.ClearBooleanFlags(character, names)
    local changed = 0
    for _, container in ipairs(getContainers(character)) do
        for name in pairs(names) do
            local valueObject = container:FindFirstChild(name)
            if valueObject and valueObject:IsA("BoolValue") and valueObject.Value then
                local ok = pcall(function()
                    valueObject.Value = false
                end)
                if ok then
                    changed = changed + 1
                end
            end
        end
    end
    return changed
end

return NativeStatus
