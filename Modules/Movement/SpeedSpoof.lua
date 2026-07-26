local SpeedSpoof = {}
SpeedSpoof.__index = SpeedSpoof

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

function SpeedSpoof.new(options, localCharacter)
    local self = setmetatable({}, SpeedSpoof)
    self.Options = options
    self.LocalCharacter = localCharacter
    self._isHooked = false
    return self
end

function SpeedSpoof:Init()
    if not hookmetamethod then
        return
    end

    local hookState = getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK
    if hookState then
        hookState.Options = self.Options
        hookState.LocalCharacter = self.LocalCharacter
        self._isHooked = true
        return
    end

    hookState = {
        Options = self.Options,
        LocalCharacter = self.LocalCharacter,
    }
    getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK = hookState

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(obj, index)
        local options = hookState.Options
        local localCharacter = hookState.LocalCharacter
        if not checkcaller()
            and typeof(obj) == "Instance"
            and obj:IsA("Humanoid")
            and localCharacter
            and localCharacter:IsLocalHumanoid(obj) then
            if options and options.SpeedSpoofEnabled then
                local realValue = oldIndex(obj, index)
                if type(realValue) ~= "number" then
                    return realValue
                end

                -- Let the game finish rebuilding sprint/state controllers after respawn.
                if localCharacter.IsRespawning and localCharacter:IsRespawning() then
                    return realValue
                end

                if index == "WalkSpeed" then
                    -- Preserve legitimate sprint or game-side boosts instead of forcing 16 forever.
                    if realValue > (DEFAULT_WALK_SPEED + 0.75) then
                        return realValue
                    end
                    return DEFAULT_WALK_SPEED
                end

                if index == "JumpPower" then
                    if realValue > (DEFAULT_JUMP_POWER + 1) then
                        return realValue
                    end
                    return DEFAULT_JUMP_POWER
                end
            end
        end
        return oldIndex(obj, index)
    end))

    self._isHooked = true
end

function SpeedSpoof:Destroy()
    local hookState = getgenv and getgenv().__STAR_GLITCHER_SPEED_SPOOF_HOOK
    if hookState and hookState.LocalCharacter == self.LocalCharacter then
        hookState.Options = nil
        hookState.LocalCharacter = nil
    end

    self._isHooked = false
    self.LocalCharacter = nil
end

return SpeedSpoof
