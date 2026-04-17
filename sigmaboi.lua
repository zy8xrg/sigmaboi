local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ============ KEY SYSTEM ============
local ValidKeys = {
    ["free"] = { rank = "user", canCrash = false },
    ["carmen6817"] = { rank = "admin", canCrash = true }
}

local UserKey = nil
local UserRank = "user"
local CanCrash = false
local KeyAuthenticated = false

-- ============ EXPLOITABLE REMOTES ============
local exploitableRemotes = {}

local function findExploitableRemotes()
    local remotes = {}
    
    local remotePaths = {
        "ReplicatedStorage.Remotes.Admingive",
        "ReplicatedStorage.Remotes.KickTeamMember",
        "ReplicatedStorage.VomaglaAdminCommand",
        "ReplicatedStorage.Shell.Run",
        "ReplicatedStorage.Shell.RunClient",
    }
    
    for _, path in pairs(remotePaths) do
        local success, remote = pcall(function()
            local parts = {}
            for part in string.gmatch(path, "[^.]+") do
                table.insert(parts, part)
            end
            
            local current = game
            for _, part in pairs(parts) do
                current = current[part]
                if not current then break end
            end
            return current
        end)
        
        if success and remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
            table.insert(remotes, {remote = remote, name = path})
        end
    end
    
    return remotes
end

-- ============ ADMIN FUNCTIONS ============
local function tryAdminRemote(targetPlayer, action)
    local successCount = 0
    
    for _, remoteData in pairs(exploitableRemotes) do
        local remote = remoteData.remote
        pcall(function()
            if remote:IsA("RemoteEvent") then
                local remoteName = remote.Name:lower()
                
                if remoteName:find("admingive") then
                    remote:FireServer(targetPlayer, action)
                    remote:FireServer(targetPlayer.Name, action)
                    successCount = successCount + 1
                elseif remoteName:find("kickteam") then
                    remote:FireServer(targetPlayer)
                    remote:FireServer(targetPlayer.Name)
                    successCount = successCount + 1
                elseif remoteName:find("vomagla") or remoteName:find("admincommand") then
                    remote:FireServer(targetPlayer, action)
                    remote:FireServer(action, targetPlayer)
                    successCount = successCount + 1
                else
                    remote:FireServer(targetPlayer, action)
                end
            end
        end)
    end
    
    return successCount
end

local function adminCrashPlayer(player)
    if not CanCrash or player == LocalPlayer then return end
    
    pcall(function()
        tryAdminRemote(player, "crash")
        
        if player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum then hum.Health = 0 end
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Transparency = 1
                end
            end
        end
    end)
end

local function crashAllFreePlayers()
    if not CanCrash then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then adminCrashPlayer(player) end
    end
    Rayfield:Notify({Title = "Admin", Content = "Crashed all free players!", Duration = 3})
end

-- ============ MAIN SCRIPT (DEFINED FIRST) ============
local function loadMainScript()
    local playerCache = {}
    local cachedChar = LocalPlayer.Character
    local CurrentAimTarget = nil
    local LibraryUnloaded = false
    local Flying = false
    local FlyBodyVelocity = nil
    local FlyConnection = nil

    -- Settings
    local v13 = { Enabled = false, UseFOV = true, FOVRadius = 150, MaxDistance = 500 }
    local ESPOptions = { Enabled = false, Name = false, Distance = false, Box = false, Chams = false, Tracer = false, Items = false, Ores = false, Crates = false, Backpacks = false, Airdrop = false, ViewmodelChams = false, ItemName = false }
    local ESPColors = { Name = Color3.fromRGB(255,255,255), Distance = Color3.fromRGB(255,255,255), Box = Color3.fromRGB(255,0,0), Tracer = Color3.fromRGB(0,255,0), Items = Color3.fromRGB(0,255,255), Ores = Color3.fromRGB(255,255,0), Crates = Color3.fromRGB(255,128,0), Backpacks = Color3.fromRGB(255,0,255), Airdrop = Color3.fromRGB(0,255,128), Viewmodel = Color3.fromRGB(0,255,0), ItemName = Color3.fromRGB(255,255,0) }
    
    local SpeedSettings = { Enabled = false, Value = 30 }
    local AutoFireSettings = { Enabled = false }
    local FOVSettings = { Enabled = false, Value = 70 }
    local SuperJumpSettings = { Enabled = false, Height = 100 }
    local ThirdPersonSettings = { Enabled = false, Distance = 10 }
    local XRaySettings = { Enabled = false }
    local NoRecoilSettings = { Enabled = false }
    local InfiniteJumpSettings = { Enabled = false }
    local FullbrightSettings = { Enabled = false }
    local RapidFireSettings = { Enabled = false }
    local HitboxExpanderEnabled = false
    local HitboxSize = 10
    local SpiderEnabled = false
    local IsClimbing = false
    local lastJumpTime = 0
    local rapidFireActive = false
    local isMouseDown = false
    local lastAim = 0
    
    -- ESP storage
    local espObjects = {}
    local chamsObjects = {}
    local viewmodelChamsInstance = nil
    local fovCircle = nil
    local oldNamecall = nil
    
    -- X-Ray
    local wlK = {"TwigWall","SoloTwigFrame","TrigTwigRoof","TwigFrame","TwigWindow","TwigRoof"}
    local xrT = {}
    local originalBrightness = Lighting.Brightness
    local originalAmbient = Lighting.Ambient
    
    -- Store connections
    local connections = {}

    -- Cache players
    for _, p in ipairs(Players:GetPlayers()) do 
        if p ~= LocalPlayer then 
            playerCache[p] = true 
        end 
    end
    
    Players.PlayerAdded:Connect(function(p) 
        if p ~= LocalPlayer then 
            playerCache[p] = true 
        end 
    end)
    
    Players.PlayerRemoving:Connect(function(p) 
        playerCache[p] = nil 
    end)

    -- Helper functions
    local function removeEmojis(text)
        if not text then return "" end
        local result = ""
        for i = 1, #text do
            local char = text:sub(i, i)
            if char:byte() < 128 then
                result = result .. char
            end
        end
        return result:gsub("%s+", " ")
    end

    local function setFullbright(enabled)
        if enabled then
            Lighting.Brightness = 2
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        else
            Lighting.Brightness = originalBrightness
            Lighting.Ambient = originalAmbient
        end
    end

    local function setXrayState(a)
        for p,d in pairs(xrT) do
            if p and p:IsDescendantOf(workspace) then 
                p.Transparency = a and 0.5 or d.OT 
            end
        end
    end

    local function clearAllESP()
        for obj, data in pairs(espObjects) do
            for _, drawingObj in pairs(data) do
                pcall(function() 
                    if drawingObj then
                        if drawingObj.Remove then 
                            drawingObj:Remove() 
                        elseif drawingObj.Destroy then 
                            drawingObj:Destroy() 
                        end
                    end
                end)
            end
        end
        espObjects = {}
    end

    local function stopFly()
        if FlyBodyVelocity then 
            FlyBodyVelocity:Destroy() 
            FlyBodyVelocity = nil 
        end
        if FlyConnection then 
            FlyConnection:Disconnect() 
            FlyConnection = nil 
        end
        local hum = cachedChar and cachedChar:FindFirstChildWhichIsA("Humanoid")
        if hum then 
            hum.PlatformStand = false 
        end
        Flying = false
    end

    local function startFly()
        if not cachedChar then return end
        local hrp = cachedChar:FindFirstChild("HumanoidRootPart")
        local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
        if not hrp then return end
        
        stopFly()
        Flying = true
        if hum then 
            hum.PlatformStand = true 
        end
        
        FlyBodyVelocity = Instance.new("BodyVelocity")
        FlyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        FlyBodyVelocity.Parent = hrp
        
        local speed = 85
        local flyConn = RunService.RenderStepped:Connect(function()
            if not Flying or not cachedChar or not FlyBodyVelocity then
                if flyConn then 
                    flyConn:Disconnect() 
                end
                return
            end
            
            local moveDirection = Vector3.new()
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then 
                moveDirection = moveDirection + Vector3.new(0, 0, -1) 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then 
                moveDirection = moveDirection + Vector3.new(0, 0, 1) 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
                moveDirection = moveDirection + Vector3.new(-1, 0, 0) 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
                moveDirection = moveDirection + Vector3.new(1, 0, 0) 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then 
                moveDirection = moveDirection + Vector3.new(0, 1, 0) 
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then 
                moveDirection = moveDirection + Vector3.new(0, -1, 0) 
            end
            
            local cam = workspace.CurrentCamera
            if cam and moveDirection.Magnitude > 0 then
                local moveVelocity = (cam.CFrame.RightVector * moveDirection.X + cam.CFrame.UpVector * moveDirection.Y + cam.CFrame.LookVector * moveDirection.Z) * speed
                FlyBodyVelocity.Velocity = moveVelocity
            elseif FlyBodyVelocity then
                FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        table.insert(connections, flyConn)
        FlyConnection = flyConn
    end

    -- Spider climb
    local function startSpiderClimb()
        if not SpiderEnabled or not cachedChar then return end
        local hrp = cachedChar:FindFirstChild("HumanoidRootPart")
        local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum then return end
        
        local origin = hrp.Position
        local direction = hrp.CFrame.LookVector
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {cachedChar, LocalPlayer.Character}
        
        local wallHit = workspace:Raycast(origin, direction * 5, raycastParams)
        local isHoldingForward = UserInputService:IsKeyDown(Enum.KeyCode.W)
        
        if wallHit and isHoldingForward then
            local distanceToWall = (origin - wallHit.Position).Magnitude
            if distanceToWall < 3 then
                IsClimbing = true
                hum.UseJumpPower = false
                
                local climbVelocity = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    climbVelocity = Vector3.new(0, 25, 0)
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    climbVelocity = Vector3.new(0, -15, 0)
                end
                
                local moveDirection = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then 
                    moveDirection = moveDirection - hrp.CFrame.RightVector 
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then 
                    moveDirection = moveDirection + hrp.CFrame.RightVector 
                end
                
                hrp.AssemblyLinearVelocity = climbVelocity + (moveDirection * 20) + (wallHit.Normal * -5)
            end
        else
            if IsClimbing then
                IsClimbing = false
                if hum then 
                    hum.UseJumpPower = true 
                end
            end
        end
    end

    local function toggleSpider()
        SpiderEnabled = not SpiderEnabled
        if SpiderEnabled then
            local spiderConn = RunService.RenderStepped:Connect(startSpiderClimb)
            table.insert(connections, spiderConn)
            if cachedChar then
                local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
                if hum then 
                    hum.AutoRotate = false 
                end
            end
            Rayfield:Notify({Title = "Spider-Man", Content = "Enabled!", Duration = 2})
        else
            if cachedChar then
                local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
                if hum then 
                    hum.AutoRotate = true 
                end
            end
            Rayfield:Notify({Title = "Spider-Man", Content = "Disabled!", Duration = 2})
        end
    end

    -- Silent aim
    local function getClosestPlayer()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local mousePos = UserInputService:GetMouseLocation()
        local best, bestD = nil, 1e9
        
        for plr in pairs(playerCache) do
            local ch = plr.Character
            if ch then
                local part = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
                if part then
                    local hum = ch:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 then
                        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local distToMouse = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
                            if v13.UseFOV and distToMouse <= v13.FOVRadius then
                                if distToMouse < bestD then
                                    best = part
                                    bestD = distToMouse
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    if hookmetamethod and getnamecallmethod then
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "Raycast" and self == workspace and v13.Enabled and CurrentAimTarget then
                local args = {...}
                local origin = args[1]
                local direction = args[2]
                if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                    local newDir = (CurrentAimTarget.Position - origin).Unit * direction.Magnitude
                    return oldNamecall(self, origin, newDir, args[3])
                end
            end
            return oldNamecall(self, ...)
        end)
    end

    -- Rapid fire
    local function doRapidFire()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end

    -- ESP update
    local lastESPUpdate = 0
    local function updateESP()
        local now = tick()
        if now - lastESPUpdate < 0.05 then return end
        lastESPUpdate = now
        
        if not ESPOptions.Enabled then
            clearAllESP()
            return
        end
        
        local cam = workspace.CurrentCamera
        if not cam then return end
        
        for plr in pairs(playerCache) do
            local ch = plr.Character
            local shouldShow = false
            local hrp = nil
            local screenPos = nil
            local onScreen = false
            
            if ch then
                hrp = ch:FindFirstChild("HumanoidRootPart")
                local hum = ch:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    shouldShow = onScreen
                end
            end
            
            if not espObjects[plr] then 
                espObjects[plr] = {} 
            end
            
            -- Name ESP
            if ESPOptions.Name and shouldShow then
                if not espObjects[plr].Name then
                    local text = Drawing.new("Text")
                    text.Size = 14
                    text.Center = true
                    text.Outline = true
                    text.Color = ESPColors.Name
                    espObjects[plr].Name = text
                end
                espObjects[plr].Name.Visible = true
                espObjects[plr].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 40)
                espObjects[plr].Name.Text = removeEmojis(plr.DisplayName)
            elseif espObjects[plr] and espObjects[plr].Name then
                espObjects[plr].Name.Visible = false
            end
            
            -- Box ESP
            if ESPOptions.Box and shouldShow then
                if not espObjects[plr].Box then
                    local box = Drawing.new("Square")
                    box.Thickness = 1
                    box.Transparency = 0.5
                    box.Color = ESPColors.Box
                    box.Filled = false
                    espObjects[plr].Box = box
                end
                local size = 100 / screenPos.Z
                espObjects[plr].Box.Size = Vector2.new(50 * size, 100 * size)
                espObjects[plr].Box.Position = Vector2.new(screenPos.X - espObjects[plr].Box.Size.X / 2, screenPos.Y - espObjects[plr].Box.Size.Y / 2)
                espObjects[plr].Box.Visible = true
            elseif espObjects[plr] and espObjects[plr].Box then
                espObjects[plr].Box.Visible = false
            end
        end
    end

    -- Chams update
    local function updateChams()
        if not ESPOptions.Chams then
            for _, cham in pairs(chamsObjects) do
                pcall(function() cham:Destroy() end)
            end
            chamsObjects = {}
            return
        end
        for plr in pairs(playerCache) do
            local ch = plr.Character
            if ch and not chamsObjects[plr] then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255, 0, 0)
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 1
                hl.Adornee = ch
                hl.Parent = ch
                chamsObjects[plr] = hl
            end
        end
    end

    -- X-Ray registration
    local function regXR(o)
        if xrT[o] then return end
        if (o:IsA("BasePart") or o:IsA("MeshPart")) then
            for _, k in ipairs(wlK) do
                if string.find(o.Name:lower(), k:lower()) then
                    xrT[o] = {OT = o.Transparency}
                    break
                end
            end
        end
    end
    
    task.spawn(function() 
        for _, o in pairs(workspace:GetDescendants()) do 
            regXR(o) 
        end 
    end)
    workspace.DescendantAdded:Connect(regXR)

    -- Movement physics
    local physConn = RunService.Heartbeat:Connect(function()
        if LibraryUnloaded then return end
        local ch = cachedChar
        if not ch then return end
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        local hum = ch:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        
        if SpeedSettings.Enabled and not Flying and not IsClimbing then
            local md = hum.MoveDirection
            if md.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * SpeedSettings.Value, hrp.AssemblyLinearVelocity.Y, md.Z * SpeedSettings.Value)
            end
        end
    end)
    table.insert(connections, physConn)

    -- Jump
    UserInputService.JumpRequest:Connect(function()
        if InfiniteJumpSettings.Enabled and not IsClimbing then
            local hum = cachedChar and cachedChar:FindFirstChildWhichIsA("Humanoid")
            if hum then 
                hum:ChangeState(Enum.HumanoidStateType.Jumping) 
            end
            return
        end
        if SuperJumpSettings.Enabled and not IsClimbing then
            local now = tick()
            if now - lastJumpTime > 0.5 then
                lastJumpTime = now
                local r = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
                if r then 
                    r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, SuperJumpSettings.Height, r.AssemblyLinearVelocity.Z) 
                end
            end
        end
    end)

    -- Visual updates
    local visConn = RunService.RenderStepped:Connect(function()
        if LibraryUnloaded then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        if FOVSettings.Enabled then 
            cam.FieldOfView = FOVSettings.Value 
        end
        if ThirdPersonSettings.Enabled then
            local hrp = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
            if hrp then 
                cam.CFrame = CFrame.new(hrp.Position - (cam.CFrame.LookVector * ThirdPersonSettings.Distance), hrp.Position) 
            end
        end
        setFullbright(FullbrightSettings.Enabled)
        setXrayState(XRaySettings.Enabled)
    end)
    table.insert(connections, visConn)

    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isMouseDown = true
            if RapidFireSettings.Enabled then
                rapidFireActive = true
                task.spawn(function()
                    while rapidFireActive and isMouseDown do
                        doRapidFire()
                        task.wait(0.01)
                    end
                end)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isMouseDown = false
            rapidFireActive = false
        end
    end)

    -- Aim
    local aimConn = RunService.RenderStepped:Connect(function()
        local now = tick()
        if now - lastAim >= 0.033 then
            lastAim = now
            CurrentAimTarget = v13.Enabled and getClosestPlayer() or nil
        end
        
        if AutoFireSettings.Enabled and v13.Enabled and CurrentAimTarget and isMouseDown and not RapidFireSettings.Enabled then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end)
    table.insert(connections, aimConn)

    -- FOV circle
    local function updateFOVCircle()
        pcall(function()
            if not v13.Enabled or not v13.UseFOV then
                if fovCircle then 
                    fovCircle.Visible = false 
                end
                return
            end
            if not fovCircle then
                fovCircle = Drawing.new("Circle")
                fovCircle.Thickness = 2
                fovCircle.Transparency = 0.7
                fovCircle.NumSides = 60
                fovCircle.Filled = false
                fovCircle.Color = Color3.fromRGB(255, 255, 255)
            end
            local mousePos = UserInputService:GetMouseLocation()
            fovCircle.Visible = true
            fovCircle.Position = mousePos
            fovCircle.Radius = v13.FOVRadius
            fovCircle.Color = CurrentAimTarget and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
        end)
    end
    
    local fovConn = RunService.RenderStepped:Connect(updateFOVCircle)
    table.insert(connections, fovConn)
    
    local espConn = RunService.RenderStepped:Connect(updateESP)
    table.insert(connections, espConn)

    -- Character respawn
    LocalPlayer.CharacterAdded:Connect(function(char)
        cachedChar = char
        if Flying then
            stopFly()
            task.wait(0.5)
            startFly()
        end
        updateChams()
    end)

    -- Hitbox expander
    local function updateHitboxSize()
        if not HitboxExpanderEnabled then return end
        for _, plr in pairs(playerCache) do
            local ch = plr.Character
            if ch then
                local head = ch:FindFirstChild("Head") or ch:FindFirstChild("HeadHitbox")
                if head and head:IsA("BasePart") then
                    pcall(function()
                        head.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        head.Transparency = 0.5
                        head.CanCollide = false
                    end)
                end
            end
        end
    end

    -- No recoil
    local function setupNoRecoil()
        if not NoRecoilSettings.Enabled then return end
        pcall(function()
            local RecoilHandler = require(ReplicatedStorage:WaitForChild("Gun").Scripts.RecoilHandler)
            RecoilHandler.nextStep = function() end
            RecoilHandler.setRecoilMultiplier = function() end
            RecoilHandler.getFinalRecoilMultiplier = function() return 0 end
        end)
    end

    -- UI
    local Window = Rayfield:CreateWindow({
        Name = "Vomagla Rost Alpha" .. (UserRank == "admin" and " [ADMIN]" or " [FREE]"),
        Icon = 0,
        LoadingTitle = "Vomagla",
        LoadingSubtitle = "by rost",
        Theme = "Dark",
        DisableThemeChange = false,
    })

    local CombatTab = Window:CreateTab("Combat")
    local VisualTab = Window:CreateTab("Visual")
    local PlayerTab = Window:CreateTab("Player")
    local MiscTab = Window:CreateTab("Misc")
    
    -- Admin tab
    if CanCrash then
        local AdminTab = Window:CreateTab("Admin")
        AdminTab:CreateButton({Name = "CRASH ALL PLAYERS", Callback = crashAllFreePlayers})
        if #exploitableRemotes > 0 then
            AdminTab:CreateSection("Found Remotes")
            for _, rd in pairs(exploitableRemotes) do
                AdminTab:CreateButton({Name = rd.name, Callback = function()
                    pcall(function() rd.remote:FireServer("test") end)
                    Rayfield:Notify({Title = "Remote", Content = "Fired " .. rd.name, Duration = 2})
                end})
            end
        end
    end

    -- Combat tab
    CombatTab:CreateSection("Silent Aim")
    CombatTab:CreateToggle({Name = "Silent Aim", CurrentValue = false, Callback = function(v) v13.Enabled = v end})
    CombatTab:CreateToggle({Name = "Use FOV", CurrentValue = true, Callback = function(v) v13.UseFOV = v end})
    CombatTab:CreateSlider({Name = "FOV Radius", Range = {50, 300}, Increment = 5, CurrentValue = 150, Callback = function(v) v13.FOVRadius = v end})
    
    CombatTab:CreateSection("Fire Modes")
    CombatTab:CreateToggle({Name = "Auto Fire", CurrentValue = false, Callback = function(v) AutoFireSettings.Enabled = v end})
    CombatTab:CreateToggle({Name = "Rapid Fire", CurrentValue = false, Callback = function(v) 
        RapidFireSettings.Enabled = v
        if not v then 
            rapidFireActive = false 
        end 
    end})
    
    CombatTab:CreateSection("Gun Mods")
    CombatTab:CreateToggle({Name = "No Recoil", CurrentValue = false, Callback = function(v) 
        NoRecoilSettings.Enabled = v
        if v then setupNoRecoil() end
    end})
    
    CombatTab:CreateSection("Hitbox Expander")
    CombatTab:CreateToggle({Name = "Expand Head Hitbox", CurrentValue = false, Callback = function(v) 
        HitboxExpanderEnabled = v
        if v then 
            updateHitboxSize() 
        end
    end})
    CombatTab:CreateSlider({Name = "Hitbox Size", Range = {5, 30}, Increment = 1, CurrentValue = 10, Callback = function(v) 
        HitboxSize = v
        if HitboxExpanderEnabled then 
            updateHitboxSize() 
        end
    end})

    -- Visual tab
    VisualTab:CreateSection("ESP")
    VisualTab:CreateToggle({Name = "ESP Master", CurrentValue = false, Callback = function(v) 
        ESPOptions.Enabled = v
        if not v then 
            clearAllESP() 
        end 
    end})
    VisualTab:CreateToggle({Name = "ESP Name", CurrentValue = false, Callback = function(v) ESPOptions.Name = v end})
    VisualTab:CreateToggle({Name = "Box ESP", CurrentValue = false, Callback = function(v) ESPOptions.Box = v end})
    VisualTab:CreateToggle({Name = "Chams", CurrentValue = false, Callback = function(v) 
        ESPOptions.Chams = v
        updateChams() 
    end})
    
    VisualTab:CreateSection("Visual Mods")
    VisualTab:CreateToggle({Name = "FOV Changer", CurrentValue = false, Callback = function(v) FOVSettings.Enabled = v end})
    VisualTab:CreateSlider({Name = "FOV Value", Range = {50, 120}, Increment = 1, CurrentValue = 70, Callback = function(v) FOVSettings.Value = v end})
    VisualTab:CreateToggle({Name = "Third Person", CurrentValue = false, Callback = function(v) ThirdPersonSettings.Enabled = v end})
    VisualTab:CreateSlider({Name = "Camera Distance", Range = {5, 50}, Increment = 1, CurrentValue = 10, Callback = function(v) ThirdPersonSettings.Distance = v end})
    VisualTab:CreateToggle({Name = "X-Ray", CurrentValue = false, Callback = function(v) XRaySettings.Enabled = v end})
    VisualTab:CreateToggle({Name = "Fullbright", CurrentValue = false, Callback = function(v) FullbrightSettings.Enabled = v end})

    -- Player tab
    PlayerTab:CreateSection("Movement")
    PlayerTab:CreateToggle({Name = "Speed Hack", CurrentValue = false, Callback = function(v) SpeedSettings.Enabled = v end})
    PlayerTab:CreateSlider({Name = "Speed Value", Range = {16, 100}, Increment = 1, CurrentValue = 30, Callback = function(v) SpeedSettings.Value = v end})
    PlayerTab:CreateToggle({Name = "Super Jump", CurrentValue = false, Callback = function(v) SuperJumpSettings.Enabled = v end})
    PlayerTab:CreateSlider({Name = "Jump Height", Range = {50, 200}, Increment = 5, CurrentValue = 100, Callback = function(v) SuperJumpSettings.Height = v end})
    PlayerTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(v) InfiniteJumpSettings.Enabled = v end})
    PlayerTab:CreateToggle({Name = "Fly", CurrentValue = false, Callback = function(v) 
        if v then 
            startFly() 
        else 
            stopFly() 
        end 
    end})
    PlayerTab:CreateToggle({Name = "Spider-Man Mode", CurrentValue = false, Callback = toggleSpider})

    -- Misc tab
    MiscTab:CreateSection("Server")
    MiscTab:CreateButton({Name = "Rejoin Game", Callback = function()
        LocalPlayer:Kick("Rejoining...")
        task.wait(1)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end})
    MiscTab:CreateButton({Name = "Server Hop", Callback = function()
        local servers = {}
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100"))
        end)
        if success and data then
            for _, v in pairs(data.data) do
                if type(v) == "table" and v.playing and v.maxPlayers and v.playing < v.maxPlayers then
                    servers[#servers + 1] = v.id
                end
            end
        end
        if #servers > 0 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
        end
    end})
    MiscTab:CreateButton({Name = "Unload Everything", Callback = function()
        LibraryUnloaded = true
        stopFly()
        clearAllESP()
        for _, cham in pairs(chamsObjects) do 
            pcall(function() cham:Destroy() end) 
        end
        for _, conn in pairs(connections) do 
            pcall(function() conn:Disconnect() end) 
        end
        setFullbright(false)
        setXrayState(false)
        Rayfield:Destroy()
    end})

    Rayfield:Notify({Title = "Vomagla Rost Alpha", Content = "Loaded! Rank: " .. UserRank:upper(), Duration = 3})
end

-- ============ KEY AUTHENTICATION GUI ============
local function showKeyAuth()
    local authGui = Instance.new("ScreenGui")
    authGui.Name = "KeyAuth"
    authGui.Parent = CoreGui
    authGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 350, 0, 200)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = authGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    title.Text = "Vomagla Rost - Key System"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = title
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -20, 0, 20)
    subtitle.Position = UDim2.new(0, 10, 0, 50)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Enter your key to continue"
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.Parent = mainFrame
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0, 250, 0, 35)
    keyBox.Position = UDim2.new(0.5, -125, 0, 80)
    keyBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    keyBox.Text = ""
    keyBox.PlaceholderText = "Enter key here..."
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 14
    keyBox.Parent = mainFrame
    
    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 6)
    keyCorner.Parent = keyBox
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0, 120, 0, 35)
    submitBtn.Position = UDim2.new(0.5, -60, 0, 130)
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    submitBtn.Text = "Submit"
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    submitBtn.Parent = mainFrame
    
    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 6)
    submitCorner.Parent = submitBtn
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0, 10, 0, 175)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.Parent = mainFrame
    
    submitBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text
        if ValidKeys[key] then
            UserKey = key
            UserRank = ValidKeys[key].rank
            CanCrash = ValidKeys[key].canCrash
            KeyAuthenticated = true
            
            statusLabel.Text = "Key accepted! Loading..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            task.wait(1)
            authGui:Destroy()
            
            exploitableRemotes = findExploitableRemotes()
            
            if UserRank == "admin" then
                Rayfield:Notify({
                    Title = "Admin Access",
                    Content = "Found " .. #exploitableRemotes .. " vulnerable remotes!",
                    Duration = 5,
                })
            else
                Rayfield:Notify({
                    Title = "Free Access",
                    Content = "You have free access.",
                    Duration = 3,
                })
            end
            
            -- Load the main script (now defined above)
            loadMainScript()
        else
            statusLabel.Text = "Invalid key! Access denied."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end

-- Start
showKeyAuth()
