local CharacterCleaner = {}
CharacterCleaner.__index = CharacterCleaner

function CharacterCleaner.new(options, localCharacter, nativeStatus)
    local self = setmetatable({}, CharacterCleaner)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.NativeStatus = nativeStatus
    return self
end

function CharacterCleaner:Clean()
    local character = self.LocalCharacter and self.LocalCharacter:GetCharacter()
    local humanoid = self.LocalCharacter and self.LocalCharacter:GetHumanoid()
    local root = self.LocalCharacter and self.LocalCharacter:GetRootPart()

    -- 1. Disable Toggles in Options
    self.Options.KillPartBypassEnabled = false
    self.Options.NoclipEnabled = false
    self.Options.CustomMoveSpeedEnabled = false
    self.Options.SpeedMultiplierEnabled = false
    self.Options.SpeedSpoofEnabled = false
    self.Options.GravityEnabled = false
    self.Options.FloatEnabled = false
    self.Options.JumpBoostEnabled = false
    self.Options.NoSlowdown = false
    self.Options.NoStun = false
    self.Options.NoDelay = false

    -- 2. Reset Humanoid Properties
    if humanoid then
        local nativeWalkSpeed = self.NativeStatus and tonumber(self.NativeStatus.Read(character, "WalkSpeed"))
        local nativeJumpPower = self.NativeStatus and tonumber(self.NativeStatus.Read(character, "JumpPower"))
        pcall(function()
            humanoid.WalkSpeed = nativeWalkSpeed or humanoid.WalkSpeed
            humanoid.JumpPower = nativeJumpPower or humanoid.JumpPower
            humanoid.AutoRotate = true
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end)
    end

    -- 4. Restore Interaction (CanTouch/CanQuery)
    if character then
        if root then
            pcall(function()
                root.CanTouch = true
                root.CanQuery = true
            end)
        end
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.CanTouch = true
                    obj.CanQuery = true
                end)
            end
        end
    end

    return true
end

return CharacterCleaner
