-- =====================================================
-- Fish It - Fish Catch & Player Server Notifier
-- Chat Based Detection (Separated Notifications)
-- =====================================================

-- SERVICES
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

-- =====================================================
-- CONFIG
-- =====================================================
local webhookURL = "" -- ISI DI GUI
local monitoringEnabled = false

-- RARITY FILTER
local AllowedRarity = {
	Common = false,
	Uncommon = false,
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythical = true
}

-- Anti spam ikan
local lastFish = {}
local DUP_DELAY = 5

-- =====================================================
-- NOTIFICATION
-- =====================================================
local function notify(t, d)
	StarterGui:SetCore("SendNotification", {
		Title = t,
		Text = d,
		Duration = 4
	})
end

-- =====================================================
-- PARSE CHAT
-- =====================================================
local function parseFish(msg)
	local player, rarity, fish =
		msg:match("(.+) caught a (%a+) (.+)!")

	if player and rarity and fish then
		return player, rarity, fish
	end
end

-- =====================================================
-- WEBHOOK: FISH ONLY
-- =====================================================
local function sendFishWebhook(player, rarity, fish)
	if not AllowedRarity[rarity] then return end
	if webhookURL == "" then return end

	local key = player..rarity..fish
	if lastFish[key] and tick() - lastFish[key] < DUP_DELAY then return end
	lastFish[key] = tick()

	local embed = {
		title = "🐟 Fish Caught!",
		color = 16776960,
		fields = {
			{ name = "👤 Player", value = player, inline = true },
			{ name = "🎖 Rarity", value = rarity, inline = true },
			{ name = "🐠 Fish", value = fish, inline = false },
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S")
	}

	request({
		Url = webhookURL,
		Method = "POST",
		Headers = {["Content-Type"]="application/json"},
		Body = HttpService:JSONEncode({
			username = "Fish It - Catch Log",
			embeds = {embed}
		})
	})
end

-- =====================================================
-- WEBHOOK: PLAYER SERVER ONLY
-- =====================================================
local function sendPlayerWebhook()
	if webhookURL == "" then return end

	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, "• "..p.Name)
	end

	local embed = {
		title = "👥 Server Player List",
		color = 5793266,
		description = table.concat(list, "\n"),
		fields = {
			{
				name = "Total Player",
				value = #list.."/"..Players.MaxPlayers,
				inline = true
			}
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S")
	}

	request({
		Url = webhookURL,
		Method = "POST",
		Headers = {["Content-Type"]="application/json"},
		Body = HttpService:JSONEncode({
			username = "Fish It - Server Monitor",
			embeds = {embed}
		})
	})
end

-- =====================================================
-- CHAT HOOK (BARU)
-- =====================================================
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.OnIncomingMessage = function(msg)
		if not monitoringEnabled then return end
		if not msg.Text then return end

		if msg.Text:find("caught a") then
			local p, r, f = parseFish(msg.Text)
			if p then
				sendFishWebhook(p, r, f)
			end
		end
	end
end

-- =====================================================
-- CHAT LAMA (BACKUP)
-- =====================================================
local function hookChat(plr)
	plr.Chatted:Connect(function(msg)
		if not monitoringEnabled then return end
		if msg:find("caught a") then
			local p, r, f = parseFish(msg)
			if p then
				sendFishWebhook(p, r, f)
			end
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	hookChat(p)
end
Players.PlayerAdded:Connect(hookChat)

-- =====================================================
-- GUI SEDERHANA
-- =====================================================
local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "FishItNotifier"

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(360, 260)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.AnchorPoint = Vector2.new(0.5,0.5)
frame.BackgroundColor3 = Color3.fromRGB(30,30,40)

local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0,8)

local title = Instance.new("TextLabel", frame)
title.Text = "🐟 Fish It Notifier"
title.Size = UDim2.fromOffset(340,30)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16

local box = Instance.new("TextBox", frame)
box.Size = UDim2.fromOffset(340,32)
box.PlaceholderText = "Discord Webhook URL"
box.BackgroundColor3 = Color3.fromRGB(45,45,60)
box.TextColor3 = Color3.new(1,1,1)

local btn = Instance.new("TextButton", frame)
btn.Size = UDim2.fromOffset(340,40)
btn.Text = "▶ START"
btn.BackgroundColor3 = Color3.fromRGB(50,180,80)
btn.TextColor3 = Color3.new(1,1,1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16

-- =====================================================
-- TOGGLE
-- =====================================================
btn.MouseButton1Click:Connect(function()
	if not monitoringEnabled then
		if box.Text == "" then
			notify("Error","Webhook kosong")
			return
		end
		webhookURL = box.Text
		monitoringEnabled = true
		btn.Text = "⏹ STOP"
		btn.BackgroundColor3 = Color3.fromRGB(200,60,60)

		sendPlayerWebhook() -- KIRIM PLAYER LIST SAAT START
		notify("Active","Monitoring berjalan")
	else
		monitoringEnabled = false
		btn.Text = "▶ START"
		btn.BackgroundColor3 = Color3.fromRGB(50,180,80)
		notify("Stopped","Monitoring berhenti")
	end
end)

notify("Fish It","Script berhasil dijalankan")
print("Fish It Separated Notifier Loaded")
