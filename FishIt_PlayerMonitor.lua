-- Fish It Player Monitor with Discord Webhook
-- Enhanced Version with ACCURATE Fishing Detection
-- FIXED: Proper fishing detection for Fish It game
-- Compatible with Delta Executor

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables
local LocalPlayer = Players.LocalPlayer
local webhookURL = ""
local monitoringEnabled = false
local notificationInterval = 300
local lastNotificationTime = 0
local isMinimized = false

-- Fishing Detection Variables
local playerFishCounts = {} -- Track fish count per player
local playerFishingStatus = {} -- Track if player is actively fishing
local FISHING_CHECK_INTERVAL = 3 -- Check every 3 seconds

-- Responsive Design Variables
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local baseSize = isMobile and 0.85 or 1

-- Function to get player's fish count from inventory - IMPROVED VERSION
local function getPlayerFishCount(player)
    local totalFish = 0
    
    local success, result = pcall(function()
        -- Method 1: Check for FishIt leaderstats (most common)
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            -- Try different possible fish stat names
            local fishStat = leaderstats:FindFirstChild("Fish") 
                or leaderstats:FindFirstChild("TotalFish") 
                or leaderstats:FindFirstChild("FishCaught")
                or leaderstats:FindFirstChild("🐟")
            
            if fishStat and (fishStat:IsA("IntValue") or fishStat:IsA("NumberValue")) then
                print("[DEBUG] " .. player.Name .. " fish from leaderstats: " .. fishStat.Value)
                return fishStat.Value
            end
        end
        
        -- Method 2: Check PlayerData folder
        local playerData = player:FindFirstChild("Data") or player:FindFirstChild("PlayerData")
        if playerData then
            local fishValue = playerData:FindFirstChild("Fish") 
                or playerData:FindFirstChild("TotalFish")
                or playerData:FindFirstChild("FishCaught")
            
            if fishValue and (fishValue:IsA("IntValue") or fishValue:IsA("NumberValue")) then
                print("[DEBUG] " .. player.Name .. " fish from PlayerData: " .. fishValue.Value)
                return fishValue.Value
            end
        end
        
        -- Method 3: Check PlayerGui for UI elements
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            -- Search through all GUIs for fish count displays
            for _, gui in pairs(playerGui:GetChildren()) do
                for _, descendant in pairs(gui:GetDescendants()) do
                    if descendant:IsA("TextLabel") or descendant:IsA("TextBox") then
                        local text = descendant.Text
                        -- Look for patterns like "Fish: 15", "15 Fish", "🐟 15"
                        local fishNum = tonumber(text:match("(%d+)%s*[Ff]ish")) 
                            or tonumber(text:match("[Ff]ish%s*:?%s*(%d+)"))
                            or tonumber(text:match("🐟%s*:?%s*(%d+)"))
                            or tonumber(text:match("(%d+)%s*🐟"))
                        
                        if fishNum and fishNum > 0 then
                            print("[DEBUG] " .. player.Name .. " fish from GUI: " .. fishNum)
                            return fishNum
                        end
                    end
                end
            end
        end
        
        -- Method 4: Check Character for fishing rod or animation
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                -- Check if player is holding a fishing rod
                for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
                    if track.Animation and track.Animation.AnimationId then
                        local animId = track.Animation.AnimationId:lower()
                        if animId:find("fish") or animId:find("cast") or animId:find("reel") then
                            print("[DEBUG] " .. player.Name .. " has fishing animation active!")
                            -- Return special flag to indicate active fishing
                            return -1 -- Special value for active animation
                        end
                    end
                end
            end
        end
        
        return 0
    end)
    
    if success then
        return result or totalFish
    else
        return totalFish
    end
end

-- Function to check if player is actively fishing (holding rod, in water, etc)
local function isPlayerActivelyFishing(player)
    local success, result = pcall(function()
        local character = player.Character
        if not character then return false end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then return false end
        
        -- Check 1: Is player holding a fishing rod tool?
        local tool = character:FindFirstChildOfClass("Tool")
        if tool then
            local toolName = tool.Name:lower()
            if toolName:find("rod") or toolName:find("fish") or toolName:find("pole") then
                print("[DEBUG] " .. player.Name .. " is holding fishing rod: " .. tool.Name)
                return true
            end
        end
        
        -- Check 2: Check backpack for equipped rod
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    local itemName = item.Name:lower()
                    if itemName:find("rod") or itemName:find("fish") or itemName:find("pole") then
                        -- Rod in backpack but check if recently used
                        local lastUsed = item:GetAttribute("LastUsed")
                        if lastUsed and (tick() - lastUsed) < 10 then
                            return true
                        end
                    end
                end
            end
        end
        
        -- Check 3: Animation check
        for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
            if track.Animation and track.Animation.AnimationId then
                local animId = track.Animation.AnimationId:lower()
                if animId:find("fish") or animId:find("cast") or animId:find("reel") or animId:find("rod") then
                    print("[DEBUG] " .. player.Name .. " has fishing animation playing")
                    return true
                end
            end
        end
        
        -- Check 4: Look for fishing-related parts attached to character
        for _, child in pairs(character:GetDescendants()) do
            if child:IsA("BasePart") then
                local partName = child.Name:lower()
                if partName:find("rod") or partName:find("line") or partName:find("bobber") or partName:find("float") then
                    print("[DEBUG] " .. player.Name .. " has fishing part attached: " .. child.Name)
                    return true
                end
            end
        end
        
        return false
    end)
    
    return success and result or false
end

-- Function to update fishing status for a player
local function updateFishingStatus(player)
    local currentFishCount = getPlayerFishCount(player)
    local previousFishCount = playerFishCounts[player.UserId] or 0
    local isActivelyFishing = isPlayerActivelyFishing(player)
    
    -- Special case: -1 means active animation detected
    if currentFishCount == -1 then
        isActivelyFishing = true
        currentFishCount = previousFishCount -- Keep previous count
    end
    
    -- Primary detection: Check if actively using fishing rod
    if isActivelyFishing then
        print("[FISHING] " .. player.Name .. " is ACTIVELY FISHING (rod/animation detected)")
        playerFishingStatus[player.UserId] = {
            isFishing = true,
            lastUpdate = tick(),
            fishCount = currentFishCount,
            fishGained = 0
        }
    -- Secondary detection: Fish count increased
    elseif currentFishCount > previousFishCount then
        print("[FISHING] " .. player.Name .. " caught fish! " .. previousFishCount .. " -> " .. currentFishCount)
        playerFishingStatus[player.UserId] = {
            isFishing = true,
            lastUpdate = tick(),
            fishCount = currentFishCount,
            fishGained = currentFishCount - previousFishCount
        }
    else
        -- Check if last activity was recent (within 15 seconds)
        local status = playerFishingStatus[player.UserId]
        if status and (tick() - status.lastUpdate) < 15 then
            -- Still consider them fishing if recently active
            status.isFishing = true
            status.fishCount = currentFishCount
        elseif status then
            -- Mark as NOT fishing (IDLE)
            if status.isFishing then
                print("[IDLE] " .. player.Name .. " is now IDLE (stopped fishing)")
            end
            status.isFishing = false
            status.fishCount = currentFishCount
        else
            playerFishingStatus[player.UserId] = {
                isFishing = false,
                lastUpdate = tick(),
                fishCount = currentFishCount,
                fishGained = 0
            }
        end
    end
    
    playerFishCounts[player.UserId] = currentFishCount
end

-- Function to check if player is fishing
local function isPlayerFishing(player)
    local status = playerFishingStatus[player.UserId]
    if status then
        return status.isFishing, status.fishCount or 0
    end
    return false, 0
end

-- Animation Functions
local function tweenSize(object, targetSize, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = targetSize
    })
    tween:Play()
    return tween
end

local function tweenPosition(object, targetPosition, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = targetPosition
    })
    tween:Play()
    return tween
end

local function tweenTransparency(object, targetTransparency, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad), {
        BackgroundTransparency = targetTransparency
    })
    tween:Play()
    return tween
end

-- GUI Creation
local function createGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FishItMonitorGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.IgnoreGuiInset = true
    
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = CoreGui
    else
        ScreenGui.Parent = CoreGui
    end
    
    -- Calculate responsive sizes
    local screenSize = workspace.CurrentCamera.ViewportSize
    local guiWidth = math.min(450 * baseSize, screenSize.X * 0.9)
    local guiHeight = math.min(580 * baseSize, screenSize.Y * 0.85)
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5, -guiWidth/2, 0.5, -guiHeight/2)
    MainFrame.Size = UDim2.new(0, guiWidth, 0, guiHeight)
    MainFrame.Parent = ScreenGui
    MainFrame.ClipsDescendants = true
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 12)
    UICorner.Parent = MainFrame
    
    -- Shadow effect
    local Shadow = Instance.new("ImageLabel")
    Shadow.Name = "Shadow"
    Shadow.BackgroundTransparency = 1
    Shadow.Position = UDim2.new(0, -15, 0, -15)
    Shadow.Size = UDim2.new(1, 30, 1, 30)
    Shadow.ZIndex = 0
    Shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.ImageTransparency = 0.7
    Shadow.ScaleType = Enum.ScaleType.Slice
    Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    Shadow.Parent = MainFrame
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    TitleBar.BorderSizePixel = 0
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    -- Title Text
    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.BackgroundTransparency = 1
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.Size = UDim2.new(0.6, 0, 1, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "🐟 Fish It Monitor"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = isMobile and 16 or 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextScaled = isMobile
    Title.Parent = TitleBar
    
    -- Minimize Button
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Name = "MinimizeButton"
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(100, 140, 200)
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Position = UDim2.new(1, -80, 0, 10)
    MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
    MinimizeButton.Font = Enum.Font.GothamBold
    MinimizeButton.Text = "−"
    MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeButton.TextSize = 20
    MinimizeButton.Parent = TitleBar
    
    local MinimizeCorner = Instance.new("UICorner")
    MinimizeCorner.CornerRadius = UDim.new(0, 6)
    MinimizeCorner.Parent = MinimizeButton
    
    -- Close Button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    CloseButton.BorderSizePixel = 0
    CloseButton.Position = UDim2.new(1, -40, 0, 10)
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    CloseButton.Parent = TitleBar
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton
    
    -- Content Frame (everything below title bar)
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Position = UDim2.new(0, 0, 0, 50)
    ContentFrame.Size = UDim2.new(1, 0, 1, -50)
    ContentFrame.Parent = MainFrame
    
    -- Webhook URL Section
    local WebhookLabel = Instance.new("TextLabel")
    WebhookLabel.Name = "WebhookLabel"
    WebhookLabel.BackgroundTransparency = 1
    WebhookLabel.Position = UDim2.new(0, 20, 0, 15)
    WebhookLabel.Size = UDim2.new(0, 200, 0, 25)
    WebhookLabel.Font = Enum.Font.GothamSemibold
    WebhookLabel.Text = "Discord Webhook URL:"
    WebhookLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    WebhookLabel.TextSize = isMobile and 12 or 14
    WebhookLabel.TextXAlignment = Enum.TextXAlignment.Left
    WebhookLabel.Parent = ContentFrame
    
    local WebhookInput = Instance.new("TextBox")
    WebhookInput.Name = "WebhookInput"
    WebhookInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    WebhookInput.BorderSizePixel = 0
    WebhookInput.Position = UDim2.new(0, 20, 0, 45)
    WebhookInput.Size = UDim2.new(1, -40, 0, 35)
    WebhookInput.Font = Enum.Font.Gotham
    WebhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
    WebhookInput.Text = ""
    WebhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookInput.TextSize = isMobile and 10 or 12
    WebhookInput.TextXAlignment = Enum.TextXAlignment.Left
    WebhookInput.ClearTextOnFocus = false
    WebhookInput.Parent = ContentFrame
    
    local WebhookCorner = Instance.new("UICorner")
    WebhookCorner.CornerRadius = UDim.new(0, 6)
    WebhookCorner.Parent = WebhookInput
    
    local WebhookPadding = Instance.new("UIPadding")
    WebhookPadding.PaddingLeft = UDim.new(0, 10)
    WebhookPadding.Parent = WebhookInput
    
    -- Interval Section
    local IntervalLabel = Instance.new("TextLabel")
    IntervalLabel.Name = "IntervalLabel"
    IntervalLabel.BackgroundTransparency = 1
    IntervalLabel.Position = UDim2.new(0, 20, 0, 95)
    IntervalLabel.Size = UDim2.new(0, 200, 0, 25)
    IntervalLabel.Font = Enum.Font.GothamSemibold
    IntervalLabel.Text = "Interval (minutes):"
    IntervalLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    IntervalLabel.TextSize = isMobile and 12 or 14
    IntervalLabel.TextXAlignment = Enum.TextXAlignment.Left
    IntervalLabel.Parent = ContentFrame
    
    local IntervalInput = Instance.new("TextBox")
    IntervalInput.Name = "IntervalInput"
    IntervalInput.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    IntervalInput.BorderSizePixel = 0
    IntervalInput.Position = UDim2.new(0, 20, 0, 125)
    IntervalInput.Size = UDim2.new(1, -40, 0, 35)
    IntervalInput.Font = Enum.Font.Gotham
    IntervalInput.PlaceholderText = "Enter minutes (e.g., 5)"
    IntervalInput.Text = "5"
    IntervalInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    IntervalInput.TextSize = 14
    IntervalInput.TextXAlignment = Enum.TextXAlignment.Center
    IntervalInput.Parent = ContentFrame
    
    local IntervalCorner = Instance.new("UICorner")
    IntervalCorner.CornerRadius = UDim.new(0, 6)
    IntervalCorner.Parent = IntervalInput
    
    -- Player List Section with Scrolling Frame
    local PlayerListLabel = Instance.new("TextLabel")
    PlayerListLabel.Name = "PlayerListLabel"
    PlayerListLabel.BackgroundTransparency = 1
    PlayerListLabel.Position = UDim2.new(0, 20, 0, 175)
    PlayerListLabel.Size = UDim2.new(0, 200, 0, 25)
    PlayerListLabel.Font = Enum.Font.GothamSemibold
    PlayerListLabel.Text = "👥 Players Online:"
    PlayerListLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    PlayerListLabel.TextSize = isMobile and 12 or 14
    PlayerListLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayerListLabel.Parent = ContentFrame
    
    -- ScrollingFrame for player list
    local PlayerListFrame = Instance.new("ScrollingFrame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    PlayerListFrame.BorderSizePixel = 0
    PlayerListFrame.Position = UDim2.new(0, 20, 0, 205)
    PlayerListFrame.Size = UDim2.new(1, -40, 0, 150)
    PlayerListFrame.ScrollBarThickness = 6
    PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
    PlayerListFrame.Parent = ContentFrame
    
    local PlayerListCorner = Instance.new("UICorner")
    PlayerListCorner.CornerRadius = UDim.new(0, 6)
    PlayerListCorner.Parent = PlayerListFrame
    
    local PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Name = "PlayerListLayout"
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.Padding = UDim.new(0, 5)
    PlayerListLayout.Parent = PlayerListFrame
    
    local PlayerListPadding = Instance.new("UIPadding")
    PlayerListPadding.PaddingTop = UDim.new(0, 8)
    PlayerListPadding.PaddingBottom = UDim.new(0, 8)
    PlayerListPadding.PaddingLeft = UDim.new(0, 10)
    PlayerListPadding.PaddingRight = UDim.new(0, 10)
    PlayerListPadding.Parent = PlayerListFrame
    
    -- Player Count Display
    local PlayerCountDisplay = Instance.new("TextLabel")
    PlayerCountDisplay.Name = "PlayerCountDisplay"
    PlayerCountDisplay.BackgroundTransparency = 1
    PlayerCountDisplay.Position = UDim2.new(0, 240, 0, 175)
    PlayerCountDisplay.Size = UDim2.new(0, 150, 0, 25)
    PlayerCountDisplay.Font = Enum.Font.GothamSemibold
    PlayerCountDisplay.Text = "0/0"
    PlayerCountDisplay.TextColor3 = Color3.fromRGB(100, 200, 255)
    PlayerCountDisplay.TextSize = 14
    PlayerCountDisplay.TextXAlignment = Enum.TextXAlignment.Right
    PlayerCountDisplay.Parent = ContentFrame
    
    -- Test Button
    local TestButton = Instance.new("TextButton")
    TestButton.Name = "TestButton"
    TestButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
    TestButton.BorderSizePixel = 0
    TestButton.Position = UDim2.new(0, 20, 0, 370)
    TestButton.Size = UDim2.new(0.48, -15, 0, 45)
    TestButton.Font = Enum.Font.GothamBold
    TestButton.Text = "🔔 TEST"
    TestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TestButton.TextSize = isMobile and 14 or 16
    TestButton.Parent = ContentFrame
    
    local TestCorner = Instance.new("UICorner")
    TestCorner.CornerRadius = UDim.new(0, 8)
    TestCorner.Parent = TestButton
    
    -- Toggle Button (Start/Stop)
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Position = UDim2.new(0.52, 5, 0, 370)
    ToggleButton.Size = UDim2.new(0.48, -15, 0, 45)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.Text = "▶ START"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = isMobile and 14 or 16
    ToggleButton.Parent = ContentFrame
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 8)
    ToggleCorner.Parent = ToggleButton
    
    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, 430)
    StatusLabel.Size = UDim2.new(1, -40, 0, 30)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "⏸ Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    StatusLabel.TextSize = isMobile and 11 or 12
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    StatusLabel.Parent = ContentFrame
    
    -- Minimized Icon
    local MinimizedIcon = Instance.new("ImageButton")
    MinimizedIcon.Name = "MinimizedIcon"
    MinimizedIcon.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    MinimizedIcon.BorderSizePixel = 0
    MinimizedIcon.Position = UDim2.new(1, -80, 1, -80)
    MinimizedIcon.Size = UDim2.new(0, 60, 0, 60)
    MinimizedIcon.Image = ""
    MinimizedIcon.Visible = false
    MinimizedIcon.Parent = ScreenGui
    
    local MinIconCorner = Instance.new("UICorner")
    MinIconCorner.CornerRadius = UDim.new(1, 0)
    MinIconCorner.Parent = MinimizedIcon
    
    local MinIconLabel = Instance.new("TextLabel")
    MinIconLabel.BackgroundTransparency = 1
    MinIconLabel.Size = UDim2.new(1, 0, 1, 0)
    MinIconLabel.Font = Enum.Font.GothamBold
    MinIconLabel.Text = "🐟"
    MinIconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinIconLabel.TextSize = 28
    MinIconLabel.Parent = MinimizedIcon
    
    -- Make title bar draggable
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Return GUI elements for easy access
    return {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        Shadow = Shadow,
        WebhookInput = WebhookInput,
        IntervalInput = IntervalInput,
        PlayerListFrame = PlayerListFrame,
        PlayerListLayout = PlayerListLayout,
        PlayerCountDisplay = PlayerCountDisplay,
        TestButton = TestButton,
        ToggleButton = ToggleButton,
        StatusLabel = StatusLabel,
        MinimizeButton = MinimizeButton,
        CloseButton = CloseButton,
        MinimizedIcon = MinimizedIcon
    }
end

-- Update player list display with fishing status
local function updatePlayerListDisplay(gui)
    -- Clear existing player entries
    for _, child in pairs(gui.PlayerListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local players = Players:GetPlayers()
    local playerCount = #players
    local fishingCount = 0
    
    -- Update player count
    gui.PlayerCountDisplay.Text = playerCount .. "/" .. Players.MaxPlayers
    
    -- Add player entries
    for i, player in ipairs(players) do
        -- Update fishing status before displaying
        updateFishingStatus(player)
        local isFishing, fishCount = isPlayerFishing(player)
        
        if isFishing then
            fishingCount = fishingCount + 1
        end
        
        local PlayerEntry = Instance.new("Frame")
        PlayerEntry.Name = "Player_" .. player.Name
        -- HIJAU untuk yang MANCING, ABU-ABU untuk yang IDLE
        PlayerEntry.BackgroundColor3 = isFishing and Color3.fromRGB(35, 65, 35) or Color3.fromRGB(45, 45, 60)
        PlayerEntry.BorderSizePixel = 0
        PlayerEntry.Size = UDim2.new(1, 0, 0, 35)
        PlayerEntry.Parent = gui.PlayerListFrame
        
        local EntryCorner = Instance.new("UICorner")
        EntryCorner.CornerRadius = UDim.new(0, 4)
        EntryCorner.Parent = PlayerEntry
        
        -- 🎣 untuk yang MANCING, 💤 untuk yang IDLE
        local FishingIndicator = Instance.new("TextLabel")
        FishingIndicator.BackgroundTransparency = 1
        FishingIndicator.Position = UDim2.new(0, 5, 0, 0)
        FishingIndicator.Size = UDim2.new(0, 20, 1, 0)
        FishingIndicator.Font = Enum.Font.GothamBold
        FishingIndicator.Text = isFishing and "🎣" or "💤"
        FishingIndicator.TextColor3 = isFishing and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150, 150, 150)
        FishingIndicator.TextSize = 16
        FishingIndicator.Parent = PlayerEntry
        
        -- Player name
        local PlayerName = Instance.new("TextLabel")
        PlayerName.BackgroundTransparency = 1
        PlayerName.Position = UDim2.new(0, 30, 0, 0)
        PlayerName.Size = UDim2.new(0.5, -30, 1, 0)
        PlayerName.Font = Enum.Font.Gotham
        PlayerName.Text = player.Name
        PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
        PlayerName.TextSize = isMobile and 11 or 12
        PlayerName.TextXAlignment = Enum.TextXAlignment.Left
        PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
        PlayerName.Parent = PlayerEntry
        
        -- Fish count
        local FishCount = Instance.new("TextLabel")
        FishCount.BackgroundTransparency = 1
        FishCount.Position = UDim2.new(0.5, 0, 0, 0)
        FishCount.Size = UDim2.new(0.5, -5, 1, 0)
        FishCount.Font = Enum.Font.GothamSemibold
        FishCount.Text = "🐟 " .. fishCount
        FishCount.TextColor3 = isFishing and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(150, 200, 255)
        FishCount.TextSize = isMobile and 10 or 11
        FishCount.TextXAlignment = Enum.TextXAlignment.Right
        FishCount.Parent = PlayerEntry
    end
    
    -- Update canvas size for scrolling
    gui.PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, gui.PlayerListLayout.AbsoluteContentSize.Y + 16)
    
    -- Update status to show fishing count
    if monitoringEnabled then
        gui.StatusLabel.Text = "✅ Active - " .. fishingCount .. "/" .. playerCount .. " fishing"
    end
end

-- Function to send webhook
local function sendWebhook(url, isTest)
    local players = Players:GetPlayers()
    local playerList = {}
    local fishingPlayers = {}
    local idlePlayers = {}
    
    for _, player in ipairs(players) do
        updateFishingStatus(player)
        local isFishing, fishCount = isPlayerFishing(player)
        
        local playerData = {
            name = player.Name,
            displayName = player.DisplayName,
            userId = player.UserId,
            isFishing = isFishing,
            fishCount = fishCount
        }
        
        table.insert(playerList, playerData)
        
        if isFishing then
            table.insert(fishingPlayers, playerData)
        else
            table.insert(idlePlayers, playerData)
        end
    end
    
    local embed = {
        ["title"] = isTest and "🧪 Test Webhook" or "📊 Player Update",
        ["description"] = isTest and "This is a test notification from Fish It Monitor!" or "Current players and fishing status:",
        ["color"] = isTest and 3447003 or 5814783,
        ["fields"] = {
            {
                ["name"] = "👥 Player Count",
                ["value"] = #players .. "/" .. Players.MaxPlayers,
                ["inline"] = true
            },
            {
                ["name"] = "🎣 Fishing",
                ["value"] = #fishingPlayers .. " active",
                ["inline"] = true
            },
            {
                ["name"] = "💤 Idle",
                ["value"] = #idlePlayers .. " idle",
                ["inline"] = true
            }
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
    }
    
    -- Add fishing players list
    if #fishingPlayers > 0 then
        local fishingList = {}
        for i, player in ipairs(fishingPlayers) do
            table.insert(fishingList, "🎣 " .. player.name .. " - " .. player.fishCount .. " fish")
        end
        table.insert(embed.fields, {
            ["name"] = "🟢 Active Fishers",
            ["value"] = table.concat(fishingList, "\n"),
            ["inline"] = false
        })
    end
    
    -- Add idle players list
    if #idlePlayers > 0 then
        local idleList = {}
        for i, player in ipairs(idlePlayers) do
            table.insert(idleList, "💤 " .. player.name .. " - " .. player.fishCount .. " fish")
        end
        table.insert(embed.fields, {
            ["name"] = "⚪ Idle Players",
            ["value"] = table.concat(idleList, "\n"),
            ["inline"] = false
        })
    end
    
    local data = {
        ["username"] = "Fish It Monitor",
        ["avatar_url"] = "https://tr.rbxcdn.com/cb7e5adc9cac8bcd85e6a3eaeff4b42e/150/150/Image/Png",
        ["embeds"] = {embed}
    }
    
    local success, response = pcall(function()
        return request({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    return success, response
end

-- Function to show notification
local function showNotification(title, text, duration)
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = duration or 5,
    })
end

-- Minimize/Maximize Functions
local function minimizeGUI(gui)
    isMinimized = true
    
    tweenSize(gui.MainFrame, UDim2.new(0, 0, 0, 0), 0.3)
    tweenTransparency(gui.Shadow, 1, 0.2)
    
    wait(0.3)
    gui.MainFrame.Visible = false
    
    gui.MinimizedIcon.Visible = true
    gui.MinimizedIcon.Size = UDim2.new(0, 0, 0, 0)
    tweenSize(gui.MinimizedIcon, UDim2.new(0, 60, 0, 60), 0.3)
    
    showNotification("📦 Minimized", "Click the icon to restore", 3)
end

local function maximizeGUI(gui)
    isMinimized = false
    
    tweenSize(gui.MinimizedIcon, UDim2.new(0, 0, 0, 0), 0.3)
    
    wait(0.3)
    gui.MinimizedIcon.Visible = false
    
    gui.MainFrame.Visible = true
    local screenSize = workspace.CurrentCamera.ViewportSize
    local guiWidth = math.min(450 * baseSize, screenSize.X * 0.9)
    local guiHeight = math.min(580 * baseSize, screenSize.Y * 0.85)
    
    gui.MainFrame.Size = UDim2.new(0, 0, 0, 0)
    tweenSize(gui.MainFrame, UDim2.new(0, guiWidth, 0, guiHeight), 0.3)
    tweenTransparency(gui.Shadow, 0.7, 0.2)
end

-- Main execution
local gui = createGUI()

-- Minimize button functionality
gui.MinimizeButton.MouseButton1Click:Connect(function()
    minimizeGUI(gui)
end)

-- Minimized icon click to restore
gui.MinimizedIcon.MouseButton1Click:Connect(function()
    maximizeGUI(gui)
end)

-- Close button functionality
gui.CloseButton.MouseButton1Click:Connect(function()
    tweenSize(gui.MainFrame, UDim2.new(0, 0, 0, 0), 0.3)
    wait(0.3)
    gui.ScreenGui:Destroy()
    monitoringEnabled = false
end)

-- Test webhook button
gui.TestButton.MouseButton1Click:Connect(function()
    local url = gui.WebhookInput.Text
    
    if url == "" or not url:match("discord.com/api/webhooks") then
        showNotification("❌ Error", "Please enter a valid Discord webhook URL!", 5)
        return
    end
    
    gui.TestButton.Text = "⏳ SENDING..."
    gui.TestButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    
    local success, response = sendWebhook(url, true)
    
    wait(0.5)
    
    if success then
        showNotification("✅ Success", "Test webhook sent successfully!", 5)
        gui.TestButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
    else
        showNotification("❌ Error", "Failed to send webhook. Check your URL!", 5)
        gui.TestButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        wait(2)
        gui.TestButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
    end
    
    gui.TestButton.Text = "🔔 TEST"
end)

-- Toggle monitoring button
gui.ToggleButton.MouseButton1Click:Connect(function()
    if not monitoringEnabled then
        local url = gui.WebhookInput.Text
        local intervalText = gui.IntervalInput.Text
        
        if url == "" or not url:match("discord.com/api/webhooks") then
            showNotification("❌ Error", "Please enter a valid Discord webhook URL!", 5)
            return
        end
        
        local intervalMinutes = tonumber(intervalText)
        if not intervalMinutes or intervalMinutes < 1 then
            showNotification("❌ Error", "Please enter a valid interval (minimum 1 minute)!", 5)
            return
        end
        
        webhookURL = url
        notificationInterval = intervalMinutes * 60
        monitoringEnabled = true
        lastNotificationTime = 0
        
        gui.ToggleButton.Text = "⏸ STOP"
        gui.ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        gui.WebhookInput.TextEditable = false
        gui.IntervalInput.TextEditable = false
        gui.StatusLabel.TextColor3 = Color3.fromRGB(50, 200, 100)
        
        showNotification("✅ Started", "Monitoring enabled! Interval: " .. intervalMinutes .. " min", 5)
    else
        monitoringEnabled = false
        
        gui.ToggleButton.Text = "▶ START"
        gui.ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
        gui.WebhookInput.TextEditable = true
        gui.IntervalInput.TextEditable = true
        gui.StatusLabel.Text = "⏸ Status: Idle"
        gui.StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        
        showNotification("⏹ Stopped", "Monitoring disabled!", 3)
    end
end)

-- Update player list every 2 seconds
spawn(function()
    while wait(2) do
        if gui.ScreenGui.Parent then
            updatePlayerListDisplay(gui)
        else
            break
        end
    end
end)

-- Monitor fishing status every 3 seconds
spawn(function()
    while wait(FISHING_CHECK_INTERVAL) do
        if gui.ScreenGui.Parent then
            for _, player in ipairs(Players:GetPlayers()) do
                updateFishingStatus(player)
            end
        else
            break
        end
    end
end)

-- Monitor and send webhooks
spawn(function()
    while wait(1) do
        if not gui.ScreenGui.Parent then
            break
        end
        
        if monitoringEnabled then
            local currentTime = tick()
            
            if currentTime - lastNotificationTime >= notificationInterval then
                local success = sendWebhook(webhookURL, false)
                
                if success then
                    lastNotificationTime = currentTime
                    showNotification("📤 Sent", "Player update sent to Discord!", 3)
                else
                    showNotification("⚠ Warning", "Failed to send webhook!", 3)
                end
            end
        end
    end
end)

-- Player join/leave notifications
Players.PlayerAdded:Connect(function(player)
    wait(0.5)
    playerFishCounts[player.UserId] = 0
    playerFishingStatus[player.UserId] = {
        isFishing = false,
        lastUpdate = tick(),
        fishCount = 0,
        fishGained = 0
    }
    updatePlayerListDisplay(gui)
    showNotification("👋 Player Joined", player.Name .. " joined the server!", 3)
end)

Players.PlayerRemoving:Connect(function(player)
    showNotification("👋 Player Left", player.Name .. " left the server!", 3)
    playerFishCounts[player.UserId] = nil
    playerFishingStatus[player.UserId] = nil
    wait(0.5)
    updatePlayerListDisplay(gui)
end)

-- Handle screen resize for responsive design
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if not isMinimized then
        local screenSize = workspace.CurrentCamera.ViewportSize
        local guiWidth = math.min(450 * baseSize, screenSize.X * 0.9)
        local guiHeight = math.min(580 * baseSize, screenSize.Y * 0.85)
        
        tweenSize(gui.MainFrame, UDim2.new(0, guiWidth, 0, guiHeight), 0.2)
    end
end)

-- Initialize fishing status for all current players
for _, player in ipairs(Players:GetPlayers()) do
    playerFishCounts[player.UserId] = 0
    playerFishingStatus[player.UserId] = {
        isFishing = false,
        lastUpdate = tick(),
        fishCount = 0,
        fishGained = 0
    }
end

-- Initial update
updatePlayerListDisplay(gui)

-- Success notification
wait(0.1)
showNotification("✅ Fish It Monitor", "Advanced fishing detection enabled! 🎣", 5)

print("=====================================================")
print("Fish It Player Monitor - ACCURATE FISHING DETECTION")
print("=====================================================")
print("✅ Multiple detection methods:")
print("   1. Rod/Tool detection")
print("   2. Animation tracking")
print("   3. Fish count monitoring")
print("   4. Leaderstats checking")
print("🎣 Press F9 to see console debug logs")
print("Compatible with: Delta Executor, Mobile & Desktop")
print("=====================================================")
