param(
    [switch]$Graph
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    foreach ($command in @("luau", "luau-analyze", "selene")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Missing required debug tool: $command"
        }
    }

    $entrySource = Get-Content "Main.lua" -Raw
    if ($entrySource -notmatch [regex]::Escape("https://cdn.statically.io/gh/Ahlstarr-Mayjishan/Star-glitcher---REVITALIZED/main/")) {
        throw "Main loader is missing the fresh branch CDN fallback."
    }
    if ($entrySource -notmatch "selectManifest" -or $entrySource -notmatch "STABLE_RELEASE_REF") {
        throw "Main loader is missing release-coherent manifest selection."
    }

    $trackerSource = Get-Content "Modules/Utils/NPCTracker.lua" -Raw
    if ($trackerSource -notmatch "DescendantAdded" -or $trackerSource -notmatch "ClassifyAttribute") {
        throw "NPC tracker is missing event-driven summon invalidation."
    }
    if ($trackerSource -notmatch "_dirtyScanInterval" -or $trackerSource.Contains("DescendantAdded:Connect(function()")) {
        throw "NPC tracker is missing bounded, classified dirty scans."
    }

    $silentAimSource = Get-Content "Modules/Combat/SilentAim.lua" -Raw
    if ($silentAimSource -match "isBossAggressiveRemote" -or -not $silentAimSource.Contains('Ready (lazy hook)')) {
        throw "Silent aim still installs or applies an unsafe broad boss hook."
    }

    $invalidVectorMembers = & rg -n '\.(XZ|XY|YZ)\b' Modules -g '*.lua' -g '*.luau'
    if ($LASTEXITCODE -eq 0) {
        throw "Invalid Roblox Vector3 member detected:`n$invalidVectorMembers"
    }
    if ($LASTEXITCODE -ne 1) {
        throw "Failed to scan for invalid Vector3 members."
    }

    Get-ChildItem "Tests" -Filter "*.spec.luau" |
        Sort-Object Name |
        ForEach-Object {
            & luau $_.FullName
            if ($LASTEXITCODE -ne 0) {
                throw "Luau test failed: $($_.Name)"
            }
        }

    $aimFiles = @(
        "Modules/Combat/AimActuator.lua",
        "Modules/Combat/AimController.lua",
        "Modules/Combat/AimMath.lua",
        "Modules/Combat/AimPolicy.lua",
        "Modules/Combat/AimPresentation.lua",
        "Modules/Combat/AimState.lua",
        "Modules/Combat/Predictor.lua",
        "Modules/Combat/SilentAimPolicy.lua",
        "Modules/Combat/TargetSelector.lua",
        "Modules/Combat/Prediction/Engine.lua",
        "Modules/Combat/Prediction/Estimator.lua",
        "Modules/Combat/Prediction/MotionPolicy.lua",
        "Modules/Combat/Prediction/Sampler.lua",
        "Modules/Combat/Prediction/Stabilizer.lua",
        "Modules/Utils/BossDetector.lua",
        "Modules/Utils/NativeTargetPolicy.lua",
        "Modules/Utils/NPCTracker.lua",
        "Modules/Utils/TargetClassifier.lua"
        "Modules/Utils/TrackerInvalidationPolicy.lua"
    )

    & selene --allow-warnings $aimFiles
    if ($LASTEXITCODE -ne 0) {
        throw "Selene failed."
    }

    & luau-analyze --formatter=gnu Modules/Combat/AimPolicy.lua Modules/Combat/AimState.lua Modules/Combat/SilentAimPolicy.lua Modules/Combat/Prediction/MotionPolicy.lua Modules/Utils/NativeTargetPolicy.lua Modules/Utils/TrackerInvalidationPolicy.lua
    if ($LASTEXITCODE -ne 0) {
        throw "Luau analysis failed."
    }

    if ($Graph) {
        if (-not (Get-Command graphify -ErrorAction SilentlyContinue)) {
            throw "Missing optional debug tool: graphify"
        }
        if (Test-Path "graphify-out/graph.json") {
            & graphify update .
        }
        else {
            & graphify extract . --code-only
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Graphify update failed."
        }
    }

    Write-Host "All debug checks passed." -ForegroundColor Green
}
finally {
    Pop-Location
}
