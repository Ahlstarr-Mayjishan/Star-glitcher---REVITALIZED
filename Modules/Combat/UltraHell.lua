local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local UltraHell = {}
UltraHell.__index = UltraHell

local MIN_HITS_PER_SECOND = 1
local MAX_HITS_PER_SECOND = 100
local EXCLUDE_KEYWORDS = { "chat", "move", "walk", "jump", "anim", "inventory", "sprint" }
local COMBAT_KEYWORDS = {
    "hit", "damage", "attack", "punch", "slash", "shoot", "fire",
    "impact", "ability", "skill", "weapon", "tool",
}

local function isCombatRemote(remote, args)
    local name = tostring(remote):lower()
    for _, word in ipairs(EXCLUDE_KEYWORDS) do
        if string.find(name, word, 1, true) then
            return false
        end
    end

    for _, word in ipairs(COMBAT_KEYWORDS) do
        if string.find(name, word, 1, true) then
            return true
        end
    end

    for index = 1, args.n do
        local arg = args[index]
        if typeof(arg) == "Instance" and arg:IsA("Model") and arg ~= LocalPlayer.Character then
            return true
        end
    end

    return false
end

local function getSharedState()
    local env = getgenv and getgenv()
    if not env then
        return nil
    end

    env.__STAR_GLITCHER_ULTRAHELL = env.__STAR_GLITCHER_ULTRAHELL or {
        Hooked = false,
        CapturedRemote = nil,
        CapturedArgs = nil,
        CapturedName = nil,
        LastCaptureClock = 0,
        ActiveInstance = nil,
    }

    return env.__STAR_GLITCHER_ULTRAHELL
end

function UltraHell.new(options)
    local self = setmetatable({}, UltraHell)
    self.Options = options
    self.SharedState = getSharedState()
    self.Status = "Waiting For Damage"
    self._heartbeatConnection = nil
    self._tokenBucket = 0
    self._statusAccumulator = 0
    return self
end

function UltraHell:_updateStatus()
    local shared = self.SharedState
    local capturedName = shared and shared.CapturedName
    if not capturedName then
        self.Status = "Hit an enemy once to arm capture"
        return
    end

    if self.Options.UltraHellEnabled then
        local rate = math.clamp(tonumber(self.Options.UltraHellHitsPerSecond) or 10, MIN_HITS_PER_SECOND, MAX_HITS_PER_SECOND)
        self.Status = string.format("Captured: %s | %d hits/s", tostring(capturedName), rate)
        return
    end

    self.Status = "Captured: " .. tostring(capturedName) .. " | Ready"
end

function UltraHell:_installHook()
    local shared = self.SharedState
    if not shared or shared.Hooked then
        return
    end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(target, ...)
        local method = getnamecallmethod()
        local args = table.pack(...)

        if not checkcaller() and (method == "FireServer" or method == "InvokeServer") and isCombatRemote(target, args) then
            shared.CapturedRemote = target
            shared.CapturedArgs = args
            shared.CapturedName = target.Name
            shared.LastCaptureClock = os.clock()

            local active = shared.ActiveInstance
            if active then
                active:_updateStatus()
            end
        end

        return oldNamecall(target, ...)
    end))

    shared.Hooked = true
end

function UltraHell:_fireCapturedRemote()
    local shared = self.SharedState
    if not shared then
        return
    end

    local remote = shared.CapturedRemote
    local args = shared.CapturedArgs
    if not remote or not args then
        self.Options.UltraHellEnabled = false
        self:_updateStatus()
        return
    end

    if remote.ClassName == "RemoteEvent" then
        remote:FireServer(table.unpack(args, 1, args.n))
    elseif remote.ClassName == "RemoteFunction" then
        task.spawn(function()
            remote:InvokeServer(table.unpack(args, 1, args.n))
        end)
    end
end

function UltraHell:Init()
    if self.SharedState then
        self.SharedState.ActiveInstance = self
    end

    self:_installHook()
    self:_updateStatus()

    if self._heartbeatConnection then
        self._heartbeatConnection:Disconnect()
    end

    self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
        self._statusAccumulator = self._statusAccumulator + dt
        if self._statusAccumulator >= 0.25 then
            self._statusAccumulator = 0
            self:_updateStatus()
        end
        if not self.Options.UltraHellEnabled then
            self._tokenBucket = 0
            return
        end

        if not (self.SharedState and self.SharedState.CapturedRemote and self.SharedState.CapturedArgs) then
            return
        end

        local rate = math.clamp(tonumber(self.Options.UltraHellHitsPerSecond) or 10, MIN_HITS_PER_SECOND, MAX_HITS_PER_SECOND)
        self._tokenBucket = math.min(self._tokenBucket + (rate * dt), rate)

        while self._tokenBucket >= 1 do
            self._tokenBucket = self._tokenBucket - 1
            self:_fireCapturedRemote()
        end
    end)
end

function UltraHell:Destroy()
    if self.SharedState and self.SharedState.ActiveInstance == self then
        self.SharedState.ActiveInstance = nil
    end

    if self._heartbeatConnection then
        self._heartbeatConnection:Disconnect()
        self._heartbeatConnection = nil
    end
end

return UltraHell
