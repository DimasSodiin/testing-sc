-- Fish It Player Monitor with Discord Webhook
-- Enhanced Version - ONLY Mythic & Secret Fish Detection
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

-- Responsive Design
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local baseSize = isMobile and 0.85 or 1

-- Hanya rarity yang diinginkan
local TARGET_RARITIES = {
    ["Mythic"] = {color = 16711680, emoji = "🔴", name = "Mythic"},
    ["Secret"] = {color = 16777215, emoji = "✨", name = "Secret"}
}

-- Animation Functions (sama seperti sebelumnya)
local function tweenSize(object, targetSize, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize})
    tween:Play()
    return tween
end

local function tweenTransparency(object, targetTransparency, duration)
    local tween = TweenService:Create(object, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = targetTransparency})
    tween:Play()
    return tween
end

-- GUI Creation (sama seperti sebelumnya, hanya saya singkat di sini)
local function createGUI()
    -- ... (kode GUI sama persis seperti versi sebelumnya)
    -- supaya tidak terlalu panjang, asumsikan bagian ini tetap sama
    -- kamu bisa copy dari kode sebelumnya
end

-- Fungsi kirim webhook khusus fish catch (Mythic/Secret only)
local function sendFishWebhook(url, playerName, fishName, rarity)
    local config = TARGET_RARITIES[rarity]
    if not config then return false end

    local embed = {
        title = "🌟 " .. config.name .. " Fish Caught!",
        description = "**" .. playerName .. "** berhasil menangkap **" .. fishName .. "** (" .. config.name .. ")!",
        color = config.color,
        fields = {
            {name = "Player", value = playerName, inline = true},
            {name = "Rarity", value = config.emoji .. " " .. rarity, inline = true},
            {name = "Fish", value = fishName, inline = true}
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
        footer = {text = "Fish It Monitor • Only Mythic & Secret"}
    }

    local data = {
        username = "Fish It Monitor",
        avatar_url = "https://tr.rbxcdn.com/cb7e5adc9cac8bcd85e6a3eaeff4b42e/150/150/Image/Png",
        embeds = {embed}
    }

    local success = pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)

    return success
end

-- Fungsi deteksi chat (diperketat hanya Mythic & Secret)
local function monitorChat()
    local success, err = pcall(function()
        local chatGui = LocalPlayer:WaitForChild("PlayerGui", 10):WaitForChild("Chat", 10)
        local scroller = chatGui:FindFirstChild("Frame", true)
                     and chatGui.Frame:FindFirstChild("ChatChannelParentFrame", true)
                     and chatGui.Frame.ChatChannelParentFrame:FindFirstChild("Frame_MessageLogDisplay", true)
                     and chatGui.Frame.ChatChannelParentFrame.Frame_MessageLogDisplay:FindFirstChild("Scroller")

        if not scroller then
            warn("[FishMonitor] Tidak menemukan Chat Scroller!")
            return
        end

        print("[FishMonitor] Chat monitoring aktif!")

        scroller.ChildAdded:Connect(function(child)
            if not monitoringEnabled then return end
            if not child:IsA("Frame") then return end

            local messageLabel = child:FindFirstChildWhichIsA("TextLabel", true)
            if not messageLabel then return end

            local msg = messageLabel.Text:lower() -- case insensitive

            -- Coba beberapa pola yang mungkin muncul di Fish It
            local patterns = {
                "(.+) caught a mythic (.+)!",
                "(.+) caught a secret (.+)!",
                "(.+) menangkap mythic (.+)",
                "(.+) menangkap secret (.+)",
                "you caught a mythic (.+)",
                "you caught a secret (.+)"
            }

            for _, pattern in ipairs(patterns) do
                local playerPart, fishPart = msg:match(pattern)
                if playerPart and fishPart then
                    local playerName = playerPart:match("^you$") and LocalPlayer.Name or playerPart:gsub("^%s*(.-)%s*$", "%1")
                    local fishName = fishPart:gsub("^%s*(.-)%s*$", "%1"):gsub("[!%.]$", "")

                    local rarity = msg:find("mythic") and "Mythic" or "Secret"

                    print("[FISH DETECTED] " .. rarity .. " | Player: " .. playerName .. " | Fish: " .. fishName)

                    -- Notifikasi di Roblox
                    StarterGui:SetCore("SendNotification", {
                        Title = "🌟 " .. rarity .. " Catch!",
                        Text = playerName .. " caught " .. fishName .. "!",
                        Duration = 8
                    })

                    -- Kirim ke Discord
                    if webhookURL ~= "" then
                        local sent = sendFishWebhook(webhookURL, playerName, fishName, rarity)
                        if not sent then
                            warn("[FishMonitor] Gagal kirim webhook untuk " .. fishName)
                        end
                    end

                    return -- cukup satu pola yang cocok
                end
            end
        end)
    end)

    if not success then
        warn("[FishMonitor] Error saat setup chat monitor: " .. tostring(err))
    end
end

-- Main (sama seperti sebelumnya, hanya update status & panggil monitorChat)
local gui = createGUI()

-- ... (kode button, minimize, close, player list, interval webhook, dll tetap sama)

-- Saat toggle ON
gui.ToggleButton.MouseButton1Click:Connect(function()
    if not monitoringEnabled then
        -- ... validasi webhook & interval sama seperti sebelumnya ...

        monitoringEnabled = true
        -- ... update UI ...

        spawn(monitorChat)  -- mulai pantau chat hanya saat monitoring aktif
    else
        monitoringEnabled = false
        -- ... update UI ...
    end
end)

-- ... (kode player list update, interval player webhook, join/leave, resize, dll tetap sama)

print("=====================================================")
print("Fish It Monitor - MYTHIC & SECRET ONLY")
print("=====================================================")
print("✅ Hanya deteksi Mythic dan Secret")
print("✅ Notifikasi + Webhook khusus rarity tinggi")
print("✅ Player list tetap ditampilkan")
print("✅ Debug log di console (F9)")
print("=====================================================")
