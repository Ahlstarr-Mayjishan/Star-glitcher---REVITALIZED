local AimState = {}
AimState.__index = AimState

function AimState.new()
    return setmetatable({
        Entry = nil,
        Part = nil,
        Solution = nil,
        Generation = 0,
    }, AimState)
end

function AimState:SetTarget(entry)
    if self.Entry == entry then
        return false
    end
    self.Entry = entry
    self.Part = nil
    self.Solution = nil
    self.Generation = self.Generation + 1
    return true
end

function AimState:SetPart(part)
    if self.Part == part then
        return false
    end
    self.Part = part
    self.Solution = nil
    self.Generation = self.Generation + 1
    return true
end

function AimState:SetSolution(solution)
    self.Solution = solution
end

function AimState:Clear()
    return self:SetTarget(nil)
end

return AimState
