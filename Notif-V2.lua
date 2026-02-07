--[[ 
    ULTIMATE FISH-IT MONITOR V4 (Delta Executor)
    Features: Rare Fish Detector + Server Player Scanner
    Created by Gemini
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- --- KONFIGURASI DEFAULT ---
local activeRarities = {
    ["Mythic"] = true,
    ["Secret"] = true,
    ["Exotic"] = true,
    ["Global"] = true
}
local isMonitoringFish = false
local isLoopingPlayers = false
local webhookURL = ""

-- --- 1. MEMBUAT GUI (DASHBOARD) ---

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FishIt_Ultimate_V4"
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 480) -- Lebih panjang muat 2 fitur
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(100, 100, 255)
UIStroke.Thickness = 1
UIStroke.Parent = MainFrame

-- Header
local Header = Instance.new("TextLabel")
Header.Text = " 🎣 ULTIMATE MONITOR"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Header.TextColor3 = Color3.fromRGB(255, 255, 255)
Header.Font = Enum.Font.GothamBlack
Header.TextSize = 16
Header.TextXAlignment = Enum.TextXAlignment.Left
Header.Parent = MainFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.Size = UDim2.new(0, 40, 0, 40)
CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.TextColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = Header
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Webhook Input
local WebhookInput = Instance.new("TextBox")
WebhookInput.Size = UDim2.new(0.9, 0, 0, 35)
WebhookInput.Position = UDim2.new(0.05, 0, 0.1, 0)
WebhookInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
WebhookInput.PlaceholderText = "Paste Webhook URL Disini..."
WebhookInput.Text = ""
WebhookInput.TextColor3 = Color3.fromRGB(255, 255, 255)
WebhookInput.Parent = MainFrame
Instance.new("UICorner", WebhookInput).CornerRadius = UDim.new(0, 6)

-- SECTION 1: FISH MONITOR
local Label1 = Instance.new("TextLabel")
Label1.Text = "DETEKSI IKAN (CHAT)"
Label1.Size = UDim2.new(1, 0, 0, 20)
Label1.Position = UDim2.new(0, 0, 0.2, 0)
Label1.TextColor3 = Color3.fromRGB(255, 220, 100) -- Kuning
Label1.BackgroundTransparency = 1
Label1.Font = Enum.Font.GothamBold
Label1.TextSize = 12
Label1.Parent = MainFrame

local RarityFrame = Instance.new("Frame")
RarityFrame.Size = UDim2.new(0.9, 0, 0.2, 0)
RarityFrame.Position = UDim2.new(0.05, 0, 0.25, 0)
RarityFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
RarityFrame.Parent = MainFrame
Instance.new("UICorner", RarityFrame)

local ToggleFishBtn = Instance.new("TextButton")
ToggleFishBtn.Size = UDim2.new(0.9, 0, 0, 35)
ToggleFishBtn.Position = UDim2.new(0.05, 0, 0.47, 0)
ToggleFishBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
ToggleFishBtn.Text = "START FISH MONITOR"
ToggleFishBtn.Font = Enum.Font.GothamBold
ToggleFishBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleFishBtn.Parent = MainFrame
Instance.new("UICorner", ToggleFishBtn).CornerRadius = UDim.new(0, 6)

-- Checkbox Generator Sederhana
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0.45, 0, 0.4, 0)
layout.Parent = RarityFrame

for name, isActive in pairs(activeRarities) do
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.BackgroundColor3 = isActive and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    btn.Parent = RarityFrame
    Instance.new("UICorner", btn)
    
    btn.MouseButton1Click:Connect(function()
        activeRarities[name] = not activeRarities[name]
        btn.BackgroundColor3 = activeRarities[name] and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    end)
end

-- SECTION 2: PLAYER MONITOR
local Label2 = Instance.new("TextLabel")
Label2.Text = "SERVER PLAYER LIST"
Label2.Size = UDim2.new(1, 0, 0, 20)
Label2.Position = UDim2.new(0, 0, 0.58, 0)
Label2.TextColor3 = Color3.fromRGB(100, 220, 255) -- Biru Muda
Label2.BackgroundTransparency = 1
Label2.Font = Enum.Font.GothamBold
Label2.TextSize = 12
Label2.Parent = MainFrame

local SendPlayersBtn = Instance.new("TextButton")
SendPlayersBtn.Size = UDim2.new(0.9, 0, 0, 35)
SendPlayersBtn.Position = UDim2.new(0.05, 0, 0.63, 0)
SendPlayersBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
SendPlayersBtn.Text = "Kirim List Player (Sekarang)"
SendPlayersBtn.Font = Enum.Font.GothamBold
SendPlayersBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SendPlayersBtn.Parent = MainFrame
Instance.new("UICorner", SendPlayersBtn).CornerRadius = UDim.new(0, 6)

local LoopPlayersBtn = Instance.new("TextButton")
LoopPlayersBtn.Size = UDim2.new(0.9, 0, 0, 35)
LoopPlayersBtn.Position = UDim2.new(0.05, 0, 0.72, 0)
LoopPlayersBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
LoopPlayersBtn.Text = "Auto Loop Player List (Mati)"
LoopPlayersBtn.Font = Enum.Font.GothamBold
LoopPlayersBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
LoopPlayersBtn.Parent = MainFrame
Instance.new("UICorner", LoopPlayersBtn).CornerRadius = UDim.new(0, 6)

-- Status Footer
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Text = "Status: Idle"
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0.9, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.Parent = MainFrame

-- --- 2. LOGIKA UTAMA ---

local function SendWebhook(data)
    if WebhookInput.Text == "" then 
        StatusLabel.Text = "Status: Masukkan Webhook Dulu!"
        return 
    end
    
    local jsonData = HttpService:JSONEncode(data)
    local headers = {["Content-Type"] = "application/json"}
    
    local req = {
        Url = WebhookInput.Text,
        Method = "POST",
        Headers = headers,
        Body = jsonData
    }

    if request then request(req)
    elseif http_request then http_request(req)
    elseif syn and syn.request then syn.request(req)
    end
end

-- A. LOGIKA PLAYER LIST
local function GetPlayerListEmbed()
    local pList = Players:GetPlayers()
    local desc = ""
    
    for i, p in ipairs(pList) do
        desc = desc .. "**" .. i .. ".** " .. p.Name .. " (@" .. p.DisplayName .. ")\n"
    end
    
    return {
        ["username"] = "Server Monitor",
        ["avatar_url"] = "https://i.imgur.com/4M34hi2.png",
        ["embeds"] = {{
            ["title"] = "👥 Server Player List",
            ["description"] = desc,
            ["color"] = 3447003, -- Blue
            ["fields"] = {
                {["name"] = "Total Players", ["value"] = tostring(#pList) .. "/15", ["inline"] = true},
                {["name"] = "Server JobID", ["value"] = game.JobId, ["inline"] = true}
            },
            ["footer"] = {["text"] = "Dikirim pada: " .. os.date("%X")}
        }}
    }
end

SendPlayersBtn.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Sending Player List..."
    SendWebhook(GetPlayerListEmbed())
    wait(1)
    StatusLabel.Text = "Player List Sent!"
end)

LoopPlayersBtn.MouseButton1Click:Connect(function()
    isLoopingPlayers = not isLoopingPlayers
    if isLoopingPlayers then
        LoopPlayersBtn.Text = "Auto Loop Player List (AKTIF - 60s)"
        LoopPlayersBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        LoopPlayersBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        
        task.spawn(function()
            while isLoopingPlayers do
                SendWebhook(GetPlayerListEmbed())
                StatusLabel.Text = "Auto-Log Players Sent."
                task.wait(60) -- Ubah angka ini untuk delay (detik)
            end
        end)
    else
        LoopPlayersBtn.Text = "Auto Loop Player List (Mati)"
        LoopPlayersBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        LoopPlayersBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end)

-- B. LOGIKA FISH DETECTOR
local function CheckChat(msg, sender)
    if not isMonitoringFish then return end
    local lowerMsg = string.lower(msg)
    
    for rarity, isActive in pairs(activeRarities) do
        if isActive and string.find(lowerMsg, string.lower(rarity)) then
            -- Filter tambahan biar ga spam chat biasa
            if string.find(lowerMsg, "caught") or string.find(lowerMsg, "obtained") or string.find(lowerMsg, "found") then
                
                local data = {
                    ["username"] = "Fish Monitor",
                    ["embeds"] = {{
                        ["title"] = "🎣 " .. rarity .. " Fish Detected!",
                        ["description"] = "**Message:** " .. msg,
                        ["color"] = 16766720, -- Gold
                        ["fields"] = {
                            {["name"] = "Finder", ["value"] = sender, ["inline"] = true}
                        }
                    }}
                }
                SendWebhook(data)
                StatusLabel.Text = "Rare Fish Detected!"
            end
        end
    end
end

ToggleFishBtn.MouseButton1Click:Connect(function()
    isMonitoringFish = not isMonitoringFish
    if isMonitoringFish then
        ToggleFishBtn.Text = "STOP FISH MONITOR"
        ToggleFishBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    else
        ToggleFishBtn.Text = "START FISH MONITOR"
        ToggleFishBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    end
end)

-- Listener Chat
TextChatService.MessageReceived:Connect(function(msg)
    local sender = msg.TextSource and msg.TextSource.Name or "System"
    CheckChat(msg.Text, sender)
end)

-- Legacy Chat Support
pcall(function()
    ReplicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent:Connect(function(data)
        CheckChat(data.Message, data.FromSpeaker)
    end)
end)

-- Dragging UI
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
