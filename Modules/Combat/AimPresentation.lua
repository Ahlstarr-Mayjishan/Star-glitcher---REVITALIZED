local AimPresentation = {}
AimPresentation.__index = AimPresentation

function AimPresentation.new(options, visuals)
    return setmetatable({
        Options = options,
        FOV = visuals.fov,
        Highlight = visuals.highlight,
        Dot = visuals.dot,
        Technique = visuals.technique,
    }, AimPresentation)
end

function AimPresentation:UpdateFOV(mousePosition, shouldTrack)
    if self.Options.ShowFOV or self.Options.ShowTargetDot or shouldTrack then
        self.FOV:Update(mousePosition)
    end
end

function AimPresentation:Show(state, camera)
    local solution = state.Solution
    if not solution or not state.Part then
        self:Clear()
        return
    end

    if self.Technique then
        self.Technique:Update(solution.Technique, state.Entry)
    end

    local screenPosition, onScreen = camera:WorldToViewportPoint(solution.AimPosition)
    if onScreen then
        self.Dot:Set(screenPosition, true)
        self.Highlight:Set(state.Part, true)
    else
        self:Clear()
    end
end

function AimPresentation:Clear()
    self.Highlight:Clear()
    self.Dot:Set(nil, false)
    if self.Technique then
        self.Technique:Clear()
    end
end

function AimPresentation:Destroy()
    self:Clear()
end

return AimPresentation
