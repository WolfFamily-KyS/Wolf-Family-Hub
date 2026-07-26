local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = true,
    ParryRange = 15,
    ParryDelay = 0.15,
    CooldownThreshold = 0.9,
    ShowCircle = true,
    ShowStatus = true,
}

local KillerAttackAnimations = {
    "132817836308238", "82666958311998", "129784271201071",
    "139369275981139", "110355011987939",
    "133963973694098", "117042998468241", "95934119190708", "129918027564423",
    "74968262036854", "113255068724446",
    "78432063483146", "77081789642514", "118907603246885", "80411309607666",
    "78935059863801", "122812055447896", "92098503722633", "84093948968516",
    "93136435416899", "86266790353635", "138045669415653", "137688077908355",
    "111920872708571", "105374834496520", "138720291317243", "130593238885843",
    "115244153053858", "106871536134254", "109402730355822", "117070354890871",
    "121216847022485", "135002183282873"
}

local State = {
    LastParryTime = 0,
    ParryCooldown = 2.5,
    IsParrying = false,
}

local Visuals = {
    Circle = nil,
    StatusLabel = nil,
}

local function CreateCircle()
    if Visuals.Circle then
        Visuals.Circle:Destroy()
    end
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local folder = Instance.new("Folder")
    folder.Name = "ParryCircle"
    folder.Parent = root
    
    local numSegments = 32
    local radius = Config.ParryRange
    local yOffset = -3.0
    
    for i = 1, numSegments do
        local angle1 = (i - 1) / numSegments * math.pi * 2
        local angle2 = i / numSegments * math.pi * 2
        
        local pos1 = Vector3.new(math.cos(angle1) * radius, yOffset, math.sin(angle1) * radius)
        local pos2 = Vector3.new(math.cos(angle2) * radius, yOffset, math.sin(angle2) * radius)
        
        local att1 = Instance.new("Attachment")
        att1.Position = pos1
        att1.Parent = root
        
        local att2 = Instance.new("Attachment")
        att2.Position = pos2
        att2.Parent = root
        
        local beam = Instance.new("Beam")
        beam.Attachment0 = att1
        beam.Attachment1 = att2
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        beam.Transparency = NumberSequence.new(0.5)
        beam.Width0 = 0.3
        beam.Width1 = 0.3
        beam.FaceCamera = true
        beam.Parent = folder
        
        att1.Parent = folder
        att2.Parent = folder
    end
    
    Visuals.Circle = folder
end

local function SetCircleColor(color)
    if not Visuals.Circle then return end
    
    for _, obj in pairs(Visuals.Circle:GetChildren()) do
        if obj:IsA("Beam") then
            obj.Color = ColorSequence.new(color)
        end
    end
end

local function CreateStatusLabel()
    if Visuals.StatusLabel then
        Visuals.StatusLabel:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoParryStatus"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 80)
    frame.Position = UDim2.new(1, -210, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "AUTO PARRY"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = frame
    
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -10, 0, 20)
    status.Position = UDim2.new(0, 5, 0, 30)
    status.BackgroundTransparency = 1
    status.Text = "Ready"
    status.TextColor3 = Color3.fromRGB(0, 255, 0)
    status.TextSize = 14
    status.Font = Enum.Font.Gotham
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame
    
    local cooldown = Instance.new("TextLabel")
    cooldown.Name = "Cooldown"
    cooldown.Size = UDim2.new(1, -10, 0, 20)
    cooldown.Position = UDim2.new(0, 5, 0, 52)
    cooldown.BackgroundTransparency = 1
    cooldown.Text = "Cooldown: 0.0s"
    cooldown.TextColor3 = Color3.fromRGB(200, 200, 200)
    cooldown.TextSize = 12
    cooldown.Font = Enum.Font.Gotham
    cooldown.TextXAlignment = Enum.TextXAlignment.Left
    cooldown.Parent = frame
    
    Visuals.StatusLabel = screenGui
end

local function UpdateStatus(text, color)
    if not Config.ShowStatus or not Visuals.StatusLabel then return end
    
    local status = Visuals.StatusLabel:FindFirstChild("Frame"):FindFirstChild("Status")
    if status then
        status.Text = text
        status.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    end
end

local function UpdateCooldown(remaining)
    if not Config.ShowStatus or not Visuals.StatusLabel then return end
    
    local cooldown = Visuals.StatusLabel:FindFirstChild("Frame"):FindFirstChild("Cooldown")
    if cooldown then
        if remaining > 0 then
            cooldown.Text = string.format("Cooldown: %.1fs", remaining)
        else
            cooldown.Text = "Cooldown: Ready"
        end
    end
end

local function GetNearestKiller()
    local char = LocalPlayer.Character
    if not char then return nil, math.huge end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, math.huge end
    
    local nearestKiller = nil
    local nearestDistance = math.huge
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team and player.Team.Name == "Killer" then
            local killerChar = player.Character
            if killerChar then
                local killerRoot = killerChar:FindFirstChild("HumanoidRootPart")
                if killerRoot then
                    local distance = (killerRoot.Position - root.Position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestKiller = killerChar
                    end
                end
            end
        end
    end
    
    return nearestKiller, nearestDistance
end

local function IsKillerAttacking(killerChar)
    if not killerChar then return false end
    
    local humanoid = killerChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    
    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation.AnimationId
        local id = animId:match("%d+")
        
        if id then
            for _, attackId in pairs(KillerAttackAnimations) do
                if id == attackId then
                    return true
                end
            end
        end
    end
    
    return false
end

local function GetParryButton()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then 
        warn("[Auto Parry] PlayerGui not found")
        return nil 
    end
    
    local survivorGui = gui:FindFirstChild("Survivor-mob")
    if not survivorGui then 
        warn("[Auto Parry] Survivor-mob not found")
        return nil 
    end
    
    local controls = survivorGui:FindFirstChild("Controls")
    if not controls then 
        warn("[Auto Parry] Controls not found")
        return nil 
    end
    
    local guiMob = controls:FindFirstChild("Gui-mob")
    if not guiMob then 
        warn("[Auto Parry] Gui-mob not found")
        return nil 
    end
    
    local icon = guiMob:FindFirstChild("icon")
    if not icon then
        warn("[Auto Parry] icon not found")
        return nil
    end
    
    return icon
end

local function DebugButton()
    local button = GetParryButton()
    if not button then
        print("[Debug] Button not found!")
        return
    end
    
    print("=================================")
    print("[Debug] Button Info:")
    print("  Name:", button.Name)
    print("  ClassName:", button.ClassName)
    print("  AbsolutePosition:", button.AbsolutePosition)
    print("  AbsoluteSize:", button.AbsoluteSize)
    print("  Visible:", button.Visible)
    print("  Active:", button.Active)
    
    print("\n[Debug] Children:")
    for _, child in pairs(button:GetChildren()) do
        print("  -", child.Name, "(" .. child.ClassName .. ")")
        if child.Name == "Bar" then
            print("    Bar.Size:", child.Size)
        end
    end
    
    print("\n[Debug] Connections:")
    local hasConnections = false
    for event, _ in pairs({
        MouseButton1Click = true,
        MouseButton1Down = true,
        Activated = true,
        TouchTap = true,
        TouchLongPress = true
    }) do
        local success, connections = pcall(function()
            return getconnections(button[event])
        end)
        if success and connections and #connections > 0 then
            print("  " .. event .. ":", #connections, "connections")
            hasConnections = true
        end
    end
    
    if not hasConnections then
        print("  No connections found (may need different method)")
    end
    
    print("=================================")
end

local function IsParryReady()
    local button = GetParryButton()
    if not button then return false end
    
    local bar = button:FindFirstChild("Bar")
    if not bar then return true end
    
    return bar.Size.X.Scale >= Config.CooldownThreshold
end

local function TriggerParry()
    local button = GetParryButton()
    if not button then
        warn("[Auto Parry] Button not found")
        return false
    end
    
    local success = false
    
    -- Method 1: Fire button connections directly (Most reliable)
    pcall(function()
        for _, connection in pairs(getconnections(button.MouseButton1Click)) do
            connection:Fire()
            success = true
        end
        for _, connection in pairs(getconnections(button.MouseButton1Down)) do
            connection:Fire()
            success = true
        end
        for _, connection in pairs(getconnections(button.Activated)) do
            connection:Fire()
            success = true
        end
        
        if success then
            print("[Auto Parry] Method 1: Button connections fired")
        end
    end)
    
    -- Method 2: VirtualInputManager Touch (Mobile - CORRECT FORMAT)
    pcall(function()
        local p = button.AbsolutePosition
        local s = button.AbsoluteSize
        local GuiService = game:GetService("GuiService")
        local i = GuiService:GetGuiInset()
        
        -- Calculate center of button
        local cx = p.X + (s.X / 2) + i.X
        local cy = p.Y + (s.Y / 2) + i.Y
        
        local touchID = 8823
        
        -- Touch start (parameter: ID, state, x, y)
        VirtualInputManager:SendTouchEvent(touchID, 0, cx, cy)
        print(string.format("[Auto Parry] Touch START sent (%.1f, %.1f)", cx, cy))
        
        task.wait(0.05)
        
        -- Touch end (state 2)
        VirtualInputManager:SendTouchEvent(touchID, 2, cx, cy)
        print("[Auto Parry] Touch END sent")
        
        success = true
    end)
    
    if success then
        State.LastParryTime = tick()
        State.IsParrying = true
        
        task.spawn(function()
            task.wait(0.5)
            State.IsParrying = false
        end)
    else
        warn("[Auto Parry] All trigger methods failed!")
    end
    
    return success
end

local function AutoParryLoop()
    if not Config.Enabled then
        SetCircleColor(Color3.fromRGB(100, 100, 100))
        UpdateStatus("Disabled", Color3.fromRGB(150, 150, 150))
        return
    end
    
    local timeSinceLastParry = tick() - State.LastParryTime
    local cooldownRemaining = math.max(0, State.ParryCooldown - timeSinceLastParry)
    UpdateCooldown(cooldownRemaining)
    
    local killer, distance = GetNearestKiller()
    
    if not killer then
        SetCircleColor(Color3.fromRGB(255, 0, 0))
        UpdateStatus("No Killer", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if distance > Config.ParryRange then
        SetCircleColor(Color3.fromRGB(255, 0, 0))
        UpdateStatus(string.format("Out of Range (%.1f)", distance), Color3.fromRGB(255, 150, 0))
        return
    end
    
    SetCircleColor(Color3.fromRGB(0, 255, 0))
    
    local isAttacking = IsKillerAttacking(killer)
    
    if isAttacking then
        SetCircleColor(Color3.fromRGB(255, 255, 0))
        
        print(string.format("[Auto Parry] Attack detected! Distance: %.1f studs", distance))
        
        if not IsParryReady() then
            UpdateStatus("Cooldown...", Color3.fromRGB(255, 200, 0))
            print("[Auto Parry] Parry not ready (cooldown)")
            return
        end
        
        if State.IsParrying then
            print("[Auto Parry] Already parrying, skipping")
            return
        end
        
        if timeSinceLastParry < 1.0 then
            print("[Auto Parry] Too soon after last parry, skipping")
            return
        end
        
        UpdateStatus("Attack Detected!", Color3.fromRGB(255, 255, 0))
        
        print(string.format("[Auto Parry] Waiting %.0fms delay...", Config.ParryDelay * 1000))
        task.wait(Config.ParryDelay)
        
        print("[Auto Parry] Executing parry trigger...")
        local success = TriggerParry()
        if success then
            UpdateStatus("PARRYING!", Color3.fromRGB(0, 255, 255))
            print(string.format("[Auto Parry] ✅ Parry executed! Distance: %.1f studs", distance))
        else
            UpdateStatus("Failed to Parry", Color3.fromRGB(255, 0, 0))
            print("[Auto Parry] ❌ Failed to execute parry")
        end
    else
        UpdateStatus(string.format("In Range (%.1f) - Ready", distance), Color3.fromRGB(0, 255, 0))
    end
end

local function Initialize()
    print("=================================")
    print("   AUTO PARRY - Stand Alone")
    print("=================================")
    print("[Config] Range:", Config.ParryRange, "studs")
    print("[Config] Delay:", Config.ParryDelay * 1000, "ms")
    print("[Config] Circle:", Config.ShowCircle)
    print("[Config] Status:", Config.ShowStatus)
    print("=================================")
    
    task.wait(2)
    
    -- Debug button info
    print("\n[Auto Parry] Inspecting parry button...")
    DebugButton()
    
    if Config.ShowCircle then
        CreateCircle()
    end
    
    if Config.ShowStatus then
        CreateStatusLabel()
    end
    
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if Config.ShowCircle then
            CreateCircle()
        end
        DebugButton()
    end)
    
    RunService.Heartbeat:Connect(function()
        pcall(AutoParryLoop)
    end)
    
    print("[Auto Parry] Initialized successfully!")
    print("[Auto Parry] Check console for debug info when parry triggers")
end

Initialize()
