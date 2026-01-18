--[[ 
    OBBY/LOBBY: POORLY SCRIPTED STUFF v11.0
    Features: Fixed Float (No Rising), Killer, Wallhop, Smart Barriers
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

--// THEME CONFIGURATION
local Theme = {
    Background = Color3.fromRGB(18, 18, 24),
    Sidebar = Color3.fromRGB(23, 23, 30),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(160, 160, 175),
    Accent = Color3.fromRGB(0, 122, 255),
    Stroke = Color3.fromRGB(60, 60, 80),
    Success = Color3.fromRGB(50, 205, 50),
    Destructive = Color3.fromRGB(255, 59, 48),
    CornerRadius = UDim.new(0, 14),
    Gold = Color3.fromRGB(255, 215, 0)
}

--// AUDIO SYSTEM
local SoundEnabled = true 
local SoundAssets = {
    Hover = "rbxassetid://6895079853",
    Click = "rbxassetid://1412830636",
    Notify = "rbxassetid://87437544236708",
    Error = "rbxassetid://15933620967"
}
local LoadedSounds = {}

local function PreloadSounds()
    local SoundFolder = Instance.new("Folder")
    SoundFolder.Name = "Obby_Script_Sounds"
    SoundFolder.Parent = SoundService
    
    for name, id in pairs(SoundAssets) do
        local s = Instance.new("Sound")
        s.Name = name
        s.SoundId = id
        s.Volume = 0.5 
        s.Parent = SoundFolder
        LoadedSounds[name] = s
    end
    ContentProvider:PreloadAsync(SoundFolder:GetChildren())
end
task.spawn(PreloadSounds)

local function PlayAudio(name)
    if not SoundEnabled then return end
    local sound = LoadedSounds[name]
    if sound then sound:Play() end
end

--// VARIABLES & SETTINGS
-- Movement
local WalkSpeedEnabled = false
local WalkSpeedValue = 24
local JumpPowerEnabled = false
local JumpPowerValue = 50
local FloatEnabled = false
local FloatPart = nil
local FloatY = 0 -- Stores the locked height
local InfJumpEnabled = false

-- Wallhop
local WallhopEnabled = false
local AutoWallhopEnabled = false
local FlickStrength = 1.5
local WaitTime = 0.06
local IsWallhopping = false
local LastWallhopTime = 0
local WallCheckDistance = 4.5

-- Killer / Teleport
local AutoKillEnabled = false
local AutoFarmEnabled = false
local BarriersRemoved = false
local BarrierCache = {} 

-- ESP Settings
local ESP_Settings = {
    Bart = {Enabled = false, Color = Color3.fromRGB(255, 215, 0)},
    Homer = {Enabled = false, Color = Color3.fromRGB(0, 122, 255)}, 
    Dead = {Enabled = false, Color = Color3.fromRGB(255, 255, 255)}, 
    AFK = {Enabled = false, Color = Color3.fromRGB(128, 128, 128)},
}
local ESP_Storage = {}

-- Global Keybind
local ToggleKey = Enum.KeyCode.RightControl 
local IsMenuOpen = true 
local IsSettingKeybind = false 

--// AUTO KILL LOGIC
task.spawn(function()
    while task.wait(0.1) do
        if AutoKillEnabled then
            pcall(function()
                if LocalPlayer.Team and LocalPlayer.Team.Name == "Homer" then
                    for _, target in pairs(Players:GetPlayers()) do
                        if target ~= LocalPlayer and target.Team and target.Team.Name == "Bart" then
                            if target.Character and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 then
                                if target.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                                    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool") or LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
                                    if tool then
                                        tool.Parent = LocalPlayer.Character
                                        tool:Activate()
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

--// FLOAT LOGIC (FIXED)
RunService.Heartbeat:Connect(function()
    if FloatEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if not FloatPart or not FloatPart.Parent then
            FloatPart = Instance.new("Part")
            FloatPart.Name = "FloatPlatform"
            FloatPart.Size = Vector3.new(6, 1, 6)
            FloatPart.Transparency = 0.5
            FloatPart.Anchored = true
            FloatPart.CanCollide = true
            FloatPart.Color = Theme.Accent
            FloatPart.Parent = Workspace
        end
        -- Lock Y to FloatY, update X and Z only
        local rootPos = LocalPlayer.Character.HumanoidRootPart.Position
        FloatPart.Position = Vector3.new(rootPos.X, FloatY, rootPos.Z)
    else
        if FloatPart then
            FloatPart:Destroy()
            FloatPart = nil
        end
    end
end)

--// WALLHOP LOGIC
local function isNearWall()
    local character = LocalPlayer.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    local velocity = rootPart.Velocity
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    if horizontalVelocity < 1 then return false end 

    local camera = workspace.CurrentCamera
    local camLook = camera.CFrame.LookVector
    local lookHorizontal = Vector3.new(camLook.X, 0, camLook.Z).Unit
    
    local directions = {
        lookHorizontal,                          
        Vector3.new(-lookHorizontal.Z, 0, lookHorizontal.X),  
        Vector3.new(lookHorizontal.Z, 0, -lookHorizontal.X),  
        -lookHorizontal                          
    }
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    for i, direction in ipairs(directions) do
        local dist = (i == 1) and WallCheckDistance or (WallCheckDistance * 0.8)
        local result = workspace:Raycast(rootPart.Position, direction * dist, raycastParams)
        
        if result then
            local normal = result.Normal
            if math.abs(normal:Dot(Vector3.new(0, 1, 0))) < 0.3 then
                return true
            end
        end
    end
    return false
end

local function performFlick()
    if IsWallhopping then return end
    IsWallhopping = true
    
    local origCFrame = workspace.CurrentCamera.CFrame
    local baseAngle = 15 
    local forceMultiplier = 6 
    local maxAngle = 30 
    
    local angle1 = math.rad(baseAngle + math.min(FlickStrength * forceMultiplier, maxAngle))
    local angle2 = math.rad(-(baseAngle + math.min(FlickStrength * forceMultiplier, maxAngle)))
    
    workspace.CurrentCamera.CFrame = origCFrame * CFrame.Angles(0, angle1, 0)
    task.wait(WaitTime / 3)
    workspace.CurrentCamera.CFrame = origCFrame * CFrame.Angles(0, angle2, 0)
    task.wait(WaitTime / 3)
    workspace.CurrentCamera.CFrame = origCFrame
    task.wait(WaitTime / 3)
    
    IsWallhopping = false
end

RunService.RenderStepped:Connect(function()
    if AutoWallhopEnabled and not IsWallhopping then
        if (tick() - LastWallhopTime) > 0.4 then
            local character = LocalPlayer.Character
            if character then
                local hum = character:FindFirstChild("Humanoid")
                if hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
                    if isNearWall() then
                        LastWallhopTime = tick()
                        performFlick()
                    end
                end
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if WallhopEnabled then
        performFlick()
    end
    
    if InfJumpEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

--// MOVEMENT & BARRIER LOGIC
RunService.Heartbeat:Connect(function()
    pcall(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            local hum = LocalPlayer.Character.Humanoid
            
            if WalkSpeedEnabled then
                hum.WalkSpeed = WalkSpeedValue
            else
                if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
            end
            
            if JumpPowerEnabled then
                hum.UseJumpPower = true
                hum.JumpPower = JumpPowerValue
            else
                if hum.JumpPower ~= 50 then hum.JumpPower = 50 end
            end
        end
    end)
end)

local function ToggleBarriers(disable)
    BarriersRemoved = disable
    
    if disable then
        for _, descendant in pairs(Workspace:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Name:lower() == "barrier" then 
                if not BarrierCache[descendant] then
                    BarrierCache[descendant] = {
                        Transparency = descendant.Transparency,
                        CanCollide = descendant.CanCollide
                    }
                end
                descendant.CanCollide = false
                descendant.Transparency = 0.8 
            end
        end
        
        local connection
        connection = Workspace.DescendantAdded:Connect(function(descendant)
            if not BarriersRemoved then connection:Disconnect() return end
            if descendant:IsA("BasePart") and descendant.Name:lower() == "barrier" then
                task.wait()
                if not BarrierCache[descendant] then
                    BarrierCache[descendant] = {
                        Transparency = descendant.Transparency,
                        CanCollide = descendant.CanCollide
                    }
                end
                descendant.CanCollide = false
                descendant.Transparency = 0.8
            end
        end)
    else
        for part, props in pairs(BarrierCache) do
            if part and part.Parent then
                part.CanCollide = props.CanCollide
                part.Transparency = props.Transparency
            end
        end
        BarrierCache = {}
    end
end

--// ESP LOGIC
local function ClearESP(player)
    if ESP_Storage[player] then
        if ESP_Storage[player].Highlight then ESP_Storage[player].Highlight:Destroy() end
        if ESP_Storage[player].Billboard then ESP_Storage[player].Billboard:Destroy() end
        ESP_Storage[player] = nil
    end
end

local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local teamName = player.Team and player.Team.Name or "Dead"
            
            local shouldShow = false
            local color = Color3.fromRGB(255, 255, 255)
            
            if teamName == "Bart" and ESP_Settings.Bart.Enabled then
                shouldShow = true
                color = ESP_Settings.Bart.Color
            elseif teamName == "Homer" and ESP_Settings.Homer.Enabled then
                shouldShow = true
                color = ESP_Settings.Homer.Color
            elseif teamName == "AFK" and ESP_Settings.AFK.Enabled then
                shouldShow = true
                color = ESP_Settings.AFK.Color
            elseif (teamName == "Dead" or teamName == "Player") and ESP_Settings.Dead.Enabled then
                shouldShow = true
                color = ESP_Settings.Dead.Color
            end

            if shouldShow then
                if not ESP_Storage[player] then
                    local highlight = Instance.new("Highlight")
                    highlight.FillColor = color
                    highlight.OutlineColor = color
                    highlight.FillTransparency = 0.5
                    highlight.OutlineTransparency = 0
                    highlight.Parent = player.Character
                    
                    local billboard = Instance.new("BillboardGui")
                    billboard.Size = UDim2.new(0, 200, 0, 50)
                    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Parent = player.Character.Head
                    
                    local text = Instance.new("TextLabel")
                    text.Size = UDim2.new(1, 0, 1, 0)
                    text.BackgroundTransparency = 1
                    text.TextColor3 = color
                    text.TextStrokeTransparency = 0
                    text.Font = Enum.Font.GothamBold
                    text.TextSize = 12
                    text.Parent = billboard
                    
                    ESP_Storage[player] = {Highlight = highlight, Billboard = billboard, TextLabel = text, Team = teamName}
                end
                
                local esp = ESP_Storage[player]
                if esp.Team ~= teamName then
                    esp.Highlight.FillColor = color
                    esp.Highlight.OutlineColor = color
                    esp.TextLabel.TextColor3 = color
                    esp.Team = teamName
                end
                
                local dist = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                esp.TextLabel.Text = string.format("%s\n[%s]\n%.0f studs", player.DisplayName, teamName, dist)
                
            else
                ClearESP(player)
            end
        else
            ClearESP(player)
        end
    end
end

RunService.RenderStepped:Connect(UpdateESP)
Players.PlayerRemoving:Connect(ClearESP)

--// TELEPORT & FARM LOGIC
task.spawn(function()
    while task.wait(0.1) do
        if AutoFarmEnabled then
            pcall(function()
                local winpad = Workspace:FindFirstChild("winpad", true)
                if winpad and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = winpad.CFrame
                end
            end)
        end
    end
end)

local function TeleportToLobby()
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart

        local lobbyCage = Workspace:FindFirstChild("lobbyCage")
        if not lobbyCage then 
            Library:Notify("Error", "Lobby folder not found!", 2)
            return 
        end

        local targetSpawn = nil
        if lobbyCage:FindFirstChild("map") and lobbyCage.map:FindFirstChild("Island Bar") then
            local spawns = lobbyCage.map["Island Bar"]:FindFirstChild("spawns")
            if spawns and spawns:FindFirstChild("spawn") then
                targetSpawn = spawns.spawn
            end
        end

        if not targetSpawn and lobbyCage:FindFirstChild("spawns") then
            local spawnsFolder = lobbyCage.spawns
            for _, child in pairs(spawnsFolder:GetChildren()) do
                if child:FindFirstChild("spawn") then
                    targetSpawn = child.spawn
                    break
                elseif child:IsA("BasePart") then
                    targetSpawn = child
                    break
                end
            end
        end

        if targetSpawn then
            root.CFrame = targetSpawn.CFrame + Vector3.new(0, 5, 0)
            Library:Notify("Success", "Teleported to Lobby", 2)
        else
            Library:Notify("Error", "Could not find a valid spawn point.", 2)
        end
    end)
end

local function TeleportToMap()
    pcall(function()
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local targetPart = nil
        local mapFolder = Workspace:FindFirstChild("map")
        if mapFolder then
             for _, child in pairs(mapFolder:GetChildren()) do
                 local spawns = child:FindFirstChild("spawns")
                 if spawns and spawns:FindFirstChild("spawn") then
                     targetPart = spawns.spawn
                     break
                 end
                 for _, desc in pairs(child:GetDescendants()) do
                     if desc:IsA("BasePart") and desc.CanCollide then
                         targetPart = desc
                         break
                     end
                 end
                 if targetPart then break end
             end
        end

        if not targetPart then
            local obbyFolder = Workspace:FindFirstChild("obby")
            if obbyFolder then
                for _, descendant in pairs(obbyFolder:GetDescendants()) do
                    if descendant:IsA("BasePart") and descendant.CanCollide == true then
                        targetPart = descendant
                        break
                    end
                end
            end
        end

        if targetPart then
            char.HumanoidRootPart.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
            Library:Notify("Success", "Teleported to Map", 2)
        else
            Library:Notify("Error", "No active map found.", 2)
        end
    end)
end

--// GUI LIBRARY (Standard macOS Style)
local Library = {}
local NotificationHolder
local ScreenGui 

function Library:Notify(Title, Text, Duration)
    PlayAudio("Notify")
    if not NotificationHolder then return end
    
    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0)
    NotifyFrame.BackgroundColor3 = Theme.Sidebar
    NotifyFrame.BackgroundTransparency = 0.1
    NotifyFrame.BorderSizePixel = 0
    NotifyFrame.ClipsDescendants = true
    NotifyFrame.Parent = NotificationHolder
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Theme.Stroke
    Stroke.Thickness = 1
    Stroke.Parent = NotifyFrame
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = NotifyFrame
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Text = Title
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 14
    TitleLabel.TextColor3 = Theme.Accent
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Size = UDim2.new(1, -20, 0, 20)
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = NotifyFrame
    
    local DescLabel = Instance.new("TextLabel")
    DescLabel.Text = Text
    DescLabel.Font = Enum.Font.Gotham
    DescLabel.TextSize = 12
    DescLabel.TextColor3 = Theme.Text
    DescLabel.BackgroundTransparency = 1
    DescLabel.Size = UDim2.new(1, -20, 0, 30)
    DescLabel.Position = UDim2.new(0, 10, 0, 22)
    DescLabel.TextXAlignment = Enum.TextXAlignment.Left
    DescLabel.TextWrapped = true
    DescLabel.Parent = NotifyFrame
    
    NotifyFrame:TweenSize(UDim2.new(1, 0, 0, 60), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
    
    task.delay(Duration or 3, function()
        NotifyFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.3, true, function()
            NotifyFrame:Destroy()
        end)
    end)
end

function Library:Init()
    if PlayerGui:FindFirstChild("ObbyScript_macOS") then PlayerGui.ObbyScript_macOS:Destroy() end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ObbyScript_macOS"
    ScreenGui.Parent = PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true

    --// SMOOTHER WELCOME SCREEN //
    local WelcomeBlur = Instance.new("Frame")
    WelcomeBlur.Size = UDim2.new(1,0,1,0)
    WelcomeBlur.BackgroundColor3 = Color3.fromRGB(0,0,0)
    WelcomeBlur.BackgroundTransparency = 0.5
    WelcomeBlur.Parent = ScreenGui
    
    local WelcomeFrame = Instance.new("Frame")
    WelcomeFrame.Name = "WelcomeFrame"
    WelcomeFrame.Size = UDim2.new(0, 0, 0, 0)
    WelcomeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    WelcomeFrame.BackgroundColor3 = Theme.Background
    WelcomeFrame.BorderSizePixel = 0
    WelcomeFrame.ClipsDescendants = true
    WelcomeFrame.Parent = ScreenGui
    
    local WelcomeCorner = Instance.new("UICorner", WelcomeFrame)
    WelcomeCorner.CornerRadius = Theme.CornerRadius
    local WelcomeStroke = Instance.new("UIStroke", WelcomeFrame)
    WelcomeStroke.Color = Theme.Accent
    WelcomeStroke.Thickness = 2

    local Avatar = Instance.new("ImageLabel")
    Avatar.Size = UDim2.new(0, 80, 0, 80)
    Avatar.Position = UDim2.new(0.5, -40, 0.2, 0)
    Avatar.BackgroundTransparency = 1
    Avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    Avatar.Parent = WelcomeFrame
    Instance.new("UICorner", Avatar).CornerRadius = UDim.new(1, 0)

    local WelcomeText = Instance.new("TextLabel")
    WelcomeText.Text = "Welcome Back, " .. LocalPlayer.DisplayName
    WelcomeText.Size = UDim2.new(1, 0, 0, 25)
    WelcomeText.Position = UDim2.new(0, 0, 0.6, 0)
    WelcomeText.BackgroundTransparency = 1
    WelcomeText.TextColor3 = Theme.Text
    WelcomeText.Font = Enum.Font.GothamBold
    WelcomeText.TextSize = 18
    WelcomeText.Parent = WelcomeFrame

    local LoadingText = Instance.new("TextLabel")
    LoadingText.Text = "Loading v11.0 Features..."
    LoadingText.Size = UDim2.new(1, 0, 0, 20)
    LoadingText.Position = UDim2.new(0, 0, 0.75, 0)
    LoadingText.BackgroundTransparency = 1
    LoadingText.TextColor3 = Theme.TextDim
    LoadingText.Font = Enum.Font.Gotham
    LoadingText.TextSize = 14
    LoadingText.Parent = WelcomeFrame

    TweenService:Create(WelcomeFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 200),
        Position = UDim2.new(0.5, -160, 0.5, -100)
    }):Play()
    
    task.wait(1)
    LoadingText.Text = "Finalizing..."
    task.wait(0.5)
    
    TweenService:Create(WelcomeFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)}):Play()
    TweenService:Create(WelcomeBlur, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    task.wait(0.4)
    WelcomeFrame:Destroy()
    WelcomeBlur:Destroy()

    NotificationHolder = Instance.new("Frame")
    NotificationHolder.Name = "Notifications"
    NotificationHolder.Size = UDim2.new(0, 250, 1, -20)
    NotificationHolder.Position = UDim2.new(1, -270, 0, 10)
    NotificationHolder.BackgroundTransparency = 1
    NotificationHolder.Parent = ScreenGui
    
    local UIList = Instance.new("UIListLayout")
    UIList.Padding = UDim.new(0, 5)
    UIList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    UIList.Parent = NotificationHolder

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "Window"
    MainFrame.Size = UDim2.new(0, 80, 0, 45)
    MainFrame.Position = UDim2.new(0.5, -40, 0.5, -22)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BackgroundTransparency = 1
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Theme.Stroke
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 650, 0, 420),
        Position = UDim2.new(0.5, -325, 0.5, -210),
        BackgroundTransparency = 0.05
    }):Play()

    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = Theme.CornerRadius

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 180, 1, 0)
    Sidebar.BackgroundColor3 = Theme.Sidebar
    Sidebar.BackgroundTransparency = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = Theme.CornerRadius
    
    local SidebarFix = Instance.new("Frame")
    SidebarFix.Size = UDim2.new(0, 10, 1, 0)
    SidebarFix.Position = UDim2.new(1, -10, 0, 0)
    SidebarFix.BackgroundColor3 = Theme.Sidebar
    SidebarFix.BorderSizePixel = 0
    SidebarFix.Parent = Sidebar
    
    local SidebarGradient = Instance.new("UIGradient")
    SidebarGradient.Rotation = 45
    SidebarGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200))
    }
    SidebarGradient.Parent = Sidebar

    local DragZone = Instance.new("Frame")
    DragZone.Size = UDim2.new(1, 0, 0, 40)
    DragZone.BackgroundTransparency = 1
    DragZone.Parent = MainFrame

    local Dragging, DragInput, DragStart, StartPos
    DragZone.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            DragStart = input.Position
            StartPos = MainFrame.Position
        end
    end)
    DragZone.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then DragInput = input end
    end)
    RunService.RenderStepped:Connect(function()
        if Dragging and DragInput then
            local Delta = DragInput.Position - DragStart
            MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        end
    end)

    local ContentPageHolder = Instance.new("Frame")
    ContentPageHolder.Size = UDim2.new(1, -180, 1, 0)
    ContentPageHolder.Position = UDim2.new(0, 180, 0, 0)
    ContentPageHolder.BackgroundTransparency = 1
    ContentPageHolder.Parent = MainFrame

    local ControlsHolder = Instance.new("Frame")
    ControlsHolder.Size = UDim2.new(0, 60, 0, 20)
    ControlsHolder.Position = UDim2.new(0, 18, 0, 18)
    ControlsHolder.BackgroundTransparency = 1
    ControlsHolder.Parent = MainFrame

    local function CreateDot(color, offset)
        local Dot = Instance.new("Frame")
        Dot.Size = UDim2.new(0, 12, 0, 12)
        Dot.Position = UDim2.new(0, offset, 0, 0)
        Dot.BackgroundColor3 = color
        Dot.Parent = ControlsHolder
        Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)
        local Btn = Instance.new("TextButton", Dot)
        Btn.Size = UDim2.new(1,0,1,0)
        Btn.BackgroundTransparency = 1
        Btn.Text = ""
        Btn.MouseEnter:Connect(function() PlayAudio("Hover") end)
        Btn.MouseButton1Click:Connect(function() PlayAudio("Click") end)
        return Btn
    end

    local CloseBtn = CreateDot(Color3.fromRGB(255, 95, 87), 0)
    local HideBtn = CreateDot(Color3.fromRGB(255, 189, 46), 20)
    local OpenBtn = CreateDot(Color3.fromRGB(40, 200, 64), 40)

    --// CLOSE CONFIRMATION //
    local function ShowCloseConfirmation()
        local ConfirmBlur = Instance.new("Frame")
        ConfirmBlur.Size = UDim2.new(1,0,1,0)
        ConfirmBlur.BackgroundColor3 = Color3.fromRGB(0,0,0)
        ConfirmBlur.BackgroundTransparency = 1
        ConfirmBlur.ZIndex = 10
        ConfirmBlur.Parent = ScreenGui
        TweenService:Create(ConfirmBlur, TweenInfo.new(0.3), {BackgroundTransparency = 0.6}):Play()

        local AlertFrame = Instance.new("Frame")
        AlertFrame.Size = UDim2.new(0,0,0,0)
        AlertFrame.Position = UDim2.new(0.5,0,0.5,0)
        AlertFrame.BackgroundColor3 = Theme.Background
        AlertFrame.ClipsDescendants = true
        AlertFrame.ZIndex = 11
        AlertFrame.Parent = ConfirmBlur
        Instance.new("UICorner", AlertFrame).CornerRadius = Theme.CornerRadius
        Instance.new("UIStroke", AlertFrame).Color = Theme.Stroke

        local AlertTitle = Instance.new("TextLabel")
        AlertTitle.Text = "Exit Script?"
        AlertTitle.Size = UDim2.new(1,0,0,30)
        AlertTitle.Position = UDim2.new(0,0,0,15)
        AlertTitle.BackgroundTransparency = 1
        AlertTitle.TextColor3 = Theme.Text
        AlertTitle.Font = Enum.Font.GothamBold
        AlertTitle.TextSize = 18
        AlertTitle.ZIndex = 12
        AlertTitle.Parent = AlertFrame

        local AlertMsg = Instance.new("TextLabel")
        AlertMsg.Text = "Are you sure you want to close the menu?"
        AlertMsg.Size = UDim2.new(1,0,0,20)
        AlertMsg.Position = UDim2.new(0,0,0,45)
        AlertMsg.BackgroundTransparency = 1
        AlertMsg.TextColor3 = Theme.TextDim
        AlertMsg.Font = Enum.Font.Gotham
        AlertMsg.TextSize = 14
        AlertMsg.ZIndex = 12
        AlertMsg.Parent = AlertFrame

        local YesBtn = Instance.new("TextButton")
        YesBtn.Text = "Yes"
        YesBtn.Size = UDim2.new(0.4, 0, 0, 35)
        YesBtn.Position = UDim2.new(0.05, 0, 0.7, 0)
        YesBtn.BackgroundColor3 = Theme.Destructive
        YesBtn.TextColor3 = Color3.new(1,1,1)
        YesBtn.Font = Enum.Font.GothamBold
        YesBtn.TextSize = 14
        YesBtn.ZIndex = 12
        YesBtn.Parent = AlertFrame
        Instance.new("UICorner", YesBtn).CornerRadius = UDim.new(0, 8)
        YesBtn.MouseEnter:Connect(function() PlayAudio("Hover") end)

        local NoBtn = Instance.new("TextButton")
        NoBtn.Text = "No"
        NoBtn.Size = UDim2.new(0.4, 0, 0, 35)
        NoBtn.Position = UDim2.new(0.55, 0, 0.7, 0)
        NoBtn.BackgroundColor3 = Theme.Sidebar
        NoBtn.TextColor3 = Theme.Text
        NoBtn.Font = Enum.Font.GothamBold
        NoBtn.TextSize = 14
        NoBtn.ZIndex = 12
        NoBtn.Parent = AlertFrame
        Instance.new("UICorner", NoBtn).CornerRadius = UDim.new(0, 8)
        NoBtn.MouseEnter:Connect(function() PlayAudio("Hover") end)

        TweenService:Create(AlertFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 280, 0, 160), Position = UDim2.new(0.5, -140, 0.5, -80)}):Play()

        YesBtn.MouseButton1Click:Connect(function()
            PlayAudio("Click")
            TweenService:Create(MainFrame, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
            TweenService:Create(AlertFrame, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
            TweenService:Create(ConfirmBlur, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            ScreenGui:Destroy()
        end)

        NoBtn.MouseButton1Click:Connect(function()
            PlayAudio("Click")
            TweenService:Create(AlertFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)}):Play()
            TweenService:Create(ConfirmBlur, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            ConfirmBlur:Destroy()
        end)
    end

    CloseBtn.MouseButton1Click:Connect(ShowCloseConfirmation)
    
    HideBtn.MouseButton1Click:Connect(function()
        IsMenuOpen = false
        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 80, 0, 45)}):Play()
        Sidebar.Visible = false
        ContentPageHolder.Visible = false
    end)

    OpenBtn.MouseButton1Click:Connect(function()
        IsMenuOpen = true
        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = UDim2.new(0, 650, 0, 420)}):Play()
        task.wait(0.1)
        Sidebar.Visible = true
        ContentPageHolder.Visible = true
    end)

    --// TOGGLE UI KEYBIND //
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if IsSettingKeybind then return end 
        
        if input.KeyCode == ToggleKey then
            if IsMenuOpen then
                IsMenuOpen = false
                TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 80, 0, 45)}):Play()
                Sidebar.Visible = false
                ContentPageHolder.Visible = false
            else
                IsMenuOpen = true
                TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = UDim2.new(0, 650, 0, 420)}):Play()
                task.wait(0.1)
                Sidebar.Visible = true
                ContentPageHolder.Visible = true
            end
        end
    end)

    local Title = Instance.new("TextLabel")
    Title.Text = "Poorly Scripted"
    Title.TextColor3 = Theme.TextDim
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 13
    Title.Size = UDim2.new(1, -40, 0, 20)
    Title.Position = UDim2.new(0, 20, 0, 60)
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Sidebar

    --// PROFILE SECTION
    local ProfileFrame = Instance.new("Frame")
    ProfileFrame.Name = "ProfileFrame"
    ProfileFrame.Size = UDim2.new(1, -24, 0, 50)
    ProfileFrame.Position = UDim2.new(0, 12, 1, -62)
    ProfileFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    ProfileFrame.BackgroundTransparency = 0.6
    ProfileFrame.Parent = Sidebar
    Instance.new("UICorner", ProfileFrame).CornerRadius = UDim.new(0, 10)
    local ProfileStroke = Instance.new("UIStroke", ProfileFrame)
    ProfileStroke.Color = Theme.Stroke
    ProfileStroke.Transparency = 0.5

    local ProfileImage = Instance.new("ImageLabel")
    ProfileImage.Name = "Avatar"
    ProfileImage.Size = UDim2.new(0, 36, 0, 36)
    ProfileImage.Position = UDim2.new(0, 7, 0.5, -18)
    ProfileImage.BackgroundTransparency = 1
    ProfileImage.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    ProfileImage.Parent = ProfileFrame
    Instance.new("UICorner", ProfileImage).CornerRadius = UDim.new(1, 0)
    
    local OnlineDot = Instance.new("Frame")
    OnlineDot.Size = UDim2.new(0, 10, 0, 10)
    OnlineDot.Position = UDim2.new(0, 34, 0, 26)
    OnlineDot.BackgroundColor3 = Theme.Success
    OnlineDot.BorderSizePixel = 0
    OnlineDot.Parent = ProfileFrame
    Instance.new("UICorner", OnlineDot).CornerRadius = UDim.new(1, 0)
    local DotStroke = Instance.new("UIStroke", OnlineDot)
    DotStroke.Color = Theme.Sidebar
    DotStroke.Thickness = 2

    local DisplayNameLabel = Instance.new("TextLabel")
    DisplayNameLabel.Name = "DName"
    DisplayNameLabel.Size = UDim2.new(1, -50, 0, 18)
    DisplayNameLabel.Position = UDim2.new(0, 50, 0, 8)
    DisplayNameLabel.BackgroundTransparency = 1
    DisplayNameLabel.Text = LocalPlayer.DisplayName
    DisplayNameLabel.TextColor3 = Theme.Text
    DisplayNameLabel.Font = Enum.Font.GothamBold
    DisplayNameLabel.TextSize = 12
    DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    DisplayNameLabel.Parent = ProfileFrame

    local UserNameLabel = Instance.new("TextLabel")
    UserNameLabel.Name = "UName"
    UserNameLabel.Size = UDim2.new(1, -50, 0, 14)
    UserNameLabel.Position = UDim2.new(0, 50, 0, 26)
    UserNameLabel.BackgroundTransparency = 1
    UserNameLabel.Text = "@" .. LocalPlayer.Name
    UserNameLabel.TextColor3 = Theme.TextDim
    UserNameLabel.Font = Enum.Font.Gotham
    UserNameLabel.TextSize = 11
    UserNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    UserNameLabel.Parent = ProfileFrame

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Size = UDim2.new(1, -20, 1, -160)
    TabContainer.Position = UDim2.new(0, 10, 0, 90)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ScrollBarThickness = 0
    TabContainer.Parent = Sidebar
    Instance.new("UIListLayout", TabContainer).Padding = UDim.new(0, 5)

    local Tabs = {}
    local FirstTab = true
    function Tabs:CreateTab(Name, Icon)
        local TabData = {}
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, 0, 0, 36)
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = "    " .. (Icon or "") .. "  " .. Name
        TabBtn.TextColor3 = Theme.TextDim
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 14
        TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        TabBtn.Parent = TabContainer
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)
        
        TabBtn.MouseEnter:Connect(function() PlayAudio("Hover") end)
        
        local Page = Instance.new("ScrollingFrame")
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.Visible = false
        Page.ScrollBarThickness = 0
        Page.Parent = ContentPageHolder
        Instance.new("UIListLayout", Page).Padding = UDim.new(0, 10)
        local Pad = Instance.new("UIPadding", Page)
        Pad.PaddingTop = UDim.new(0,20) Pad.PaddingLeft = UDim.new(0,20) Pad.PaddingRight = UDim.new(0,20)

        local function Activate()
            PlayAudio("Click")
            for _, c in pairs(TabContainer:GetChildren()) do 
                if c:IsA("TextButton") then 
                    TweenService:Create(c, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextColor3 = Theme.TextDim}):Play()
                end 
            end
            for _, c in pairs(ContentPageHolder:GetChildren()) do if c:IsA("ScrollingFrame") then c.Visible = false end end
            Page.Visible = true
            TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85, TextColor3 = Theme.Text}):Play()
            TabBtn.BackgroundColor3 = Theme.Text
        end
        
        TabBtn.MouseButton1Click:Connect(Activate)
        
        if FirstTab then Activate() FirstTab = false end

        function TabData:CreateToggle(Text, Callback, Default)
            local ToggleFrame = Instance.new("Frame", Page)
            ToggleFrame.Size = UDim2.new(1, 0, 0, 44)
            ToggleFrame.BackgroundColor3 = Theme.Sidebar
            ToggleFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 10)
            local ToggleStroke = Instance.new("UIStroke", ToggleFrame)
            ToggleStroke.Color = Theme.Stroke
            ToggleStroke.Transparency = 0.5
            
            local Label = Instance.new("TextLabel", ToggleFrame)
            Label.Text = "  " .. Text
            Label.Size = UDim2.new(0.7, 0, 1, 0)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.Gotham
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left

            local SwitchBg = Instance.new("Frame", ToggleFrame)
            SwitchBg.Size = UDim2.new(0, 44, 0, 24)
            SwitchBg.Position = UDim2.new(1, -55, 0.5, -12)
            SwitchBg.BackgroundColor3 = Default and Theme.Accent or Color3.fromRGB(60, 60, 70)
            Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

            local SwitchCircle = Instance.new("Frame", SwitchBg)
            SwitchCircle.Size = UDim2.new(0, 20, 0, 20)
            SwitchCircle.Position = Default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            SwitchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", SwitchCircle).CornerRadius = UDim.new(1, 0)

            local Toggled = Default or false
            local Trigger = Instance.new("TextButton", ToggleFrame)
            Trigger.Size = UDim2.new(1, 0, 1, 0)
            Trigger.BackgroundTransparency = 1
            Trigger.Text = ""
            Trigger.MouseEnter:Connect(function() PlayAudio("Hover") end)

            Trigger.MouseButton1Click:Connect(function()
                PlayAudio("Click")
                Toggled = not Toggled
                TweenService:Create(SwitchBg, TweenInfo.new(0.3), {BackgroundColor3 = Toggled and Theme.Accent or Color3.fromRGB(60, 60, 70)}):Play()
                TweenService:Create(SwitchCircle, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = Toggled and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}):Play()
                Library:Notify("Toggle Update", Text .. " has been " .. (Toggled and "Enabled" or "Disabled"), 2)
                Callback(Toggled)
            end)
        end

        function TabData:CreateSlider(Text, Min, Max, Default, Callback)
            local SliderFrame = Instance.new("Frame", Page)
            SliderFrame.Size = UDim2.new(1, 0, 0, 55)
            SliderFrame.BackgroundColor3 = Theme.Sidebar
            SliderFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 10)
            local SliderStroke = Instance.new("UIStroke", SliderFrame)
            SliderStroke.Color = Theme.Stroke
            SliderStroke.Transparency = 0.5

            local Label = Instance.new("TextLabel", SliderFrame)
            Label.Text = "  " .. Text .. ": " .. Default
            Label.Size = UDim2.new(1, 0, 0, 25)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.Gotham
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left

            local SliderBar = Instance.new("Frame", SliderFrame)
            SliderBar.Size = UDim2.new(1, -40, 0, 4)
            SliderBar.Position = UDim2.new(0, 20, 0, 38)
            SliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            Instance.new("UICorner", SliderBar)

            local SliderFill = Instance.new("Frame", SliderBar)
            SliderFill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = Theme.Accent
            Instance.new("UICorner", SliderFill)
            
            local SliderBtn = Instance.new("Frame", SliderFill)
            SliderBtn.Size = UDim2.new(0, 12, 0, 12)
            SliderBtn.Position = UDim2.new(1, -6, 0.5, -6)
            SliderBtn.BackgroundColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", SliderBtn).CornerRadius = UDim.new(1, 0)

            local function UpdateSlider(Input)
                local Size = math.clamp((Input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                SliderFill.Size = UDim2.new(Size, 0, 1, 0)
                local Value = math.floor((Min + (Max - Min) * Size) * 10) / 10 
                Label.Text = "  " .. Text .. ": " .. Value
                Callback(Value)
            end

            SliderBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    UpdateSlider(input)
                    local Connection; Connection = UserInputService.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider(input) end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then Connection:Disconnect() end
                    end)
                end
            end)
        end

        function TabData:CreateButton(Text, Callback)
            local ButtonFrame = Instance.new("Frame", Page)
            ButtonFrame.Size = UDim2.new(1, 0, 0, 40)
            ButtonFrame.BackgroundColor3 = Theme.Accent
            ButtonFrame.BackgroundTransparency = 0.2
            Instance.new("UICorner", ButtonFrame).CornerRadius = UDim.new(0, 10)
            
            local Gradient = Instance.new("UIGradient")
            Gradient.Rotation = 90
            Gradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(1, Theme.Accent)
            }
            Gradient.Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.7),
                NumberSequenceKeypoint.new(1, 0.1)
            }
            Gradient.Parent = ButtonFrame
            
            local BtnStroke = Instance.new("UIStroke", ButtonFrame)
            BtnStroke.Color = Color3.fromRGB(255,255,255)
            BtnStroke.Transparency = 0.6
            BtnStroke.Thickness = 1

            local Btn = Instance.new("TextButton", ButtonFrame)
            Btn.Size = UDim2.new(1, 0, 1, 0)
            Btn.BackgroundTransparency = 1
            Btn.Text = Text
            Btn.TextColor3 = Color3.fromRGB(255,255,255)
            Btn.Font = Enum.Font.GothamBold
            Btn.TextSize = 14
            Btn.MouseEnter:Connect(function() PlayAudio("Hover") end)

            Btn.MouseButton1Click:Connect(function()
                PlayAudio("Click")
                Callback()
            end)
            return Btn
        end
        return TabData
    end
    return Tabs
end

--// INITIALIZE
local Window = Library:Init()

local MainTab = Window:CreateTab("Main", "🏠")
MainTab:CreateToggle("Enable WalkSpeed", function(val) WalkSpeedEnabled = val end, false)
MainTab:CreateSlider("WalkSpeed", 16, 200, 16, function(val) WalkSpeedValue = val end)
MainTab:CreateToggle("Enable JumpPower", function(val) JumpPowerEnabled = val end, false)
MainTab:CreateSlider("JumpPower", 50, 300, 50, function(val) JumpPowerValue = val end)
MainTab:CreateToggle("Float", function(val) 
    FloatEnabled = val 
    if val and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        FloatY = LocalPlayer.Character.HumanoidRootPart.Position.Y - 3.5
    end
    if not val and FloatPart then FloatPart:Destroy() FloatPart = nil end
end, false)
MainTab:CreateToggle("Remove Barriers", function(val) ToggleBarriers(val) end, false)
MainTab:CreateToggle("Infinite Jump", function(val) InfJumpEnabled = val end, false)

local WallhopTab = Window:CreateTab("Wallhop", "🧱")
WallhopTab:CreateToggle("Glitch Wallhop (On Jump)", function(val) WallhopEnabled = val end, false)
WallhopTab:CreateToggle("Auto Wallhop", function(val) AutoWallhopEnabled = val end, false)
WallhopTab:CreateSlider("Flick Strength", 1, 5, 1.5, function(val) FlickStrength = val end)

local KillerTab = Window:CreateTab("Killer", "🔪")
KillerTab:CreateToggle("Auto Kill Barts (Must be Homer)", function(val) AutoKillEnabled = val end, false)

local VisualsTab = Window:CreateTab("Visuals", "👁️")
VisualsTab:CreateToggle("Bart ESP", function(val) ESP_Settings.Bart.Enabled = val end, false)
VisualsTab:CreateToggle("Homer ESP", function(val) ESP_Settings.Homer.Enabled = val end, false)
VisualsTab:CreateToggle("Player ESP", function(val) ESP_Settings.Dead.Enabled = val end, false)
VisualsTab:CreateToggle("AFK ESP", function(val) ESP_Settings.AFK.Enabled = val end, false)

local TeleportTab = Window:CreateTab("Teleports", "✈️")
TeleportTab:CreateButton("Teleport to Lobby", function()
    TeleportToLobby()
end)

TeleportTab:CreateButton("Teleport to Map (Random)", function()
    TeleportToMap()
end)

TeleportTab:CreateToggle("Auto Farm Winpad", function(val)
    AutoFarmEnabled = val
    if val then
        Library:Notify("Auto Farm", "Teleporting to winpad...", 2)
    end
end, false)

local MiscTab = Window:CreateTab("Misc", "⚙️")

MiscTab:CreateButton("Infinite Yield", function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
end)

MiscTab:CreateButton("Force Reset", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    end
end)

local SettingsTab = Window:CreateTab("Settings", "🛠️")

SettingsTab:CreateToggle("Enable UI Sounds", function(val)
    SoundEnabled = val
end, true)

local KeybindButton
KeybindButton = SettingsTab:CreateButton("Menu Keybind: RightControl", function()
    KeybindButton.Text = "Press any key..."
    IsSettingKeybind = true 
    local InputConnection
    InputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            ToggleKey = input.KeyCode
            KeybindButton.Text = "Menu Keybind: " .. input.KeyCode.Name
            Library:Notify("Settings", "Keybind set to " .. input.KeyCode.Name, 2)
            task.wait(0.2) 
            IsSettingKeybind = false 
            InputConnection:Disconnect()
        end
    end)
end)

print("Obby Utilities v11.0 - Loaded")
