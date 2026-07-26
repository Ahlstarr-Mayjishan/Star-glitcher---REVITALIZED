local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local POLL_INTERVAL = 0.5

local RejoinOnKick = {}
RejoinOnKick.__index = RejoinOnKick

function RejoinOnKick.new(options, entryUrl)
    local self = setmetatable({}, RejoinOnKick)
    self.Options = options
    self.EntryUrl = entryUrl
    self.Status = "Idle"
    self._connections = {}
    self._alive = false
    self._rejoinAttemptInProgress = false
    self._lastKickLikeMessage = nil
    return self
end

local function isKickLikeMessage(message)
    local text = string.lower(tostring(message or ""))
    if text == "" then
        return false
    end

    return text:find("kick", 1, true) ~= nil
        or text:find("kicked", 1, true) ~= nil
        or text:find("banned", 1, true) ~= nil
        or text:find("disconnected", 1, true) ~= nil
        or text:find("connection error", 1, true) ~= nil
        or text:find("same account launched", 1, true) ~= nil
end

function RejoinOnKick:_queueReload()
    local queueTeleport = queue_on_teleport or queueonteleport
    if not queueTeleport or not self.EntryUrl then
        return
    end

    local command = string.format(
        "loadstring(game:HttpGet(%q .. \"?v=\" .. tostring(os.time())))()",
        self.EntryUrl
    )
    pcall(queueTeleport, command)
end

function RejoinOnKick:_scanPromptGui()
    local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
    if not promptGui then
        return nil
    end

    for _, descendant in ipairs(promptGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = descendant.Text
            if isKickLikeMessage(text) then
                return text
            end
        end
    end

    return nil
end

function RejoinOnKick:_captureMessage()
    local guiMessage = GuiService:GetErrorMessage()
    if isKickLikeMessage(guiMessage) then
        return guiMessage
    end

    return self:_scanPromptGui()
end

function RejoinOnKick:_attemptRejoin(message)
    if self.Options.RejoinOnKickEnabled ~= true or self._rejoinAttemptInProgress then
        return
    end

    local player = Players.LocalPlayer
    if not player then
        return
    end

    self._rejoinAttemptInProgress = true
    self.Status = "Rejoining"
    self:_queueReload()

    task.spawn(function()
        task.wait(1.5)

        local teleported = false
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
            teleported = true
        end)

        if not ok or not teleported then
            warn("[KickRejoin] Teleport failed, trying same instance | Error: " .. tostring(err))
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end)
        end

        task.delay(5, function()
            self._rejoinAttemptInProgress = false
            self.Status = self.Options.RejoinOnKickEnabled and "Armed" or "Disabled"
        end)
    end)
end

function RejoinOnKick:_observe(message)
    if not isKickLikeMessage(message) or message == self._lastKickLikeMessage then
        return
    end

    self._lastKickLikeMessage = message
    self:_attemptRejoin(message)
end

function RejoinOnKick:Init()
    if self._alive then
        return
    end

    self._alive = true
    self.Status = self.Options.RejoinOnKickEnabled and "Armed" or "Disabled"

    self._connections[#self._connections + 1] = GuiService.ErrorMessageChanged:Connect(function()
        self:_observe(GuiService:GetErrorMessage())
    end)

    task.spawn(function()
        while self._alive do
            task.wait(POLL_INTERVAL)
            local message = self:_captureMessage()
            if message then
                self:_observe(message)
            elseif self.Options.RejoinOnKickEnabled == true and not self._rejoinAttemptInProgress then
                self.Status = "Armed"
            elseif self.Options.RejoinOnKickEnabled ~= true then
                self.Status = "Disabled"
            end
        end
    end)
end

function RejoinOnKick:Destroy()
    self._alive = false
    self._rejoinAttemptInProgress = false
    self._lastKickLikeMessage = nil

    for _, connection in ipairs(self._connections) do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return RejoinOnKick
