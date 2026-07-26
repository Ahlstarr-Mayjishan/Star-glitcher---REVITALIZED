local TargetClassifier = {}

function TargetClassifier.ShouldRejectStructuralName(evidence)
    if not evidence or evidence.AuthoritativeEntityFolder then
        return false
    end

    return evidence.HasBlacklistedName == true
        or evidence.HasDecorativeLineage == true
end

function TargetClassifier.ClassifyCombatEvidence(evidence)
    if not evidence or evidence.IsAlive == false then
        return false
    end

    -- Star Glitcher itself treats direct children of workspace.Entities as
    -- combat entities. Some summoned bosses (Cube included) are anchored,
    -- non-humanoid models with no replicated health value, so structural
    -- evidence from this authoritative container must win over heuristics.
    if evidence.AuthoritativeEntityFolder then
        return true
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
