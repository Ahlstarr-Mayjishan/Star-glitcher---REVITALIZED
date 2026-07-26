--!strict

--[[
    SilentAim.lua - High-Performance Neural Combat Hook
    Job: Safely redirect combat packets without interfering with user intent.
    Notes: Uses a singleton hook state to avoid stacking metamethod hooks on reload.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local SilentAim = {}
SilentAim.__index = SilentAim

-- Bump this key when hook closure behavior changes. Executor metamethod hooks
-- cannot be removed, so a new key is required for an in-session loader update.
local GLOBAL_HOOK_KEY = "__STAR_GLITCHER_SILENT_AIM_HOOK_V3"
local REDIRECT_WINDOW = 0.35
local clock = os.clock

local function buildTargetCFrame(targetPos)
    local camera = Workspace.CurrentCamera
    if not camera then
        return CFrame.new(targetPos)
    end
    return CFrame.lookAt(camera.CFrame.Position, targetPos)
end

local function buildTargetRay(origin, targetPos, length)
    local direction = targetPos - origin
    if direction.Magnitude <= 0.001 then
        local camera = Workspace.CurrentCamera
        direction = camera and camera.CFrame.LookVector or Vector3.zAxis
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
            and selfRef:_hasTargetLock()
            and not checkcaller()
            and selfRef:_shouldRedirectAimSource() then
            if inst == Mouse or (typeof(inst) == "Instance" and inst:IsA("Mouse")) then
                if index == "Hit" then
                    return buildTargetCFrame(selfRef.TargetPosCache)
                elseif index == "Target" then
                    return selfRef.TargetPartCache
                elseif index == "UnitRay" then
                    local camera = Workspace.CurrentCamera
                    if not camera then
                        return oldIndex(inst, index)
                    end
                    local camPos = camera.CFrame.Position
                    return buildTargetRay(camPos, selfRef.TargetPosCache, 1)
                end
            end
        end

        return oldIndex(inst, index)
    end))

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(inst, ...)
        local selfRef = hookState.Instance
        if not selfRef
            or selfRef._destroyed
            or not selfRef:_hasTargetLock()
            or checkcaller() then
            return oldNamecall(inst, ...)
        end

        local method = getnamecallmethod()
        if selfRef:_shouldRedirectAimSource()
            and (method == "ViewportPointToRay" or method == "ScreenPointToRay")
            and inst == Workspace.CurrentCamera then
            local camera = Workspace.CurrentCamera
            if camera then
                return buildTargetRay(camera.CFrame.Position, selfRef.TargetPosCache, 1)
            end
            return oldNamecall(inst, ...)
        end

        if not selfRef:_isRedirectActive() then
            return oldNamecall(inst, ...)
        end

        if (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist")
            and inst == Workspace then
            local args = table.pack(...)
            local ray = args[1]
            if typeof(ray) == "Ray" then
                args[1] = buildTargetRay(ray.Origin, selfRef.TargetPosCache, ray.Direction.Magnitude)
                return oldNamecall(inst, unpack(args, 1, args.n))
            end
            return oldNamecall(inst, ...)
        end

        if (method == "FireServer" or method == "InvokeServer")
            and selfRef.Policy
            and selfRef.Policy.IsCombatRemoteName
            and selfRef.Policy.IsCombatRemoteName(tostring(inst)) then
            local args = table.pack(...)
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
                return oldNamecall(inst, unpack(args, 1, args.n))
            end
        end

        return oldNamecall(inst, ...)
    end))

    getgenv()[GLOBAL_HOOK_KEY] = hookState
    return hookState
end

function SilentAim.new(config, synapse, resolver, policy)
    local self = setmetatable({}, SilentAim)
    self.Options = config.Options
    self.Synapse = synapse
    self.Resolver = resolver
    self.Policy = policy

    self.Active = false
    self.TargetPartCache = nil
    self.TargetPosCache = nil
    self.CurrentTargetEntry = nil
    self._lastClickTime = 0
    self._lastRedirectTime = 0
    self._destroyed = false
    self._hookState = nil
    self._hooksSupported = false
    return self
end

function SilentAim:_hasTargetLock()
    return self.Active
        and typeof(self.TargetPosCache) == "Vector3"
        and typeof(self.TargetPartCache) == "Instance"
        and self.TargetPartCache:IsA("BasePart")
        and self.TargetPartCache.Parent ~= nil
end

function SilentAim:_shouldRedirectAimSource()
    local hasTargetLock = self:_hasTargetLock()
    if self.Policy and self.Policy.ShouldRedirectAimSource then
        return self.Policy.ShouldRedirectAimSource(hasTargetLock)
    end
    return hasTargetLock
end

function SilentAim:_isRedirectActive()
    local now = clock()
    if self.Policy and self.Policy.ShouldRewriteSideEffect then
        return self.Policy.ShouldRewriteSideEffect(
            self:_hasTargetLock(),
            now - self._lastClickTime,
            now - self._lastRedirectTime,
            REDIRECT_WINDOW
        )
    end
    return self:_hasTargetLock()
        and ((now - self._lastClickTime) <= REDIRECT_WINDOW
            or (now - self._lastRedirectTime) <= REDIRECT_WINDOW)
end

function SilentAim:Init()
    self._hooksSupported = hookmetamethod
        and newcclosure
        and getnamecallmethod
        and checkcaller
        and getgenv
        and true
        or false
    if not self._hooksSupported then
        self.Status = "Unsupported executor hooks"
        return
    end

    self._destroyed = false
    self.Status = "Ready (lazy hook)"
end

function SilentAim:_ensureHooks()
    if self._hookState then
        return true
    end
    if not self._hooksSupported
        or not hookmetamethod
        or not newcclosure
        or not getnamecallmethod
        or not checkcaller
        or not getgenv then
        self.Status = "Unsupported executor hooks"
        return false
    end

    self._hookState = ensureHookState()
    self._hookState.Instance = self
    self.Status = "Hook ready"
    return true
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
    if not active
        or typeof(targetPart) ~= "Instance"
        or not targetPart:IsA("BasePart")
        or not targetPart.Parent
        or typeof(targetPos) ~= "Vector3" then
        self:Clear()
        return
    end

    if not self:_ensureHooks() then
        self:Clear()
        return
    end

    self.Active = active
    self.TargetPartCache = targetPart
    
    local resolvedPos = active and self.Resolver and self.Resolver.Resolve and self.Resolver:Resolve(targetPart, targetPos, currentEntry) or targetPos
    
    -- Multi-Point Hitbox: Adjust resolved point to nearest surface point if part is large (e.g., Boss)
    if self.Options and self.Options.MultiPointHitbox ~= false then
        local size = targetPart.Size
        if size.X > 6 or size.Y > 6 or size.Z > 6 then
            local camera = Workspace.CurrentCamera
            if not camera then
                self:Clear()
                return
            end
            local camPos = camera.CFrame.Position
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
