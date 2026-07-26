--[[
    StatusLoop.lua - Player tab active status refresh loop
]]

local StatusLoop = {}

function StatusLoop.Start(refs, deps, labelUtils)
    local handle = {
        Alive = true,
    }

    task.spawn(function()
        local lastSlowdownText
        local lastStunText
        local lastSpeedText
        local lastJumpText
        local lastFloatText
        local lastGravityText
        local lastNoclipText
        local lastGodText

        while handle.Alive do
            if deps.noSlowdown then
                local nextText = "Slowdown Status: " .. tostring(deps.noSlowdown.Status)
                if nextText ~= lastSlowdownText then
                    labelUtils.SetText(refs.slowdownLabel, nextText)
                    lastSlowdownText = nextText
                end
            end

            if deps.noStun then
                local nextText = "Stun Status: " .. tostring(deps.noStun.Status)
                if nextText ~= lastStunText then
                    labelUtils.SetText(refs.stunLabel, nextText)
                    lastStunText = nextText
                end
            end

            if deps.speedMultiplier then
                local nextText = "Multi Speed Status: " .. tostring(deps.speedMultiplier.Status)
                if nextText ~= lastSpeedText then
                    labelUtils.SetText(refs.speedMultiplierLabel, nextText)
                    lastSpeedText = nextText
                end
            end

            if deps.jumpBoost then
                local nextText = "Jump Boost Status: " .. tostring(deps.jumpBoost.Status)
                if nextText ~= lastJumpText then
                    labelUtils.SetText(refs.jumpBoostLabel, nextText)
                    lastJumpText = nextText
                end
            end

            if deps.floatController then
                local nextText = "Float Status: " .. tostring(deps.floatController.Status)
                if nextText ~= lastFloatText then
                    labelUtils.SetText(refs.floatLabel, nextText)
                    lastFloatText = nextText
                end
            end

            if deps.gravityController then
                local nextText = "Gravity Status: " .. tostring(deps.gravityController.Status)
                if nextText ~= lastGravityText then
                    labelUtils.SetText(refs.gravityLabel, nextText)
                    lastGravityText = nextText
                end
            end

            if deps.noclip then
                local nextText = "Noclip Status: " .. tostring(deps.noclip.Status)
                if nextText ~= lastNoclipText then
                    labelUtils.SetText(refs.noclipLabel, nextText)
                    lastNoclipText = nextText
                end
            end

            task.wait(0.5)
        end
    end)

    function handle:Destroy()
        self.Alive = false
    end

    return handle
end

return StatusLoop
