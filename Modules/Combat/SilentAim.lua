--[[
    SilentAim.lua - High-Performance Neural Combat Hook
    Job: Safely redirect combat packets without interfering with user intent.
    Notes: Uses a singleton hook state to avoid stacking metamethod hooks on reload.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local SilentAim = {}
SilentAim.__index = SilentAim

local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_SILENT_AIM_HOOK"
local REDIRECT_WINDOW = 0.35
local clock = os.clock

local REMOTE_BLACKLIST = {
    "sprint", "speed", "walk", "jump", "action", "interact", "dialogue", "inventory", "tab",
    "shop", "trade", "quest", "mission", "chat", "menu", "equip", "unequip"
}

local function isCombatRemote(remote)
    local mName = tostring(remote):lower()
    for _, word in ipairs(REMOTE_BLACKLIST) do
        if mName:find(word) then return false end
    end
    return mName:find("shoot")
        or mName:find("fire")
        or mName:find("attack")
        or mName:find("hit")
        or mName:find("damage")
        or mName:find("impact")
end

local function isSpatialArg(value)
    local valueType = typeof(value)
    if valueType == "Vector3" or valueType == "CFrame" or valueType == "Ray" then
        return true
    end

    return valueType == "Instance" and (value:IsA("BasePart") or value:IsA("Model"))
end

local function hasSpatialPayload(args)
    for i = 1, args.n do
        if isSpatialArg(args[i]) then
            return true
        end
    end
    return false
end

local function isBossAggressiveRemote(selfRef, remote, args)
    local entry = selfRef and selfRef.CurrentTargetEntry
    if not (entry and entry.IsBoss) then
        return false
    end

    local remoteName = tostring(remote):lower()
    for _, word in ipairs(REMOTE_BLACKLIST) do
        if remoteName:find(word, 1, true) then
            return false
        end
    end

    return hasSpatialPayload(args)
end

local function buildTargetCFrame(targetPos)
    local camPos = Workspace.CurrentCamera.CFrame.Position
    return CFrame.lookAt(camPos, targetPos)
end

local function buildTargetRay(origin, targetPos, length)
    local direction = targetPos - origin
    if direction.Magnitude <= 0.001 then
        direction = Workspace.CurrentCamera.CFrame.LookVector
    else
        direction = direction.Unit * (length or (targetPos - origin).Magnitude)
    end
    return Ray.new(origin, direction)
end

local function ensureHookState()
    local hookState = getgenv()[GLOBAL_HOOK_KEY]
    if hookState then
        return hookState
    end

    local LocalPlayer = Players.LocalPlayer
    local Mouse = LocalPlayer:GetMouse()
    hookState = {
        Instance = nil,
    }

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(inst, index)
        local selfRef = hookState.Instance
        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef:_hasTargetLock()
            and selfRef:_isRedirectActive() then -- FIX: Only redirect mouse during firing window
            if inst == Mouse or (typeof(inst) == "Instance" and inst:IsA("Mouse")) then
                if index == "Hit" then
                    return buildTargetCFrame(selfRef.TargetPosCache)
                elseif index == "Target" then
                    return selfRef.TargetPartCache
                elseif index == "UnitRay" then
                    local camPos = Workspace.CurrentCamera.CFrame.Position
                    return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
                end
            end
        end

        return oldIndex(inst, index)
    end))

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local selfRef = hookState.Instance
        local method = getnamecallmethod()
        local args = table.pack(...)

        if selfRef
            and not selfRef._destroyed
            and not checkcaller()
            and selfRef:_hasTargetLock() then
            if selfRef:_isRedirectActive()
                and (method == "ViewportPointToRay" or method == "ScreenPointToRay")
                and inst == Workspace.CurrentCamera then
                local camPos = Workspace.CurrentCamera.CFrame.Position
                return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
            end

            if selfRef:_isRedirectActive() then
                if (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and inst == Workspace then
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        args[1] = buildTargetRay(ray.Origin, selfRef.TargetPosCache, ray.Direction.Magnitude)
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end

                if (method == "FireServer" or method == "InvokeServer")
                    and (isCombatRemote(inst) or isBossAggressiveRemote(selfRef, inst, args)) then
                    local modified = false
                    local maxRewrites = (selfRef.CurrentTargetEntry and selfRef.CurrentTargetEntry.IsBoss) and 3 or 1
                    local rewrites = 0

                    for i = 1, args.n do
                        if rewrites >= maxRewrites then
                            break
                        end

                        local arg = args[i]
                        if typeof(arg) == "Vector3" then
                            args[i] = selfRef.TargetPosCache
                            modified = true
                            rewrites = rewrites + 1
                        elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                            local localCharacter = LocalPlayer.Character
                            if not (localCharacter and arg:IsDescendantOf(localCharacter)) then
                                args[i] = selfRef.TargetPartCache
                                modified = true
                                rewrites = rewrites + 1
                            end
                        elseif typeof(arg) == "CFrame" then
                            args[i] = buildTargetCFrame(selfRef.TargetPosCache)
                            modified = true
                            rewrites = rewrites + 1
                        elseif typeof(arg) == "Ray" then
                            args[i] = buildTargetRay(arg.Origin, selfRef.TargetPosCache, arg.Direction.Magnitude)
                            modified = true
                            rewrites = rewrites + 1
                        end
                    end

                    if modified then
                        selfRef._lastRedirectTime = clock()
                        
                        -- Optional Packet Duplication / Multiplexing (Boost DPS)
                        local mult = tonumber(selfRef.Options and selfRef.Options.PacketDuplicationMultiplier) or 1
                        if mult > 1 then
                            local packedArgs = table.pack(unpack(args, 1, args.n))
                            for _ = 2, math.min(mult, 4) do
                                task.defer(function()
                                    if inst and inst.Parent then
                                        oldNamecall(inst, unpack(packedArgs, 1, packedArgs.n))
                                    end
                                end)
                            end
                        end
                        
                        return oldNamecall(inst, unpack(args, 1, args.n))
                    end
                end
            end
        end

        return oldNamecall(inst, unpack(args, 1, args.n))
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function SilentAim.new(config, synapse, resolver)
    local self = setmetatable({}, SilentAim)
    self.Options = config.Options
    self.Synapse = synapse
    self.Resolver = resolver

    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._lastRedirectTime = 0
    self._destroyed = false
    self._hookState = nil
    return self
end

function SilentAim:_hasTargetLock()
    return self.Active and self.TargetPosCache ~= nil and self.TargetPartCache ~= nil
end

function SilentAim:_isRedirectActive()
    if not self:_hasTargetLock() then
        return false
    end

    local now = clock()
    return (now - self._lastClickTime) <= REDIRECT_WINDOW
        or (now - self._lastRedirectTime) <= REDIRECT_WINDOW
end

function SilentAim:Init()
    if not hookmetamethod then
        return
    end

    self._destroyed = false
    self._hookState = ensureHookState()
    self._hookState.Instance = self
end

function SilentAim:NotifyShot(now, entry)
    self._lastClickTime = now or clock()
    if not (self.Active and entry) then
        return
    end
    local LocalPlayer = Players.LocalPlayer
    local character = LocalPlayer.Character
    local muzzlePosition = (character and character:GetPivot().Position) or Vector3.zero
    self.Synapse.fire("ShotFired", entry.Model, self._lastClickTime, muzzlePosition)
end

function SilentAim:SetState(active, targetPart, targetPos, currentEntry, dt)
    self.Active = active
    self.TargetPartCache = targetPart
    
    local resolvedPos = active and self.Resolver and self.Resolver.Resolve and self.Resolver:Resolve(targetPart, targetPos, currentEntry) or targetPos
    
    -- Multi-Point Hitbox: Adjust resolved point to nearest surface point if part is large (e.g., Boss)
    if active and targetPart and self.Options and self.Options.MultiPointHitbox ~= false then
        local size = targetPart.Size
        if size.X > 6 or size.Y > 6 or size.Z > 6 then
            local camPos = Workspace.CurrentCamera.CFrame.Position
            local cf = targetPart.CFrame
            local localCam = cf:PointToObjectSpace(camPos)
            local half = size * 0.45 -- 45% inner boundary for safe collision
            local clampedLocal = Vector3.new(
                math.clamp(localCam.X, -half.X, half.X),
                math.clamp(localCam.Y, -half.Y, half.Y),
                math.clamp(localCam.Z, -half.Z, half.Z)
            )
            local surfaceWorld = cf:PointToWorldSpace(clampedLocal)
            -- Shift resolved prediction towards nearest surface point
            resolvedPos = resolvedPos + (surfaceWorld - targetPart.Position)
        end
    end
    
    self.TargetPosCache = resolvedPos
    self.CurrentTargetEntry = currentEntry
end

function SilentAim:Clear()
    if not self.Active
        and self.TargetPartCache == nil
        and self.TargetPosCache == nil
        and self.CurrentTargetEntry == nil then
        return
    end

    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._lastRedirectTime = 0
end

function SilentAim:Destroy()
    self._destroyed = true
    self:Clear()

    if self._hookState and self._hookState.Instance == self then
        self._hookState.Instance = nil
    end

end

return SilentAim
