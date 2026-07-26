--[[
    ===============================================================
         Boss Aim Assist - Centralized Brain Orchestration v7       
      Scientifically Reorganized | Fully Modular | Lazy Loading  
    ===============================================================
]]

-- Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local coreBootNow = os.clock()
local coreBootUntil = tonumber(_G.__STAR_GLITCHER_CORE_BOOT_UNTIL) or 0
if _G.BossAimAssist_SessionID and coreBootUntil > coreBootNow then
    warn("[Core] Duplicate runtime load suppressed.")
    return _G.BossAimAssist_SessionID
end
_G.__STAR_GLITCHER_CORE_BOOT_UNTIL = coreBootNow + 8

-- 1. Setup Resource Manager (The Loader)
-- These are injected by the bootstrapper (root Main.lua)
local resourceManager = _G.StarGlitcher_ResourceManager
if not resourceManager then
    error("[Core] ResourceManager not found. Please ensure root Main.lua was executed correctly.")
end

local function requireModule(path)
    return resourceManager:Load(path)
end

local function loadModule(path)
    return resourceManager:Load(path)
end

-- 2. Initial Data Loading
local Config  = requireModule("Data/Config.lua")
local Version = requireModule("Data/Version.lua")
local PlaceProfiles = requireModule("Data/PlaceProfiles.lua")
local Options = Config.Options
local placeProfile = PlaceProfiles.Get(game.PlaceId)
local Normalize = requireModule("Modules/Core/Bootstrap/Normalize.lua")
local RayfieldUI = requireModule("Modules/Core/Bootstrap/RayfieldUI.lua")
local RejoinOnKick = requireModule("Modules/Core/Bootstrap/RejoinOnKick.lua")
local RuntimeLifecycle = requireModule("Modules/Core/Bootstrap/RuntimeLifecycle.lua")

if _G.BossAimAssist_Cleanup then
    _G.BossAimAssist_Cleanup()
end

-- 3. UI Initialization (High Priority)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Rayfield = Rayfield

Options.ToggleUIKey = Normalize.ToggleUIKey(Options.ToggleUIKey)
Options.TargetingMethod = Normalize.TargetingMethod(Options.TargetingMethod)

local Window = RayfieldUI.CreateWindow(Rayfield)
local playerTabController = nil
local settingsTabController = nil

-- Create a temporary loading notifier
local loadingNotification = Rayfield:Notify({
    Title = "Star Glitcher",
    Content = "Initializing modular systems...",
    Duration = 3,
    -- Image removed for compatibility
})

-- 4. Component Loading (Dependency Order)
-- Combat
local Kalman          = requireModule("Modules/Utils/Math/Kalman.lua")
local AimMath         = requireModule("Modules/Combat/AimMath.lua")
local Tracker        = requireModule("Modules/Utils/NPCTracker.lua")
local Detector       = requireModule("Modules/Utils/BossDetector.lua")
local TargetClassifier = requireModule("Modules/Utils/TargetClassifier.lua")
local NativeTargetPolicy = requireModule("Modules/Utils/NativeTargetPolicy.lua")
local NativeStatus    = requireModule("Modules/Utils/NativeStatus.lua")
local Predictor       = requireModule("Modules/Combat/Predictor.lua")
local SelectiveResolver = requireModule("Modules/Combat/Prediction/SilentResolver.lua")
local Aimbot          = requireModule("Modules/Combat/Aimbot.lua")
local Selector        = requireModule("Modules/Combat/TargetSelector.lua")
local SilentAim       = requireModule("Modules/Combat/SilentAim.lua")
local SilentAimPolicy = requireModule("Modules/Combat/SilentAimPolicy.lua")
local AimPolicy       = requireModule("Modules/Combat/AimPolicy.lua")
local AimState        = requireModule("Modules/Combat/AimState.lua")
local AimActuator     = requireModule("Modules/Combat/AimActuator.lua")
local AimPresentation = requireModule("Modules/Combat/AimPresentation.lua")
local AimController   = requireModule("Modules/Combat/AimController.lua")

-- Movement Tools
local TaskScheduler   = requireModule("Modules/Utils/TaskScheduler.lua")
local LocalCharacter = requireModule("Modules/Utils/LocalCharacter.lua")
local MovementArbiter = requireModule("Modules/Movement/MovementArbiter.lua")
local Synapse         = requireModule("Modules/Utils/Synapse.lua")

local InputHandler    = requireModule("Modules/Utils/InputHandler.lua")
local DataPruner      = requireModule("Modules/Utils/DataPruner.lua")
local GarbageCollector = requireModule("Modules/Utils/GarbageCollector.lua")

-- Visuals
local FOVCircle       = requireModule("Modules/Visuals/FOVCircle.lua")
local Highlight       = requireModule("Modules/Visuals/Highlight.lua")
local TechniqueOverlay = requireModule("Modules/Visuals/TechniqueOverlay.lua")
local TargetDot       = requireModule("Modules/Visuals/TargetDot.lua")

-- 5. Movement Suite (Lazy instantiate helper)
local movementSuite = {}
local function setupMovement()
    local mc = LocalCharacter.new(TaskScheduler.new(Options))
    local arb = MovementArbiter.new(Options, mc)
    
    movementSuite.spoof = requireModule("Modules/Movement/SpeedSpoof.lua").new(Options, mc)
    movementSuite.arbiter = arb
    movementSuite.multi = requireModule("Modules/Movement/SpeedMultiplier.lua").new(Options, mc, arb)
    movementSuite.fixed = requireModule("Modules/Movement/CustomSpeed.lua").new(Options, mc, arb)
    movementSuite.gravity = requireModule("Modules/Movement/GravityController.lua").new(Options)
    movementSuite.float = requireModule("Modules/Movement/FloatController.lua").new(Options, mc)
    movementSuite.jump = requireModule("Modules/Movement/JumpBoost.lua").new(Options, mc, arb)
    movementSuite.slow  = requireModule("Modules/Movement/AntiSlowdown.lua").new(Options, mc, arb)
    movementSuite.stun  = requireModule("Modules/Movement/AntiStun.lua").new(Options, mc, NativeStatus)
    movementSuite.noclip = requireModule("Modules/Movement/Noclip.lua").new(Options, mc)
    if placeProfile.EnableGamemodeTools then
        movementSuite.killPart = requireModule("Modules/Movement/KillPartBypass.lua").new(Options, mc)
    end
    movementSuite.clean = requireModule("Modules/Movement/AttributeCleaner.lua").new(Options, mc, NativeStatus)
    movementSuite.charCleaner = requireModule("Modules/Utils/CharacterCleaner.lua").new(Options, mc, NativeStatus)
    movementSuite.waypoint = requireModule("Modules/Movement/WaypointTeleport.lua").new(Options, mc)
    
    return mc, arb
end

local localChar, arbiter = setupMovement()
local taskScheduler = TaskScheduler.new(Options)
local input = InputHandler.new(Config)
local detector = Detector.new()
local tracker = Tracker.new(Config, detector, taskScheduler, TargetClassifier)
tracker:SetNativeTargetPolicy(NativeTargetPolicy)
local aimbot = Aimbot.new(Config, AimMath)
local silentResolver = SelectiveResolver.new(Config)
local silentAim = SilentAim.new(Config, Synapse, silentResolver, SilentAimPolicy)
local ultraHell = nil
if placeProfile.EnableGamemodeTools then
    local UltraHell = requireModule("Modules/Combat/UltraHell.lua")
    ultraHell = UltraHell.new(Options)
else
    Options.UltraHellEnabled = false
    Options.KillPartBypassEnabled = false
end
local cleaner = GarbageCollector.new(Options, resourceManager)
local rejoinOnKick = RejoinOnKick.new(Options, _G.StarGlitcher_BootloaderURL or "Main.lua")

local pred = Predictor.new(Config, loadModule, Kalman, AimMath)
local selector = Selector.new(Config, tracker, pred, AimMath)
local dataPruner = DataPruner.new(taskScheduler, tracker, pred)

local visuals = {
    fov = FOVCircle.new(Options),
    highlight = Highlight.new(),
    technique = TechniqueOverlay.new(Options),
    dot = TargetDot.new()
}

local aimActuator = AimActuator.new(Options, aimbot, silentAim)
local aimPresentation = AimPresentation.new(Options, visuals)
local aimController = AimController.new(Config, {
    Input = input,
    Tracker = tracker,
    Predictor = pred,
    Selector = selector,
    Actuator = aimActuator,
    Presentation = aimPresentation,
}, AimPolicy, AimState)

input:SetShotCallback(function(now)
    aimController:OnShot(now)
end)

-- 6. Initialize Systems
input:Init()
taskScheduler:Init()
localChar:Init()
detector:Init()
tracker:Init()
aimbot:Init()
selector:Init()
silentAim:Init()
if ultraHell then ultraHell:Init() end
dataPruner:Init()
resourceManager:Init()
cleaner:Init()
for _, m in pairs(movementSuite) do if m.Init then m:Init() end end

-- 7. Tabs Loading (Lazy UI strategy)
-- Load basic tabs first
local function safeLoadTab(path, ...)
    local args = {...}
    local ok, err = pcall(function()
        local tabFunc = requireModule(path)
        if type(tabFunc) == "function" then
            tabFunc(Window, Options, unpack(args))
        else
            error("Tab module did not return a function: " .. path)
        end
    end)
    if not ok then
        warn("[UI] Failed to load tab: " .. path .. " | Error: " .. tostring(err))
    end
end

safeLoadTab("UI/Tabs/AimbotTab.lua", {FOVCircle = visuals.fov.Drawing}, tracker)
safeLoadTab("UI/Tabs/PredictionTab.lua")

-- Load complex tabs in background
task.spawn(function()
    local ok, controller = pcall(function()
        local PlayerController = requireModule("UI/Tabs/Player/Controller.lua")
        local PlayerLayout = requireModule("UI/Tabs/Player/Layout.lua")
        local PlayerStatusLoop = requireModule("UI/Tabs/Player/StatusLoop.lua")
        local PlayerLabelUtils = requireModule("UI/Tabs/Player/LabelUtils.lua")
        return PlayerController.new(PlayerLayout, PlayerStatusLoop, PlayerLabelUtils, Rayfield)
    end)

    if ok and controller then
        playerTabController = controller
        safeLoadTab("UI/Tabs/PlayerTab.lua", movementSuite.slow, movementSuite.stun, movementSuite.multi, movementSuite.gravity, movementSuite.float, movementSuite.jump, movementSuite.noclip, controller, movementSuite.charCleaner)
    end

    safeLoadTab("UI/Tabs/TeleportTab.lua", movementSuite.waypoint, Rayfield)
    safeLoadTab("UI/Tabs/BlatantTab.lua")
    if placeProfile.EnableGamemodeTools then
        safeLoadTab("UI/Tabs/GamemodeTab.lua", movementSuite.killPart, ultraHell, movementSuite.waypoint)
    end
    
    local settingsOk, loadedSettingsController = pcall(function()
        return requireModule("UI/Tabs/SettingsTab.lua")(
            Window,
            Options,
            cleaner,
            resourceManager,
            tracker,
            taskScheduler,
            Rayfield
        )
    end)
    if settingsOk then
        settingsTabController = loadedSettingsController
    end
    
    -- Final config load
    pcall(function()
        RayfieldUI.SafeLoadConfiguration(Rayfield)
        movementSuite.waypoint:LoadFromOptions()
    end)
end)

-- 8. Lifecycle Management
local runtimeLifecycle = RuntimeLifecycle.new(
    Options,
    Version,
    Rayfield,
    resourceManager,
    cleaner,
    Synapse,
    _G.StarGlitcher_BootloaderURL or (Config.GITHUB_BASE .. "Main.lua"),
    function()
        local source = resourceManager:FetchFreshSource(
            "Main.lua",
            _G.StarGlitcher_DynamicRemoteBases or resourceManager.RemoteBases
        )
        return loadstring(source, "=updated-entry")()
    end,
    function()
        return resourceManager:GetLatestManifestVersion()
    end,
    function() 
        local objects = {
            aimController, input, localChar, detector, tracker, pred, selector, aimbot, silentAim,
            cleaner, visuals.fov, visuals.highlight, visuals.technique, visuals.dot,
            taskScheduler, dataPruner, movementSuite.waypoint, rejoinOnKick
        }
        if ultraHell then objects[#objects + 1] = ultraHell end
        if movementSuite.killPart then objects[#objects + 1] = movementSuite.killPart end
        if playerTabController then objects[#objects + 1] = playerTabController end
        if settingsTabController then objects[#objects + 1] = settingsTabController end
        return objects
    end,
    function() end
)

runtimeLifecycle:BindGlobals()
runtimeLifecycle:StartAutoUpdateLoop()
rejoinOnKick:Init()

-- Event Connections
local function reg(connection) return runtimeLifecycle:RegisterConnection(connection) end
local lastAimRuntimeWarning = 0
reg(RunService.RenderStepped:Connect(function(dt)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    local cameraCFrame = camera.CFrame
    local ok, err = pcall(aimController.Step, aimController, dt, mousePos, cameraCFrame, camera)
    if not ok then
        aimController:Recover()
        local now = os.clock()
        if (now - lastAimRuntimeWarning) >= 2 then
            lastAimRuntimeWarning = now
            warn("[Aim] Frame recovered after runtime error: " .. tostring(err))
        end
    end
end))

warn(" [Core] Star Glitcher Aim Pipeline Active (Optimized v8.0).")
return _G.BossAimAssist_SessionID
