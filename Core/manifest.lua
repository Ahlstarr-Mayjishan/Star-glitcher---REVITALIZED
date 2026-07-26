--[[
    Master Manifest for STAR GLITCHER ~ REVITALIZED
    This file tracks all modules and their versions for the modular loader.
]]

return {
    Version = "1.6.0",
    Files = {
        -- Core
        ["Core/Main.lua"] = { Version = 190 },
        ["Modules/Core/Bootstrap/Normalize.lua"] = { Version = 100 },
        ["Modules/Core/Bootstrap/RayfieldUI.lua"] = { Version = 110 },
        ["Modules/Core/Bootstrap/RejoinOnKick.lua"] = { Version = 100 },
        ["Modules/Core/Bootstrap/RuntimeLifecycle.lua"] = { Version = 120 },
        ["Core/Brain.lua"] = { Version = 130 },
        
        -- Data
        ["Data/Config.lua"] = { Version = 180 },
        ["Data/PlaceProfiles.lua"] = { Version = 100 },
        ["Data/Version.lua"] = { Version = 160 },
        
        -- Modules/Combat
        ["Modules/Combat/AimMath.lua"] = { Version = 100 },
        ["Modules/Combat/AimPolicy.lua"] = { Version = 100 },
        ["Modules/Combat/AimState.lua"] = { Version = 100 },
        ["Modules/Combat/AimActuator.lua"] = { Version = 100 },
        ["Modules/Combat/AimPresentation.lua"] = { Version = 100 },
        ["Modules/Combat/AimController.lua"] = { Version = 110 },
        ["Modules/Combat/Aimbot.lua"] = { Version = 120 },
        ["Modules/Combat/Predictor.lua"] = { Version = 160 },
        ["Modules/Combat/SilentAim.lua"] = { Version = 160 },
        ["Modules/Combat/SilentAimPolicy.lua"] = { Version = 100 },
        ["Modules/Combat/TargetSelector.lua"] = { Version = 125 },
        ["Modules/Combat/UltraHell.lua"] = { Version = 110 },
        ["Modules/Combat/Prediction/SilentResolver.lua"] = { Version = 110 },
        ["Modules/Combat/Prediction/Base.lua"] = { Version = 100 },
        ["Modules/Combat/Prediction/Engine.lua"] = { Version = 130 },
        ["Modules/Combat/Prediction/Estimator.lua"] = { Version = 130 },
        ["Modules/Combat/Prediction/FeedbackLoop.lua"] = { Version = 100 },
        ["Modules/Combat/Prediction/Sampler.lua"] = { Version = 110 },
        ["Modules/Combat/Prediction/Stabilizer.lua"] = { Version = 110 },
        ["Modules/Combat/Prediction/MotionPolicy.lua"] = { Version = 100 },
        ["Modules/Combat/Prediction/TechniqueSelector.lua"] = { Version = 100 },
        
        -- Modules/Movement
        ["Modules/Movement/AntiSlowdown.lua"] = { Version = 110 },
        ["Modules/Movement/AntiStun.lua"] = { Version = 110 },
        ["Modules/Movement/AttributeCleaner.lua"] = { Version = 120 },
        ["Modules/Movement/CustomSpeed.lua"] = { Version = 100 },
        ["Modules/Movement/FloatController.lua"] = { Version = 100 },
        ["Modules/Movement/GravityController.lua"] = { Version = 100 },
        ["Modules/Movement/JumpBoost.lua"] = { Version = 100 },
        ["Modules/Movement/KillPartBypass.lua"] = { Version = 110 },
        ["Modules/Movement/MovementArbiter.lua"] = { Version = 100 },
        ["Modules/Movement/Noclip.lua"] = { Version = 110 },
        ["Modules/Movement/SpeedMultiplier.lua"] = { Version = 100 },
        ["Modules/Movement/SpeedSpoof.lua"] = { Version = 100 },
        ["Modules/Movement/WaypointTeleport.lua"] = { Version = 100 },
        
        -- Modules/Utils
        ["Modules/Utils/BossDetector.lua"] = { Version = 130 },
        ["Modules/Utils/DataPruner.lua"] = { Version = 100 },
        ["Modules/Utils/GarbageCollector.lua"] = { Version = 130 },
        ["Modules/Utils/InputHandler.lua"] = { Version = 115 },
        ["Modules/Utils/LocalCharacter.lua"] = { Version = 110 },
        ["Modules/Utils/NPCTracker.lua"] = { Version = 170 },
        ["Modules/Utils/ResourceManager.lua"] = { Version = 170 },
        ["Modules/Utils/Synapse.lua"] = { Version = 100 },
        ["Modules/Utils/TaskScheduler.lua"] = { Version = 110 },
        ["Modules/Utils/TargetClassifier.lua"] = { Version = 110 },
        ["Modules/Utils/NativeTargetPolicy.lua"] = { Version = 100 },
        ["Modules/Utils/NativeStatus.lua"] = { Version = 100 },
        ["Modules/Utils/Math/Kalman.lua"] = { Version = 100 },
        
        ["Modules/Utils/CharacterCleaner.lua"] = { Version = 110 },
        -- Modules/Visuals
        ["Modules/Visuals/FOVCircle.lua"] = { Version = 100 },
        ["Modules/Visuals/Highlight.lua"] = { Version = 110 },
        ["Modules/Visuals/TargetDot.lua"] = { Version = 100 },
        ["Modules/Visuals/TechniqueOverlay.lua"] = { Version = 110 },
        
        -- UI/Tabs
        ["UI/Tabs/AimbotTab.lua"] = { Version = 130 },
        ["UI/Tabs/BlatantTab.lua"] = { Version = 110 },
        ["UI/Tabs/GamemodeTab.lua"] = { Version = 100 },
        ["UI/Tabs/PlayerTab.lua"] = { Version = 100 },
        ["UI/Tabs/PredictionTab.lua"] = { Version = 110 },
        ["UI/Tabs/SettingsTab.lua"] = { Version = 150 },
        ["UI/Tabs/TeleportTab.lua"] = { Version = 120 },
        ["UI/Tabs/Player/Controller.lua"] = { Version = 110 },
        ["UI/Tabs/Player/LabelUtils.lua"] = { Version = 100 },
        ["UI/Tabs/Player/Layout.lua"] = { Version = 110 },
        ["UI/Tabs/Player/StatusLoop.lua"] = { Version = 100 },
    }
}
