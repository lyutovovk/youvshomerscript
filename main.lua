-- YOU VS HOMER SCRIPT [v4.4.4]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local T_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local TARGET_ID = 8816493943
local PROFILE_LINK = "https://www.roblox.com/users/"..TARGET_ID.."/profile"

-- // GLOBAL STATES
_G.espActive = false
_G.noclipActive = false
_G.floatActive = false
_G.afkFarmActive = false
_G.fullbrightActive = false
_G.zoomUnlocked = false
_G.deleteBarriersActive = false 
_G.killBartsActive = false -- Added for Killer Tab

local origBrightness = Lighting.Brightness
local origClockTime = Lighting.ClockTime
local origGlobalShadows = Lighting.GlobalShadows

-- // HELPERS
local function getRoleInfo(p)
    if not p or not p.Character then return "Lobby", Color3.new(1, 1, 1) end
    if p.Character:FindFirstChild("Homer") or (p.Team and p.Team.Name == "Homer") then return "HOMER", Color3.new(1, 0, 0) end
    if p.Character:FindFirstChild("Bart") or (p.Team and p.Team.Name == "Bart") then return "BART", Color3.new(1, 1, 0) end
    return "Player", Color3.new(1, 1, 1)
end

local function ClearAllESP()
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character then
            if v.Character:FindFirstChild("HHubESP") then v.Character.HHubESP:Destroy() end
            if v.Character:FindFirstChild("HHubTag") then v.Character.HHubTag:Destroy() end
        end
    end
end

-- // BARRIER LOGIC
local function UpdateBarriers()
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("barrier") or v.Name:lower():find("invisible")) then
            v.CanCollide = not _G.deleteBarriersActive
            v.Transparency = _G.deleteBarriersActive and 0.8 or 1
        end
    end
end

-- // FOLLOW CHECKER
local function checkFollowStatus()
    local success, result = pcall(function()
        local url = "https://friends.roproxy.com/v1/users/"..player.UserId.."/followings?limit=100"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        for _, user in pairs(data.data) do
            if user.id == TARGET_ID then return true end
        end
        return false
    end)
    return success and result
end

-- // MAIN CHEAT MENU
function StartCheatMenu()
    local sg = Instance.new("ScreenGui", game.CoreGui); sg.Name = "HomerHubGui"; sg.DisplayOrder = 999
    local main = Instance.new("Frame", sg)
    main.Size = UDim2.new(0, 520, 0, 0); main.Position = UDim2.new(0.5, -260, 0.5, -210); main.BackgroundColor3 = Color3.fromRGB(15, 15, 15); main.BackgroundTransparency = 0.2; main.ClipsDescendants = true; main.Active = true; main.Draggable = true; Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    
    local modal = Instance.new("Frame", sg); modal.Size = UDim2.new(0, 360, 0, 0); modal.Position = UDim2.new(0.5, -180, 0.5, -90); modal.BackgroundColor3 = Color3.fromRGB(20, 20, 20); modal.Visible = false; modal.ZIndex = 100; Instance.new("UICorner", modal)
    local warnTxt = Instance.new("TextLabel", modal); warnTxt.Size = UDim2.new(1, -40, 0, 90); warnTxt.Position = UDim2.new(0, 20, 0, 10); warnTxt.Text = "Script would be closed and you'll have to execute it again. Continue?"; warnTxt.TextColor3 = Color3.new(1,1,1); warnTxt.Font = "GothamBold"; warnTxt.TextSize = 18; warnTxt.BackgroundTransparency = 1; warnTxt.ZIndex = 101; warnTxt.TextWrapped = true

    local yesBtn = Instance.new("TextButton", modal); yesBtn.Size = UDim2.new(0, 130, 0, 45); yesBtn.Position = UDim2.new(0.08, 0, 0.65, 0); yesBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50); yesBtn.Text = "YES"; yesBtn.Font = "GothamBold"; yesBtn.TextSize = 18; yesBtn.ZIndex = 101; Instance.new("UICorner", yesBtn)
    local noBtn = Instance.new("TextButton", modal); noBtn.Size = UDim2.new(0, 130, 0, 45); noBtn.Position = UDim2.new(0.55, 0, 0.65, 0); noBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); noBtn.Text = "NO"; noBtn.Font = "GothamBold"; noBtn.TextSize = 18; noBtn.ZIndex = 101; Instance.new("UICorner", noBtn)
    local closeBtn = Instance.new("TextButton", main); closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -40, 0, 10); closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50); closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.Font = "GothamBold"; closeBtn.TextSize = 18; Instance.new("UICorner", closeBtn)

    closeBtn.MouseButton1Click:Connect(function() modal.Visible = true; TweenService:Create(modal, T_INFO, {Size = UDim2.new(0, 360, 0, 190)}):Play() end)
    noBtn.MouseButton1Click:Connect(function() local t = TweenService:Create(modal, T_INFO, {Size = UDim2.new(0, 360, 0, 0)}); t:Play(); t.Completed:Connect(function() modal.Visible = false end) end)
    yesBtn.MouseButton1Click:Connect(function() ClearAllESP(); sg:Destroy() end)

    local sidebar = Instance.new("Frame", main); sidebar.Size = UDim2.new(0, 140, 1, -60); sidebar.Position = UDim2.new(0, 5, 0, 55); sidebar.BackgroundColor3 = Color3.new(0,0,0); sidebar.BackgroundTransparency = 0.6; Instance.new("UICorner", sidebar)
    local container = Instance.new("Frame", main); container.Size = UDim2.new(1, -165, 1, -70); container.Position = UDim2.new(0, 155, 0, 60); container.BackgroundTransparency = 1
    local pages = {}

    local function CreateTab(name, order)
        local p = Instance.new("ScrollingFrame", container); p.Size = UDim2.new(1, 0, 1, 0); p.Visible = (order == 1); p.BackgroundTransparency = 1; p.ScrollBarThickness = 2; p.CanvasSize = UDim2.new(0,0,1.5,0)
        Instance.new("UIListLayout", p).Padding = UDim.new(0, 12); pages[name] = p
        local b = Instance.new("TextButton", sidebar); b.Size = UDim2.new(0.9, 0, 0, 45); b.Position = UDim2.new(0.05, 0, 0, (order-1)*50 + 10); b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 0.9; b.Text = name; b.TextColor3 = Color3.new(1,1,1); b.Font = "GothamBold"; b.TextSize = 16; Instance.new("UICorner", b)
        b.MouseButton1Click:Connect(function() for _, pg in pairs(pages) do pg.Visible = false end p.Visible = true end)
    end

    local function AddBtn(txt, pg, cb)
        local btn = Instance.new("TextButton", pages[pg]); btn.Size = UDim2.new(1, -10, 0, 52); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); btn.BackgroundTransparency = 0.4; btn.Text = txt; btn.TextColor3 = Color3.new(1,1,1); btn.Font = "GothamBold"; btn.TextSize = 18; Instance.new("UICorner", btn)
        btn.MouseButton1Click:Connect(function() 
            cb(btn) 
            local active = (_G.espActive and txt == "Toggle ESP") or (_G.afkFarmActive and txt == "Autofarm (7s)") or (_G.noclipActive and txt == "Noclip") or (_G.floatActive and txt == "Float Platform") or (_G.fullbrightActive and txt == "Fullbright") or (_G.zoomUnlocked and txt == "Unlock Zoom") or (_G.deleteBarriersActive and txt == "Disable Barriers") or (_G.killBartsActive and txt == "Kill All Barts")
            TweenService:Create(btn, T_INFO, {BackgroundColor3 = active and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 50, 50), BackgroundTransparency = active and 0.2 or 0.4}):Play()
        end)
    end

    local function AddLabel(txt, pg, col)
        local l = Instance.new("TextLabel", pages[pg]); l.Size = UDim2.new(1, -10, 0, 40); l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = col or Color3.new(1,1,1); l.Font = "GothamBold"; l.TextSize = 16; l.TextXAlignment = "Left"; l.TextWrapped = true
    end

    CreateTab("Main", 1); CreateTab("Player", 2); CreateTab("Visuals", 3); CreateTab("Teleport", 4); CreateTab("Killer", 5)
    AddLabel("🏠 YOU VS HOMER SCRIPT v4.4.4", "Main", Color3.new(1, 1, 0))
    AddLabel("Status: Verified (v3.7.4 Engine)", "Main", Color3.new(0, 1, 0))
    
    AddBtn("Noclip", "Player", function() _G.noclipActive = not _G.noclipActive end)
    AddBtn("Float Platform", "Player", function() _G.floatActive = not _G.floatActive end)
    AddBtn("Unlock Zoom", "Player", function() _G.zoomUnlocked = not _G.zoomUnlocked; player.CameraMaxZoomDistance = _G.zoomUnlocked and 10000 or 50 end)
    
    AddBtn("Toggle ESP", "Visuals", function() _G.espActive = not _G.espActive if not _G.espActive then ClearAllESP() end end)
    AddBtn("Fullbright", "Visuals", function() _G.fullbrightActive = not _G.fullbrightActive if not _G.fullbrightActive then Lighting.Brightness = origBrightness; Lighting.ClockTime = origClockTime; Lighting.GlobalShadows = origGlobalShadows end end)
    AddBtn("Disable Barriers", "Visuals", function() _G.deleteBarriersActive = not _G.deleteBarriersActive; UpdateBarriers() end)

    AddBtn("Teleport Lobby", "Teleport", function() local l = Workspace:FindFirstChild("lobbyCage") if l then local sp = l.spawns:GetChildren() local r = sp[math.random(1, #sp)] local t = r:FindFirstChild("spawn") or r:FindFirstChildWhichIsA("BasePart") if t then player.Character.HumanoidRootPart.CFrame = t.CFrame * CFrame.new(0, 3, 0) end end end)
    AddBtn("Teleport Map", "Teleport", function() if Workspace:FindFirstChild("map") then for _, m in pairs(Workspace.map:GetChildren()) do local s = m:FindFirstChild("spawns") if s then local t = s:FindFirstChild("spawn") or s:FindFirstChildWhichIsA("BasePart") if t then player.Character.HumanoidRootPart.CFrame = t.CFrame * CFrame.new(0, 3, 0) break end end end end end)
    AddBtn("Autofarm (7s)", "Teleport", function() _G.afkFarmActive = not _G.afkFarmActive end)

    AddBtn("Kill All Barts", "Killer", function() _G.killBartsActive = not _G.killBartsActive end)

    TweenService:Create(main, T_INFO, {Size = UDim2.new(0, 520, 0, 430)}):Play()
    UserInputService.InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == Enum.KeyCode.LeftControl then local isOpen = main.Size.Y.Offset > 0 TweenService:Create(main, T_INFO, {Size = isOpen and UDim2.new(0, 520, 0, 0) or UDim2.new(0, 520, 0, 430), BackgroundTransparency = isOpen and 1 or 0.2}):Play() end end)

    local floatPart = Instance.new("Part"); floatPart.Anchored = true; floatPart.Size = Vector3.new(10,1,10); floatPart.Transparency = 1
    
    -- // CORE LOOP
    RunService.RenderStepped:Connect(function()
        if _G.fullbrightActive then Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false end
        if _G.noclipActive and player.Character then for _, v in pairs(player.Character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end
        if _G.floatActive and player.Character then floatPart.Parent = Workspace; floatPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.5,0) else floatPart.Parent = nil end
        
        -- // KILL ALL BARTS LOGIC (TEAM CHECK)
        if _G.killBartsActive and getRoleInfo(player) == "HOMER" then
            for _, v in pairs(Players:GetPlayers()) do
                if v ~= player and v.Character and getRoleInfo(v) == "BART" and v.Character:FindFirstChild("HumanoidRootPart") then
                    player.Character.HumanoidRootPart.CFrame = v.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.5)
                end
            end
        end

        if _G.espActive then 
            for _, v in pairs(Players:GetPlayers()) do 
                if v ~= player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then 
                    local role, color = getRoleInfo(v) 
                    local h = v.Character:FindFirstChild("HHubESP") or Instance.new("Highlight", v.Character) 
                    h.Name = "HHubESP"; h.FillColor = color; h.DepthMode = "AlwaysOnTop" 
                    local head = v.Character:FindFirstChild("Head") 
                    if head and not v.Character:FindFirstChild("HHubTag") then 
                        local tag = Instance.new("BillboardGui", v.Character); tag.Name = "HHubTag"; tag.Size = UDim2.new(0, 200, 0, 50); tag.AlwaysOnTop = true; tag.Adornee = head; tag.ExtentsOffset = Vector3.new(0, 3, 0) 
                        local lbl = Instance.new("TextLabel", tag); lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1; lbl.Text = role .. " | " .. v.Name; lbl.TextColor3 = color; lbl.Font = "GothamBold"; lbl.TextSize = 16 
                    end 
                end 
            end 
        end
    end)
    
    -- // AUTOFARM LOOP
    task.spawn(function() 
        while true do 
            task.wait(7) 
            if _G.afkFarmActive and player.Character then 
                local w = Workspace:FindFirstChild("winpad", true) or Workspace:FindFirstChild("WinPart", true)
                if w then 
                    local old = player.Character.HumanoidRootPart.CFrame 
                    player.Character.HumanoidRootPart.CFrame = w.CFrame * CFrame.new(0, 4, 0) 
                    task.wait(0.2); player.Character.HumanoidRootPart.CFrame = old 
                end 
            end 
        end 
    end)
end

-- // VERIFICATION GATE
function StartVerification()
    local sg = Instance.new("ScreenGui", game.CoreGui); sg.Name = "HomerVerifyGui"
    local vMain = Instance.new("Frame", sg); vMain.Size = UDim2.new(0, 400, 0, 0); vMain.Position = UDim2.new(0.5, -200, 0.5, -125); vMain.BackgroundColor3 = Color3.fromRGB(15, 15, 15); vMain.BackgroundTransparency = 0.2; vMain.ClipsDescendants = true; Instance.new("UICorner", vMain).CornerRadius = UDim.new(0, 15)
    local title = Instance.new("TextLabel", vMain); title.Size = UDim2.new(1, 0, 0, 50); title.Position = UDim2.new(0, 0, 0, 10); title.Text = "STRICT VERIFICATION"; title.TextColor3 = Color3.new(1, 1, 0); title.Font = "GothamBold"; title.TextSize = 20; title.BackgroundTransparency = 1
    local desc = Instance.new("TextLabel", vMain); desc.Size = UDim2.new(1, -40, 0, 60); desc.Position = UDim2.new(0, 20, 0, 60); desc.Text = "Please follow derWolfderwutet. Verification checks your live followings list."; desc.TextColor3 = Color3.new(1,1,1); desc.Font = "Gotham"; desc.TextSize = 15; desc.TextWrapped = true; desc.BackgroundTransparency = 1
    local copyBtn = Instance.new("TextButton", vMain); copyBtn.Size = UDim2.new(0, 320, 0, 45); copyBtn.Position = UDim2.new(0.5, -160, 0, 130); copyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40); copyBtn.Text = "COPY PROFILE LINK"; copyBtn.TextColor3 = Color3.new(1,1,1); copyBtn.Font = "GothamBold"; copyBtn.TextSize = 17; Instance.new("UICorner", copyBtn)
    local verifyBtn = Instance.new("TextButton", vMain); verifyBtn.Size = UDim2.new(0, 320, 0, 45); verifyBtn.Position = UDim2.new(0.5, -160, 0, 185); verifyBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50); verifyBtn.Text = "VERIFY FOLLOW"; verifyBtn.TextColor3 = Color3.new(1,1,1); verifyBtn.Font = "GothamBold"; verifyBtn.TextSize = 17; Instance.new("UICorner", verifyBtn)

    copyBtn.MouseButton1Click:Connect(function() setclipboard(PROFILE_LINK) copyBtn.Text = "LINK COPIED!" task.wait(2) copyBtn.Text = "COPY PROFILE LINK" end)
    verifyBtn.MouseButton1Click:Connect(function()
        verifyBtn.Text = "CHECKING API..."; verifyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        local isFollowing = checkFollowStatus()
        task.wait(1.5)
        if isFollowing then
            verifyBtn.Text = "SUCCESS!"; verifyBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 100); task.wait(0.5)
            local t = TweenService:Create(vMain, T_INFO, {Size = UDim2.new(0, 400, 0, 0), BackgroundTransparency = 1})
            t:Play(); t.Completed:Connect(function() sg:Destroy() StartCheatMenu() end)
        else
            verifyBtn.Text = "NOT FOLLOWED!"; verifyBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            local op = vMain.Position; for i = 1, 8 do vMain.Position = op + UDim2.new(0, math.random(-6, 6), 0, 0) task.wait(0.04) end; vMain.Position = op
            task.wait(2); verifyBtn.Text = "VERIFY FOLLOW"; verifyBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        end
    end)
    TweenService:Create(vMain, T_INFO, {Size = UDim2.new(0, 400, 0, 250)}):Play()
end

StartVerification()
