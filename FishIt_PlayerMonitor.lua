-- Fish It Player Monitor with Discord Webhook
-- Enhanced Version with Minimize/Maximize Feature & Responsive Design
-- FIXED: Added ScrollingFrame for player list so buttons are visible
-- Compatible with Delta Executor

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Variables
local LocalPlayer = Players.LocalPlayer
local webhookURL = ""
local monitoringEnabled = false
local notificationInterval = 300
local lastNotificationTime = 0
local isMinimized = false

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
    
    -- FIXED: Changed from Frame to ScrollingFrame
    local PlayerListFrame = Instance.new("ScrollingFrame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    PlayerListFrame.BorderSizePixel = 0
    PlayerListFrame.Position = UDim2.new(0, 20, 0, 205)
    PlayerListFrame.Size = UDim2.new(1, -40, 0, 150) -- Fixed height untuk memberikan ruang untuk tombol
    PlayerListFrame.ScrollBarThickness = 6
    PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be updated dynamically
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
    
    -- FIXED: Buttons repositioned to be below the player list
    -- Test Button
    local TestButton = Instance.new("TextButton")
    TestButton.Name = "TestButton"
    TestButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
    TestButton.BorderSizePixel = 0
    TestButton.Position = UDim2.new(0, 20, 0, 370) -- Moved down
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
    ToggleButton.Position = UDim2.new(0.52, 5, 0, 370) -- Moved down
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
    StatusLabel.Position = UDim2.new(0, 20, 0, 430) -- Moved down
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

-- Update player list display with scroll support
local function updatePlayerListDisplay(gui)
    -- Clear existing player entries
    for _, child in pairs(gui.PlayerListFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local players = Players:GetPlayers()
    local playerCount = #players
    
    -- Update player count
    gui.PlayerCountDisplay.Text = playerCount .. "/" .. Players.MaxPlayers
    
    -- Add player entries
    for i, player in ipairs(players) do
        local PlayerEntry = Instance.new("Frame")
        PlayerEntry.Name = "Player_" .. player.Name
        PlayerEntry.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        PlayerEntry.BorderSizePixel = 0
        PlayerEntry.Size = UDim2.new(1, 0, 0, 30)
        PlayerEntry.Parent = gui.PlayerListFrame
        
        local EntryCorner = Instance.new("UICorner")
        EntryCorner.CornerRadius = UDim.new(0, 4)
        EntryCorner.Parent = PlayerEntry
        
        local PlayerName = Instance.new("TextLabel")
        PlayerName.BackgroundTransparency = 1
        PlayerName.Position = UDim2.new(0, 10, 0, 0)
        PlayerName.Size = UDim2.new(0.7, -10, 1, 0)
        PlayerName.Font = Enum.Font.Gotham
        PlayerName.Text = player.Name
        PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255)
        PlayerName.TextSize = isMobile and 11 or 12
        PlayerName.TextXAlignment = Enum.TextXAlignment.Left
        PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
        PlayerName.Parent = PlayerEntry
        
        local DisplayName = Instance.new("TextLabel")
        DisplayName.BackgroundTransparency = 1
        DisplayName.Position = UDim2.new(0.7, 0, 0, 0)
        DisplayName.Size = UDim2.new(0.3, 0, 1, 0)
        DisplayName.Font = Enum.Font.GothamSemibold
        DisplayName.Text = player.DisplayName
        DisplayName.TextColor3 = Color3.fromRGB(150, 200, 255)
        DisplayName.TextSize = isMobile and 10 or 11
        DisplayName.TextXAlignment = Enum.TextXAlignment.Right
        DisplayName.TextTruncate = Enum.TextTruncate.AtEnd
        DisplayName.Parent = PlayerEntry
    end
    
    -- Update canvas size for scrolling
    gui.PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, gui.PlayerListLayout.AbsoluteContentSize.Y + 16)
end

-- Function to send webhook
local function sendWebhook(url, isTest)
    local players = Players:GetPlayers()
    local playerList = {}
    
    for _, player in ipairs(players) do
        table.insert(playerList, {
            name = player.Name,
            displayName = player.DisplayName,
            userId = player.UserId
        })
    end
    
    local embed = {
        ["title"] = isTest and "🧪 Test Webhook" or "📊 Player Update",
        ["description"] = isTest and "This is a test notification from Fish It Monitor!" or "Current players in the server:",
        ["color"] = isTest and 3447003 or 5814783,
        ["fields"] = {
            {
                ["name"] = "👥 Player Count",
                ["value"] = #players .. "/" .. Players.MaxPlayers,
                ["inline"] = true
            },
            {
                ["name"] = "🎮 Server",
                ["value"] = game.JobId ~= "" and game.JobId:sub(1, 8) .. "..." or "Private Server",
                ["inline"] = true
            }
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
    }
    
    -- Add player list if not empty
    if #playerList > 0 then
        local playerNames = {}
        for i, player in ipairs(playerList) do
            table.insert(playerNames, i .. ". " .. player.name .. " (@" .. player.displayName .. ")")
        end
        table.insert(embed.fields, {
            ["name"] = "📋 Player List",
            ["value"] = table.concat(
