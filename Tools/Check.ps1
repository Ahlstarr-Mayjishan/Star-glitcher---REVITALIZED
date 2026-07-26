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
        "Modules/Combat/TargetSelector.lua",
        "Modules/Utils/TargetClassifier.lua"
    )

    & selene --allow-warnings $aimFiles
    if ($LASTEXITCODE -ne 0) {
        throw "Selene failed."
    }

    & luau-analyze --formatter=gnu Modules/Combat/AimPolicy.lua Modules/Combat/AimState.lua
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
