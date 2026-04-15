local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local playerCache = {}
local cachedChar = LocalPlayer.Character
local CurrentAimTarget = nil
local LibraryUnloaded = false
local Flying = false
local FlyBodyVelocity = nil
local FlyConnection = nil

-- No Recoil variables
local RecoilHandler = nil
local originalRecoilNew = nil
local originalRecoilFromRecoilInfo = nil
local noRecoilActive = false

-- Inventory Viewer State
local inventoryViewerActive = false
local currentInventoryGui = nil
local inventoryUpdateConnection = nil

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
    ItemName = false  -- Changed from Inventory to ItemName
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
    ItemName = Color3.fromRGB(255,255,0)  -- Yellow color for item names
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

-- Cache players
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then playerCache[p] = true end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then playerCache[p] = true end end)
Players.PlayerRemoving:Connect(function(p) playerCache[p] = nil end)

-- ============ VIEWMODEL CHAMS ============
local viewmodelChamsInstance = nil
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

-- ============ GET PLAYER CURRENT WEAPON ============
local function getPlayerCurrentWeapon(player)
    if not player or not player.Character then return nil end
    
    local char = player.Character
    for _, child in pairs(char:GetChildren()) do
        if child:IsA("Tool") and (child:FindFirstChild("Handle") or child:FindFirstChild("PrimaryPart")) then
            return child.Name
        end
    end
    return nil
end

-- ============ GET PLAYER INVENTORY ITEMS ============
local function getPlayerInventoryItems(player)
    if not player then return {} end
    
    local items = {}
    local seenItems = {}
    
    if player.Character then
        for _, tool in pairs(player.Character:GetChildren()) do
            if tool:IsA("Tool") and not seenItems[tool.Name] then
                seenItems[tool.Name] = true
                table.insert(items, tool.Name)
            end
        end
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in pairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and not seenItems[tool.Name] then
                seenItems[tool.Name] = true
                table.insert(items, tool.Name)
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
    
    for plr in next, playerCache do
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
            nameLabel.Text = player.DisplayName .. " 🔫 " .. currentWeapon
        else
            nameLabel.Text = player.DisplayName .. " (No Weapon)"
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
    invGui.Parent = game.CoreGui
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
    nameLabel.Text = target.DisplayName
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
    
    inventoryUpdateConnection = game:GetService("RunService").Stepped:Connect(function()
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

-- ============ ESP SYSTEM ============
local espObjects = {}
local lastESPCleanup = 0

local function isPlayerDead(character)
    local hum = character and character:FindFirstChild("Humanoid")
    return not hum or hum.Health <= 0
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
    
    for plr in next, playerCache do
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
                
                -- Player Name ESP (top)
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
                        espObjects[plr].Name.Text = plr.DisplayName
                    end
                elseif espObjects[plr] and espObjects[plr].Name then
                    espObjects[plr].Name.Visible = false
                end
                
                -- Distance ESP
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
                
                -- Item Name ESP (below the player - shows current weapon)
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
                        espObjects[plr].ItemName.Text = "📦 " .. currentWeapon
                    end
                elseif espObjects[plr] and espObjects[plr].ItemName then
                    espObjects[plr].ItemName.Visible = false
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
                    if espObjects[plr].Box then
                        local size = 100 / screenPos.Z
                        espObjects[plr].Box.Size = Vector2.new(50 * size, 100 * size)
                        espObjects[plr].Box.Position = Vector2.new(screenPos.X - espObjects[plr].Box.Size.X / 2, screenPos.Y - espObjects[plr].Box.Size.Y / 2)
                        espObjects[plr].Box.Visible = true
                    end
                elseif espObjects[plr] and espObjects[plr].Box then
                    espObjects[plr].Box.Visible = false
                end
                
                -- Tracer ESP
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
                                espObjects[item].Name.Text = item.Name
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
                            espObjects[ore].Name.Text = ore.Name
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
                                espObjects[crate].Name.Text = crate.Name
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
    updateViewmodelChams()
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
        CurrentAimTarget = v13.Enabled and getClosestPlayerForAim() or nil
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
    updateViewmodelChams()
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

-- Visual Tab
VisualTab:CreateSection("ESP Settings")
VisualTab:CreateToggle({
    Name = "ESP Master",
    CurrentValue = false,
    Callback = function(v) 
        ESPOptions.Enabled = v
        if not v then clearAllESP() end
    end,
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
VisualTab:CreateToggle({
    Name = "Viewmodel Chams",
    CurrentValue = false,
    Callback = function(v) ESPOptions.ViewmodelChams = v; updateViewmodelChams() end,
})
VisualTab:CreateToggle({
    Name = "Item Name ESP (Current Weapon Below Player)",
    CurrentValue = false,
    Callback = function(v) ESPOptions.ItemName = v end,
})

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
MiscTab:CreateToggle({
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
    Content = "Loaded! Item Name ESP now shows current weapon below player (📦 WeaponName)",
    Duration = 3,
})

-- Initialize No Recoil if needed
if NoRecoilSettings.Enabled then
    setupNoRecoil()
end

-- ============ UNLOAD ============
local function Unload()
    LibraryUnloaded = true
    stopFly()
    
    -- Close inventory viewer if open
    if inventoryViewerActive then
        if currentInventoryGui then currentInventoryGui:Destroy() end
        if inventoryUpdateConnection then inventoryUpdateConnection:Disconnect() end
        inventoryViewerActive = false
    end
    
    if viewmodelChamsInstance then viewmodelChamsInstance:Destroy() end
    
    -- Restore original recoil
    if originalRecoilNew and RecoilHandler then
        pcall(function()
            RecoilHandler.new = originalRecoilNew
            RecoilHandler.fromRecoilInfo = originalRecoilFromRecoilInfo
        end)
    end
    
    if physConn then physConn:Disconnect() end
    if visConn then visConn:Disconnect() end
    if aimConn then aimConn:Disconnect() end
    if espConn then espConn:Disconnect() end
    if fovConn then fovConn:Disconnect() end
    
    if fovCircle then fovCircle:Remove() end
    
    clearAllESP()
    
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
