local AimActuator = {}
AimActuator.__index = AimActuator

function AimActuator.new(options, aimbot, silentAim)
    return setmetatable({
        Options = options,
        Aimbot = aimbot,
        SilentAim = silentAim,
    }, AimActuator)
end

function AimActuator:Apply(mode, state, dt)
    local solution = state.Solution
    if not solution then
        self:Rest()
        return
    end

    if mode == "Camera Lock" then
        self.SilentAim:Clear()
        self.Aimbot:SetState(true)
        self.Aimbot:Update(solution.AimPosition, self.Options.Smoothness, dt)
    elseif mode == "Silent Aim" then
        self.Aimbot:SetState(false)
        self.SilentAim:SetState(
            true,
            state.Part,
            solution.RawPosition or solution.AimPosition,
            state.Entry,
            dt
        )
    else
        self:Rest()
    end
end

function AimActuator:NotifyShot(now, entry)
    if self.SilentAim.NotifyShot then
        self.SilentAim:NotifyShot(now, entry)
    end
end

function AimActuator:Rest()
    self.Aimbot:SetState(false)
    self.SilentAim:Clear()
end

function AimActuator:Destroy()
    self:Rest()
end

return AimActuator
