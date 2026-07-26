--[[
    FeedbackLoop.lua - Closed-Loop Hit Verification & Adaptive Lead Control
    Job: Track shot effectiveness against target health deltas and dynamically scale 
         the prediction lead multiplier to prevent overshoot on evasive targets.
]]

local FeedbackLoop = {}
FeedbackLoop.__index = FeedbackLoop

local clock = os.clock
local HEALTH_HINTS = { "Health", "HP", "HitPoints", "BossHealth", "EnemyHealth", "HealthValue" }
local DEFAULT_WINDOW = 1.0
local MIN_LEAD_SCALE = 0.25
local MAX_LEAD_SCALE = 1.0
local DECAY_RATE = 0.35 -- Speed of lead scale drop on consecutive misses
local RECOVERY_RATE = 0.5 -- Speed of recovery on hits

function FeedbackLoop.new(config)
    local self = setmetatable({}, FeedbackLoop)
    self.Config = config
    self.Options = (config and config.Options) or {}
    self._activeShots = {}
    self._targetFeedback = setmetatable({}, { __mode = "k" })
    self._lastCheck = 0
    return self
end

local function extractHealth(entry)
    if not entry then return nil end
    local humanoid = entry.Humanoid
    if humanoid and humanoid.Parent and humanoid.Health then
        return humanoid.Health
    end
    
    local model = entry.Model
    if model then
        local cached = entry.HealthObject
        if cached
            and cached.Parent
            and (cached:IsA("NumberValue") or cached:IsA("IntValue")) then
            return cached.Value
        end

        for _, name in ipairs(HEALTH_HINTS) do
            local val = model:FindFirstChild(name, true)
            if val and (val:IsA("NumberValue") or val:IsA("IntValue")) then
                entry.HealthObject = val
                return val.Value
            end
        end
    end
    return nil
end

function FeedbackLoop:GetState(entry)
    if not entry then return nil end
    local state = self._targetFeedback[entry]
    if not state then
        state = {
            LeadScale = 1.0,
            ConsecutiveMisses = 0,
            TotalShots = 0,
            HitCount = 0,
            LastHealth = extractHealth(entry) or 0,
            LastShotTime = 0,
        }
        self._targetFeedback[entry] = state
    end
    return state
end

function FeedbackLoop:RegisterShot(entry, targetPos)
    if not entry then return end
    local state = self:GetState(entry)
    local currentHp = extractHealth(entry) or state.LastHealth
    
    table.insert(self._activeShots, {
        Entry = entry,
        ShotTime = clock(),
        StartHp = currentHp,
        TargetPos = targetPos,
        Evaluated = false,
    })
    
    state.TotalShots = state.TotalShots + 1
    state.LastShotTime = clock()
    state.LastHealth = currentHp
end

function FeedbackLoop:Update(dt)
    local now = clock()
    if now - self._lastCheck < 0.05 then return end
    self._lastCheck = now

    local i = #self._activeShots
    while i >= 1 do
        local shot = self._activeShots[i]
        local entry = shot.Entry
        local state = entry and self._targetFeedback[entry]
        
        if not entry or not entry.Model or not entry.Model.Parent then
            table.remove(self._activeShots, i)
        else
            local currentHp = extractHealth(entry) or (state and state.LastHealth) or 0
            local elapsed = now - shot.ShotTime

            if currentHp < (shot.StartHp - 0.5) then
                -- Hit confirmed!
                if state then
                    state.HitCount = state.HitCount + 1
                    state.ConsecutiveMisses = 0
                    state.LeadScale = math.min(MAX_LEAD_SCALE, state.LeadScale + RECOVERY_RATE)
                    state.LastHealth = currentHp
                end
                table.remove(self._activeShots, i)
            elseif elapsed >= DEFAULT_WINDOW then
                -- Window expired with no health loss -> Miss
                if state then
                    state.ConsecutiveMisses = state.ConsecutiveMisses + 1
                    state.LeadScale = math.max(MIN_LEAD_SCALE, state.LeadScale - DECAY_RATE)
                end
                table.remove(self._activeShots, i)
            end
        end
        i = i - 1
    end
end

function FeedbackLoop:GetLeadScaleFactor(entry)
    if not entry then return 1.0 end
    local state = self._targetFeedback[entry]
    if not state then return 1.0 end
    return state.LeadScale
end

function FeedbackLoop:Reset(entry)
    if entry then
        self._targetFeedback[entry] = nil
    else
        table.clear(self._activeShots)
        table.clear(self._targetFeedback)
    end
end

return FeedbackLoop
