--[[
    RayfieldUI.lua - Bootstrap UI helper for Rayfield startup
    Job: Create the main window, discover Rayfield ScreenGuis, and load config safely.
]]

local Players = game:GetService("Players")

local RayfieldUI = {}

function RayfieldUI.CreateWindow(rayfield)
    return rayfield:CreateWindow({
        Name = "STAR GLITCHER ~ REVITALIZED",
        LoadingTitle = "Neural Interface Initializing...",
        LoadingSubtitle = "Scientific Neural Network Active",
        ConfigurationSaving = { Enabled = true, FolderName = "Boss_AimAssist", FileName = "Config" },
        Discord = { Enabled = false },
        KeySystem = false,
    })
end

function RayfieldUI.IsRayfieldScreenGui(screenGui)
    if not screenGui or not screenGui:IsA("ScreenGui") then
        return false
    end

    local guiName = string.lower(screenGui.Name)
    if guiName:find("rayfield", 1, true) or guiName:find("sirius", 1, true) then
        return true
    end

    for _, descendant in ipairs(screenGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = descendant.Text
            if text == "STAR GLITCHER ~ REVITALIZED" or text == "Neural Interface Initializing..." then
                return true
            end
        end
    end

    return false
end

function RayfieldUI.GetScreenGuis(coreGui)
    local matches = {}
    local seen = {}
    local containers = { coreGui }

    local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        table.insert(containers, playerGui)
    end

    for _, container in ipairs(containers) do
        for _, descendant in ipairs(container:GetDescendants()) do
            if descendant:IsA("ScreenGui") and not seen[descendant] and RayfieldUI.IsRayfieldScreenGui(descendant) then
                seen[descendant] = true
                matches[#matches + 1] = descendant
            end
        end
    end

    return matches
end

function RayfieldUI.SafeLoadConfiguration(rayfield)
    local ok, err = pcall(function()
        if rayfield and rayfield.LoadConfiguration then
            rayfield:LoadConfiguration()
        end
    end)

    return ok, err
end

return RayfieldUI
