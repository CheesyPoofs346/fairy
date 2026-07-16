local ReplicatedStorage = game:GetService("ReplicatedStorage")
local scriptMarker = string.char(95) .. string.reverse("evitCAlortnoC elciheV") .. string.char(95)
if _G[scriptMarker] then
    pcall(function()
        _G[scriptMarker]:Disconnect()
    end)
    _G[scriptMarker] = nil
    task.wait(math.random(40, 60) / 100)
end
local gS = game.GetService
local Services = {
    Players = gS(game, "Players"),
    RunService = gS(game, "RunService"),
    UserInputService = gS(game, "UserInputService"),
    Workspace = gS(game, "Workspace"),
    TweenService = gS(game, "TweenService"),
    ProximityPromptService = gS(game, "ProximityPromptService"),
    CollectionService = gS(game, "CollectionService")
}
local player = Services.Players.LocalPlayer
local FALL_PROTECTION_TAGS = {"NoFallDamage", "NoRagdoll"}
local function setFallProtection(character, enabled)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root and enabled and character then
        root = character:WaitForChild("HumanoidRootPart", 5)
    end
    if not root then return false end
    for _, tag in ipairs(FALL_PROTECTION_TAGS) do
        if enabled then
            Services.CollectionService:AddTag(root, tag)
        else
            Services.CollectionService:RemoveTag(root, tag)
        end
    end
    return true
end
_G[scriptMarker] = {Disconnect = function() end}

local State = {
    sessionID = tostring(math.random(100000, 999999)),
    guiID = string.char(math.random(65, 90)) .. tostring(math.random(100000, 999999)),
    iconIdentifier = string.char(math.random(65, 90)) .. tostring(math.random(100000, 999999)),
    waterBypassEnabled = false,
    autopilotEnabled = false,
    teamIconsEnabled = true,
    laserRemoverEnabled = true,
    flightEnabled = false,
    softAimEnabled = false,
    autoSolveMuseum = false,
    noclipEnabled = false,
    oldSoftAimEnabled = false,
    mouseFovEnabled = false,
    autoShootEnabled = false,
    guiVisible = false,
    flying = false,
    isClimbing = false,
    isAtWaypoint = false,
    hazardProcessingRunning = false,
    workspaceScanRunning = false,
    killed = false
}

local Keybinds = {
    gui = Enum.KeyCode.K,
    water = Enum.KeyCode.Unknown,
    flight = Enum.KeyCode.G,
    autopilot = Enum.KeyCode.F,
    teamIcons = Enum.KeyCode.Unknown,
    laser = Enum.KeyCode.Unknown,
    softAim = Enum.KeyCode.Unknown,
    mouseFov = Enum.KeyCode.Unknown,
    autoShoot = Enum.KeyCode.Unknown,
    flightUp = Enum.KeyCode.Space,
    flightDown = Enum.KeyCode.LeftControl
}

local Buttons = {}
local Connections = {}
local Cache = {
    vehicleUtils = nil,
    targets = {},
    npcTargets = {},
    esp = {},
    noclipParts = {},
    hazards = {
        processed = setmetatable({}, {__mode = "k"}),
        queue = {},
        queueHead = 1,
        queueTail = 0,
        enqueued = setmetatable({}, {__mode = "k"}),
    }
}

local Timers = {

    lastTargetScan = 0,
    lastNpcScan = 0
}

local Config = {

    HAZARD_BATCH_SIZE = math.random(4, 8),
    HAZARD_SCAN_INTERVAL = math.random(3, 6) / 10,
    TARGET_CACHE_TIME = 0.15,
    flySpeed = 200,
    minDistance = 5,
    targetAltitude = 100,
    lookAheadDistance = 50,
    obstacleDetectionRadius = 50,
    CALIBRATION_FACTOR = 0.745,
    flightSpeed = 40,
    flightHeight = 8,
    roadScanInterval = 1.5,
    roadSearchRadius = 180,
    roadLookAhead = 85,
    roadRideHeight = 3.5,
    maxRoadParts = 220,
    minRoadPartSize = 8,
    maxDriveSpeed = 145,
    minDriveSpeed = 20,
    approachSlowDistance = 95,
    turnSlowAngle = 95,
    steeringResponsiveness = 0.18,
    speedSmoothing = 0.08,
    brakeSmoothing = 0.18,
    obstacleBrakeDistance = 65,
    roadTags = {"Road", "RoadPart", "Street", "Lane", "Driveable"},
    roadNameKeywords = {"road", "street", "lane", "asphalt", "pavement", "highway", "drive", "route"}
}

local AutopilotData = {
    currentVehicle = nil,
    currentWaypoint = nil,
    lastValidVehRoot = nil,
    arrived = false,
    lastPosition = nil,
    lastProgressAt = 0,
    escapeUntil = 0,
    vehicleReadyAt = 0,
    arrestMode = false,  -- 3-phase arrest flight: ascend → cruise → descend
    obstacleDirections = {
        Vector3.new(0, 0, 1),
        Vector3.new(0.5, 0, 0.866025),
        Vector3.new(0.866025, 0, 0.5),
        Vector3.new(1, 0, 0),
        Vector3.new(0.866025, 0, -0.5),
        Vector3.new(0.5, 0, -0.866025),
        Vector3.new(0, 0, -1),
        Vector3.new(-0.5, 0, -0.866025),
        Vector3.new(-0.866025, 0, -0.5),
        Vector3.new(-1, 0, 0),
        Vector3.new(-0.866025, 0, 0.5),
        Vector3.new(-0.5, 0, 0.866025)
    },
    obstacleHeightOffsets = {-30, -20, -10, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90},
    obstacleCache = {
        checkedAt = 0,
        position = nil,
        vehicle = nil,
        hasObstacle = false,
        top = 0,
        bottom = 0
    },
    groundIgnore = {},
    obstacleIgnore = {}
}

local RoadPilotData = {
    roadParts = {},
    lastRoadScan = 0,
    lastFullRoadScan = 0,
    currentSpeed = 0,
    currentRoad = nil,
    lastTarget = nil,
    obstacleIgnore = {},
    obstacleIgnoreRoads = nil,
    obstacleIgnoreVehicle = nil,
    obstacleIgnoreCharacter = nil
}

-- Restore workspace.Raycast/FindPartOnRayWithIgnoreList if a previous run of this
-- script hooked them (leaving a broken Lua wrapper instead of the C original).
pcall(function()
    local function restoreIfLua(methodName)
        local fn = workspace[methodName]
        if iscclosure and not iscclosure(fn) then
            -- It's a Lua wrapper from a previous run. Walk its upvalues to find
            -- the stored original (stored as SAI.origRaycast / SAI.origFindPart).
            for i = 1, 50 do
                local name, val = debug.getupvalue(fn, i)
                if name == nil then break end
                if type(val) == "table" then
                    local orig = val["orig" .. methodName:gsub("^%l", string.upper)]
                        or val.origRaycast or val.origFindPart
                    if orig and iscclosure(orig) then
                        hookfunction(fn, orig)
                        break
                    end
                end
            end
        end
    end
    restoreIfLua("Raycast")
    restoreIfLua("FindPartOnRayWithIgnoreList")
end)

-- Clean up BulletEmitter hooks from a previous run.
pcall(function()
    local emitterModule = require(game:GetService("ReplicatedStorage").Game.ItemSystem.BulletEmitter)
    if _G["__sai_emit_orig"] then
        local targetFn = _G["__sai_emit_targetfn"] or emitterModule.Emit
        local restored = false
        if targetFn and type(hookfunction) == "function" then
            restored = pcall(function()
                hookfunction(targetFn, _G["__sai_emit_orig"])
            end)
        end
        if not restored then emitterModule.Emit = _G["__sai_emit_orig"] end
    end
    _G["__sai_emit_orig"] = nil
    _G["__sai_emit_targetfn"] = nil

    if _G["__sai_update_orig"] then
        local targetFn = _G["__sai_update_targetfn"] or emitterModule.Update
        local restored = false
        if targetFn and type(hookfunction) == "function" then
            restored = pcall(function()
                hookfunction(targetFn, _G["__sai_update_orig"])
            end)
        end
        if not restored then emitterModule.Update = _G["__sai_update_orig"] end
    end
    _G["__sai_update_orig"] = nil
    _G["__sai_update_targetfn"] = nil
end)

-- Clean up old RayCast hooks from a previous run.
pcall(function()
    if _G["__sai_old_orig"] then
        local RaycastModule = require(game:GetService("ReplicatedStorage").Module.RayCast)
        local targetFn = _G["__sai_old_targetfn"] or RaycastModule.RayIgnoreNonCollideWithIgnoreList
        local restored = false
        if targetFn and type(hookfunction) == "function" then
            restored = pcall(function()
                hookfunction(targetFn, _G["__sai_old_orig"])
            end)
        end
        if not restored then RaycastModule.RayIgnoreNonCollideWithIgnoreList = _G["__sai_old_orig"] end
    end
    _G["__sai_old_orig"] = nil
    _G["__sai_old_targetfn"] = nil
end)

local SoftAimData = {
    settings = {Enabled = false, Wallbang = false, MaxRange = 5000, MinAimDot = math.cos(math.rad(45))},
    emitHooked = false,
    emitOrig = nil,
    emitTargetFn = nil,
    oldHooked = false,
    oldOrig = nil,
    oldTargetFn = nil,
    lockedOffset = nil,
    selectionParams = RaycastParams.new(),
    shotParams = RaycastParams.new(),
    peekOffsets = {
        Vector3.new(0, 5, 0),
        Vector3.new(4, 0, 0),
        Vector3.new(-4, 0, 0),
        Vector3.new(0, -3, 0),
        Vector3.new(3, 3, 0),
        Vector3.new(-3, 3, 0),
    },
}
SoftAimData.selectionParams.FilterType = Enum.RaycastFilterType.Exclude
SoftAimData.selectionParams.IgnoreWater = true
SoftAimData.shotParams.FilterType = Enum.RaycastFilterType.Exclude
SoftAimData.shotParams.IgnoreWater = true


SoftAimData.getAimPosition = function(target)
    if not target then return nil end
    if target:IsA("BasePart") then return target.Position end
    local head = target:FindFirstChild("Head")
    local root = target:FindFirstChild("HumanoidRootPart")
    return head and head.Position or root and root.Position or nil
end

-- Wallbang through any obstacle: terrain, buildings, walls, cover.
-- Walks each hit all the way up to its top-level workspace child so entire buildings
-- are excluded in one entry — avoids needing to hit every individual wall part.
SoftAimData.getAnyBlockerPath = function(target, origin, myChar)
    local targetPos = SoftAimData.getAimPosition(target)
    if not targetPos then return nil end
    local ignored = {myChar, target}
    local obstacles = {}
    local params = SoftAimData.shotParams
    for _ = 1, 12 do
        params.FilterDescendantsInstances = ignored
        local result = workspace:Raycast(origin, targetPos - origin, params)
        if not result then return obstacles end
        local inst = result.Instance
        -- walk up to the direct child of workspace (excludes whole building at once)
        local blocker = inst
        if inst == workspace.Terrain then
            blocker = workspace.Terrain
        else
            while blocker.Parent and blocker.Parent ~= workspace
                and not blocker.Parent:IsA("WorldRoot") do
                blocker = blocker.Parent
            end
        end
        local already = false
        for _, v in ipairs(ignored) do if v == blocker then already = true; break end end
        if not already then
            obstacles[#obstacles + 1] = blocker
            ignored[#ignored + 1] = blocker
        end
    end
    -- return whatever we collected; caller adds to ignore list so bullet clears those layers
    return obstacles
end

-- Gap-router: find a clear direction through an opening (tunnel mouth, hole in terrain).
-- Samples a cone of rays around the direct line; returns the first clear direction, or nil.
SoftAimData.findPeekOffset = function(target, origin, myChar)
    local targetPos = SoftAimData.getAimPosition(target)
    if not targetPos then return nil end
    local params = SoftAimData.selectionParams
    params.FilterDescendantsInstances = {myChar, target}
    for _, offset in ipairs(SoftAimData.peekOffsets) do
        local testOrigin = origin + offset
        if not Services.Workspace:Raycast(origin, offset, params)
            and not Services.Workspace:Raycast(testOrigin, targetPos - testOrigin, params)
        then
            return offset
        end
    end
    return nil
end

local FlightData = {
    bodyVel = nil,
    bodyGyro = nil,
    skydiveAnimTrack = nil
}

-- ===== MANUAL VEHICLE FLY =====
local VehFlySettings = {
    Enabled = false,
    Speed = 190,
}
local vehFlyConnection = nil
local vehFlyCurrentVehicle = nil

-- ===== C4 ORBIT =====
local OrbitSettings = {
    Enabled = false,
    Speed = 3,
    Radius = 8
}
local OrbitLogic = {Objs = {}, Connection = nil}

-- ===== ESP (PLAYER HIGHLIGHTING) =====
local ESPSettings = {
    Enabled = false,
    TeamCheck = true,
    Transparency = 0.7,
    COREGUI = game:GetService("CoreGui")
}

-- ===== REMOTE VEHICLE CONTROL =====
local RopeSettings = {
    FlyEnabled = false,
    FlySpeed = 200,
    LinkedVehicle = nil,
    VehicleSeat = nil,
    FlyConnection = nil,
    OriginalCameraSubject = nil,
    OriginalCameraType = nil,
    CameraDistance = 25,
    CameraAngleX = 0,
    CameraAngleY = 0,
}

-- ===== AUTO BANK ROBBERY =====
local BankRobSettings = {
    Enabled = false,
    CurrentPhase = "Idle",
    HeliSearchRadius = 500,
    BankFlyHeight = 250,
    VaultWaitTime = 10,
    TriggerWaitTime = 8,
}
local bankRobState = {
    targetHeli = nil,
    phaseConnection = nil,
    phaseInProgress = false,
    phaseStart = nil,
    phaseStartDist = nil,
    triggerDoorPart = nil,
    moneyPart = nil,
    barrier2Pos = nil,
    lastPhaseUpdate = 0
}
local PathRecorder = {
    Recording = false,
    RecordedPath = {},
    RecordInterval = 0.3,
    RecordConnection = nil,
    RecordElapsed = 0
}

-- ===== AUTO ARREST =====
local ArrestSettings = {
    Enabled = false,
    Range = 10,
    CheckInterval = 0.1
}
local arrestState = {isArresting = false, lastCheck = 0}
local arrestConnection = nil

-- ===== PLAYER LIST =====
local playerListConnections = {}

local function areEnemies(team1, team2)
    if not team1 or not team2 then return false end
    local team1Name = team1.Name:lower()
    local team2Name = team2.Name:lower()
    local isTeam1Police = team1Name:find("polic") or team1Name:find("cop") or team1Name:find("guard")
    local isTeam2Police = team2Name:find("polic") or team2Name:find("cop") or team2Name:find("guard")
    local isTeam1Crim = team1Name:find("criminal") or team1Name:find("prisoner") or team1Name:find("inmate")
    local isTeam2Crim = team2Name:find("criminal") or team2Name:find("prisoner") or team2Name:find("inmate")
    if isTeam1Police and isTeam2Crim then return true end
    if isTeam1Crim and isTeam2Police then return true end
    return false
end

local function quickVisCheck(targetChar, fromPos, myChar)
    if not targetChar then return false end
    local targetHead = targetChar:FindFirstChild("Head")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end
    
    local targetPos = targetHead and targetHead.Position or targetRoot.Position
    local rayDir = (targetPos - fromPos)
    
    local params = SoftAimData.selectionParams
    params.FilterDescendantsInstances = {myChar, targetChar}
    
    local result = Services.Workspace:Raycast(fromPos, rayDir, params)
    if not result then return true end
    if result.Instance:IsDescendantOf(targetChar) then return true end
    if result.Instance.Transparency >= 0.5 or not result.Instance.CanCollide then return true end
    return false
end

local function scanTargets(myTeam)
    local targets = Cache.targets
    table.clear(targets)
    
    for _, v in ipairs(Services.Players:GetPlayers()) do
        if v ~= player and areEnemies(myTeam, v.Team) then
            local char = v.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    targets[#targets + 1] = char
                end
            end
        end
    end

    local now = tick()
    if now - Timers.lastNpcScan >= 1 then
        Timers.lastNpcScan = now
        local npcTargets = Cache.npcTargets
        table.clear(npcTargets)
        local drop = Services.Workspace:FindFirstChild("Drop")
        local npcs = drop and drop:FindFirstChild("NPCs")
        if npcs then
            for _, npc in ipairs(npcs:GetChildren()) do
                if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then
                    npcTargets[#npcTargets + 1] = npc
                end
            end
        end

        for _, child in ipairs(Services.Workspace:GetChildren()) do
            if child:IsA("Model") then
                local guards = child:FindFirstChild("GuardsFolder")
                if guards then
                    for _, guard in ipairs(guards:GetChildren()) do
                        if guard:FindFirstChild("HumanoidRootPart") then
                            npcTargets[#npcTargets + 1] = guard
                        end
                    end
                end
                local boss = child:FindFirstChild("ActiveBoss")
                if boss and boss:FindFirstChild("HumanoidRootPart") then
                    npcTargets[#npcTargets + 1] = boss
                end
            end
        end
    end

    for _, npc in ipairs(Cache.npcTargets) do
        local hum = npc.Parent and npc:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 and npc:FindFirstChild("HumanoidRootPart") then
            targets[#targets + 1] = npc
        end
    end
end

local function findBestTarget(origin, myRoot, myChar, maxRange, aimDirection)
    local camera = Services.Workspace.CurrentCamera
    local lookDir = camera and camera.CFrame.LookVector or aimDirection and aimDirection.Magnitude > 0
        and aimDirection.Unit or workspace.CurrentCamera.CFrame.LookVector
    local candidates = {}
    for _, targetChar in ipairs(Cache.targets) do
        local root = targetChar:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = (root.Position - myRoot.Position).Magnitude
            if dist <= maxRange then
                local toTarget = (root.Position - origin).Unit
                local aimDot = lookDir:Dot(toTarget)
                if aimDot >= SoftAimData.settings.MinAimDot then
                    table.insert(candidates, {char = targetChar, dist = dist, angle = math.acos(math.clamp(aimDot, -1, 1))})
                end
            end
        end
    end

    -- sort by angle from crosshair (closest to reticle wins)
    table.sort(candidates, function(a, b)
        if math.abs(a.angle - b.angle) < math.rad(2) then return a.dist < b.dist end
        return a.angle < b.angle
    end)

    for _, data in ipairs(candidates) do
        if quickVisCheck(data.char, origin, myChar) or SoftAimData.settings.Wallbang then
            return data.char, nil
        end
        local peekOffset = SoftAimData.findPeekOffset(data.char, origin, myChar)
        if peekOffset then
            return data.char, peekOffset
        end
    end
    return nil
end

-- Hooks BulletEmitter.Emit — runs ONLY ONCE per shot fired.
-- Uses lead-prediction to aim at where the target WILL BE when the bullet arrives.
-- Bullet travels in a STRAIGHT LINE so the server validates the hit and deals damage.
-- Bullet pathfinding: shifts emission origin slightly (up to 5 studs) to shoot around walls/cover.
-- Wallbang support: injects wall parts into IgnoreList so bullet passes through them.
local function createSoftAimEmitHook()
    return function(emitter, origin, direction, speed, ...)
        local original = SoftAimData.emitOrig
        if not original then return end

        local restoreIgnore = nil

        if SoftAimData.settings.Enabled and emitter and emitter.Local == true then
            local target = SoftAimData.lockedTarget
            if target then
                local aimPos = SoftAimData.getAimPosition(target)
                if aimPos then
                    -- Lead prediction: aim at where the target will be when bullet arrives
                    local targetRoot = target:FindFirstChild("HumanoidRootPart")
                    local actualSpeed = (type(speed) == "number" and speed > 10) and speed or 600
                    local distance = (aimPos - origin).Magnitude
                    local travelTime = distance / actualSpeed

                    local predictedPos = aimPos
                    if targetRoot then
                        local vel = targetRoot.AssemblyLinearVelocity
                        predictedPos = aimPos + vel * travelTime
                    end

                    local finalOrigin = origin
                    local peekOffset = SoftAimData.lockedOffset
                    if peekOffset then
                        local rayParams = SoftAimData.shotParams
                        rayParams.FilterDescendantsInstances = {player.Character, target}
                        local testOrigin = origin + peekOffset
                        if not workspace:Raycast(origin, peekOffset, rayParams)
                            and not workspace:Raycast(testOrigin, predictedPos - testOrigin, rayParams)
                        then
                            finalOrigin = testOrigin
                        end
                    end

                    origin = finalOrigin
                    direction = (predictedPos - finalOrigin).Unit

                    if SoftAimData.settings.Wallbang then
                        local obstacles = SoftAimData.getAnyBlockerPath(target, origin, player.Character)
                        if obstacles and #obstacles > 0 then
                            local originalIgnore = emitter.IgnoreList or {}
                            local newIgnore = table.clone(originalIgnore)
                            for _, v in ipairs(obstacles) do
                                newIgnore[#newIgnore + 1] = v
                            end
                            emitter.IgnoreList = newIgnore
                            restoreIgnore = originalIgnore
                        end
                    end
                end
            end
        end

        local results = table.pack(pcall(original, emitter, origin, direction, speed, ...))

        if restoreIgnore then
            emitter.IgnoreList = restoreIgnore
        end

        if not results[1] then error(results[2], 0) end
        return table.unpack(results, 2, results.n)
    end
end

local toggleOldSoftAim

local function toggleSoftAim(state)
    State.softAimEnabled = state
    SoftAimData.settings.Enabled = state
    if state then
        if State.oldSoftAimEnabled then
            toggleOldSoftAim(false)
        end
        -- Hook Emit only — straight-line lead-prediction shot, server validates it
        if not SoftAimData.emitHooked then
            pcall(function()
                local emitterModule = require(ReplicatedStorage.Game.ItemSystem.BulletEmitter)
                local targetFn = emitterModule.Emit
                local hookFn = createSoftAimEmitHook()

                local realOrig
                if type(hookfunction) == "function" then
                    realOrig = hookfunction(targetFn, hookFn)
                else
                    realOrig = targetFn
                    emitterModule.Emit = hookFn
                end

                _G["__sai_emit_orig"] = realOrig
                _G["__sai_emit_targetfn"] = targetFn

                SoftAimData.emitOrig = realOrig
                SoftAimData.emitTargetFn = targetFn
                SoftAimData.emitHooked = true
            end)
        end

        -- Background target scanner loop: runs asynchronously to prevent click lag
        task.spawn(function()
            while State.softAimEnabled and SoftAimData.settings.Enabled do
                pcall(function()
                    local myChar = player.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myChar and myRoot then
                        local now = tick()
                        if now - Timers.lastTargetScan > Config.TARGET_CACHE_TIME then
                            Timers.lastTargetScan = now
                            scanTargets(player.Team)
                        end

                        local target, peekOffset = findBestTarget(
                            myRoot.Position, myRoot, myChar,
                            SoftAimData.settings.MaxRange,
                            workspace.CurrentCamera.CFrame.LookVector
                        )

                        if target then
                            local aimPos = SoftAimData.getAimPosition(target)
                            if aimPos then
                                SoftAimData.lockedTarget = target
                                SoftAimData.lockedOffset = peekOffset
                            else
                                SoftAimData.lockedTarget = nil
                                SoftAimData.lockedOffset = nil
                            end
                        else
                            SoftAimData.lockedTarget = nil
                            SoftAimData.lockedOffset = nil
                        end
                    end
                end)
                task.wait(0.08) -- 12.5Hz update frequency (extremely light, fully responsive)
            end
        end)
    else
        SoftAimData.lockedTarget = nil
        SoftAimData.lockedOffset = nil

        -- Unhook Emit
        if SoftAimData.emitHooked and SoftAimData.emitTargetFn and SoftAimData.emitOrig then
            pcall(function()
                if type(hookfunction) == "function" then
                    hookfunction(SoftAimData.emitTargetFn, SoftAimData.emitOrig)
                else
                    local emitterModule = require(ReplicatedStorage.Game.ItemSystem.BulletEmitter)
                    emitterModule.Emit = SoftAimData.emitOrig
                end
                _G["__sai_emit_orig"] = nil
                _G["__sai_emit_targetfn"] = nil
                SoftAimData.emitOrig = nil
                SoftAimData.emitTargetFn = nil
                SoftAimData.emitHooked = false
            end)
        end
    end
    pcall(function()
        if Buttons.softAimToggle and Buttons.softAimToggle.updateSwitch then
            Buttons.softAimToggle.updateSwitch(state, true)
        end
    end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- OLD aim implementation (exact v2.lua RayCast hook aim)
-- ──────────────────────────────────────────────────────────────────────────────
local function createOldSoftAimHook()
    return function(origin, direction, distance, ignoreList, ...)
        local original = SoftAimData.oldOrig
        if not original then return end

        local myTeam = player.Team
        local myChar = player.Character
        if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then
            return original(origin, direction, distance, ignoreList, ...)
        end
        local myRoot = myChar.HumanoidRootPart

        local callerEnv = getfenv(2)
        local shouldModify = false
        if callerEnv and callerEnv.script then
            local scriptName = tostring(callerEnv.script)
            if scriptName == "BulletEmitter" or scriptName == "Basic" then
                shouldModify = true
            end
        end

        if shouldModify then
            local now = tick()
            local maxRange = 1200

            if now - Timers.lastTargetScan > Config.TARGET_CACHE_TIME then
                Timers.lastTargetScan = now
                scanTargets(myTeam)
            end

            local selectedTarget = findBestTarget(origin, myRoot, myChar, maxRange)
            if selectedTarget then
                local targetHead = selectedTarget:FindFirstChild("Head")
                local targetPos = targetHead and targetHead.Position or selectedTarget.HumanoidRootPart.Position
                local newDirection = (targetPos - origin).Unit
                local fullDistance = math.min((targetPos - origin).Magnitude, 10000)

                local modifiedIgnoreList = ignoreList and table.clone(ignoreList) or {}
                return original(origin, newDirection, fullDistance, modifiedIgnoreList, ...)
            end
        end

        return original(origin, direction, distance, ignoreList, ...)
    end
end

toggleOldSoftAim = function(state)
    State.oldSoftAimEnabled = state
    if state then
        if State.softAimEnabled then
            toggleSoftAim(false)
        end
        SoftAimData.settings.Enabled = true
        if not SoftAimData.oldHooked then
            pcall(function()
                local RaycastModule = require(game:GetService("ReplicatedStorage").Module.RayCast)
                local targetFn = RaycastModule.RayIgnoreNonCollideWithIgnoreList
                local hookFn = createOldSoftAimHook()

                local realOrig
                if type(hookfunction) == "function" then
                    realOrig = hookfunction(targetFn, hookFn)
                else
                    realOrig = targetFn
                    RaycastModule.RayIgnoreNonCollideWithIgnoreList = hookFn
                end

                _G["__sai_old_orig"] = realOrig
                _G["__sai_old_targetfn"] = targetFn

                SoftAimData.oldOrig = realOrig
                SoftAimData.oldTargetFn = targetFn
                SoftAimData.oldHooked = true
            end)
        end
    else
        SoftAimData.settings.Enabled = false
        if SoftAimData.oldHooked and SoftAimData.oldTargetFn and SoftAimData.oldOrig then
            pcall(function()
                if type(hookfunction) == "function" then
                    hookfunction(SoftAimData.oldTargetFn, SoftAimData.oldOrig)
                else
                    local RaycastModule = require(game:GetService("ReplicatedStorage").Module.RayCast)
                    RaycastModule.RayIgnoreNonCollideWithIgnoreList = SoftAimData.oldOrig
                end
                _G["__sai_old_orig"] = nil
                _G["__sai_old_targetfn"] = nil
                SoftAimData.oldOrig = nil
                SoftAimData.oldTargetFn = nil
                SoftAimData.oldHooked = false
            end)
        end
    end
    pcall(function()
        if Buttons.oldSoftAimToggle and Buttons.oldSoftAimToggle.updateSwitch then
            Buttons.oldSoftAimToggle.updateSwitch(state, true)
        end
    end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Volcano Lava trigger — broad workspace scan + getconnections approach
-- ──────────────────────────────────────────────────────────────────────────────
local function triggerVolcanoLava()
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end

    -- Collect ALL character BaseParts so every part can fake-touch lava
    local charParts = {root}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then charParts[#charParts + 1] = p end
    end

    -- Broad search: every BasePart in workspace whose name hints at lava/volcano
    local lavaKeywords = {"lava", "volcano", "heat", "magma", "lavafun", "lavatouch"}
    local lavaParts = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            for _, kw in ipairs(lavaKeywords) do
                if n:find(kw, 1, true) then
                    lavaParts[#lavaParts + 1] = obj
                    break
                end
            end
        end
    end

    if #lavaParts == 0 then
        pcall(function()
            local Notification = require(game:GetService("ReplicatedStorage").Game.Notification)
            Notification.new({Text = "No lava parts found in workspace!", Duration = 3})
        end)
        return
    end

    for _, lavaPart in ipairs(lavaParts) do
        -- Approach A: firetouchinterest on EVERY character part (not just root)
        if type(firetouchinterest) == "function" then
            for _, cp in ipairs(charParts) do
                pcall(firetouchinterest, cp, lavaPart, 0)
                pcall(firetouchinterest, cp, lavaPart, 1)  -- also fire TouchEnded then re-touch
                pcall(firetouchinterest, cp, lavaPart, 0)
            end
        end

        -- Approach B: getconnections — directly invoke Touched handlers
        -- This bypasses physics entirely; works even when firetouchinterest fails
        if type(getconnections) == "function" then
            pcall(function()
                local conns = getconnections(lavaPart.Touched)
                for _, conn in ipairs(conns) do
                    if conn.Function then
                        for _, cp in ipairs(charParts) do
                            pcall(conn.Function, cp)
                        end
                    end
                end
            end)
        end
    end

    -- Approach C: scan ReplicatedStorage for any RemoteEvent with lava/volcano name
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("lava") or n:find("volcano") or n:find("heat") or n:find("magma") then
                pcall(function() obj:FireServer() end)
                pcall(function() obj:FireServer(root) end)
            end
        end
    end

    -- Play any Sounds found in or near lava parts (fix audio not triggering)
    for _, lavaPart in ipairs(lavaParts) do
        for _, obj in ipairs(lavaPart:GetDescendants()) do
            if obj:IsA("Sound") then pcall(function() obj:Play() end) end
        end
        if lavaPart.Parent then
            for _, obj in ipairs(lavaPart.Parent:GetDescendants()) do
                if obj:IsA("Sound") then pcall(function() obj:Play() end) end
            end
        end
    end

    print("Lava trigger fired on " .. #lavaParts .. " part(s)")
    pcall(function()
        local Notification = require(game:GetService("ReplicatedStorage").Game.Notification)
        Notification.new({Text = "Triggered Lava", Duration = 3})
    end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Museum robbery auto-solver implementation (grouped to bypass Luau register limit)
-- ──────────────────────────────────────────────────────────────────────────────
local Museum = {
    puzzle = nil,
    flow = nil,
    event = nil,
    lastFlowId = nil
}

Museum.ACTION = {
    DYNAMITE = "ljszusl6",
    ITEM_GRAB = "r6vzxd5g",
    LEVER = "jgl4ejzf"
}

function Museum.getPuzzleState()
    if not Museum.puzzle then
        local gameFolder = ReplicatedStorage:FindFirstChild("Game")
        local robberyFolder = gameFolder and gameFolder:FindFirstChild("Robbery")
        local module = robberyFolder and robberyFolder:FindFirstChild("PuzzleFlow")
        if not module then return nil end

        local ok, puzzle = pcall(require, module)
        if not ok or type(puzzle) ~= "table" or type(puzzle.Init) ~= "function" then
            return nil
        end
        Museum.puzzle = puzzle
    end

    if Museum.flow and Museum.event and Museum.event.Parent then
        return Museum.flow, Museum.event
    end

    local function inspect(fn)
        if type(fn) ~= "function" then return end
        for i = 1, 20 do
            local ok, name, value = pcall(debug.getupvalue, fn, i)
            if not ok or name == nil then break end
            if type(value) == "table"
                and type(value.SetGrid) == "function"
                and type(value.Draw) == "function"
            then
                Museum.flow = value
            elseif typeof(value) == "Instance" and value:IsA("RemoteEvent") then
                Museum.event = value
            end
        end
    end

    inspect(Museum.puzzle.Init)
    if Museum.flow then inspect(Museum.flow.OnConnection) end
    return Museum.flow, Museum.event
end

function Museum.findEvent()
    local _, event = Museum.getPuzzleState()
    return event
end

function Museum.solveFlow(grid)
    if type(grid) ~= "table" or type(grid[1]) ~= "table" then return nil end

    local height, width = #grid, #grid[1]
    local endpoints = {}
    for y = 1, height do
        if type(grid[y]) ~= "table" or #grid[y] ~= width then return nil end
        for x = 1, width do
            local value = grid[y][x]
            if type(value) ~= "number" then return nil end
            if value >= 0 then
                endpoints[value] = endpoints[value] or {}
                endpoints[value][#endpoints[value] + 1] = {x, y}
            end
        end
    end

    local pairList = {}
    for id, points in pairs(endpoints) do
        if #points ~= 2 then return nil end
        pairList[#pairList + 1] = {id = id, start = points[1], goal = points[2]}
    end
    table.sort(pairList, function(a, b) return a.id < b.id end)

    local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
    local occupied, solution, occupiedCount = {}, {}, 0
    local function key(x, y)
        return (y - 1) * width + x
    end

    local function candidates(pair)
        local paths = {}
        local path = {{pair.start[1], pair.start[2]}}
        local seen = {[key(pair.start[1], pair.start[2])] = true}

        local function walk(x, y)
            -- ponytail: cap path candidates; raise only if larger museum grids prove it necessary.
            if #paths >= 256 then return end
            if x == pair.goal[1] and y == pair.goal[2] then
                local copy = table.create(#path)
                for i, point in ipairs(path) do copy[i] = {point[1], point[2]} end
                paths[#paths + 1] = copy
                return
            end

            for _, direction in ipairs(directions) do
                local nextX, nextY = x + direction[1], y + direction[2]
                local nextKey = key(nextX, nextY)
                if nextX >= 1 and nextX <= width
                    and nextY >= 1 and nextY <= height
                    and not seen[nextKey]
                    and not occupied[nextKey]
                then
                    local value = grid[nextY][nextX]
                    if value < 0 or (nextX == pair.goal[1] and nextY == pair.goal[2]) then
                        seen[nextKey] = true
                        path[#path + 1] = {nextX, nextY}
                        walk(nextX, nextY)
                        path[#path] = nil
                        seen[nextKey] = nil
                    end
                end
            end
        end

        walk(pair.start[1], pair.start[2])
        table.sort(paths, function(a, b) return #a < #b end)
        return paths
    end

    local function search(remaining)
        if #remaining == 0 then
            return occupiedCount == width * height
        end

        local selectedIndex, selectedPaths
        for index, pair in ipairs(remaining) do
            local paths = candidates(pair)
            if #paths == 0 then return false end
            if not selectedPaths or #paths < #selectedPaths then
                selectedIndex, selectedPaths = index, paths
            end
        end

        local pair = table.remove(remaining, selectedIndex)
        for _, path in ipairs(selectedPaths) do
            for _, point in ipairs(path) do
                occupied[key(point[1], point[2])] = true
            end
            occupiedCount += #path
            solution[pair.id] = path

            if search(remaining) then return true end

            solution[pair.id] = nil
            occupiedCount -= #path
            for _, point in ipairs(path) do
                occupied[key(point[1], point[2])] = nil
            end
        end

        table.insert(remaining, selectedIndex, pair)
        return false
    end

    local remaining = table.clone(pairList)
    if not search(remaining) then return nil end

    local solved = table.create(height)
    for y = 1, height do solved[y] = table.clone(grid[y]) end
    for id, path in pairs(solution) do
        for _, point in ipairs(path) do
            solved[point[2]][point[1]] = id
        end
    end
    return solved
end

do
    local check = Museum.solveFlow({
        {0, -1, 1},
        {-1, -1, 1},
        {0, -1, -1}
    })
    assert(check and check[2][2] >= 0, "Museum flow solver self-check failed")
end

function Museum.solveActiveFlow()
    local flow = Museum.getPuzzleState()
    if not flow
        or not flow.IsOpen
        or flow.FlowId == nil
        or flow.FlowId == Museum.lastFlowId
        or type(flow.GridClean) ~= "table"
        or type(flow.OnConnection) ~= "function"
    then
        return false
    end

    local solved = Museum.solveFlow(flow.GridClean)
    if not solved then return false end

    flow.Grid = solved
    pcall(flow.Draw, flow)
    if not pcall(flow.OnConnection) then return false end
    Museum.lastFlowId = flow.FlowId
    return true
end

function Museum.placeDynamiteNow(event)
    event = event or Museum.findEvent()
    if not event then return 0 end

    local placed = 0
    for _, node in ipairs(Services.CollectionService:GetTagged("Museum_DynamiteNode")) do
        local arm = node.Parent and node.Parent:FindFirstChild("Arm")
        if arm and arm.Transparency < 0.5 then
            local ok = pcall(event.FireServer, event, Museum.ACTION.DYNAMITE, node)
            if ok then placed += 1 end
        end
    end
    return placed
end

function Museum.runSolverStep()
    Museum.solveActiveFlow()

    local event = Museum.findEvent()
    if not event then return end

    Museum.placeDynamiteNow(event)
    task.wait(0.3)

    for _, lever in ipairs(Services.CollectionService:GetTagged("Museum_Lever")) do
        pcall(function()
            if lever.Reflectance < 0.15 then
                event:FireServer(Museum.ACTION.LEVER, lever)
            end
        end)
    end

    task.wait(0.3)

    for _, item in ipairs(Services.CollectionService:GetTagged("Museum_Item")) do
        pcall(function()
            local hidePart
            if item.Name == "DonutNode" then
                hidePart = item.Parent and item.Parent:FindFirstChild("Model")
                    and item.Parent.Model:FindFirstChild("Bread")
            elseif item.Name == "MummyNode" then
                hidePart = item.Parent and item.Parent:FindFirstChild("Glass")
            end
            if ((hidePart or item).Transparency or 0) < 0.999 then
                event:FireServer(Museum.ACTION.ITEM_GRAB, item)
            end
        end)
    end
end

task.spawn(function()
    while not State.killed do
        task.wait(1.5)
        if State.autoSolveMuseum then
            pcall(Museum.runSolverStep)
        end
    end
end)

local function toggleAutoSolveMuseum(state)
    State.autoSolveMuseum = state
    if state then
        Museum.lastFlowId = nil
        task.spawn(pcall, Museum.runSolverStep)
    end
    if Buttons.museumToggle and Buttons.museumToggle.updateSwitch then
        Buttons.museumToggle.updateSwitch(state, true)
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Noclip: disables collision on every character part every Stepped frame
-- ──────────────────────────────────────────────────────────────────────────────
local function cacheNoclipCharacter(character)
    if Connections.noclipAdded then
        Connections.noclipAdded:Disconnect()
        Connections.noclipAdded = nil
    end
    for part, canCollide in pairs(Cache.noclipParts) do
        if part.Parent then part.CanCollide = canCollide end
    end
    table.clear(Cache.noclipParts)
    Cache.noclipCharacter = character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then Cache.noclipParts[part] = part.CanCollide end
    end
    Connections.noclipAdded = character.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then Cache.noclipParts[part] = part.CanCollide end
    end)
end

local function toggleNoclip(state)
    State.noclipEnabled = state
    if state then
        cacheNoclipCharacter(player.Character)
        if not Connections.noclip then
            Connections.noclip = Services.RunService.Stepped:Connect(function()
                if Cache.noclipCharacter ~= player.Character then
                    cacheNoclipCharacter(player.Character)
                end
                for part in pairs(Cache.noclipParts) do
                    if part.Parent then
                        if part.CanCollide then part.CanCollide = false end
                    else
                        Cache.noclipParts[part] = nil
                    end
                end
            end)
        end
    else
        if Connections.noclip then
            Connections.noclip:Disconnect()
            Connections.noclip = nil
        end
        cacheNoclipCharacter(nil)
    end
    pcall(function()
        if Buttons.noclipToggle and Buttons.noclipToggle.updateSwitch then
            Buttons.noclipToggle.updateSwitch(state, true)
        end
    end)
end

local function safeGet(obj, prop)
    if not obj then return nil end
    local s, v = pcall(function() return obj[prop] end)
    return s and v or nil
end
local function safeCall(obj, method, ...)
    if not obj then return nil end
    local args = {...}
    local s, v = pcall(function() return obj[method](obj, unpack(args)) end)
    return s and v or nil
end
local function isValid(obj)
    if not obj then return false end
    local s, p = pcall(function() return obj.Parent end)
    return s and p ~= nil
end
local function waterBypassLoop()

    local ok, packet = pcall(function()
        Cache.vehicleUtils = Cache.vehicleUtils or require(ReplicatedStorage.Vehicle.VehicleUtils)
        return Cache.vehicleUtils.GetLocalVehiclePacket()
    end)
    if not ok or not packet or packet.__ClassName ~= "JetSki" then return end

    local sensor = packet.BuoyancySensor
    local vectorForce = packet.VectorForce
    local enginePart = packet.EnginePart
    if not sensor or sensor.TouchingSurface or not vectorForce or not enginePart then return end

    pcall(function()
        local force = vectorForce.Force
        local throttle = force.Z < 0 and math.clamp(-force.Z / 1800, 0, 1)
            or -math.clamp(force.Z / 300, 0, 1)
        local fullForce = throttle >= 0 and -6000 * throttle or -1000 * throttle
        vectorForce.Force = Vector3.new(force.X, force.Y, fullForce)
        if math.abs(throttle) > 0.01 then
            local forward = enginePart.CFrame.LookVector
            local velocity = enginePart.AssemblyLinearVelocity
            local speed = 90 * throttle
            enginePart.AssemblyLinearVelocity = Vector3.new(forward.X * speed, velocity.Y, forward.Z * speed)
        end
    end)
end
local function toggleWaterBypass(state)
    State.waterBypassEnabled = state
    if state then
        if not Connections.waterBypass then
            Connections.waterBypass = Services.RunService.RenderStepped:Connect(waterBypassLoop)
        end
    else
        if Connections.waterBypass then
            Connections.waterBypass:Disconnect()
            Connections.waterBypass = nil
        end
    end
    pcall(function()
        if Buttons.waterToggle and Buttons.waterToggle.updateSwitch then
            Buttons.waterToggle.updateSwitch(state, true)
        end
    end)
end
local HAZARD_TAGS = {"BarbedWireClient", "BarbedWire", "BossRoomLaser", "DartDispenser", "Laser", "Lasers", "LaserBeam", "LaserTrap", "MilitaryLaser", "MilitaryLasers", "RoadSpike", "Spike", "TombSpike"}
local HAZARD_NAME_WORDS = {"laser", "barbed", "spike", "dart"}
local HAZARD_IGNORED_PATH_WORDS = {"cosmetic", "decorative"}

local function isInsideHazardFolder(obj)
    local current = obj
    while isValid(current) and current ~= Services.Workspace do
        local name = string.lower(safeGet(current, "Name") or "")
        local parent = safeGet(current, "Parent")
        if name == "darts"
            or (name == "lights" and string.lower(safeGet(parent, "Name") or "") == "museum")
        then
            return true
        end
        current = parent
    end
    return false
end

local function lockHazardPart(part)
    if not part:IsA("BasePart") then return end
    Cache.hazards.touchLocks = Cache.hazards.touchLocks or {}
    if not Cache.hazards.touchLocks[part] then
        local original = part.CanTouch
        local connection = part:GetPropertyChangedSignal("CanTouch"):Connect(function()
            if State.laserRemoverEnabled and part.Parent and part.CanTouch then
                part.CanTouch = false
            end
        end)
        Cache.hazards.touchLocks[part] = {connection = connection, original = original}
    end
    part.CanTouch = false
end

local function neutralizeHazard(obj)
    if not isValid(obj) then return end
    if Cache.hazards.processed[obj] then return end
    Cache.hazards.processed[obj] = true

    task.defer(function()
        pcall(function()
            if obj:IsA("BasePart") then lockHazardPart(obj) end

            local descendants = obj:GetDescendants()
            for i = 1, #descendants do
                local child = descendants[i]
                Cache.hazards.processed[child] = true
                if i % 100 == 0 then task.wait() end
                if child:IsA("BasePart") then lockHazardPart(child) end
            end
        end)
    end)
end

local function isHazardousObject(obj)
    local name = safeGet(obj, "Name")
    if not name then return false end

    local nameLower = string.lower(name)
    local parent = safeGet(obj, "Parent")
    if nameLower == "lights"
        and string.lower(safeGet(parent, "Name") or "") == "museum"
    then
        return true
    end

    local matched = false
    for _, word in ipairs(HAZARD_NAME_WORDS) do
        if string.find(nameLower, word, 1, true) then
            matched = true
            break
        end
    end
    if not matched then return false end

    local path = string.lower(parent and parent:GetFullName() or "")
    for _, word in ipairs(HAZARD_IGNORED_PATH_WORDS) do
        if string.find(path, word, 1, true) then
            return false
        end
    end
    return true
end

local function enqueueHazard(obj)
    if not isValid(obj) or Cache.hazards.enqueued[obj] then return end
    Cache.hazards.queueTail += 1
    Cache.hazards.queue[Cache.hazards.queueTail] = obj
    Cache.hazards.enqueued[obj] = true
end

local function scanTaggedHazards()
    pcall(function()
        for _, tag in ipairs(HAZARD_TAGS) do
            for _, obj in ipairs(Services.CollectionService:GetTagged(tag)) do
                enqueueHazard(obj)
            end
        end
    end)
end

local function scanNamedHazards()
    pcall(function()
        local allObjects = Services.Workspace:GetDescendants()
        local total = #allObjects
        for idx = 1, total do
            if idx % 100 == 0 then task.wait(0) end
            local obj = allObjects[idx]
            if isHazardousObject(obj) then enqueueHazard(obj) end
        end
    end)
end

local function processHazardQueue()
    if State.hazardProcessingRunning then return end
    State.hazardProcessingRunning = true
    task.spawn(function()
        while State.laserRemoverEnabled and not State.killed do
            task.wait(0.15)
            for _ = 1, Config.HAZARD_BATCH_SIZE do
                local head = Cache.hazards.queueHead
                if head > Cache.hazards.queueTail then break end
                local obj = Cache.hazards.queue[head]
                Cache.hazards.queue[head] = nil
                Cache.hazards.queueHead = head + 1
                pcall(function()
                    Cache.hazards.enqueued[obj] = nil
                    if isValid(obj) then neutralizeHazard(obj) end
                end)
            end
            if Cache.hazards.queueHead > Cache.hazards.queueTail then
                table.clear(Cache.hazards.queue)
                Cache.hazards.queueHead = 1
                Cache.hazards.queueTail = 0
            end
        end
        State.hazardProcessingRunning = false
    end)
end

local function monitorNewHazards()
    if Connections.workspaceDescendant and Connections.workspaceDescendant.Connected then return end
    Connections.workspaceDescendant = Services.Workspace.DescendantAdded:Connect(function(obj)
        if not State.laserRemoverEnabled then return end
        task.defer(function()
            if isHazardousObject(obj) or isInsideHazardFolder(obj) then enqueueHazard(obj) end
        end)
    end)
end

local DART_DAMAGE_SINK = {FireServer = function() end}

local function suppressDartDamage()
    Cache.hazards.dartControllers = Cache.hazards.dartControllers or {}
    local binder = nil
    local ok = pcall(function()
        binder = require(ReplicatedStorage.Game.DartDispenser.DartDispenserBinder)
    end)
    if not ok or not binder then return end

    local function suppress(controller)
        if not controller or Cache.hazards.dartControllers[controller] then return end
        local remote = controller._damageRemote
        if typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
            Cache.hazards.dartControllers[controller] = remote
            controller._damageRemote = DART_DAMAGE_SINK
        end
    end

    for controller in binder:GetAllSet() do suppress(controller) end
    if not Connections.dartDamageBinder then
        Connections.dartDamageBinder = binder:GetClassAddedSignal():Connect(function(controller)
            if State.laserRemoverEnabled then task.defer(suppress, controller) end
        end)
    end
end

local function restoreDartDamage()
    if Connections.dartDamageBinder then
        Connections.dartDamageBinder:Disconnect()
        Connections.dartDamageBinder = nil
    end
    for controller, remote in pairs(Cache.hazards.dartControllers or {}) do
        pcall(function()
            if controller._damageRemote == DART_DAMAGE_SINK then
                controller._damageRemote = remote
            end
        end)
    end
    Cache.hazards.dartControllers = {}
end

local function restoreHazardTouchLocks()
    for part, lock in pairs(Cache.hazards.touchLocks or {}) do
        pcall(function() lock.connection:Disconnect() end)
        pcall(function()
            if part.Parent then part.CanTouch = lock.original end
        end)
    end
    Cache.hazards.touchLocks = {}
end

local function toggleLaserRemover(state)
    State.laserRemoverEnabled = state
    if state then
        suppressDartDamage()
        scanTaggedHazards()
        scanNamedHazards()
        processHazardQueue()
        monitorNewHazards()
    else
        restoreDartDamage()
        restoreHazardTouchLocks()
        if Connections.workspaceDescendant then
            Connections.workspaceDescendant:Disconnect()
            Connections.workspaceDescendant = nil
        end
    end
    pcall(function()
        if Buttons.laserToggle and Buttons.laserToggle.updateSwitch then
            Buttons.laserToggle.updateSwitch(state, true)
        end
    end)
end
local destructibleTriggerRunning = false
local SMILEY_PIECE_LIMIT = 96

local function collectSmileyParts(inst, parts, seen)
    if not inst then return end
    for _, part in ipairs(inst:GetDescendants()) do
        if #parts >= SMILEY_PIECE_LIMIT * 3 then return end
        if part:IsA("BasePart") and part.Transparency < 1 and not seen[part] then
            seen[part] = true
            parts[#parts + 1] = part
        end
    end
end

local function buildSmileyPoints(root)
    local up = Vector3.new(0, 1, 0)
    local camera = Services.Workspace.CurrentCamera
    local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
    local flatForward = Vector3.new(look.X, 0, look.Z)
    if flatForward.Magnitude < 0.01 then
        local rootLook = root.CFrame.LookVector
        flatForward = Vector3.new(rootLook.X, 0, rootLook.Z)
    end
    flatForward = flatForward.Magnitude >= 0.01 and flatForward.Unit or Vector3.new(0, 0, -1)
    local center = root.Position + up * 80 + flatForward * 90
    local right = flatForward:Cross(up).Unit
    local points = {}
    local function add(x, y)
        points[#points + 1] = center + right * x + up * y
    end

    for i = 0, 55 do
        local angle = math.pi * 2 * i / 56
        add(math.cos(angle) * 68, math.sin(angle) * 68)
    end
    for _, eyeX in ipairs({-27, 27}) do
        for i = 0, 9 do
            local angle = math.pi * 2 * i / 10
            add(eyeX + math.cos(angle) * 10, 24 + math.sin(angle) * 10)
        end
    end
    for i = 0, 19 do
        local angle = math.rad(205 + 130 * i / 19)
        add(math.cos(angle) * 48, math.sin(angle) * 32 - 12)
    end
    return points
end

local function arrangeDestructibleSmiley(parts)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or #parts == 0 then return 0 end

    local old = Services.Workspace:FindFirstChild("__JB_DestructibleSmiley")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "__JB_DestructibleSmiley"
    folder.Parent = Services.Workspace

    local points = buildSmileyPoints(root)
    local used = math.min(#parts, #points)
    table.sort(parts, function(a, b)
        return a.Size.Magnitude < b.Size.Magnitude
    end)
    for index = 1, used do
        local part = parts[index]
        pcall(function()
            part:BreakJoints()
            part.Parent = folder
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0
            part.CFrame = CFrame.new(points[index]) * CFrame.Angles(
                math.rad(math.random(-20, 20)),
                math.rad(math.random(0, 359)),
                math.rad(math.random(-20, 20))
            )
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    task.delay(8, function()
        if not folder.Parent then return end
        for _, part in ipairs(folder:GetChildren()) do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.CanCollide = true
                part.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
            end
        end
    end)
    task.delay(20, function()
        if folder.Parent then folder:Destroy() end
    end)
    return used
end

local function triggerAllDestructibles(makeSmiley)
    if destructibleTriggerRunning then return 0, 0 end
    destructibleTriggerRunning = true
    local triggered = 0
    local smileyParts, smileySeen = {}, {}

    local ok, err = pcall(function()
        local spawnFolder = Services.Workspace:FindFirstChild("DestructibleSpawn")
        if not spawnFolder then return end
        local binder = nil
        pcall(function()
            binder = require(ReplicatedStorage.Game.Destructible.DestructibleBinder)
        end)

        local spawnPoints = spawnFolder:GetChildren()
        for index, spawnPoint in ipairs(spawnPoints) do
            if State.killed then break end
            pcall(function()
                local remote = spawnPoint:FindFirstChild("DestructibleCollisionBroadcast")
                if not remote or not remote:IsA("RemoteEvent") then return end

                local controller = nil
                if binder then
                    pcall(function() controller = binder:Get(spawnPoint) end)
                end
                local instValue = spawnPoint:FindFirstChild("DestructibleInstance")
                local inst = instValue and instValue.Value or nil
                if makeSmiley and inst then
                    collectSmileyParts(inst, smileyParts, smileySeen)
                end

                local hitPosition = nil
                local spawnValue = safeGet(spawnPoint, "Value")
                if typeof(spawnValue) == "CFrame" then
                    hitPosition = spawnValue.Position
                elseif typeof(spawnValue) == "Vector3" then
                    hitPosition = spawnValue
                elseif inst and inst.PrimaryPart then
                    hitPosition = inst.PrimaryPart.Position
                end
                if not hitPosition then return end

                if controller and inst then
                    controller._wasTouched = true
                end
                if pcall(function() remote:FireServer(hitPosition) end) then
                    triggered += 1
                end
                if controller and inst then
                    local localController, localHitPosition = controller, hitPosition
                    task.spawn(function()
                        pcall(localController._handleHitPosition, localController, localHitPosition)
                    end)
                end
            end)
            if index % 250 == 0 then
                Services.RunService.Heartbeat:Wait()
            end
        end
    end)

    local smileyCount = 0
    if makeSmiley and #smileyParts > 0 then
        smileyCount = math.min(#smileyParts, SMILEY_PIECE_LIMIT)
        task.spawn(function()
            task.wait(0.15)
            arrangeDestructibleSmiley(smileyParts)
        end)
    end

    destructibleTriggerRunning = false
    if not ok then warn("[Destructibles] " .. tostring(err)) end
    return triggered, smileyCount
end

local function getWaypointFolder()
    local folders = {"WaypointMarker", "Waypoints", "Waypoint"}
    for _, name in ipairs(folders) do
        local folder = safeCall(Services.Workspace, "FindFirstChild", name)
        if isValid(folder) then
            return folder
        end
    end
    return nil
end
local function resolveVehicleModel(candidate)
    if not isValid(candidate) then return nil end
    local current = candidate
    if safeCall(current, "IsA", "BasePart") then
        current = safeCall(current, "FindFirstAncestorWhichIsA", "Model")
    end
    local best = safeCall(current, "IsA", "Model") and current or nil
    while isValid(current) and current ~= Services.Workspace do
        if safeCall(current, "IsA", "Model") then
            local hasVehicleShape =
                safeCall(current, "FindFirstChild", "Physics") or
                safeCall(current, "FindFirstChild", "BoundingBox") or
                safeCall(current, "FindFirstChild", "Engine") or
                safeCall(current, "FindFirstChildWhichIsA", "VehicleSeat", true)
            if hasVehicleShape then
                best = current
            end
        end
        current = safeGet(current, "Parent")
    end
    return best
end
local function getVehicle()
    local char = safeGet(player, "Character")
    if not isValid(char) then return nil end
    local hum = safeCall(char, "FindFirstChild", "Humanoid")
    if hum then
        local seat = safeGet(hum, "SeatPart")
        if isValid(seat) then
            local veh = resolveVehicleModel(seat)
            if isValid(veh) then
                return veh
            end
        end
    end
    local root = safeCall(char, "FindFirstChild", "HumanoidRootPart")
    if not isValid(root) then return nil end
    local success, children = pcall(function() return root:GetChildren() end)
    if not success then return nil end
    for i = 1, #children do
        local obj = children[i]
        if not isValid(obj) then continue end
        local className = safeGet(obj, "ClassName")
        if className == "Weld" or className == "ManualWeld" or className == "Motor6D" or className == "WeldConstraint" then
            local p0 = safeGet(obj, "Part0")
            local p1 = safeGet(obj, "Part1")
            local otherPart = nil
            if isValid(p0) and isValid(char) then
                local s, isDesc = pcall(function() return p0:IsDescendantOf(char) end)
                if s and not isDesc then
                    otherPart = p0
                end
            end
            if not otherPart and isValid(p1) and isValid(char) then
                local s, isDesc = pcall(function() return p1:IsDescendantOf(char) end)
                if s and not isDesc then
                    otherPart = p1
                end
            end
            if isValid(otherPart) then
                local veh = safeCall(otherPart, "FindFirstAncestorWhichIsA", "Model")
                if isValid(veh) then
                    return resolveVehicleModel(veh) or veh
                end
            end
        end
    end
    return nil
end
local function getRoot(veh)
    if not isValid(veh) then return nil end
    local parts = {"BoundingBox", "Engine", "HumanoidRootPart"}
    for _, name in ipairs(parts) do
        local part = safeCall(veh, "FindFirstChild", name)
        if isValid(part) then
            return part
        end
    end
    local primary = safeGet(veh, "PrimaryPart")
    if isValid(primary) then return primary end
    local part = safeCall(veh, "FindFirstChildWhichIsA", "BasePart")
    if isValid(part) then return part end
    return nil
end
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = {}
local obstacleParams = RaycastParams.new()
obstacleParams.FilterType = Enum.RaycastFilterType.Exclude
obstacleParams.FilterDescendantsInstances = {}
local function getGroundHeightAhead(currentPos, direction, distance)
    local ignore = AutopilotData.groundIgnore
    table.clear(ignore)
    if player.Character then ignore[#ignore + 1] = player.Character end
    if isValid(AutopilotData.currentVehicle) then
        ignore[#ignore + 1] = AutopilotData.currentVehicle
    end
    local vehicles = workspace:FindFirstChild("Vehicles")
    if vehicles then ignore[#ignore + 1] = vehicles end
    groundParams.FilterDescendantsInstances = ignore
    local s, result = pcall(function()
        local lookAheadPos = currentPos + (direction * distance)
        local origin = lookAheadPos + Vector3.new(0, 200, 0)
        local rayDirection = Vector3.new(0, -500, 0)
        local hit = Services.Workspace:Raycast(origin, rayDirection, groundParams)
        return hit and hit.Position.Y or 0
    end)
    return s and result or 0
end
local function getGroundBelow(position)
    local ignore = AutopilotData.groundIgnore
    table.clear(ignore)
    if player.Character then ignore[#ignore + 1] = player.Character end
    if isValid(AutopilotData.currentVehicle) then
        ignore[#ignore + 1] = AutopilotData.currentVehicle
    end
    local vehicles = workspace:FindFirstChild("Vehicles")
    if vehicles then ignore[#ignore + 1] = vehicles end
    groundParams.FilterDescendantsInstances = ignore
    local s, result, found = pcall(function()
        local origin = position + Vector3.new(0, 50, 0)
        local rayDirection = Vector3.new(0, -300, 0)
        local hit = Services.Workspace:Raycast(origin, rayDirection, groundParams)
        return hit and hit.Position.Y or 0, hit ~= nil
    end)
    return s and result or 0, s and found or false
end
local function checkObstaclesAround(fromPos, scanRadius, currentVehicle)
    local cache = AutopilotData.obstacleCache
    local now = tick()
    if cache.vehicle == currentVehicle
        and cache.position
        and now - cache.checkedAt < 0.12
        and (fromPos - cache.position).Magnitude < 35
    then
        return cache.hasObstacle, cache.top, cache.bottom
    end

    local s, hasObstacle, obstacleTopHeight, obstacleBottomHeight = pcall(function()
        local ignore = AutopilotData.obstacleIgnore
        table.clear(ignore)
        if isValid(currentVehicle) then ignore[#ignore + 1] = currentVehicle end
        if player.Character then ignore[#ignore + 1] = player.Character end
        obstacleParams.FilterDescendantsInstances = ignore
        local maxTopHeight = 0
        local minBottomHeight = math.huge
        local foundObstacle = false
        for _, horizontalDir in ipairs(AutopilotData.obstacleDirections) do
            local rayDir = horizontalDir * scanRadius
            for _, heightOffset in ipairs(AutopilotData.obstacleHeightOffsets) do
                local origin = fromPos + Vector3.new(0, heightOffset, 0)
                local hit = Services.Workspace:Raycast(origin, rayDir, obstacleParams)
                if hit then
                    foundObstacle = true
                    local hitY = hit.Position.Y
                    if hitY > maxTopHeight then
                        maxTopHeight = hitY
                    end
                    if hitY < minBottomHeight then
                        minBottomHeight = hitY
                    end
                end
            end
        end
        for verticalSign = -1, 1, 2 do
            local hit = Services.Workspace:Raycast(
                fromPos,
                Vector3.new(0, scanRadius * verticalSign, 0),
                obstacleParams
            )
            if hit then
                foundObstacle = true
                local hitY = hit.Position.Y
                if hitY > maxTopHeight then
                    maxTopHeight = hitY
                end
                if hitY < minBottomHeight then
                    minBottomHeight = hitY
                end
            end
        end
        if not foundObstacle then
            return false, 0, 0
        end
        return foundObstacle, maxTopHeight, minBottomHeight
    end)
    if not s then
        hasObstacle, obstacleTopHeight, obstacleBottomHeight = false, 0, 0
    end
    cache.checkedAt = now
    cache.position = fromPos
    cache.vehicle = currentVehicle
    cache.hasObstacle = hasObstacle
    cache.top = obstacleTopHeight
    cache.bottom = obstacleBottomHeight
    return hasObstacle, obstacleTopHeight, obstacleBottomHeight
end

local function clampValue(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function isInstanceA(obj, className)
    if not obj then return false end
    local s, result = pcall(function() return obj:IsA(className) end)
    return s and result
end

local function flatVector(vec)
    return Vector3.new(vec.X, 0, vec.Z)
end

local function flatUnit(vec, fallback)
    local flat = flatVector(vec)
    if flat.Magnitude > 0.001 then
        return flat.Unit
    end
    return fallback or Vector3.new(0, 0, -1)
end

local function flatDistance(a, b)
    return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function getObjectPosition(obj)
    if not isValid(obj) then return nil end
    if isInstanceA(obj, "BasePart") then
        return safeGet(obj, "Position")
    end
    if isInstanceA(obj, "Attachment") then
        return safeGet(obj, "WorldPosition")
    end
    if isInstanceA(obj, "Model") then
        local primary = safeGet(obj, "PrimaryPart")
        if isValid(primary) then
            return safeGet(primary, "Position")
        end
        local s, pivot = pcall(function() return obj:GetPivot() end)
        if s and pivot then
            return pivot.Position
        end
    end
    return nil
end

local function collectWaypointObjects(root)
    local results = {}
    if not isValid(root) then return results end
    if isInstanceA(root, "BasePart") or isInstanceA(root, "Attachment") or isInstanceA(root, "Model") then
        table.insert(results, root)
    end
    local s, descendants = pcall(function() return root:GetDescendants() end)
    if s and descendants then
        for _, obj in ipairs(descendants) do
            if isValid(obj) and (isInstanceA(obj, "BasePart") or isInstanceA(obj, "Attachment") or isInstanceA(obj, "Model")) then
                table.insert(results, obj)
            end
        end
    end
    return results
end

local function roadNameMatches(obj)
    local name = string.lower(safeGet(obj, "Name") or "")
    local parent = safeGet(obj, "Parent")
    local parentName = parent and string.lower(safeGet(parent, "Name") or "") or ""
    for _, keyword in ipairs(Config.roadNameKeywords) do
        if name:find(keyword, 1, true) or parentName:find(keyword, 1, true) then
            return true
        end
    end
    return false
end

local function addRoadCandidate(candidate, roads, seen)
    if not isValid(candidate) or not isInstanceA(candidate, "BasePart") or seen[candidate] then return end
    local size = safeGet(candidate, "Size")
    if not size or math.max(size.X, size.Z) < Config.minRoadPartSize then return end
    seen[candidate] = true
    table.insert(roads, candidate)
end

local function scanRoadParts()
    local now = tick()
    if now - RoadPilotData.lastRoadScan < Config.roadScanInterval then
        return RoadPilotData.roadParts
    end
    RoadPilotData.lastRoadScan = now
    local roads = {}
    local seen = {}

    for _, road in ipairs(RoadPilotData.roadParts) do
        addRoadCandidate(road, roads, seen)
    end

    pcall(function()
        for _, tag in ipairs(Config.roadTags) do
            for _, obj in ipairs(Services.CollectionService:GetTagged(tag)) do
                if #roads >= Config.maxRoadParts then break end
                if isInstanceA(obj, "BasePart") then
                    addRoadCandidate(obj, roads, seen)
                else
                    for _, child in ipairs(obj:GetDescendants()) do
                        if #roads >= Config.maxRoadParts then break end
                        addRoadCandidate(child, roads, seen)
                    end
                end
            end
        end
    end)
    
    if #roads == 0 or now - RoadPilotData.lastFullRoadScan >= 15 then
        RoadPilotData.lastFullRoadScan = now
        pcall(function()
            for _, obj in ipairs(Services.Workspace:GetDescendants()) do
                if #roads >= Config.maxRoadParts then break end
                if roadNameMatches(obj) then
                    addRoadCandidate(obj, roads, seen)
                end
            end
        end)
    end
    
    RoadPilotData.roadParts = roads
    return roads
end

local function projectPointToRoad(road, worldPoint, extraForward)
    local cf = safeGet(road, "CFrame")
    local size = safeGet(road, "Size")
    if not cf or not size then return nil end
    local localPoint = cf:PointToObjectSpace(worldPoint + (extraForward or Vector3.zero))
    local margin = math.min(4, math.max(1, math.min(size.X, size.Z) * 0.2))
    local halfX = math.max(0.5, (size.X * 0.5) - margin)
    local halfZ = math.max(0.5, (size.Z * 0.5) - margin)
    local clamped = Vector3.new(
        clampValue(localPoint.X, -halfX, halfX),
        (size.Y * 0.5) + Config.roadRideHeight,
        clampValue(localPoint.Z, -halfZ, halfZ)
    )
    return cf:PointToWorldSpace(clamped)
end

local function getRoadDirection(road, currentPos, destinationPos)
    local cf = safeGet(road, "CFrame")
    local size = safeGet(road, "Size")
    if not cf or not size then return nil end
    local axis = size.X >= size.Z and cf.RightVector or cf.LookVector
    axis = flatUnit(axis)
    local towardDestination = flatUnit(destinationPos - currentPos, axis)
    if axis:Dot(towardDestination) < 0 then
        axis = -axis
    end
    return axis
end

local function findBestRoadTarget(currentPos, destinationPos, vehCFrame)
    local roads = scanRoadParts()
    if not roads or #roads == 0 then return nil, nil end
    local routeDir = flatUnit(destinationPos - currentPos)
    local forward = flatUnit(vehCFrame.LookVector, routeDir)
    local bestRoad = nil
    local bestTarget = nil
    local bestScore = math.huge
    
    for _, road in ipairs(roads) do
        if isValid(road) then
            local closestPoint = projectPointToRoad(road, currentPos)
            if closestPoint then
                local distToRoad = flatDistance(currentPos, closestPoint)
                if distToRoad <= Config.roadSearchRadius then
                    local roadDir = getRoadDirection(road, currentPos, destinationPos)
                    if roadDir then
                        local leadPoint = projectPointToRoad(road, closestPoint, roadDir * Config.roadLookAhead)
                        if leadPoint then
                            local targetDir = flatUnit(leadPoint - currentPos, routeDir)
                            local towardScore = roadDir:Dot(routeDir)
                            local forwardScore = forward:Dot(targetDir)
                            local destinationScore = flatDistance(leadPoint, destinationPos) * 0.035
                            local turnPenalty = (1 - clampValue(forwardScore, -1, 1)) * 42
                            local routePenalty = (1 - clampValue(towardScore, -1, 1)) * 75
                            local heightPenalty = math.abs(leadPoint.Y - currentPos.Y) * 0.15
                            local score = (distToRoad * 0.9) + routePenalty + turnPenalty + destinationScore + heightPenalty
                            if score < bestScore then
                                bestScore = score
                                bestRoad = road
                                bestTarget = leadPoint
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget, bestRoad
end

local function scanForwardObstacle(currentPos, direction, veh)
    local s, hit = pcall(function()
        local char = player.Character
        if RoadPilotData.obstacleIgnoreRoads ~= RoadPilotData.roadParts
            or RoadPilotData.obstacleIgnoreVehicle ~= veh
            or RoadPilotData.obstacleIgnoreCharacter ~= char
        then
            local ignore = RoadPilotData.obstacleIgnore
            table.clear(ignore)
            if veh then ignore[#ignore + 1] = veh end
            if char then ignore[#ignore + 1] = char end
            for _, road in ipairs(RoadPilotData.roadParts) do
                if isValid(road) then
                    ignore[#ignore + 1] = road
                end
            end
            RoadPilotData.obstacleIgnoreRoads = RoadPilotData.roadParts
            RoadPilotData.obstacleIgnoreVehicle = veh
            RoadPilotData.obstacleIgnoreCharacter = char
        end
        obstacleParams.FilterDescendantsInstances = RoadPilotData.obstacleIgnore
        local origin = currentPos + Vector3.new(0, 4, 0)
        return Services.Workspace:Raycast(origin, direction * Config.obstacleBrakeDistance, obstacleParams)
    end)
    if not s or not hit then return false, Config.obstacleBrakeDistance end
    if RoadPilotData.currentRoad and hit.Instance and hit.Instance == RoadPilotData.currentRoad then
        return false, Config.obstacleBrakeDistance
    end
    return true, (hit.Position - currentPos).Magnitude
end

local function isGroundVehicle(veh)
    if not isValid(veh) then return false end
    local skel = veh:FindFirstChild("Skeleton")
    if skel and (skel:FindFirstChild("FricitorFront") or skel:FindFirstChild("FricitorBack")) then
        return true
    end
    local n = veh.Name:lower()
    return n:find("cruiser") or n:find("camaro") or n:find("jeep") or n:find("buggy") or n:find("pickup") ~= nil
end

local function calculateSmartDriveMotion(currentPos, vehCFrame, destinationPos, veh)
    local roadTarget, road = findBestRoadTarget(currentPos, destinationPos, vehCFrame)
    RoadPilotData.currentRoad = road
    local targetPos = roadTarget or destinationPos
    RoadPilotData.lastTarget = targetPos
    
    local forward = flatUnit(vehCFrame.LookVector, flatUnit(destinationPos - currentPos))
    local targetDir = flatUnit(targetPos - currentPos, forward)
    local steerDir = flatUnit(forward:Lerp(targetDir, Config.steeringResponsiveness), targetDir)
    local dot = clampValue(forward:Dot(targetDir), -1, 1)
    local turnAngle = math.deg(math.acos(dot))
    
    local distToDestination = flatDistance(currentPos, destinationPos)
    local desiredSpeed = Config.maxDriveSpeed
    if distToDestination < Config.approachSlowDistance then
        local approachAlpha = clampValue(distToDestination / Config.approachSlowDistance, 0, 1)
        desiredSpeed = Config.minDriveSpeed + ((Config.maxDriveSpeed - Config.minDriveSpeed) * approachAlpha)
    end
    
    local turnAlpha = clampValue(turnAngle / Config.turnSlowAngle, 0, 1)
    desiredSpeed = desiredSpeed * (1 - (turnAlpha * 0.68))
    desiredSpeed = math.max(Config.minDriveSpeed, desiredSpeed)
    
    local hasObstacle, obstacleDistance = scanForwardObstacle(currentPos, steerDir, veh)
    if hasObstacle then
        local brakeAlpha = clampValue(obstacleDistance / Config.obstacleBrakeDistance, 0, 1)
        desiredSpeed = math.min(desiredSpeed, Config.minDriveSpeed * brakeAlpha)
    end
    
    local smoothing = desiredSpeed < RoadPilotData.currentSpeed and Config.brakeSmoothing or Config.speedSmoothing
    RoadPilotData.currentSpeed = RoadPilotData.currentSpeed + ((desiredSpeed - RoadPilotData.currentSpeed) * smoothing)
    
    local groundHeight = roadTarget and (roadTarget.Y - Config.roadRideHeight) or getGroundBelow(currentPos)
    local desiredY = groundHeight + Config.roadRideHeight
    local verticalCorrection = clampValue((desiredY - currentPos.Y) * 0.12, -0.45, 0.45)
    local rawMoveDirection = steerDir + Vector3.new(0, verticalCorrection, 0)
    local moveDirection = rawMoveDirection.Magnitude > 0.001 and rawMoveDirection.Unit or steerDir
    local newRotation = CFrame.Angles(0, math.atan2(steerDir.X, steerDir.Z), 0)
    
    return moveDirection, newRotation, RoadPilotData.currentSpeed
end
local function getClosestWaypoint()
    local waypointFolder = getWaypointFolder()
    if not isValid(waypointFolder) then return nil, math.huge end
    if not isValid(AutopilotData.currentVehicle) then return nil, math.huge end
    local vehRoot = getRoot(AutopilotData.currentVehicle)
    if not isValid(vehRoot) then return nil, math.huge end
    local vehPos = safeGet(safeGet(vehRoot, "CFrame"), "Position")
    if not vehPos then return nil, math.huge end
    local pinned = AutopilotData.currentWaypoint
    if isValid(pinned) and safeGet(pinned, "Name") == "ArrestTarget" then
        local pinnedPos = getObjectPosition(pinned)
        if pinnedPos then return pinned, flatDistance(pinnedPos, vehPos) end
    end
    local candidates = collectWaypointObjects(waypointFolder)
    if not candidates or #candidates == 0 then return nil, math.huge end
    local closest = nil
    local closestDist = math.huge
    for i = 1, #candidates do
        local obj = candidates[i]
        if isValid(obj) then
            local pos = getObjectPosition(obj)
            if pos and vehPos then
                local xzDist = flatDistance(pos, vehPos)
                if xzDist < closestDist then
                    closest = obj
                    closestDist = xzDist
                end
            end
        end
    end
    return closest, closestDist
end
local function updateAutopilotGUI(state)
    pcall(function()
        if Buttons.autopilotToggle and Buttons.autopilotToggle.updateSwitch then
            Buttons.autopilotToggle.updateSwitch(state, true)
        end
    end)
end

AutopilotData.getLandingY = function(veh, currentPos)
    local groundY, found = getGroundBelow(currentPos)
    if not found or not isValid(veh) then return nil end
    local root = getRoot(veh)
    if not isValid(root) then return nil end
    local rootAboveBottom = Config.roadRideHeight
    local boxOk, boxCFrame, boxSize = pcall(function() return veh:GetBoundingBox() end)
    if boxOk then
        rootAboveBottom = root.Position.Y - (boxCFrame.Position.Y - boxSize.Y * 0.5)
    end
    return groundY + math.max(rootAboveBottom, Config.roadRideHeight) + 1, groundY
end

local function handleWaypointArrival(vehRoot, vehCFrame, currentPos)
    local landingY = AutopilotData.getLandingY(AutopilotData.currentVehicle, currentPos)
    if not landingY or not isValid(vehRoot) then return false end
    local success = pcall(function()
        local currentRotation = vehCFrame - vehCFrame.Position
        vehRoot.CFrame = CFrame.new(currentPos.X, landingY, currentPos.Z) * currentRotation
        vehRoot.AssemblyLinearVelocity = Vector3.zero
        vehRoot.AssemblyAngularVelocity = Vector3.zero
        AutopilotData.arrived = true
        State.flying = false
        State.autopilotEnabled = false
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        updateAutopilotGUI(false)
    end)
    return success
end
local function calculateVerticalAdjust(heightDifference)
    if heightDifference > 10 then
        return 0.4
    elseif heightDifference > 3 then
        return 0.2
    elseif heightDifference < -10 then
        return -0.4
    elseif heightDifference < -3 then
        return -0.2
    end
    return 0
end

local function calculateMoveDirection(currentPos, flatDirection, veh)
    local hasObstacle, obstacleTop, obstacleBottom = checkObstaclesAround(currentPos, Config.obstacleDetectionRadius, veh)
    local moveDirection
    local newRotation
    
    if hasObstacle then
        local obstacleHeight = obstacleTop - obstacleBottom
        if obstacleHeight >= 15 then
            if not State.isClimbing then
                State.isClimbing = true
            end
            newRotation = CFrame.Angles(math.rad(90), math.atan2(flatDirection.X, flatDirection.Z), 0)
            moveDirection = Vector3.new(0, 1, 0)
            return moveDirection, newRotation, true
        else
            if State.isClimbing then
                State.isClimbing = false
            end
        end
    else
        if State.isClimbing then
            State.isClimbing = false
        end
    end
    
    local groundAhead = getGroundHeightAhead(currentPos, flatDirection, Config.lookAheadDistance)
    local desiredHeight = groundAhead + Config.targetAltitude
    local heightDifference = desiredHeight - currentPos.Y
    newRotation = CFrame.Angles(0, math.atan2(flatDirection.X, flatDirection.Z), 0)
    local verticalAdjust = calculateVerticalAdjust(heightDifference)
    moveDirection = (flatDirection + Vector3.new(0, verticalAdjust, 0)).Unit
    
    return moveDirection, newRotation, false
end

local function flyToWaypoint(dt)
    local veh = getVehicle()
    if not isValid(veh) then
        AutopilotData.currentVehicle = nil
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        return
    end
    AutopilotData.currentVehicle = veh
    if tick() < AutopilotData.vehicleReadyAt then return end
    local vehRoot = getRoot(veh)
    if not isValid(vehRoot) then
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        return
    end
    AutopilotData.lastValidVehRoot = vehRoot
    local waypoint = getClosestWaypoint()
    if not isValid(waypoint) then
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        AutopilotData.currentWaypoint = nil
        State.isAtWaypoint = false
        return
    end
    if AutopilotData.currentWaypoint ~= waypoint then
        AutopilotData.currentWaypoint = waypoint
        State.isAtWaypoint = false
    end
    local vehCFrame = safeGet(vehRoot, "CFrame")
    if not vehCFrame then return end
    local currentPos = safeGet(vehCFrame, "Position")
    local waypointPos = getObjectPosition(waypoint)
    if not currentPos or not waypointPos then return end
    local progressNow = tick()
    if not AutopilotData.lastPosition
        or (currentPos - AutopilotData.lastPosition).Magnitude > 6
    then
        AutopilotData.lastPosition = currentPos
        AutopilotData.lastProgressAt = progressNow
    elseif progressNow - AutopilotData.lastProgressAt > 1.25 then
        AutopilotData.escapeUntil = progressNow + 0.75
        AutopilotData.lastProgressAt = progressNow
        warn("[Autopilot] Stuck; climbing to clear obstacle")
    end
    local flatDirection = Vector3.new(
        waypointPos.X - currentPos.X,
        0,
        waypointPos.Z - currentPos.Z
    )
    local horizontalDistance = flatDirection.Magnitude
    if horizontalDistance <= Config.minDistance and not AutopilotData.arrestMode then
        if not State.isAtWaypoint then State.isAtWaypoint = true end
        local currentGroundHeight, foundGround = getGroundBelow(currentPos)
        if not foundGround then return end
        local floatingHeight = currentPos.Y - currentGroundHeight
        local frameTime = math.min(dt or (1 / 60), 0.1)
        pcall(function()
            vehRoot.AssemblyLinearVelocity = Vector3.new(0, vehRoot.AssemblyLinearVelocity.Y, 0)
            vehRoot.AssemblyAngularVelocity = Vector3.zero
            if floatingHeight > 2 then
                local descendSpeed = 40
                local nextPos = currentPos + Vector3.new(0, -descendSpeed * frameTime, 0)
                local currentRotation = vehCFrame - vehCFrame.Position
                vehRoot.CFrame = CFrame.new(nextPos) * currentRotation
                vehRoot.AssemblyLinearVelocity = Vector3.new(0, -descendSpeed, 0)
            else
                handleWaypointArrival(vehRoot, vehCFrame, currentPos)
            end
        end)
        return
    elseif horizontalDistance <= Config.minDistance then
        local landingY = AutopilotData.getLandingY(veh, currentPos)
        if not landingY then return end
        local frameTime = math.min(dt or (1 / 60), 0.1)
        local verticalStep = math.clamp(landingY - currentPos.Y, -120 * frameTime, 120 * frameTime)
        if math.abs(landingY - currentPos.Y) > 1 then
            local currentRotation = vehCFrame - vehCFrame.Position
            local nextY = currentPos.Y + verticalStep
            pcall(function()
                vehRoot.CFrame = CFrame.new(currentPos.X, nextY, currentPos.Z) * currentRotation
                vehRoot.AssemblyLinearVelocity = Vector3.new(0, verticalStep / frameTime, 0)
                vehRoot.AssemblyAngularVelocity = Vector3.zero
            end)
            State.isAtWaypoint = false
            return
        end
        if not State.isAtWaypoint then
            State.isAtWaypoint = true
        end
        handleWaypointArrival(vehRoot, vehCFrame, currentPos)
        return
    end
    flatDirection = flatDirection.Unit
    pcall(function()
        vehRoot.CanCollide = false
        vehRoot.Anchored = false
        sethiddenproperty(vehRoot, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
    end)

    local speed = Config.flySpeed / Config.CALIBRATION_FACTOR
    local moveDirection, newRotation, effectiveSpeed

    if AutopilotData.arrestMode then
        -- 3-phase arrest flight: ascend clear of buildings → cruise horizontal →
        -- drop straight down onto target. Avoids terrain entirely.
        local CRUISE_HEIGHT = 200  -- studs above target
        local cruiseY = waypointPos.Y + CRUISE_HEIGHT
        local flatDist = horizontalDistance  -- pre-normalization magnitude, computed above
        local faceRot = flatDist > 1
            and CFrame.Angles(0, math.atan2(flatDirection.X, flatDirection.Z), 0)
            or (vehCFrame - vehCFrame.Position)

        -- Stuck detection: if we haven't moved 6 studs in 2s, blast sideways to escape
        local pNow = tick()
        if not AutopilotData.lastPosition
            or (currentPos - AutopilotData.lastPosition).Magnitude > 6
        then
            AutopilotData.lastPosition = currentPos
            AutopilotData.lastProgressAt = pNow
        end
        local stuck = pNow - AutopilotData.lastProgressAt > 2
        if stuck then
            -- Escape: pick a random horizontal offset direction and blast upward+sideways
            AutopilotData.escapeUntil = pNow + 1.2
            AutopilotData.lastProgressAt = pNow
        end

        if pNow < AutopilotData.escapeUntil then
            -- Escape burst: up + sideways away from current direction
            local perpDir = Vector3.new(-flatDirection.Z, 0, flatDirection.X)
            moveDirection = (Vector3.new(0, 1, 0) + perpDir * 0.6).Unit
        elseif currentPos.Y < cruiseY - 8 then
            -- Phase 1: shoot straight up
            moveDirection = Vector3.new(0, 1, 0)
        elseif flatDist > 20 then
            -- Phase 2: cruise at altitude, fly horizontal toward XZ of target
            moveDirection = Vector3.new(flatDirection.X, 0, flatDirection.Z).Unit
        else
            -- Phase 3: drop straight down
            moveDirection = Vector3.new(0, -1, 0)
        end
        newRotation = faceRot
        effectiveSpeed = speed
    else
        moveDirection, newRotation = calculateMoveDirection(currentPos, flatDirection, veh)
        effectiveSpeed = speed
    end
    if not isValid(vehRoot) then return end
    local nextPos = currentPos + (moveDirection * effectiveSpeed * math.min(dt or (1 / 60), 0.1))
    pcall(function()
        if isValid(vehRoot) then
            vehRoot.CFrame = CFrame.new(nextPos) * newRotation
            vehRoot.AssemblyLinearVelocity = moveDirection * effectiveSpeed
            vehRoot.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end
-- ─────────────────────────────────────────────────────────────────────────────
-- FSD (Full Self-Drive) — follows RoadNetwork YellowStripe graph to waypoint
-- ─────────────────────────────────────────────────────────────────────────────
local FSDSettings = {
    Enabled     = false,
    TargetSpeed = 90,   -- studs/s cruise on straights (auto-slows for turns)
    Speed       = 90,   -- legacy alias
    RideHeight  = 3,    -- studs the body floats above the road (looks grounded)
    LookAhead   = 3,
}

local FSDData = {
    stripes    = {},
    adj        = {},
    built      = false,
    building   = false,
    route      = {},
    routeHead  = 1,
    lastRouteAt = 0,
    chassis    = nil,
    inputArr   = nil,
    inputOwner = nil,
    connection = nil,
    statusLbl  = nil,
    bodyVel    = nil,
    bodyGyro   = nil,
    -- stuck detection / recovery
    stuckPos      = nil,
    stuckSince    = 0,
    reverseUntil  = 0,
    reverseSteer  = 0,
    stuckCooldown = 0,
    lastSteer     = 0,
    crossTrack    = 0,
    curveAngle    = 0,
    cmd           = {0, 0, 0, 0},  -- last driving input {fwd, steerL, rev, steerR}
    applyConn     = nil,
    arrived       = false,
    arrivedAt     = nil,
    prevThrottle  = 0,
    prevBrake     = 0,
    tanX = 0, tanZ = 0,
    toLineX = 0, toLineZ = 0,
    nearX = 0, nearZ = 0,
    curveMax = 0,
    flyBV = nil, flyBG = nil,
    flyUntil = 0, gapSince = nil,
    cmdSpeed = 0,
}

-- Raycast params reused for the forward terrain/obstacle scan
local fsdScanParams = RaycastParams.new()
fsdScanParams.FilterType = Enum.RaycastFilterType.Exclude

local function fsdBuildGraph()
    if FSDData.built or FSDData.building then return end
    FSDData.building = true
    local rn = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("RoadNetwork")
    if not rn then FSDData.building = false; return end

    local stripes  = {}
    local children = rn:GetChildren()
    for idx, road in ipairs(children) do
        local s = road:FindFirstChild("YellowStripe")
        if s and s:IsA("BasePart") then
            local cf   = s.CFrame
            local half = s.Size.Z * 0.5
            stripes[#stripes + 1] = {
                pos  = s.Position,
                ep1  = (cf * CFrame.new(0, 0, -half)).Position,
                ep2  = (cf * CFrame.new(0, 0,  half)).Position,
                part = s,
            }
        end
        if idx % 200 == 0 then
            if FSDData.statusLbl then
                FSDData.statusLbl.Text = "  FSD: Mapping... " .. idx .. "/" .. #children
            end
            task.wait()
        end
    end

    -- Build weighted adjacency. Each stripe links to its K nearest neighbors
    -- (measured by closest endpoint gap) within a generous link radius so the
    -- graph stays connected across dash spacing and small gaps in the lines.
    local adj      = {}
    local N        = #stripes
    local K        = 6      -- neighbors per node
    local LINK_MAX = 90     -- hard cap on a single link length (studs)

    -- endpoint-to-endpoint minimum distance between two stripes
    local function gapDist(a, b)
        return math.min(
            (a.ep1 - b.ep1).Magnitude, (a.ep1 - b.ep2).Magnitude,
            (a.ep2 - b.ep1).Magnitude, (a.ep2 - b.ep2).Magnitude
        )
    end

    for i = 1, N do adj[i] = {} end

    for i = 1, N do
        local s1 = stripes[i]
        -- collect candidate neighbors within LINK_MAX
        local cand = {}
        for j = 1, N do
            if j ~= i then
                local g = gapDist(s1, stripes[j])
                if g < LINK_MAX then
                    cand[#cand + 1] = { idx = j, g = g, w = (s1.pos - stripes[j].pos).Magnitude }
                end
            end
        end
        table.sort(cand, function(a, b) return a.g < b.g end)
        local lim = math.min(K, #cand)
        for k = 1, lim do
            local c = cand[k]
            -- undirected: add both ways, avoid dupes cheaply
            adj[i][#adj[i] + 1] = { node = c.idx, w = c.w }
            adj[c.idx][#adj[c.idx] + 1] = { node = i, w = c.w }
        end
        if i % 50 == 0 then
            if FSDData.statusLbl then
                FSDData.statusLbl.Text = "  FSD: Linking... " .. i .. "/" .. N
            end
            task.wait()
        end
    end

    FSDData.stripes  = stripes
    FSDData.adj      = adj
    FSDData.built    = true
    FSDData.building = false
    if FSDData.statusLbl then
        FSDData.statusLbl.Text = "  FSD: Ready — " .. N .. " road nodes"
    end
end

local function fsdNearest(pos)
    local best, bestD = 1, math.huge
    for i, s in ipairs(FSDData.stripes) do
        local d = (s.pos - pos).Magnitude
        if d < bestD then best = i; bestD = d end
    end
    return best
end

-- Return up to k nearest stripe indices to a position (sorted nearest-first).
local function fsdNearestK(pos, k)
    local cand = {}
    for i, s in ipairs(FSDData.stripes) do
        cand[#cand + 1] = { idx = i, d = (s.pos - pos).Magnitude }
    end
    table.sort(cand, function(a, b) return a.d < b.d end)
    local out = {}
    for i = 1, math.min(k, #cand) do out[#out + 1] = cand[i] end
    return out
end

-- Weighted shortest path (Dijkstra). Returns ordered list of stripe indices.
local function fsdDijkstra(startIdx, goalIdx)
    if startIdx == goalIdx then return {startIdx} end
    local N       = #FSDData.stripes
    local dist    = {}
    local prev    = {}
    local visited = {}
    for i = 1, N do dist[i] = math.huge end
    dist[startIdx] = 0

    -- simple O(N^2) Dijkstra; N is a few hundred, runs instantly
    for _ = 1, N do
        -- pick unvisited node with smallest dist
        local u, best = nil, math.huge
        for i = 1, N do
            if not visited[i] and dist[i] < best then best = dist[i]; u = i end
        end
        if not u then break end
        if u == goalIdx then break end
        visited[u] = true
        for _, edge in ipairs(FSDData.adj[u] or {}) do
            local v = edge.node
            if not visited[v] then
                local nd = dist[u] + edge.w
                if nd < dist[v] then
                    dist[v] = nd
                    prev[v] = u
                end
            end
        end
    end

    if dist[goalIdx] == math.huge then return nil end
    local path, node = {}, goalIdx
    while node do
        path[#path + 1] = node
        node = prev[node]
    end
    local rev = {}
    for i = #path, 1, -1 do rev[#rev + 1] = path[i] end
    return rev
end

-- Robust multi-source route: seed Dijkstra from several nearby stripes (so a car
-- sitting off-road next to an isolated node still gets connected to the real road)
-- and pick the best reachable goal among several near the waypoint. One pass.
local function fsdRoute(vehPos, goalPos)
    local N = #FSDData.stripes
    if N == 0 then return nil end
    local starts = fsdNearestK(vehPos,  6)
    local goals  = fsdNearestK(goalPos, 4)
    if #starts == 0 or #goals == 0 then return nil end

    local dist, prev, visited = {}, {}, {}
    for i = 1, N do dist[i] = math.huge end
    for _, s in ipairs(starts) do
        -- seed cost = how far the car is from that entry stripe
        if s.d < dist[s.idx] then dist[s.idx] = s.d end
    end

    for _ = 1, N do
        local u, best = nil, math.huge
        for i = 1, N do
            if not visited[i] and dist[i] < best then best = dist[i]; u = i end
        end
        if not u then break end
        visited[u] = true
        for _, edge in ipairs(FSDData.adj[u] or {}) do
            local v = edge.node
            if not visited[v] then
                local nd = dist[u] + edge.w
                if nd < dist[v] then dist[v] = nd; prev[v] = u end
            end
        end
    end

    -- choose reachable goal candidate with lowest total (path + offset to waypoint)
    local goalIdx, goalScore = nil, math.huge
    for _, g in ipairs(goals) do
        if dist[g.idx] < math.huge then
            local score = dist[g.idx] + g.d
            if score < goalScore then goalScore = score; goalIdx = g.idx end
        end
    end
    if not goalIdx then return nil end

    local path, node = {}, goalIdx
    while node do path[#path + 1] = node; node = prev[node] end
    local rev = {}
    for i = #path, 1, -1 do rev[#rev + 1] = path[i] end
    return rev
end

-- Greedy fallback (only if the graph truly can't connect): aim at a stripe that
-- is BOTH ahead of us and closer to the goal, so we make forward progress and
-- never orbit a side/behind node. If none qualifies, drive straight at the goal.
local function fsdGreedyTarget(vehPos, goalPos)
    local toGoal = Vector3.new(goalPos.X - vehPos.X, 0, goalPos.Z - vehPos.Z)
    local goalDist = toGoal.Magnitude
    if goalDist < 0.001 then return goalPos end
    toGoal = toGoal.Unit
    local REACH = 140
    local bestPos, bestScore = nil, math.huge
    for _, s in ipairs(FSDData.stripes) do
        local off = Vector3.new(s.pos.X - vehPos.X, 0, s.pos.Z - vehPos.Z)
        local dCar = off.Magnitude
        if dCar > 6 and dCar < REACH then
            local ahead = (off.X * toGoal.X + off.Z * toGoal.Z) / dCar  -- cosine vs goal dir
            local sGoal = (s.pos - goalPos).Magnitude
            -- must be roughly goalward and actually closer to the goal than we are
            if ahead > 0.25 and sGoal < goalDist then
                local score = sGoal + dCar * 0.2
                if score < bestScore then bestScore = score; bestPos = s.pos end
            end
        end
    end
    return bestPos or goalPos
end

-- Write a driving command to the chassis input array and remember it so the
-- high-frequency applier can keep it fresh between planning ticks.
local function fsdApply(u104, fwd, rev, steerL, steerR)
    FSDData.cmd[1] = fwd; FSDData.cmd[2] = steerL
    FSDData.cmd[3] = rev; FSDData.cmd[4] = steerR
    if type(u104) == "table" then
        pcall(function()
            u104[1] = fwd; u104[2] = steerL; u104[3] = rev; u104[4] = steerR
        end)
    end
end

-- Clears any drive command and cached physics
local function fsdCleanPhysics()
    FSDData.bodyVel  = nil
    FSDData.bodyGyro = nil
    FSDData.cmd[1] = 0; FSDData.cmd[2] = 0; FSDData.cmd[3] = 0; FSDData.cmd[4] = 0
    if FSDData.chassis then
        pcall(function() rawset(FSDData.chassis, "DriveToPosition", nil) end)
        pcall(function() rawset(FSDData.chassis, "DriveToPositionOnReached", nil) end)
    end
    local arr = FSDData.inputArr
    if type(arr) == "table" then
        pcall(function() arr[1] = 0; arr[2] = 0; arr[3] = 0; arr[4] = 0 end)
    end
    if FSDData.flyBV then pcall(function() FSDData.flyBV:Destroy() end); FSDData.flyBV = nil end
    if FSDData.flyBG then pcall(function() FSDData.flyBG:Destroy() end); FSDData.flyBG = nil end
end

-- Locate the live AlexChassis instance for the local vehicle. The chassis is a
-- plain table with fields: Model (Instance), Seat (VehicleSeat), Make (string),
-- setForward (function), and a DriveToPosition field its update loop consumes.
-- We set that field each frame so the game's own physics steers/accelerates.
local function fsdFindChassis(veh)
    -- reuse cached instance while its model is still in the world
    local cached = FSDData.chassis
    if cached then
        local ok, alive = pcall(function()
            local m = rawget(cached, "Model")
            return m and m.Parent ~= nil
        end)
        if ok and alive then return cached end
        FSDData.chassis = nil
    end
    if type(getgc) ~= "function" then return nil end

    -- the seat we're currently occupying (best match key)
    local seat
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then seat = hum.SeatPart end

    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then return nil end
    for _, obj in ipairs(gc) do
        if type(obj) == "table" then
            local good, model, make, sf, oseat = pcall(function()
                return rawget(obj, "Model"), rawget(obj, "Make"),
                       rawget(obj, "setForward"), rawget(obj, "Seat")
            end)
            if good and typeof(model) == "Instance"
                and type(make) == "string" and type(sf) == "function" then
                local match = false
                if seat and oseat == seat then
                    match = true
                elseif veh and (model == veh or model:IsDescendantOf(veh)
                    or (veh.Parent and model == veh.Parent)) then
                    match = true
                end
                if match then
                    FSDData.chassis = obj
                    return obj
                end
            end
        end
    end
    return nil
end

-- Grab the chassis input array (u104): u104[1]=forward, u104[3]=reverse,
-- u104[2]=steer-left, u104[4]=steer-right. It lives as an upvalue of the
-- chassis setForward function, shared module-wide.
local function fsdGetInput(chassis)
    if not chassis then return nil end
    if FSDData.inputArr and FSDData.inputOwner == chassis then
        return FSDData.inputArr
    end
    local sf = rawget(chassis, "setForward")
    if type(sf) ~= "function" then return nil end
    local getuv = (debug and debug.getupvalue) or getupvalue
    if type(getuv) ~= "function" then return nil end
    local arr
    -- setForward has a single upvalue (u104); scan a few just in case
    for idx = 1, 4 do
        local ok, val = pcall(getuv, sf, idx)
        if ok and type(val) == "table" then arr = val; break end
    end
    if arr then
        FSDData.inputArr   = arr
        FSDData.inputOwner = chassis
    end
    return arr
end

-- Zero all driving input
local function fsdReleaseInput()
    FSDData.cmd[1] = 0; FSDData.cmd[2] = 0; FSDData.cmd[3] = 0; FSDData.cmd[4] = 0
    local arr = FSDData.inputArr
    if type(arr) == "table" then
        pcall(function() arr[1] = 0; arr[2] = 0; arr[3] = 0; arr[4] = 0 end)
    end
    if FSDData.flyBV then pcall(function() FSDData.flyBV:Destroy() end); FSDData.flyBV = nil end
    if FSDData.flyBG then pcall(function() FSDData.flyBG:Destroy() end); FSDData.flyBG = nil end
end

-- Recovery flight: lift the car and glide it toward a target to rejoin the road
-- when it's stranded off the line, stuck, or bridging a gap. Used sparingly —
-- normal wheel driving resumes the moment it's realigned.
local function fsdFlyToward(vehRoot, vehPos, targetPos, speed, heightOff, faceDir)
    if not FSDData.flyBV or not FSDData.flyBV.Parent then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1/0, 1/0, 1/0)
        bv.Velocity = Vector3.zero
        bv.Parent   = vehRoot
        FSDData.flyBV = bv
    end
    if not FSDData.flyBG or not FSDData.flyBG.Parent then
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1/0, 1/0, 1/0)
        bg.P = 5500; bg.D = 900
        bg.Parent = vehRoot
        FSDData.flyBG = bg
    end
    local flat  = Vector3.new(targetPos.X - vehPos.X, 0, targetPos.Z - vehPos.Z)
    local horiz = (flat.Magnitude > 0.1) and flat.Unit or Vector3.new(0, 0, 0)
    local groundY  = getGroundBelow(vehPos)
    local desiredY = (type(groundY) == "number" and groundY or vehPos.Y) + (heightOff or 5)
    local yVel     = math.clamp((desiredY - vehPos.Y) * 6, -35, 35)
    FSDData.flyBV.Velocity = Vector3.new(horiz.X * speed, yVel, horiz.Z * speed)
    local fd = faceDir or ((horiz.Magnitude > 0.1) and horiz or nil)
    if fd then
        pcall(function()
            FSDData.flyBG.CFrame = CFrame.lookAt(vehRoot.Position, vehRoot.Position + fd)
        end)
    end
end

local function fsdStopFly()
    if FSDData.flyBV then pcall(function() FSDData.flyBV:Destroy() end); FSDData.flyBV = nil end
    if FSDData.flyBG then pcall(function() FSDData.flyBG:Destroy() end); FSDData.flyBG = nil end
end

local function fsdLoop()
    if not FSDSettings.Enabled or not FSDData.built then return end
    local veh     = getVehicle()
    local vehRoot = veh and getRoot(veh)
    if not veh or not vehRoot then
        if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: No vehicle" end
        return
    end

    -- Register vehicle so getGroundBelow/raycasts ignore it (fixes height)
    AutopilotData.currentVehicle = veh

    -- Use the autopilot's proven waypoint resolver (handles Model/Attachment markers)
    local waypoint = getClosestWaypoint()
    local waypointPos = waypoint and getObjectPosition(waypoint)
    if not waypointPos then
        if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: Set a waypoint" end
        return
    end

    local vehPos = vehRoot.Position

    -- ── ARRIVAL (latched) ────────────────────────────────────────────────
    -- Once we reach the waypoint we LATCH "arrived" and hold a full stop, so the
    -- car can't overshoot the radius, re-engage, and accelerate around it. We
    -- only re-arm when a genuinely new destination is set (waypoint moved) or the
    -- car has been driven well away from the arrival spot.
    local wpXZ     = Vector3.new(waypointPos.X, 0, waypointPos.Z)
    local carXZ2   = Vector3.new(vehPos.X, 0, vehPos.Z)
    local distToWp = (wpXZ - carXZ2).Magnitude

    if FSDData.arrived then
        local moved = math.huge
        if FSDData.arrivedAt then
            moved = (wpXZ - Vector3.new(FSDData.arrivedAt.X, 0, FSDData.arrivedAt.Z)).Magnitude
        end
        if moved > 25 or distToWp > 45 then
            FSDData.arrived = false      -- new destination → resume driving
        end
    end

    if FSDData.arrived or distToWp < 18 then
        FSDData.arrived   = true
        FSDData.arrivedAt = waypointPos
        FSDData.cmdSpeed  = 0
        local sp = 0
        pcall(function() sp = vehRoot.AssemblyLinearVelocity.Magnitude end)
        if sp > 8 then
            -- still rolling in: hover-glide to a gentle stop over the waypoint
            fsdFlyToward(vehRoot, vehPos, vehPos, 0, FSDSettings.RideHeight or 3)
        else
            fsdStopFly()
            pcall(function()
                vehRoot.AssemblyLinearVelocity  = Vector3.new(0, vehRoot.AssemblyLinearVelocity.Y, 0)
                vehRoot.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        FSDData.route     = {}
        FSDData.routeHead = 1
        FSDData.lastSteer = 0
        if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: Arrived!" end
        return
    end

    -- Recompute the graph route only when needed: no route yet, finished it, or
    -- we've wandered far from it. Following is handled every frame below, so the
    -- route itself rarely needs rebuilding.
    local nowT = tick()
    local gapMode = (#FSDData.route == 0)
    local needReroute = gapMode or (FSDData.routeHead >= #FSDData.route)
    -- retry fast while bridging a gap, otherwise a periodic sanity re-plan
    local reInterval = gapMode and 0.4 or 5.0
    if not needReroute and (nowT - (FSDData.lastRouteAt or 0)) > reInterval then
        needReroute = true
    end
    if needReroute then
        local route = fsdRoute(vehPos, waypointPos)
        FSDData.lastRouteAt = nowT
        if route and #route > 0 then
            FSDData.route     = route
            FSDData.routeHead = 1
            if FSDData.statusLbl then
                FSDData.statusLbl.Text = "  FSD: Driving — " .. #route .. " nodes"
            end
        else
            FSDData.route = {}
            if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: Bridging gap..." end
        end
    end

    local targetPos
    FSDData.crossTrack = 0
    FSDData.curveAngle = 0

    if #FSDData.route > 0 then
        -- PATH-PROJECTION FOLLOWING (keeps the car ON the yellow line, so it
        -- can't cut corners across intersections onto the grass):
        -- 1) project the car onto the route polyline to find the nearest point
        --    and which segment we're on,
        -- 2) aim at a point that lies ON the line, a look-ahead distance ahead,
        -- 3) measure how far off the line we are (cross-track) and how sharp the
        --    upcoming bend is (curve angle) for steering/speed correction.
        local route  = FSDData.route
        local n      = #route
        local head   = math.max(1, FSDData.routeHead)
        local winEnd = math.min(n - 1, head + 40)
        local carXZ  = Vector3.new(vehPos.X, 0, vehPos.Z)

        local bestSeg, bestT, bestD = head, 0, math.huge
        local bestProj, bestTangent = carXZ, nil
        for i = head, winEnd do
            local sA = FSDData.stripes[route[i]]
            local sB = FSDData.stripes[route[i + 1]]
            if sA and sB then
                local a  = Vector3.new(sA.pos.X, 0, sA.pos.Z)
                local b  = Vector3.new(sB.pos.X, 0, sB.pos.Z)
                local ab = b - a
                local abLen2 = ab.X * ab.X + ab.Z * ab.Z
                local t  = 0
                if abLen2 > 1e-4 then
                    t = math.clamp(((carXZ - a).X * ab.X + (carXZ - a).Z * ab.Z) / abLen2, 0, 1)
                end
                local proj = a + ab * t
                local d = (carXZ - proj).Magnitude
                if d < bestD then
                    bestD = d; bestSeg = i; bestT = t; bestProj = proj
                    bestTangent = (abLen2 > 1e-4) and ab.Unit or nil
                end
            end
        end
        FSDData.routeHead  = bestSeg
        FSDData.crossTrack = bestD
        if bestTangent then
            FSDData.tanX, FSDData.tanZ = bestTangent.X, bestTangent.Z
        else
            FSDData.tanX, FSDData.tanZ = 0, 0
        end
        FSDData.nearX, FSDData.nearZ = bestProj.X, bestProj.Z
        do
            local toLine = bestProj - carXZ
            if toLine.Magnitude > 1e-3 then
                local u = toLine.Unit
                FSDData.toLineX, FSDData.toLineZ = u.X, u.Z
            else
                FSDData.toLineX, FSDData.toLineZ = 0, 0
            end
        end

        -- speed-scaled look-ahead along the polyline (shorter than before so it
        -- hugs the line; longer at speed for stability)
        local speedMag = 0
        pcall(function() speedMag = vehRoot.AssemblyLinearVelocity.Magnitude end)
        local LOOKAHEAD = math.clamp(8 + speedMag * 0.28, 8, 38)

        -- walk forward along the polyline from the projected point
        local acc     = 0
        local prevPos = bestProj
        local aim     = nil
        for i = bestSeg + 1, n do
            local s = FSDData.stripes[route[i]]
            if s then
                local p = Vector3.new(s.pos.X, 0, s.pos.Z)
                acc = acc + (p - prevPos).Magnitude
                prevPos = p
                aim = s.pos
                if acc >= LOOKAHEAD then break end
            end
        end
        targetPos = aim or waypointPos

        -- anticipate the sharpest bend within the look-ahead window so we can
        -- ease off the gas BEFORE the corner instead of mid-corner
        local curveMax = 0
        if bestTangent then
            local prevT = bestTangent
            for i = bestSeg + 1, math.min(n - 1, bestSeg + 8) do
                local sA = FSDData.stripes[route[i]]
                local sB = FSDData.stripes[route[i + 1]]
                if sA and sB then
                    local d = Vector3.new(sB.pos.X - sA.pos.X, 0, sB.pos.Z - sA.pos.Z)
                    if d.Magnitude > 1e-3 then
                        local u = d.Unit
                        local dotT = math.clamp(prevT.X * u.X + prevT.Z * u.Z, -1, 1)
                        local bend = math.acos(dotT)
                        if bend > curveMax then curveMax = bend end
                        prevT = u
                    end
                end
            end
        end
        FSDData.curveAngle = curveMax
        FSDData.curveMax   = curveMax
    end

    -- No route target → head to the NEAREST road stripe to rejoin the yellow-line
    -- network. Never beeline at the raw waypoint (that cuts straight through
    -- buildings and off-road, which is exactly what we don't want).
    if not targetPos then
        local ni = fsdNearest(vehPos)
        local ns = ni and FSDData.stripes[ni]
        targetPos = ns and ns.pos or waypointPos
    end

    -- Drive by injecting real steering/throttle input into the chassis, exactly
    -- like the player's keyboard. This guarantees forward motion (the game's own
    -- DriveToPosition zeroes throttle whenever the car isn't already facing the
    -- target, which stalls it from a standstill and on every turn).
    -- ── FLY-DRIVE: glide the car along the route at road height so it looks
    --    like normal driving, but with the smoothness and reliability of flight.
    --    Heading follows the yellow line; speed eases into corners and the stop. ─
    local speedMag = 0
    pcall(function() speedMag = vehRoot.AssemblyLinearVelocity.Magnitude end)

    local target   = FSDSettings.TargetSpeed or 90
    local curveMax = FSDData.curveMax or 0

    -- CONSTANT CRUISE: hold target speed almost everywhere. Only a mild ease for
    -- genuinely sharp bends, and a gentle slow right at the waypoint. No obstacle
    -- braking (we're gliding at height) so it never freezes mid-route.
    local bendSlow = math.clamp(1 - (curveMax / math.rad(75)) * 0.45, 0.62, 1)
    local desiredSpeed = target * bendSlow

    -- only ease down in the last stretch before the waypoint so the stop is smooth
    local dWp = (Vector3.new(waypointPos.X, 0, waypointPos.Z)
               - Vector3.new(vehPos.X, 0, vehPos.Z)).Magnitude
    if dWp < 40 then
        desiredSpeed = math.min(desiredSpeed, math.max(22, (dWp - 12) * 2.2))
    end

    -- smooth commanded speed; reach cruise quickly, ease off a touch more gently
    local prevCmd = FSDData.cmdSpeed or 0
    local aStep   = (desiredSpeed > prevCmd) and 0.14 or 0.20
    FSDData.cmdSpeed = prevCmd + (desiredSpeed - prevCmd) * aStep

    -- ── WALL SCAN — cast ahead (and to the front corners); if a vertical face is
    --    in the way, slide the heading along it to steer around instead of
    --    ramming it, and ease the speed. Keeps it off buildings/fences. ────────
    local moveDir
    do
        local flat = Vector3.new(targetPos.X - vehPos.X, 0, targetPos.Z - vehPos.Z)
        if flat.Magnitude > 0.1 then moveDir = flat.Unit end
    end
    if moveDir then
        fsdScanParams.FilterDescendantsInstances = { veh, player.Character }
        local origin = vehRoot.Position
        local right  = Vector3.new(-moveDir.Z, 0, moveDir.X)
        local scan   = 8 + math.min(FSDData.cmdSpeed or 0, 120) * 0.28
        local nrm    = nil
        for _, off in ipairs({ 0, 2.2, -2.2 }) do
            local o = origin + right * off
            local ok, hit = pcall(function()
                return workspace:Raycast(o, moveDir * scan, fsdScanParams)
            end)
            if ok and hit and math.abs(hit.Normal.Y) < 0.55 then
                nrm = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
                break
            end
        end
        if nrm and nrm.Magnitude > 0.01 then
            nrm = nrm.Unit
            -- remove the into-the-wall component and push out along the wall normal
            local slid = (moveDir - nrm * moveDir:Dot(nrm)) + nrm * 0.35
            if slid.Magnitude > 0.01 then moveDir = slid.Unit end
            FSDData.cmdSpeed = math.min(FSDData.cmdSpeed or 0, 34)
            if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: Avoiding wall" end
        end
        -- fly along the (possibly adjusted) heading
        local moveTarget = vehRoot.Position + moveDir * 24
        fsdFlyToward(vehRoot, vehPos, moveTarget, FSDData.cmdSpeed, FSDSettings.RideHeight or 3, moveDir)
    else
        fsdFlyToward(vehRoot, vehPos, targetPos, FSDData.cmdSpeed, FSDSettings.RideHeight or 3)
    end
    if FSDData.statusLbl and not string.find(FSDData.statusLbl.Text, "Avoiding") then
        FSDData.statusLbl.Text = string.format("  FSD: Driving  %d studs/s", math.floor(FSDData.cmdSpeed))
    end
end

local function toggleFSD(state)
    FSDSettings.Enabled = state
    if state then
        if not FSDData.built and not FSDData.building then
            if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: Building road map..." end
            task.spawn(fsdBuildGraph)
        end
        FSDData.route     = {}
        FSDData.routeHead = 1
        FSDData.stuckPos      = nil
        FSDData.stuckSince    = tick()
        FSDData.reverseUntil  = 0
        FSDData.stuckCooldown = 0
        FSDData.lastSteer     = 0
        FSDData.arrived       = false
        FSDData.arrivedAt     = nil
        FSDData.prevThrottle  = 0
        FSDData.prevBrake     = 0
        if not FSDData.connection then
            -- Stepped fires before physics each frame: the full planner (route,
            -- steering, throttle) runs here so input lands before the car simulates.
            FSDData.connection = Services.RunService.Stepped:Connect(function()
                pcall(fsdLoop)
            end)
        end
        if not FSDData.applyConn then
            -- Extra high-frequency applier: re-writes the latest command to the
            -- chassis input every RenderStepped frame too, so throttle/steer stay
            -- fresh right up to the moment the chassis reads them (snappier).
            FSDData.applyConn = Services.RunService.RenderStepped:Connect(function()
                if not FSDSettings.Enabled then return end
                local arr = FSDData.inputArr
                local c   = FSDData.cmd
                if type(arr) == "table" and c then
                    pcall(function()
                        arr[1] = c[1]; arr[2] = c[2]; arr[3] = c[3]; arr[4] = c[4]
                    end)
                end
            end)
        end
    else
        if FSDData.connection then FSDData.connection:Disconnect(); FSDData.connection = nil end
        if FSDData.applyConn then FSDData.applyConn:Disconnect(); FSDData.applyConn = nil end
        fsdCleanPhysics()
        FSDData.route     = {}
        FSDData.routeHead = 1
        if FSDData.statusLbl then FSDData.statusLbl.Text = "  FSD: Off" end
    end
    pcall(function()
        if Buttons.fsdToggle and Buttons.fsdToggle.updateSwitch then
            Buttons.fsdToggle.updateSwitch(state, true)
        end
    end)
end

local function toggleAutopilot(state)
    State.autopilotEnabled = state
    State.flying = state
    if state then
        AutopilotData.arrived = false
        AutopilotData.lastPosition = nil
        AutopilotData.lastProgressAt = tick()
        AutopilotData.escapeUntil = 0
    end
    if state then
        if Connections.autopilot then
            Connections.autopilot:Disconnect()
        end
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        Connections.autopilot = Services.RunService.Heartbeat:Connect(function(dt)
            if not State.flying then return end
            pcall(flyToWaypoint, dt)
        end)
        State.isClimbing = false
        State.isAtWaypoint = false
    else
        State.isClimbing = false
        State.isAtWaypoint = false
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        AutopilotData.arrestMode = false
        if Connections.autopilot then
            Connections.autopilot:Disconnect()
            Connections.autopilot = nil
        end
    end
    updateAutopilotGUI(state)
end
local function reconnectAutopilotIfNeeded()
    if State.autopilotEnabled then
        task.wait(1)
        if Connections.autopilot then
            Connections.autopilot:Disconnect()
        end
        RoadPilotData.currentSpeed = 0
        RoadPilotData.currentRoad = nil
        RoadPilotData.lastTarget = nil
        Connections.autopilot = Services.RunService.Heartbeat:Connect(function(dt)
            if not State.flying then return end
            pcall(flyToWaypoint, dt)
        end)
    end
end
local function flightLoop()
    pcall(function()
        local char = player.Character
        if not isValid(char) then return end
        local veh = getVehicle()
        if veh then
            toggleFlight(false)
            return
        end
        local root = safeCall(char, "FindFirstChild", "HumanoidRootPart")
        local hum = safeCall(char, "FindFirstChild", "Humanoid")
        if not isValid(root) or not isValid(hum) then return end
        if not FlightData.bodyVel or not FlightData.bodyVel.Parent then
            FlightData.bodyVel = Instance.new("BodyVelocity")
            FlightData.bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            FlightData.bodyVel.Velocity = Vector3.zero
            FlightData.bodyVel.Parent = root
        end
        if not FlightData.bodyGyro or not FlightData.bodyGyro.Parent then
            FlightData.bodyGyro = Instance.new("BodyGyro")
            FlightData.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            FlightData.bodyGyro.P = 10000
            FlightData.bodyGyro.D = 100
            FlightData.bodyGyro.Parent = root
        end
        if not FlightData.skydiveAnimTrack or not FlightData.skydiveAnimTrack.IsPlaying then
            local skydiveAnim = ReplicatedStorage:FindFirstChild("Resource")
            if skydiveAnim then
                skydiveAnim = skydiveAnim:FindFirstChild("Skydive")
                if skydiveAnim then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        FlightData.skydiveAnimTrack = animator:LoadAnimation(skydiveAnim)
                        if FlightData.skydiveAnimTrack then
                            FlightData.skydiveAnimTrack:Play()
                        end
                    end
                end
            end
        end
        hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        local currentCF = root.CFrame
        local currentPos = currentCF.Position
        local goingUp = Services.UserInputService:IsKeyDown(Keybinds.flightUp)
        local goingDown = Services.UserInputService:IsKeyDown(Keybinds.flightDown)
        local moving = Services.UserInputService:IsKeyDown(Enum.KeyCode.W) or
                      Services.UserInputService:IsKeyDown(Enum.KeyCode.A) or
                      Services.UserInputService:IsKeyDown(Enum.KeyCode.S) or
                      Services.UserInputService:IsKeyDown(Enum.KeyCode.D)
        local moveDir = Vector3.zero
        if moving then
            local cam = Services.Workspace.CurrentCamera
            if isValid(cam) then
                local camCF = cam.CFrame
                local lookVector = camCF.LookVector
                local rightVector = camCF.RightVector
                local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
                local horizontalRight = Vector3.new(rightVector.X, 0, rightVector.Z).Unit
                if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + horizontalLook
                end
                if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - horizontalLook
                end
                if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + horizontalRight
                end
                if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - horizontalRight
                end
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit
                end
            end
        end
        local verticalVel = 0
        if goingUp then
            verticalVel = 50
        end
        if goingDown then
            verticalVel = -30
        end
        local horizontalVel = moveDir * Config.flightSpeed
        local finalVelocity = Vector3.new(horizontalVel.X, verticalVel, horizontalVel.Z)
        FlightData.bodyVel.Velocity = finalVelocity
        if moveDir.Magnitude > 0 then
            FlightData.bodyGyro.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(moveDir.X, 0, moveDir.Z))
        else
            FlightData.bodyGyro.CFrame = CFrame.new(root.Position, root.Position + currentCF.LookVector)
        end
    end)
end
local function updateFlightGUI(state)
    pcall(function()
        if Buttons.flightToggle and Buttons.flightToggle.updateSwitch then
            Buttons.flightToggle.updateSwitch(state, true)
        end
    end)
end
-- Same as pressing G but steered toward a target position instead of WASD.
-- Exact copy of flightLoop's setup + cleanup path so animation/states match perfectly.
local function arrestFootFly(targetPos, speed)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    -- BodyVelocity (identical to flightLoop)
    if not FlightData.bodyVel or not FlightData.bodyVel.Parent then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity  = Vector3.zero
        bv.Parent    = root
        FlightData.bodyVel = bv
    end
    -- BodyGyro (identical to flightLoop)
    if not FlightData.bodyGyro or not FlightData.bodyGyro.Parent then
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bg.P = 10000
        bg.D = 100
        bg.Parent = root
        FlightData.bodyGyro = bg
    end
    -- Skydive animation (identical to flightLoop)
    if not FlightData.skydiveAnimTrack or not FlightData.skydiveAnimTrack.IsPlaying then
        local res = ReplicatedStorage:FindFirstChild("Resource")
        local anim = res and res:FindFirstChild("Skydive")
        if anim then
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                FlightData.skydiveAnimTrack = animator:LoadAnimation(anim)
                if FlightData.skydiveAnimTrack then FlightData.skydiveAnimTrack:Play() end
            end
        end
    end
    -- Humanoid states (identical to flightLoop)
    hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    if not targetPos then
        FlightData.bodyVel.Velocity = Vector3.zero
        return
    end

    local spd = speed or Config.flightSpeed
    local flat = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
    local yErr = (targetPos.Y + 3) - root.Position.Y
    local yVel = math.clamp(yErr * 3, -30, 60)
    if yVel < 0 then
        local groundY = getGroundBelow(root.Position)
        if root.Position.Y - groundY <= 8 then yVel = 0 end
    end
    if flat.Magnitude > 0.5 then
        local horizontalSpeed = math.min(spd, flat.Magnitude * 4)
        FlightData.bodyVel.Velocity  = Vector3.new(flat.Unit.X * horizontalSpeed, yVel, flat.Unit.Z * horizontalSpeed)
        FlightData.bodyGyro.CFrame   = CFrame.new(root.Position, root.Position + Vector3.new(flat.X, 0, flat.Z))
    else
        FlightData.bodyVel.Velocity  = Vector3.new(0, yVel, 0)
    end
end

local function toggleFlight(state)
    local veh = getVehicle()
    if state and veh then return end
    State.flightEnabled = state
    if state then
        if Connections.flight then
            Connections.flight:Disconnect()
        end
        Connections.flight = Services.RunService.Heartbeat:Connect(flightLoop)
    else
        if Connections.flight then
            Connections.flight:Disconnect()
            Connections.flight = nil
        end
        if FlightData.bodyVel and FlightData.bodyVel.Parent then
            FlightData.bodyVel:Destroy()
            FlightData.bodyVel = nil
        end
        if FlightData.bodyGyro and FlightData.bodyGyro.Parent then
            FlightData.bodyGyro:Destroy()
            FlightData.bodyGyro = nil
        end
        if FlightData.skydiveAnimTrack then
            FlightData.skydiveAnimTrack:Stop()
            FlightData.skydiveAnimTrack = nil
        end
        pcall(function()
            local char = player.Character
            if not isValid(char) then return end
            local hum = safeCall(char, "FindFirstChild", "Humanoid")
            local root = safeCall(char, "FindFirstChild", "HumanoidRootPart")
            if not isValid(hum) then return end

            hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.Jump = false

            if isValid(root) and not veh then
                root.Anchored = false
                for _, child in pairs(root:GetChildren()) do
                    if child:IsA("BodyVelocity") or child:IsA("BodyGyro") or child:IsA("BodyPosition") then
                        child:Destroy()
                    end
                end

                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {char}
                local hit = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), params)
                local groundDistance = hit and (root.Position.Y - hit.Position.Y) or math.huge
                if groundDistance <= 8 then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                else
                    local velocity = root.AssemblyLinearVelocity
                    root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, -25), velocity.Z)
                    root.AssemblyAngularVelocity = Vector3.zero
                    hum:ChangeState(Enum.HumanoidStateType.Freefall)
                end
            elseif hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.Seated)
            end
        end)
        task.wait(0.2)
    end
    updateFlightGUI(state)
end
local function determineTeamData(targetPlayer)
    local team = targetPlayer and targetPlayer.Team
    if team then
        local name = team.Name:lower()
        if name:find("polic") or name:find("cop") or name:find("guard") then
            return Color3.fromRGB(0, 100, 255)
        end
        if name:find("criminal") or name:find("prisoner") or name:find("inmate") then
            return Color3.fromRGB(255, 0, 0)
        end
        local color = team.TeamColor
        if color == BrickColor.new("Bright blue") or color == BrickColor.new("Blue") then
            return Color3.fromRGB(0, 100, 255)
        end
        if color == BrickColor.new("Bright red") or color == BrickColor.new("Really red") then
            return Color3.fromRGB(255, 0, 0)
        end
    end
    return Color3.fromRGB(255, 255, 255)
end
local function createTeamIcon(targetPlayer)
    pcall(function()
        if not isValid(targetPlayer) or targetPlayer == player then return end
        local char = safeGet(targetPlayer, "Character")
        if not isValid(char) then return end
        local torso = safeCall(char, "FindFirstChild", "Torso") or safeCall(char, "FindFirstChild", "UpperTorso") or safeCall(char, "FindFirstChild", "LowerTorso") or safeCall(char, "FindFirstChild", "HumanoidRootPart")
        if not isValid(torso) then return end
        local existingIcon = safeCall(torso, "FindFirstChild", State.iconIdentifier)
        if isValid(existingIcon) then
            existingIcon:Destroy()
        end
        local teamColor = determineTeamData(targetPlayer)
        local billboard = Instance.new("BillboardGui")
        billboard.Name = State.iconIdentifier
        billboard.Size = UDim2.new(0, 13, 0, 15)
        billboard.StudsOffset = Vector3.new(0, 1.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = torso
        local bgCircle = Instance.new("Frame")
        bgCircle.Size = UDim2.new(0, 13, 0, 13)
        bgCircle.Position = UDim2.new(0.5, -6, 0, 0)
        bgCircle.BackgroundColor3 = teamColor
        bgCircle.BorderSizePixel = 0
        bgCircle.Parent = billboard
        local bgCorner = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(1, 0)
        bgCorner.Parent = bgCircle
        local bgStroke = Instance.new("UIStroke")
        bgStroke.Color = Color3.fromRGB(0, 0, 0)
        bgStroke.Thickness = 2
        bgStroke.Parent = bgCircle
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Parent = billboard
        local headCircle = Instance.new("Frame")
        headCircle.Size = UDim2.new(0, 6, 0, 6)
        headCircle.Position = UDim2.new(0.5, -3, 0, 1)
        headCircle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        headCircle.BorderSizePixel = 0
        headCircle.Parent = frame
        local headCorner = Instance.new("UICorner")
        headCorner.CornerRadius = UDim.new(1, 0)
        headCorner.Parent = headCircle
        local headStroke = Instance.new("UIStroke")
        headStroke.Color = teamColor
        headStroke.Thickness = 2
        headStroke.Parent = headCircle
        local bodyContainer = Instance.new("Frame")
        bodyContainer.Size = UDim2.new(0, 9, 0, 6)
        bodyContainer.Position = UDim2.new(0.5, -4, 0, 7)
        bodyContainer.BackgroundTransparency = 1
        bodyContainer.ClipsDescendants = true
        bodyContainer.BorderSizePixel = 0
        bodyContainer.Parent = frame
        local bodyCircle = Instance.new("Frame")
        bodyCircle.Size = UDim2.new(0, 9, 0, 12)
        bodyCircle.Position = UDim2.new(0, 0, 0, 0)
        bodyCircle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bodyCircle.BorderSizePixel = 0
        bodyCircle.Parent = bodyContainer
        local bodyCorner = Instance.new("UICorner")
        bodyCorner.CornerRadius = UDim.new(1, 0)
        bodyCorner.Parent = bodyCircle
        local bodyStroke = Instance.new("UIStroke")
        bodyStroke.Color = teamColor
        bodyStroke.Thickness = 2
        bodyStroke.Parent = bodyCircle
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(3, 0, 0.5, 0)
        label.Position = UDim2.new(-1, 0, 1, 2)
        label.BackgroundTransparency = 1
        label.Text = safeGet(targetPlayer, "Name") or "Player"
        label.TextColor3 = teamColor
        label.TextSize = 10
        label.TextStrokeTransparency = 0.5
        label.Font = Enum.Font.GothamBold
        label.Parent = billboard
    end)
end
local function removeTeamIcon(targetPlayer)
    pcall(function()
        if not isValid(targetPlayer) then return end
        local char = safeGet(targetPlayer, "Character")
        if not isValid(char) then return end
        local torso = safeCall(char, "FindFirstChild", "Torso") or safeCall(char, "FindFirstChild", "UpperTorso") or safeCall(char, "FindFirstChild", "LowerTorso") or safeCall(char, "FindFirstChild", "HumanoidRootPart")
        if isValid(torso) then
            local icon = safeCall(torso, "FindFirstChild", State.iconIdentifier)
            if isValid(icon) then
                icon:Destroy()
            end
        end
    end)
end
local function clearAllTeamIcons()
    pcall(function()
        local allPlayers = Services.Players:GetPlayers()
        for i = 1, #allPlayers do
            removeTeamIcon(allPlayers[i])
        end
    end)
end
local teamMonitorConnections = {}
local function setupTeamIconMonitoring()
    pcall(function()
        for _, existingPlayer in pairs(Services.Players:GetPlayers()) do
            if existingPlayer ~= player then
                if safeGet(existingPlayer, "Character") then
                    createTeamIcon(existingPlayer)
                end
                local charConn = existingPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if State.teamIconsEnabled then
                        createTeamIcon(existingPlayer)
                    end
                end)
                table.insert(teamMonitorConnections, charConn)
                local teamConn = existingPlayer:GetPropertyChangedSignal("Team"):Connect(function()
                    task.wait(0.1)
                    if State.teamIconsEnabled then
                        createTeamIcon(existingPlayer)
                    end
                end)
                table.insert(teamMonitorConnections, teamConn)
            end
        end
        local playerAddedConn = Services.Players.PlayerAdded:Connect(function(newPlayer)
            if newPlayer == player then return end
            local charConn = newPlayer.CharacterAdded:Connect(function()
                task.wait(0.5)
                if State.teamIconsEnabled then
                    createTeamIcon(newPlayer)
                end
            end)
            table.insert(teamMonitorConnections, charConn)
            local teamConn = newPlayer:GetPropertyChangedSignal("Team"):Connect(function()
                task.wait(0.1)
                if State.teamIconsEnabled then
                    createTeamIcon(newPlayer)
                end
            end)
            table.insert(teamMonitorConnections, teamConn)
        end)
        table.insert(teamMonitorConnections, playerAddedConn)
        local playerRemovingConn = Services.Players.PlayerRemoving:Connect(function(leavingPlayer)
            removeTeamIcon(leavingPlayer)
        end)
        table.insert(teamMonitorConnections, playerRemovingConn)
    end)
end
local function cleanupTeamIconMonitoring()
    pcall(function()
        for i = #teamMonitorConnections, 1, -1 do
            local conn = teamMonitorConnections[i]
            if conn then
                pcall(function() conn:Disconnect() end)
            end
            teamMonitorConnections[i] = nil
        end
        teamMonitorConnections = {}
    end)
end
local function toggleTeamIcons(state)
    State.teamIconsEnabled = state
    if state then
        cleanupTeamIconMonitoring()
        setupTeamIconMonitoring()
        if not Connections.iconUpdate then
            local elapsed = 0
            Connections.iconUpdate = Services.RunService.Heartbeat:Connect(function(dt)
                if not State.teamIconsEnabled then return end
                elapsed += dt
                if elapsed < 0.2 then return end
                elapsed = 0
                local camera = Services.Workspace.CurrentCamera
                if not camera then return end
                local cameraPos = camera.CFrame.Position
                for _, p in ipairs(Services.Players:GetPlayers()) do
                    if p and p ~= player then
                        local char = p.Character
                        local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
                        local billboard = torso and torso:FindFirstChild(State.iconIdentifier)
                        if billboard then
                            local distance = (torso.Position - cameraPos).Magnitude
                            local newSize
                            if distance < 50 then
                                newSize = UDim2.new(0, 13, 0, 15)
                            elseif distance < 150 then
                                newSize = UDim2.new(0, 10, 0, 12)
                            elseif distance < 300 then
                                newSize = UDim2.new(0, 8, 0, 9)
                            else
                                newSize = UDim2.new(0, 6, 0, 8)
                            end
                            if billboard.Size ~= newSize then
                                billboard.Size = newSize
                            end
                        end
                    end
                end
            end)
        end
    else
        cleanupTeamIconMonitoring()
        if Connections.iconUpdate then
            Connections.iconUpdate:Disconnect()
            Connections.iconUpdate = nil
        end
        clearAllTeamIcons()
    end
    pcall(function()
        if Buttons.teamIconToggle and Buttons.teamIconToggle.updateSwitch then
            Buttons.teamIconToggle.updateSwitch(state, true)
        end
    end)
end
local heightSlider, brakesSlider, speedSlider
local codeLabel = nil

local function startAutoCarMods()
    if Connections.autoMod then return end
    local elapsed = 0
    Connections.autoMod = Services.RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.25 then return end
        elapsed = 0
        pcall(function()
            Cache.vehicleUtils = Cache.vehicleUtils or require(ReplicatedStorage.Vehicle.VehicleUtils)
            local packet = Cache.vehicleUtils.GetLocalVehiclePacket()
            if not packet then return end
            local height = tonumber(heightSlider and heightSlider.Text) or 6
            local brakes = tonumber(brakesSlider and brakesSlider.Text) or 100
            local speed = tonumber(speedSlider and speedSlider.Text) or 25
            if packet.Height ~= height then packet.Height = height end
            if packet.GarageBrakes ~= brakes then packet.GarageBrakes = brakes end
            if packet.GarageEngineSpeed ~= speed then packet.GarageEngineSpeed = speed end
        end)
    end)
end
local waitingForKey = nil
local function setKeybind(callback)
    waitingForKey = callback
end

-- ===== MANUAL VEHICLE FLY LOGIC =====
local function stopVehFly()
    if vehFlyConnection then
        vehFlyConnection:Disconnect()
        vehFlyConnection = nil
    end
    if vehFlyCurrentVehicle then
        local root = getRoot(vehFlyCurrentVehicle)
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        vehFlyCurrentVehicle = nil
    end
    VehFlySettings.Enabled = false
end

local function startVehFly()
    if vehFlyConnection then return end
    local veh = getVehicle()
    if not veh then return end
    vehFlyCurrentVehicle = veh
    local root = getRoot(veh)
    if not root then return end
    VehFlySettings.Enabled = true
    local lastRotation = root.CFrame - root.CFrame.Position

    vehFlyConnection = Services.RunService.Heartbeat:Connect(function(dt)
        if not VehFlySettings.Enabled then stopVehFly() return end
        if not veh.Parent or not player.Character then stopVehFly() return end

        local moveDir = Vector3.zero
        local cam = Services.Workspace.CurrentCamera
        if not isValid(cam) then return end
        local camCF = cam.CFrame

        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if Services.UserInputService:IsKeyDown(Keybinds.flightUp) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if Services.UserInputService:IsKeyDown(Keybinds.flightDown) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        pcall(function()
            root.CanCollide = false
            root.Anchored = false
            sethiddenproperty(root, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
        end)

        local effectiveSpeed = VehFlySettings.Speed / Config.CALIBRATION_FACTOR

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
            local nextPos = root.Position + (moveDir * effectiveSpeed * dt)
            lastRotation = CFrame.lookAlong(Vector3.zero, moveDir)
            root.CFrame = CFrame.new(nextPos) * lastRotation
            root.AssemblyLinearVelocity = moveDir * effectiveSpeed
            root.AssemblyAngularVelocity = Vector3.zero
        else
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function toggleVehFly(state)
    if state then
        startVehFly()
    else
        stopVehFly()
    end
    pcall(function()
        if Buttons.vehFlyToggle and Buttons.vehFlyToggle.updateSwitch then
            Buttons.vehFlyToggle.updateSwitch(VehFlySettings.Enabled, true)
        end
    end)
end

-- ===== C4 ORBIT LOGIC =====
function OrbitLogic:GetRoot()
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

function OrbitLogic:Claim(part)
    if part and part:IsA("BasePart") then
        pcall(function()
            part.Anchored = false
            part.CanCollide = false
            sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
        end)
    end
end

function OrbitLogic:Gather()
    self.Objs = {}
    if player and player:FindFirstChild("Folder") and player.Folder:FindFirstChild("C4") then
        pcall(function() player.Folder.C4.InventoryEquipRemote:FireServer(true) end)
    end
    local c4Found = nil
    for i = 1, 20 do
        c4Found = Services.Workspace:FindFirstChild("C4")
        if c4Found then break end
        task.wait(0.1)
    end
    if c4Found then
        local part = c4Found.PrimaryPart or c4Found:FindFirstChildWhichIsA("BasePart")
        if part then table.insert(self.Objs, part); self:Claim(part) end
    end
    for _, v in pairs(Services.Workspace:GetChildren()) do
        if #self.Objs >= 2 then break end
        local char = player.Character
        if v:IsA("BasePart") and not v.Anchored and v.Name ~= "C4" and (not char or not v:IsDescendantOf(char)) then
            table.insert(self.Objs, v); self:Claim(v)
        elseif v:IsA("Model") and v.Name ~= "C4" and (not char or not v:IsDescendantOf(char)) then
            local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if p and not p.Anchored then table.insert(self.Objs, p); self:Claim(p) end
        end
    end
end

function OrbitLogic:Toggle(bool)
    OrbitSettings.Enabled = bool
    if bool then
        if self.Connection then return end
        task.spawn(function()
            self:Gather()
            if not OrbitSettings.Enabled then return end
            self.Connection = Services.RunService.Heartbeat:Connect(function()
                if not OrbitSettings.Enabled then return end
                local Root = self:GetRoot()
                if not Root then return end
                pcall(function() setsimulationradius(math.huge) end)
                local t = os.clock() * OrbitSettings.Speed
                for i, v in pairs(self.Objs) do
                    if v and v:IsA("BasePart") and v.Parent then
                        v.Anchored = false
                        v.CanCollide = false
                        local angleSpacing = (math.pi * 2 / #self.Objs) * i
                        local newCFrame = CFrame.new(Root.Position)
                            * CFrame.Angles(0, t + angleSpacing, 0)
                            * CFrame.new(0, 0, OrbitSettings.Radius)
                        v.CFrame = newCFrame
                        v.Velocity = Vector3.zero
                        v.RotVelocity = Vector3.zero
                    end
                end
            end)
        end)
    else
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
        for _, v in pairs(self.Objs) do
            if v and v:IsA("BasePart") then v.Velocity = Vector3.zero; v.RotVelocity = Vector3.zero end
        end
        self.Objs = {}
    end
end

local function toggleC4Orbit(state)
    OrbitLogic:Toggle(state)
    pcall(function()
        if Buttons.orbitToggle and Buttons.orbitToggle.updateSwitch then
            Buttons.orbitToggle.updateSwitch(OrbitSettings.Enabled, true)
        end
    end)
end

-- ===== ESP LOGIC =====
local function roundNum(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5) / mult
end

local function removeESP(plr)
    local record = Cache.esp[plr]
    local folder = record and record.folder or ESPSettings.COREGUI:FindFirstChild(plr.Name .. "_ESP")
    if folder then folder:Destroy() end
    Cache.esp[plr] = nil
end

local function createESP(plr, teamCheck)
    if plr == player then return end
    local character = plr.Character
    local root = character and getRoot(character)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local head = character and character:FindFirstChild("Head")
    if not root or not humanoid or not head then return end

    removeESP(plr)
    local holder = Instance.new("Folder")
    holder.Name = plr.Name .. "_ESP"
    holder.Parent = ESPSettings.COREGUI
    local color = teamCheck
        and (plr.TeamColor.Color == player.TeamColor.Color and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60))
        or plr.TeamColor.Color

    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local adornment = Instance.new("BoxHandleAdornment")
            adornment.Name = plr.Name
            adornment.Adornee = part
            adornment.AlwaysOnTop = true
            adornment.ZIndex = 10
            adornment.Size = part.Size
            adornment.Transparency = ESPSettings.Transparency
            adornment.Color3 = color
            adornment.Parent = holder
        end
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = head
    billboard.Name = plr.Name
    billboard.Size = UDim2.new(0, 100, 0, 150)
    billboard.StudsOffset = Vector3.new(0, 1, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = holder

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 0, 0, -50)
    label.Size = UDim2.new(0, 100, 0, 100)
    label.Font = Enum.Font.SourceSansSemibold
    label.TextSize = 20
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextYAlignment = Enum.TextYAlignment.Bottom
    label.ZIndex = 10
    label.Parent = billboard

    Cache.esp[plr] = {
        character = character,
        teamColor = plr.TeamColor,
        folder = holder,
        label = label,
        humanoid = humanoid,
        root = root,
    }
end

local function updateESP()
    local myRoot = player.Character and getRoot(player.Character)
    for _, plr in ipairs(Services.Players:GetPlayers()) do
        if plr ~= player then
            local record = Cache.esp[plr]
            if not record or record.character ~= plr.Character or record.teamColor ~= plr.TeamColor then
                createESP(plr, ESPSettings.TeamCheck)
                record = Cache.esp[plr]
            end
            if record and myRoot and record.root.Parent and record.humanoid.Parent then
                local distance = math.floor((myRoot.Position - record.root.Position).Magnitude)
                local health = roundNum(record.humanoid.Health, 1)
                if record.distance ~= distance or record.health ~= health then
                    record.distance = distance
                    record.health = health
                    record.label.Text = plr.Name .. " | HP:" .. health .. " | " .. distance .. "st"
                end
            end
        end
    end
    for plr in pairs(Cache.esp) do
        if plr.Parent ~= Services.Players then removeESP(plr) end
    end
end

local function clearAllESP()
    for plr in pairs(Cache.esp) do removeESP(plr) end
    for _, plr in ipairs(Services.Players:GetPlayers()) do
        if plr ~= player then removeESP(plr) end
    end
end

local function toggleESP(state)
    ESPSettings.Enabled = state
    if state then
        updateESP()
        if not Connections.espUpdate then
            local elapsed = 0
            Connections.espUpdate = Services.RunService.Heartbeat:Connect(function(dt)
                elapsed += dt
                if elapsed < 0.15 then return end
                elapsed = 0
                updateESP()
            end)
        end
    else
        if Connections.espUpdate then
            Connections.espUpdate:Disconnect()
            Connections.espUpdate = nil
        end
        clearAllESP()
    end
    pcall(function()
        if Buttons.espToggle and Buttons.espToggle.updateSwitch then
            Buttons.espToggle.updateSwitch(state, true)
        end
    end)
end
-- ===== REMOTE VEHICLE CONTROL LOGIC =====
local function getClosestVehicle()
    local char = player.Character
    if not char or not char.PrimaryPart then return nil end
    local playerPos = char.PrimaryPart.Position
    local closestVehicle, closestDistance = nil, math.huge
    local vehicles = Services.Workspace:FindFirstChild("Vehicles")
    if vehicles then
        for _, vehicle in pairs(vehicles:GetChildren()) do
            if vehicle:IsA("Model") and vehicle.Name ~= "Heli" then
                local vehPart = vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart")
                if vehPart then
                    local dist = (vehPart.Position - playerPos).Magnitude
                    if dist < closestDistance then
                        closestDistance = dist
                        closestVehicle = vehicle
                    end
                end
            end
        end
    end
    return closestVehicle
end

local function findVehicleSeat(vehicle)
    if not vehicle then return nil end
    local directSeat = vehicle:FindFirstChild("VehicleSeat") or vehicle:FindFirstChild("Seat")
    if directSeat and directSeat:IsA("BasePart") then return directSeat end
    local fallback
    for _, obj in pairs(vehicle:GetDescendants()) do
        if obj:IsA("VehicleSeat") or obj:IsA("Seat") then return obj end
        if not fallback and obj:IsA("BasePart") and obj.Name:lower():find("seat") then
            fallback = obj
        end
    end
    return fallback
end

local function getNilInstance(name, class)
    local ok, result = pcall(function()
        for _, v in pairs(getnilinstances()) do
            if v.ClassName == class and v.Name == name then return v end
        end
    end)
    return ok and result or nil
end

local function startRemoteVehFly()
    if not RopeSettings.LinkedVehicle then return false end
    local vehRoot = getRoot(RopeSettings.LinkedVehicle)
    if not vehRoot then return false end
    pcall(function()
        vehRoot.CanCollide = false
        vehRoot.Anchored = false
        sethiddenproperty(vehRoot, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
    end)
    pcall(function()
        for _, seat in pairs(RopeSettings.LinkedVehicle:GetDescendants()) do
            if seat:IsA("VehicleSeat") then
                if not seat:GetAttribute("OriginalMaxSpeed") then
                    seat:SetAttribute("OriginalMaxSpeed", seat.MaxSpeed)
                    seat:SetAttribute("OriginalTorque", seat.Torque)
                    seat:SetAttribute("OriginalTurnSpeed", seat.TurnSpeed)
                end
                seat.MaxSpeed = 0; seat.Torque = 0; seat.TurnSpeed = 0
            end
        end
    end)
    local cam = Services.Workspace.CurrentCamera
    RopeSettings.OriginalCameraSubject = cam.CameraSubject
    RopeSettings.OriginalCameraType = cam.CameraType
    cam.CameraType = Enum.CameraType.Scriptable
    local isRightHeld = false
    local lastMouse = Services.UserInputService:GetMouseLocation()
    local rBegin = Services.UserInputService.InputBegan:Connect(function(i)
        if not RopeSettings.FlyEnabled then return end
        if i.UserInputType == Enum.UserInputType.MouseButton2 then
            isRightHeld = true; lastMouse = Services.UserInputService:GetMouseLocation()
        end
    end)
    local rEnd = Services.UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton2 then isRightHeld = false end
    end)
    local rMove = Services.UserInputService.InputChanged:Connect(function(i)
        if not RopeSettings.FlyEnabled then return end
        if isRightHeld and i.UserInputType == Enum.UserInputType.MouseMovement then
            local mp = Services.UserInputService:GetMouseLocation()
            local delta = mp - lastMouse
            lastMouse = mp
            RopeSettings.CameraAngleX = math.clamp(RopeSettings.CameraAngleX - delta.Y * 0.003, -1.4, 1.4)
            RopeSettings.CameraAngleY = RopeSettings.CameraAngleY - delta.X * 0.003
        end
    end)
    local rScroll = Services.UserInputService.InputChanged:Connect(function(i)
        if not RopeSettings.FlyEnabled then return end
        if i.UserInputType == Enum.UserInputType.MouseWheel then
            RopeSettings.CameraDistance = math.clamp(RopeSettings.CameraDistance - i.Position.Z * 3, 8, 80)
        end
    end)
    local conns = {rBegin, rEnd, rMove, rScroll}
    RopeSettings.FlyConnection = Services.RunService.Heartbeat:Connect(function(dt)
        if not RopeSettings.FlyEnabled then
            for _, c in pairs(conns) do pcall(function() c:Disconnect() end) end
            if RopeSettings.FlyConnection then RopeSettings.FlyConnection:Disconnect(); RopeSettings.FlyConnection = nil end
            return
        end
        if not RopeSettings.LinkedVehicle or not RopeSettings.LinkedVehicle.Parent or not vehRoot or not vehRoot.Parent then
            RopeSettings.FlyEnabled = false; return
        end
        pcall(function()
            vehRoot.CanCollide = false; vehRoot.Anchored = false
            sethiddenproperty(vehRoot, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
        end)
        local vehPos = vehRoot.Position
        local camRot = CFrame.Angles(RopeSettings.CameraAngleX, RopeSettings.CameraAngleY, 0)
        local camOff = camRot * Vector3.new(0, 0, RopeSettings.CameraDistance)
        cam.CFrame = CFrame.new(vehPos + camOff, vehPos)
        local moveDir = Vector3.zero
        local camCF = cam.CFrame
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
        if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
        if Services.UserInputService:IsKeyDown(Keybinds.flightUp) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if Services.UserInputService:IsKeyDown(Keybinds.flightDown) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        local effSpeed = RopeSettings.FlySpeed / Config.CALIBRATION_FACTOR
        if moveDir.Magnitude > 0 then
            local nextPos = vehRoot.Position + (moveDir * effSpeed * dt)
            pcall(function()
                vehRoot.CFrame = CFrame.new(nextPos, nextPos + camCF.LookVector)
                vehRoot.AssemblyLinearVelocity = moveDir * effSpeed
                vehRoot.AssemblyAngularVelocity = Vector3.zero
            end)
        else
            pcall(function()
                vehRoot.AssemblyLinearVelocity = Vector3.zero
                vehRoot.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)
    return true
end

local function stopRemoteVehFly()
    RopeSettings.FlyEnabled = false
    if RopeSettings.FlyConnection then RopeSettings.FlyConnection:Disconnect(); RopeSettings.FlyConnection = nil end
    local cam = Services.Workspace.CurrentCamera
    if RopeSettings.OriginalCameraSubject then
        cam.CameraType = RopeSettings.OriginalCameraType or Enum.CameraType.Custom
        cam.CameraSubject = RopeSettings.OriginalCameraSubject
        RopeSettings.OriginalCameraSubject = nil; RopeSettings.OriginalCameraType = nil
    end
    RopeSettings.CameraAngleX = 0; RopeSettings.CameraAngleY = 0
    if RopeSettings.LinkedVehicle then
        pcall(function()
            for _, seat in pairs(RopeSettings.LinkedVehicle:GetDescendants()) do
                if seat:IsA("VehicleSeat") then
                    seat.MaxSpeed = seat:GetAttribute("OriginalMaxSpeed") or 50
                    seat.Torque = seat:GetAttribute("OriginalTorque") or 10
                    seat.TurnSpeed = seat:GetAttribute("OriginalTurnSpeed") or 1
                end
            end
        end)
        local root = getRoot(RopeSettings.LinkedVehicle)
        if root then root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end
    end
end

-- ===== BANK ROBBERY LOGIC =====
local function resetBankRobState()
    bankRobState.targetHeli = nil
    bankRobState.phaseInProgress = false
    bankRobState.phaseStart = nil
    bankRobState.phaseStartDist = nil
    bankRobState.triggerDoorPart = nil
    bankRobState.moneyPart = nil
    bankRobState.barrier2Pos = nil
    bankRobState.lastPhaseUpdate = 0
end

local function findBankTargetPosition()
    local banks = Services.Workspace:FindFirstChild("Banks")
    if not banks then return nil end
    local bank = banks:FindFirstChild("Bank")
    if not bank then return nil end
    local children = bank:GetChildren()
    if children[16] then
        local part = children[16].PrimaryPart or children[16]:FindFirstChildWhichIsA("BasePart")
        if part then return part.Position end
    end
    return nil
end

local function findTriggerDoorAndMoney()
    local banks = Services.Workspace:FindFirstChild("Banks")
    if not banks then return nil, nil end
    local bank = banks:FindFirstChild("Bank")
    if not bank then return nil, nil end
    local layout = bank:FindFirstChild("Layout")
    if not layout then return nil, nil end
    for _, folder in pairs(layout:GetChildren()) do
        if folder:IsA("Folder") then
            local triggerDoor = folder:FindFirstChild("TriggerDoor")
            local money = folder:FindFirstChild("Money")
            if triggerDoor then
                local tp = triggerDoor.PrimaryPart or triggerDoor:FindFirstChildWhichIsA("BasePart")
                local mp = money and (money.PrimaryPart or money:FindFirstChildWhichIsA("BasePart"))
                if tp then return tp, mp, folder.Name end
            end
        end
    end
    return nil, nil, nil
end

local bankCharFlyConn = nil
local bankCharFlyActive = false

local function startBankCharFly()
    if bankCharFlyActive then return end
    bankCharFlyActive = true
    local char = player.Character
    if not char then bankCharFlyActive = false; return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.PlatformStand = true end)
        local elapsed = 0
        bankCharFlyConn = Services.RunService.Heartbeat:Connect(function(dt)
            if not bankCharFlyActive then
                if bankCharFlyConn then bankCharFlyConn:Disconnect(); bankCharFlyConn = nil end
                return
            end
            elapsed += dt
            if elapsed < 0.25 then return end
            elapsed = 0
            pcall(function() if hum and hum.Parent then hum.PlatformStand = true end end)
        end)
    end
end

local function stopBankCharFly()
    bankCharFlyActive = false
    if bankCharFlyConn then bankCharFlyConn:Disconnect(); bankCharFlyConn = nil end
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Parent then hum.PlatformStand = false end
    end
end

local function bankNavigateTo(targetPos, speed, flyHeight)
    local char = player.Character
    if not char or not char.PrimaryPart then return false end
    local root = char.PrimaryPart
    flyHeight = flyHeight or 8
    local elevated = targetPos + Vector3.new(0, flyHeight, 0)
    startBankCharFly()
    local timeout, elapsed = 25, 0
    while elapsed < timeout do
        if not BankRobSettings.Enabled or not root or not root.Parent then return false end
        local dist = (elevated - root.Position).Magnitude
        if dist < 5 then stopBankCharFly(); return true end
        local dir = (elevated - root.Position).Unit
        pcall(function()
            root.CFrame = CFrame.new(root.Position + (dir * (speed or 50) * 0.1), elevated)
            root.AssemblyLinearVelocity = dir * (speed or 50)
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end
    stopBankCharFly()
    return false
end

local function flyHeliToBank(heli, targetPos, speed)
    local heliRoot = getRoot(heli)
    if not heliRoot then return false end
    pcall(function()
        heliRoot.CanCollide = false; heliRoot.Anchored = false
        sethiddenproperty(heliRoot, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
    end)
    local timeout, elapsed = 60, 0
    while elapsed < timeout do
        if not heli or not heli.Parent or not heliRoot or not heliRoot.Parent then return false end
        local dist = (targetPos - heliRoot.Position).Magnitude
        if dist < 15 then return true end
        pcall(function()
            heliRoot.CanCollide = false; heliRoot.Anchored = false
            local moveDir = (targetPos - heliRoot.Position).Unit
            local effSpeed = speed / Config.CALIBRATION_FACTOR
            local nextPos = heliRoot.Position + (moveDir * effSpeed * 0.016)
            heliRoot.CFrame = CFrame.new(nextPos, nextPos + moveDir)
            heliRoot.AssemblyLinearVelocity = moveDir * effSpeed
            heliRoot.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.016)
        elapsed = elapsed + 0.016
    end
    return false
end

function PathRecorder:StartRecording()
    if self.Recording then return end
    self.Recording = true
    self.RecordedPath = {}
    self.RecordElapsed = self.RecordInterval
    self.RecordConnection = Services.RunService.Heartbeat:Connect(function(dt)
        if not self.Recording then
            if self.RecordConnection then self.RecordConnection:Disconnect(); self.RecordConnection = nil end
            return
        end
        self.RecordElapsed += dt
        if self.RecordElapsed < self.RecordInterval then return end
        self.RecordElapsed = 0
        local char = player.Character
        if char and char.PrimaryPart then
            local pos = char.PrimaryPart.Position
            table.insert(self.RecordedPath, {X = pos.X, Y = pos.Y, Z = pos.Z})
        end
    end)
end

function PathRecorder:StopRecording()
    self.Recording = false
    if self.RecordConnection then self.RecordConnection:Disconnect(); self.RecordConnection = nil end
end

-- ===== AUTO ARREST LOGIC =====
local function arrestRaycastCheck(targetChar, fromPos, myChar)
    if not targetChar then return false end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return false end

    local rayDir = (targetRoot.Position - fromPos)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {myChar}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local result = Services.Workspace:Raycast(fromPos, rayDir, params)
    if not result then return true end
    if result.Instance:IsDescendantOf(targetChar) then return true end
    if result.Instance.Transparency >= 0.5 or not result.Instance.CanCollide then return true end
    return false
end

local function getPlayerBounty(targetPlayer)
    local bounty = 0
    pcall(function()
        local leaderstats = targetPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            local bountyValue = leaderstats:FindFirstChild("Bounty")
            if bountyValue then bounty = bountyValue.Value end
        end
    end)
    return bounty
end

local function findBestTargetForArrest()
    local char = player.Character
    if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local candidates = {}
    for _, p in ipairs(Services.Players:GetPlayers()) do
        if p ~= player and p.Character and p.Team then
            local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = p.Character:FindFirstChild("Humanoid")
            if targetRoot and targetHum and targetHum.Health > 0 then
                local teamName = p.Team.Name:lower()
                if teamName:find("criminal") and not p.Character:GetAttribute("HasHandcuffs") then
                    local dist = (myRoot.Position - targetRoot.Position).Magnitude
                    local bounty = getPlayerBounty(p)
                    table.insert(candidates, {player = p, distance = dist, bounty = bounty})
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.bounty ~= b.bounty then return a.bounty > b.bounty end
        return a.distance < b.distance
    end)
    if #candidates > 0 then return candidates[1].player, candidates[1] end
    return nil
end

local function enableDoorClip(char)
    if not char then return end
    pcall(function()
        local original = Cache.doorClipOriginal or {}
        Cache.doorClipOriginal = original
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if original[part] == nil then original[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    end)
end

local function disableDoorClip(char)
    local original = Cache.doorClipOriginal
    if not original then return end
    pcall(function()
        for part, canCollide in pairs(original) do
            if part.Parent then part.CanCollide = canCollide end
        end
    end)
    Cache.doorClipOriginal = nil
end
local AV = {
    vehicle = nil,
    lastSpawn = 0,
    lastSpawnCheck = 0,
    spawnBlockedUntil = 0,
    lastSpawnWaitLog = 0,
    lastAcquire = 0,
    acquiring = false,
    pathfinding = false,
    footMode = false,
    pathMarkers = {},
    shooting = nil,
    lastOutsideCheck = 0,
    outsideCache = false,
    route = {
        waypoints = {},
        index = 1,
        lastAt = 0,
        lastGoal = nil,
        requestedGoal = nil,
        computing = nil,
        generation = 0,
        lastSteer = nil,
    },
}
AV.newArrestActionState = function()
    return {
        targetUserId = nil,
        targetVehicle = nil,
        tiresPopped = false,
        vehicleStartedAt = 0,
        vehicleShots = 0,
        lastShot = 0,
        lastTase = 0,
        lastEquipAttempt = 0,
        pendingItem = nil,
        cuffHoldStarted = 0,
        landingStartedAt = 0,
        lastEjectPress = 0,
    }
end
AV.shooting = AV.newArrestActionState()

AV.resetRoute = function()
    local route = AV.route
    route.generation += 1
    route.waypoints = {}
    route.index = 1
    route.lastAt = 0
    route.lastGoal = nil
    route.requestedGoal = nil
    route.computing = nil
    route.lastSteer = nil
end

AV.allowedVehicleMakes = {Camaro = true, Jeep = true}

AV.getVehicleMake = function(vehicle)
    local make = vehicle and vehicle:FindFirstChild("Make")
    return make and make:IsA("StringValue") and make.Value or (vehicle and vehicle.Name)
end

AV.isOwnedAllowedVehicle = function(vehicle)
    return vehicle and vehicle:IsA("Model")
        and AV.allowedVehicleMakes[AV.getVehicleMake(vehicle)] == true
        and tonumber(vehicle:GetAttribute("LastDriverId")) == player.UserId
end

AV.isDriverSeatFree = function(vehicle, seat)
    if not seat or vehicle:GetAttribute("VehicleHasDriver") == true then return false end
    local occupied = seat:FindFirstChild("Player")
    local playerName = seat:FindFirstChild("PlayerName")
    if occupied and occupied:IsA("BoolValue") and occupied.Value then return false end
    if playerName and playerName:IsA("StringValue") and playerName.Value ~= "" then return false end
    if seat:IsA("Seat") or seat:IsA("VehicleSeat") then return seat.Occupant == nil end
    return true
end

AV.getDriverEntrySpec = function(seat)
    local ok, ui = pcall(require, ReplicatedStorage.Module.UI)
    if not ok or not ui.CircleAction then return nil end
    for _, spec in ipairs(ui.CircleAction.Specs or {}) do
        if (spec.Part == seat or spec.Tag == seat) and spec.Name == "Enter Driver" then
            return spec
        end
    end
    return nil
end

AV.readSpawnWaitSeconds = function(previous)
    local gui = player:FindFirstChild("PlayerGui")
    local notificationGui = gui and gui:FindFirstChild("NotificationGui")
    local container = notificationGui and notificationGui:FindFirstChild("Container")
    local best, message = 0, nil
    for _, label in ipairs(container and container:GetDescendants() or {}) do
        if label:IsA("TextLabel") and (not previous or previous[label] ~= label.Text) then
            local lower = string.lower(label.Text)
            if lower:find("second", 1, true)
                and (lower:find("wait", 1, true) or lower:find("spawn", 1, true))
            then
                local seconds = tonumber(lower:match("(%d+)%s*seconds?"))
                if seconds and seconds > best then
                    best, message = seconds, label.Text
                end
            end
        end
    end
    return best > 0 and best or nil, message
end

AV.getInventoryItem = function(name)
    local current = player:FindFirstChild("CurrentInventory")
    local folder = current and current.Value or player:FindFirstChild("Folder")
    return folder and folder:FindFirstChild(name) or nil
end

AV.getItemSystem = function()
    if AV.itemSystem then return AV.itemSystem end
    local ok, itemSystem = pcall(require, ReplicatedStorage.Game.ItemSystem.ItemSystem)
    if ok then AV.itemSystem = itemSystem end
    return AV.itemSystem
end

AV.getInventoryItemUtils = function()
    if AV.inventoryItemUtils then return AV.inventoryItemUtils end
    local ok, utils = pcall(require, ReplicatedStorage.Inventory.InventoryItemUtils)
    if ok then AV.inventoryItemUtils = utils end
    return AV.inventoryItemUtils
end

AV.isItemEquipped = function(name)
    local item = AV.getInventoryItem(name)
    if not item then return false end

    local itemSystem = AV.getItemSystem()
    if itemSystem and type(itemSystem.GetLocalEquipped) == "function" then
        local ok, controller = pcall(itemSystem.GetLocalEquipped)
        if ok then return controller ~= nil and controller.inventoryItemValue == item end
    end

    local utils = AV.getInventoryItemUtils()
    local ok, equipped = pcall(function() return utils and utils.getEquipped(item) end)
    return ok and equipped == true
end

AV.equipItem = function(name)
    local item = AV.getInventoryItem(name)
    if not item then
        warn("[AutoArrest] Missing inventory item: " .. name)
        return false
    end
    if AV.isItemEquipped(name) then return true end

    local remote = item:FindFirstChild("InventoryEquipRemote")
    if not remote then
        warn("[AutoArrest] Missing equip remote: " .. name)
        return false
    end

    local utils = AV.getInventoryItemUtils()
    if utils then pcall(utils.setEquipped, item, true) end
    remote:FireServer(true)
    for _ = 1, 20 do
        task.wait(0.05)
        if AV.isItemEquipped(name) then return true end
    end
    warn("[AutoArrest] Equip timed out: " .. name)
    return false
end

AV.ensureEquipped = function(name, retryDelay)
    if AV.isItemEquipped(name) then
        AV.shooting.pendingItem = nil
        return true
    end

    local now = tick()
    if AV.shooting.pendingItem ~= name then
        AV.shooting.pendingItem = name
        AV.shooting.lastEquipAttempt = 0
    end
    if now - AV.shooting.lastEquipAttempt < (retryDelay or 1) then return false end

    AV.shooting.lastEquipAttempt = now
    return AV.equipItem(name)
end

AV.useEquippedItem = function(target)
    local itemSystem = AV.getItemSystem()
    if not itemSystem then
        warn("[AutoArrest] ItemSystem unavailable")
        return false
    end

    local controller = itemSystem.GetLocalEquipped()
    if not controller then
        warn("[AutoArrest] No locally equipped item controller")
        return false
    end

    local targetPos = typeof(target) == "Instance" and SoftAimData.getAimPosition(target) or target
    if targetPos then
        local camera = workspace.CurrentCamera
        local screen, onScreen = camera:WorldToScreenPoint(targetPos)
        if not onScreen then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPos)
            screen = camera:WorldToScreenPoint(targetPos)
        end
        game:GetService("VirtualInputManager"):SendMouseMoveEvent(screen.X, screen.Y, game)
        task.wait()
    end

    local input = {
        UserInputType = Enum.UserInputType.MouseButton1,
        KeyCode = Enum.KeyCode.Unknown,
    }
    local inputOk, inputError = pcall(function()
        controller:InputBegan(input, false)
        task.wait(0.05)
        controller:InputEnded(input, false)
    end)
    if not inputOk then
        warn("[AutoArrest] Item input failed: " .. tostring(inputError))
        return false
    end
    return true
end

AV.useTaserAt = function(targetChar)
    local itemSystem = AV.getItemSystem()
    local controller = itemSystem and itemSystem.GetLocalEquipped and itemSystem.GetLocalEquipped()
    local targetRoot = targetChar and (targetChar.PrimaryPart or targetChar:FindFirstChild("HumanoidRootPart"))
    local aimPart = targetChar and (targetChar:FindFirstChild("Head") or targetRoot)
    local tip = controller and controller.Tip
    if not controller or type(controller.Tase) ~= "function" or not targetRoot or not aimPart or not tip then
        return false
    end

    local range = controller.Config and controller.Config.Range or 85
    if (aimPart.Position - tip.Position).Magnitude > range - 2 then return false end

    local input = {
        UserInputType = Enum.UserInputType.MouseButton1,
        KeyCode = Enum.KeyCode.Unknown,
    }
    local previousUpdateMousePosition = rawget(controller, "UpdateMousePosition")
    local previousCanCollide = aimPart.CanCollide
    controller.UpdateMousePosition = function(self)
        local liveAimPart = targetChar and (targetChar:FindFirstChild("Head") or targetChar.PrimaryPart)
        self.MousePosition = liveAimPart and liveAimPart.Position or aimPart.Position
    end
    aimPart.CanCollide = true
    local ok, fired = pcall(controller.Tase, controller, input)
    aimPart.CanCollide = previousCanCollide
    controller.UpdateMousePosition = previousUpdateMousePosition

    if not ok then
        warn("[AutoArrest] Taser fire failed: " .. tostring(fired))
        return false
    end
    return fired == true
end
AV.getVehicleUtils = function()
    if AV.vehicleUtils then return AV.vehicleUtils end
    local ok, vehicleUtils = pcall(require, ReplicatedStorage.Vehicle.VehicleUtils)
    if ok then AV.vehicleUtils = vehicleUtils end
    return AV.vehicleUtils
end

AV.getTireHealth = function(vehicle)
    local vehicleUtils = AV.getVehicleUtils()
    if vehicleUtils and type(vehicleUtils.getTireHealth) == "function" then
        local ok, health = pcall(vehicleUtils.getTireHealth, vehicle)
        if ok then return health end
    end
    return vehicle and vehicle:GetAttribute("VehicleTireHealth") or nil
end

AV.computePath = function(origin, goal)
    local path = game:GetService("PathfindingService"):CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 8,
    })
    local ok = pcall(function()
        path:ComputeAsync(origin, goal)
    end)
    if not ok or path.Status ~= Enum.PathStatus.Success then return nil end
    return path:GetWaypoints()
end

AV.nextGroundWaypoint = function(origin, goal)
    local route = AV.route
    local now = tick()
    route.requestedGoal = goal

    while route.index <= #route.waypoints do
        local currentDistance = (origin - route.waypoints[route.index].Position).Magnitude
        local nextWaypoint = route.waypoints[route.index + 1]
        local passedCurrent = nextWaypoint
            and (origin - nextWaypoint.Position).Magnitude + 1 < currentDistance
        if currentDistance < 8 or passedCurrent then
            route.index += 1
        else
            break
        end
    end

    local shouldRefresh = not route.lastGoal
        or (route.lastGoal - goal).Magnitude > 2
        or now - route.lastAt > 0.35
        or (#route.waypoints > 0 and route.index > #route.waypoints)
    if shouldRefresh and not route.computing then
        route.lastGoal = goal
        route.lastAt = now
        local generation = route.generation
        route.computing = generation
        task.spawn(function()
            local ok, computed = pcall(AV.computePath, origin, goal)
            if route.computing == generation then route.computing = nil end
            if route.generation ~= generation then return end
            if not route.requestedGoal or (route.requestedGoal - goal).Magnitude > 2 then
                route.lastAt = 0
                return
            end
            if not ok or not computed or #computed == 0 then return end

            local currentRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local currentPosition = currentRoot and currentRoot.Position or origin
            local closestIndex, closestDistance = 1, math.huge
            for index, waypoint in ipairs(computed) do
                local distance = (currentPosition - waypoint.Position).Magnitude
                if distance < closestDistance then
                    closestIndex, closestDistance = index, distance
                end
            end
            if closestDistance < 10 and closestIndex < #computed then closestIndex += 1 end
            route.waypoints = computed
            route.index = closestIndex
        end)
    end

    local waypoint = route.waypoints[route.index]
    if waypoint then
        route.lastSteer = waypoint.Position + Vector3.new(0, 3, 0)
        return route.lastSteer
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {player.Character}
    local vehicles = workspace:FindFirstChild("Vehicles")
    if vehicles then table.insert(ignore, vehicles) end
    params.FilterDescendantsInstances = ignore
    pcall(function() params.RespectCanCollide = true end)
    local from = origin + Vector3.new(0, 2, 0)
    local flatGoal = Vector3.new(goal.X, from.Y, goal.Z)
    if not workspace:Raycast(from, flatGoal - from, params) then return goal end
    return route.lastSteer
end
local isOutside -- forward declaration; assigned below

local function isOutsideCached()
    local now = tick()
    if now - AV.lastOutsideCheck < 2 then return AV.outsideCache end
    AV.lastOutsideCheck = now
    AV.outsideCache = isOutside()
    return AV.outsideCache
end

local function clearPathMarkers()
    for _, m in ipairs(AV.pathMarkers) do pcall(function() m:Destroy() end) end
    AV.pathMarkers = {}
end

local EXIT_EXCLUDED_NAMES = { Button = true, TrapButton = true, Plank = true, Shield = true }
local EXIT_EXCLUDED_PATH_WORDS = {
    "laser", "trap", "pillar", "shield", "plank", "bridge", "spike", "tile", "popup",
    "landinggear", "rudder", "button", "wall", "cosmetic", "decorative", "vent", "gate", "shutter",
}

local function isExitDoor(door)
    local vehicles = workspace:FindFirstChild("Vehicles")
    if not door:IsDescendantOf(workspace) then return false end
    if vehicles and door:IsDescendantOf(vehicles) then return false end
    if EXIT_EXCLUDED_NAMES[door.Name] then return false end
    local name = string.lower(door.Name)
    if not string.find(name, "door", 1, true) then return false end
    local path = string.lower(door:GetFullName())
    for _, word in ipairs(EXIT_EXCLUDED_PATH_WORDS) do
        if string.find(path, word, 1, true) then return false end
    end
    return true
end

local function getDoorPosition(door)
    if door:IsA("BasePart") then
        return door.Position
    elseif door:IsA("Model") then
        local cf, _ = door:GetBoundingBox()
        return cf.Position
    end
    return nil
end

local function findNearestExitDoor(origin)
    local nearest, nearestDist, nearestPos = nil, math.huge, nil
    local seen = {}
    for _, tag in ipairs({"Door2", "Door"}) do
        for _, door in ipairs(Services.CollectionService:GetTagged(tag)) do
            if not seen[door] and isExitDoor(door) then
                seen[door] = true
                local pos = getDoorPosition(door)
                if pos then
                    local dist = (origin - pos).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = door
                        nearestPos = pos
                    end
                end
            end
        end
    end
    return nearestPos, nearestDist, nearest
end

local function pathfindToExit()
    if AV.pathfinding then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not hum or not myRoot then return end

    local doorPos, doorDist, door = findNearestExitDoor(myRoot.Position)
    if not doorPos then
        warn("[AutoArrest] No nearby exit door; treating area as outside")
        toggleFlight(false)
        AV.outsideCache = true
        AV.lastOutsideCheck = tick()
        return
    end
    if doorDist > 200 then
        warn("[AutoArrest] Ignoring very distant exit door; treating area as outside")
        toggleFlight(false)
        AV.outsideCache = true
        AV.lastOutsideCheck = tick()
        return
    end
    warn("[AutoArrest] Exit via " .. (door and door.Name or "?") .. " dist=" .. math.floor(doorDist))
    local exitDirection = doorPos - myRoot.Position
    AV.pathfinding = true
    task.spawn(function()
        enableDoorClip(char)

        local waypoints = AV.computePath(myRoot.Position, doorPos) or {{Position = doorPos}}
        for _, waypoint in ipairs(waypoints) do
            local timeout = tick() + 8
            while ArrestSettings.Enabled and tick() < timeout
                and (myRoot.Position - waypoint.Position).Magnitude > 5
            do
                arrestFootFly(waypoint.Position + Vector3.new(0, 3, 0), 60)
                task.wait(0.1)
            end
        end

        if exitDirection.Magnitude > 0 then
            local exitTarget = doorPos + exitDirection.Unit * 50
            local timeout = tick() + 8
            while ArrestSettings.Enabled and tick() < timeout
                and (myRoot.Position - exitTarget).Magnitude > 6
            do
                arrestFootFly(exitTarget, 60)
                task.wait(0.1)
            end
        end

        disableDoorClip(char)
        clearPathMarkers()
        local exited = isOutside()
        toggleFlight(false)
        AV.outsideCache = exited
        AV.lastOutsideCheck = tick()
        AV.pathfinding = false
        if exited then
            AV.lastSpawn = 0
            AV.lastSpawnCheck = 0
            warn("[AutoArrest] Exit done - vehicle spawn ready")
        else
            warn("[AutoArrest] Exit incomplete - retrying")
        end
    end)
end
local function isTargetInVehicle(targetChar)
    if not targetChar then return nil end
    local hum = targetChar:FindFirstChild("Humanoid")
    if not hum or not hum.SeatPart then return nil end
    if hum.SeatPart:IsA("VehicleSeat") or hum.SeatPart:IsA("Seat") then
        return resolveVehicleModel(hum.SeatPart)
    end
    return nil
end

AV.hasOverheadCoverAt = function(position, targetChar)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {player.Character, targetChar}
    local vehicles = workspace:FindFirstChild("Vehicles")
    if vehicles then table.insert(ignore, vehicles) end
    params.FilterDescendantsInstances = ignore
    pcall(function() params.RespectCanCollide = true end)

    local coverHits = 0
    local offsets = {
        Vector3.zero,
        Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0),
        Vector3.new(0, 0, 5), Vector3.new(0, 0, -5),
    }
    for _, offset in ipairs(offsets) do
        local hit = workspace:Raycast(position + offset + Vector3.new(0, 3, 0), Vector3.new(0, 220, 0), params)
        if hit then
            if hit.Instance == workspace.Terrain then return true end
            if hit.Instance:IsA("BasePart") and hit.Instance.CanCollide and hit.Instance.Transparency < 0.9 then
                coverHits += 1
            end
        end
    end
    return coverHits >= 2
end

AV.getSeatApproachPosition = function(seat, origin)
    local right = seat.CFrame.RightVector * 6
    local first = seat.Position + right + Vector3.new(0, 2, 0)
    local second = seat.Position - right + Vector3.new(0, 2, 0)
    if (origin - first).Magnitude <= (origin - second).Magnitude then return first end
    return second
end

local function exitVehicle()
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    hum.Jump = false
    local characterUtilOk, characterUtil = pcall(require, ReplicatedStorage.Game.CharacterUtil)
    local vehicleUtils = AV.getVehicleUtils()

    local requested = false
    if characterUtilOk and type(characterUtil.OnJump) == "function" then
        requested = pcall(characterUtil.OnJump)
    end
    if not requested then
        hum.Sit = false
    end

    for _ = 1, 15 do
        task.wait(0.1)
        local packet
        pcall(function()
            packet = vehicleUtils and vehicleUtils.GetLocalVehiclePacket and vehicleUtils.GetLocalVehiclePacket()
        end)
        if not getVehicle() and not packet then
            return true
        end
    end

    return false
end

isOutside = function()
    local char = player.Character
    if not char then return false end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end

    local origin = myRoot.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local outsideIgnore = {char}
    local vehicles = workspace:FindFirstChild("Vehicles")
    if vehicles then table.insert(outsideIgnore, vehicles) end
    params.FilterDescendantsInstances = outsideIgnore

    local roofHits = 0
    local upDirs = {
        Vector3.new(0, 1, 0),
        Vector3.new(0.5, 0.866, 0),
        Vector3.new(-0.5, 0.866, 0),
        Vector3.new(0, 0.866, 0.5),
        Vector3.new(0, 0.866, -0.5),
    }
    for _, dir in ipairs(upDirs) do
        local hit = workspace:Raycast(origin, dir * 120, params)
        if hit then
            local inst = hit.Instance
            if not inst:IsA("ForceField") and inst.Transparency < 0.9 and inst.CanCollide then
                roofHits += 1
            end
        end
    end

    local wallHits = 0
    local hDirs = {
        Vector3.new(1,0,0), Vector3.new(-1,0,0),
        Vector3.new(0,0,1), Vector3.new(0,0,-1),
    }
    for _, dir in ipairs(hDirs) do
        local hit = workspace:Raycast(origin, dir * 25, params)
        if hit and hit.Instance.CanCollide and hit.Instance.Transparency < 0.9 then
            wallHits += 1
        end
    end

    if wallHits >= 3 or roofHits >= 2 then
        warn("[isOutside] INSIDE - roof=" .. roofHits .. " walls=" .. wallHits)
        return false
    end
    return true
end
local function hasNearbyVehicle(range)
    local char = player.Character
    if not char then return false end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    local vehicles = workspace:FindFirstChild("Vehicles")
    if not vehicles then return false end
    for _, veh in ipairs(vehicles:GetChildren()) do
        local seat = AV.isOwnedAllowedVehicle(veh) and findVehicleSeat(veh)
        if seat and AV.isDriverSeatFree(veh, seat) and (myRoot.Position - seat.Position).Magnitude < range then
            return true
        end
    end
    return false
end

local function spawnVehicleIfNeeded()
    local now = tick()
    local remaining = math.ceil(AV.spawnBlockedUntil - now)
    if remaining > 0 then
        if now - AV.lastSpawnWaitLog >= 5 then
            AV.lastSpawnWaitLog = now
            warn("[AutoArrest] Garage cooldown: " .. remaining .. "s")
        end
        return
    end
    if now - AV.lastSpawn < 8 then return end
    if now - AV.lastSpawnCheck < 2 then return end
    AV.lastSpawnCheck = now

    if hasNearbyVehicle(35) then
        warn("[AutoArrest] Free owned Camaro/Jeep already nearby - skipping spawn")
        return
    end

    local outsideNow = isOutside()
    AV.outsideCache = outsideNow
    AV.lastOutsideCheck = tick()
    if not outsideNow then
        warn("[AutoArrest] Inside building - waiting before spawn retry")
        return
    end

    toggleFlight(false)
    AV.lastSpawn = now
    local previousNotifications = {}
    local playerGui = player:FindFirstChild("PlayerGui")
    local notificationGui = playerGui and playerGui:FindFirstChild("NotificationGui")
    local container = notificationGui and notificationGui:FindFirstChild("Container")
    for _, label in ipairs(container and container:GetDescendants() or {}) do
        if label:IsA("TextLabel") then previousNotifications[label] = label.Text end
    end

    local ok, err = pcall(function()
        local garageOpen = ReplicatedStorage:FindFirstChild("GarageSetUIOpen")
        local spawnRemote = ReplicatedStorage:FindFirstChild("GarageSpawnVehicle")
        if not spawnRemote then error("GarageSpawnVehicle missing") end
        if garageOpen then
            garageOpen:FireServer(true)
            task.delay(0.5, function()
                pcall(function() garageOpen:FireServer(false) end)
            end)
            task.wait(0.1)
        end
        spawnRemote:FireServer("Chassis", "Camaro")
    end)
    if ok then
        local waitSeconds, waitMessage
                                              for _ = 1, 10 do
            task.wait(0.1)
            waitSeconds, waitMessage = AV.readSpawnWaitSeconds(previousNotifications)
            if waitSeconds then break end
        end
        if waitSeconds then
            AV.spawnBlockedUntil = tick() + waitSeconds
            AV.lastSpawnWaitLog = tick()
            warn("[AutoArrest] Garage cooldown detected: " .. waitSeconds .. "s - " .. tostring(waitMessage))
        else
            warn("[AutoArrest] Camaro spawn requested; retrying in 8s if none appears")
        end
    else
        warn("[AutoArrest] Vehicle spawn failed: " .. tostring(err))
    end
end

local function acquireVehicle()
    if AV.acquiring then return false end
    local now = tick()
    if now - AV.lastAcquire < 2 then return false end
    AV.lastAcquire = now

    local char = player.Character
    if not char then return false end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not myRoot or not hum or hum.Health <= 0 then return false end

    local vehicles = Services.Workspace:FindFirstChild("Vehicles")
    if not vehicles then return false end

    local nearest, nearestSeat = nil, nil
    local nearestDist = math.huge

    for _, veh in ipairs(vehicles:GetChildren()) do
        if AV.isOwnedAllowedVehicle(veh) then
            local seat = findVehicleSeat(veh)
            if seat and AV.isDriverSeatFree(veh, seat) then
                local dist = (myRoot.Position - seat.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = veh
                    nearestSeat = seat
                end
            end
        end
    end

    if not nearest then
        warn("[AutoArrest] No owned Camaro or Jeep in workspace.Vehicles")
        return false
    end

    warn("[AutoArrest] Nearest owned " .. AV.getVehicleMake(nearest) .. " dist=" .. math.floor(nearestDist))

    if nearestDist > 350 and now >= AV.spawnBlockedUntil then
        warn("[AutoArrest] Owned car is far away; trying a local Camaro spawn")
        return false
    end

    local seat = nearestSeat
    if not AV.isDriverSeatFree(nearest, seat) then
        warn("[AutoArrest] Driver seat occupied or missing")
        return false
    end
    if nearestDist > 9 then
        arrestFootFly(seat.Position + Vector3.new(0, 3, 0), 60)
        return true
    end

    local entrySpec = AV.getDriverEntrySpec(seat)
    if not entrySpec or entrySpec.Enabled == false then
        warn("[AutoArrest] Enter Driver action not ready; waiting")
        return true
    end

    AV.acquiring = true
    toggleFlight(false)
    local enteredOk, enteredErr = pcall(function()
        entrySpec:Callback(false)
        task.wait(entrySpec.Duration or 1)
        entrySpec:Callback(true)
    end)
    task.wait(0.4)
    AV.acquiring = false

    if not enteredOk then
        warn("[AutoArrest] Enter Driver failed: " .. tostring(enteredErr))
        return false
    end

    local enteredVehicle = getVehicle()
    if enteredVehicle then
        AV.vehicle = enteredVehicle
        AutopilotData.arrived = false
        AutopilotData.vehicleReadyAt = tick() + 1.25
        State.isAtWaypoint = false
        AV.shooting.landingStartedAt = 0
        AV.resetRoute()
        warn("[AutoArrest] Entered owned " .. AV.getVehicleMake(nearest))
        return true
    end

    warn("[AutoArrest] Failed to enter vehicle")
    return false
end

local function setArrestWaypoint(pos)
    local folder = workspace:FindFirstChild("WaypointMarker") or Instance.new("Folder")
    if not folder.Parent then
        folder.Name = "WaypointMarker"
        folder.Parent = workspace
    end
    local wp = folder:FindFirstChild("ArrestTarget")
    if not wp then
        wp = Instance.new("Part")
        wp.Name = "ArrestTarget"
        wp.Anchored = true
        wp.CanCollide = false
        wp.Transparency = 1
        wp.Size = Vector3.new(1, 1, 1)
        wp.Parent = folder
    end
    wp.Position = pos
    AutopilotData.currentWaypoint = wp
    AutopilotData.arrestMode = true
    if not State.autopilotEnabled then
        toggleAutopilot(true)
    end
end

local function clearArrestWaypoint()
    AutopilotData.arrived = false
    AutopilotData.arrestMode = false
    AutopilotData.currentWaypoint = nil
    local folder = workspace:FindFirstChild("WaypointMarker")
    if folder then
        local wp = folder:FindFirstChild("ArrestTarget")
        if wp then wp:Destroy() end
    end
    if State.autopilotEnabled or Connections.autopilot then
        toggleAutopilot(false)
    end
end

local function pressAndHoldE(dur)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.delay(dur or 1, function()
            pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
        end)
    end)
end

local function toggleAutoArrest(state)
    ArrestSettings.Enabled = state
    warn("[AutoArrest] Toggle called with state: " .. tostring(state))

    if state then
        local teamName = player.Team and player.Team.Name:lower() or ""
        if not teamName:find("polic") then
            ArrestSettings.Enabled = false
            warn("[AutoArrest] Police team required")
            return
        end
        warn("[AutoArrest] Starting auto arrest - FLYING PHASE FIRST")
        arrestState.isArresting = false
        arrestState.lastCheck = 0
        AV.shooting = AV.newArrestActionState()
        AV.footMode = false
        AV.resetRoute()
        clearArrestWaypoint()
        AV.vehicle = getVehicle()
        AutopilotData.vehicleReadyAt = AV.vehicle and tick() + 0.75 or 0
        if arrestConnection then arrestConnection:Disconnect() end

        arrestConnection = Services.RunService.Heartbeat:Connect(function()
            if not ArrestSettings.Enabled then
                if arrestConnection then arrestConnection:Disconnect(); arrestConnection = nil end
                clearPathMarkers()
                AV.footMode = false
                return
            end

            if AV.pathfinding then return end

            local now = tick()
            if now - arrestState.lastCheck < ArrestSettings.CheckInterval then return end
            arrestState.lastCheck = now

            local veh = getVehicle()
            if veh ~= AV.vehicle then
                AV.vehicle = veh
                AutopilotData.arrived = false
                AutopilotData.vehicleReadyAt = veh and now + 1.25 or 0
                State.isAtWaypoint = false
                AV.shooting.landingStartedAt = 0
                AV.resetRoute()
            end

            -- No vehicle and not foot-flying: need to get one
            if not veh and not AV.footMode then
                if not acquireVehicle() then
                    if isOutsideCached() then
                        spawnVehicleIfNeeded()
                    else
                        pathfindToExit()
                    end
                end
                return
            end

            if arrestState.isArresting then return end

            local targetPlayer, targetData = findBestTargetForArrest()
            if not targetPlayer or not targetPlayer.Character then
                if AV.shooting.targetUserId ~= nil then AV.resetRoute() end
                AV.shooting = AV.newArrestActionState()
                clearArrestWaypoint()
                return
            end

            local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not targetRoot then
                clearArrestWaypoint()
                return
            end

            local targetHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not targetHum then
                clearArrestWaypoint()
                return
            end
            local hDist = math.sqrt((myRoot.Position.X - targetRoot.Position.X)^2 + (myRoot.Position.Z - targetRoot.Position.Z)^2)
            local vDist = math.abs(myRoot.Position.Y - targetRoot.Position.Y)
            local targetVehicle = isTargetInVehicle(targetPlayer.Character)
            local action = AV.shooting

            if action.targetUserId ~= targetPlayer.UserId or action.targetVehicle ~= targetVehicle then
                action.targetUserId = targetPlayer.UserId
                action.targetVehicle = targetVehicle
                action.tiresPopped = false
                action.vehicleStartedAt = targetVehicle and now or 0
                action.vehicleShots = 0
                action.lastShot = 0
                action.lastTase = 0
                action.lastEquipAttempt = 0
                action.pendingItem = nil
                action.cuffHoldStarted = 0
                action.landingStartedAt = 0
                AutopilotData.arrived = false
                AV.resetRoute()
            end

            local targetCovered = AV.hasOverheadCoverAt(targetRoot.Position, targetPlayer.Character)
            local pursuitPos = targetRoot.Position
            local holdingCuffs = false

            -- Covered targets use the existing ground path instead of flying into tunnel terrain.
            -- ponytail: add tunnel-entrance indexing only if the ground route proves too slow.
            if veh and not AV.footMode then
                local exitRadius = targetVehicle and 30 or 18
                local maxExitVertical = targetCovered and 40 or 20
                local shouldExit = hDist < exitRadius and vDist < maxExitVertical
                if shouldExit then
                    if now - action.landingStartedAt < 0.5 then return end
                    action.landingStartedAt = now
                    warn("[AutoArrest] Close to target - exiting vehicle")
                    local exited = exitVehicle()
                    if exited then
                        AV.footMode = true
                        clearArrestWaypoint()
                    else
                        warn("[AutoArrest] Vehicle exit did not complete; retrying")
                    end
                    return
                end
            end

            if targetVehicle and AV.footMode then
                local tireHealth = AV.getTireHealth(targetVehicle)
                if type(tireHealth) == "number" and tireHealth <= 0 then
                    if not action.tiresPopped then warn("[AutoArrest] Target tires disabled") end
                    action.tiresPopped = true
                elseif type(tireHealth) ~= "number" and action.vehicleShots >= 20 then
                    action.tiresPopped = true
                    warn("[AutoArrest] Tire health unavailable after 20 shots; advancing to cuffs")
                end

                if not action.tiresPopped then
                    if AV.ensureEquipped("Pistol", 1) and now - action.lastShot >= 0.15 then
                        local targetVehicleRoot = getRoot(targetVehicle)
                        if targetVehicleRoot and AV.useEquippedItem(targetVehicleRoot.Position) then
                            action.lastShot = now
                            action.vehicleShots += 1
                        end
                    end
                else
                    local targetSeat = targetHum.SeatPart
                    if targetSeat then
                        pursuitPos = AV.getSeatApproachPosition(targetSeat, myRoot.Position)
                        local seatDelta = targetSeat.Position - myRoot.Position
                        local seatHorizontal = Vector3.new(seatDelta.X, 0, seatDelta.Z).Magnitude
                        local hasCuffs = AV.ensureEquipped("Handcuffs", 0.5)
                        if seatHorizontal <= 9 and math.abs(seatDelta.Y) <= 14
                            and hasCuffs
                        then
                            holdingCuffs = true
                            if action.cuffHoldStarted == 0 then
                                action.cuffHoldStarted = now
                                warn("[AutoArrest] Ejecting " .. targetPlayer.Name .. " from " .. targetSeat.Name)
                            end
                            if now - action.lastEjectPress > 0.5 then
                                action.lastEjectPress = now
                                pressAndHoldE(1)
                            end
                        else
                            action.cuffHoldStarted = 0
                        end
                    end
                end
            elseif not targetVehicle then
                local canCuff = hDist <= 10 and vDist <= 14
                    and arrestRaycastCheck(targetPlayer.Character, myRoot.Position, player.Character)
                if canCuff and AV.footMode and AV.ensureEquipped("Handcuffs", 0.5) then
                    holdingCuffs = true
                    if action.cuffHoldStarted == 0 then
                        action.cuffHoldStarted = now
                        warn("[AutoArrest] Holding cuffs on " .. targetPlayer.Name .. " (Bounty: " .. targetData.bounty .. ")")
                    end
                else
                    action.cuffHoldStarted = 0
                    if AV.footMode and hDist < 85 and now - action.lastTase >= 10
                        and arrestRaycastCheck(targetPlayer.Character, myRoot.Position, player.Character)
                        and AV.ensureEquipped("Taser", 1)
                    then
                        if AV.useTaserAt(targetPlayer.Character) then
                            action.lastTase = now
                            warn("[AutoArrest] Tasing " .. targetPlayer.Name .. " before cuff pursuit")
                        end
                    end
                end
            end

            if holdingCuffs then
                clearArrestWaypoint()
                arrestFootFly(nil)
                if now - action.lastEjectPress > 0.75 then
                    action.lastEjectPress = now
                    pressAndHoldE(1.5)
                end
                return
            end

            if AV.footMode then
                local nextPoint = AV.nextGroundWaypoint(myRoot.Position, pursuitPos)
                arrestFootFly(nextPoint or pursuitPos, 80)
            else
                setArrestWaypoint(targetRoot.Position)
            end
        end)
        warn("[AutoArrest] ACTIVE - Criminals only | fly 2x speed | path+exit if inside")
    else
        warn("[AutoArrest] Stopping auto arrest...")
        if arrestConnection then
            arrestConnection:Disconnect()
            arrestConnection = nil
        end
        arrestState.isArresting = false
        AV.footMode = false
        AV.pathfinding = false
        AV.vehicle = nil
        AV.resetRoute()
        AutopilotData.vehicleReadyAt = 0
        clearPathMarkers()
        AV.shooting = AV.newArrestActionState()
        clearArrestWaypoint()
        toggleFlight(false)
    end

    pcall(function()
        if Buttons.arrestToggle and Buttons.arrestToggle.updateSwitch then
            Buttons.arrestToggle.updateSwitch(state, true)
        end
    end)
end

State.killScript = function()
    if State.killed then return end
    State.killed = true
    warn("[Script] Kill requested - cleaning up")

    pcall(function() toggleAutoArrest(false) end)
    pcall(function() toggleFlight(false) end)
    pcall(function() toggleAutopilot(false) end)
    pcall(function() toggleSoftAim(false) end)
    pcall(function() toggleOldSoftAim(false) end)
    pcall(function() toggleWaterBypass(false) end)
    pcall(function() toggleLaserRemover(false) end)
    pcall(function() toggleTeamIcons(false) end)
    pcall(function() toggleESP(false) end)
    pcall(function() toggleVehFly(false) end)
    pcall(function() toggleC4Orbit(false) end)
    pcall(stopRemoteVehFly)
    pcall(stopBankCharFly)
    pcall(clearAllESP)
    pcall(clearPathMarkers)
    pcall(setFallProtection, player.Character, false)

    BankRobSettings.Enabled = false
    ArrestSettings.Enabled = false
    if bankRobState.phaseConnection then
        pcall(function() bankRobState.phaseConnection:Disconnect() end)
        bankRobState.phaseConnection = nil
    end
    if arrestConnection then
        pcall(function() arrestConnection:Disconnect() end)
        arrestConnection = nil
    end

    cleanupTeamIconMonitoring()
    for i = #playerListConnections, 1, -1 do
        pcall(function() playerListConnections[i]:Disconnect() end)
        playerListConnections[i] = nil
    end
    for key, connection in pairs(Connections) do
        pcall(function() connection:Disconnect() end)
        Connections[key] = nil
    end

    local playerGui = player:FindFirstChild("PlayerGui")
    local screenGui = playerGui and playerGui:FindFirstChild(State.guiID)
    if screenGui then screenGui:Destroy() end
    _G[scriptMarker] = nil
    warn("[Script] Killed. Re-run the file to start a clean instance.")
end

_G[scriptMarker] = {
    Disconnect = function()
        State.killScript()
    end,
}

local gui  -- declared here so keybind handler can reference it after the GUI scope
State.defineGUI = function()
-- ===== GUI COLORS =====
local accentColor = Color3.fromRGB(91, 0, 145)
local accentColorDark = Color3.fromRGB(58, 0, 92)
local accentColorLight = Color3.fromRGB(132, 24, 190)
local bgPrimary = Color3.fromRGB(17, 17, 17)
local bgSecondary = Color3.fromRGB(27, 27, 27)
local bgTertiary = Color3.fromRGB(21, 21, 21)
local textPrimary = Color3.fromRGB(242, 242, 242)
local textSecondary = Color3.fromRGB(218, 218, 218)
local textMuted = Color3.fromRGB(112, 112, 112)
local successColor = Color3.fromRGB(74, 222, 128)
local dangerColor = Color3.fromRGB(248, 113, 113)
local warningColor = Color3.fromRGB(251, 191, 36)

local function tweenProperty(obj, props, duration)
    local ti = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tween = Services.TweenService:Create(obj, ti, props)
    tween:Play()
    return tween
end

local function createToggleSwitch(parent, yPos, labelText, initialState, onToggle)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -8, 0, 30)
    container.Position = UDim2.new(0, 4, 0, yPos)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Parent = parent
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 0)
    containerCorner.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -52, 1, 0)
    label.Position = UDim2.new(0, 44, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = textPrimary
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local switchBg = Instance.new("Frame")
    switchBg.Size = UDim2.new(0, 26, 0, 26)
    switchBg.Position = UDim2.new(0, 8, 0, 2)
    switchBg.BackgroundColor3 = initialState and accentColorLight or accentColor
    switchBg.BorderSizePixel = 0
    switchBg.Parent = container
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(0, 6)
    switchCorner.Parent = switchBg
    
    local switchKnob = Instance.new("TextLabel")
    switchKnob.Size = UDim2.new(1, 0, 1, 0)
    switchKnob.Position = UDim2.new(0, 0, 0, 0)
    switchKnob.BackgroundTransparency = 1
    switchKnob.Text = utf8.char(10003)          -- checkmark
    switchKnob.TextColor3 = Color3.fromRGB(255, 255, 255)
    switchKnob.TextSize = 18
    switchKnob.Font = Enum.Font.GothamBold
    switchKnob.TextScaled = false
    switchKnob.Parent = switchBg
    switchKnob.Visible = initialState
    
    local state = initialState
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = container
    
    local function updateSwitch(newState, skipCallback)
        state = newState
        tweenProperty(switchBg, {BackgroundColor3 = state and accentColorLight or accentColor}, 0.15)
        switchKnob.Visible = state
        if not skipCallback and onToggle then onToggle(state) end
    end
    
    btn.Activated:Connect(function()
        updateSwitch(not state)
    end)
    
    btn.MouseEnter:Connect(function()
        tweenProperty(label, {TextColor3 = accentColorLight}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tweenProperty(label, {TextColor3 = textPrimary}, 0.15)
    end)
    
    return {container = container, updateSwitch = updateSwitch, getState = function() return state end}
end

local function createSectionHeader(parent, yPos, text)
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -8, 0, 25)
    header.Position = UDim2.new(0, 4, 0, yPos)
    header.BackgroundColor3 = accentColor
    header.BorderSizePixel = 0
    header:SetAttribute("JBSectionHeader", true)
    header:SetAttribute("JBCollapsed", true)
    header.Parent = parent
    
    local accent = Instance.new("TextLabel")
    accent.Name = "Arrow"
    accent.Size = UDim2.new(0, 30, 1, 0)
    accent.BackgroundTransparency = 1
    accent.Text = utf8.char(9654)
    accent.TextColor3 = textPrimary
    accent.TextSize = 15
    accent.Font = Enum.Font.Gotham
    accent.Parent = header
    
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 4)
    accentCorner.Parent = header
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -36, 1, 0)
    label.Position = UDim2.new(0, 34, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = textPrimary
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = header
    
    return header
end

local function activateSectionDropdowns(parent)
    local headers, items = {}, {}
    local baseCanvasY = parent.CanvasSize.Y.Offset

    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            child:SetAttribute("JBBaseY", child.Position.Y.Offset)
            child:SetAttribute("JBBaseVisible", child.Visible)
            items[#items + 1] = child
            if child:GetAttribute("JBSectionHeader") then headers[#headers + 1] = child end
        end
    end
    table.sort(headers, function(a, b) return a:GetAttribute("JBBaseY") < b:GetAttribute("JBBaseY") end)

    local function relayout()
        local removed = 0
        for index, header in ipairs(headers) do
            local startY = header:GetAttribute("JBBaseY")
            local endY = headers[index + 1] and headers[index + 1]:GetAttribute("JBBaseY") or baseCanvasY
            local collapsed = header:GetAttribute("JBCollapsed") == true
            local arrow = header:FindFirstChild("Arrow")
            if arrow then arrow.Text = collapsed and utf8.char(9654) or utf8.char(9660) end
            header.Position = UDim2.new(header.Position.X.Scale, header.Position.X.Offset, header.Position.Y.Scale, startY - removed)

            for _, item in ipairs(items) do
                local baseY = item:GetAttribute("JBBaseY")
                if item ~= header and baseY > startY and baseY < endY then
                    item.Visible = not collapsed and item:GetAttribute("JBBaseVisible") == true
                    item.Position = UDim2.new(item.Position.X.Scale, item.Position.X.Offset, item.Position.Y.Scale, baseY - removed)
                end
            end
            if collapsed then removed += math.max(0, endY - startY - 30) end
        end
        parent.CanvasSize = UDim2.new(parent.CanvasSize.X.Scale, parent.CanvasSize.X.Offset, 0, baseCanvasY - removed)
    end

    for _, header in ipairs(headers) do
        local sectionHeader = header
        local button = Instance.new("TextButton")
        button.Name = "SectionToggle"
        button.Size = UDim2.fromScale(1, 1)
        button.BackgroundTransparency = 1
        button.Text = ""
        button.ZIndex = sectionHeader.ZIndex + 1
        button.Parent = sectionHeader
        button.Activated:Connect(function()
            sectionHeader:SetAttribute("JBCollapsed", not sectionHeader:GetAttribute("JBCollapsed"))
            relayout()
        end)
    end
    relayout()
end

local function createInputField(parent, yPos, labelText, defaultValue)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -8, 0, 30)
    container.Position = UDim2.new(0, 4, 0, yPos)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Parent = parent
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 0)
    containerCorner.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.55, -44, 1, 0)
    label.Position = UDim2.new(0, 44, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = textSecondary
    label.TextSize = 15
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local inputBg = Instance.new("Frame")
    inputBg.Size = UDim2.new(0, 130, 0, 26)
    inputBg.Position = UDim2.new(1, -142, 0, 2)
    inputBg.BackgroundColor3 = accentColorDark
    inputBg.BorderSizePixel = 0
    inputBg.Parent = container
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = inputBg
    
    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = accentColor
    inputStroke.Thickness = 1
    inputStroke.Parent = inputBg
    
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -16, 1, 0)
    input.Position = UDim2.new(0, 8, 0, 0)
    input.BackgroundTransparency = 1
    input.Text = defaultValue
    input.TextColor3 = textPrimary
    input.PlaceholderColor3 = textMuted
    input.TextSize = 14
    input.Font = Enum.Font.Gotham
    input.ClearTextOnFocus = false
    input.Parent = inputBg
    
    input.Focused:Connect(function()
        tweenProperty(inputStroke, {Color = accentColor}, 0.15)
    end)
    input.FocusLost:Connect(function()
        tweenProperty(inputStroke, {Color = accentColor}, 0.15)
    end)
    
    return input
end

local function createButton(parent, yPos, text, isPrimary)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, math.clamp(#text * 8 + 22, 96, 360), 0, 26)
    btn.Position = UDim2.new(0, 12, 0, yPos)
    btn.BackgroundColor3 = isPrimary and accentColorLight or accentColor
    btn.Text = text
    btn.TextColor3 = textPrimary
    btn.TextSize = 15
    btn.Font = Enum.Font.Gotham
    btn.AutoButtonColor = false
    btn.Parent = parent
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        tweenProperty(btn, {BackgroundColor3 = accentColorLight}, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tweenProperty(btn, {BackgroundColor3 = isPrimary and accentColorLight or accentColor}, 0.15)
    end)
    btn.MouseButton1Down:Connect(function()
        tweenProperty(btn, {BackgroundColor3 = accentColorDark}, 0.08)
    end)
    btn.MouseButton1Up:Connect(function()
        tweenProperty(btn, {BackgroundColor3 = isPrimary and accentColorLight or accentColor}, 0.08)
    end)
    
    return btn
end

local function createMainFrame(screenGui)
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 560, 0, 470)
    mainFrame.Position = UDim2.new(0.5, -280, 0.5, -235)
    mainFrame.BackgroundColor3 = bgPrimary
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 4)
    mainCorner.Parent = mainFrame

    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(8, 8, 8)
    border.Thickness = 2
    border.Parent = mainFrame
    return mainFrame
end

local function createTitleBar(mainFrame)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = accentColor
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 6)
    titleCorner.Parent = titleBar
    
    local titleCover = Instance.new("Frame")
    titleCover.Size = UDim2.new(1, 0, 0, 8)
    titleCover.Position = UDim2.new(0, 0, 1, -8)
    titleCover.BackgroundColor3 = accentColor
    titleCover.BorderSizePixel = 0
    titleCover.Parent = titleBar
    
    local logoIcon = Instance.new("TextButton")
    logoIcon.Size = UDim2.new(0, 28, 1, 0)
    logoIcon.Position = UDim2.new(0, 4, 0, 0)
    logoIcon.BackgroundTransparency = 1
    logoIcon.BorderSizePixel = 0
    logoIcon.Text = utf8.char(9660)
    logoIcon.TextColor3 = textPrimary
    logoIcon.TextSize = 18
    logoIcon.Font = Enum.Font.Gotham
    logoIcon.Parent = titleBar

    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 4)
    logoCorner.Parent = logoIcon

    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 1, 0)
    logoText.BackgroundTransparency = 1
    logoText.Text = "JB"
    logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoText.TextSize = 14
    logoText.Font = Enum.Font.GothamBlack
    logoText.Parent = logoIcon

    logoText.Visible = false
    local uiCollapsed = false
    local activeCollapseTween = nil
    -- Grab mainFrame's UICorner so we can fix black-corner artifact when collapsed
    local mainCorner = mainFrame:FindFirstChildOfClass("UICorner")

    logoIcon.Activated:Connect(function()
        if activeCollapseTween then activeCollapseTween:Cancel() end
        uiCollapsed = not uiCollapsed
        local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if uiCollapsed then
            logoIcon.Text = utf8.char(9654)
            -- Hide titleCover (its job is to flatten bottom when expanded — not needed when collapsed)
            titleCover.Visible = false
            -- Match mainFrame corner radius to titleBar so no black bleeds through
            if mainCorner then mainCorner.CornerRadius = UDim.new(0, 6) end
            activeCollapseTween = Services.TweenService:Create(mainFrame, ti, {
                Size = UDim2.new(0, 560, 0, 28)
            })
            activeCollapseTween:Play()
        else
            logoIcon.Text = utf8.char(9660)
            titleCover.Visible = true
            if mainCorner then mainCorner.CornerRadius = UDim.new(0, 4) end
            activeCollapseTween = Services.TweenService:Create(mainFrame, ti, {
                Size = UDim2.new(0, 560, 0, 470)
            })
            activeCollapseTween:Play()
        end
    end)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -76, 1, 0)
    title.Position = UDim2.new(0, 36, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Jailbreak Enhanced"
    title.TextColor3 = textPrimary
    title.TextSize = 17
    title.Font = Enum.Font.Gotham
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -110, 0, 14)
    subtitle.Position = UDim2.new(0, 56, 0, 32)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "v2 • Free Version"
    subtitle.TextColor3 = textMuted
    subtitle.TextSize = 11
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = titleBar
    subtitle.Text = "SESSION TOOLS / LIVE STATE"
    
    subtitle.Visible = false
    local statusContainer = Instance.new("Frame")
    statusContainer.Size = UDim2.new(0, 64, 0, 24)
    statusContainer.Position = UDim2.new(1, -108, 0.5, -12)
    statusContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    statusContainer.BorderSizePixel = 0
    statusContainer.Parent = titleBar
    
    statusContainer.Visible = false
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 4)
    statusCorner.Parent = statusContainer
    
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 6, 0, 6)
    statusDot.Position = UDim2.new(0, 10, 0.5, -3)
    statusDot.BackgroundColor3 = successColor
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusContainer
    
    local statusDotCorner = Instance.new("UICorner")
    statusDotCorner.CornerRadius = UDim.new(1, 0)
    statusDotCorner.Parent = statusDot
    
    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -22, 1, 0)
    statusText.Position = UDim2.new(0, 20, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "LIVE"
    statusText.TextColor3 = successColor
    statusText.TextSize = 10
    statusText.Font = Enum.Font.GothamBold
    statusText.Parent = statusContainer
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 28, 1, 0)
    closeButton.Position = UDim2.new(1, -30, 0, 0)
    closeButton.BackgroundTransparency = 1
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = textPrimary
    closeButton.TextSize = 14
    closeButton.Font = Enum.Font.Gotham
    closeButton.Parent = titleBar
    closeButton.Activated:Connect(function()
        State.guiVisible = false
        local startPos = mainFrame.Position
        local ti = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        local slideTween = Services.TweenService:Create(mainFrame, ti, {
            Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset - 24)
        })
        slideTween:Play()
        slideTween.Completed:Connect(function()
            mainFrame.Visible = false
            mainFrame.Position = startPos  -- reset so next open is in same spot
        end)
    end)
    return titleBar
end

local function createTabSystem(mainFrame)
    local nav = Instance.new("Frame")
    nav.Size = UDim2.new(1, 0, 0, 36)
    nav.Position = UDim2.new(0, 0, 0, 28)
    nav.BackgroundColor3 = bgSecondary
    nav.BorderSizePixel = 0
    nav.Parent = mainFrame

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 2)
    divider.Position = UDim2.new(0, 0, 1, -2)
    divider.BackgroundColor3 = accentColorDark
    divider.BorderSizePixel = 0
    divider.Parent = nav

    local tabs = {"Features", "Vehicle", "Settings"}
    local tabButtons = {}
    local tabMarkers = {}
    local contentFrames = {}
    local currentTab = 1

    for i, tabName in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(0, 100, 1, -2)
        tabBtn.Position = UDim2.new(0, 12 + ((i - 1) * 100), 0, 0)
        tabBtn.BackgroundTransparency = 1
        tabBtn.BorderSizePixel = 0
        tabBtn.Text = tabName
        tabBtn.TextColor3 = i == 1 and textPrimary or textMuted
        tabBtn.TextSize = 16
        tabBtn.Font = Enum.Font.Gotham
        tabBtn.Parent = nav
        tabButtons[i] = tabBtn

        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 4)
        tabCorner.Parent = tabBtn
        local marker = Instance.new("Frame")
        marker.Size = UDim2.new(1, -22, 0, 2)
        marker.Position = UDim2.new(0, 11, 1, -2)
        marker.BackgroundColor3 = accentColor
        marker.BorderSizePixel = 0
        marker.Visible = i == 1
        marker.Parent = tabBtn
        tabMarkers[i] = marker

        local content = Instance.new("ScrollingFrame")
        content.Size = UDim2.new(1, -32, 1, -78)
        content.Position = UDim2.new(0, 16, 0, 72)
        content.BackgroundColor3 = bgPrimary
        content.BackgroundTransparency = 0
        content.BorderSizePixel = 0
        content.CanvasSize = UDim2.new(0, 0, 0, 800)
        content.ScrollBarThickness = 6
        content.ScrollBarImageColor3 = accentColor
        content.Visible = i == 1
        content.Parent = mainFrame
        contentFrames[i] = content

        tabBtn.Activated:Connect(function()
            if currentTab == i then return end
            currentTab = i
            for j, btn in ipairs(tabButtons) do
                btn.TextColor3 = j == i and textPrimary or textMuted
                tabMarkers[j].Visible = j == i
                contentFrames[j].Visible = j == i
            end
        end)
    end
    return contentFrames
end

local RobberyTracker = {
    CasinoCodeDisplay = "",
    RobberyStatusDisplay = {},
    rows = nil,
    codes = nil,
    STATUS = {[1] = "OPEN", [2] = "STARTED", [3] = "CLOSED"},
    ROBBERY_ORDER = {
        "Bank", "Bank2", "Jewelry", "Museum", "PowerPlant", "TrainPassenger",
        "TrainCargo", "CargoShip", "CargoPlane", "Gas", "Donut", "MoneyTruck",
        "HomeVault", "Tomb", "Casino", "Mansion", "OilRig",
    },
    casinoUpdateRunning = false,
    robberyUpdateRunning = false,
}

local function updateCasinoCode()
    if RobberyTracker.casinoUpdateRunning then return end
    RobberyTracker.casinoUpdateRunning = true
    task.spawn(function()
        while RobberyTracker.casinoUpdateRunning and not State.killed do
            pcall(function()
                local codes = RobberyTracker.codes
                if not codes or not codes.Parent then
                    local casino = Services.Workspace:FindFirstChild("Casino", true)
                    local robberyDoor = casino and casino:FindFirstChild("RobberyDoor", true)
                    codes = robberyDoor and robberyDoor:FindFirstChild("Codes", true)
                    RobberyTracker.codes = codes
                end
                if codes then
                        local code = ""
                        local digits = {}
                        for _, label in ipairs(codes:GetDescendants()) do
                            if label:IsA("TextLabel") or label:IsA("TextButton") then
                                local textDigits = string.gsub(label.Text, "%D", "")
                                if #textDigits == 4 then
                                    code = textDigits
                                    break
                                elseif #textDigits == 1 and label.Visible then
                                    local gui = label.Parent
                                    while gui and not gui:IsA("SurfaceGui") and gui ~= codes do gui = gui.Parent end
                                    local part = gui and gui:IsA("SurfaceGui")
                                        and (gui.Adornee or (gui.Parent and gui.Parent:IsA("BasePart") and gui.Parent)) or nil
                                    table.insert(digits, {
                                        digit = textDigits,
                                        gui = gui,
                                        part = part,
                                        path = label:GetFullName(),
                                    })
                                end
                            end
                        end
                        if code == "" and #digits == 4 then
                            local axis
                            local center = Vector3.zero
                            local allPartsPresent = true
                            for _, entry in ipairs(digits) do
                                if not entry.part then
                                    allPartsPresent = false
                                    break
                                end
                                center = center + entry.part.Position
                            end
                            local reference = digits[1]
                            if allPartsPresent and reference.gui and reference.part then
                                center = center / #digits
                                local localNormal = Vector3.FromNormalId(reference.gui.Face)
                                local worldNormal = reference.part.CFrame:VectorToWorldSpace(localNormal)
                                local worldUp = reference.part.CFrame.UpVector
                                if math.abs(worldNormal:Dot(worldUp)) > 0.95 then
                                    worldUp = reference.part.CFrame.LookVector
                                end
                                axis = CFrame.lookAt(center + worldNormal * 20, center, worldUp).RightVector
                            end
                            table.sort(digits, function(a, b)
                                if axis and a.part and b.part then
                                    return a.part.Position:Dot(axis) < b.part.Position:Dot(axis)
                                end
                                    return a.path < b.path
                            end)
                            for _, entry in ipairs(digits) do code = code .. entry.digit end
                        end
                        if #code == 4 and code ~= RobberyTracker.CasinoCodeDisplay then
                            RobberyTracker.CasinoCodeDisplay = code
                            if codeLabel then
                                codeLabel.Text = "CASINO CODE / " .. code
                                codeLabel.TextColor3 = successColor
                            end
                        end
                end
            end)
            task.wait(0.5)
        end
    end)
end

local function updateRobberyStatus()
    if RobberyTracker.robberyUpdateRunning then return end
    RobberyTracker.robberyUpdateRunning = true
    task.spawn(function()
        while RobberyTracker.robberyUpdateRunning and not State.killed do
            pcall(function()
                local stateFolder = ReplicatedStorage:FindFirstChild("RobberyState")
                for i, name in ipairs(RobberyTracker.ROBBERY_ORDER) do
                    local value = stateFolder and stateFolder:FindFirstChild(tostring(i))
                    local status = value and value:IsA("IntValue")
                        and (RobberyTracker.STATUS[value.Value] or "UNKNOWN") or "UNKNOWN"
                    -- Fix: Museum server state can lag behind; cross-reference IsOpen flag
                    if name == "Museum" and status == "STARTED" then
                        local flow = Museum and Museum.flow
                        if flow and flow.IsOpen == false then
                            status = "CLOSED"
                        end
                    end
                    RobberyTracker.RobberyStatusDisplay[name] = status
                    local row = RobberyTracker.rows and RobberyTracker.rows[name]
                    if row and row.status.Text ~= status then
                        local color = status == "OPEN" and successColor
                            or status == "STARTED" and warningColor
                            or status == "CLOSED" and dangerColor or textMuted
                        row.dot.BackgroundColor3 = color
                        row.status.Text = status
                        row.status.TextColor3 = color
                        end
                end
            end)
            task.wait(1)
        end
    end)
end

task.delay(0.5, updateCasinoCode)
task.delay(0.5, updateRobberyStatus)

State.setupFeaturesTab = function(scrollingFrame)
    local yPos = 0

    createSectionHeader(scrollingFrame, yPos, "Combat")
    yPos = yPos + 30
    
    local softAimToggle = createToggleSwitch(scrollingFrame, yPos, "Soft Aim", false, function(state)
        toggleSoftAim(state)
    end)
    Buttons.softAimToggle = softAimToggle
    yPos = yPos + 34

    local oldSoftAimToggle = createToggleSwitch(scrollingFrame, yPos, "OLD aim", false, function(state)
        toggleOldSoftAim(state)
    end)
    Buttons.oldSoftAimToggle = oldSoftAimToggle
    yPos = yPos + 34

    local wallbangToggle = createToggleSwitch(scrollingFrame, yPos, "Wall Bang (Terrain + Cover)", false, function(state)
        SoftAimData.settings.Wallbang = state
    end)
    Buttons.softAimWallbangToggle = wallbangToggle
    yPos = yPos + 34

    createSectionHeader(scrollingFrame, yPos, "Robberies")
    yPos = yPos + 30

    local museumToggle = createToggleSwitch(scrollingFrame, yPos, "Auto Solve Museum", false, function(state)
        toggleAutoSolveMuseum(state)
    end)
    Buttons.museumToggle = museumToggle
    yPos = yPos + 34

    local dynamiteBtn = createButton(scrollingFrame, yPos, "Place Dynamite Now", false)
    dynamiteBtn.MouseButton1Click:Connect(function()
        pcall(Museum.placeDynamiteNow)
    end)
    yPos = yPos + 34

    createSectionHeader(scrollingFrame, yPos, "Movement")
    yPos = yPos + 30

    local noclipSw = createToggleSwitch(scrollingFrame, yPos, "Noclip", false, function(state)
        toggleNoclip(state)
    end)
    Buttons.noclipToggle = noclipSw
    yPos = yPos + 34

    local flightSw = createToggleSwitch(scrollingFrame, yPos, "Player Flight", false, function(state)
        State.flightEnabled = state
        toggleFlight(state)
    end)
    Buttons.flightToggle = flightSw
    yPos = yPos + 34
    
    local autopilotSw = createToggleSwitch(scrollingFrame, yPos, "Autopilot", false, function(state)
        State.autopilotEnabled = state
        toggleAutopilot(state)
    end)
    Buttons.autopilotToggle = autopilotSw
    yPos = yPos + 34
    
    createSectionHeader(scrollingFrame, yPos, "Visuals")
    yPos = yPos + 30
    
    local teamIconSw = createToggleSwitch(scrollingFrame, yPos, "Team Icons", false, function(state)
        State.teamIconsEnabled = state
        toggleTeamIcons(state)
    end)
    Buttons.teamIconToggle = teamIconSw
    yPos = yPos + 34
    
    local laserSw = createToggleSwitch(scrollingFrame, yPos, "Remove Lasers", State.laserRemoverEnabled, function(state)
        State.laserRemoverEnabled = state
        toggleLaserRemover(state)
    end)
    Buttons.laserToggle = laserSw
    yPos = yPos + 34
    
    local lavaBtn = createButton(scrollingFrame, yPos, "Trigger Volcano Lava", false)
    lavaBtn.MouseButton1Click:Connect(function()
        pcall(triggerVolcanoLava)
    end)
    yPos = yPos + 34

    codeLabel = Instance.new("TextLabel")
    codeLabel.Size = UDim2.new(1, -8, 0, 28)
    codeLabel.Position = UDim2.new(0, 4, 0, yPos)
    codeLabel.BackgroundColor3 = accentColorDark
    codeLabel.Text = "  🎰 Casino Code: ----"
    codeLabel.TextColor3 = textMuted
    codeLabel.TextSize = 14
    codeLabel.Font = Enum.Font.Gotham
    codeLabel.TextXAlignment = Enum.TextXAlignment.Left
    codeLabel.TextYAlignment = Enum.TextYAlignment.Center
    codeLabel.Parent = scrollingFrame
    codeLabel.Text = "CASINO CODE / " .. (RobberyTracker.CasinoCodeDisplay ~= "" and RobberyTracker.CasinoCodeDisplay or "----")
    codeLabel.TextColor3 = RobberyTracker.CasinoCodeDisplay ~= "" and successColor or textMuted
    local codeLabelCorner = Instance.new("UICorner")
    codeLabelCorner.CornerRadius = UDim.new(0, 4)
    codeLabelCorner.Parent = codeLabel

    yPos = yPos + 34

    createSectionHeader(scrollingFrame, yPos, "Robberies")
    yPos = yPos + 30

    local robberyPanel = Instance.new("Frame")
    robberyPanel.Size = UDim2.new(1, -8, 0, 282)
    robberyPanel.Position = UDim2.new(0, 4, 0, yPos)
    robberyPanel.BackgroundColor3 = bgPrimary
    robberyPanel.BorderSizePixel = 0
    robberyPanel.Parent = scrollingFrame
    local robberyPanelCorner = Instance.new("UICorner")
    robberyPanelCorner.CornerRadius = UDim.new(0, 4)
    robberyPanelCorner.Parent = robberyPanel
    local robberyPanelStroke = Instance.new("UIStroke")
    robberyPanelStroke.Color = accentColorDark
    robberyPanelStroke.Thickness = 1
    robberyPanelStroke.Parent = robberyPanel

    local robberyRows = {}
    RobberyTracker.rows = robberyRows
    for index, name in ipairs(RobberyTracker.ROBBERY_ORDER) do
        local column = (index - 1) % 2
        local rowIndex = math.floor((index - 1) / 2)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(0.5, -10, 0, 29)
        row.Position = UDim2.new(column * 0.5, column == 0 and 6 or 4, 0, 4 + (rowIndex * 30))
        row.BackgroundTransparency = 1
        row.Parent = robberyPanel

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 7, 0, 7)
        dot.Position = UDim2.new(0, 2, 0.5, -3)
        dot.BackgroundColor3 = textMuted
        dot.BorderSizePixel = 0
        dot.Parent = row
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -82, 1, 0)
        nameLabel.Position = UDim2.new(0, 16, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = name
        nameLabel.TextColor3 = textSecondary
        nameLabel.TextSize = 11
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = row

        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0, 64, 1, 0)
        statusLabel.Position = UDim2.new(1, -64, 0, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "UNKNOWN"
        statusLabel.TextColor3 = textMuted
        statusLabel.TextSize = 9
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel.Parent = row
        robberyRows[name] = {dot = dot, status = statusLabel}
    end

    yPos = yPos + 290

    -- ===== EXTRAS =====
    createSectionHeader(scrollingFrame, yPos, "Extras")
    yPos = yPos + 30
    local destructibleButton = createButton(scrollingFrame, yPos, "Break All / Sky Smiley", false)
    destructibleButton.Activated:Connect(function()
        if destructibleTriggerRunning then return end
        destructibleButton.Text = "Breaking..."
        task.spawn(function()
            local count, smileyCount = triggerAllDestructibles(true)
            if not State.killed and destructibleButton.Parent then
                destructibleButton.Text = "BROKE " .. tostring(count) .. " / FACE " .. tostring(smileyCount)
                task.wait(2)
                if destructibleButton.Parent then
                    destructibleButton.Text = "Break All / Sky Smiley"
                end
            end
        end)
    end)
    yPos = yPos + 34


    local espSw = createToggleSwitch(scrollingFrame, yPos, "Player ESP", false, function(state)
        toggleESP(state)
    end)
    Buttons.espToggle = espSw
    yPos = yPos + 34

    local orbitSw = createToggleSwitch(scrollingFrame, yPos, "C4 Orbit", false, function(state)
        toggleC4Orbit(state)
    end)
    Buttons.orbitToggle = orbitSw
    yPos = yPos + 34

    local vehFlySw = createToggleSwitch(scrollingFrame, yPos, "Vehicle Fly (WASD)", false, function(state)
        toggleVehFly(state)
    end)
    Buttons.vehFlyToggle = vehFlySw
    yPos = yPos + 34

    local jetSkiLandSw = createToggleSwitch(scrollingFrame, yPos, "JetSki Land Drive", false, function(state)
        toggleWaterBypass(state)
    end)
    Buttons.waterToggle = jetSkiLandSw
    yPos = yPos + 34

    -- Speed input for vehicle fly
    local vehFlySpeedInput = createInputField(scrollingFrame, yPos, "Veh Fly Speed", tostring(VehFlySettings.Speed))
    vehFlySpeedInput.FocusLost:Connect(function()
        local n = tonumber(vehFlySpeedInput.Text)
        if n and n > 0 then VehFlySettings.Speed = n else vehFlySpeedInput.Text = tostring(VehFlySettings.Speed) end
    end)
    yPos = yPos + 34

    -- ===== CRIME TOOLS =====
    createSectionHeader(scrollingFrame, yPos, "Crime Tools")
    yPos = yPos + 30

    local arrestSw = createToggleSwitch(scrollingFrame, yPos, "Auto Arrest (Police)", false, function(state)
        toggleAutoArrest(state)
    end)
    Buttons.arrestToggle = arrestSw
    yPos = yPos + 34

    -- Bank robbery status label
    local bankRobStatusLbl = Instance.new("TextLabel")
    bankRobStatusLbl.Size = UDim2.new(1, -8, 0, 28)
    bankRobStatusLbl.Position = UDim2.new(0, 4, 0, yPos)
    bankRobStatusLbl.BackgroundColor3 = bgTertiary
    bankRobStatusLbl.Text = "  🏦 Bank Rob: Idle"
    bankRobStatusLbl.TextColor3 = textMuted
    bankRobStatusLbl.TextSize = 11
    bankRobStatusLbl.Font = Enum.Font.GothamMedium
    bankRobStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    bankRobStatusLbl.TextYAlignment = Enum.TextYAlignment.Center
    bankRobStatusLbl.Parent = scrollingFrame
    local bankRobLblCorner = Instance.new("UICorner")
    bankRobLblCorner.CornerRadius = UDim.new(0, 8)
    bankRobLblCorner.Parent = bankRobStatusLbl
    yPos = yPos + 36

    local bankRobBtn = createButton(scrollingFrame, yPos, "Enable Bank Robbery", true)
    bankRobBtn.Activated:Connect(function()
        BankRobSettings.Enabled = not BankRobSettings.Enabled
        if BankRobSettings.Enabled then
            bankRobBtn.Text = "Stop Bank Robbery"
            bankRobBtn.BackgroundColor3 = dangerColor
            bankRobStatusLbl.Text = "  🏦 Bank Rob: Starting..."
            bankRobStatusLbl.TextColor3 = successColor
            resetBankRobState()
            BankRobSettings.CurrentPhase = "Idle"
            -- Start the bank robbery phase loop
            if bankRobState.phaseConnection then bankRobState.phaseConnection:Disconnect() end
            bankRobState.phaseConnection = Services.RunService.Heartbeat:Connect(function()
                if not BankRobSettings.Enabled then
                    if bankRobState.phaseConnection then bankRobState.phaseConnection:Disconnect(); bankRobState.phaseConnection = nil end
                    return
                end
                local now = tick()
                if now - bankRobState.lastPhaseUpdate < 0.1 then return end
                bankRobState.lastPhaseUpdate = now

                local phase = BankRobSettings.CurrentPhase
                if not bankRobState.phaseStart then bankRobState.phaseStart = now end

                if phase == "Idle" then
                    bankRobStatusLbl.Text = "  🏦 Detecting vehicle..."
                    BankRobSettings.CurrentPhase = "DetectVehicle"
                elseif phase == "DetectVehicle" then
                    local char = player.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum and hum.SeatPart then
                            bankRobState.targetHeli = hum.SeatPart.Parent
                            BankRobSettings.CurrentPhase = "FlyToBank"
                            bankRobState.phaseStart = tick()
                            bankRobStatusLbl.Text = "  🏦 Flying to bank..."
                            bankRobStatusLbl.TextColor3 = warningColor
                        else
                            local veh = Services.Workspace:FindFirstChild("Vehicles")
                            local heli = veh and veh:FindFirstChild("Heli")
                            if heli then
                                bankRobState.targetHeli = heli
                                BankRobSettings.CurrentPhase = "FlyToBank"
                                bankRobState.phaseStart = tick()
                            end
                        end
                    end
                elseif phase == "FlyToBank" then
                    local bankPos = findBankTargetPosition()
                    if not bankPos then BankRobSettings.CurrentPhase = "Idle"; resetBankRobState(); return end
                    local heliRoot = bankRobState.targetHeli and getRoot(bankRobState.targetHeli)
                    if not heliRoot then BankRobSettings.CurrentPhase = "Idle"; resetBankRobState(); return end
                    local targetWithHeight = bankPos + Vector3.new(0, BankRobSettings.BankFlyHeight, 0)
                    if (targetWithHeight - heliRoot.Position).Magnitude < 20 then
                        BankRobSettings.CurrentPhase = "ExitVehicle"
                        bankRobState.phaseStart = tick()
                        bankRobStatusLbl.Text = "  🏦 Exiting vehicle..."
                        return
                    end
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            flyHeliToBank(bankRobState.targetHeli, targetWithHeight, 200)
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "ExitVehicle" then
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            local char = player.Character
                            if char then
                                local hum = char:FindFirstChildOfClass("Humanoid")
                                if hum then pcall(function() hum.Sit = false; hum.PlatformStand = false end) end
                                task.wait(1)
                            end
                            BankRobSettings.CurrentPhase = "DescendToVault"
                            bankRobState.phaseStart = tick()
                            bankRobStatusLbl.Text = "  🏦 Descending to vault..."
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "DescendToVault" then
                    local bankPos = findBankTargetPosition()
                    if not bankPos then BankRobSettings.CurrentPhase = "Idle"; resetBankRobState(); return end
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            bankNavigateTo(bankPos, 75, 5)
                            BankRobSettings.CurrentPhase = "PushThrough"
                            bankRobState.phaseStart = tick()
                            bankRobStatusLbl.Text = "  🏦 Pushing through barriers..."
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "PushThrough" then
                    local bankPos = findBankTargetPosition()
                    if not bankPos then BankRobSettings.CurrentPhase = "Idle"; resetBankRobState(); return end
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            local char = player.Character
                            local root = char and char:FindFirstChild("HumanoidRootPart")
                            if root then
                                for i = 1, 80 do
                                    if not BankRobSettings.Enabled then break end
                                    local dir = (bankPos - root.Position).Unit
                                    pcall(function()
                                        root.CFrame = root.CFrame + (dir * 2)
                                        root.AssemblyLinearVelocity = dir * 120
                                    end)
                                    task.wait(0.04)
                                end
                                bankRobState.barrier2Pos = root.Position
                            end
                            local tp, mp = findTriggerDoorAndMoney()
                            if tp then
                                bankRobState.triggerDoorPart = tp
                                bankRobState.moneyPart = mp
                                BankRobSettings.CurrentPhase = "NavigateToTrigger"
                                bankRobStatusLbl.Text = "  🏦 Going to trigger..."
                            else
                                BankRobSettings.CurrentPhase = "Idle"
                                resetBankRobState()
                            end
                            bankRobState.phaseStart = tick()
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "NavigateToTrigger" then
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            if bankRobState.triggerDoorPart then
                                bankNavigateTo(bankRobState.triggerDoorPart.Position, 50, 8)
                            end
                            BankRobSettings.CurrentPhase = "ReturnToBarrier"
                            bankRobState.phaseStart = tick()
                            bankRobStatusLbl.Text = "  🏦 Returning to barrier..."
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "ReturnToBarrier" then
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            if bankRobState.barrier2Pos then
                                bankNavigateTo(bankRobState.barrier2Pos, 60, 8)
                            end
                            task.wait(BankRobSettings.TriggerWaitTime)
                            BankRobSettings.CurrentPhase = "GetMoney"
                            bankRobState.phaseStart = tick()
                            bankRobStatusLbl.Text = "  🏦 Getting money! 💰"
                            bankRobStatusLbl.TextColor3 = successColor
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "GetMoney" then
                    if not bankRobState.phaseInProgress then
                        bankRobState.phaseInProgress = true
                        spawn(function()
                            if bankRobState.triggerDoorPart then
                                bankNavigateTo(bankRobState.triggerDoorPart.Position, 50, 8)
                            end
                            if bankRobState.moneyPart then
                                bankNavigateTo(bankRobState.moneyPart.Position, 50, 8)
                            end
                            task.wait(BankRobSettings.VaultWaitTime)
                            BankRobSettings.CurrentPhase = "Complete"
                            bankRobState.phaseStart = tick()
                            bankRobState.phaseInProgress = false
                        end)
                    end
                elseif phase == "Complete" then
                    bankRobStatusLbl.Text = "  🏦 Complete! ✅"
                    bankRobStatusLbl.TextColor3 = successColor
                    BankRobSettings.Enabled = false
                    bankRobBtn.Text = "Enable Bank Robbery"
                    bankRobBtn.BackgroundColor3 = accentColor
                    if bankRobState.phaseConnection then bankRobState.phaseConnection:Disconnect(); bankRobState.phaseConnection = nil end
                    resetBankRobState()
                    stopBankCharFly()
                end
            end)
        else
            bankRobBtn.Text = "Enable Bank Robbery"
            bankRobBtn.BackgroundColor3 = accentColor
            bankRobStatusLbl.Text = "  🏦 Bank Rob: Idle"
            bankRobStatusLbl.TextColor3 = textMuted
            if bankRobState.phaseConnection then bankRobState.phaseConnection:Disconnect(); bankRobState.phaseConnection = nil end
            resetBankRobState()
            stopBankCharFly()
        end
    end)
    yPos = yPos + 34

    -- ===== PLAYER LIST =====
    createSectionHeader(scrollingFrame, yPos, "Player List")
    yPos = yPos + 30

    local playerListFrame = Instance.new("Frame")
    playerListFrame.Size = UDim2.new(1, -8, 0, 140)
    playerListFrame.Position = UDim2.new(0, 4, 0, yPos)
    playerListFrame.BackgroundColor3 = bgTertiary
    playerListFrame.BorderSizePixel = 0
    playerListFrame.ClipsDescendants = true
    playerListFrame.Parent = scrollingFrame
    local plCorner = Instance.new("UICorner")
    plCorner.CornerRadius = UDim.new(0, 10)
    plCorner.Parent = playerListFrame

    local playerScrollFrame = Instance.new("ScrollingFrame")
    playerScrollFrame.Size = UDim2.new(1, -4, 1, -4)
    playerScrollFrame.Position = UDim2.new(0, 2, 0, 2)
    playerScrollFrame.BackgroundTransparency = 1
    playerScrollFrame.ScrollBarThickness = 4
    playerScrollFrame.ScrollBarImageColor3 = accentColor
    playerScrollFrame.BorderSizePixel = 0
    playerScrollFrame.Parent = playerListFrame

    local playerListLayout = Instance.new("UIListLayout")
    playerListLayout.Parent = playerScrollFrame
    playerListLayout.Padding = UDim.new(0, 3)
    playerListLayout.SortOrder = Enum.SortOrder.Name

    local function refreshPlayerList()
        for _, v in pairs(playerScrollFrame:GetChildren()) do
            if v:IsA("TextLabel") then v:Destroy() end
        end
        for _, p in pairs(Services.Players:GetPlayers()) do
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -4, 0, 22)
            lbl.BackgroundTransparency = 1
            lbl.Text = "  👤 " .. p.DisplayName .. " (" .. p.Name .. ")"
            lbl.TextColor3 = p == player and successColor or textSecondary
            lbl.TextSize = 11
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = playerScrollFrame
        end
        playerScrollFrame.CanvasSize = UDim2.new(0, 0, 0, playerListLayout.AbsoluteContentSize.Y + 4)
    end

    refreshPlayerList()
    playerListConnections[#playerListConnections + 1] = Services.Players.PlayerAdded:Connect(refreshPlayerList)
    playerListConnections[#playerListConnections + 1] = Services.Players.PlayerRemoving:Connect(function()
        task.defer(refreshPlayerList)
    end)
    yPos = yPos + 148

    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)
    activateSectionDropdowns(scrollingFrame)
end

State.setupVehicleTab = function(vehicleFrame)
    local yPos = 0
    
    createSectionHeader(vehicleFrame, yPos, "Car Modifications")
    yPos = yPos + 30
    
    heightSlider = createInputField(vehicleFrame, yPos, "Height", "6")
    yPos = yPos + 34
    
    brakesSlider = createInputField(vehicleFrame, yPos, "Brakes", "100")
    yPos = yPos + 34
    
    speedSlider = createInputField(vehicleFrame, yPos, "Engine Speed", "25")
    yPos = yPos + 34
    
    local autoApplyLabel = Instance.new("TextLabel")
    autoApplyLabel.Size = UDim2.new(1, -8, 0, 24)
    autoApplyLabel.Position = UDim2.new(0, 4, 0, yPos)
    autoApplyLabel.BackgroundTransparency = 1
    autoApplyLabel.Text = "✓ Auto-applying when in vehicle"
    autoApplyLabel.TextColor3 = successColor
    autoApplyLabel.TextSize = 10
    autoApplyLabel.Font = Enum.Font.GothamMedium
    autoApplyLabel.Parent = vehicleFrame
    yPos = yPos + 32
    
    createSectionHeader(vehicleFrame, yPos, "Boost")
    yPos = yPos + 30
    
    local infNitroEnabled = true
    local nitroCache = setmetatable({}, {__mode = "k"})
    local nitroScanRunning = false
    local lastVehiclePacket = nil
    local nitroElapsed = 0
    
    local function buildNitroCache()
        if nitroScanRunning then return end
        nitroScanRunning = true
        task.spawn(function()
            pcall(function()
                local fresh = setmetatable({}, {__mode = "k"})
                local objects = getgc(true)
                for index, obj in ipairs(objects) do
                    if type(obj) == "table" and rawget(obj, "Nitro") ~= nil then
                        fresh[obj] = true
                    end
                    if index % 500 == 0 then task.wait() end
                end
                nitroCache = fresh
            end)
            nitroScanRunning = false
        end)
    end
    
    Connections.infNitro = Services.RunService.Heartbeat:Connect(function(dt)
        if not infNitroEnabled then return end
        nitroElapsed += dt
        if nitroElapsed < 0.1 then return end
        nitroElapsed = 0

        local packet
        pcall(function()
            Cache.vehicleUtils = Cache.vehicleUtils or require(ReplicatedStorage.Vehicle.VehicleUtils)
            packet = Cache.vehicleUtils.GetLocalVehiclePacket()
        end)
        if packet ~= lastVehiclePacket then
            lastVehiclePacket = packet
            if packet then buildNitroCache() end
        end
        if type(packet) == "table" and rawget(packet, "Nitro") ~= nil then
            nitroCache[packet] = true
        end
        for obj in pairs(nitroCache) do
            local nitro = rawget(obj, "Nitro")
            if type(nitro) == "number" and nitro < 200 then
                rawset(obj, "Nitro", 200)
            end
        end
    end)
    
    local nitroSw = createToggleSwitch(vehicleFrame, yPos, "Infinite Nitro", true, function(state)
        infNitroEnabled = state
        if state then
            lastVehiclePacket = nil
        end
    end)
    yPos = yPos + 34

    -- ===== REMOTE VEHICLE CONTROL =====
    createSectionHeader(vehicleFrame, yPos, "Remote Control")
    yPos = yPos + 30

    local remoteStatusLbl = Instance.new("TextLabel")
    remoteStatusLbl.Size = UDim2.new(1, -8, 0, 28)
    remoteStatusLbl.Position = UDim2.new(0, 4, 0, yPos)
    remoteStatusLbl.BackgroundColor3 = accentColorDark
    remoteStatusLbl.Text = "  Status: No vehicle claimed"
    remoteStatusLbl.TextColor3 = textMuted
    remoteStatusLbl.TextSize = 14
    remoteStatusLbl.Font = Enum.Font.Gotham
    remoteStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    remoteStatusLbl.TextYAlignment = Enum.TextYAlignment.Center
    remoteStatusLbl.Parent = vehicleFrame
    local remStLblCorner = Instance.new("UICorner")
    remStLblCorner.CornerRadius = UDim.new(0, 8)
    remStLblCorner.Parent = remoteStatusLbl
    yPos = yPos + 36

    local claimBtn = createButton(vehicleFrame, yPos, "1. Claim Nearby Vehicle", false)
    claimBtn.Activated:Connect(function()
        local targetVehicle = getClosestVehicle()
        if not targetVehicle then
            remoteStatusLbl.Text = "  ✗ No vehicle found nearby"
            remoteStatusLbl.TextColor3 = dangerColor
            return
        end
        -- Find ReqLink remote
        local reqLink = nil
        pcall(function()
            local heliVeh = Services.Workspace:FindFirstChild("Vehicles")
            if heliVeh then
                for _, v in pairs(heliVeh:GetDescendants()) do
                    if v:IsA("RemoteEvent") and v.Name == "ReqLink" then reqLink = v; break end
                end
            end
        end)
        if not reqLink then
            pcall(function()
                for _, v in pairs(Services.Workspace:GetDescendants()) do
                    if v:IsA("RemoteEvent") and v.Name == "ReqLink" then reqLink = v; break end
                end
            end)
        end
        if not reqLink then reqLink = getNilInstance("ReqLink", "RemoteEvent") end
        if reqLink then
            pcall(function() reqLink:FireServer(targetVehicle, Vector3.new(-2.09, 2, -4.28)) end)
        end
        RopeSettings.LinkedVehicle = targetVehicle
        RopeSettings.VehicleSeat = findVehicleSeat(targetVehicle)
        remoteStatusLbl.Text = "  ✓ Claimed: " .. targetVehicle.Name
        remoteStatusLbl.TextColor3 = successColor
    end)
    yPos = yPos + 34

    local remoteFlySpeedInput = createInputField(vehicleFrame, yPos, "Remote Fly Speed", tostring(RopeSettings.FlySpeed))
    remoteFlySpeedInput.FocusLost:Connect(function()
        local n = tonumber(remoteFlySpeedInput.Text)
        if n and n > 0 then RopeSettings.FlySpeed = n else remoteFlySpeedInput.Text = tostring(RopeSettings.FlySpeed) end
    end)
    yPos = yPos + 34

    local remoteFlyBtn = createButton(vehicleFrame, yPos, "2. Start Remote Flying", true)
    remoteFlyBtn.Activated:Connect(function()
        RopeSettings.FlyEnabled = not RopeSettings.FlyEnabled
        if RopeSettings.FlyEnabled then
            if not RopeSettings.LinkedVehicle then
                RopeSettings.FlyEnabled = false
                remoteStatusLbl.Text = "  ✗ Claim a vehicle first"
                remoteStatusLbl.TextColor3 = dangerColor
                return
            end
            local ok = startRemoteVehFly()
            if ok then
                remoteFlyBtn.Text = "Stop Remote Flying"
                remoteFlyBtn.BackgroundColor3 = dangerColor
                remoteStatusLbl.Text = "  ✈️ Remote flying active!"
                remoteStatusLbl.TextColor3 = successColor
            else
                RopeSettings.FlyEnabled = false
                remoteStatusLbl.Text = "  ✗ Failed to start"
                remoteStatusLbl.TextColor3 = dangerColor
            end
        else
            stopRemoteVehFly()
            remoteFlyBtn.Text = "2. Start Remote Flying"
            remoteFlyBtn.BackgroundColor3 = accentColor
            remoteStatusLbl.Text = "  Stopped. Vehicle claimed: " .. (RopeSettings.LinkedVehicle and RopeSettings.LinkedVehicle.Name or "none")
            remoteStatusLbl.TextColor3 = textSecondary
        end
    end)
    yPos = yPos + 34

    local remoteInfoLbl = Instance.new("TextLabel")
    remoteInfoLbl.Size = UDim2.new(1, -8, 0, 38)
    remoteInfoLbl.Position = UDim2.new(0, 4, 0, yPos)
    remoteInfoLbl.BackgroundTransparency = 1
    remoteInfoLbl.Text = "WASD = move | Space/LCtrl = up/down\nRight-click drag = rotate camera | Scroll = zoom"
    remoteInfoLbl.Visible = false
    remoteInfoLbl.TextColor3 = textMuted
    remoteInfoLbl.TextSize = 10
    remoteInfoLbl.Font = Enum.Font.Gotham
    remoteInfoLbl.TextXAlignment = Enum.TextXAlignment.Left
    remoteInfoLbl.TextWrapped = true
    remoteInfoLbl.Parent = vehicleFrame

    vehicleFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)
    activateSectionDropdowns(vehicleFrame)
end

State.setupSettingsTab = function(settingsFrame)
    local yPos = 0
    
    createSectionHeader(settingsFrame, yPos, "Keybinds")
    yPos = yPos + 30
    
    local function createKeybindRow(labelText, currentKey, callback)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -8, 0, 30)
        container.Position = UDim2.new(0, 4, 0, yPos)
        container.BackgroundTransparency = 1
        container.BorderSizePixel = 0
        container.Parent = settingsFrame
        
        local containerCorner = Instance.new("UICorner")
        containerCorner.CornerRadius = UDim.new(0, 0)
        containerCorner.Parent = container
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -100, 1, 0)
        label.Position = UDim2.new(0, 88, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = labelText
        label.TextColor3 = textSecondary
        label.TextSize = 15
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = container
        
        local keyBg = Instance.new("Frame")
        keyBg.Size = UDim2.new(0, 70, 0, 26)
        keyBg.Position = UDim2.new(0, 8, 0, 2)
        keyBg.BackgroundColor3 = accentColor
        keyBg.BorderSizePixel = 0
        keyBg.Parent = container
        
        local keyCorner = Instance.new("UICorner")
        keyCorner.CornerRadius = UDim.new(0, 6)
        keyCorner.Parent = keyBg
        
        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(1, 0, 1, 0)
        keyLabel.BackgroundTransparency = 1
        keyLabel.Text = currentKey.Name
        keyLabel.TextColor3 = textPrimary
        keyLabel.TextSize = 14
        keyLabel.Font = Enum.Font.Gotham
        keyLabel.Parent = keyBg
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = keyBg
        
        btn.Activated:Connect(function()
            keyLabel.Text = "..."
            keyLabel.TextColor3 = warningColor
            setKeybind(function(key)
                callback(key)
                keyLabel.Text = key.Name
                keyLabel.TextColor3 = textPrimary
            end)
        end)
        
        btn.MouseEnter:Connect(function()
            tweenProperty(keyBg, {BackgroundColor3 = accentColorLight}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tweenProperty(keyBg, {BackgroundColor3 = accentColor}, 0.15)
        end)
        
        yPos = yPos + 34
        return keyLabel
    end
    
    createKeybindRow("Toggle Menu", Keybinds.gui, function(key) Keybinds.gui = key end)
    createKeybindRow("Flight", Keybinds.flight, function(key) Keybinds.flight = key end)
    createKeybindRow("Autopilot", Keybinds.autopilot, function(key) Keybinds.autopilot = key end)
    createKeybindRow("Soft Aim", Keybinds.softAim, function(key) Keybinds.softAim = key end)
    createKeybindRow("Flight Up", Keybinds.flightUp, function(key) Keybinds.flightUp = key end)
    createKeybindRow("Flight Down", Keybinds.flightDown, function(key) Keybinds.flightDown = key end)
    
    createSectionHeader(settingsFrame, yPos, "Script")
    yPos = yPos + 30

    Buttons.killScript = createButton(settingsFrame, yPos, "Kill Script", false)
    Buttons.killScript.Activated:Connect(function()
        task.defer(State.killScript)
    end)
    yPos = yPos + 34

    
    settingsFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 20)
    activateSectionDropdowns(settingsFrame)
end

createGUI = function()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = State.guiID
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = math.random(1, 10)
    
    local mainFrame = createMainFrame(screenGui)
    local titleBar = createTitleBar(mainFrame)
    local contentFrames = createTabSystem(mainFrame)
    
    State.setupFeaturesTab(contentFrames[1])
    State.setupVehicleTab(contentFrames[2])
    State.setupSettingsTab(contentFrames[3])
    setupDragging(titleBar, mainFrame)
    
    screenGui.Parent = player:WaitForChild("PlayerGui")
    return mainFrame
end
end
State.defineGUI()
State.defineGUI = nil

setupDragging = function(titleBar, mainFrame)
    local dragging, dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    Connections.dragInput = Services.UserInputService.InputChanged:Connect(function(input)
        if State.killed then return end
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

gui = createGUI()
startAutoCarMods()
toggleTeamIcons(State.teamIconsEnabled)
pcall(setFallProtection, player.Character, true)

-- Defer heavy hazard scanning to avoid blocking GUI load
task.delay(0.5, function()
    if State.killed then return end
    if State.laserRemoverEnabled then
        toggleLaserRemover(State.laserRemoverEnabled)
    end
end)
Connections.mainInput = Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if State.killed or gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Keybinds.gui then
            State.guiVisible = not State.guiVisible
            gui.Visible = State.guiVisible
        end
        if key == Keybinds.flight then
            State.flightEnabled = not State.flightEnabled
            toggleFlight(State.flightEnabled)
        end
        if key == Keybinds.autopilot then
            State.autopilotEnabled = not State.autopilotEnabled
            toggleAutopilot(State.autopilotEnabled)
        end
        if key == Keybinds.teamIcons then
            State.teamIconsEnabled = not State.teamIconsEnabled
            toggleTeamIcons(State.teamIconsEnabled)
        end
        if key == Keybinds.laser then
            State.laserRemoverEnabled = not State.laserRemoverEnabled
            toggleLaserRemover(State.laserRemoverEnabled)
        end
        if key == Keybinds.softAim then
            toggleSoftAim(not State.softAimEnabled)
        end
        if waitingForKey then
            waitingForKey(key)
            waitingForKey = nil
        end
    end
end)

Connections.characterAdded = player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    if State.killed then return end
    pcall(setFallProtection, newChar, true)
    pcall(function()
        if isValid(newChar) then
            groundParams.FilterDescendantsInstances = {newChar}
        end
    end)
    Cache.targets = {}
    Timers.lastTargetScan = 0
    if not Connections.autoMod then
        startAutoCarMods()
    end
    reconnectAutopilotIfNeeded()

    -- Reset arrest state on respawn so auto-arrest resumes cleanly
    if ArrestSettings.Enabled then
        AV.vehicle = nil
        AV.acquiring = false
        AV.pathfinding = false
        AV.footMode = false
        AV.lastAcquire = 0
        AV.shooting = AV.newArrestActionState()
        AV.outsideCache = false
        AV.lastOutsideCheck = 0
        arrestState.isArresting = false
        clearPathMarkers()
        clearArrestWaypoint()
        toggleFlight(false)
        warn("[AutoArrest] Respawned - state reset, resuming")
    end
end)
pcall(function()
    local char = player.Character
    if isValid(char) then
        groundParams.FilterDescendantsInstances = {char}
    end
end)
Connections.characterRemoving = player.CharacterRemoving:Connect(function()
    if State.killed then return end
    State.flying = false
    State.flightEnabled = false
    if Connections.autopilot then
        pcall(function() Connections.autopilot:Disconnect() end)
        Connections.autopilot = nil
    end
    if Connections.flight then
        pcall(function() Connections.flight:Disconnect() end)
        Connections.flight = nil
    end
    if FlightData.bodyVel then
        pcall(function() FlightData.bodyVel:Destroy() end)
        FlightData.bodyVel = nil
    end
    if FlightData.bodyGyro then
        pcall(function() FlightData.bodyGyro:Destroy() end)
        FlightData.bodyGyro = nil
    end
    if FlightData.skydiveAnimTrack then
        pcall(function() FlightData.skydiveAnimTrack:Stop() end)
        FlightData.skydiveAnimTrack = nil
    end
    if Connections.autoMod then
        pcall(function() Connections.autoMod:Disconnect() end)
        Connections.autoMod = nil
    end
    Cache.vehicleUtils = nil
    Cache.targets = {}
    Timers.lastTargetScan = 0
    AutopilotData.currentVehicle = nil
    AutopilotData.lastValidVehRoot = nil
    AutopilotData.currentWaypoint = nil
    -- Cleanup new features
    pcall(function() stopVehFly() end)
    if OrbitLogic.Connection then
        pcall(function() OrbitLogic.Connection:Disconnect(); OrbitLogic.Connection = nil end)
        OrbitSettings.Enabled = false
        OrbitLogic.Objs = {}
    end
    if RopeSettings.FlyEnabled then
        pcall(function() stopRemoteVehFly() end)
    end
    if bankRobState.phaseConnection then
        pcall(function() bankRobState.phaseConnection:Disconnect(); bankRobState.phaseConnection = nil end)
    end
    BankRobSettings.Enabled = false
    pcall(function() stopBankCharFly() end)
    if arrestConnection then
        pcall(function() arrestConnection:Disconnect(); arrestConnection = nil end)
    end
    ArrestSettings.Enabled = false
    -- FSD cleanup
    pcall(function() toggleFSD(false) end)
end)
Connections.teamChanged = player:GetPropertyChangedSignal("Team"):Connect(function()
    task.wait(0.1)
    if State.killed then return end
    Cache.targets = {}
    Timers.lastTargetScan = 0
end)
warn("[Script] GUI loaded in ~0.5 seconds")

pcall(function()
    local Notification = require(game:GetService("ReplicatedStorage").Game.Notification)
    Notification.new({
        Text = "Jailbreak Enhanced v2 loaded. Press K for menu.",
        Duration = 3
    })
end)

warn("[Script] All systems ready!")
