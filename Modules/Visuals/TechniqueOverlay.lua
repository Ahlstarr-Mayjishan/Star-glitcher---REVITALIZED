local TechniqueOverlay = {}
TechniqueOverlay.__index = TechniqueOverlay

function TechniqueOverlay.new(options)
    local self = setmetatable({}, TechniqueOverlay)
    self.Options = options
    self.Drawing = Drawing.new("Text")
    self.Drawing.Visible = false
    self.Drawing.Size = 16
    self.Drawing.Color = Color3.fromRGB(255, 236, 236)
    self.Drawing.Outline = true
    self.Drawing.Center = false
    self.Drawing.Font = 2
    return self
end

function TechniqueOverlay:Update(decision, entry)
    if not self.Options.PredictionTechniqueDebug then
        self.Drawing.Visible = false
        return
    end

    if not decision then
        self.Drawing.Visible = false
        return
    end

    local technique = tostring(decision.Technique or "Unknown")
    local reason = tostring(decision.Reason or "n/a")
    local confidence = math.floor(((decision.Confidence or 0) * 100) + 0.5)
    local targetName = entry and entry.Name or "No target"

    self.Drawing.Position = Vector2.new(18, 160)
    self.Drawing.Text = string.format(
        "Technique: %s\nTarget: %s\nConfidence: %d%%\nReason: %s",
        technique,
        targetName,
        confidence,
        reason
    )
    self.Drawing.Visible = true
end

function TechniqueOverlay:Clear()
    self.Drawing.Visible = false
end

function TechniqueOverlay:Destroy()
    pcall(function()
        self.Drawing:Remove()
    end)
end

return TechniqueOverlay
