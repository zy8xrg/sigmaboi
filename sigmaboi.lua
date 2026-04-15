local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local playerCache = {}
local cachedChar = LocalPlayer.Character
local CurrentAimTarget = nil
local LibraryUnloaded = false
local Flying = false
local FlyBodyVelocity = nil
local FlyConnection = nil

-- Store original gun functions for restoration
local originalGunFunctions = {}
local hookedGuns = {}

local v13 = {
    Enabled = false, TargetPart = "Head",
    UseFOV = true, FOVRadius = 150,
    MaxDistance = 500,
}

local ESPOptions = { Enabled = false, Name = false, Distance = false, Box = false, Chams = false, Tracer = false }
local ESPColors = { 
    Name = Color3.fromRGB(255,255,255), 
    Distance = Color3.fromRGB(255,255,255),
    Box = Color3.fromRGB(255,0,0),
    Tracer = Color3.fromRGB(0,255,0)
}
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
local InstantReloadSettings = { Enabled = false }
local InfiniteAmmoSettings = { Enabled = false }

-- Cache players
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then playerCache[p] = true end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then playerCache[p] = true end end)
Players.PlayerRemoving:Connect(function(p) playerCache[p] = nil end)

-- ============ GUN SYSTEM INTEGRATION ============
local function getCurrentGun()
    if not cachedChar then return nil end
    local tool = cachedChar:FindFirstChildWhichIsA("Tool")
    if not tool then return nil end
    return tool
end

local function hookGun(gunTool)
    if hookedGuns[gunTool] then return end
    
    -- Find the gun instance in memory
    local gunInstance = nil
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "Tool") == gunTool and rawget(v, "IsEquipped") ~= nil then
            gunInstance = v
            break
        end
    end
    
    if not gunInstance then return end
    
    hookedGuns[gunTool] = gunInstance
    originalGunFunctions[gunTool] = {}
    
    -- Infinite Ammo
    if InfiniteAmmoSettings.Enabled then
        originalGunFunctions[gunTool].CurrentAmmo = gunInstance.CurrentAmmo
        originalGunFunctions[gunTool].MaxAmmo = gunInstance.MaxAmmo
        originalGunFunctions[gunTool].MagAmmo = gunInstance.MagAmmo
        
        gunInstance.CurrentAmmo = 999
        gunInstance.MaxAmmo = 999
        gunInstance.MagAmmo = 999
    end
    
    -- No Recoil
    if NoRecoilSettings.Enabled and gunInstance.RecoilHandler then
        originalGunFunctions[gunTool].RecoilNextStep = gunInstance.RecoilHandler.nextStep
        gunInstance.RecoilHandler.nextStep = function() end
        gunInstance.RecoilHandler.RecoilMultiplier = 0
    end
    
    -- Instant Reload
    if InstantReloadSettings.Enabled then
        originalGunFunctions[gunTool].Reload = gunInstance.reload
        gunInstance.reload = function(self)
            self.CurrentAmmo = self.MaxAmmo
            return true
        end
    end
end

local function unhookGun(gunTool)
    local gunInstance = hookedGuns[gunTool]
    if not gunInstance then return end
    
    if originalGunFunctions[gunTool] then
        if originalGunFunctions[gunTool].RecoilNextStep and gunInstance.RecoilHandler then
            gunInstance.RecoilHandler.nextStep = originalGunFunctions[gunTool].RecoilNextStep
        end
        if originalGunFunctions[gunTool].Reload then
            gunInstance.reload = originalGunFunctions[gunTool].Reload
        end
    end
    
    hookedGuns[gunTool] = nil
    originalGunFunctions[gunTool] = nil
end

local function updateGunMods()
    for gunTool, gunInstance in pairs(hookedGuns) do
        if gunTool and gunTool.Parent then
            -- Update Infinite Ammo
            if InfiniteAmmoSettings.Enabled then
                gunInstance.CurrentAmmo = 999
                gunInstance.MaxAmmo = 999
                gunInstance.MagAmmo = 999
            elseif originalGunFunctions[gunTool] then
                gunInstance.CurrentAmmo = originalGunFunctions[gunTool].CurrentAmmo or gunInstance.CurrentAmmo
                gunInstance.MaxAmmo = originalGunFunctions[gunTool].MaxAmmo or gunInstance.MaxAmmo
                gunInstance.MagAmmo = originalGunFunctions[gunTool].MagAmmo or gunInstance.MagAmmo
            end
            
            -- Update No Recoil
            if NoRecoilSettings.Enabled and gunInstance.RecoilHandler then
                gunInstance.RecoilHandler.nextStep = function() end
                gunInstance.RecoilHandler.RecoilMultiplier = 0
            elseif originalGunFunctions[gunTool] and originalGunFunctions[gunTool].RecoilNextStep and gunInstance.RecoilHandler then
                gunInstance.RecoilHandler.nextStep = originalGunFunctions[gunTool].RecoilNextStep
            end
        else
            unhookGun(gunTool)
        end
    end
    
    -- Hook new gun if equipped
    local currentGun = getCurrentGun()
    if currentGun and not hookedGuns[currentGun] then
        hookGun(currentGun)
    end
end

-- ============ SILENT AIM ============
local function getClosestPlayer()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestD = nil, 1e9
    
    for plr in next, playerCache do
        local ch = plr.Character
        if not ch then continue end
        local part = ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local hum = ch:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local distToMouse = (mousePos - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
        if v13.UseFOV and distToMouse > v13.FOVRadius then continue end
        local distToPlayer = (cam.CFrame.Position - part.Position).Magnitude
        if distToPlayer > v13.MaxDistance then continue end
        if distToMouse < bestD then
            best = part
            bestD = distToMouse
        end
    end
    return best
end

local oldNamecall
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

-- ============ RAPID FIRE ============
local function doRapidFire()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- ============ VISUAL MODS ============
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient

local function setFullbright(enabled)
    if enabled then
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    else
        Lighting.Brightness = originalBrightness
        Lighting.Ambient = originalAmbient
    end
end

-- ============ ESP SYSTEM (Optimized) ============
local espObjects = {}
local lastESPCleanup = 0

local function cleanupESP()
    local now = tick()
    if now - lastESPCleanup < 0.5 then return end
    lastESPCleanup = now
    
    for plr, objects in pairs(espObjects) do
        if not playerCache[plr] or not plr.Parent then
            for _, obj in pairs(objects) do
                pcall(function() if obj.Remove then obj:Remove() else obj:Destroy() end end)
            end
            espObjects[plr] = nil
        end
    end
end

local function updateESP()
    cleanupESP()
    
    if not ESPOptions.Enabled then
        for _, objects in pairs(espObjects) do
            for _, obj in pairs(objects) do
                pcall(function() if obj.Remove then obj:Remove() else obj:Destroy() end end)
            end
        end
        for k in pairs(espObjects) do espObjects[k] = nil end
        return
    end
    
    local cam = workspace.CurrentCamera
    if not cam then return end
    local myRoot = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
    
    for plr in next, playerCache do
        local ch = plr.Character
        local shouldSkip = false
        
        if not ch then 
            shouldSkip = true
        else
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            local hum = ch:FindFirstChild("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then
                shouldSkip = true
            end
        end
        
        if shouldSkip then
            if espObjects[plr] then
                for _, obj in pairs(espObjects[plr]) do
                    pcall(function() if obj.Visible ~= nil then obj.Visible = false end end)
                end
            end
        else
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            local hum = ch:FindFirstChild("Humanoid")
            local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
            local dist = myRoot and (myRoot.Position - hrp.Position).Magnitude or 0
            
            if not espObjects[plr] then espObjects[plr] = {} end
            
            -- Name ESP
            if ESPOptions.Name then
                if not espObjects[plr].Name then
                    local text = Drawing.new("Text")
                    text.Size = 14
                    text.Center = true
                    text.Outline = true
                    text.Color = ESPColors.Name
                    espObjects[plr].Name = text
                end
                local nameObj = espObjects[plr].Name
                nameObj.Visible = onScreen
                if onScreen then
                    nameObj.Position = Vector2.new(screenPos.X, screenPos.Y - 40)
                    nameObj.Text = plr.DisplayName
                end
            elseif espObjects[plr].Name then
                espObjects[plr].Name.Visible = false
            end
            
            -- Distance ESP
            if ESPOptions.Distance then
                if not espObjects[plr].Dist then
                    local text = Drawing.new("Text")
                    text.Size = 12
                    text.Center = true
                    text.Outline = true
                    text.Color = ESPColors.Distance
                    espObjects[plr].Dist = text
                end
                local distObj = espObjects[plr].Dist
                distObj.Visible = onScreen
                if onScreen then
                    distObj.Position = Vector2.new(screenPos.X, screenPos.Y - 25)
                    distObj.Text = math.floor(dist) .. "m"
                end
            elseif espObjects[plr].Dist then
                espObjects[plr].Dist.Visible = false
            end
            
            -- Box ESP
            if ESPOptions.Box and onScreen then
                if not espObjects[plr].Box then
                    local box = Drawing.new("Square")
                    box.Thickness = 1
                    box.Transparency = 0.5
                    box.Color = ESPColors.Box
                    box.Filled = false
                    espObjects[plr].Box = box
                end
                local boxObj = espObjects[plr].Box
                local size = 100 / screenPos.Z
                boxObj.Size = Vector2.new(50 * size, 100 * size)
                boxObj.Position = Vector2.new(screenPos.X - boxObj.Size.X / 2, screenPos.Y - boxObj.Size.Y / 2)
                boxObj.Visible = true
            elseif espObjects[plr] and espObjects[plr].Box then
                espObjects[plr].Box.Visible = false
            end
            
            -- Tracer ESP
            if ESPOptions.Tracer and onScreen and cam then
                if not espObjects[plr].Tracer then
                    local tracer = Drawing.new("Line")
                    tracer.Thickness = 1
                    tracer.Color = ESPColors.Tracer
                    espObjects[plr].Tracer = tracer
                end
                local tracerObj = espObjects[plr].Tracer
                local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                tracerObj.From = center
                tracerObj.To = Vector2.new(screenPos.X, screenPos.Y)
                tracerObj.Visible = true
            elseif espObjects[plr] and espObjects[plr].Tracer then
                espObjects[plr].Tracer.Visible = false
            end
        end
    end
end

-- Chams System
local chamsObjects = {}
local function updateChams()
    if not ESPOptions.Chams then
        for _, cham in pairs(chamsObjects) do
            pcall(function() cham:Destroy() end)
        end
        chamsObjects = {}
        return
    end
    for plr in next, playerCache do
        if plr.Character and not chamsObjects[plr] then
            local hl = Instance.new("Highlight")
            hl.Name = "VomaglaChams"
            hl.FillColor = Color3.fromRGB(255, 0, 0)
            hl.FillTransparency = 0.5
            hl.OutlineTransparency = 1
            hl.Adornee = plr.Character
            hl.Parent = plr.Character
            chamsObjects[plr] = hl
        end
    end
end

-- ============ FLY SYSTEM ============
local function stopFly()
    if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    local hum = cachedChar and cachedChar:FindFirstChildWhichIsA("Humanoid")
    if hum then hum.PlatformStand = false end
    Flying = false
end

local function startFly()
    if not cachedChar then return end
    local hrp = cachedChar:FindFirstChild("HumanoidRootPart")
    local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
    if not hrp then return end
    
    stopFly()
    Flying = true
    
    if hum then hum.PlatformStand = true end
    
    FlyBodyVelocity = Instance.new("BodyVelocity")
    FlyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
    FlyBodyVelocity.Parent = hrp
    
    local speed = 85
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not Flying or not cachedChar or not FlyBodyVelocity then
            if FlyConnection then FlyConnection:Disconnect() end
            return
        end
        
        local moveDirection = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDirection = moveDirection + Vector3.new(0, -1, 0) end
        
        local cam = workspace.CurrentCamera
        if cam and moveDirection.Magnitude > 0 then
            local moveVelocity = (cam.CFrame.RightVector * moveDirection.X + cam.CFrame.UpVector * moveDirection.Y + cam.CFrame.LookVector * moveDirection.Z) * speed
            FlyBodyVelocity.Velocity = moveVelocity
        elseif FlyBodyVelocity then
            FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

-- ============ INVENTORY VIEWER ============
local function showInventory()
    local invGui = Instance.new("ScreenGui")
    invGui.Name = "InventoryViewer"
    invGui.Parent = game.CoreGui
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = invGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    title.Text = "Inventory Viewer"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = mainFrame
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -40)
    scroll.Position = UDim2.new(0, 5, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 5
    scroll.Parent = mainFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scroll
    
    local function addItem(itemName)
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -10, 0, 35)
        itemFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        itemFrame.Parent = scroll
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = itemFrame
        local itemLabel = Instance.new("TextLabel")
        itemLabel.Size = UDim2.new(1, -10, 1, 0)
        itemLabel.Position = UDim2.new(0, 5, 0, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = itemName
        itemLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.TextSize = 12
        itemLabel.Parent = itemFrame
    end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then addItem(tool.Name) end
        end
    end
    
    if cachedChar then
        for _, tool in pairs(cachedChar:GetChildren()) do
            if tool:IsA("Tool") then addItem(tool.Name) end
        end
    end
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 60, 0, 25)
    closeBtn.Position = UDim2.new(1, -70, 1, -30)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "Close"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = mainFrame
    closeBtn.MouseButton1Click:Connect(function() invGui:Destroy() end)
end

-- ============ X-RAY SYSTEM ============
local wlK = {"TwigWall","SoloTwigFrame","TrigTwigRoof","TwigFrame","TwigWindow","TwigRoof"}
local xrT = {}
local function isWL(n) for _,k in ipairs(wlK) do if string.find(n:lower(), k:lower()) then return true end end return false end
local function regXR(o)
    if xrT[o] then return end
    if (o:IsA("BasePart") or o:IsA("MeshPart")) and isWL(o.Name) then
        xrT[o] = {OT = o.Transparency}
    end
end
local function setXrayState(a)
    for p,d in pairs(xrT) do
        if p and p:IsDescendantOf(workspace) then p.Transparency = a and 0.5 or d.OT end
    end
end
task.spawn(function() for _,o in pairs(workspace:GetDescendants()) do regXR(o) end end)
workspace.DescendantAdded:Connect(function(o) regXR(o) end)

-- ============ MOVEMENT & PHYSICS ============
local physConn = RunService.Heartbeat:Connect(function()
    if LibraryUnloaded then return end
    local ch = cachedChar
    if not ch then return end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    local hum = ch:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    
    if SpeedSettings.Enabled and not Flying then
        local md = hum.MoveDirection
        if md.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = Vector3.new(md.X * SpeedSettings.Value, hrp.AssemblyLinearVelocity.Y, md.Z * SpeedSettings.Value)
        end
    end
end)

-- Jump Mods
local lastJumpTime = 0
UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpSettings.Enabled then
        local hum = cachedChar and cachedChar:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        return
    end
    if SuperJumpSettings.Enabled then
        local now = tick()
        if now - lastJumpTime > 0.5 then
            lastJumpTime = now
            local r = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
            if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, SuperJumpSettings.Height, r.AssemblyLinearVelocity.Z) end
        end
    end
end)

-- Visual Updates
local visConn = RunService.RenderStepped:Connect(function()
    if LibraryUnloaded then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if FOVSettings.Enabled then cam.FieldOfView = FOVSettings.Value end
    if ThirdPersonSettings.Enabled then
        local hrp = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
        if hrp then cam.CFrame = CFrame.new(hrp.Position - (cam.CFrame.LookVector * ThirdPersonSettings.Distance), hrp.Position) end
    end
    setFullbright(FullbrightSettings.Enabled)
    setXrayState(XRaySettings.Enabled)
    updateGunMods()
end)

-- ============ INPUT HANDLING ============
local lastAim = 0
local isMouseDown = false
local rapidFireActive = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = true
        if RapidFireSettings.Enabled then
            rapidFireActive = true
            task.spawn(function()
                while rapidFireActive and RapidFireSettings.Enabled and isMouseDown do
                    doRapidFire()
                    task.wait(0.01)
                end
            end)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isMouseDown = false
        rapidFireActive = false
    end
end)

-- Aim Logic
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

-- FOV Circle
local fovCircle = nil
local function updateFOVCircle()
    pcall(function()
        if not v13.Enabled or not v13.UseFOV then
            if fovCircle then fovCircle.Visible = false end
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

local fovConn = RunService.RenderStepped:Connect(function() updateFOVCircle() end)
local espConn = RunService.RenderStepped:Connect(function() updateESP() end)

-- Character Events
LocalPlayer.CharacterAdded:Connect(function(char)
    cachedChar = char
    if Flying then
        stopFly()
        task.wait(0.5)
        startFly()
    end
    task.wait(1)
    updateChams()
end)

-- Tool Equipped Event for Gun Hooking
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    local char = LocalPlayer.Character
    if char then
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.1)
                hookGun(child)
            end
        end)
    end
end)

-- ============ UI ============
local Window = Rayfield:CreateWindow({
    Name = "Vomagla Rost Alpha",
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

-- Combat Tab
CombatTab:CreateSection("Silent Aim")
CombatTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Callback = function(v) v13.Enabled = v end,
})
CombatTab:CreateToggle({
    Name = "Use FOV",
    CurrentValue = true,
    Callback = function(v) v13.UseFOV = v end,
})
CombatTab:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 300},
    Increment = 5,
    CurrentValue = 150,
    Callback = function(v) v13.FOVRadius = v end,
})
CombatTab:CreateSlider({
    Name = "Max Distance",
    Range = {100, 2000},
    Increment = 50,
    CurrentValue = 500,
    Callback = function(v) v13.MaxDistance = v end,
})

CombatTab:CreateSection("Fire Modes")
CombatTab:CreateToggle({
    Name = "Auto Fire (Hold on Enemy)",
    CurrentValue = false,
    Callback = function(v) AutoFireSettings.Enabled = v end,
})
CombatTab:CreateToggle({
    Name = "Rapid Fire (Full Auto)",
    CurrentValue = false,
    Callback = function(v) 
        RapidFireSettings.Enabled = v
        if not v then rapidFireActive = false end
    end,
})

CombatTab:CreateSection("Gun Mods")
CombatTab:CreateToggle({
    Name = "No Recoil",
    CurrentValue = false,
    Callback = function(v) NoRecoilSettings.Enabled = v; updateGunMods() end,
})
CombatTab:CreateToggle({
    Name = "Infinite Ammo",
    CurrentValue = false,
    Callback = function(v) InfiniteAmmoSettings.Enabled = v; updateGunMods() end,
})
CombatTab:CreateToggle({
    Name = "Instant Reload",
    CurrentValue = false,
    Callback = function(v) InstantReloadSettings.Enabled = v; updateGunMods() end,
})

-- Visual Tab
VisualTab:CreateSection("ESP Settings")
VisualTab:CreateToggle({
    Name = "ESP Master",
    CurrentValue = false,
    Callback = function(v) ESPOptions.Enabled = v end,
})
VisualTab:CreateToggle({
    Name = "ESP Name",
    CurrentValue = false,
    Callback = function(v) ESPOptions.Name = v end,
})
VisualTab:CreateToggle({
    Name = "ESP Distance",
    CurrentValue = false,
    Callback = function(v) ESPOptions.Distance = v end,
})
VisualTab:CreateToggle({
    Name = "Box ESP",
    CurrentValue = false,
    Callback = function(v) ESPOptions.Box = v end,
})
VisualTab:CreateToggle({
    Name = "Tracer ESP",
    CurrentValue = false,
    Callback = function(v) ESPOptions.Tracer = v end,
})
VisualTab:CreateToggle({
    Name = "Chams (Red)",
    CurrentValue = false,
    Callback = function(v) ESPOptions.Chams = v; updateChams() end,
})

VisualTab:CreateSection("Visual Mods")
VisualTab:CreateToggle({
    Name = "FOV Changer",
    CurrentValue = false,
    Callback = function(v) FOVSettings.Enabled = v end,
})
VisualTab:CreateSlider({
    Name = "FOV Value",
    Range = {50, 120},
    Increment = 1,
    CurrentValue = 70,
    Callback = function(v) FOVSettings.Value = v end,
})
VisualTab:CreateToggle({
    Name = "Third Person",
    CurrentValue = false,
    Callback = function(v) ThirdPersonSettings.Enabled = v end,
})
VisualTab:CreateSlider({
    Name = "Camera Distance",
    Range = {5, 50},
    Increment = 1,
    CurrentValue = 10,
    Callback = function(v) ThirdPersonSettings.Distance = v end,
})
VisualTab:CreateToggle({
    Name = "X-Ray (See Through Walls)",
    CurrentValue = false,
    Callback = function(v) XRaySettings.Enabled = v end,
})
VisualTab:CreateToggle({
    Name = "Fullbright (White)",
    CurrentValue = false,
    Callback = function(v) FullbrightSettings.Enabled = v end,
})

-- Player Tab
PlayerTab:CreateSection("Movement")
PlayerTab:CreateToggle({
    Name = "Speed Hack",
    CurrentValue = false,
    Callback = function(v) SpeedSettings.Enabled = v end,
})
PlayerTab:CreateSlider({
    Name = "Speed Value",
    Range = {16, 100},
    Increment = 1,
    CurrentValue = 30,
    Callback = function(v) SpeedSettings.Value = v end,
})
PlayerTab:CreateToggle({
    Name = "Super Jump",
    CurrentValue = false,
    Callback = function(v) SuperJumpSettings.Enabled = v end,
})
PlayerTab:CreateSlider({
    Name = "Jump Height",
    Range = {50, 200},
    Increment = 5,
    CurrentValue = 100,
    Callback = function(v) SuperJumpSettings.Height = v end,
})
PlayerTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(v) InfiniteJumpSettings.Enabled = v end,
})
PlayerTab:CreateToggle({
    Name = "Fly (WASD + Space/Ctrl)",
    CurrentValue = false,
    Callback = function(v) if v then startFly() else stopFly() end end,
})

-- Misc Tab
MiscTab:CreateSection("Inventory")
MiscTab:CreateButton({
    Name = "View Inventory",
    Callback = function() showInventory() end,
})

MiscTab:CreateSection("Server")
MiscTab:CreateButton({
    Name = "Rejoin Game",
    Callback = function()
        LocalPlayer:Kick("Rejoining...")
        task.wait(1)
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})
MiscTab:CreateButton({
    Name = "Server Hop",
    Callback = function()
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
    end,
})

Rayfield:Notify({
    Title = "Vomagla Rost Alpha",
    Content = "Loaded! Added: Box/Tracer ESP, Infinite Ammo, Instant Reload | Removed: Hitbox Expander",
    Duration = 3,
})

-- ============ UNLOAD ============
local function Unload()
    LibraryUnloaded = true
    stopFly()
    
    -- Unhook all guns
    for gunTool in pairs(hookedGuns) do
        unhookGun(gunTool)
    end
    
    if physConn then physConn:Disconnect() end
    if visConn then visConn:Disconnect() end
    if aimConn then aimConn:Disconnect() end
    if espConn then espConn:Disconnect() end
    if fovConn then fovConn:Disconnect() end
    
    if fovCircle then fovCircle:Remove() end
    
    for _, objects in pairs(espObjects) do
        for _, obj in pairs(objects) do
            pcall(function() if obj.Remove then obj:Remove() else obj:Destroy() end end)
        end
    end
    
    for _, cham in pairs(chamsObjects) do
        pcall(function() cham:Destroy() end)
    end
    
    if oldNamecall and hookmetamethod then
        hookmetamethod(game, "__namecall", oldNamecall)
    end
    
    setFullbright(false)
    setXrayState(false)
    Rayfield:Destroy()
end

Rayfield:SetUnloadCallback(Unload)
