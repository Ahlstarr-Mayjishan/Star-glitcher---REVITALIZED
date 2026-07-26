local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local WaypointTeleport = {}
WaypointTeleport.__index = WaypointTeleport

local DEFAULT_SPEED = 150
local MIN_SPEED = 10
local MAX_SPEED = 1000
local EMPTY_OPTION = "(No waypoints yet)"
local SERIALIZED_OPTION_KEY = "TeleportWaypointsData"
local WAYPOINT_FOLDER = "Boss_AimAssist"
local WAYPOINT_FILE = WAYPOINT_FOLDER .. "/Waypoints.json"

function WaypointTeleport.new(options, localCharacter)
    local self = setmetatable({}, WaypointTeleport)
    self.Options = options
    self.LocalCharacter = localCharacter
    self.Status = "Idle"
    self.Waypoints = {}
    self.SelectedWaypointName = nil
    self.Dropdown = nil
    self._tweenConnection = nil
    return self
end

function WaypointTeleport:_writeWaypointFile(serialized)
    if not writefile then
        return false
    end

    pcall(function()
        if makefolder and not isfolder(WAYPOINT_FOLDER) then
            makefolder(WAYPOINT_FOLDER)
        end
    end)

    return pcall(function()
        writefile(WAYPOINT_FILE, serialized)
    end)
end

function WaypointTeleport:_readWaypointFile()
    if not readfile or not isfile or not isfile(WAYPOINT_FILE) then
        return nil
    end

    local ok, content = pcall(function()
        return readfile(WAYPOINT_FILE)
    end)

    if ok and type(content) == "string" and content ~= "" then
        return content
    end

    return nil
end

function WaypointTeleport:_serializeWaypoints()
    local payload = table.create(#self.Waypoints)
    for index = 1, #self.Waypoints do
        local waypoint = self.Waypoints[index]
        local cf = waypoint.CFrame
        local components = table.pack(cf:GetComponents())
        payload[index] = {
            Name = waypoint.Name,
            Components = {
                components[1], components[2], components[3], components[4],
                components[5], components[6], components[7], components[8],
                components[9], components[10], components[11], components[12],
            },
            CreatedAt = waypoint.CreatedAt,
        }
    end

    local ok, result = pcall(function()
        return HttpService:JSONEncode(payload)
    end)

    self.Options[SERIALIZED_OPTION_KEY] = ok and result or ""
    if ok and result then
        self:_writeWaypointFile(result)
    end
end

function WaypointTeleport:LoadFromOptions()
    local encoded = self.Options[SERIALIZED_OPTION_KEY]
    if type(encoded) ~= "string" or encoded == "" then
        encoded = self:_readWaypointFile()
        if encoded then
            self.Options[SERIALIZED_OPTION_KEY] = encoded
        else
            self:_refreshDropdown()
            return
        end
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(encoded)
    end)
    if not ok or type(decoded) ~= "table" then
        self.Options[SERIALIZED_OPTION_KEY] = ""
        self.Waypoints = {}
        self.SelectedWaypointName = nil
        self:_refreshDropdown()
        return
    end

    local loadedWaypoints = {}
    for index = 1, #decoded do
        local item = decoded[index]
        local components = item and item.Components
        if type(item) == "table" and type(item.Name) == "string" and type(components) == "table" and #components == 12 then
            local okCFrame, waypointCFrame = pcall(CFrame.new, table.unpack(components, 1, 12))
            if okCFrame and waypointCFrame then
                loadedWaypoints[#loadedWaypoints + 1] = {
                    Name = item.Name,
                    CFrame = waypointCFrame,
                    CreatedAt = tonumber(item.CreatedAt) or os.clock(),
                }
            end
        end
    end

    self.Waypoints = loadedWaypoints
    self.SelectedWaypointName = self.Waypoints[1] and self.Waypoints[1].Name or nil
    self:_serializeWaypoints()
    self:_refreshDropdown()
end

function WaypointTeleport:_getCharacterState()
    if self.LocalCharacter and self.LocalCharacter.GetState then
        return self.LocalCharacter:GetState()
    end

    local character = Players.LocalPlayer and Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
    return character, humanoid, root
end

function WaypointTeleport:_getRoot()
    local character, _, root = self:_getCharacterState()
    return character, root
end

function WaypointTeleport:_refreshDropdown()
    if not self.Dropdown then
        return
    end

    local options = self:GetWaypointNames()
    local currentOption = self.SelectedWaypointName or options[1]

    local ok = pcall(function()
        if type(self.Dropdown.Refresh) == "function" then
            self.Dropdown:Refresh(options, true)
        elseif type(self.Dropdown.SetOptions) == "function" then
            self.Dropdown:SetOptions(options)
        else
            self.Dropdown.Options = options
        end
    end)

    if not ok and typeof(self.Dropdown) == "Instance" then
        local textLabel = self.Dropdown:FindFirstChildWhichIsA("TextLabel", true)
        if textLabel then
            textLabel.Text = tostring(currentOption)
        end
    end

    if type(self.Dropdown.Set) == "function" then
        pcall(function()
            self.Dropdown:Set(currentOption)
        end)
    end
end

function WaypointTeleport:SetDropdown(dropdown)
    self.Dropdown = dropdown
    self:_refreshDropdown()
end

function WaypointTeleport:GetWaypointNames()
    if #self.Waypoints == 0 then
        return { EMPTY_OPTION }
    end

    local names = table.create(#self.Waypoints)
    for i = 1, #self.Waypoints do
        names[i] = self.Waypoints[i].Name
    end
    return names
end

function WaypointTeleport:SetSelectedWaypoint(name)
    if not name or name == EMPTY_OPTION then
        self.SelectedWaypointName = nil
        return
    end

    self.SelectedWaypointName = name
end

function WaypointTeleport:_findWaypointByName(name)
    if not name then
        return self.Waypoints[1]
    end

    for i = 1, #self.Waypoints do
        local waypoint = self.Waypoints[i]
        if waypoint.Name == name then
            return waypoint
        end
    end

    return self.Waypoints[1]
end

function WaypointTeleport:_formatWaypointName(root)
    local pos = root.Position
    return string.format("%s | %.0f, %.0f, %.0f", os.date("%H:%M:%S"), pos.X, pos.Y, pos.Z)
end

function WaypointTeleport:SetWaypoint(customName)
    local _, root = self:_getRoot()
    if not root then
        self.Status = "Body Missing"
        return false, "Character body is not available."
    end

    local name = customName or self:_formatWaypointName(root)
    
    -- Duplicate Name Check
    for _, wp in ipairs(self.Waypoints) do
        if wp.Name == name then
            return false, "Waypoint with name '" .. name .. "' already exists."
        end
    end

    table.insert(self.Waypoints, 1, {
        Name = name,
        CFrame = root.CFrame,
        CreatedAt = os.clock(),
    })

    self.SelectedWaypointName = name
    self.Status = "Saved Waypoint"
    self:_serializeWaypoints()
    self:_refreshDropdown()
    return true, name
end

function WaypointTeleport:_stopTween(status)
    if self._tweenConnection then
        self._tweenConnection:Disconnect()
        self._tweenConnection = nil
    end

    if status then
        self.Status = status
    end
end

function WaypointTeleport:_startTween(targetCFrame)
    self:_stopTween()
    self.Status = "Tweening"

    self._tweenConnection = RunService.Heartbeat:Connect(function(dt)
        local character, root = self:_getRoot()
        if not character or not root then
            self:_stopTween("Body Missing")
            return
        end

        local current = root.CFrame
        local delta = targetCFrame.Position - current.Position
        local distance = delta.Magnitude
        if distance <= 2 then
            character:PivotTo(targetCFrame)
            self:_stopTween("Arrived")
            return
        end

        local speed = math.clamp(tonumber(self.Options.TeleportTweenSpeed) or DEFAULT_SPEED, MIN_SPEED, MAX_SPEED)
        local alpha = math.clamp((speed * dt) / math.max(distance, 0.001), 0, 1)
        character:PivotTo(current:Lerp(targetCFrame, alpha))
    end)
end

function WaypointTeleport:GotoSelectedWaypoint()
    local waypoint = self:_findWaypointByName(self.SelectedWaypointName)
    if not waypoint then
        self.Status = "No Waypoint"
        return false, "No waypoint has been saved yet."
    end

    local character, root = self:_getRoot()
    if not character or not root then
        self.Status = "Body Missing"
        return false, "Character body is not available."
    end

    local method = tostring(self.Options.TeleportMethod or "Tween")
    if method == "Teleport" then
        character:PivotTo(waypoint.CFrame)
        self.Status = "Teleported"
        self:_stopTween()
        return true, waypoint.Name
    end

    self:_startTween(waypoint.CFrame)
    return true, waypoint.Name
end

function WaypointTeleport:Destroy()
    self:_stopTween("Destroyed")
    self.Dropdown = nil
end

return WaypointTeleport
