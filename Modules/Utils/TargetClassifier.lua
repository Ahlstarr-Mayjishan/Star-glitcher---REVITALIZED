local TargetClassifier = {}

function TargetClassifier.ClassifyCombatEvidence(evidence)
    if not evidence or evidence.IsAlive == false then
        return false
    end

    if evidence.IsAnchored and not evidence.ExplicitCombatMarker then
        if evidence.HasHumanoid then
            return evidence.IsBoss == true
                and evidence.MaxHealth ~= nil
                and evidence.MaxHealth > 500
        end
        return evidence.IsBoss == true
            and evidence.Health ~= nil
            and evidence.Health > 0
    end

    if evidence.HasHumanoid then
        return true
    end

    if evidence.ExplicitCombatMarker or evidence.StrongCombatFolder then
        return true
    end

    return evidence.IsBoss == true
        and evidence.Health ~= nil
        and evidence.Health > 0
end

return TargetClassifier
