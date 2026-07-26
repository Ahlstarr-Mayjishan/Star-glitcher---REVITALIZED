local Workspace = game:GetService("Workspace")

local Aimbot = {}
Aimbot.__index = Aimbot

function Aimbot.new(config, aimMath)
    local self = setmetatable({}, Aimbot)
    self.Config = config
    self.Options = config.Options
    self.AimMath = aimMath
    self.Active = false
    return self
end

function Aimbot:Init()
    self.Active = false
end

function Aimbot:Update(targetPosition, smoothness, dt)
    if not targetPosition then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local baseAlpha = math.clamp(smoothness or self.Options.Smoothness or 0.15, 0.01, 1)
    local alphaForFrame = self.AimMath.FrameRateIndependentAlpha(baseAlpha, dt, 60)
    local targetCFrame = CFrame.lookAt(camera.CFrame.Position, targetPosition)

    if targetPosition.X == targetPosition.X then
        local angleDot = math.clamp(camera.CFrame.LookVector:Dot(targetCFrame.LookVector), -1, 1)
        local angle = math.acos(angleDot)
        local angleBoost = math.clamp(angle / math.rad(15), 0, 1) * 0.45
        local boostedAlpha = math.clamp(baseAlpha + angleBoost, baseAlpha, 0.95)
        local boostRatio = boostedAlpha / math.max(baseAlpha, 0.0001)
        local alpha = math.clamp(alphaForFrame * boostRatio, alphaForFrame, 0.95)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
    end
end

function Aimbot:SetState(active)
    self.Active = active
end

function Aimbot:Destroy()
    self.Active = false
end

return Aimbot
