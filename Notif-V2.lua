-- Fish It Player Monitor & Catch Detector
-- Modified Version - Detects Chat Notifications & Player List
-- Compatible with Delta Executor / Mobile / PC

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Variables
local LocalPlayer = Players.LocalPlayer
local webhookURL = ""
local monitoringEnabled = false
local catchMonitoringEnabled = false -- New variable for catch alerts
local notificationInterval = 300
local lastNotificationTime = 0
local isMinimized = false

-- Rarity Configuration (Colors & Keywords)
local RarityConfig = {
    ["Common"] = {Color = 10066329, Priority = 1},     -- Grey
    ["Uncommon"] = {Color = 3066993, Priority = 2},    -- Green
    ["Rare"] = {Color = 3447003, Priority = 3},        -- Blue
    ["Epic"] = {Color = 10181046, Priority = 4},       -- Purple
    ["Legendary"] = {Color = 15105570, Priority = 5},  -- Orange/Gold
    ["Mythical"] = {Color = 15548997, Priority = 6},   -- Red
    ["Exotic"] = {Color = 16711800, Priority = 7},     -- Pink
    ["Secret"] = {Color = 0, Priority = 8}             -- Black
}

-- Minimum rarity to notify (Change to "Common" to see everything)
local MinRarityToNotify = "Rare" 

-- Responsive Design Variables
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local baseSize = isMobile and 0.85 or 1

-- Animation Functions
local function tweenSize(object, targetSize, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = targetSize
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
    ScreenGui.Name = "FishItMonitorGUI_V2"
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
    local guiHeight = math.min(650 * baseSize, screenSize.Y * 0.85) -- Increased height for new button
    
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
    Title.Text = "🐟 Fish It Monitor & Alerts"
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
    
    -- Content Frame
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
    
    -- Player List Section
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
    
    local PlayerListFrame = Instance.new("ScrollingFrame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    PlayerListFrame.BorderSizePixel = 0
    PlayerListFrame.Position = UDim2.new(0, 20, 0, 205)
    PlayerListFrame.Size = UDim2.new(1, -40, 0, 130) -- Slightly smaller to make room
    PlayerListFrame.ScrollBarThickness = 6
    PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerListFrame.Parent = ContentFrame
    
    local PlayerListCorner = Instance.new("UICorner")
    PlayerListCorner.CornerRadius = UDim.new(0, 6)
    PlayerListCorner.Parent = PlayerListFrame
    
    local PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.Padding = UDim.new(0, 5)
    PlayerListLayout.Parent = PlayerListFrame
    
    local PlayerListPadding = Instance.new("UIPadding")
    PlayerListPadding.PaddingTop = UDim.new(0, 8)
    PlayerListPadding.PaddingBottom = UDim.new(0, 8)
    PlayerListPadding.PaddingLeft = UDim.new(0, 10)
    PlayerListPadding.PaddingRight = UDim.new(0, 10)
    PlayerListPadding.Parent = PlayerListFrame
    
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
    
    -- CONTROL BUTTONS AREA --
    local ButtonStartY = 350
    local ButtonHeight = 40
    local ButtonGap = 10
    
    -- Test Button
    local TestButton = Instance.new("TextButton")
    TestButton.Name = "TestButton"
    TestButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
    TestButton.BorderSizePixel = 0
    TestButton.Position = UDim2.new(0, 20, 0, ButtonStartY)
    TestButton.Size = UDim2.new(0.48, -5, 0, ButtonHeight)
    TestButton.Font = Enum.Font.GothamBold
    TestButton.Text = "🔔 TEST WEBHOOK"
    TestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TestButton.TextSize = isMobile and 12 or 14
    TestButton.Parent = ContentFrame
    Instance.new("UICorner", TestButton).CornerRadius = UDim.new(0, 8)
    
    -- Player Monitor Toggle
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Position = UDim2.new(0.52, 0, 0, ButtonStartY)
    ToggleButton.Size = UDim2.new(0.48, -20, 0, ButtonHeight)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.Text = "▶ START MONITOR"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = isMobile and 12 or 14
    ToggleButton.Parent = ContentFrame
    Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 8)
    
    -- Fish Alert Toggle (NEW)
    local CatchToggleButton = Instance.new("TextButton")
    CatchToggleButton.Name = "CatchToggleButton"
    CatchToggleButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100) -- Default Off color
    CatchToggleButton.BorderSizePixel = 0
    CatchToggleButton.Position = UDim2.new(0, 20, 0, ButtonStartY + ButtonHeight + ButtonGap)
    CatchToggleButton.Size = UDim2.new(1, -40, 0, ButtonHeight)
    CatchToggleButton.Font = Enum.Font.GothamBold
    CatchToggleButton.Text = "🎣 FISH ALERTS: OFF"
    CatchToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CatchToggleButton.TextSize = isMobile and 12 or 14
    CatchToggleButton.Parent = ContentFrame
    Instance.new("UICorner", CatchToggleButton).CornerRadius = UDim.new(0, 8)
    
    -- Status Label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Position = UDim2.new(0, 20, 0, ButtonStartY + (ButtonHeight * 2) + (ButtonGap * 2))
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
    MinimizedIcon.Visible = false
    MinimizedIcon.Parent = ScreenGui
    Instance.new("UICorner", MinimizedIcon).CornerRadius = UDim.new(1, 0)
    
    local MinIconLabel = Instance.new("TextLabel")
    MinIconLabel.BackgroundTransparency = 1
    MinIconLabel.Size = UDim2.new(1, 0, 1, 0)
    MinIconLabel.Font = Enum.Font.GothamBold
    MinIconLabel.Text = "🐟"
    MinIconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinIconLabel.TextSize = 28
    MinIconLabel.Parent = MinimizedIcon
    
    -- Draggable Logic
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    return {
        ScreenGui = ScreenGui, MainFrame = MainFrame, Shadow = Shadow, WebhookInput = WebhookInput,
        IntervalInput = IntervalInput, PlayerListFrame = PlayerListFrame, PlayerListLayout = PlayerListLayout,
        PlayerCountDisplay = PlayerCountDisplay, TestButton = TestButton, ToggleButton = ToggleButton,
        CatchToggleButton = CatchToggleButton, StatusLabel = StatusLabel, MinimizeButton = MinimizeButton,
        CloseButton = CloseButton, MinimizedIcon = MinimizedIcon
    }
end

-- Update player list display
local function updatePlayerListDisplay(gui)
    for _, child in pairs(gui.PlayerListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local players = Players:GetPlayers()
    gui.PlayerCountDisplay.Text = #players .. "/" .. Players.MaxPlayers
    for i, player in ipairs(players) do
        local PlayerEntry = Instance.new("Frame")
        PlayerEntry.Name = "Player_" .. player.Name
        PlayerEntry.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        PlayerEntry.Size = UDim2.new(1, 0, 0, 35)
        PlayerEntry.Parent = gui.PlayerListFrame
        Instance.new("UICorner", PlayerEntry).CornerRadius = UDim.new(0, 4)
        
        local PlayerIcon = Instance.new("TextLabel")
        PlayerIcon.BackgroundTransparency, PlayerIcon.Position, PlayerIcon.Size = 1, UDim2.new(0, 5, 0, 0), UDim2.new(0, 25, 1, 0)
        PlayerIcon.Text, PlayerIcon.TextColor3 = "👤", Color3.fromRGB(100, 200, 255)
        PlayerIcon.Parent = PlayerEntry
        
        local PlayerName = Instance.new("TextLabel")
        PlayerName.BackgroundTransparency, PlayerName.Position, PlayerName.Size = 1, UDim2.new(0, 35, 0, 0), UDim2.new(0.6, -35, 1, 0)
        PlayerName.Text, PlayerName.TextColor3, PlayerName.Font = player.Name, Color3.fromRGB(255, 255, 255), Enum.Font.Gotham
        PlayerName.TextXAlignment = Enum.TextXAlignment.Left
        PlayerName.Parent = PlayerEntry
        
        local DisplayName = Instance.new("TextLabel")
        DisplayName.BackgroundTransparency, DisplayName.Position, DisplayName.Size = 1, UDim2.new(0.6, 0, 0, 0), UDim2.new(0.4, -5, 1, 0)
        DisplayName.Text, DisplayName.TextColor3, DisplayName.Font = "@" .. player.DisplayName, Color3.fromRGB(150, 200, 255), Enum.Font.GothamSemibold
        DisplayName.TextXAlignment = Enum.TextXAlignment.Right
        DisplayName.Parent = PlayerEntry
    end
    gui.PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, gui.PlayerListLayout.AbsoluteContentSize.Y + 16)
end

-- Send Catch Webhook (New Function)
local function sendCatchWebhook(playerName, fishRarity, message)
    if webhookURL == "" then return end
    
    local color = RarityConfig[fishRarity] and RarityConfig[fishRarity].Color or 16777215
    
    local embed = {
        ["title"] = "🎣 New " .. fishRarity .. " Catch!",
        ["description"] = "**" .. playerName .. "** just caught something!",
        ["color"] = color,
        ["fields"] = {
            {
                ["name"] = "🐟 Notification",
                ["value"] = message,
                ["inline"] = false
            },
            {
                ["name"] = "💎 Rarity",
                ["value"] = fishRarity,
                ["inline"] = true
            },
            {
                ["name"] = "⏰ Time",
                ["value"] = os.date("%H:%M:%S"),
                ["inline"] = true
            }
        },
        ["footer"] = {
            ["text"] = "Fish It Monitor • Auto Detection"
        }
    }

    local data = {
        ["username"] = "Fish It Alerts",
        ["avatar_url"] = "https://tr.rbxcdn.com/cb7e5adc9cac8bcd85e6a3eaeff4b42e/150/150/Image/Png",
        ["embeds"] = {embed}
    }

    pcall(function()
        request({
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Process Chat Messages for Fish
local function processChatMessage(msg, senderName)
    if not catchMonitoringEnabled or webhookURL == "" then return end
    
    -- Convert message to lowercase for checking
    local lowerMsg = msg:lower()
    
    -- Check if it contains keywords indicating a catch
    if lowerMsg:find("caught") or lowerMsg:find("captured") or lowerMsg:find("found") then
        local detectedRarity = nil
        local highestPriority = 0
        
        -- Check against Rarity Config
        for rarity, data in pairs(RarityConfig) do
            if lowerMsg:find(rarity:lower()) then
                -- Check priority to ensure "Legendary" is picked over "Rare" if both exist
                if data.Priority > highestPriority then
                    highestPriority = data.Priority
                    detectedRarity = rarity
                end
            end
        end
        
        -- Filter by MinRarity
        if detectedRarity then
            local minPriority = RarityConfig[MinRarityToNotify] and RarityConfig[MinRarityToNotify].Priority or 0
            if highestPriority >= minPriority then
                sendCatchWebhook(senderName, detectedRarity, msg)
            end
        end
    end
end

-- Chat Listener
local function startChatListener()
    -- 1. Modern TextChatService
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        TextChatService.MessageReceived:Connect(function(textChatMessage)
            local sender = textChatMessage.TextSource and textChatMessage.TextSource.Name or "System"
            processChatMessage(textChatMessage.Text, sender)
        end)
    else
        -- 2. Legacy Chat (Player.Chatted)
        -- Also listen for System messages if possible, but Player.Chatted is reliable for player announcements
        local function setupPlayer(player)
            player.Chatted:Connect(function(msg)
                processChatMessage(msg, player.Name)
            end)
        end
        
        for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
        Players.PlayerAdded:Connect(setupPlayer)
        
        -- Try to listen to legacy system messages
        if ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") then
            local chatEvents = ReplicatedStorage.DefaultChatSystemChatEvents
            if chatEvents:FindFirstChild("OnMessageDoneFiltering") then
                chatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(function(data)
                    if data and data.Message and data.FromSpeaker then
                        processChatMessage(data.Message, data.FromSpeaker)
                    end
                end)
            end
        end
    end
end

-- Generic Webhook function (for Player List)
local function sendWebhook(url, isTest)
    local players = Players:GetPlayers()
    local embed = {
        ["title"] = isTest and "🧪 Test Webhook" or "📊 Server Status Update",
        ["description"] = isTest and "Webhook functional!" or "Regular player list update.",
        ["color"] = isTest and 3447003 or 5814783,
        ["fields"] = {
            {["name"] = "👥 Player Count", ["value"] = #players .. "/" .. Players.MaxPlayers, ["inline"] = true},
            {["name"] = "🎮 Job ID", ["value"] = game.JobId ~= "" and game.JobId:sub(1,8) or "N/A", ["inline"] = true}
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
    }
    
    local data = {
        ["username"] = "Fish It Monitor",
        ["embeds"] = {embed}
    }
    
    local success, _ = pcall(function()
        request({
            Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    return success
end

local function showNotification(title, text, duration)
    StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 5})
end

-- Main Execution
local gui = createGUI()

gui.MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = true
    tweenSize(gui.MainFrame, UDim2.new(0, 0, 0, 0), 0.3)
    wait(0.3)
    gui.MainFrame.Visible = false
    gui.MinimizedIcon.Visible = true
end)

gui.MinimizedIcon.MouseButton1Click:Connect(function()
    isMinimized = false
    gui.MinimizedIcon.Visible = false
    gui.MainFrame.Visible = true
    tweenSize(gui.MainFrame, UDim2.new(0, 450 * baseSize, 0, 650 * baseSize), 0.3)
end)

gui.CloseButton.MouseButton1Click:Connect(function()
    gui.ScreenGui:Destroy()
    monitoringEnabled = false
    catchMonitoringEnabled = false
end)

gui.TestButton.MouseButton1Click:Connect(function()
    if gui.WebhookInput.Text == "" then return end
    sendWebhook(gui.WebhookInput.Text, true)
    showNotification("✅ Sent", "Test webhook sent", 3)
end)

gui.ToggleButton.MouseButton1Click:Connect(function()
    if not monitoringEnabled then
        if gui.WebhookInput.Text == "" then return end
        webhookURL = gui.WebhookInput.Text
        notificationInterval = tonumber(gui.IntervalInput.Text) * 60 or 300
        monitoringEnabled = true
        gui.ToggleButton.Text = "⏸ STOP MONITOR"
        gui.ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        showNotification("Started", "Player monitoring active", 3)
    else
        monitoringEnabled = false
        gui.ToggleButton.Text = "▶ START MONITOR"
        gui.ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
        showNotification("Stopped", "Player monitoring stopped", 3)
    end
end)

-- NEW: Fish Alert Toggle Logic
gui.CatchToggleButton.MouseButton1Click:Connect(function()
    if not catchMonitoringEnabled then
        if gui.WebhookInput.Text == "" then 
            showNotification("❌ Error", "Enter Webhook URL first!", 3)
            return 
        end
        webhookURL = gui.WebhookInput.Text
        catchMonitoringEnabled = true
        gui.CatchToggleButton.Text = "🎣 FISH ALERTS: ON"
        gui.CatchToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80) -- Green
        showNotification("🎣 Alerts On", "Scanning chat for " .. MinRarityToNotify .. "+ fish!", 3)
    else
        catchMonitoringEnabled = false
        gui.CatchToggleButton.Text = "🎣 FISH ALERTS: OFF"
        gui.CatchToggleButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100) -- Default
        showNotification("🎣 Alerts Off", "Chat scanning disabled", 3)
    end
end)

-- Loops
spawn(function()
    while wait(2) do
        if gui.ScreenGui.Parent then updatePlayerListDisplay(gui) else break end
    end
end)

spawn(function()
    while wait(1) do
        if not gui.ScreenGui.Parent then break end
        if monitoringEnabled then
            local currentTime = tick()
            if currentTime - lastNotificationTime >= notificationInterval then
                if sendWebhook(webhookURL, false) then lastNotificationTime = currentTime end
            end
        end
    end
end)

-- Initialize Chat Listener
startChatListener()

updatePlayerListDisplay(gui)
showNotification("✅ Fish It Monitor V2", "Loaded successfully!", 5)
