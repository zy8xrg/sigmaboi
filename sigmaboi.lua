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
    ["admin123"] = { rank = "admin", canCrash = true }
}

local UserKey = nil
local UserRank = "user"
local CanCrash = false
local KeyAuthenticated = false

-- Admin crash function
local function crashFreePlayer(player)
    if not CanCrash then return end
    if player == LocalPlayer then return end
    
    pcall(function()
        if player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum then
                hum.Health = 0
                hum.PlatformStand = true
            end
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Transparency = 1
                end
            end
        end
        
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                tool:Destroy()
            end
        end
        
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in pairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    gui.Enabled = false
                end
            end
        end
        
        player:Kick("You have been crashed by an admin!")
    end)
end

local function crashAllFreePlayers()
    if not CanCrash then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            crashFreePlayer(player)
        end
    end
    
    Rayfield:Notify({
        Title = "Admin",
        Content = "Crashed all free players!",
        Duration = 3,
    })
end

-- DEFINE loadMainScript FIRST before calling it
local function loadMainScript()
    local playerCache = {}
    local cachedChar = LocalPlayer.Character
    local CurrentAimTarget = nil
    local LibraryUnloaded = false
    local Flying = false
    local FlyBodyVelocity = nil
    local FlyConnection = nil

    -- Hitbox Expander variables
    local HitboxExpanderEnabled = false
    local HitboxSize = 10
    local HitboxVisuals = {}
    local hitboxUpdateConnection = nil

    -- Spider/Climbing variables
    local SpiderEnabled = false
    local SpiderConnection = nil
    local IsClimbing = false
    local CurrentWallNormal = nil
    local LastWallCheck = 0

    -- No Recoil variables
    local RecoilHandler = nil
    local originalRecoilNew = nil
    local originalRecoilFromRecoilInfo = nil
    local noRecoilActive = false

    -- Always Headshot variables
    local AlwaysHeadshotEnabled = false

    -- Instant Eoka variables
    local InstantEokaEnabled = false
    local originalEokaStartFiring = nil

    -- Inventory Viewer State
    local inventoryViewerActive = false
    local currentInventoryGui = nil
    local inventoryUpdateConnection = nil

    -- Store all connections for easy cleanup
    local allConnections = {}
    local allToggles = {}

    -- ESP variables (defined early to avoid nil errors)
    local espObjects = {}
    local chamsObjects = {}
    local viewmodelChamsInstance = nil
    local rapidFireActive = false
    local fovCircle = nil
    
    -- X-Ray variables
    local wlK = {"TwigWall","SoloTwigFrame","TrigTwigRoof","TwigFrame","TwigWindow","TwigRoof"}
    local xrT = {}
    
    -- Original lighting values
    local originalBrightness = Lighting.Brightness
    local originalAmbient = Lighting.Ambient

    local v13 = {
        Enabled = false, TargetPart = "Head",
        UseFOV = true, FOVRadius = 150,
        MaxDistance = 500,
    }

    local ESPOptions = { 
        Enabled = false, 
        Name = false, 
        Distance = false, 
        Box = false, 
        Chams = false, 
        Tracer = false,
        Items = false,
        Ores = false,
        Crates = false,
        Backpacks = false,
        Airdrop = false,
        ViewmodelChams = false,
        ItemName = false
    }

    local ESPColors = { 
        Name = Color3.fromRGB(255,255,255), 
        Distance = Color3.fromRGB(255,255,255),
        Box = Color3.fromRGB(255,0,0),
        Tracer = Color3.fromRGB(0,255,0),
        Items = Color3.fromRGB(0,255,255),
        Ores = Color3.fromRGB(255,255,0),
        Crates = Color3.fromRGB(255,128,0),
        Backpacks = Color3.fromRGB(255,0,255),
        Airdrop = Color3.fromRGB(0,255,128),
        Viewmodel = Color3.fromRGB(0,255,0),
        ItemName = Color3.fromRGB(255,255,0)
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

    -- ============ HELPER FUNCTIONS (DEFINED FIRST) ============
    local function removeEmojis(text)
        if not text then return "" end
        local cleaned = text:gsub("[\228-\250][\128-\191][\128-\191][\128-\191]", "")
        cleaned = cleaned:gsub("[\226-\244][\128-\191][\128-\191]", "")
        cleaned = cleaned:gsub("[🔫📦🕷️🚪⚠️🎯⚡]", "")
        cleaned = cleaned:gsub("%s+", " ")
        return cleaned
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
            if p and p:IsDescendantOf(workspace) then p.Transparency = a and 0.5 or d.OT end
        end
    end

    local function clearAllESP()
        for obj, data in pairs(espObjects) do
            for _, drawingObj in pairs(data) do
                pcall(function() 
                    if drawingObj then
                        if drawingObj.Remove then drawingObj:Remove() 
                        elseif drawingObj.Destroy then drawingObj:Destroy() 
                        end
                    end
                end)
            end
        end
        espObjects = {}
    end

    local function stopFly()
        if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
        if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
        local hum = cachedChar and cachedChar:FindFirstChildWhichIsA("Humanoid")
        if hum then hum.PlatformStand = false end
        Flying = false
    end

    -- ============ HITBOX EXPANDER ============
    local function createHitboxVisual(part)
        if not part or not HitboxExpanderEnabled then return end
        
        if HitboxVisuals[part] then
            pcall(function() HitboxVisuals[part]:Destroy() end)
            HitboxVisuals[part] = nil
        end
        
        local selectionBox = Instance.new("SelectionBox")
        selectionBox.Adornee = part
        selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
        selectionBox.Transparency = 0.5
        selectionBox.LineThickness = 0.05
        selectionBox.Visible = true
        selectionBox.Parent = part
        
        HitboxVisuals[part] = selectionBox
    end

    local function updateHitboxSize()
        if not HitboxExpanderEnabled then return end
        
        for _, plr in pairs(playerCache) do
            local ch = plr.Character
            if ch then
                local headHitbox = ch:FindFirstChild("HeadHitbox") or ch:FindFirstChild("Head")
                if headHitbox and headHitbox:IsA("BasePart") then
                    pcall(function()
                        headHitbox.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        headHitbox.Transparency = 0.7
                        headHitbox.CanCollide = false
                    end)
                    createHitboxVisual(headHitbox)
                end
            end
        end
    end

    local function setupHitboxExpander()
        if not HitboxExpanderEnabled then return end
        
        for _, plr in pairs(playerCache) do
            local ch = plr.Character
            if ch then
                local headHitbox = ch:FindFirstChild("HeadHitbox") or ch:FindFirstChild("Head")
                if headHitbox and headHitbox:IsA("BasePart") then
                    pcall(function()
                        headHitbox.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                        headHitbox.Transparency = 0.7
                        headHitbox.CanCollide = false
                    end)
                    createHitboxVisual(headHitbox)
                end
            end
        end
        
        if hitboxUpdateConnection then hitboxUpdateConnection:Disconnect() end
        hitboxUpdateConnection = RunService.RenderStepped:Connect(function()
            if HitboxExpanderEnabled then
                updateHitboxSize()
            end
        end)
        table.insert(allConnections, hitboxUpdateConnection)
    end

    local function clearHitboxVisuals()
        for part, visual in pairs(HitboxVisuals) do
            pcall(function() visual:Destroy() end)
        end
        HitboxVisuals = {}
        if hitboxUpdateConnection then
            hitboxUpdateConnection:Disconnect()
            hitboxUpdateConnection = nil
        end
    end

    -- ============ ALWAYS HEADSHOT ============
    local function setupAlwaysHeadshot()
        if not AlwaysHeadshotEnabled then return end
        
        pcall(function()
            local GunRemotes = ReplicatedStorage:FindFirstChild("Gun")
            if GunRemotes then
                local Remotes = GunRemotes:FindFirstChild("Remotes")
                if Remotes then
                    local HitRemote = Remotes:FindFirstChild("Hit")
                    if HitRemote then
                        local oldHit = HitRemote.FireServer
                        HitRemote.FireServer = function(self, buffer, hitPart)
                            if CurrentAimTarget and AlwaysHeadshotEnabled then
                                local targetChar = CurrentAimTarget.Parent
                                if targetChar then
                                    local headHitbox = targetChar:FindFirstChild("HeadHitbox") or targetChar:FindFirstChild("Head")
                                    if headHitbox then
                                        hitPart = headHitbox
                                    end
                                end
                            end
                            return oldHit(self, buffer, hitPart)
                        end
                    end
                end
            end
            
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and rawget(v, "TotalAttachmentStats") then
                    if rawget(v, "TotalAttachmentStats") and rawget(v, "TotalAttachmentStats").DamageMult then
                        v.TotalAttachmentStats.DamageMult = 999
                    end
                end
            end
        end)
    end

    -- ============ INSTANT EOKA ============
    local function setupInstantEoka()
        if not InstantEokaEnabled then return end
        
        pcall(function()
            local GunModule = ReplicatedStorage:FindFirstChild("Gun")
            if GunModule then
                local Scripts = GunModule:FindFirstChild("Scripts")
                if Scripts then
                    for _, child in pairs(Scripts:GetChildren()) do
                        if child.Name and child.Name:lower():find("eoka") then
                            local EokaModule = require(child)
                            if EokaModule and EokaModule.new then
                                if not originalEokaStartFiring then
                                    originalEokaStartFiring = EokaModule.startFiring
                                end
                                
                                EokaModule.startFiring = function(self)
                                    if not self.HoldingMouseButton1 and self.CurrentAmmo and self.CurrentAmmo > 0 then
                                        self.HoldingMouseButton1 = true
                                        local GunRemotes = ReplicatedStorage:FindFirstChild("Gun")
                                        if GunRemotes then
                                            local Remotes = GunRemotes:FindFirstChild("Remotes")
                                            if Remotes then
                                                local StartedHitting = Remotes:FindFirstChild("StartedHitting")
                                                if StartedHitting then
                                                    StartedHitting:FireServer(self.Tool)
                                                end
                                            end
                                        end
                                        
                                        if self.AnimationHandler then
                                            self.AnimationHandler:playTrack(self.Animations.EokaHit)
                                        end
                                        
                                        task.wait(0.05)
                                        
                                        if originalEokaStartFiring then
                                            originalEokaStartFiring(self)
                                        else
                                            local GunBase = require(GunModule.Scripts.GunBase)
                                            if GunBase and GunBase.fire then
                                                GunBase.fire(self)
                                            end
                                        end
                                        
                                        task.wait(0.1)
                                        if Remotes and Remotes:FindFirstChild("StoppedHitting") then
                                            Remotes.StoppedHitting:FireServer(self.Tool)
                                        end
                                        self.HoldingMouseButton1 = false
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and rawget(v, "Rock") then
                    if rawget(v, "FireDelay") then
                        v.FireDelay = 0
                    end
                    if rawget(v, "CurrentAmmo") then
                        v.CurrentAmmo = 999
                    end
                end
            end
        end)
    end

    -- ============ NO RECOIL SYSTEM ============
    local function setupNoRecoil()
        if not NoRecoilSettings.Enabled then
            if originalRecoilNew and RecoilHandler then
                RecoilHandler.new = originalRecoilNew
                RecoilHandler.fromRecoilInfo = originalRecoilFromRecoilInfo
            end
            return
        end
        
        if noRecoilActive then return end
        
        pcall(function()
            RecoilHandler = require(ReplicatedStorage:WaitForChild("Gun").Scripts.RecoilHandler)
            
            if not originalRecoilNew then
                originalRecoilNew = RecoilHandler.new
                originalRecoilFromRecoilInfo = RecoilHandler.fromRecoilInfo
            end
            
            RecoilHandler.__index = RecoilHandler
            
            RecoilHandler.new = function(xFunction, yFunction, startingPoint, step, degreesPerUnit)
                local recoilFunctionInstance = setmetatable({}, RecoilHandler)
                recoilFunctionInstance.XFunction = xFunction
                recoilFunctionInstance.YFunction = yFunction
                recoilFunctionInstance.StartingPoint = startingPoint or 0
                recoilFunctionInstance.Step = step or 1
                recoilFunctionInstance.DegreesPerUnit = degreesPerUnit or 5
                recoilFunctionInstance.RadiansPerUnit = math.rad(recoilFunctionInstance.DegreesPerUnit)
                recoilFunctionInstance.RecoilMultiplier = 0
                recoilFunctionInstance:reset()
                return recoilFunctionInstance
            end
            
            RecoilHandler.fromRecoilInfo = function(recoilInfo)
                return RecoilHandler.new(
                    recoilInfo.XFunction,
                    recoilInfo.YFunction,
                    recoilInfo.StartingPoint,
                    recoilInfo.Step,
                    recoilInfo.DegreesPerUnit
                )
            end
            
            RecoilHandler.setRecoilMultiplier = function(recoilInfo, multiplier)
                recoilInfo.RecoilMultiplier = multiplier
            end
            
            RecoilHandler.reset = function(recoilInstance)
                recoilInstance.CurrentStep = recoilInstance.StartingPoint
                recoilInstance.PreviousX = recoilInstance.XFunction(recoilInstance.CurrentStep)
                recoilInstance.PreviousY = recoilInstance.YFunction(recoilInstance.CurrentStep)
            end
            
            RecoilHandler.getFinalRecoilMultiplier = function(recoilInfo)
                return 0
            end
            
            RecoilHandler.nextStep = function(recoilInstance)
                recoilInstance.CurrentStep = recoilInstance.CurrentStep + recoilInstance.Step
                local currentX = recoilInstance.XFunction(recoilInstance.CurrentStep)
                local currentY = recoilInstance.YFunction(recoilInstance.CurrentStep)
                recoilInstance.PreviousX = currentX
                recoilInstance.PreviousY = currentY
            end
            
            noRecoilActive = true
        end)
    end

    -- ============ UNLOAD EVERYTHING FUNCTION ============
    local function unloadEverything()
        Rayfield:Notify({
            Title = "Unloading",
            Content = "Disabling all features...",
            Duration = 2,
        })
        
        if HitboxExpanderEnabled then
            HitboxExpanderEnabled = false
            clearHitboxVisuals()
            for _, plr in pairs(playerCache) do
                local ch = plr.Character
                if ch then
                    local headHitbox = ch:FindFirstChild("HeadHitbox") or ch:FindFirstChild("Head")
                    if headHitbox then
                        pcall(function()
                            headHitbox.Size = Vector3.new(2, 2, 2)
                            headHitbox.Transparency = 0
                            headHitbox.CanCollide = true
                        end)
                    end
                end
            end
        end
        
        AlwaysHeadshotEnabled = false
        
        if InstantEokaEnabled then
            InstantEokaEnabled = false
            if originalEokaStartFiring then
                pcall(function()
                    local GunModule = ReplicatedStorage:FindFirstChild("Gun")
                    if GunModule then
                        local Scripts = GunModule:FindFirstChild("Scripts")
                        if Scripts then
                            for _, child in pairs(Scripts:GetChildren()) do
                                if child.Name and child.Name:lower():find("eoka") then
                                    local EokaModule = require(child)
                                    if EokaModule then
                                        EokaModule.startFiring = originalEokaStartFiring
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
        
        ESPOptions.Enabled = false
        clearAllESP()
        
        ESPOptions.Name = false
        ESPOptions.Distance = false
        ESPOptions.Box = false
        ESPOptions.Tracer = false
        ESPOptions.Chams = false
        ESPOptions.ViewmodelChams = false
        ESPOptions.ItemName = false
        ESPOptions.Items = false
        ESPOptions.Ores = false
        ESPOptions.Crates = false
        ESPOptions.Backpacks = false
        ESPOptions.Airdrop = false
        
        for flag, toggle in pairs(allToggles) do
            pcall(function()
                if toggle and toggle.Set then
                    toggle:Set(false)
                end
            end)
        end
        
        v13.Enabled = false
        AutoFireSettings.Enabled = false
        RapidFireSettings.Enabled = false
        rapidFireActive = false
        
        NoRecoilSettings.Enabled = false
        if originalRecoilNew and RecoilHandler then
            pcall(function()
                RecoilHandler.new = originalRecoilNew
                RecoilHandler.fromRecoilInfo = originalRecoilFromRecoilInfo
            end)
        end
        noRecoilActive = false
        
        SpeedSettings.Enabled = false
        SuperJumpSettings.Enabled = false
        InfiniteJumpSettings.Enabled = false
        
        if Flying then
            stopFly()
        end
        
        if SpiderEnabled then
            SpiderEnabled = false
            if SpiderConnection then
                SpiderConnection:Disconnect()
                SpiderConnection = nil
            end
            if cachedChar then
                local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    hum.AutoRotate = true
                    hum.UseJumpPower = true
                end
            end
        end
        
        FOVSettings.Enabled = false
        ThirdPersonSettings.Enabled = false
        XRaySettings.Enabled = false
        FullbrightSettings.Enabled = false
        setFullbright(false)
        setXrayState(false)
        
        if inventoryViewerActive then
            if currentInventoryGui then currentInventoryGui:Destroy() end
            if inventoryUpdateConnection then inventoryUpdateConnection:Disconnect() end
            inventoryViewerActive = false
        end
        
        if viewmodelChamsInstance then
            viewmodelChamsInstance:Destroy()
            viewmodelChamsInstance = nil
        end
        
        for _, cham in pairs(chamsObjects) do
            pcall(function() cham:Destroy() end)
        end
        chamsObjects = {}
        
        Rayfield:Notify({
            Title = "Unload Complete",
            Content = "All features have been disabled",
            Duration = 3,
        })
    end

    -- Cache players
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then playerCache[p] = true end end
    Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then playerCache[p] = true end end)
    Players.PlayerRemoving:Connect(function(p) playerCache[p] = nil end)

    -- ============ SPIDER/SPIDER-MAN CLIMBING SYSTEM ============
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
            local wallNormal = wallHit.Normal
            local wallPoint = wallHit.Position
            local distanceToWall = (origin - wallPoint).Magnitude
            
            if distanceToWall < 3 then
                IsClimbing = true
                CurrentWallNormal = wallNormal
                
                hum.UseJumpPower = false
                
                local climbVelocity = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    climbVelocity = Vector3.new(0, 25, 0)
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    climbVelocity = Vector3.new(0, -15, 0)
                else
                    climbVelocity = Vector3.new(0, 0, 0)
                end
                
                local rightDirection = hrp.CFrame.RightVector
                local moveDirection = Vector3.new()
                
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection = moveDirection - rightDirection
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection = moveDirection + rightDirection
                end
                
                local finalVelocity = climbVelocity + (moveDirection * 20)
                local pushToWall = wallNormal * -5
                finalVelocity = finalVelocity + pushToWall
                
                hrp.AssemblyLinearVelocity = finalVelocity
                
                if tick() - LastWallCheck > 0.2 then
                    LastWallCheck = tick()
                    local attachment = Instance.new("Attachment")
                    attachment.Parent = hrp
                    local particleEmitter = Instance.new("ParticleEmitter")
                    particleEmitter.Parent = attachment
                    particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                    particleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
                    particleEmitter.Lifetime = NumberRange.new(0.2)
                    particleEmitter.Rate = 50
                    particleEmitter.SpreadAngle = Vector2.new(180, 180)
                    particleEmitter.VelocityInheritance = 0
                    particleEmitter.Speed = NumberRange.new(2)
                    particleEmitter.Enabled = true
                    
                    task.delay(0.1, function()
                        particleEmitter.Enabled = false
                        task.delay(0.5, function()
                            if attachment then attachment:Destroy() end
                        end)
                    end)
                end
            else
                IsClimbing = false
                CurrentWallNormal = nil
                if hum then hum.UseJumpPower = true end
            end
        else
            if IsClimbing then
                IsClimbing = false
                CurrentWallNormal = nil
                if hum then hum.UseJumpPower = true end
            end
        end
    end

    local function toggleSpider()
        SpiderEnabled = not SpiderEnabled
        
        if SpiderEnabled then
            if SpiderConnection then SpiderConnection:Disconnect() end
            SpiderConnection = RunService.RenderStepped:Connect(startSpiderClimb)
            table.insert(allConnections, SpiderConnection)
            
            if cachedChar then
                local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    hum.AutoRotate = false
                    hum.PlatformStand = false
                end
            end
            
            Rayfield:Notify({
                Title = "Spider-Man Mode",
                Content = "Enabled! Hold W near walls + Space to climb up, Ctrl to climb down",
                Duration = 3,
            })
        else
            if SpiderConnection then
                SpiderConnection:Disconnect()
                SpiderConnection = nil
            end
            IsClimbing = false
            CurrentWallNormal = nil
            
            if cachedChar then
                local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
                if hum then
                    hum.AutoRotate = true
                    hum.UseJumpPower = true
                    hum.PlatformStand = false
                end
            end
            
            Rayfield:Notify({
                Title = "Spider-Man Mode",
                Content = "Disabled!",
                Duration = 2,
            })
        end
    end

    -- ============ VIEWMODEL CHAMS ============
    local function updateViewmodelChams()
        if ESPOptions.ViewmodelChams then
            local char = LocalPlayer.Character
            if char then
                local viewmodel = char:FindFirstChild("ViewModel")
                if viewmodel then
                    if not viewmodelChamsInstance then
                        viewmodelChamsInstance = Instance.new("Highlight")
                        viewmodelChamsInstance.FillColor = ESPColors.Viewmodel
                        viewmodelChamsInstance.FillTransparency = 0.3
                        viewmodelChamsInstance.OutlineTransparency = 0.5
                    end
                    viewmodelChamsInstance.Adornee = viewmodel
                    viewmodelChamsInstance.Parent = viewmodel
                end
            end
        else
            if viewmodelChamsInstance then
                viewmodelChamsInstance:Destroy()
                viewmodelChamsInstance = nil
            end
        end
    end

    -- ============ GET PLAYER CURRENT WEAPON (WITHOUT EMOJIS) ============
    local function getPlayerCurrentWeapon(player)
        if not player or not player.Character then return nil end
        
        local char = player.Character
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Tool") and (child:FindFirstChild("Handle") or child:FindFirstChild("PrimaryPart")) then
                return removeEmojis(child.Name)
            end
        end
        return nil
    end

    -- ============ GET PLAYER INVENTORY ITEMS (WITHOUT EMOJIS) ============
    local function getPlayerInventoryItems(player)
        if not player then return {} end
        
        local items = {}
        local seenItems = {}
        
        if player.Character then
            for _, tool in pairs(player.Character:GetChildren()) do
                if tool:IsA("Tool") and not seenItems[tool.Name] then
                    seenItems[tool.Name] = true
                    table.insert(items, removeEmojis(tool.Name))
                end
            end
        end
        
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and not seenItems[tool.Name] then
                    seenItems[tool.Name] = true
                    table.insert(items, removeEmojis(tool.Name))
                end
            end
        end
        
        return items
    end

    -- ============ INVENTORY VIEWER GUI ============
    local function getClosestPlayerToCenter()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local viewportCenter = cam.ViewportSize / 2
        local closest = nil
        local closestDist = math.huge
        
        for plr in pairs(playerCache) do
            local ch = plr.Character
            if ch then
                local hrp = ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - viewportCenter).Magnitude
                        if distToCenter < closestDist then
                            closestDist = distToCenter
                            closest = plr
                        end
                    end
                end
            end
        end
        return closest
    end

    local function updateInventoryViewerDisplay(player, scrollFrame, mainFrame)
        if not player or not scrollFrame or not mainFrame then return end
        
        for _, child in pairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local items = getPlayerInventoryItems(player)
        local currentWeapon = getPlayerCurrentWeapon(player)
        
        local nameLabel = mainFrame:FindFirstChild("NameLabel")
        if nameLabel then
            if currentWeapon then
                nameLabel.Text = removeEmojis(player.DisplayName) .. " - " .. currentWeapon
            else
                nameLabel.Text = removeEmojis(player.DisplayName) .. " (No Weapon)"
            end
        end
        
        local canvasWidth = #items * 55
        scrollFrame.CanvasSize = UDim2.new(0, math.max(canvasWidth, 350), 0, 30)
        
        for i, itemName in ipairs(items) do
            local isCurrentWeapon = (itemName == currentWeapon)
            
            local itemBtn = Instance.new("TextButton")
            itemBtn.Size = UDim2.new(0, 50, 0, 30)
            itemBtn.Position = UDim2.new(0, (i-1) * 55, 0, 0)
            itemBtn.BackgroundColor3 = isCurrentWeapon and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 45)
            itemBtn.BackgroundTransparency = 0.3
            itemBtn.Text = itemName
            itemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            itemBtn.Font = Enum.Font.Gotham
            itemBtn.TextSize = 10
            itemBtn.TextWrapped = true
            itemBtn.Parent = scrollFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = itemBtn
        end
    end

    local function toggleInventoryViewer()
        if inventoryViewerActive then
            if currentInventoryGui then
                currentInventoryGui:Destroy()
                currentInventoryGui = nil
            end
            if inventoryUpdateConnection then
                inventoryUpdateConnection:Disconnect()
                inventoryUpdateConnection = nil
            end
            inventoryViewerActive = false
            return
        end
        
        local target = getClosestPlayerToCenter()
        if not target then
            Rayfield:Notify({
                Title = "Inventory Viewer",
                Content = "No player found near center of screen!",
                Duration = 2,
            })
            return
        end
        
        inventoryViewerActive = true
        
        if currentInventoryGui then currentInventoryGui:Destroy() end
        
        local invGui = Instance.new("ScreenGui")
        invGui.Name = "PlayerInventoryViewer"
        invGui.Parent = CoreGui
        invGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        currentInventoryGui = invGui
        
        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 450, 0, 65)
        mainFrame.Position = UDim2.new(0.5, -225, 0, 10)
        mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        mainFrame.BorderSizePixel = 0
        mainFrame.BackgroundTransparency = 0.15
        mainFrame.Parent = invGui
        
        local mainCorner = Instance.new("UICorner")
        mainCorner.CornerRadius = UDim.new(0, 12)
        mainCorner.Parent = mainFrame
        
        local glow = Instance.new("Frame")
        glow.Size = UDim2.new(1, 0, 1, 0)
        glow.Position = UDim2.new(0, 0, 0, 0)
        glow.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        glow.BackgroundTransparency = 0.8
        glow.BorderSizePixel = 0
        glow.Parent = mainFrame
        
        local glowCorner = Instance.new("UICorner")
        glowCorner.CornerRadius = UDim.new(0, 12)
        glowCorner.Parent = glow
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -50, 0, 25)
        nameLabel.Position = UDim2.new(0, 10, 0, 5)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = removeEmojis(target.DisplayName)
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 14
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = mainFrame
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 25, 0, 25)
        closeBtn.Position = UDim2.new(1, -30, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        closeBtn.BackgroundTransparency = 0.5
        closeBtn.Text = "X"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        closeBtn.Parent = mainFrame
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 6)
        closeCorner.Parent = closeBtn
        
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -20, 0, 30)
        scrollFrame.Position = UDim2.new(0, 10, 0, 32)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 3
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = mainFrame
        
        updateInventoryViewerDisplay(target, scrollFrame, mainFrame)
        
        inventoryUpdateConnection = RunService.Stepped:Connect(function()
            if invGui and invGui.Parent and inventoryViewerActive then
                local currentTarget = getClosestPlayerToCenter()
                if currentTarget and currentTarget == target then
                    updateInventoryViewerDisplay(target, scrollFrame, mainFrame)
                elseif currentTarget then
                    target = currentTarget
                    updateInventoryViewerDisplay(target, scrollFrame, mainFrame)
                end
            elseif inventoryViewerActive then
                toggleInventoryViewer()
            end
        end)
        table.insert(allConnections, inventoryUpdateConnection)
        
        closeBtn.MouseButton1Click:Connect(function()
            toggleInventoryViewer()
        end)
    end

    -- ============ SILENT AIM ============
    local function getClosestPlayerForAim()
        local cam = workspace.CurrentCamera
        if not cam then return nil end
        local mousePos = UserInputService:GetMouseLocation()
        local best, bestD = nil, 1e9
        
        for plr in pairs(playerCache) do
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

    -- ============ ESP SYSTEM ============
    local lastESPCleanup = 0

    local function isPlayerDead(character)
        local hum = character and character:FindFirstChild("Humanoid")
        return not hum or hum.Health <= 0
    end

    local function cleanupESP()
        local now = tick()
        if now - lastESPCleanup < 0.5 then return end
        lastESPCleanup = now
        
        for obj, data in pairs(espObjects) do
            local valid = false
            if obj and obj.Parent then
                if obj:IsA("Player") then
                    valid = true
                elseif obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("MeshPart") then
                    if obj.Parent then valid = true end
                end
            end
            
            if not valid then
                for _, drawingObj in pairs(data) do
                    pcall(function() 
                        if drawingObj then
                            if drawingObj.Remove then drawingObj:Remove() 
                            elseif drawingObj.Destroy then drawingObj:Destroy() 
                            end
                        end
                    end)
                end
                espObjects[obj] = nil
            end
        end
    end

    local function updateESP()
        cleanupESP()
        
        if not ESPOptions.Enabled then
            clearAllESP()
            return
        end
        
        local cam = workspace.CurrentCamera
        if not cam then return end
        local myRoot = cachedChar and cachedChar:FindFirstChild("HumanoidRootPart")
        
        for plr in pairs(playerCache) do
            local ch = plr.Character
            local isDead = isPlayerDead(ch)
            
            if not ch or isDead then
                if espObjects[plr] then
                    for _, obj in pairs(espObjects[plr]) do
                        pcall(function() if obj and obj.Visible ~= nil then obj.Visible = false end end)
                    end
                end
            else
                local hrp = ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    local dist = myRoot and (myRoot.Position - hrp.Position).Magnitude or 0
                    local currentWeapon = getPlayerCurrentWeapon(plr)
                    
                    if not espObjects[plr] then espObjects[plr] = {} end
                    
                    if ESPOptions.Name and onScreen then
                        if not espObjects[plr].Name then
                            local text = Drawing.new("Text")
                            text.Size = 14
                            text.Center = true
                            text.Outline = true
                            text.Color = ESPColors.Name
                            espObjects[plr].Name = text
                        end
                        if espObjects[plr].Name then
                            espObjects[plr].Name.Visible = true
                            espObjects[plr].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 55)
                            espObjects[plr].Name.Text = removeEmojis(plr.DisplayName)
                        end
                    elseif espObjects[plr] and espObjects[plr].Name then
                        espObjects[plr].Name.Visible = false
                    end
                    
                    if ESPOptions.Distance and onScreen then
                        if not espObjects[plr].Dist then
                            local text = Drawing.new("Text")
                            text.Size = 12
                            text.Center = true
                            text.Outline = true
                            text.Color = ESPColors.Distance
                            espObjects[plr].Dist = text
                        end
                        if espObjects[plr].Dist then
                            espObjects[plr].Dist.Visible = true
                            espObjects[plr].Dist.Position = Vector2.new(screenPos.X, screenPos.Y - 40)
                            espObjects[plr].Dist.Text = math.floor(dist) .. "m"
                        end
                    elseif espObjects[plr] and espObjects[plr].Dist then
                        espObjects[plr].Dist.Visible = false
                    end
                    
                    if ESPOptions.ItemName and onScreen and currentWeapon then
                        if not espObjects[plr].ItemName then
                            local text = Drawing.new("Text")
                            text.Size = 12
                            text.Center = true
                            text.Outline = true
                            text.Color = ESPColors.ItemName
                            espObjects[plr].ItemName = text
                        end
                        if espObjects[plr].ItemName then
                            espObjects[plr].ItemName.Visible = true
                            espObjects[plr].ItemName.Position = Vector2.new(screenPos.X, screenPos.Y + 15)
                            espObjects[plr].ItemName.Text = currentWeapon
                        end
                    elseif espObjects[plr] and espObjects[plr].ItemName then
                        espObjects[plr].ItemName.Visible = false
                    end
                    
                    if ESPOptions.Box and onScreen then
                        if not espObjects[plr].Box then
                            local box = Drawing.new("Square")
                            box.Thickness = 1
                            box.Transparency = 0.5
                            box.Color = ESPColors.Box
                            box.Filled = false
                            espObjects[plr].Box = box
                        end
                        if espObjects[plr].Box then
                            local size = 100 / screenPos.Z
                            espObjects[plr].Box.Size = Vector2.new(50 * size, 100 * size)
                            espObjects[plr].Box.Position = Vector2.new(screenPos.X - espObjects[plr].Box.Size.X / 2, screenPos.Y - espObjects[plr].Box.Size.Y / 2)
                            espObjects[plr].Box.Visible = true
                        end
                    elseif espObjects[plr] and espObjects[plr].Box then
                        espObjects[plr].Box.Visible = false
                    end
                    
                    if ESPOptions.Tracer and onScreen then
                        if not espObjects[plr].Tracer then
                            local tracer = Drawing.new("Line")
                            tracer.Thickness = 1
                            tracer.Color = ESPColors.Tracer
                            espObjects[plr].Tracer = tracer
                        end
                        if espObjects[plr].Tracer then
                            local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                            espObjects[plr].Tracer.From = center
                            espObjects[plr].Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                            espObjects[plr].Tracer.Visible = true
                        end
                    elseif espObjects[plr] and espObjects[plr].Tracer then
                        espObjects[plr].Tracer.Visible = false
                    end
                end
            end
        end
        
        -- BackpackItems ESP
        if ESPOptions.Items then
            local backpackItems = ReplicatedStorage:FindFirstChild("BackpackItems")
            if backpackItems then
                for _, item in pairs(backpackItems:GetChildren()) do
                    if item:IsA("Model") then
                        local primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                        if primaryPart and primaryPart.Parent then
                            local screenPos, onScreen = cam:WorldToViewportPoint(primaryPart.Position)
                            if onScreen then
                                if not espObjects[item] then espObjects[item] = {} end
                                if not espObjects[item].Name then
                                    local text = Drawing.new("Text")
                                    text.Size = 12
                                    text.Center = true
                                    text.Outline = true
                                    text.Color = ESPColors.Items
                                    espObjects[item].Name = text
                                end
                                if espObjects[item].Name then
                                    espObjects[item].Name.Visible = true
                                    espObjects[item].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                                    espObjects[item].Name.Text = removeEmojis(item.Name)
                                end
                            elseif espObjects[item] and espObjects[item].Name then
                                espObjects[item].Name.Visible = false
                            end
                        end
                    end
                end
            end
        else
            for obj, data in pairs(espObjects) do
                if obj and (obj:IsDescendantOf(ReplicatedStorage) and obj.Parent == ReplicatedStorage:FindFirstChild("BackpackItems")) then
                    if data.Name then data.Name.Visible = false end
                end
            end
        end
        
        -- Ores ESP
        if ESPOptions.Ores then
            local ores = Workspace:FindFirstChild("ores")
            if ores then
                for _, ore in pairs(ores:GetChildren()) do
                    if ore:IsA("MeshPart") and ore.Parent then
                        local screenPos, onScreen = cam:WorldToViewportPoint(ore.Position)
                        if onScreen then
                            if not espObjects[ore] then espObjects[ore] = {} end
                            if not espObjects[ore].Name then
                                local text = Drawing.new("Text")
                                text.Size = 12
                                text.Center = true
                                text.Outline = true
                                text.Color = ESPColors.Ores
                                espObjects[ore].Name = text
                            end
                            if espObjects[ore].Name then
                                espObjects[ore].Name.Visible = true
                                espObjects[ore].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                                espObjects[ore].Name.Text = removeEmojis(ore.Name)
                            end
                        elseif espObjects[ore] and espObjects[ore].Name then
                            espObjects[ore].Name.Visible = false
                        end
                    end
                end
            end
        else
            for obj, data in pairs(espObjects) do
                if obj and obj:IsDescendantOf(Workspace) and obj.Parent == Workspace:FindFirstChild("ores") then
                    if data.Name then data.Name.Visible = false end
                end
            end
        end
        
        -- Crates ESP
        if ESPOptions.Crates then
            local crates = Workspace:FindFirstChild("Crates")
            if crates then
                for _, crate in pairs(crates:GetChildren()) do
                    if crate:IsA("Model") then
                        local primaryPart = crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart")
                        if primaryPart and primaryPart.Parent then
                            local screenPos, onScreen = cam:WorldToViewportPoint(primaryPart.Position)
                            if onScreen then
                                if not espObjects[crate] then espObjects[crate] = {} end
                                if not espObjects[crate].Name then
                                    local text = Drawing.new("Text")
                                    text.Size = 12
                                    text.Center = true
                                    text.Outline = true
                                    text.Color = ESPColors.Crates
                                    espObjects[crate].Name = text
                                end
                                if espObjects[crate].Name then
                                    espObjects[crate].Name.Visible = true
                                    espObjects[crate].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                                    espObjects[crate].Name.Text = removeEmojis(crate.Name)
                                end
                            elseif espObjects[crate] and espObjects[crate].Name then
                                espObjects[crate].Name.Visible = false
                            end
                        end
                    end
                end
            end
        else
            for obj, data in pairs(espObjects) do
                if obj and obj:IsDescendantOf(Workspace) and obj.Parent == Workspace:FindFirstChild("Crates") then
                    if data.Name then data.Name.Visible = false end
                end
            end
        end
        
        -- DeathBackpacks ESP
        if ESPOptions.Backpacks then
            local deathBackpacks = Workspace:FindFirstChild("DeathBackpacks")
            if deathBackpacks then
                for _, backpack in pairs(deathBackpacks:GetChildren()) do
                    if backpack:IsA("Model") then
                        local primaryPart = backpack.PrimaryPart or backpack:FindFirstChildWhichIsA("BasePart")
                        if primaryPart and primaryPart.Parent then
                            local screenPos, onScreen = cam:WorldToViewportPoint(primaryPart.Position)
                            if onScreen then
                                if not espObjects[backpack] then espObjects[backpack] = {} end
                                if not espObjects[backpack].Name then
                                    local text = Drawing.new("Text")
                                    text.Size = 12
                                    text.Center = true
                                    text.Outline = true
                                    text.Color = ESPColors.Backpacks
                                    espObjects[backpack].Name = text
                                end
                                if espObjects[backpack].Name then
                                    espObjects[backpack].Name.Visible = true
                                    espObjects[backpack].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                                    espObjects[backpack].Name.Text = "Death Backpack"
                                end
                            elseif espObjects[backpack] and espObjects[backpack].Name then
                                espObjects[backpack].Name.Visible = false
                            end
                        end
                    end
                end
            end
        else
            for obj, data in pairs(espObjects) do
                if obj and obj:IsDescendantOf(Workspace) and obj.Parent == Workspace:FindFirstChild("DeathBackpacks") then
                    if data.Name then data.Name.Visible = false end
                end
            end
        end
        
        -- Airdrop ESP
        if ESPOptions.Airdrop then
            local airdrop = Workspace:FindFirstChild("Airdrop")
            if airdrop then
                local airdropModel = airdrop:FindFirstChild("AirdropModel")
                if airdropModel and airdropModel:IsA("Model") then
                    local primaryPart = airdropModel.PrimaryPart or airdropModel:FindFirstChildWhichIsA("BasePart")
                    if primaryPart and primaryPart.Parent then
                        local screenPos, onScreen = cam:WorldToViewportPoint(primaryPart.Position)
                        if onScreen then
                            if not espObjects[airdropModel] then espObjects[airdropModel] = {} end
                            if not espObjects[airdropModel].Name then
                                local text = Drawing.new("Text")
                                text.Size = 14
                                text.Center = true
                                text.Outline = true
                                text.Color = ESPColors.Airdrop
                                espObjects[airdropModel].Name = text
                            end
                            if espObjects[airdropModel].Name then
                                espObjects[airdropModel].Name.Visible = true
                                espObjects[airdropModel].Name.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
                                espObjects[airdropModel].Name.Text = "AIRDROP"
                            end
                            
                            if not espObjects[airdropModel].Box then
                                local box = Drawing.new("Square")
                                box.Thickness = 2
                                box.Transparency = 0.5
                                box.Color = ESPColors.Airdrop
                                box.Filled = false
                                espObjects[airdropModel].Box = box
                            end
                            if espObjects[airdropModel].Box then
                                local size = 150 / screenPos.Z
                                espObjects[airdropModel].Box.Size = Vector2.new(60 * size, 60 * size)
                                espObjects[airdropModel].Box.Position = Vector2.new(screenPos.X - espObjects[airdropModel].Box.Size.X / 2, screenPos.Y - espObjects[airdropModel].Box.Size.Y / 2)
                                espObjects[airdropModel].Box.Visible = true
                            end
                        elseif espObjects[airdropModel] then
                            if espObjects[airdropModel].Name then espObjects[airdropModel].Name.Visible = false end
                            if espObjects[airdropModel].Box then espObjects[airdropModel].Box.Visible = false end
                        end
                    end
                end
            end
        else
            for obj, data in pairs(espObjects) do
                if obj and obj.Name == "AirdropModel" then
                    if data.Name then data.Name.Visible = false end
                    if data.Box then data.Box.Visible = false end
                end
            end
        end
    end

    -- Chams System
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
            if ch and not isPlayerDead(ch) and not chamsObjects[plr] then
                local hl = Instance.new("Highlight")
                hl.Name = "VomaglaChams"
                hl.FillColor = Color3.fromRGB(255, 0, 0)
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 1
                hl.Adornee = ch
                hl.Parent = ch
                chamsObjects[plr] = hl
            end
        end
    end

    -- ============ FLY SYSTEM ============
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
        table.insert(allConnections, FlyConnection)
    end

    -- ============ X-RAY REGISTRATION ============
    local function isWL(n) for _,k in ipairs(wlK) do if string.find(n:lower(), k:lower()) then return true end end return false end
    local function regXR(o)
        if xrT[o] then return end
        if (o:IsA("BasePart") or o:IsA("MeshPart")) and isWL(o.Name) then
            xrT[o] = {OT = o.Transparency}
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
        
        if SpeedSettings.Enabled and not Flying and not IsClimbing then
            local md = hum.MoveDirection
            if md.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * SpeedSettings.Value, hrp.AssemblyLinearVelocity.Y, md.Z * SpeedSettings.Value)
            end
        end
    end)
    table.insert(allConnections, physConn)

    -- Jump Mods
    local lastJumpTime = 0
    local jumpRequestConn = UserInputService.JumpRequest:Connect(function()
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
                if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, SuperJumpSettings.Height, r.AssemblyLinearVelocity.Z) end
            end
        end
    end)
    table.insert(allConnections, jumpRequestConn)

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
        updateViewmodelChams()
    end)
    table.insert(allConnections, visConn)

    -- ============ INPUT HANDLING ============
    local lastAim = 0
    local isMouseDown = false

    local inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
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
    table.insert(allConnections, inputBeganConn)

    local inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isMouseDown = false
            rapidFireActive = false
        end
    end)
    table.insert(allConnections, inputEndedConn)

    -- Aim Logic
    local aimConn = RunService.RenderStepped:Connect(function()
        local now = tick()
        if now - lastAim >= 0.033 then
            lastAim = now
            CurrentAimTarget = v13.Enabled and getClosestPlayerForAim() or nil
        end
        
        if AutoFireSettings.Enabled and v13.Enabled and CurrentAimTarget and isMouseDown and not RapidFireSettings.Enabled then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end)
    table.insert(allConnections, aimConn)

    -- FOV Circle
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
    table.insert(allConnections, fovConn)

    local espConn = RunService.RenderStepped:Connect(function() updateESP() end)
    table.insert(allConnections, espConn)

    -- Character Events
    local charAddedConn = LocalPlayer.CharacterAdded:Connect(function(char)
        cachedChar = char
        if Flying then
            stopFly()
            task.wait(0.5)
            startFly()
        end
        task.wait(1)
        updateChams()
        updateViewmodelChams()
        
        if SpiderEnabled then
            if SpiderConnection then SpiderConnection:Disconnect() end
            SpiderConnection = RunService.RenderStepped:Connect(startSpiderClimb)
            table.insert(allConnections, SpiderConnection)
            local hum = cachedChar:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum.AutoRotate = false
            end
        end
    end)
    table.insert(allConnections, charAddedConn)

    -- ============ UI ============
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
    
    -- Admin Tab (only visible for admin users)
    local AdminTab = nil
    if CanCrash then
        AdminTab = Window:CreateTab("Admin")
        
        AdminTab:CreateSection("Player Control")
        AdminTab:CreateButton({
            Name = "CRASH ALL FREE PLAYERS",
            Callback = function()
                crashAllFreePlayers()
            end,
        })
        
        AdminTab:CreateButton({
            Name = "Kick All Free Players",
            Callback = function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        player:Kick("You have been kicked by an admin!")
                    end
                end
                Rayfield:Notify({
                    Title = "Admin",
                    Content = "Kicked all free players!",
                    Duration = 3,
                })
            end,
        })
        
        AdminTab:CreateButton({
            Name = "Freeze All Free Players",
            Callback = function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hum = player.Character:FindFirstChild("Humanoid")
                        if hum then
                            hum.PlatformStand = true
                        end
                    end
                end
                Rayfield:Notify({
                    Title = "Admin",
                    Content = "Froze all free players!",
                    Duration = 3,
                })
            end,
        })
        
        AdminTab:CreateButton({
            Name = "Unfreeze All Players",
            Callback = function()
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local hum = player.Character:FindFirstChild("Humanoid")
                        if hum then
                            hum.PlatformStand = false
                        end
                    end
                end
                Rayfield:Notify({
                    Title = "Admin",
                    Content = "Unfroze all players!",
                    Duration = 3,
                })
            end,
        })
    end

    -- Combat Tab
    CombatTab:CreateSection("Silent Aim")
    local silentAimToggle = CombatTab:CreateToggle({
        Name = "Silent Aim",
        CurrentValue = false,
        Callback = function(v) v13.Enabled = v end,
    })
    allToggles["SilentAim"] = silentAimToggle

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
    local autoFireToggle = CombatTab:CreateToggle({
        Name = "Auto Fire (Hold on Enemy)",
        CurrentValue = false,
        Callback = function(v) AutoFireSettings.Enabled = v end,
    })
    allToggles["AutoFire"] = autoFireToggle

    local rapidFireToggle = CombatTab:CreateToggle({
        Name = "Rapid Fire (Full Auto)",
        CurrentValue = false,
        Callback = function(v) 
            RapidFireSettings.Enabled = v
            if not v then rapidFireActive = false end
        end,
    })
    allToggles["RapidFire"] = rapidFireToggle

    CombatTab:CreateSection("Gun Mods")
    local noRecoilToggle = CombatTab:CreateToggle({
        Name = "No Recoil",
        CurrentValue = false,
        Callback = function(v) 
            NoRecoilSettings.Enabled = v
            if v then
                setupNoRecoil()
            else
                if originalRecoilNew and RecoilHandler then
                    RecoilHandler.new = originalRecoilNew
                    RecoilHandler.fromRecoilInfo = originalRecoilFromRecoilInfo
                    noRecoilActive = false
                end
            end
        end,
    })
    allToggles["NoRecoil"] = noRecoilToggle

    local alwaysHeadshotToggle = CombatTab:CreateToggle({
        Name = "Always Headshot",
        CurrentValue = false,
        Callback = function(v)
            AlwaysHeadshotEnabled = v
            if v then setupAlwaysHeadshot() end
        end,
    })
    allToggles["AlwaysHeadshot"] = alwaysHeadshotToggle

    local instantEokaToggle = CombatTab:CreateToggle({
        Name = "Instant Eoka (100% Fire Rate)",
        CurrentValue = false,
        Callback = function(v)
            InstantEokaEnabled = v
            if v then setupInstantEoka() end
        end,
    })
    allToggles["InstantEoka"] = instantEokaToggle

    CombatTab:CreateSection("Hitbox Expander")
    local hitboxExpanderToggle = CombatTab:CreateToggle({
        Name = "Head Hitbox Expander",
        CurrentValue = false,
        Callback = function(v)
            HitboxExpanderEnabled = v
            if v then
                setupHitboxExpander()
                updateHitboxSize()
            else
                clearHitboxVisuals()
                for _, plr in pairs(playerCache) do
                    local ch = plr.Character
                    if ch then
                        local headHitbox = ch:FindFirstChild("HeadHitbox") or ch:FindFirstChild("Head")
                        if headHitbox then
                            pcall(function()
                                headHitbox.Size = Vector3.new(2, 2, 2)
                                headHitbox.Transparency = 0
                                headHitbox.CanCollide = true
                            end)
                        end
                    end
                end
            end
        end,
    })
    allToggles["HitboxExpander"] = hitboxExpanderToggle

    local hitboxSizeSlider = CombatTab:CreateSlider({
        Name = "Hitbox Size",
        Range = {5, 30},
        Increment = 1,
        CurrentValue = 10,
        Callback = function(v)
            HitboxSize = v
            if HitboxExpanderEnabled then
                updateHitboxSize()
            end
        end,
    })
    allToggles["HitboxSize"] = hitboxSizeSlider

    -- Visual Tab
    VisualTab:CreateSection("ESP Settings")
    local espMasterToggle = VisualTab:CreateToggle({
        Name = "ESP Master",
        CurrentValue = false,
        Callback = function(v) 
            ESPOptions.Enabled = v
            if not v then clearAllESP() end
        end,
    })
    allToggles["ESPMaster"] = espMasterToggle

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
    local chamsToggle = VisualTab:CreateToggle({
        Name = "Chams (Red)",
        CurrentValue = false,
        Callback = function(v) ESPOptions.Chams = v; updateChams() end,
    })
    allToggles["Chams"] = chamsToggle

    local viewmodelChamsToggle = VisualTab:CreateToggle({
        Name = "Viewmodel Chams",
        CurrentValue = false,
        Callback = function(v) ESPOptions.ViewmodelChams = v; updateViewmodelChams() end,
    })
    allToggles["ViewmodelChams"] = viewmodelChamsToggle

    local itemNameToggle = VisualTab:CreateToggle({
        Name = "Item Name ESP (Current Weapon Below Player)",
        CurrentValue = false,
        Callback = function(v) ESPOptions.ItemName = v end,
    })
    allToggles["ItemName"] = itemNameToggle

    VisualTab:CreateSection("World ESP")
    VisualTab:CreateToggle({
        Name = "Items ESP (BackpackItems)",
        CurrentValue = false,
        Callback = function(v) ESPOptions.Items = v end,
    })
    VisualTab:CreateToggle({
        Name = "Ores ESP",
        CurrentValue = false,
        Callback = function(v) ESPOptions.Ores = v end,
    })
    VisualTab:CreateToggle({
        Name = "Crates ESP",
        CurrentValue = false,
        Callback = function(v) ESPOptions.Crates = v end,
    })
    VisualTab:CreateToggle({
        Name = "Death Backpacks ESP",
        CurrentValue = false,
        Callback = function(v) ESPOptions.Backpacks = v end,
    })
    VisualTab:CreateToggle({
        Name = "Airdrop ESP",
        CurrentValue = false,
        Callback = function(v) ESPOptions.Airdrop = v end,
    })

    VisualTab:CreateSection("Visual Mods")
    local fovChangerToggle = VisualTab:CreateToggle({
        Name = "FOV Changer",
        CurrentValue = false,
        Callback = function(v) FOVSettings.Enabled = v end,
    })
    allToggles["FOVChanger"] = fovChangerToggle

    VisualTab:CreateSlider({
        Name = "FOV Value",
        Range = {50, 120},
        Increment = 1,
        CurrentValue = 70,
        Callback = function(v) FOVSettings.Value = v end,
    })
    local thirdPersonToggle = VisualTab:CreateToggle({
        Name = "Third Person",
        CurrentValue = false,
        Callback = function(v) ThirdPersonSettings.Enabled = v end,
    })
    allToggles["ThirdPerson"] = thirdPersonToggle

    VisualTab:CreateSlider({
        Name = "Camera Distance",
        Range = {5, 50},
        Increment = 1,
        CurrentValue = 10,
        Callback = function(v) ThirdPersonSettings.Distance = v end,
    })
    local xrayToggle = VisualTab:CreateToggle({
        Name = "X-Ray (See Through Walls)",
        CurrentValue = false,
        Callback = function(v) XRaySettings.Enabled = v end,
    })
    allToggles["XRay"] = xrayToggle

    local fullbrightToggle = VisualTab:CreateToggle({
        Name = "Fullbright (White)",
        CurrentValue = false,
        Callback = function(v) FullbrightSettings.Enabled = v end,
    })
    allToggles["Fullbright"] = fullbrightToggle

    -- Player Tab
    PlayerTab:CreateSection("Movement")
    local speedToggle = PlayerTab:CreateToggle({
        Name = "Speed Hack",
        CurrentValue = false,
        Callback = function(v) SpeedSettings.Enabled = v end,
    })
    allToggles["Speed"] = speedToggle

    PlayerTab:CreateSlider({
        Name = "Speed Value",
        Range = {16, 100},
        Increment = 1,
        CurrentValue = 30,
        Callback = function(v) SpeedSettings.Value = v end,
    })
    local superJumpToggle = PlayerTab:CreateToggle({
        Name = "Super Jump",
        CurrentValue = false,
        Callback = function(v) SuperJumpSettings.Enabled = v end,
    })
    allToggles["SuperJump"] = superJumpToggle

    PlayerTab:CreateSlider({
        Name = "Jump Height",
        Range = {50, 200},
        Increment = 5,
        CurrentValue = 100,
        Callback = function(v) SuperJumpSettings.Height = v end,
    })
    local infiniteJumpToggle = PlayerTab:CreateToggle({
        Name = "Infinite Jump",
        CurrentValue = false,
        Callback = function(v) InfiniteJumpSettings.Enabled = v end,
    })
    allToggles["InfiniteJump"] = infiniteJumpToggle

    local flyToggle = PlayerTab:CreateToggle({
        Name = "Fly (WASD + Space/Ctrl)",
        CurrentValue = false,
        Callback = function(v) if v then startFly() else stopFly() end end,
    })
    allToggles["Fly"] = flyToggle

    local spiderToggle = PlayerTab:CreateToggle({
        Name = "Spider-Man Mode (Climb Walls)",
        CurrentValue = false,
        Callback = function(v) 
            if v then
                toggleSpider()
            else
                if SpiderEnabled then
                    toggleSpider()
                end
            end
        end,
    })
    allToggles["Spider"] = spiderToggle

    -- Misc Tab
    MiscTab:CreateSection("Inventory")
    local inventoryViewerToggle = MiscTab:CreateToggle({
        Name = "Inventory Viewer (Closest Player to Crosshair)",
        CurrentValue = false,
        Callback = function(v) 
            if v then
                toggleInventoryViewer()
            else
                if inventoryViewerActive then
                    toggleInventoryViewer()
                end
            end
        end,
    })
    allToggles["InventoryViewer"] = inventoryViewerToggle

    MiscTab:CreateSection("Utility")
    MiscTab:CreateButton({
        Name = "UNLOAD EVERYTHING",
        Callback = function()
            unloadEverything()
        end,
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
        Content = string.format("Loaded! Rank: %s | Key: %s", UserRank:upper(), UserKey),
        Duration = 3,
    })

    -- Initialize No Recoil if needed
    if NoRecoilSettings.Enabled then
        setupNoRecoil()
    end

    -- ============ UNLOAD ============
    local function Unload()
        LibraryUnloaded = true
        unloadEverything()
        
        if fovCircle then fovCircle:Remove() end
        
        if oldNamecall and hookmetamethod then
            hookmetamethod(game, "__namecall", oldNamecall)
        end
        
        setFullbright(false)
        setXrayState(false)
        Rayfield:Destroy()
    end

    Rayfield:SetUnloadCallback(Unload)
end

-- Key authentication GUI
local function showKeyAuth()
    local authGui = Instance.new("ScreenGui")
    authGui.Name = "Kee"
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
    title.Text = "Vomagla Rost - Kee Syst3m"
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
    subtitle.Text = "3nter your kee to continu3"
    subtitle.TextColor3 = Color3.fromRGB(180, 180, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.Parent = mainFrame
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(0, 250, 0, 35)
    keyBox.Position = UDim2.new(0.5, -125, 0, 80)
    keyBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    keyBox.Text = ""
    keyBox.PlaceholderText = "3nter kee here..."
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
    submitBtn.Text = "Subm1t"
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
            
            statusLabel.Text = "✓ Kee accepted! Load1ng..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            
            task.wait(1)
            authGui:Destroy()
            
            if UserRank == "admin" then
                Rayfield:Notify({
                    Title = "Admin Access",
                    Content = "You have admin You can crash free users.",
                    Duration = 5,
                })
            else
                Rayfield:Notify({
                    Title = "Free Access",
                    Content = "You have free access.",
                    Duration = 3,
                })
            end
            
            -- Load the main script
            loadMainScript()
        else
            statusLabel.Text = "✗ 1nval1d kee Acc3ss deni3d."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
end

-- Start the key authentication
showKeyAuth()
